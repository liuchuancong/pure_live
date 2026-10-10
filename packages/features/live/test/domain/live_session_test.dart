// Module: test/domain/live_session_test.dart
// Purpose: Pins the commit-only-when-opened rule, and which switches are allowed to commit anything.
// Author: liuchuancong
// Created: 2026-10-10

import 'package:pure_live_live/pure_live_live.dart';
import 'package:pure_live_platform/pure_live_platform.dart';
import 'package:test/test.dart';

const List<StreamVariant> _table = <StreamVariant>[
  StreamVariant(id: 'src', label: '原画', kind: StreamVariantKind.quality, isDefault: true),
  StreamVariant(id: '720', label: '高清', kind: StreamVariantKind.quality),
  StreamVariant(id: '480', label: '标清', kind: StreamVariantKind.quality),
  StreamVariant(id: 'l1', label: '线路1', kind: StreamVariantKind.line, isDefault: true),
  StreamVariant(id: 'l2', label: '线路2', kind: StreamVariantKind.line),
];

MediaTicket _ticket({String uri = 'https://live.example.com/a.m3u8', String id = 't1'}) => MediaTicket(
  id: id,
  uri: Uri.parse(uri),
  kind: MediaKind.live,
  protocol: MediaProtocol.hls,
  createdAt: DateTime.utc(2026, 10, 10),
);

ContentRef _room() => const ContentRef(sourceId: 'huya', contentId: 'room-1', kind: ContentKind.liveRoom);

LiveSession _session({MediaTicket? ticket}) =>
    LiveSession.opened(roomRef: _room(), ticket: ticket ?? _ticket(), variants: _table);

(SwitchRequest, LiveSession) _switch(LiveSession session, StreamVariant variant) {
  final (next, request) = session.requestSwitch(variant);
  return (request, next);
}

void main() {
  final quality = _table[1]; // 720
  final line2 = _table[4]; // l2

  test('test_liveSession_opened_adoptsTheSourceDefaults', () {
    final session = _session();
    expect(session.selection.quality?.id, 'src');
    expect(session.selection.line?.id, 'l1');
    expect(session.hasPendingSwitch, isFalse);
  });

  test('test_liveSession_selectionHoldsBothAxesAtOnce', () async {
    var session = _session();
    final (first, afterFirst) = _switch(session, quality);
    session = afterFirst;
    final (second, afterSecond) = _switch(session, line2);
    session = afterSecond;

    expect(first, isA<SwitchAccepted>());
    expect(second, isA<SwitchAccepted>());
    // Both axes were in flight one after the other; each commits independently.
    session = session.commitSwitch((first as SwitchAccepted).attempt).commitSwitch((second as SwitchAccepted).attempt);
    expect(session.selection.quality?.id, '720');
    expect(session.selection.line?.id, 'l2');
  });

  test('test_liveSession_switchDoesNotCommitUntilThePlayerReportsOpen', () {
    final session = _session();
    final (request, after) = _switch(session, quality);

    expect((request as SwitchAccepted).attempt.target.id, '720');
    expect(after.selection.quality?.id, 'src', reason: 'the old stream is still the one playing');
    expect(after.hasPendingSwitch, isTrue);
  });

  test('test_liveSession_abandonedSwitchKeepsTheCommittedSelection', () {
    final session = _session();
    final (request, after) = _switch(session, quality);
    final rolledBack = after.abandonSwitch((request as SwitchAccepted).attempt);

    expect(rolledBack.selection.quality?.id, 'src');
    expect(rolledBack.hasPendingSwitch, isFalse);
  });

  test('test_liveSession_supersededAttemptCannotCommitTheNewerSelection', () {
    final session = _session();
    final (first, afterFirst) = _switch(session, quality);
    // The user changes their mind before the player answers; the newer quality attempt owns the axis now.
    final (second, afterSecond) = _switch(afterFirst, _table[2]); // 480
    final stale = (first as SwitchAccepted).attempt;

    expect(second, isA<SwitchAccepted>());
    expect(
      () => afterSecond.commitSwitch(stale),
      throwsA(
        isA<SwitchFailure>().having(
          (error) => error.reason,
          'reason',
          allOf(contains('no longer pending'), contains('superseded')),
        ),
      ),
      reason: 'the late "opened" callback of the abandoned quality must not rewrite the selection',
    );
    // The newer attempt still commits, and lands on what it named.
    expect(afterSecond.commitSwitch((second as SwitchAccepted).attempt).selection.quality?.id, '480');
  });

  test('test_liveSession_aSwitchOnTheOtherAxisDoesNotSupersedeThisOne', () {
    final session = _session();
    final (qualityRequest, afterQuality) = _switch(session, quality);
    final (lineRequest, afterBoth) = _switch(afterQuality, line2);

    expect(afterBoth.pending(StreamVariantKind.quality)?.id, (qualityRequest as SwitchAccepted).attempt.id);
    expect(afterBoth.pending(StreamVariantKind.line)?.id, (lineRequest as SwitchAccepted).attempt.id);
    // Abandoning the line attempt leaves the quality attempt in flight: the axes are independent.
    final rolledBack = afterBoth.abandonSwitch(lineRequest.attempt);
    expect(rolledBack.pending(StreamVariantKind.quality), isNotNull);
    expect(rolledBack.pending(StreamVariantKind.line), isNull);
  });

  test('test_liveSession_switchingToTheCurrentVariantIsANoopNotAnError', () {
    final (request, after) = _switch(_session(), _table[0]);

    expect(request, isA<SwitchNoop>());
    expect(after.hasPendingSwitch, isFalse);
  });

  test('test_liveSession_refusesAVariantTheSourceNeverOffered', () {
    const ghost = StreamVariant(id: 'gone', label: '幽灵线路', kind: StreamVariantKind.line);
    final (request, after) = _switch(_session(), ghost);

    expect(request, isA<SwitchRefused>());
    expect(after.selection.line?.id, 'l1');
    expect(after.hasPendingSwitch, isFalse);
  });

  test('test_liveSession_refusesAWithoutAStreamPlaying', () {
    final session = LiveSession(
      roomRef: _room(),
      ticket: _ticket(uri: ''),
      variants: _table,
    );
    final (request, after) = _switch(session, quality);

    expect((request as SwitchRefused).failure.reason, contains('nothing to switch'));
    expect(after.hasPendingSwitch, isFalse);
  });

  test('test_liveSession_variantsThatDisappearReleaseTheirSelection', () {
    final session = _session();
    final shrunk = session.withVariants(<StreamVariant>[
      const StreamVariant(id: '720', label: '高清', kind: StreamVariantKind.quality),
    ]);

    expect(shrunk.selection.quality, isNull, reason: '原画 is no longer offered');
    expect(shrunk.selection.line, isNull);
    expect(shrunk.offered(StreamVariantKind.quality).map((variant) => variant.id), <String>['720']);
  });

  test('test_liveSession_aStalledAttemptDiesWithTheVariantTable', () {
    final session = _session();
    final (request, after) = _switch(session, quality);
    final dropped = after.withVariants(const <StreamVariant>[]);

    expect(dropped.hasPendingSwitch, isFalse);
    expect(() => dropped.commitSwitch((request as SwitchAccepted).attempt), throwsA(isA<SwitchFailure>()));
  });

  test('test_liveSession_newTicketDropsTheInFlightSwitch', () {
    final session = _session();
    final (request, after) = _switch(session, quality);
    final refreshed = after.withTicket(_ticket(id: 't2'));

    expect(refreshed.hasPendingSwitch, isFalse);
    expect(refreshed.selection.quality?.id, 'src');
    expect((request as SwitchAccepted).attempt.target.id, '720');
  });

  test('test_liveSession_variantsAreUnmodifiableAndOfferedReturnsACopy', () {
    final session = _session();
    expect(() => session.variants.add(quality), throwsUnsupportedError);

    // offered() hands out a snapshot that cannot be mutated either, so neither the table nor a caller's
    // ordering of it can be changed through the view.
    expect(() => session.offered(StreamVariantKind.line).clear(), throwsUnsupportedError);
    expect(session.offered(StreamVariantKind.line), hasLength(2));
  });
}
