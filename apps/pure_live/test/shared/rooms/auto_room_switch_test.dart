import 'dart:async' show TimeoutException, Timer;

import 'package:flutter_test/flutter_test.dart';
import 'package:live_sites/live_sites.dart'
    show
        LiveRestriction,
        LiveRoom,
        LiveRoomRefIdentity,
        LiveSiteAuthenticationError,
        LiveSiteContentUnavailable,
        LiveSiteNetworkError,
        LiveSiteNotFound,
        LiveSiteParseError,
        LiveStatus,
        RoomBroadcast;
import 'package:media_core/media_core.dart' show PlayerCoreState, PlayerFailure;
import 'package:pure_live/shared/rooms/auto_room_switch.dart';

/// A recorded timer: the scheduler's waits fire by hand, so a test says
/// "twenty seconds passed" instead of waiting for one.
final class _FakeTimer implements Timer {
  _FakeTimer(this.duration, this._callback);
  final Duration duration;
  final void Function() _callback;
  bool _cancelled = false;

  @override
  bool get isActive => !_cancelled;

  @override
  void cancel() => _cancelled = true;

  @override
  int get tick => 0;
}

/// The timer factory the tests hand the scheduler, plus the waits to fire.
final class _Timers {
  final List<_FakeTimer> _pending = [];

  Timer create(Duration duration, void Function() callback) {
    final timer = _FakeTimer(duration, callback);
    _pending.add(timer);
    return timer;
  }

  /// Whether a wait of exactly [duration] is scheduled and still live.
  bool scheduled(Duration duration) => _pending.any((timer) => timer.isActive && timer.duration == duration);

  /// Fires every live wait of exactly [duration]; each fired wait leaves the
  /// list before its callback runs, so a callback may schedule the same wait.
  void fire(Duration duration) {
    final due = [
      for (final timer in _pending)
        if (timer.isActive && timer.duration == duration) timer,
    ];
    for (final timer in due) {
      _pending.remove(timer);
      timer._callback();
    }
  }
}

/// One scheduler with its seams recorded: the follows it reads, the details
/// its lookups answer, and every switch, refresh and exhaustion.
final class _Harness {
  final timers = _Timers();

  /// Whether the viewer's switch is on (the settings toggle).
  bool enabled = true;

  /// Whether the owning page still wants switches.
  bool maySwitch = true;

  /// The followed rooms, in storage order.
  List<LiveRoom> follows = [];

  /// The fresh detail each lookup answers, by the candidate's identity;
  /// a missing entry answers null (the ask found nothing usable).
  final Map<String, LiveRoom> details = {};

  /// The rooms removed from the follows after the list was read.
  final Set<String> unfollowed = {};

  final List<LiveRoom> switched = [];
  final List<String> lookedUp = [];
  int refreshes = 0;
  int exhaustedCount = 0;

  /// Whether the round first re-reads the current room (the room page's
  /// refresh seam); the plain harness walks the candidates directly.
  bool refreshesFirst = false;

  late final AutoRoomSwitch switcher = AutoRoomSwitch(
    enabled: () => enabled,
    followsOf: () => follows,
    isFollowed: (candidate) =>
        !unfollowed.contains(candidate.ref.identityKey) &&
        follows.any((room) => room.ref.identityKey == candidate.ref.identityKey),
    lookupRoom: (candidate) async {
      // The harness seeds and reads by the room's own platform id; the
      // platform is constant across every harness test.
      lookedUp.add(candidate.ref.roomId);
      return details[candidate.ref.roomId];
    },
    onSwitch: switched.add,
    maySwitch: () => maySwitch,
    onRefresh: refreshesFirst
        ? () async {
            refreshes++;
          }
        : null,
    onExhausted: () => exhaustedCount++,
    timer: timers.create,
  );
}

LiveRoom _room(String roomId, {LiveStatus? status, LiveRestriction? restriction}) => LiveRoom.normalized(
  platform: 'test',
  roomId: roomId,
  broadcast: RoomBroadcast.of(liveStatus: status, restriction: restriction),
);

/// Lets the scheduler's awaited lookup answers land before the assertions.
Future<void> _pump() => Future<void>.delayed(Duration.zero);

void main() {
  test('a paused, stopped or network-loss state never switches', () {
    final harness = _Harness()
      ..follows = [_room('1'), _room('2', status: LiveStatus.live)]
      ..details['2'] = _room('2', status: LiveStatus.live);

    // A stop nothing explains — the viewer's lifecycle, the app's background
    // — is theirs, not evidence the room is gone.
    harness.switcher.update(
      room: _room('1'),
      playback: PlayerCoreState.idle.stoppedState(),
      resolving: false,
      unavailable: false,
    );
    expect(harness.timers.scheduled(const Duration(seconds: 1)), isFalse);

    // A viewer's own pause holds the room all the same.
    harness.switcher.update(
      room: _room('1'),
      playback: PlayerCoreState.idle.pausedState(),
      resolving: false,
      unavailable: false,
    );
    expect(harness.timers.scheduled(const Duration(seconds: 1)), isFalse);

    // A room the app cannot classify is not a verdict either.
    harness.switcher.update(
      room: _room('1'),
      playback: PlayerCoreState.idle.playingState(),
      resolving: false,
      unavailable: false,
    );
    expect(harness.timers.scheduled(const Duration(seconds: 1)), isFalse);

    // A network loss keeps its own probing in the playback session; the
    // scheduler must not read it as a broadcast that ended.
    harness.switcher.update(
      room: _room('1'),
      playback: PlayerCoreState.idle.errorState(),
      resolving: false,
      unavailable: false,
      failure: PlayerFailure.network(),
    );
    expect(harness.timers.scheduled(const Duration(seconds: 1)), isFalse);

    // A player error the engine gave up on is worth a switch.
    harness.switcher.update(
      room: _room('1'),
      playback: PlayerCoreState.idle.errorState(),
      resolving: false,
      unavailable: false,
      failure: PlayerFailure.playback(),
    );
    expect(harness.timers.scheduled(const Duration(seconds: 1)), isTrue);
    expect(harness.switched, isEmpty);

    // The switch is opt-in; off means the pending round is cancelled.
    harness
      ..enabled = false
      ..switcher.update(
        room: _room('1', status: LiveStatus.offline),
        playback: PlayerCoreState.idle,
        resolving: false,
        unavailable: true,
      );
    expect(harness.timers.scheduled(const Duration(seconds: 1)), isFalse);
    expect(harness.switched, isEmpty);
  });

  test('an explicitly offline room switches to the next live follow', () async {
    final candidate = _room('2', status: LiveStatus.live);
    final harness = _Harness()
      ..follows = [_room('1', status: LiveStatus.offline), candidate]
      // The platform answers under its own alias id for the same room; the
      // room that opens must still be the followed one.
      ..details['2'] = LiveRoom.normalized(platform: 'test', roomId: '2-alias', broadcast: candidate.broadcast);

    harness.switcher.update(
      room: _room('1', status: LiveStatus.offline),
      playback: PlayerCoreState.idle,
      resolving: false,
      unavailable: false,
    );
    expect(harness.timers.scheduled(const Duration(seconds: 1)), isTrue);

    harness.timers.fire(const Duration(seconds: 1));
    await _pump();
    expect(harness.lookedUp, ['2']);
    expect(harness.switched.single.ref.identityKey, 'test:2');
    expect(harness.exhaustedCount, 0);
  });

  test('a platform-stated site failure switches, an unstated one does not', () {
    final harness = _Harness()
      ..follows = [_room('1', status: LiveStatus.live), _room('2', status: LiveStatus.live)]
      ..details['2'] = _room('2', status: LiveStatus.live);

    // The room is on air and refuses to serve its stream: the platform said.
    harness.switcher.update(
      room: _room('1', status: LiveStatus.live),
      playback: PlayerCoreState.idle,
      resolving: false,
      unavailable: true,
    );
    expect(harness.timers.scheduled(const Duration(seconds: 1)), isTrue);

    // The same room behind an ask that merely failed is nothing to act on —
    // the caller passes `unavailable` only for the stated failures, and the
    // pending round is cancelled the moment the state says so.
    harness.switcher.update(
      room: _room('1', status: LiveStatus.live),
      playback: PlayerCoreState.idle,
      resolving: false,
      unavailable: false,
    );
    expect(harness.timers.scheduled(const Duration(seconds: 1)), isFalse);
    expect(harness.switched, isEmpty);
  });

  test('a candidate needs a fresh live, unrestricted detail', () async {
    final harness = _Harness()
      ..follows = [
        _room('1', status: LiveStatus.offline),
        _room('2', status: LiveStatus.live),
        _room('3', status: LiveStatus.live),
      ]
      // The stored card said live, but the fresh answer says the broadcast
      // ended minutes ago.
      ..details['2'] = _room('2', status: LiveStatus.offline)
      // This one now needs a login the viewer does not have.
      ..details['3'] = _room('3', status: LiveStatus.live, restriction: LiveRestriction.needsLogin);

    harness.switcher.update(
      room: _room('1', status: LiveStatus.offline),
      playback: PlayerCoreState.idle,
      resolving: false,
      unavailable: false,
    );
    harness.timers.fire(const Duration(seconds: 1));
    await _pump();
    expect(harness.lookedUp, ['2', '3']);
    expect(harness.switched, isEmpty);
    expect(harness.exhaustedCount, 1);
  });

  test('an unfollowed candidate is not opened', () async {
    final harness = _Harness()
      ..follows = [_room('1', status: LiveStatus.offline), _room('2', status: LiveStatus.live)]
      ..details['2'] = _room('2', status: LiveStatus.live)
      ..unfollowed.add('test:2');

    harness.switcher.update(
      room: _room('1', status: LiveStatus.offline),
      playback: PlayerCoreState.idle,
      resolving: false,
      unavailable: false,
    );
    harness.timers.fire(const Duration(seconds: 1));
    await _pump();
    expect(harness.lookedUp, ['2']);
    expect(harness.switched, isEmpty);
    expect(harness.exhaustedCount, 1);
  });

  test('two panes of one wall never land on the same room', () async {
    final group = AutoRoomSwitchGroup();
    final timers = _Timers();
    final held = _room('2', status: LiveStatus.live);

    ({AutoRoomSwitch switcher, List<LiveRoom> switched}) pane({
      required List<LiveRoom> follows,
      Map<String, LiveRoom> details = const {},
    }) {
      final switched = <LiveRoom>[];
      final switcher = AutoRoomSwitch(
        enabled: () => true,
        followsOf: () => follows,
        isFollowed: (candidate) => follows.any((room) => room.ref.identityKey == candidate.ref.identityKey),
        lookupRoom: (candidate) async => details[candidate.ref.identityKey],
        onSwitch: switched.add,
        maySwitch: () => true,
        group: group,
        timer: timers.create,
      );
      return (switcher: switcher, switched: switched);
    }

    // Pane A plays room 2 and holds its reservation.
    final paneA = pane(
      follows: [held],
    )..switcher.update(room: held, playback: PlayerCoreState.idle.playingState(), resolving: false, unavailable: false);
    // Pane B's only live follow is that same room.
    final paneB = pane(
      follows: [
        _room('1', status: LiveStatus.offline),
        held,
      ],
      details: {'test:2': held},
    );
    paneB.switcher.update(
      room: _room('1', status: LiveStatus.offline),
      playback: PlayerCoreState.idle,
      resolving: false,
      unavailable: false,
    );
    expect(group.available(paneB.switcher, held), isFalse);

    timers.fire(const Duration(seconds: 1));
    await _pump();
    expect(paneB.switched, isEmpty);
    expect(paneA.switched, isEmpty);
  });

  test('a lookup timeout stops the round instead of cascading', () async {
    final timers = _Timers();
    final switched = <LiveRoom>[];
    var exhaustedCount = 0;
    final follows = [_room('1', status: LiveStatus.offline), _room('2', status: LiveStatus.live)];
    // A lost network: the ask dies the way a timed-out one does.
    final switcher = AutoRoomSwitch(
      enabled: () => true,
      followsOf: () => follows,
      isFollowed: (_) => true,
      lookupRoom: (_) => Future<LiveRoom?>.error(TimeoutException('network lost')),
      onSwitch: switched.add,
      maySwitch: () => true,
      onExhausted: () => exhaustedCount++,
      timer: timers.create,
    )..update(
      room: _room('1', status: LiveStatus.offline),
      playback: PlayerCoreState.idle,
      resolving: false,
      unavailable: false,
    );
    timers.fire(const Duration(seconds: 1));
    await _pump();
    expect(switcher.exhausted, isTrue);
    expect(switched, isEmpty);
    expect(exhaustedCount, 1);

    // The exhausted round arms nothing further until a healthy spell or a
    // room choice resets it.
    switcher.update(
      room: _room('1', status: LiveStatus.offline),
      playback: PlayerCoreState.idle,
      resolving: false,
      unavailable: false,
    );
    expect(timers.scheduled(const Duration(seconds: 1)), isFalse);
  });

  test('thirty healthy seconds let a failed candidate be watched again', () async {
    final first = _room('1', status: LiveStatus.offline);
    final second = _room('2', status: LiveStatus.live);
    final harness = _Harness()
      ..follows = [first, second, _room('3', status: LiveStatus.offline)]
      ..details['2'] = second;

    // The broadcast ended; the round switches to room 2.
    harness.switcher.update(room: first, playback: PlayerCoreState.idle, resolving: false, unavailable: false);
    harness.timers.fire(const Duration(seconds: 1));
    await _pump();
    expect(harness.switched.single.ref.identityKey, 'test:2');

    // Room 2 plays; the healthy spell arms.
    harness.switcher.setRoom(second, automatic: true);
    harness.switcher.update(
      room: second,
      playback: PlayerCoreState.idle.playingState(),
      resolving: false,
      unavailable: false,
    );

    // It dies before the spell finished: room 1 (already tried) is skipped,
    // and nothing else being live ends the round.
    harness.switcher.update(room: second, playback: PlayerCoreState.idle, resolving: false, unavailable: true);
    harness.timers.fire(const Duration(seconds: 1));
    await _pump();
    expect(harness.switched, hasLength(1));
    expect(harness.exhaustedCount, 1);

    // Thirty healthy seconds clear the round's memory; the first streamer
    // came back, and the next failure may walk back to their room.
    harness.details['1'] = _room('1', status: LiveStatus.live);
    // The comeback shows in the follows the next refresh brought in; the
    // walk only spends a lookup on a candidate the list already says is live.
    harness.follows = [harness.details['1']!, second, _room('3', status: LiveStatus.offline)];
    harness.switcher.update(
      room: second,
      playback: PlayerCoreState.idle.playingState(),
      resolving: false,
      unavailable: false,
    );
    harness.timers.fire(const Duration(seconds: 30));
    harness.switcher.update(room: second, playback: PlayerCoreState.idle, resolving: false, unavailable: true);
    harness.timers.fire(const Duration(seconds: 1));
    await _pump();
    expect(harness.switched, hasLength(2));
    expect(harness.switched.last.ref.identityKey, 'test:1');
  });

  test('the current room is refreshed twice before the follows are walked', () async {
    final candidate = _room('2', status: LiveStatus.live);
    final harness = _Harness()
      ..refreshesFirst = true
      ..follows = [_room('1', status: LiveStatus.offline), candidate]
      ..details['2'] = candidate;

    harness.switcher.update(
      room: _room('1', status: LiveStatus.offline),
      playback: PlayerCoreState.idle,
      resolving: false,
      unavailable: true,
    );
    harness.timers.fire(const Duration(seconds: 1));
    await _pump();
    expect(harness.refreshes, 1);
    expect(harness.lookedUp, isEmpty);
    expect(harness.timers.scheduled(const Duration(seconds: 20)), isTrue);

    // The refresh's 20-second grace holds the round: a reload may yet start
    // playing, and an immediate second read would double the asks.
    harness.switcher.update(
      room: _room('1', status: LiveStatus.offline),
      playback: PlayerCoreState.idle,
      resolving: false,
      unavailable: true,
    );
    expect(harness.timers.scheduled(const Duration(seconds: 1)), isFalse);

    harness.timers.fire(const Duration(seconds: 20));
    expect(harness.timers.scheduled(const Duration(seconds: 1)), isTrue);
    harness.timers.fire(const Duration(seconds: 1));
    await _pump();
    expect(harness.refreshes, 2);
    expect(harness.lookedUp, isEmpty);

    harness.timers.fire(const Duration(seconds: 20));
    harness.timers.fire(const Duration(seconds: 1));
    await _pump();
    expect(harness.refreshes, 2);
    expect(harness.switched.single.ref.identityKey, 'test:2');
  });

  test('a viewer room choice starts a fresh round; an automatic one keeps it', () async {
    final first = _room('1', status: LiveStatus.offline);
    final second = _room('2', status: LiveStatus.live);
    final harness = _Harness()
      ..follows = [first, second]
      ..details['2'] = second;

    // The round runs and spends its candidate.
    harness.switcher.update(room: first, playback: PlayerCoreState.idle, resolving: false, unavailable: false);
    harness.timers.fire(const Duration(seconds: 1));
    await _pump();
    expect(harness.switched.single.ref.identityKey, 'test:2');

    // The viewer opens room 2 themselves: the memory starts over, and the
    // next failure runs a fresh round (which here ends exhausted again —
    // room 2 is the current room and its neighbours are spent or offline).
    harness.switcher.setRoom(second);
    harness.switcher.update(room: second, playback: PlayerCoreState.idle, resolving: false, unavailable: true);
    harness.timers.fire(const Duration(seconds: 1));
    await _pump();
    expect(harness.exhaustedCount, 1);
    expect(harness.switcher.exhausted, isTrue);

    // An automatic arrival keeps the spent attempts: the exhausted round the
    // switch came out of does not read as a fresh one.
    final kept = _Harness()
      ..follows = [first, second]
      ..details['2'] = second;
    kept.switcher.update(room: first, playback: PlayerCoreState.idle, resolving: false, unavailable: false);
    kept.timers.fire(const Duration(seconds: 1));
    await _pump();
    kept.switcher.setRoom(second, automatic: true);
    expect(kept.switcher.exhausted, isFalse);
    expect(kept.switched, hasLength(1));
  });

  test('only the failures the platform stated are worth a switch', () {
    // A room that does not exist any more and a stream the platform refuses
    // to serve are verdicts about the room.
    expect(liveSiteErrorWarrantsSwitch(const LiveSiteNotFound(siteId: 't', message: 'gone')), isTrue);
    expect(liveSiteErrorWarrantsSwitch(const LiveSiteContentUnavailable(siteId: 't', message: 'no stream')), isTrue);
    // Watching without a sign-in is the platform's own gate.
    expect(liveSiteErrorWarrantsSwitch(const LiveSiteAuthenticationError(siteId: 't', message: 'login')), isTrue);
    // A stored cookie the platform refused belongs to the account page.
    expect(
      liveSiteErrorWarrantsSwitch(
        const LiveSiteAuthenticationError(siteId: 't', message: 'refused', cookieSuspect: true),
      ),
      isFalse,
    );
    // A transport blink and an answer this app could not read are not the
    // platform's verdict on the room.
    expect(liveSiteErrorWarrantsSwitch(const LiveSiteNetworkError(siteId: 't', message: 'blink')), isFalse);
    expect(liveSiteErrorWarrantsSwitch(const LiveSiteParseError(siteId: 't', message: 'shape')), isFalse);
  });
}
