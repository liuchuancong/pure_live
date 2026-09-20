import 'dart:convert';

import 'package:pure_live/common/index.dart';
import 'package:pure_live/common/services/utils/backup_migration_util.dart';
import 'package:pure_live/common/utils/hive_pref_util.dart';
import 'package:synchronized/synchronized.dart';

const int defaultHistoryLimit = 50;
const int unlimitedHistoryLimit = 0;

int normalizeHistoryLimit(Object? value) {
  final parsed = value is num ? value.toInt() : int.tryParse(value?.toString() ?? '');
  if (parsed == null || parsed < 0) return defaultHistoryLimit;
  return parsed;
}

List<T> applyHistoryLimit<T>(Iterable<T> values, int limit) {
  final normalized = normalizeHistoryLimit(limit);
  return normalized == unlimitedHistoryLimit
      ? List<T>.of(values, growable: true)
      : values.take(normalized).toList(growable: true);
}

List<LiveRoom> upsertHistoryRoom(
  List<LiveRoom> current,
  LiveRoom room, {
  required int watchedAt,
  int limit = defaultHistoryLimit,
}) {
  final maxLength = normalizeHistoryLimit(limit);
  final next = List<LiveRoom>.from(current)..removeWhere((entry) => entry.hasSameIdentity(room));
  next.insert(0, room.normalizedIdentityCopy().copyWith(lastWatchedAt: watchedAt));
  if (maxLength != unlimitedHistoryLimit && next.length > maxLength) {
    next.removeRange(maxLength, next.length);
  }
  return next;
}

LiveRoom preserveHistoryMetadata(LiveRoom refreshed, LiveRoom previous) {
  return refreshed.withAudienceFallbackFrom(previous).copyWith(lastWatchedAt: previous.lastWatchedAt);
}

List<LiveRoom> removeHistorySnapshotEntries(Iterable<LiveRoom> current, Iterable<LiveRoom> snapshot) {
  final ownedEntries = Set<LiveRoom>.identity()..addAll(snapshot);
  if (ownedEntries.isEmpty) return List<LiveRoom>.of(current, growable: true);
  return current.where((room) => !ownedEntries.contains(room)).toList(growable: true);
}

class HistoryController extends GetxController {
  static HistoryController get to => Get.find();

  static const String historyLimitKey = 'historyLimit';
  static const String _historyRoomsKey = 'historyRooms';

  final Lock _historyMutationLock = Lock();

  final Rx<List<LiveRoom>> historyRooms = hiveObject(
    'historyRooms',
    <LiveRoom>[],
    fromJson: (json) {
      return (json['list'] as List).map((e) => LiveRoom.fromJson(e)).toList();
    },
    toJson: (list) {
      return {'list': list.map((e) => e.toJson()).toList()};
    },
  );

  final historyLimit = hiveInt(historyLimitKey, defaultHistoryLimit);

  @override
  void onInit() {
    super.onInit();
    setHistoryLimit(historyLimit.v);
  }

  void setHistoryLimit(int value) {
    final normalized = normalizeHistoryLimit(value);
    historyLimit.v = normalized;
    if (normalized != unlimitedHistoryLimit && historyRooms.v.length > normalized) {
      historyRooms.v = historyRooms.v.take(normalized).toList(growable: true);
    }
  }

  Future<void> setHistoryLimitDurably(int value) {
    return _historyMutationLock.synchronized(() async {
      final beforeLimit = historyLimit.v;
      final beforeRooms = List<LiveRoom>.from(historyRooms.v);
      setHistoryLimit(value);
      if (beforeLimit == historyLimit.v && _encodeRooms(beforeRooms) == _encodeRooms(historyRooms.v)) return;
      try {
        await _writeState(limit: historyLimit.v, rooms: historyRooms.v);
      } catch (error, stackTrace) {
        historyLimit.v = beforeLimit;
        historyRooms.v = beforeRooms;
        try {
          await _writeState(limit: beforeLimit, rooms: beforeRooms);
        } catch (_) {}
        Error.throwWithStackTrace(error, stackTrace);
      }
    });
  }

  void addRoomToHistory(LiveRoom room) {
    historyRooms.v = upsertHistoryRoom(
      historyRooms.v,
      room,
      watchedAt: DateTime.now().millisecondsSinceEpoch,
      limit: historyLimit.v,
    );
  }

  Future<bool> addRoomToHistoryDurably(LiveRoom room) {
    return _mutateRoomsDurably(
      (current) =>
          upsertHistoryRoom(current, room, watchedAt: DateTime.now().millisecondsSinceEpoch, limit: historyLimit.v),
    );
  }

  void removeRoomFromHistory(LiveRoom room) {
    historyRooms.v = List<LiveRoom>.from(historyRooms.v)..removeWhere((entry) => entry.hasSameIdentity(room));
  }

  void removeRoomFromHistoryAt(int index) {
    if (index < 0 || index >= historyRooms.v.length) return;
    historyRooms.v = List<LiveRoom>.from(historyRooms.v)..removeAt(index);
  }

  void clearHistory() {
    historyRooms.v = <LiveRoom>[];
  }

  void clearHistorySnapshot(Iterable<LiveRoom> snapshot) {
    historyRooms.v = removeHistorySnapshotEntries(historyRooms.v, snapshot);
  }

  Future<bool> clearHistorySnapshotDurably(Iterable<LiveRoom> snapshot) {
    final ownedSnapshot = List<LiveRoom>.from(snapshot);
    return _mutateRoomsDurably((current) => removeHistorySnapshotEntries(current, ownedSnapshot));
  }

  void applyRefreshedRooms(List<LiveRoom> snapshot, List<LiveRoom?> refreshed) {
    // LiveRoom equality compares room identity, not the particular watch/import.
    // Only replace the exact entries still owned by this refresh snapshot.
    final replacements = Map<LiveRoom, LiveRoom>.identity();
    for (var i = 0; i < snapshot.length && i < refreshed.length; i++) {
      final updated = refreshed[i];
      if (updated != null) replacements[snapshot[i]] = updated;
    }
    historyRooms.v = applyHistoryLimit(historyRooms.v.map((room) => replacements[room] ?? room), historyLimit.v);
  }

  Future<bool> applyRefreshedRoomsDurably(List<LiveRoom> snapshot, List<LiveRoom?> refreshed) {
    final ownedSnapshot = List<LiveRoom>.from(snapshot);
    final ownedRefreshed = List<LiveRoom?>.from(refreshed);
    return _mutateRoomsDurably((current) {
      final replacements = Map<LiveRoom, LiveRoom>.identity();
      for (var index = 0; index < ownedSnapshot.length && index < ownedRefreshed.length; index++) {
        final updated = ownedRefreshed[index];
        if (updated != null) replacements[ownedSnapshot[index]] = updated;
      }
      return applyHistoryLimit(current.map((room) => replacements[room] ?? room), historyLimit.v);
    });
  }

  Future<bool> _mutateRoomsDurably(List<LiveRoom> Function(List<LiveRoom> current) update) {
    return _historyMutationLock.synchronized(() async {
      final before = List<LiveRoom>.from(historyRooms.v);
      final updated = applyHistoryLimit(update(List<LiveRoom>.from(before)), historyLimit.v);
      if (_encodeRooms(before) == _encodeRooms(updated)) return false;
      historyRooms.v = updated;
      try {
        await _writeRooms(updated);
        return true;
      } catch (error, stackTrace) {
        historyRooms.v = before;
        try {
          await _writeRooms(before);
        } catch (_) {}
        Error.throwWithStackTrace(error, stackTrace);
      }
    });
  }

  Future<void> _writeRooms(List<LiveRoom> rooms) async {
    await HivePrefUtil.setString(_historyRoomsKey, _encodeRooms(rooms));
    await HivePrefUtil.flush();
  }

  Future<void> _writeState({required int limit, required List<LiveRoom> rooms}) async {
    await HivePrefUtil.setPrefs({historyLimitKey: limit, _historyRoomsKey: _encodeRooms(rooms)});
    await HivePrefUtil.flush();
  }

  String _encodeRooms(Iterable<LiveRoom> rooms) {
    return jsonEncode({'list': rooms.map((room) => room.toJson()).toList(growable: false)});
  }

  Map<String, dynamic> toJson() {
    return {'historyRooms': historyRooms.v.map((e) => e.toJson()).toList(), historyLimitKey: historyLimit.v};
  }

  void fromJson(Map<String, dynamic> json) {
    final parsed = parseConfig(json);
    historyLimit.v = parsed[historyLimitKey];
    historyRooms.v = parsed['historyRooms'];
  }

  static Map<String, dynamic> parseConfig(Map<String, dynamic> json) {
    final limit = normalizeHistoryLimit(json[historyLimitKey]);
    return {
      historyLimitKey: limit,
      'historyRooms': applyHistoryLimit(
        BackupMigrationUtil.parseObjectList(json['historyRooms'], LiveRoom.fromJson, strict: true),
        limit,
      ),
    };
  }

  static Map<String, dynamic> extractConfig(Map<String, dynamic>? rootConfig) {
    final history = rootConfig?['history'] as Map<String, dynamic>? ?? {};

    final list = BackupMigrationUtil.parseObjectList(history['historyRooms'], LiveRoom.fromJson);

    final limit = normalizeHistoryLimit(history[historyLimitKey]);
    return {'historyRooms': applyHistoryLimit(list, limit).map((e) => e.toJson()).toList(), historyLimitKey: limit};
  }

  static Map<String, dynamic> mergeConfig(Map<String, dynamic> rootConfig, Map<String, dynamic> updateFields) {
    final history = Map<String, dynamic>.from(rootConfig['history'] ?? {});

    updateFields.forEach((k, v) => history[k] = v);
    rootConfig['history'] = history;

    return rootConfig;
  }
}
