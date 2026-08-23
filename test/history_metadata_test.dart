import 'package:flutter_test/flutter_test.dart';
import 'package:pure_live/common/models/live_room.dart';
import 'package:pure_live/common/services/settings/history_controller.dart';

void main() {
  test('history identity is platform scoped and stores the latest watch time', () {
    final first = LiveRoom(roomId: '100', platform: 'bilibili', title: 'Bili');
    final sameNumberOtherSite = LiveRoom(roomId: '100', platform: 'huya', title: 'Huya');
    final updated = LiveRoom(roomId: '100', platform: 'bilibili', title: 'Bili updated');

    var history = upsertHistoryRoom(const [], first, watchedAt: 10);
    history = upsertHistoryRoom(history, sameNumberOtherSite, watchedAt: 20);
    history = upsertHistoryRoom(history, updated, watchedAt: 30);

    expect(history, hasLength(2));
    expect(history.first.title, 'Bili updated');
    expect(history.first.lastWatchedAt, 30);
    expect(history.last.platform, 'huya');
  });

  test('history timestamp survives JSON and detail refresh', () {
    final stored = LiveRoom(roomId: '1', platform: 'test', title: 'Old', lastWatchedAt: 123456);
    final decoded = LiveRoom.fromJson(stored.toJson());
    final refreshed = preserveHistoryMetadata(LiveRoom(roomId: '1', platform: 'test', title: 'Fresh'), decoded);

    expect(decoded.lastWatchedAt, 123456);
    expect(refreshed.title, 'Fresh');
    expect(refreshed.lastWatchedAt, 123456);
  });

  test('history list keeps newest fifty entries', () {
    var history = <LiveRoom>[];
    for (var index = 0; index < 55; index++) {
      history = upsertHistoryRoom(
        history,
        LiveRoom(roomId: '$index', platform: 'test'),
        watchedAt: index,
      );
    }
    expect(history, hasLength(50));
    expect(history.first.roomId, '54');
    expect(history.last.roomId, '5');
  });
}
