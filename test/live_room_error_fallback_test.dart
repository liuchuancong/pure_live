import 'package:flutter_test/flutter_test.dart';
import 'package:pure_live/common/models/live_room.dart';

void main() {
  test('room identity comparison normalizes platform and whitespace', () {
    final room = LiveRoom(platform: 'BILIBILI', roomId: ' 12345 ');

    expect(room.hasIdentity(platform: 'bilibili', roomId: '12345'), isTrue);
    expect(room.hasIdentity(platform: 'douyu', roomId: '12345'), isFalse);
    expect(room.hasIdentity(platform: 'bilibili', roomId: '54321'), isFalse);
  });

  test('error fallback returns an offline copy without mutating active room state', () {
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
    expect(fallback.liveStatus, LiveStatus.offline);
    expect(active.status, isTrue);
    expect(active.isRecord, isTrue);
    expect(active.liveStatus, LiveStatus.live);
  });
}
