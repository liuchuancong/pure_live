import 'package:flutter_test/flutter_test.dart';
import 'package:pure_live/common/services/settings/favorite_room_controller.dart';

Map<String, dynamic> _room(String? platform, String? roomId) => {'platform': platform, 'roomId': roomId};

void main() {
  test('backup extraction drops invalid favourite room identities', () {
    final extracted = FavoriteRoomController.extractConfig({
      'favorite': {
        'favoriteRooms': [
          _room('bilibili', '100'),
          _room('huya', '0'),
          _room('douyu', ' null '),
          _room('', '200'),
          _room('douyin', ''),
        ],
      },
    });

    final rooms = extracted['favoriteRooms'] as List<dynamic>;

    expect(rooms, hasLength(1));
    expect(rooms.single, containsPair('platform', 'bilibili'));
    expect(rooms.single, containsPair('roomId', '100'));
  });
}
