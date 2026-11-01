import 'package:meta/meta.dart';

/// Causal version tracking for concurrent-modification detection.
///
/// Wall-clock timestamps cannot order concurrent edits — device clocks
/// drift. Every change carries a version vector: one counter per device
/// that has touched the entity. Two vectors compare to *ahead*, *behind*,
/// *concurrent* or *equal*, and only a *concurrent* result is a conflict.
///
/// Vectors grow with the number of participating devices. Retirement is
/// explicit: a device that leaves the sync set is removed through
/// [withoutDevice] by the host's device-management policy, never silently.
@immutable
final class VersionVector {
  /// A vector over [counters], copied so callers cannot mutate the model.
  new(Map<String, int> counters) : _counters = Map.of(counters);

  /// The empty vector: an entity no device has touched yet.
  const new empty() : _counters = const <String, int>{};

  /// A vector restored from a JSON object of device id → counter.
  factory fromJson(Map<String, Object?> json) =>
      VersionVector({for (final entry in json.entries) entry.key: (entry.value! as num).toInt()});

  final Map<String, int> _counters;

  /// The counter contribution of [deviceId], or 0 when it never touched
  /// this entity.
  int operator [](String deviceId) => _counters[deviceId] ?? 0;

  /// The device ids this vector tracks.
  Iterable<String> get deviceIds => _counters.keys;

  /// Whether no device has touched the entity yet.
  bool get isEmpty => _counters.isEmpty;

  /// This vector with [deviceId]'s counter advanced by one. Returns a new
  /// vector; vectors are immutable.
  VersionVector incremented(String deviceId) => VersionVector({..._counters, deviceId: this[deviceId] + 1});

  /// This vector with every component maxed against [other]: the vector a
  /// merge of both histories would carry.
  VersionVector merged(VersionVector other) => VersionVector({
    for (final id in {..._counters.keys, ...other._counters.keys}) id: this[id] > other[id] ? this[id] : other[id],
  });

  /// This vector without [deviceId], used when a device permanently leaves
  /// the sync set so the vector does not grow forever.
  VersionVector withoutDevice(String deviceId) => VersionVector({
    for (final entry in _counters.entries)
      if (entry.key != deviceId) entry.key: entry.value,
  });

  /// How this vector relates to [other] causally.
  VersionRelation compareTo(VersionVector other) {
    var strictlyGreater = false;
    var strictlyLess = false;
    for (final id in {..._counters.keys, ...other._counters.keys}) {
      final mine = this[id];
      final theirs = other[id];
      if (mine > theirs) {
        strictlyGreater = true;
      } else if (mine < theirs) {
        strictlyLess = true;
      }
    }
    return switch ((strictlyGreater, strictlyLess)) {
      (false, false) => VersionRelation.equal,
      (true, false) => VersionRelation.ahead,
      (false, true) => VersionRelation.behind,
      (true, true) => VersionRelation.concurrent,
    };
  }

  /// The JSON object a payload carries this vector as.
  Map<String, Object?> toJson() => Map<String, Object?>.of(_counters);

  @override
  bool operator ==(Object other) {
    if (other is! VersionVector) return false;
    if (other._counters.length != _counters.length) return false;
    for (final entry in _counters.entries) {
      if (other._counters[entry.key] != entry.value) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hashAll(_counters.entries.map((e) => Object.hash(e.key, e.value)));

  @override
  String toString() => 'VersionVector${_counters.entries.map((e) => '${e.key}:${e.value}').toList()}';
}

/// The causal relation between two version vectors.
enum VersionRelation {
  /// Both vectors are component-wise identical.
  equal,

  /// This vector causally follows the other.
  ahead,

  /// This vector causally precedes the other.
  behind,

  /// Neither vector follows from the other: two devices edited the entity
  /// without seeing each other. This is the only relation that is a
  /// conflict.
  concurrent,
}
