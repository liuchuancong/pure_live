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
  Future<SearchAggregate> search(SearchQuery query, {Iterable<SourceId>? onlySources});
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
  Future<SearchAggregate> search(SearchQuery query, {Iterable<SourceId>? onlySources}) async {
    if (query.keyword.trim().isEmpty) {
      // A blank keyword over N sources is N pointless requests, and every one of them would be answered by
      // the provider's own contract test as an empty search.
      return SearchAggregate(query: query, outcomes: const <SearchProviderOutcome>[], refused: 'keyword is blank');
    }

    // Sources that claimed search but cannot take the call; they are reported, not dropped.
    final unsearchable = <SearchProviderOutcome>[];
    final targets = <(SourceId, SearchCapability)>[];
    for (final entry in _providers.providersFor(CapabilityKind.search)) {
      if (onlySources != null && !onlySources.contains(entry.sourceId)) {
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

    final answered = await Future.wait<SearchProviderOutcome>(
      targets.map((target) => _ask(target.$1, target.$2, query)),
    );

    return SearchAggregate(query: query, outcomes: <SearchProviderOutcome>[...unsearchable, ...answered]);
  }

  Future<SearchProviderOutcome> _ask(SourceId sourceId, SearchCapability capability, SearchQuery query) async {
    final PageResult<ContentSummary> page;
    try {
      page = await capability.search(query).timeout(perProviderTimeout);
    } on TimeoutException {
      return SearchProviderOutcome(
        sourceId: sourceId,
        kind: SearchOutcomeKind.timedOut,
        detail: 'no answer within ${perProviderTimeout.inMilliseconds}ms',
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
}
