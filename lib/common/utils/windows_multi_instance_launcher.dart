import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:pure_live/common/models/live_room.dart';

/// Launches an isolated Windows player process.
///
/// Every process receives a unique `--instance` value, so Hive, player, PiP
/// and window state are never shared concurrently. An optional compact room
/// payload lets the new process open the selected live room immediately.
class WindowsMultiInstanceLauncher {
  static const String instancePrefix = '--instance=';
  static const String roomPrefix = '--open-room=';

  /// Produces one safe path component and mutex suffix from an external
  /// command-line value. Generated launcher IDs are already safe, but Windows
  /// shortcuts and protocol handlers can supply arbitrary arguments.
  static String sanitizeInstanceId(String value) {
    var result = value.replaceAll(RegExp(r'[^a-zA-Z0-9_.-]'), '');
    result = result.replaceAll(RegExp(r'\.{2,}'), '.');
    result = result.replaceAll(RegExp(r'^[.-]+|[.-]+$'), '');
    if (result.length > 96) result = result.substring(0, 96);
    if (result.isEmpty) return '';

    // Windows device names are reserved even when used with an extension.
    final stem = result.split('.').first.toUpperCase();
    if (RegExp(r'^(CON|PRN|AUX|NUL|COM[1-9]|LPT[1-9])$').hasMatch(stem)) {
      result = 'instance_$result';
    }
    return result;
  }

  static String instanceIdFromArgs(List<String> args) {
    final argument = args.where((item) => item.startsWith(instancePrefix)).firstOrNull;
    return argument == null ? '' : sanitizeInstanceId(argument.substring(instancePrefix.length));
  }

  static LiveRoom? roomFromArgs(List<String> args) {
    final argument = args.where((item) => item.startsWith(roomPrefix)).firstOrNull;
    if (argument == null) return null;
    try {
      final encoded = argument.substring(roomPrefix.length);
      final normalized = base64Url.normalize(encoded);
      final decoded = jsonDecode(utf8.decode(base64Url.decode(normalized)));
      if (decoded is! Map) return null;
      final room = LiveRoom.fromJson(Map<String, dynamic>.from(decoded));
      final roomId = room.roomId?.trim() ?? '';
      final platform = room.platform?.trim().toLowerCase() ?? '';
      if (roomId.isEmpty || platform.isEmpty) return null;
      return room.copyWith(roomId: roomId, platform: platform);
    } catch (_) {
      return null;
    }
  }

  static String encodeRoomArgument(LiveRoom room) {
    final payload = <String, dynamic>{
      'roomId': room.roomId,
      'userId': room.userId,
      'title': room.title,
      'nick': room.nick,
      'avatar': room.avatar,
      'cover': room.cover,
      'area': room.area,
      'watching': room.watching,
      'audienceMetricType': room.effectiveAudienceMetricType.name,
      'popularity': room.popularity,
      'onlineViewers': room.onlineViewers,
      'totalViewers': room.totalViewers,
      'followers': room.followers,
      'platform': room.platform,
      'liveStatus': room.liveStatus?.index ?? LiveStatus.unknown.index,
      'isRecord': room.isRecord,
      'status': room.status,
    };
    return '$roomPrefix${base64Url.encode(utf8.encode(jsonEncode(payload))).replaceAll('=', '')}';
  }

  static List<String> buildArguments({LiveRoom? room, int? processId, int? timestampMicros}) {
    final id = 'window_${processId ?? pid}_${timestampMicros ?? DateTime.now().microsecondsSinceEpoch}';
    return <String>['$instancePrefix$id', if (room != null) encodeRoomArgument(room)];
  }

  static Future<void> launch({LiveRoom? room}) async {
    if (!Platform.isWindows) return;
    final executable = Platform.resolvedExecutable;
    await Process.start(
      executable,
      buildArguments(room: room),
      workingDirectory: p.dirname(executable),
      mode: ProcessStartMode.detached,
    );
  }
}
