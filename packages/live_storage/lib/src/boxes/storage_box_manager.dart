import 'package:hive_box_manager/hive_box_manager.dart';

/// Opens the project's Hive CE boxes through hive_box_manager's typed
/// box families.
///
/// Boxes auto-open on first use and hive_box_manager caches open boxes
/// by name, so repeated opens of one name answer with the same box; the
/// manager exists to pin the project rules — string keys everywhere,
/// one box family per call site — in one place.
final class StorageBoxManager {
  /// Opens or reuses the keyed box [name].
  Future<KeyedBox<T, String>> keyed<T extends Object>(String name) {
    _validateName(name);
    return KeyedBox.open<T, String>(name).run();
  }

  /// Opens or reuses the keyed box [name] whose values are lists of
  /// [E].
  Future<KeyedBox<List<E>, String>> list<E extends Object>(String name) {
    _validateName(name);
    return KeyedBox.open<List<E>, String>(name).run();
  }

  /// Opens or reuses the map box [name]; every value is a map with keys
  /// of [MK] and values of [MV].
  Future<MapBox<MK, MV, String>> map<MK extends Object, MV extends Object>(String name) {
    _validateName(name);
    return MapBox.open<MK, MV, String>(name).run();
  }

  /// Opens or reuses the set box [name]; every value is a set of [E].
  Future<SetBox<E, String>> set<E extends Object>(String name) {
    _validateName(name);
    return SetBox.open<E, String>(name).run();
  }

  /// Opens or reuses the single-value box [name].
  Future<SingleValueBox<V>> single<V extends Object>(String name) {
    _validateName(name);
    return SingleValueBox.open<V>(name).run();
  }

  void _validateName(String name) {
    if (name.trim().isEmpty) {
      throw ArgumentError.value(name, 'name', 'Must not be empty.');
    }
  }
}
