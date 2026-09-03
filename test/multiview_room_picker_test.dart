import 'package:flutter_test/flutter_test.dart';
import 'package:pure_live/common/models/live_room.dart';
import 'package:pure_live/modules/multiview/widgets/multiview_room_picker.dart';

void main() {
  test('multiview picker sorts live state before localized audience values', () {
    final rooms = <LiveRoom>[
      LiveRoom(roomId: 'offline', platform: 'douyu', status: false, watching: '99万'),
      LiveRoom(roomId: 'small', platform: 'douyu', status: true, watching: '9500'),
      LiveRoom(roomId: 'large', platform: 'douyu', status: true, watching: '1.2万'),
    ]..sort(compareMultiviewRooms);

    expect(rooms.map((room) => room.roomId), <String?>['large', 'small', 'offline']);
  });

  test('picker uses canonical state when legacy bool and enum disagree', () {
    final rooms = <LiveRoom>[
      LiveRoom(
        roomId: 'stale-offline-enum',
        platform: 'douyu',
        status: true,
        liveStatus: LiveStatus.offline,
        watching: '9500',
      ),
      LiveRoom(
        roomId: 'explicit-unknown',
        platform: 'douyu',
        status: true,
        liveStatus: LiveStatus.unknown,
        watching: '99万',
      ),
      LiveRoom(roomId: 'offline', platform: 'douyu', status: false, watching: '100万'),
    ]..sort(compareMultiviewRooms);

    expect(rooms.map((room) => room.roomId), <String?>[
      'offline',
      'explicit-unknown',
      'stale-offline-enum',
    ]);
    expect(rooms.last.isLiveNow, isFalse);
  });
}
