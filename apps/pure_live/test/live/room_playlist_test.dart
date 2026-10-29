import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:live_sites/live_sites.dart';
import 'package:pure_live/modules/live/room/player/room_playlist.dart';

LiveRoom _room(String id) => LiveRoom.normalized(platform: 'douyin', roomId: id);

/// A page that leaves the way the room page does: the list was written by the
/// navigation seam, and the page only hands its clear over from `dispose`,
/// which runs while the frame is still coming down.
class _LeavingPage extends ConsumerStatefulWidget {
  const _LeavingPage({required this.room});

  final LiveRoom room;

  @override
  ConsumerState<_LeavingPage> createState() => _LeavingPageState();
}

class _LeavingPageState extends ConsumerState<_LeavingPage> {
  late final RoomPlaylistController _playlistNotifier;

  @override
  void initState() {
    super.initState();
    _playlistNotifier = ref.read(roomPlaylistProvider.notifier);
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();

  @override
  void dispose() {
    _playlistNotifier.clearIfCurrent(widget.room.identityKey);
    super.dispose();
  }
}

void main() {
  late ProviderContainer container;

  setUp(() => container = ProviderContainer());
  tearDown(() => container.dispose());

  /// The navigation seam's write: a room opened from a list of [roomIds].
  void open(List<String> roomIds, String current) => container.read(roomPlaylistProvider.notifier).open(
    rooms: [for (final id in roomIds) _room(id)],
    current: _room(current),
  );

  testWidgets('a leaving page hands its list clear outside the teardown phase', (tester) async {
    open(['123', '456'], '123');
    await tester.pumpWidget(UncontrolledProviderScope(container: container, child: _LeavingPage(room: _room('123'))));
    expect(container.read(roomPlaylistProvider)?.current.roomId, '123');

    await tester.pumpWidget(UncontrolledProviderScope(container: container, child: const SizedBox.shrink()));

    expect(tester.takeException(), isNull, reason: 'a provider write during unmount is rejected by Riverpod');
    expect(container.read(roomPlaylistProvider), isNull, reason: 'the leaving page forgot its list');
  });

  testWidgets("a leaving page leaves a newer room's list alone", (tester) async {
    open(['123', '456'], '123');
    await tester.pumpWidget(UncontrolledProviderScope(container: container, child: _LeavingPage(room: _room('123'))));

    // The room the viewer is on now is not the one being unmounted.
    open(['456', '123'], '456');
    await tester.pumpWidget(UncontrolledProviderScope(container: container, child: const SizedBox.shrink()));
    await tester.pump();

    expect(container.read(roomPlaylistProvider)?.current.roomId, '456');
  });

  test('the list is only there to swipe between rooms', () {
    expect(RoomPlaylist.of([_room('123')], _room('123')), isNull);
    expect(RoomPlaylist.of([_room('123'), _room('456')], _room('789')), isNull);
    final playlist = RoomPlaylist.of([_room('123'), _room('456')], _room('456'));
    expect(playlist?.current.roomId, '456');
    expect(playlist?.neighbour(1)?.roomId, '123', reason: 'swiping wraps around');
  });
}
