import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:live_sites/live_sites.dart';
import 'package:pure_live/features/room/room_playlist.dart';
import 'package:pure_live/features/room/widgets/room_header_parts.dart';
import 'package:pure_live/l10n/generated/strings.g.dart';
import 'package:pure_uikit/pure_uikit.dart';

/// The badge's previous/next switch, pinned at the widget level: it appears
/// only for a room opened from a list that holds more than one room, and it
/// reads the position in that list.

LiveRoom _room(String platform, String id, [String title = '']) => LiveRoom.normalized(
  platform: platform,
  roomId: id,
  content: RoomContent(title: title),
);

final _alpha = _room('bilibili', '1', 'A');
final _beta = _room('bilibili', '2', 'B');
final _gamma = _room('douyu', '3', 'C');

void main() {
  testWidgets('a room opened on its own has no switch', (tester) async {
    await tester.pumpWidget(_host(RoomIdentityBadge(room: _alpha, siteName: 'Bilibili')));
    expect(find.byKey(const ValueKey('room-previous')), findsNothing);
    expect(find.byKey(const ValueKey('room-next')), findsNothing);
  });

  testWidgets('a list of one room has no switch either', (tester) async {
    await tester.pumpWidget(
      _host(
        RoomIdentityBadge(room: _alpha, siteName: 'Bilibili'),
        playlist: (rooms: [_alpha], current: _alpha),
      ),
    );
    expect(find.byKey(const ValueKey('room-next')), findsNothing);
  });

  testWidgets('a room opened from a list shows its place and both switches', (tester) async {
    await tester.pumpWidget(
      _host(
        RoomIdentityBadge(room: _beta, siteName: 'Bilibili'),
        playlist: (rooms: [_alpha, _beta, _gamma], current: _beta),
      ),
    );
    expect(find.text('2/3'), findsOneWidget);
    expect(find.byKey(const ValueKey('room-previous')), findsOneWidget);
    expect(find.byKey(const ValueKey('room-next')), findsOneWidget);
  });

  testWidgets('a stale list left by an earlier room does not offer a switch', (tester) async {
    // The provider still holds the list the last list-opened room came from;
    // this room was opened by a deep link and is not in it.
    await tester.pumpWidget(
      _host(
        RoomIdentityBadge(room: _alpha, siteName: 'Bilibili'),
        playlist: (rooms: [_beta, _gamma], current: _gamma),
      ),
    );
    expect(find.byKey(const ValueKey('room-next')), findsNothing);
  });
}

Widget _host(Widget child, {({List<LiveRoom> rooms, LiveRoom current})? playlist}) {
  final container = ProviderContainer();
  if (playlist != null) {
    container.read(roomPlaylistProvider.notifier).open(playlist.rooms, playlist.current);
  }
  addTearDown(container.dispose);
  return UncontrolledProviderScope(
    container: container,
    child: PureConfigProvider(
      config: const UiConfig(language: PureDesignLanguage.material),
      child: MaterialApp(
        home: TranslationProvider(
          child: Scaffold(body: SizedBox(width: 400, height: 80, child: child)),
        ),
      ),
    ),
  );
}
