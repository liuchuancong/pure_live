import 'package:flutter_test/flutter_test.dart';
import 'package:pure_live/common/models/live_room.dart';

void main() {
  test('room identity comparison normalizes platform and whitespace', () {
    final room = LiveRoom(platform: 'BILIBILI', roomId: ' 12345 ');

    expect(room.hasIdentity(platform: 'bilibili', roomId: '12345'), isTrue);
    expect(room.hasIdentity(platform: 'douyu', roomId: '12345'), isFalse);
    expect(room.hasIdentity(platform: 'bilibili', roomId: '54321'), isFalse);
  });

  test('request error keeps room status pending without mutating active state', () {
    final active = LiveRoom(
      platform: 'bilibili',
      roomId: '12345',
      status: true,
      isRecord: true,
      liveStatus: LiveStatus.live,
    );

    final fallback = active.getLiveRoomWithError();

    expect(fallback, isNot(same(active)));
    expect(fallback.status, isFalse);
    expect(fallback.isRecord, isFalse);
    expect(fallback.liveStatus, LiveStatus.unknown);
    expect(fallback.isLiveStatusPending, isTrue);
    expect(fallback.isExplicitlyOfflineNow, isFalse);
    expect(active.status, isTrue);
    expect(active.isRecord, isTrue);
    expect(active.liveStatus, LiveStatus.live);
  });

  test('empty request-error fallback does not invent an audience value', () {
    final fallback = LiveRoom(platform: 'bilibili', roomId: '12345').getLiveRoomWithError();
    expect(fallback.audienceValue(preferRealOnline: false, platformEnabled: false), isEmpty);
  });
}
