// Module: lib/src/domain/search_controller.dart
// Purpose: Run one search at a time and let only the newest generation reach the caller.
// Author: liuchuancong
// Created: 2026-10-10
//
// A search field fires on every pause between keystrokes, so "har" and "harry" are both in flight at once
// and whichever source answers last wins the screen - the user sees the results for a query they already
// finished typing. The aggregator cannot fix this: it is asked for one query and answers it honestly. So the
// fence lives here, in the layer that knows a newer keystroke arrived.
//
// The fence is a generation counter, not a cancelled http call. The service's own documentation is explicit
// that a request it already dispatched is not this layer's to abort, and pretending otherwise would report a
// cancellation that never happened. What this does guarantee is narrower and testable: a superseded answer
// is dropped, is never rendered, and never enters history.

import 'package:pure_live_platform/pure_live_platform.dart';
import 'package:pure_live_search/pure_live_search.dart';
import 'package:pure_live_utils/pure_live_utils.dart';

import 'search_history.dart';
import 'search_result_order.dart';
import 'search_term.dart';

/// What a run produced, in one of the three ways it can end.
sealed class SearchOutcome {
  const SearchOutcome();
}

/// The newest generation's answer, already ranked.
final class SearchAnswer extends SearchOutcome {
  const SearchAnswer({required this.term, required this.aggregate, required this.ranked});

  final SearchTerm term;
  final SearchAggregate aggregate;
  final List<RankedResult> ranked;

  /// The usable items to render, in order, with duplicates removed.
  List<ContentSummary> get visibleItems => <ContentSummary>[
    for (final result in ranked)
      if (result.isShowing) result.item,
  ];
}

/// The keyword folded to nothing, so no request was made and no source is to blame.
final class SearchRejected extends SearchOutcome {
  const SearchRejected(this.reason);

  final String reason;
}

/// An answer existed but a newer run had started, so this one was thrown away on purpose.
final class SearchSuperseded extends SearchOutcome {
  const SearchSuperseded(this.term);

  final SearchTerm term;
}

/// Runs queries through one aggregator, fenced to the newest generation.
final class SearchController {
  SearchController({required SearchAggregator aggregator, this.history}) : _aggregator = aggregator;

  final SearchAggregator _aggregator;

  /// Where used keywords are recorded. Absent means the app has decided it does not keep history at all -
  /// a per-account or incursive build - which is a legitimate choice rather than a missing dependency.
  final SearchHistoryRepository? history;

  final CancellationToken _idleToken = CancellationToken();
  int _generation = 0;
  CancellationToken? _activeToken;

  /// True while a run is waiting on the aggregator.
  bool get isRunning => _activeToken != null;

  /// The token that fires when a run is *abandoned* - superseded or cancelled.
  ///
  /// A completed run never fires it: success is not the event a listener on this token is waiting for, and
  /// folding both into one signal is how a spinner ends up stuck. While idle this is a token that can never
  /// cancel, so a widget can subscribe without a null check.
  CancellationToken get currentToken => _activeToken ?? _idleToken;

  /// Runs [keyword] and returns the outcome for the generation that ends up owning the screen.
  ///
  /// Starting a run abandons the previous one: the request it dispatched keeps going at the service layer,
  /// but nothing its answer arrives into is still listening.
  Future<SearchOutcome> run(String keyword, {Iterable<SourceId>? onlySources}) async {
    final term = SearchTerm.tryParse(keyword);
    if (term == null) {
      // Refuse before the fan-out: blank over N sources is N pointless requests.
      return const SearchRejected('keyword is blank');
    }

    _activeToken?.cancel();
    final generation = ++_generation;
    _activeToken = CancellationToken();

    final aggregate = await _aggregator.search(SearchQuery(keyword: term.display), onlySources: onlySources);

    if (generation != _generation) {
      // A newer run started while this one was in the air; its answer is the caller's now. The token was
      // already cancelled when that run began, so listeners have been told.
      return SearchSuperseded(term);
    }
    _activeToken = null;

    // Ranking is part of the answer, not a UI detail: two apps rendering the same aggregate have to agree
    // on which tile is first without both re-implementing the comparator.
    final answer = SearchAnswer(term: term, aggregate: aggregate, ranked: rankSearchResults(term, aggregate));
    await history?.record(term);
    return answer;
  }

  /// Abandons the in-flight run, if any, so its answer is dropped like a superseded one.
  void cancel() {
    final token = _activeToken;
    _activeToken = null;
    // Bumping the generation is what actually drops the answer; the token is how listeners learn it happened.
    _generation++;
    token?.cancel();
  }

  /// Releases the controller; nothing may call [run] afterwards.
  void dispose() => cancel();
}
