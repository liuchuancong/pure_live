// The TV wall, pinned: an empty wall shows its empty state, and a card
// carries the room's key, cover and title so the D-pad has something to land
// on.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:live_sites/live_sites.dart' show LiveRoom, RoomAudience, RoomContent;
import 'package:pure_live/platforms/tv/widgets/tv_room_wall.dart';
import 'package:pure_uikit/pure_uikit.dart';

LiveRoom _room(String id, {String title = '直播间', int? viewers}) => LiveRoom.normalized(
  platform: 'douyu',
  roomId: id,
  content: RoomContent(title: title),
  audience: RoomAudience(onlineViewers: viewers),
);

void main() {
  testWidgets('an empty wall shows the empty state', (tester) async {
    await tester.pumpWidget(
      _host(TvRoomWall(rooms: const [], onSelect: (_) {}, emptyTitle: '还没有关注的房间')),
    );
    expect(find.text('还没有关注的房间'), findsOneWidget);
  });

  testWidgets('a card carries the room, its title and its audience', (tester) async {
    LiveRoom? opened;
    await tester.pumpWidget(
      _host(
        TvRoomWall(
          rooms: [
            _room('1', title: '王者荣耀'),
            _room('2', title: '英雄联盟', viewers: 12000),
          ],
          onSelect: (room) => opened = room,
        ),
      ),
    );
    await tester.pump();
    expect(find.byKey(const ValueKey('tv-room-douyu-1')), findsOneWidget);
    expect(find.text('王者荣耀'), findsOneWidget);
    expect(find.text('1.2万'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('tv-room-douyu-2')));
    expect(opened?.ref.roomId, '2');
  });
}

Widget _host(Widget child) => PureConfigProvider(
  config: const UiConfig(language: PureDesignLanguage.material),
  child: MaterialApp(home: Scaffold(body: child)),
);
