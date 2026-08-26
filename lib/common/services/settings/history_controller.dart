import 'package:pure_live/common/index.dart';
import 'package:pure_live/common/services/utils/backup_migration_util.dart';

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

class HistoryController extends GetxController {
  static HistoryController get to => Get.find();

  static const String historyLimitKey = 'historyLimit';

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

  void addRoomToHistory(LiveRoom room) {
    historyRooms.v = upsertHistoryRoom(
      historyRooms.v,
      room,
      watchedAt: DateTime.now().millisecondsSinceEpoch,
      limit: historyLimit.v,
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

  Map<String, dynamic> toJson() {
    return {'historyRooms': historyRooms.v.map((e) => e.toJson()).toList(), historyLimitKey: historyLimit.v};
  }

  void fromJson(Map<String, dynamic> json) {
    final limit = normalizeHistoryLimit(json[historyLimitKey]);
    historyLimit.v = limit;
    historyRooms.v = applyHistoryLimit(
      BackupMigrationUtil.parseObjectList(json['historyRooms'], (m) => LiveRoom.fromJson(m)),
      limit,
    );
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
