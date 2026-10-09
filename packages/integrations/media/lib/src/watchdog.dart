// Module: lib/src/watchdog.dart
// Purpose: The platform-side playback watchdog: ticket expiry, prefetch, and the stall the kernel cannot see.
// Author: liuchuancong
// Created: 2026-10-09
//
// Spec: docs/media/watchdog.md. Two of its five rows are the platform's to notice, and media_core says so
// itself: kernel/player_handle_recovery.dart leaves "a stream that stops moving later" to the position-stall
// watchdog, and a ticket's expiry is knowledge the kernel never has - it is handed a url, not a TTL. The
// other rows (frame heartbeat, adapter errors) already live in the kernel, so they are not re-detected here
// (docs/adr/0020-media-core-owns-recovery.md).
//
// The watchdog only *initiates*. It never runs a recovery ladder itself: a stall becomes a
// RecoveryFailure handed to PlayerHandle.reportFailure with the watchdog as its source, and the kernel
// decides whether and how to recover.

import 'package:media_core/media_core.dart' as core;
import 'package:pure_live_platform/pure_live_platform.dart' as platform;

/// What the host reports about one moment of playback.
enum PlaybackPhase {
  /// Nothing opened yet.
  idle,

  /// Opened, waiting for the first frame.
  preparing,

  /// Frames are advancing.
  playing,

  /// Playing was requested and progress has stopped while the buffer fills.
  buffering,

  /// The user paused. A stalled clock the user caused is not a fault.
  paused,

  /// The stream finished.
  ended,
}

/// One observation of the player, taken by whoever owns it.
final class PlaybackSample {
  const PlaybackSample({required this.at, required this.phase, required this.position});

  final DateTime at;
  final PlaybackPhase phase;

  /// Playback clock. Compared across samples to tell progress from a stuck stream.
  final Duration position;

  bool get isLiveProgress => phase == PlaybackPhase.playing;
}

/// How long the watchdog waits before it acts.
///
/// The defaults are docs/media/watchdog.md's: a 45 second prefetch lead ("T-45s") and generous stall windows,
/// because a stall that resolves itself is normal on a TV network and a watchdog that fires on all of them
/// turns one bad second into a line switch.
final class WatchdogThresholds {
  const WatchdogThresholds({
    this.startTimeout = const Duration(seconds: 20),
    this.stallTimeout = const Duration(seconds: 15),
    this.prefetchLead = const Duration(seconds: 45),
  });

  /// How long `preparing` may last before the start is treated as failed.
  final Duration startTimeout;

  /// How long a non-advancing clock may last before it counts as a stall.
  final Duration stallTimeout;

  /// How far before `expiresAt` a replacement ticket is requested.
  final Duration prefetchLead;
}

/// What the watchdog decided to do about one observation.
enum WatchdogAction {
  nothing,

  /// Ask for a replacement ticket early, while the current one still works.
  prefetchTicket,

  /// The ticket is already past its expiry: refresh before anything else.
  refreshTicket,

  /// Hand a stall to the kernel's ladder.
  reportStall,

  /// Hand a failed start to the kernel's ladder.
  reportStartTimeout,
}

/// A decision plus the reason the watchdog will log with it.
final class WatchdogDecision {
  const WatchdogDecision({required this.action, required this.detail, this.since});

  final WatchdogAction action;
  final String detail;

  /// When the condition being reported began, when there is a "since" to name.
  final DateTime? since;

  bool get acts => action != WatchdogAction.nothing;

  @override
  String toString() => 'WatchdogDecision(${action.name}: $detail)';
}

/// Decides what one observation means. Pure: no clock, no kernel, no side effects.
///
/// [preparingSince] is when the current `preparing` window started; pass it once and keep it while the phase
/// stays preparing, because "no first frame for 20s" is measured from the attempt, not from the sample.
WatchdogDecision decidePlaybackHealth({
  required PlaybackSample sample,
  PlaybackSample? previous,
  platform.MediaTicket? ticket,
  DateTime? preparingSince,
  WatchdogThresholds thresholds = const WatchdogThresholds(),
}) {
  // Expiry outranks everything: a link that has already died cannot be rescued by a stall timer, and
  // docs/media/media-ticket.md is explicit that what refreshes is the ticket, never the session.
  if (ticket != null) {
    final expiry = ticket.expiresAt;
    if (expiry != null) {
      final at = sample.at.toUtc();
      if (!at.isBefore(expiry)) {
        return WatchdogDecision(
          action: WatchdogAction.refreshTicket,
          detail: 'ticket ${ticket.id} expired at $expiry',
          since: expiry,
        );
      }
      if (ticket.policy.allowRefresh && at.isAfter(expiry.subtract(thresholds.prefetchLead))) {
        return WatchdogDecision(
          action: WatchdogAction.prefetchTicket,
          detail: 'ticket ${ticket.id} expires at $expiry, within the ${thresholds.prefetchLead.inSeconds}s lead',
          since: expiry,
        );
      }
    }
  }

  if (sample.phase == PlaybackPhase.preparing) {
    final started = preparingSince ?? previous?.at;
    if (started != null && sample.at.difference(started) >= thresholds.startTimeout) {
      return WatchdogDecision(
        action: WatchdogAction.reportStartTimeout,
        detail: 'no first frame within ${thresholds.startTimeout.inSeconds}s',
        since: started,
      );
    }
    return const WatchdogDecision(action: WatchdogAction.nothing, detail: 'still preparing');
  }

  final before = previous;
  if (before == null || !sameClock(before, sample)) {
    return const WatchdogDecision(action: WatchdogAction.nothing, detail: 'progressing');
  }

  // Only a buffering phase turns a frozen clock into a fault. A paused or idle one is the user's
  // intention, which AGENTS.md protects, and `playing` with an unchanged clock has already been
  // reported on the previous sample.
  if (sample.phase == PlaybackPhase.buffering && sample.at.difference(before.at) >= thresholds.stallTimeout) {
    return WatchdogDecision(
      action: WatchdogAction.reportStall,
      detail:
          'position stuck at ${_format(before.position)} for '
          '${sample.at.difference(before.at).inSeconds}s while buffering',
      since: before.at,
    );
  }
  return const WatchdogDecision(action: WatchdogAction.nothing, detail: 'waiting');
}

/// Whether two samples show the same playback clock.
bool sameClock(PlaybackSample a, PlaybackSample b) => a.position == b.position;

/// The watchdog's state across observations, and the actions it takes.
///
/// Detection lives in [decidePlaybackHealth]; this class only remembers what it last saw and carries out what
/// was decided, so the interesting part stays testable without a clock or a player.
///
/// [reportFailure] is the kernel's own entry - pass `handle.reportFailure`. A function rather than a
/// PlayerHandle because PlayerHandle is closed for extension, and because whoever owns the handle also decides
/// where a stall is reported.
final class PlaybackWatchdog {
  PlaybackWatchdog({
    required void Function(core.RecoveryFailure failure) reportFailure,
    this.thresholds = const WatchdogThresholds(),
    Future<void> Function(platform.RefreshReason reason)? onTicketRefresh,
    platform.MediaTicket? ticket,
  }) : _reportToLadder = reportFailure,
       _ticket = ticket,
       _onTicketRefresh = onTicketRefresh;

  final void Function(core.RecoveryFailure failure) _reportToLadder;
  final Future<void> Function(platform.RefreshReason reason)? _onTicketRefresh;

  platform.MediaTicket? _ticket;
  WatchdogThresholds thresholds;

  PlaybackSample? _last;
  DateTime? _preparingSince;
  WatchdogAction _lastAction = WatchdogAction.nothing;
  bool _refreshInFlight = false;

  platform.MediaTicket? get ticket => _ticket;

  /// The ticket the host resolved most recently. Replacing it is how a refresh reaches the next decision.
  set ticket(platform.MediaTicket? value) {
    _ticket = value;
  }

  /// The action the last observation produced, so a host can tell a repeat from a new fault.
  WatchdogAction get lastAction => _lastAction;

  /// Feeds one observation and performs whatever it implies.
  Future<WatchdogDecision> observe(PlaybackSample sample) async {
    final decision = decidePlaybackHealth(
      sample: sample,
      previous: _last,
      ticket: _ticket,
      preparingSince: _preparingSince,
      thresholds: thresholds,
    );
    _last = sample;
    _preparingSince = sample.phase == PlaybackPhase.preparing ? (_preparingSince ?? sample.at) : null;
    _lastAction = decision.action;

    final action = decision.action;
    if (action == WatchdogAction.reportStall) {
      _reportFailure(core.PlayerErrorCode.timeout, decision.detail);
    } else if (action == WatchdogAction.reportStartTimeout) {
      _reportFailure(core.PlayerErrorCode.timeout, 'start: ${decision.detail}');
    } else if (action == WatchdogAction.prefetchTicket) {
      await _refresh(platform.RefreshReason.expiring);
    } else if (action == WatchdogAction.refreshTicket) {
      await _refresh(platform.RefreshReason.expired);
    }
    return decision;
  }

  /// Forgets the previous sample, for a host that restarted playback or switched source.
  void reset() {
    _last = null;
    _preparingSince = null;
    _lastAction = WatchdogAction.nothing;
  }

  void _reportFailure(core.PlayerErrorCode code, String message) {
    _reportToLadder(
      core.RecoveryFailure(
        code: code,
        message: message,
        source: core.RecoveryFailureSource.watchdog,
        reason: const core.RecoveryReasonTimeout(),
      ),
    );
  }

  Future<void> _refresh(platform.RefreshReason reason) async {
    final callback = _onTicketRefresh;
    if (callback == null || _refreshInFlight) {
      return;
    }
    // One request at a time: a host that takes 30s to re-resolve must not get a request per sample, or the
    // watchdog becomes the reason playback never catches up.
    _refreshInFlight = true;
    try {
      await callback(reason);
    } finally {
      _refreshInFlight = false;
    }
  }
}

/// mm:ss, so a watchdog line reads like the clock a viewer saw rather than like microseconds.
String _format(Duration value) => '${value.inMinutes}:${(value.inSeconds % 60).toString().padLeft(2, '0')}';
