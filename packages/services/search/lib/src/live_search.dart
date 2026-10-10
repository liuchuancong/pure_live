// Module: lib/src/live_search.dart
// Purpose: The fan-out that reports as each source answers, paced by a concurrency bound and a health ledger.
// Author: liuchuancong
// Created: 2026-10-11
//
// docs/services/search.md says partial results stay usable and a source that answered nothing is marked
// without blocking the rest. Collecting every provider into one `Future.wait` breaks the first of those: a
// twenty-source search shows an empty screen until the slowest source burns its whole budget, and the user
// reads that as "no results" rather than "still working". The live path therefore streams outcomes, and it
// bounds how many sources are asked at once, because an unbounded fan-out is a small denial-of-service against
// whoever hosts the weakest source.

import 'dart:async';

import 'package:pure_live_capability/pure_live_capability.dart';
import 'package:pure_live_platform/pure_live_platform.dart';
import 'package:pure_live_utils/pure_live_utils.dart';

import 'search_aggregator.dart';

/// How a live run paces itself.
final class SearchFanout {
  const SearchFanout({
    this.maxConcurrent = 6,
    this.perSourceTimeout = const Duration(seconds: 8),
    this.firstAnswerBudget = const Duration(seconds: 3),
  }) : assert(maxConcurrent >= 1, 'a fan-out that asks nobody is not a search');

  /// Sources asked at the same time. Six is a browser's own per-host limit and stays polite to a shared
  /// gateway host; unbounded turns one search into twenty simultaneous requests over a phone's radio.
  final int maxConcurrent;

  /// One source's budget before it is reported as timed out.
  final Duration perSourceTimeout;

  /// How long the UI should be willing to show a spinner with nothing behind it. Past this the run says so.
  final Duration firstAnswerBudget;
}

/// A source's recent health, decided by the ledger rather than remembered by each caller.
enum SourceHealth { healthy, degraded, coolingDown }

/// Remembers timeouts and failures per source for a while.
///
/// A source that timed out three times in a row is going to time out again while the user is still typing, and
/// asking it every keystroke costs a request and a whole concurrency slot. The ledger does not *drop* the
/// source - the run asks it last and reports it as cooling down - because a source the user enabled is theirs
/// to use again once it recovers.
final class SourceHealthLedger {
  SourceHealthLedger({
    Clock? clock,
    this.cooldown = const Duration(seconds: 30),
    this.failuresBeforeCooldown = 3,
    this.sourceLimit = 128,
  }) : _clock = clock ?? systemClock;

  final Clock _clock;
  final Duration cooldown;

  /// Consecutive bad outcomes before a source is marked cooling down.
  final int failuresBeforeCooldown;

  /// Distinct sources tracked; past this the least recently seen is forgotten.
  final int sourceLimit;

  final Map<String, _Record> _records = <String, _Record>{};

  int get trackedSources => _records.length;

  /// Records one outcome for [sourceId]. `empty` is a good answer to a bad query, so it is not a failure.
  void observe(SourceId sourceId, SearchOutcomeKind kind) {
    final bad = kind == SearchOutcomeKind.timedOut || kind == SearchOutcomeKind.failed;
    final key = sourceId;
    final previous = _records[key];
    _records[key] = _Record(
      failures: bad ? (previous?.failures ?? 0) + 1 : 0,
      until: bad ? _clock().add(cooldown) : null,
      seenAt: _clock(),
    );
    while (_records.length > sourceLimit) {
      final stale = _records.entries.toList(growable: false)
        ..sort((left, right) => left.value.seenAt.compareTo(right.value.seenAt));
      _records.remove(stale.first.key);
    }
  }

  SourceHealth healthOf(SourceId sourceId) {
    final record = _records[sourceId];
    if (record == null) {
      return SourceHealth.healthy;
    }
    final until = record.until;
    if (until != null && _clock().isBefore(until) && record.failures >= failuresBeforeCooldown) {
      return SourceHealth.coolingDown;
    }
    return record.failures > 0 ? SourceHealth.degraded : SourceHealth.healthy;
  }

  /// How long [sourceId] still owes before it is worth asking again.
  Duration remainingCooldown(SourceId sourceId) {
    final until = _records[sourceId]?.until;
    if (until == null) {
      return Duration.zero;
    }
    final left = until.difference(_clock());
    return left.isNegative ? Duration.zero : left;
  }

  void forget(SourceId sourceId) => _records.remove(sourceId);

  void clear() => _records.clear();
}

final class _Record {
  const _Record({required this.failures, required this.until, required this.seenAt});

  final int failures;
  final DateTime? until;
  final DateTime seenAt;
}

/// Nothing answered inside the first-answer budget. A distinct value, not a fake outcome: a wait notice names
/// no source and must not be able to look like one that failed.
final class SearchWaitNotice {
  const SearchWaitNotice({required this.sources, required this.waited});

  final int sources;
  final Duration waited;

  @override
  String toString() => 'SearchWaitNotice($sources sources still running, waited=${waited.inMilliseconds}ms)';
}

/// A [SearchAggregator] that reports as sources answer, over the capability registry.
final class LiveSearchAggregator implements SearchAggregator {
  LiveSearchAggregator({required CapabilityRegistry providers, this.fanout = const SearchFanout(), this.health})
    : _providers = providers;

  final CapabilityRegistry _providers;
  final SearchFanout fanout;

  /// Pass the same ledger the feed or the resolver uses and a source that is slow for one is slow for all
  /// three, instead of being re-probed by every surface.
  final SourceHealthLedger? health;

  /// The collected form: the same run, awaited. Blank keywords are refused here rather than thrown, matching
  /// the port's contract that a refusal is a report with a reason.
  @override
  Future<SearchAggregate> search(
    SearchQuery query, {
    Iterable<SourceId>? onlySources,
    CancellationToken? cancellation,
  }) async {
    if (query.keyword.trim().isEmpty) {
      return SearchAggregate(query: query, outcomes: const <SearchProviderOutcome>[], refused: 'keyword is blank');
    }
    final outcomes = <SearchProviderOutcome>[];
    await for (final outcome in stream(query, onlySources: onlySources)) {
      outcomes.add(outcome);
    }
    return SearchAggregate(query: query, outcomes: List<SearchProviderOutcome>.unmodifiable(outcomes));
  }

  /// Outcomes as their sources answer. Single subscription: cancelling it stops the pump, so a search box that
  /// moved on does not keep twenty timers running behind it.
  Stream<SearchProviderOutcome> stream(
    SearchQuery query, {
    Iterable<SourceId>? onlySources,
    CancellationToken? cancellation,
  }) {
    final selected = selectSearchTargets(providers: _providers, onlySources: onlySources);
    final ledger = health;
    // Cooling-down sources are asked last: when they answer at all they answer late, and a run that starts
    // with them spends its first-answer budget on the one source it already knows is slow.
    final fresh = <(SourceId, SearchCapability)>[];
    final cooling = <(SourceId, SearchCapability)>[];
    for (final target in selected.targets) {
      if (ledger != null && ledger.healthOf(target.$1) == SourceHealth.coolingDown) {
        cooling.add(target);
      } else {
        fresh.add(target);
      }
    }
    final ordered = <(SourceId, SearchCapability)>[...fresh, ...cooling];

    final out = StreamController<SearchProviderOutcome>();
    var running = 0;
    var index = 0;
    var finished = false;

    void finish() {
      if (finished) {
        return;
      }
      finished = true;
      for (final outcome in selected.unsearchable) {
        out.add(outcome);
      }
      out.close();
    }

    void pump() {
      if (out.isClosed || cancellation != null && cancellation.isCancelled) {
        return;
      }
      while (running < fanout.maxConcurrent && index < ordered.length) {
        final target = ordered[index++];
        running++;
        askSearchSource(target.$1, target.$2, query, timeout: fanout.perSourceTimeout).then((outcome) {
          running--;
          ledger?.observe(outcome.sourceId, outcome.kind);
          if (!out.isClosed) {
            out.add(outcome);
          }
          if (running == 0 && index >= ordered.length) {
            finish();
          } else {
            pump();
          }
        });
      }
      if (running == 0 && index >= ordered.length) {
        finish();
      }
    }

    out.onListen = pump;
    out.onCancel = () {
      finished = true;
      return Future<void>.value();
    };
    return out.stream;
  }

  /// The first thing worth showing: the first answered outcome, or a wait notice once the budget burns.
  ///
  /// Both answers are correct - the notice does not end the run, the stream keeps going underneath - which is
  /// why this returns a value instead of throwing on the slow path. A spinner with no explanation is what the
  /// user sees when the only honest answer was suppressed to keep the signature a `Future<SearchProviderOutcome?>`.
  Future<Object?> firstAnswer(SearchQuery query, {Iterable<SourceId>? onlySources, Duration? budget}) async {
    final wait = budget ?? fanout.firstAnswerBudget;
    final outcomes = stream(query, onlySources: onlySources);
    final completer = Completer<Object?>();
    late final StreamSubscription<SearchProviderOutcome> subscription;
    final timer = Timer(wait, () {
      if (!completer.isCompleted) {
        completer.complete(SearchWaitNotice(sources: _sourceCount(onlySources), waited: wait));
      }
    });
    subscription = outcomes.listen(
      (outcome) {
        if (!completer.isCompleted && outcome.isUsable) {
          completer.complete(outcome);
        }
      },
      onError: (Object error, StackTrace stackTrace) {
        if (!completer.isCompleted) {
          completer.completeError(error, stackTrace);
        }
      },
      onDone: () {
        if (!completer.isCompleted) {
          timer.cancel();
          completer.complete(null);
        }
      },
    );
    try {
      return await completer.future;
    } finally {
      timer.cancel();
      await subscription.cancel();
    }
  }

  /// The next page from one source, keeping the query's keyword, kind and filters.
  Future<SearchProviderOutcome?> more(
    SearchProviderOutcome previous, {
    required SearchQuery query,
    SourceId? sourceId,
  }) async {
    final request = continuationFor(previous).request;
    if (request == null) {
      return null;
    }
    final target = sourceId ?? previous.sourceId;
    final capability = _searchCapabilityFor(target);
    if (capability == null) {
      return null;
    }
    final outcome = await askSearchSource(
      target,
      capability,
      SearchQuery(keyword: query.keyword, page: request, kind: query.kind, filters: query.filters),
      timeout: fanout.perSourceTimeout,
    );
    health?.observe(outcome.sourceId, outcome.kind);
    return outcome;
  }

  SearchCapability? _searchCapabilityFor(SourceId sourceId) {
    for (final entry in _providers.providersFor(CapabilityKind.search)) {
      if (entry.sourceId == sourceId && entry.provider is SearchCapability) {
        return entry.provider as SearchCapability;
      }
    }
    return null;
  }

  /// How many sources this run would ask, for a wait notice that says what it is waiting on.
  int _sourceCount(Iterable<SourceId>? onlySources) {
    return selectSearchTargets(providers: _providers, onlySources: onlySources).targets.length;
  }
}
