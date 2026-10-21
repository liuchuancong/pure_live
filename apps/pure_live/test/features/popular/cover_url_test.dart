import 'package:flutter_test/flutter_test.dart';
import 'package:live_sites/live_sites.dart';
import 'package:pure_live/app/preferences/app_preferences.dart';
import 'package:pure_live/shared/widgets/room_card.dart';

LiveRoom _room({String cover = 'https://cover/1.jpg'}) => LiveRoom(
  ref: const LiveRoomRef(platform: 'douyin', roomId: '42'),
  content: RoomContent(coverUrl: cover),
);

void main() {
  group('coverUrlFor', () {
    test('off by default: the address is the platform\u2019s own', () {
      expect(RoomCard.coverUrlFor(_room(), const AppPreferences()), 'https://cover/1.jpg');
    });

    test('auto-refresh appends the interval bucket once per window', () {
      const preferences = AppPreferences(autoRefreshThumbnails: true);
      final first = RoomCard.coverUrlFor(_room(), preferences);
      final second = RoomCard.coverUrlFor(_room(), preferences);
      expect(first, startsWith('https://cover/1.jpg?t='));
      // Two reads inside one 30-minute window give the same address.
      expect(second, first);
    });

    test('a URL that already carries a query joins with &', () {
      const preferences = AppPreferences(autoRefreshThumbnails: true);
      final busted = RoomCard.coverUrlFor(_room(cover: 'https://cover/1.jpg?a=1'), preferences);
      expect(busted, contains('?a=1&t='));
    });
  });
}
