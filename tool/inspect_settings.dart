import 'dart:convert';
import 'dart:io';

import 'package:hive_ce/hive.dart';

/// Prints only value types and collection counts from an app_settings Hive
/// file. User content, credentials and the migration ledger are never printed.
Future<void> main(List<String> args) async {
  if (args.length != 1) {
    stderr.writeln('Usage: dart tool/inspect_settings.dart <app_settings.hive>');
    exitCode = 64;
    return;
  }

  final source = File(args.single);
  if (!await source.exists()) {
    stderr.writeln('Settings file not found: ${source.path}');
    exitCode = 66;
    return;
  }

  final temporaryDirectory = await Directory.systemTemp.createTemp('pure_live_settings_inspect_');
  try {
    await source.copy('${temporaryDirectory.path}/verified.hive');
    Hive.init(temporaryDirectory.path);
    final box = await Hive.openBox<dynamic>('verified');
    final result = <String, dynamic>{};
    for (final key in [
      'favoriteRooms',
      'historyRooms',
      'favoriteAreas',
      'webDavConfigs',
      'shieldList',
      'blockedDanmakuUsers',
      'settingsUpgradeSchema',
      'settingsUpgradeImportedSources',
    ]) {
      final raw = box.get(key);
      dynamic decoded = raw;
      if (raw is String) {
        try {
          decoded = jsonDecode(raw);
        } catch (_) {}
      }

      if (decoded is Map && decoded['list'] is List) {
        result[key] = {'type': 'json.list', 'length': (decoded['list'] as List).length};
      } else if (decoded is List) {
        result[key] = {'type': 'list', 'length': decoded.length};
      } else {
        result[key] = {
          'type': raw.runtimeType.toString(),
          'value': key == 'settingsUpgradeImportedSources' ? '<redacted ledger>' : raw,
        };
      }
    }
    stdout.writeln(const JsonEncoder.withIndent('  ').convert(result));
    await box.close();
  } finally {
    await Hive.close();
    await temporaryDirectory.delete(recursive: true);
  }
}
