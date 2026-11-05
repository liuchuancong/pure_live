import 'package:live_sites/live_sites.dart' show LiveRoom;

/// The rooms a route could not carry a payload for.
///
/// A room opened inside the app travels as the route's `extra`. A room
/// opened in its own window travels as a route string, which cannot carry
/// an object; the window is in the same isolate, so the page takes the
/// room from here instead. Entries are consumed on first use and bounded,
/// so a window that never comes up leaves at most a handful of stale rooms.
const int _kSeedLimit = 8;

final Map<String, LiveRoom> _seeds = <String, LiveRoom>{};

/// The key one room's seed is kept under.
String roomSeedKey(String platform, String roomId) => '${platform.trim().toLowerCase()}/${roomId.trim()}';

/// Remembers [room] for the window that is about to open.
void rememberRoomSeed(LiveRoom room) {
  final key = roomSeedKey(room.ref.platform, room.ref.roomId);
  _seeds
    ..remove(key)
    ..[key] = room;
  while (_seeds.length > _kSeedLimit) {
    _seeds.remove(_seeds.keys.first);
  }
}

/// The seeded room for [platform] and [roomId], removed from the shelf.
LiveRoom? takeRoomSeed(String platform, String roomId) => _seeds.remove(roomSeedKey(platform, roomId));

/// Drops a seed that will not be claimed — a window that failed to open.
void forgetRoomSeed(String platform, String roomId) => _seeds.remove(roomSeedKey(platform, roomId));
