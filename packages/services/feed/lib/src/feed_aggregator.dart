// Module: lib/src/feed_aggregator.dart
// Purpose: Turn every source's front page into the sections Home renders, with one source's failure kept local.
// Author: liuchuancong
// Created: 2026-10-09
//
// Spec: docs/services/feed.md - "Home 不是业务数据源,只是 Feed 聚合器", FeedSource[] -> FeedAggregator ->
// FeedSection[], 无该能力的源不出现在 Feed, and the paging cursor runs through to the provider. The reason
// this is its own layer is the first rule: Home may not name Bilibili/Douyu/Music, only consume sections.

import 'dart:async';

import 'package:pure_live_capability/pure_live_capability.dart';
import 'package:pure_live_platform/pure_live_platform.dart';
import 'package:pure_live_utils/pure_live_utils.dart' show CancellationToken;

/// Why a source ended up with no section. Recorded rather than silently missing, because a tile that simply
/// vanished is unexplainable to whoever has to support it.
enum FeedSkipReason { notCapable, timedOut, failed, empty }

/// One source that did not make it into the sections.
final class FeedSkip {
  const FeedSkip({required this.sourceId, required this.reason, this.detail});

  final SourceId sourceId;
  final FeedSkipReason reason;
  final String? detail;

  @override
  String toString() => 'FeedSkip($sourceId ${reason.name}${detail == null ? '' : ': $detail'})';
}

/// One provider's section of the home feed.
///
/// There is deliberately no title here: feed.md makes section order and titles user data (the sync-owned home
/// layout), so a title invented by the aggregator would be a second source of truth for the same tile.
final class FeedSection {
  const FeedSection({
    required this.sourceId,
    required this.items,
    required this.page,
    required this.mode,
    this.nextCursor,
    this.hasMore = false,
    this.contractViolation,
    this.duplicateItems = 0,
    this.foreignItems = 0,
  });

  final SourceId sourceId;
  final List<ContentSummary> items;

  /// The page this section came from, echoed back so "load more" can ask for the next one without guessing.
  /// Meaningless when [mode] is [PageMode.cursor].
  final int page;

  /// How this source pages. Carried out of the provider because the rule for asking again differs per
  /// source: feed.md wants the cursor to run through to the provider, and a caller cannot continue what the
  /// aggregator threw away.
  final PageMode mode;

  /// The continuation token for [mode] == [PageMode.cursor], null when the source gave none.
  final String? nextCursor;

  final bool hasMore;

  /// Set when the source's own answer contradicts its declared paging mode - a `singleShot` source that
  /// claims more rows, or a cursor source that says it has them and hands over no token. Recorded rather
  /// than quietly corrected: the surface stops at the end either way, but a "why did Home stop loading"
  /// report needs to know which source was wrong.
  final String? contractViolation;

  /// Repeated rows within this one section (contract.feed.duplicate_ref). The later copy is dropped; the
  /// count stays so a diagnostics view can say the source is double-listing.
  final int duplicateItems;

  /// Rows the source returned that belong to a different source. Dropped, because a row that names the wrong
  /// source cannot be opened, and the count is the evidence that the provider is broken.
  final int foreignItems;

  @override
  String toString() => 'FeedSection($sourceId ${items.length} items, page $page, hasMore: $hasMore)';
}

/// The sections plus what was left out, as one run produced them.
final class FeedResult {
  const FeedResult({required this.sections, required this.skips, required this.page});

  final List<FeedSection> sections;
  final List<FeedSkip> skips;
  final int page;

  List<ContentSummary> get allItems => <ContentSummary>[for (final section in sections) ...section.items];

  bool get isEmpty => sections.isEmpty;

  int get droppedRows => sections.fold(0, (sum, section) => sum + section.duplicateItems + section.foreignItems);
}

abstract interface class FeedAggregator {
  /// One page of the aggregated feed. Refresh means asking for page 1 again with [cursors] cleared rather
  /// than a separate reload path, because a refresh that keeps an old cursor is how a front page stops
  /// showing new rows.
  ///
  /// [cursors] is per source, from that source's own previous [FeedSection.nextCursor]: a token from one
  /// provider means nothing to another, and `PageRequest.cursor` wins over the page number, so a single
  /// shared cursor would either stall every source that ignores it or hand each source somebody else's
  /// token.
  ///
  /// [cancellation] abandons assembly: the provider requests already dispatched are not this layer's to
  /// abort (see [CapabilityFeedAggregator.perSourceTimeout]), but a cancelled run stops being reported as a
  /// set of source failures, which is what a user leaving Home actually means.
  Future<FeedResult> feed(PageRequest page, {Map<SourceId, String> cursors, CancellationToken? cancellation});
}

/// A [FeedAggregator] over the [CapabilityRegistry].
final class CapabilityFeedAggregator implements FeedAggregator {
  CapabilityFeedAggregator({required CapabilityRegistry providers, this.perSourceTimeout = const Duration(seconds: 8)})
    : _providers = providers;

  final CapabilityRegistry _providers;

  /// One source's budget. A slow recommendation must not hold the front page open, and the abandoned request
  /// is not cancelled here either: nothing in this layer knows whether the user stopped looking.
  final Duration perSourceTimeout;

  @override
  Future<FeedResult> feed(
    PageRequest page, {
    Map<SourceId, String> cursors = const <SourceId, String>{},
    CancellationToken? cancellation,
  }) async {
    cancellation?.throwIfCancelled();
    final targets = <({SourceId id, FeedCapability capability})>[];
    final skips = <FeedSkip>[];

    for (final entry in _providers.providersFor(CapabilityKind.feed)) {
      final provider = entry.provider;
      if (provider is! FeedCapability) {
        skips.add(
          FeedSkip(
            sourceId: entry.sourceId,
            reason: FeedSkipReason.notCapable,
            detail: 'declares feed but is not a FeedCapability',
          ),
        );
        continue;
      }
      targets.add((id: entry.sourceId, capability: provider));
    }

    final answered = await Future.wait<_Answer>(
      targets.map((target) => _read(target.id, target.capability, page, cursors)),
    );

    // Assembly stops here when the caller walked away. The provider requests are already dispatched and
    // keep running - this layer does not own them - but reporting their outcome as source failures would
    // blame twelve providers for one user leaving Home.
    cancellation?.throwIfCancelled();

    // Registry order, not arrival order: a front page that reorders itself between refreshes because one
    // source was slower today cannot be compared against what the user arranged.
    final sections = <FeedSection>[
      for (final answer in answered)
        if (answer.section != null) answer.section!,
    ];
    for (final answer in answered) {
      final skip = answer.skip;
      if (skip != null) {
        skips.add(skip);
      }
    }

    return FeedResult(sections: sections, skips: skips, page: page.page);
  }

  Future<_Answer> _read(
    SourceId sourceId,
    FeedCapability capability,
    PageRequest page,
    Map<SourceId, String> cursors,
  ) async {
    final PageResult<ContentSummary> result;
    final cursor = cursors[sourceId];
    final request = cursor == null ? page : PageRequest(page: page.page, pageSize: page.pageSize, cursor: cursor);
    try {
      result = await capability.feed(request).timeout(perSourceTimeout);
    } on TimeoutException {
      return _Answer(
        sourceId: sourceId,
        skip: FeedSkip(
          sourceId: sourceId,
          reason: FeedSkipReason.timedOut,
          detail: 'no answer within ${perSourceTimeout.inMilliseconds}ms',
        ),
      );
    } catch (error) {
      return _Answer(
        sourceId: sourceId,
        skip: FeedSkip(sourceId: sourceId, reason: FeedSkipReason.failed, detail: '$error'),
      );
    }

    final items = <ContentSummary>[];
    final seen = <ContentRef>{};
    var duplicates = 0;
    var foreign = 0;
    for (final item in result.items) {
      if (item.ref.sourceId != sourceId) {
        foreign++;
        continue;
      }
      // A section is one source's own list, so a repeat inside it is that source double-listing; the contract
      // forbids it and keeping the first copy is what a front page can still render.
      if (!seen.add(item.ref)) {
        duplicates++;
        continue;
      }
      items.add(item);
    }

    if (items.isEmpty) {
      final detail = foreign > 0 ? '$foreign rows named other sources' : 'the source answered with nothing';
      return _Answer(
        sourceId: sourceId,
        skip: FeedSkip(sourceId: sourceId, reason: FeedSkipReason.empty, detail: detail),
      );
    }

    return _Answer(
      sourceId: sourceId,
      section: FeedSection(
        sourceId: sourceId,
        items: items,
        page: result.page,
        mode: result.mode,
        nextCursor: result.nextCursor,
        hasMore: result.hasMore,
        contractViolation: _violationOf(sourceId, result),
        duplicateItems: duplicates,
        foreignItems: foreign,
      ),
    );
  }

  /// The ways a source's answer can contradict its own declared paging mode, named for the diagnostics view.
  ///
  /// Each case ends the same way on screen - no more rows - so the temptation is to normalise it silently.
  /// That hides the only evidence that a provider is broken, and a "Home stopped loading" report is
  /// unanswerable without it.
  static String? _violationOf(SourceId sourceId, PageResult<ContentSummary> result) => switch (result.mode) {
    PageMode.singleShot when result.hasMore || result.nextCursor != null =>
      '$sourceId is a single-shot feed but claims more rows',
    PageMode.cursor when result.hasMore && result.nextCursor == null =>
      '$sourceId says a cursor page continues but returned no cursor',
    PageMode.fixedPage when result.nextCursor != null =>
      '$sourceId returned a continuation token for a fixed-page feed',
    _ => null,
  };
}

/// One source's outcome, kept private so the public surface stays sections and skips.
final class _Answer {
  const _Answer({required this.sourceId, this.section, this.skip});

  final SourceId sourceId;
  final FeedSection? section;
  final FeedSkip? skip;
}
