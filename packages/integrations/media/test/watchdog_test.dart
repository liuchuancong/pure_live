// Module: test/watchdog_test.dart
// Purpose: Verify the platform watchdog's decisions and that its actions reach the kernel ladder.
// Author: liuchuancong
// Created: 2026-10-09
//
// The decision table is docs/media/watchdog.md section 1, restricted to the rows the platform can actually
// observe: ticket expiry (the kernel is handed a url, not a TTL) and a clock that stopped moving (which
// kernel/player_handle_recovery.dart explicitly leaves to the host's position-stall watchdog).
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:media_core/media_core.dart' as core;
import 'package:media_core/testing/library.dart' as doubles;
import 'package:pure_live_media/pure_live_media.dart';
import 'package:pure_live_platform/pure_live_platform.dart' as platform;

import 'support/fake_engine.dart';

final DateTime _t0 = DateTime.utc(2026, 10, 9, 12);

platform.MediaTicket _ticket({Duration? lifetime, bool allowRefresh = true, platform.MediaTicketRefreshInfo? refresh}) {
  return platform.MediaTicket(
    id: 'ticket-1',
    uri: Uri.parse('https://example.test/master.m3u8'),
    kind: platform.MediaKind.live,
    protocol: platform.MediaProtocol.hls,
    createdAt: _t0,
    expiresAt: lifetime == null ? null : _t0.add(lifetime),
    policy: platform.MediaTicketPolicy(allowRefresh: allowRefresh),
    refresh: refresh,
    metadata: const platform.MediaPlaybackMetadata(isLive: true),
  );
}

PlaybackSample _sample({
  required DateTime at,
  PlaybackPhase phase = PlaybackPhase.playing,
  Duration position = Duration.zero,
}) {
  return PlaybackSample(at: at, phase: phase, position: position);
}

const Duration _lead = Duration(seconds: 45);

/// The thresholds this suite uses; spelled out so the timings in the tests are not tied to a default.
const WatchdogThresholds _thresholds = WatchdogThresholds(
  startTimeout: Duration(seconds: 20),
  stallTimeout: Duration(seconds: 15),
  prefetchLead: _lead,
);

void main() {
  group('ticket expiry', () {
    test('test_decide_pastExpiry_asksForARefresh', () {
      final decision = decidePlaybackHealth(
        sample: _sample(at: _t0.add(const Duration(minutes: 10))),
        ticket: _ticket(lifetime: const Duration(minutes: 5)),
        thresholds: _thresholds,
      );

      expect(decision.action, WatchdogAction.refreshTicket);
      expect(decision.detail, contains('expired'));
    });

    test('test_decide_insideTheLead_asksForAReplacementEarly', () {
      // 30 seconds of ticket left against a 45 second lead: this is the window the host prefetches in.
      final decision = decidePlaybackHealth(
        sample: _sample(at: _t0.add(const Duration(minutes: 4, seconds: 30))),
        ticket: _ticket(lifetime: const Duration(minutes: 5)),
        thresholds: _thresholds,
      );

      expect(decision.action, WatchdogAction.prefetchTicket);
      expect(decision.detail, contains('45s'));
    });

    test('test_decide_outsideTheLead_doesNothing', () {
      // 60 seconds left is beyond the lead: asking now would only ask again sooner.
      final decision = decidePlaybackHealth(
        sample: _sample(at: _t0.add(const Duration(minutes: 4))),
        ticket: _ticket(lifetime: const Duration(minutes: 30)),
        thresholds: _thresholds,
      );

      expect(decision.action, WatchdogAction.nothing);
    });

    test('test_decide_ticketWithoutExpiry_isNotGuessedAt', () {
      // A protocol that never said a TTL has no lead to prefetch on; pretending otherwise would refresh
      // forever on a static stream.
      final decision = decidePlaybackHealth(
        sample: _sample(at: _t0.add(const Duration(hours: 3))),
        ticket: _ticket(),
        thresholds: _thresholds,
      );

      expect(decision.action, WatchdogAction.nothing);
    });

    test('test_decide_sourceThatCannotBeReplaced_isLeftAlone', () {
      // policy.allowRefresh says the platform may try; the source saying "one-shot url" says there is
      // nothing to try. The source's no wins, because a doomed re-resolve still costs a resolve.
      final withAdvice = _ticket(lifetime: const Duration(minutes: 5));
      final decided = decidePlaybackHealth(
        sample: _sample(at: _t0.add(const Duration(minutes: 4, seconds: 30))),
        ticket: platform.MediaTicket(
          id: withAdvice.id,
          uri: withAdvice.uri,
          kind: withAdvice.kind,
          protocol: withAdvice.protocol,
          createdAt: withAdvice.createdAt,
          expiresAt: withAdvice.expiresAt,
          refresh: const platform.MediaTicketRefreshInfo(supported: false),
        ),
        thresholds: _thresholds,
      );

      expect(decided.action, WatchdogAction.nothing);
      expect(decided.detail, contains('cannot be replaced'));
    });

    test('test_decide_advisedLeadBeatsTheGlobalOne', () {
      // The source advises 5 minutes of lead on a 30 minute ticket: that is the only reason this sample
      // (25 minutes in) is inside a window at all - the global 45s lead would still be far away.
      final decision = decidePlaybackHealth(
        sample: _sample(at: _t0.add(const Duration(minutes: 25))),
        ticket: _ticket(
          lifetime: const Duration(minutes: 30),
          refresh: const platform.MediaTicketRefreshInfo(refreshBefore: Duration(minutes: 5)),
        ),
        thresholds: _thresholds,
      );

      expect(decision.action, WatchdogAction.prefetchTicket);
    });

    test('test_decide_refreshForbiddenByPolicy_isLeftAlone', () {
      final decision = decidePlaybackHealth(
        sample: _sample(at: _t0.add(const Duration(minutes: 4))),
        ticket: _ticket(lifetime: const Duration(minutes: 5), allowRefresh: false),
        thresholds: _thresholds,
      );

      expect(decision.action, WatchdogAction.nothing);
    });

    test('test_decide_expiryOutranksAStall', () {
      // Both conditions are true here; the dead link has to be the one acted on first.
      final previous = _sample(
        at: _t0.add(const Duration(minutes: 9)),
        phase: PlaybackPhase.buffering,
        position: const Duration(seconds: 30),
      );
      final decision = decidePlaybackHealth(
        sample: _sample(
          at: _t0.add(const Duration(minutes: 10)),
          phase: PlaybackPhase.buffering,
          position: const Duration(seconds: 30),
        ),
        previous: previous,
        ticket: _ticket(lifetime: const Duration(minutes: 5)),
        thresholds: _thresholds,
      );

      expect(decision.action, WatchdogAction.refreshTicket);
    });
  });

  group('stall and start', () {
    test('test_decide_frozenClockWhileBuffers_reportsStall', () {
      final first = _sample(at: _t0, phase: PlaybackPhase.buffering, position: const Duration(seconds: 42));
      final later = _sample(
        at: _t0.add(const Duration(seconds: 20)),
        phase: PlaybackPhase.buffering,
        position: const Duration(seconds: 42),
      );

      final decision = decidePlaybackHealth(sample: later, previous: first, thresholds: _thresholds);

      expect(decision.action, WatchdogAction.reportStall);
      expect(decision.detail, contains('0:42'));
      expect(decision.since, first.at);
    });

    test('test_decide_stallShorterThanTheWindow_waits', () {
      final first = _sample(at: _t0, phase: PlaybackPhase.buffering, position: const Duration(seconds: 42));
      final later = _sample(
        at: _t0.add(const Duration(seconds: 5)),
        phase: PlaybackPhase.buffering,
        position: const Duration(seconds: 42),
      );

      expect(
        decidePlaybackHealth(sample: later, previous: first, thresholds: _thresholds).action,
        WatchdogAction.nothing,
      );
    });

    test('test_decide_clockAdvancing_isHealthy', () {
      final first = _sample(at: _t0, position: const Duration(seconds: 10));
      final later = _sample(at: _t0.add(const Duration(seconds: 30)), position: const Duration(seconds: 40));

      expect(
        decidePlaybackHealth(sample: later, previous: first, thresholds: _thresholds).action,
        WatchdogAction.nothing,
      );
    });

    test('test_decide_pausedWithFrozenClock_isTheUserNotAFault', () {
      // AGENTS.md: user pause intent is preserved, and a watchdog that "rescues" a pause is the bug that
      // resumes playback behind the viewer.
      final first = _sample(at: _t0, phase: PlaybackPhase.paused, position: const Duration(seconds: 42));
      final later = _sample(
        at: _t0.add(const Duration(minutes: 2)),
        phase: PlaybackPhase.paused,
        position: const Duration(seconds: 42),
      );

      expect(
        decidePlaybackHealth(sample: later, previous: first, thresholds: _thresholds).action,
        WatchdogAction.nothing,
      );
    });

    test('test_decide_preparingPastTheStartTimeout_reportsIt', () {
      final decision = decidePlaybackHealth(
        sample: _sample(at: _t0.add(const Duration(seconds: 25)), phase: PlaybackPhase.preparing),
        preparingSince: _t0,
        thresholds: _thresholds,
      );

      expect(decision.action, WatchdogAction.reportStartTimeout);
      expect(decision.detail, contains('first frame'));
    });

    test('test_decide_preparingInsideTheWindow_isNotYetAFault', () {
      expect(
        decidePlaybackHealth(
          sample: _sample(at: _t0.add(const Duration(seconds: 5)), phase: PlaybackPhase.preparing),
          preparingSince: _t0,
          thresholds: _thresholds,
        ).action,
        WatchdogAction.nothing,
      );
    });
  });

  group('actions', () {
    test('test_observe_expiry_requestsARefreshAndReportsTheReason', () async {
      final requests = <platform.RefreshReason>[];
      final watchdog = PlaybackWatchdog(
        reportFailure: _noReporting,
        thresholds: _thresholds,
        ticket: _ticket(lifetime: const Duration(minutes: 5)),
        onTicketRefresh: (reason) async => requests.add(reason),
      );

      await watchdog.observe(_sample(at: _t0.add(const Duration(minutes: 10))));

      expect(requests, <platform.RefreshReason>[platform.RefreshReason.expired]);
      expect(watchdog.lastAction, WatchdogAction.refreshTicket);
    });

    test('test_observe_prefetchLead_reportsExpiring', () async {
      final requests = <platform.RefreshReason>[];
      final watchdog = PlaybackWatchdog(
        reportFailure: _noReporting,
        thresholds: _thresholds,
        ticket: _ticket(lifetime: const Duration(minutes: 5)),
        onTicketRefresh: (reason) async => requests.add(reason),
      );

      await watchdog.observe(_sample(at: _t0.add(const Duration(minutes: 4, seconds: 30))));

      expect(requests, <platform.RefreshReason>[platform.RefreshReason.expiring]);
    });

    test('test_observe_doesNotStackRefreshRequests', () async {
      // A slow re-resolve must not turn one expiry into one request per sample.
      final gate = Completer<void>();
      var calls = 0;
      final watchdog = PlaybackWatchdog(
        reportFailure: _noReporting,
        thresholds: _thresholds,
        ticket: _ticket(lifetime: const Duration(minutes: 5)),
        onTicketRefresh: (reason) async {
          calls++;
          await gate.future;
        },
      );

      final first = watchdog.observe(_sample(at: _t0.add(const Duration(minutes: 10))));
      await Future<void>.delayed(Duration.zero);
      final second = watchdog.observe(_sample(at: _t0.add(const Duration(minutes: 10, seconds: 2))));
      gate.complete();
      await Future.wait(<Future<WatchdogDecision>>[first, second]);

      expect(calls, 1);
    });

    test('test_observe_stall_reachesTheKernelLadderAsAWatchdogFailure', () async {
      final created = <doubles.FakePlayerAdapter>[];
      final kernel = fakeEngineKernel(created: created);
      final handle = await kernel.createFromMedia(toCoreSource(_ticket()), preferredBackend: 'fake');
      final watchdog = PlaybackWatchdog(
        reportFailure: handle.reportFailure,
        thresholds: _thresholds,
        ticket: _ticket(),
      );

      final decision = await watchdog.observe(
        _sample(at: _t0, phase: PlaybackPhase.buffering, position: const Duration(seconds: 42)),
      );
      await watchdog.observe(
        _sample(
          at: _t0.add(const Duration(seconds: 20)),
          phase: PlaybackPhase.buffering,
          position: const Duration(seconds: 42),
        ),
      );

      expect(decision.action, WatchdogAction.nothing, reason: 'the first sample has nothing to compare to');
      expect(handle.recoveryFailure, isNotNull, reason: 'the ladder received the stall the watchdog inferred');
      expect(handle.recoveryFailure!.source, core.RecoveryFailureSource.watchdog);
      expect(handle.recoveryFailure!.message, contains('0:42'));

      await handle.dispose();
      await kernel.dispose();
    });

    test('test_reset_forgetsTheStalledClockAndThePreparingWindow', () async {
      final watchdog = PlaybackWatchdog(reportFailure: _noReporting, thresholds: _thresholds);

      await watchdog.observe(_sample(at: _t0, phase: PlaybackPhase.preparing));
      watchdog.reset();
      final decision = await watchdog.observe(
        _sample(at: _t0.add(const Duration(seconds: 30)), phase: PlaybackPhase.preparing),
      );

      expect(decision.action, WatchdogAction.nothing);
      expect(watchdog.lastAction, WatchdogAction.nothing);
    });
  });
}

/// The refresh-path tests must not reach the ladder at all: a stall there would be the bug, so reporting is
/// absent rather than stubbed with something permissive.
void _noReporting(core.RecoveryFailure failure) => fail('watchdog reported "${failure.message}" to the ladder');
