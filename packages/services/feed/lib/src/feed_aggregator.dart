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
    required this.hasMore,
    this.duplicateItems = 0,
    this.foreignItems = 0,
  });

  final SourceId sourceId;
  final List<ContentSummary> items;

  /// The page this section came from, echoed back so "load more" can ask for the next one without guessing.
  final int page;
  final bool hasMore;

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
  /// One page of the aggregated feed. Refresh means asking for page 1 again rather than a separate reload
  /// path, because a refresh that keeps an old cursor is how a front page stops showing new rows.
  Future<FeedResult> feed(PageRequest page);
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
  Future<FeedResult> feed(PageRequest page) async {
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

    final answered = await Future.wait<_Answer>(targets.map((target) => _read(target.id, target.capability, page)));

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

  Future<_Answer> _read(SourceId sourceId, FeedCapability capability, PageRequest page) async {
    final PageResult<ContentSummary> result;
    try {
      result = await capability.feed(page).timeout(perSourceTimeout);
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
        hasMore: result.hasMore,
        duplicateItems: duplicates,
        foreignItems: foreign,
      ),
    );
  }
}

/// One source's outcome, kept private so the public surface stays sections and skips.
final class _Answer {
  const _Answer({required this.sourceId, this.section, this.skip});

  final SourceId sourceId;
  final FeedSection? section;
  final FeedSkip? skip;
}
