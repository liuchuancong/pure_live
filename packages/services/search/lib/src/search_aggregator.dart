// Module: lib/src/search_aggregator.dart
// Purpose: Fan a search out over every provider that serves it, and keep one source's failure local.
// Author: liuchuancong
// Created: 2026-10-09
//
// Spec: docs/services/search.md - CapabilityRegistry enumerates the search providers, the queries run
// concurrently with timeout and failure isolation, partial results stay usable, and a source that answered
// nothing is marked rather than blocking the rest.

import 'dart:async';

import 'package:pure_live_capability/pure_live_capability.dart';
import 'package:pure_live_platform/pure_live_platform.dart';
import 'package:pure_live_utils/pure_live_utils.dart' show CancellationToken;

/// How one provider's share of a search ended.
enum SearchOutcomeKind { answered, empty, timedOut, failed }

/// One provider's answer.
final class SearchProviderOutcome {
  const SearchProviderOutcome({
    required this.sourceId,
    required this.kind,
    this.items = const <ContentSummary>[],
    this.page,
    this.detail,
    this.droppedForeignItems = 0,
  });

  final SourceId sourceId;
  final SearchOutcomeKind kind;

  /// The provider's own items, in the order it returned them. Empty for every non-`answered` outcome.
  final List<ContentSummary> items;

  /// What the provider said about paging. Absent when it never got to answer.
  final PageResult<ContentSummary>? page;

  /// Failure or timeout detail, for the diagnostics view and for "why is this source missing".
  final String? detail;

  /// Items the provider returned that belong to a different source (contract.search.foreign_source). They are
  /// dropped here rather than shown, because a result that names another source cannot be opened correctly.
  final int droppedForeignItems;

  bool get isUsable => kind == SearchOutcomeKind.answered;

  @override
  String toString() => 'SearchProviderOutcome($sourceId ${kind.name}${items.isEmpty ? '' : ' ${items.length}'})';
}

/// The whole fan-out. Grouping by content family is the UI's job; this keeps the per-source split so a source
/// that failed can be shown as failed.
final class SearchAggregate {
  const SearchAggregate({required this.query, required this.outcomes, this.refused});

  final SearchQuery query;
  final List<SearchProviderOutcome> outcomes;

  /// Set when the search was not run at all, so no source is blamed for a request that never went out.
  final String? refused;

  List<ContentSummary> get allItems => <ContentSummary>[for (final outcome in outcomes) ...outcome.items];

  List<SearchProviderOutcome> get answered => outcomes.where((o) => o.isUsable).toList(growable: false);

  List<SearchProviderOutcome> get problems =>
      outcomes.where((o) => !o.isUsable && o.kind != SearchOutcomeKind.empty).toList(growable: false);

  bool get isEmpty => allItems.isEmpty;

  int get droppedForeignItems => outcomes.fold(0, (sum, outcome) => sum + outcome.droppedForeignItems);
}

/// Searches whatever the platform currently knows about.
abstract interface class SearchAggregator {
  /// [onlySources] narrows the fan-out to a 站内搜索 over named sources; naming an unregistered source simply
  /// leaves it out of the run.
  ///
  /// [cancellation] abandons the run: a search box that moved on does not want its superseded answer
  /// reported as a page full of source failures.
  Future<SearchAggregate> search(SearchQuery query, {Iterable<SourceId>? onlySources, CancellationToken? cancellation});
}

/// A [SearchAggregator] over the [CapabilityRegistry].
///
/// The registry's declared routing decides which sources are asked; the object is checked again before the
/// call, and a source that declared search without implementing it is reported as failed rather than skipped -
/// a missing tile is something the user should be able to see the reason for.
final class CapabilitySearchAggregator implements SearchAggregator {
  CapabilitySearchAggregator({
    required CapabilityRegistry providers,
    this.perProviderTimeout = const Duration(seconds: 8),
  }) : _providers = providers;

  final CapabilityRegistry _providers;

  /// One source's budget. A hung provider is stopped for the aggregator's purposes only; the request it left
  /// behind is not this layer's to cancel, and cancelling it would look like a user action it never was.
  final Duration perProviderTimeout;

  @override
  Future<SearchAggregate> search(
    SearchQuery query, {
    Iterable<SourceId>? onlySources,
    CancellationToken? cancellation,
  }) async {
    cancellation?.throwIfCancelled();
    if (query.keyword.trim().isEmpty) {
      // A blank keyword over N sources is N pointless requests, and every one of them would be answered by
      // the provider's own contract test as an empty search.
      return SearchAggregate(query: query, outcomes: const <SearchProviderOutcome>[], refused: 'keyword is blank');
    }

    // Sources that claimed search but cannot take the call; they are reported, not dropped.
    final selected = selectSearchTargets(providers: _providers, onlySources: onlySources);
    final unsearchable = selected.unsearchable;
    final targets = selected.targets;

    final answered = await Future.wait<SearchProviderOutcome>(
      targets.map((target) => _ask(target.$1, target.$2, query)),
    );

    // Assembly stops for a caller that walked away; the per-provider requests already dispatched keep running
    // because this layer does not own them (see [perProviderTimeout] for the same boundary).
    cancellation?.throwIfCancelled();
    return SearchAggregate(query: query, outcomes: <SearchProviderOutcome>[...unsearchable, ...answered]);
  }

  Future<SearchProviderOutcome> _ask(SourceId sourceId, SearchCapability capability, SearchQuery query) =>
      askSearchSource(sourceId, capability, query, timeout: perProviderTimeout);
}

/// Runs one source's share of a search and classifies what came back.
///
/// Public because the live and the collected fan-out are the same rule with a different container; two copies
/// would mean one of them stops dropping foreign-source items or stops timing out.
Future<SearchProviderOutcome> askSearchSource(
  SourceId sourceId,
  SearchCapability capability,
  SearchQuery query, {
  required Duration timeout,
}) async {
  final PageResult<ContentSummary> page;
  try {
    page = await capability.search(query).timeout(timeout);
  } on TimeoutException {
    return SearchProviderOutcome(
      sourceId: sourceId,
      kind: SearchOutcomeKind.timedOut,
      detail: 'no answer within ${timeout.inMilliseconds}ms',
    );
  } catch (error) {
    return SearchProviderOutcome(sourceId: sourceId, kind: SearchOutcomeKind.failed, detail: '$error');
  }

  // A provider may only name its own content; the contract test asserts the same rule, and this is the
  // copy of it that still holds when the assertion was skipped (a third-party source that shipped anyway).
  final mine = page.items.where((item) => item.ref.sourceId == sourceId).toList(growable: false);
  if (mine.isEmpty) {
    return SearchProviderOutcome(
      sourceId: sourceId,
      kind: SearchOutcomeKind.empty,
      page: page,
      droppedForeignItems: page.items.length - mine.length,
    );
  }
  return SearchProviderOutcome(
    sourceId: sourceId,
    kind: SearchOutcomeKind.answered,
    items: mine,
    page: page,
    droppedForeignItems: page.items.length - mine.length,
  );
}

/// The sources a run will ask, plus the ones that claimed search and cannot take the call.
///
/// A declared-but-unusable provider is **reported**, not dropped: a missing tile needs a reason a user or a
/// support attachment can point at.
({List<(SourceId, SearchCapability)> targets, List<SearchProviderOutcome> unsearchable}) selectSearchTargets({
  required CapabilityRegistry providers,
  SearchQuery? query,
  Iterable<SourceId>? onlySources,
}) {
  final wanted = onlySources == null ? null : onlySources.toSet();
  final targets = <(SourceId, SearchCapability)>[];
  final unsearchable = <SearchProviderOutcome>[];
  for (final entry in providers.providersFor(CapabilityKind.search)) {
    if (wanted != null && !wanted.contains(entry.sourceId)) {
      continue;
    }
    final provider = entry.provider;
    if (provider is! SearchCapability) {
      unsearchable.add(
        SearchProviderOutcome(
          sourceId: entry.sourceId,
          kind: SearchOutcomeKind.failed,
          detail: 'declares search but is not a SearchCapability',
        ),
      );
      continue;
    }
    targets.add((entry.sourceId, provider));
  }
  return (targets: targets, unsearchable: unsearchable);
}

/// The next page for one source, or why there is not one.
///
/// Fixed-page sources continue by number, cursor sources by token; the mode is what the provider reported, so
/// guessing which one a source uses is exactly how a continuation repeats the first page and calls it page two.
sealed class SearchContinuation {
  const SearchContinuation();

  /// The request to send, or null when the source has nothing more.
  PageRequest? get request;

  String get reason;
}

final class HasMorePages implements SearchContinuation {
  const HasMorePages(this.request, this.page) : super();

  @override
  final PageRequest request;
  final int page;

  @override
  String get reason => 'the source serves fixed pages and reported more';
}

final class HasMoreCursor implements SearchContinuation {
  const HasMoreCursor(this.request, this.cursor) : super();

  @override
  final PageRequest request;
  final String cursor;

  @override
  String get reason => 'the source returned a continuation cursor';
}

final class SourceExhausted implements SearchContinuation {
  const SourceExhausted(this.request) : super();

  @override
  final PageRequest? request;

  @override
  String get reason => 'the source reported no more results';
}

final class ContinuationUnknown implements SearchContinuation {
  const ContinuationUnknown(this.detail) : super();

  final String detail;

  @override
  PageRequest? get request => null;

  @override
  String get reason => detail;
}

/// Works out what to ask [outcome]'s source for next.
SearchContinuation continuationFor(SearchProviderOutcome outcome) {
  final answer = outcome.page;
  if (answer == null) {
    return const ContinuationUnknown('the source never answered, so there is no page to continue');
  }
  final request = PageRequest(page: answer.page, pageSize: answer.pageSize);
  switch (answer.mode) {
    case PageMode.singleShot:
      return SourceExhausted(request);
    case PageMode.cursor:
      final cursor = answer.nextCursor;
      if (!answer.hasMore || cursor == null || cursor.trim().isEmpty) {
        return SourceExhausted(request);
      }
      return HasMoreCursor(PageRequest(page: answer.page + 1, pageSize: answer.pageSize, cursor: cursor), cursor);
    case PageMode.fixedPage:
      if (!answer.hasMore) {
        return SourceExhausted(request);
      }
      final next = answer.page + 1;
      if (next < 1) {
        // A provider that reported a page number it cannot advance (zero or negative) would otherwise loop
        // back onto the first page forever.
        return const ContinuationUnknown('the source reported a page number that cannot advance');
      }
      return HasMorePages(PageRequest(page: next, pageSize: answer.pageSize), next);
  }
}
