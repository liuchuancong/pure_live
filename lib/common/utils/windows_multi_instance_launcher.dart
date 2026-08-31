import 'dart:io';
import 'dart:convert';

import 'package:path/path.dart' as p;
import 'package:pure_live/get/get.dart';
import 'package:pure_live/common/models/live_room.dart';
import 'package:pure_live/common/services/settings/backup_controller.dart';

/// Launches an isolated Windows player process.
///
/// Every process receives a unique `--instance` value, so Hive, player, PiP
/// and window state are never shared concurrently. An optional compact room
/// payload lets the new process open the selected live room immediately.
///
/// The current settings are exported to a temporary backup file before the
/// new process is launched. The new process imports the backup during startup
/// and removes the temporary file after the configuration has been restored.
class WindowsMultiInstanceLauncher {
  static const String instancePrefix = '--instance=';
  static const String roomPrefix = '--open-room=';
  static const String configPrefix = '--config-file=';

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

  static String? configFileFromArgs(List<String> args) {
    final argument = args.where((item) => item.startsWith(configPrefix)).firstOrNull;

    if (argument == null) return null;

    final path = argument.substring(configPrefix.length).trim();

    if (path.isEmpty) return null;

    return path;
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
      'liveStatus': room.effectiveLiveStatus.index,
      'isRecord': room.isRecord,
      'status': room.isLiveNow,
    };

    return '$roomPrefix'
        '${base64Url.encode(utf8.encode(jsonEncode(payload))).replaceAll('=', '')}';
  }

  static Future<File> _createConfigFile(String instanceId) async {
    final backupController = Get.find<BackupController>();

    final data = backupController.exportAllSettings(includeSensitiveData: true);

    final directory = await Directory.systemTemp.createTemp('pure_live_instance_');

    final file = File(p.join(directory.path, '$instanceId.json'));

    await file.writeAsString(const JsonEncoder.withIndent('  ').convert(data), flush: true);

    return file;
  }

  static List<String> buildArguments({
    LiveRoom? room,
    String? instanceId,
    String? configFile,
    int? processId,
    int? timestampMicros,
  }) {
    final id =
        instanceId ??
        'window_${processId ?? pid}_'
            '${timestampMicros ?? DateTime.now().microsecondsSinceEpoch}';

    return <String>[
      '$instancePrefix$id',
      if (configFile != null) '$configPrefix$configFile',
      if (room != null) encodeRoomArgument(room),
    ];
  }

  static Future<void> launch({LiveRoom? room}) async {
    if (!Platform.isWindows) return;

    final timestampMicros = DateTime.now().microsecondsSinceEpoch;

    final id = sanitizeInstanceId('window_${pid}_$timestampMicros');

    File? configFile;

    try {
      configFile = await _createConfigFile(id);

      final executable = Platform.resolvedExecutable;

      await Process.start(
        executable,
        buildArguments(room: room, instanceId: id, configFile: configFile.path),
        workingDirectory: p.dirname(executable),
        mode: ProcessStartMode.detached,
      );
    } catch (_) {
      if (configFile != null) {
        try {
          if (await configFile.exists()) {
            await configFile.delete();
          }

          final directory = configFile.parent;

          if (await directory.exists()) {
            await directory.delete();
          }
        } catch (_) {}
      }

      rethrow;
    }
  }
}
