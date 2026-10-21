import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:live_sites/live_sites.dart';
import 'package:pure_live/features/room/room_playlist.dart';

LiveRoom _room(String platform, String id, [String title = '']) => LiveRoom.normalized(
  platform: platform,
  roomId: id,
  content: RoomContent(title: title),
);

void main() {
  final alpha = _room('bilibili', '1', 'A');
  final beta = _room('bilibili', '2', 'B');
  final gamma = _room('douyu', '3', 'C');

  group('RoomPlaylist', () {
    test('finds the open room where the list has it', () {
      final playlist = RoomPlaylist([alpha, beta, gamma], current: beta);
      expect(playlist.index, 1);
      expect(playlist.currentRoom, beta);
      expect(playlist.switchable, isTrue);
    });

    test('steps forward and back, wrapping at either end', () {
      final playlist = RoomPlaylist([alpha, beta, gamma], current: beta);
      expect(playlist.neighbour(1), gamma);
      expect(playlist.neighbour(-1), alpha);

      final first = RoomPlaylist([alpha, beta, gamma], current: alpha);
      expect(first.neighbour(-1), gamma);
      final last = RoomPlaylist([alpha, beta, gamma], current: gamma);
      expect(last.neighbour(1), alpha);
    });

    test('a room missing from the list goes first, before the list order', () {
      final stray = _room('huya', '9', 'S');
      final playlist = RoomPlaylist([alpha, beta], current: stray);
      expect(playlist.rooms, [stray, alpha, beta]);
      expect(playlist.index, 0);
      expect(playlist.neighbour(1), alpha);
      expect(playlist.neighbour(-1), beta);
    });

    test('a lone room has nothing to switch to', () {
      final playlist = RoomPlaylist([alpha], current: alpha);
      expect(playlist.switchable, isFalse);
      expect(playlist.neighbour(1), isNull);
      expect(playlist.neighbour(-1), isNull);
    });

    test('moving keeps the list and follows the room', () {
      final playlist = RoomPlaylist([alpha, beta, gamma], current: alpha).movedTo(gamma);
      expect(playlist.rooms, [alpha, beta, gamma]);
      expect(playlist.index, 2);
      expect(playlist.currentRoom, gamma);
    });

    test('identity is the platform plus the room id', () {
      expect(RoomPlaylist.sameRoom(alpha, _room('bilibili', '1')), isTrue);
      expect(RoomPlaylist.sameRoom(alpha, beta), isFalse);
      expect(RoomPlaylist.sameRoom(alpha, _room('douyu', '1')), isFalse);
    });
  });

  group('roomPlaylistProvider', () {
    test('opens a list and moves through it', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = container.read(roomPlaylistProvider.notifier);

      expect(container.read(roomPlaylistProvider), isNull);
      notifier.open([alpha, beta, gamma], alpha);
      expect(container.read(roomPlaylistProvider)!.index, 0);

      notifier.movedTo(beta);
      expect(container.read(roomPlaylistProvider)!.index, 1);
      expect(container.read(roomPlaylistProvider)!.currentRoom, beta);
    });
  });
}
