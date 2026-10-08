import 'dart:io';
import 'dart:convert';

import 'package:path/path.dart' as p;
import 'package:pure_live/core/models/live_room.dart';
import 'package:pure_live/core/platform/multi_instance_settings_source.dart';

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

  static const String configDirectoryPrefix = 'pure_live_instance_';

  /// The settings file handed over by [launch], or null.
  ///
  /// The file is imported and then deleted, so only a file this launcher could
  /// have written is accepted: `<system temp>/pure_live_instance_*/<id>.json`
  /// for this window's own instance id. Any other path is ignored.
  static String? configFileFromArgs(List<String> args, {String? tempRoot}) {
    final argument = args.where((item) => item.startsWith(configPrefix)).firstOrNull;
    if (argument == null) return null;
    final path = argument.substring(configPrefix.length).trim();
    final instanceId = instanceIdFromArgs(args);
    if (path.isEmpty || instanceId.isEmpty) return null;
    final normalized = p.normalize(p.absolute(path));
    final root = p.normalize(p.absolute(tempRoot ?? Directory.systemTemp.path));
    final parent = p.dirname(normalized);
    if (p.dirname(parent) != root) return null;
    if (!p.basename(parent).startsWith(configDirectoryPrefix)) return null;
    if (p.basename(normalized) != '$instanceId.json') return null;
    return normalized;
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

  static String encodeRoomArgument(LiveRoom liveroom) {
    final payload = <String, dynamic>{
      'roomId': liveroom.roomId,
      'userId': liveroom.userId,
      'title': liveroom.title,
      'nick': liveroom.nick,
      'avatar': liveroom.avatar,
      'cover': liveroom.cover,
      'area': liveroom.area,
      'watching': liveroom.watching,
      'audienceMetricType': liveroom.effectiveAudienceMetricType.name,
      'popularity': liveroom.popularity,
      'onlineViewers': liveroom.onlineViewers,
      'totalViewers': liveroom.totalViewers,
      'followers': liveroom.followers,
      'platform': liveroom.platform,
      'liveStatus': liveroom.effectiveLiveStatus.index,
      'isRecord': liveroom.isRecord,
      'status': liveroom.isLiveNow,
    };

    return '$roomPrefix'
        '${base64Url.encode(utf8.encode(jsonEncode(payload))).replaceAll('=', '')}';
  }

  static Future<File> _createConfigFile(String instanceId) async {
    final data = MultiInstanceSettingsSource.export(includeSensitiveData: true);

    final directory = await Directory.systemTemp.createTemp(configDirectoryPrefix);

    final file = File(p.join(directory.path, '$instanceId.json'));

    await file.writeAsString(const JsonEncoder.withIndent('  ').convert(data), flush: true);

    return file;
  }

  static List<String> buildArguments({
    LiveRoom? liveroom,
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
      if (liveroom != null) encodeRoomArgument(liveroom),
    ];
  }

  static Future<void> launch({LiveRoom? liveroom}) async {
    if (!Platform.isWindows) return;

    final timestampMicros = DateTime.now().microsecondsSinceEpoch;

    final id = sanitizeInstanceId('window_${pid}_$timestampMicros');

    File? configFile;

    try {
      configFile = await _createConfigFile(id);

      final executable = Platform.resolvedExecutable;

      await Process.start(
        executable,
        buildArguments(liveroom: liveroom, instanceId: id, configFile: configFile.path),
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
