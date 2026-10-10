// Module: lib/src/paging.dart
// Purpose: Carry Home's paging forward: which sources can continue, what to ask them for, and what "refresh"
// is allowed to forget.
// Author: liuchuancong
// Created: 2026-10-11
//
// feed.md gives two rules that pull against each other: the cursor runs through to the provider, and refresh
// means re-fetching the head. A single shared cursor cannot do either - one provider's token is meaningless to
// another, and a refresh that keeps the old token is how a front page stops showing new rows forever. So the
// cursors are per source, and the reset is an operation on the book rather than a flag on the request.

import 'dart:async';

import 'package:pure_live_platform/pure_live_platform.dart';
import 'package:pure_live_utils/pure_live_utils.dart' show CancellationToken;

import 'feed_aggregator.dart';

/// Why a section cannot be continued.
enum FeedContinuationReason {
  /// The source said there is nothing after this page.
  exhausted,

  /// A cursor source promised more and handed over no token.
  missingCursor,

  /// The section is the tail of a run, not a page a source produced.
  notPaged,
}

/// What to ask one source for next, or why not to ask.
final class FeedContinuation {
  const FeedContinuation._(this.sourceId, this.request, this.reason);

  factory FeedContinuation.next(SourceId sourceId, PageRequest request) => FeedContinuation._(sourceId, request, null);

  factory FeedContinuation.blocked(SourceId sourceId, FeedContinuationReason reason) =>
      FeedContinuation._(sourceId, null, reason);

  final SourceId sourceId;

  /// Null when the source cannot continue.
  final PageRequest? request;
  final FeedContinuationReason? reason;

  bool get canContinue => request != null;

  @override
  String toString() => canContinue
      ? 'FeedContinuation($sourceId -> page ${request!.page})'
      : 'FeedContinuation.blocked($sourceId ${reason?.name})';
}

/// The next request for one section, read off the mode the *source* reported.
///
/// Guessing is what makes a continuation repeat page one and call it page two, and a cursor token taken from a
/// different source is not a guess at all - it is somebody else's state.
FeedContinuation continuationFor(FeedSection section) {
  switch (section.mode) {
    case PageMode.singleShot:
      return FeedContinuation.blocked(section.sourceId, FeedContinuationReason.exhausted);
    case PageMode.cursor:
      final cursor = section.nextCursor;
      if (!section.hasMore || cursor == null || cursor.trim().isEmpty) {
        return FeedContinuation.blocked(section.sourceId, FeedContinuationReason.exhausted);
      }
      return FeedContinuation.next(
        section.sourceId,
        PageRequest(page: section.page + 1, pageSize: section.items.length, cursor: cursor),
      );
    case PageMode.fixedPage:
      if (!section.hasMore) {
        return FeedContinuation.blocked(section.sourceId, FeedContinuationReason.exhausted);
      }
      final next = section.page + 1;
      if (next < 1) {
        return FeedContinuation.blocked(section.sourceId, FeedContinuationReason.notPaged);
      }
      return FeedContinuation.next(section.sourceId, PageRequest(page: next, pageSize: section.items.length));
  }
}

/// The per-source cursors between runs.
///
/// Only a cursor source's token is kept: a numbered feed continues by page number, and storing a number here
/// would put the same fact in two places with different lifetimes - the classic way a numbered feed starts
/// skipping pages after a refresh.
final class FeedCursorBook {
  FeedCursorBook({Map<SourceId, String> initial = const <SourceId, String>{}})
    : _tokens = Map<SourceId, String>.of(initial);

  final Map<SourceId, String> _tokens;

  Map<SourceId, String> get tokens => Map<SourceId, String>.unmodifiable(_tokens);

  int get length => _tokens.length;

  /// Records what a source just handed over, so the next page can be asked with it.
  void observe(FeedSection section) {
    final cursor = section.nextCursor;
    if (section.mode != PageMode.cursor || cursor == null || cursor.trim().isEmpty) {
      return;
    }
    _tokens[section.sourceId] = cursor;
  }

  /// Drops one source's token, for the tile the user pulled on individually.
  void forget(SourceId sourceId) => _tokens.remove(sourceId);

  /// Forgets every token. This is what "refresh" means in feed.md: the head is re-fetched, and a stale token
  /// would re-fetch the tail of a session the user has left behind.
  void reset() => _tokens.clear();

  @override
  String toString() => 'FeedCursorBook(${_tokens.length} sources)';
}

/// One page boundary the pager produced.
final class FeedPage {
  const FeedPage({required this.sections, required this.skips, required this.blocked, required this.page});

  /// The sections that arrived, in registry order as the aggregator produced them.
  final List<FeedSection> sections;

  /// Sources that did not answer this page.
  final List<FeedSkip> skips;

  /// Sources that said they have nothing more, with the reason. Reported rather than absent: "why did this
  /// tile stop" needs an answer that is not "it silently stopped".
  final List<FeedContinuation> blocked;

  final int page;

  bool get hasAnything => sections.isNotEmpty;

  @override
  String toString() =>
      'FeedPage(page $page, ${sections.length} sections, ${skips.length} skipped, ${blocked.length} blocked)';
}

/// Pages a set of sources forward, one request per source that can continue.
///
/// The aggregator's own `feed(page)` sends the same page number to every source, which is right for the first
/// pull and wrong for the tail: sources run out at different depths, and continuing a source that already said
/// "no more" is how a load-more button re-renders rows the user has already seen.
final class FeedPager {
  FeedPager({required this.aggregator, this.pageSize = 20, this.maxPagesPerRun = 1});

  final FeedAggregator aggregator;
  final int pageSize;

  /// A safety bound on one gesture: more than this and a stuck source keeps asking while the user waits.
  final int maxPagesPerRun;

  final FeedCursorBook cursors = FeedCursorBook();

  Map<SourceId, List<FeedSection>> _tail = <SourceId, List<FeedSection>>{};
  int _pages = 0;
  int _gesturePages = 0;

  /// The sections gathered so far, per source, oldest first.
  Map<SourceId, List<FeedSection>> get accumulated => Map<SourceId, List<FeedSection>>.unmodifiable(_tail);

  /// Every row in source order, for a flat list view.
  List<ContentSummary> get allItems => <ContentSummary>[
    for (final sections in _tail.values)
      for (final section in sections) ...section.items,
  ];

  int get pagesTaken => _pages;

  /// Whether one more `next()` is allowed before the gesture bound bites.
  bool get canAdvance => _gesturePages < maxPagesPerRun;

  /// Pulls the head: clears every cursor, then asks page one of every source.
  Future<FeedPage> refresh({CancellationToken? cancellation}) async {
    cursors.reset();
    _tail = <SourceId, List<FeedSection>>{};
    _pages = 0;
    _gesturePages = 0;
    return _run(PageRequest(page: 1, pageSize: pageSize), cancellation: cancellation);
  }

  /// Asks each source that can continue for its next page. A source with nothing to say is left where it is.
  Future<FeedPage> next({CancellationToken? cancellation}) async {
    final wanted = <SourceId, PageRequest>{};
    final blocked = <FeedContinuation>[];
    for (final entries in _tail.entries) {
      final last = entries.value.isEmpty ? null : entries.value.last;
      if (last == null) {
        blocked.add(FeedContinuation.blocked(entries.key, FeedContinuationReason.notPaged));
        continue;
      }
      final continuation = continuationFor(last);
      if (!continuation.canContinue) {
        blocked.add(continuation);
        continue;
      }
      wanted[entries.key] = continuation.request!;
    }
    if (wanted.isEmpty || !canAdvance) {
      // `maxPagesPerRun` guards one gesture, and the counter resets on refresh, so a user who scrolls deep is
      // not punished for the pages they already asked for while the bound still stops a runaway loop.
      return FeedPage(
        sections: const <FeedSection>[],
        skips: const <FeedSkip>[],
        blocked: List<FeedContinuation>.unmodifiable(blocked),
        page: _pages,
      );
    }
    final result = await aggregator.feed(
      PageRequest(page: _pages + 1, pageSize: pageSize),
      cursors: Map<SourceId, String>.fromEntries(
        wanted.entries
            .where((entry) => cursors.tokens.containsKey(entry.key))
            .map((entry) => MapEntry<SourceId, String>(entry.key, cursors.tokens[entry.key]!)),
      ),
      cancellation: cancellation,
    );
    return _absorb(result, blocked: blocked, requested: wanted.keys.toSet());
  }

  Future<FeedPage> _run(PageRequest page, {CancellationToken? cancellation}) async {
    final result = await aggregator.feed(page, cursors: cursors.tokens, cancellation: cancellation);
    return _absorb(result, blocked: const <FeedContinuation>[], requested: null);
  }

  FeedPage _absorb(FeedResult result, {required List<FeedContinuation> blocked, required Set<SourceId>? requested}) {
    _pages++;
    _gesturePages++;
    for (final section in result.sections) {
      cursors.observe(section);
      _tail.putIfAbsent(section.sourceId, () => <FeedSection>[]).add(section);
    }
    if (requested != null) {
      // A source that was asked and answered nothing at all is done, not failed; keeping its old tail would
      // let a later `next()` ask it again on the strength of a page it never returned.
      for (final sourceId in requested.difference(<SourceId>{for (final s in result.sections) s.sourceId})) {
        final tail = _tail[sourceId];
        if (tail != null && tail.isNotEmpty) {
          tail[tail.length - 1] = _closeOff(tail.last);
        }
      }
    }
    return FeedPage(
      sections: List<FeedSection>.unmodifiable(result.sections),
      skips: List<FeedSkip>.unmodifiable(result.skips),
      blocked: List<FeedContinuation>.unmodifiable(blocked),
      page: _pages,
    );
  }

  /// A section with `hasMore` cleared, so a continuation will not be offered for a source that stopped answering.
  static FeedSection _closeOff(FeedSection section) => FeedSection(
    sourceId: section.sourceId,
    items: section.items,
    page: section.page,
    mode: section.mode,
    nextCursor: null,
    hasMore: false,
    contractViolation: section.contractViolation,
    duplicateItems: section.duplicateItems,
    foreignItems: section.foreignItems,
  );
}
