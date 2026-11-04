import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pure_live/modules/live/room/controller/room_controller.dart';
import 'package:pure_live/modules/live/room/controller/room_open_timing.dart';

void main() {
  group('the standing login notice', () {
    test('the same words for the same platform do not move the bar', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notice = container.read(roomChatNoticeProvider.notifier)..show('twitch', 'the cookie was refused');
      final raised = container.read(roomChatNoticeProvider);

      // A masked-name run re-raises the same notice on every connection; a new
      // record each time would redraw the bar and look like a flicker.
      notice.show('twitch', 'the cookie was refused');

      expect(container.read(roomChatNoticeProvider), same(raised));
    });

    test('another platform words replace the bar', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      container.read(roomChatNoticeProvider.notifier).show('twitch', 'the cookie was refused');

      container.read(roomChatNoticeProvider.notifier).show('bilibili', 'every name is masked');

      final raised = container.read(roomChatNoticeProvider);
      expect(raised?.siteId, 'bilibili');
      // The button beside the bar opens *this* platform's sign-in.
      expect(raised?.text, 'every name is masked');
    });

    test('a new connection clears it', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      container.read(roomChatNoticeProvider.notifier)
        ..show('bilibili', 'every name is masked')
        ..clear();

      expect(container.read(roomChatNoticeProvider), isNull);
    });
  });

  group('the entry timings the details panel reads', () {
    test('a finished entry publishes its stages and the route it took', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final timing = RoomOpenTiming(site: 'youtube', roomId: '3', proxy: RoomOpenProxy.manual)
        ..markDetail()
        ..markQualities()
        ..markLines()
        ..markRequested()
        ..markFirstFrame()
        ..markPlaying();

      container.read(roomOpenRecordProvider.notifier).report(timing);

      final record = container.read(roomOpenRecordProvider);
      expect(record?.site, 'youtube');
      expect(record?.proxy, RoomOpenProxy.manual);
      expect(record?.failed, isFalse);
      // The panel lists only what happened; `chat` did not, so it has no row.
      expect(record?.stages.where((stage) => stage.took != null).map((stage) => stage.name).toList(), [
        'detail',
        'qualities',
        'lines',
        'request',
        'firstFrame',
        'playing',
      ]);
    });

    test('a failed entry says it failed, in words the panel can show', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final timing = RoomOpenTiming(site: 'bigo', roomId: '9')..markDetail();

      container.read(roomOpenRecordProvider.notifier).report(timing, failed: true);

      expect(container.read(roomOpenRecordProvider)?.failed, isTrue);
    });

    test('the next room drops the previous visit numbers', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      container.read(roomOpenRecordProvider.notifier)
        ..report(RoomOpenTiming(site: 'douyu', roomId: '1')..markDetail())
        // Last visit's milliseconds would otherwise read as this room's.
        ..clear();

      expect(container.read(roomOpenRecordProvider), isNull);
    });
  });
}
