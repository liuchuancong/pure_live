import 'dart:convert';
import 'dart:io';

import 'package:hive_ce/hive.dart';
import 'package:path/path.dart' as p;

class SettingsUpgradeReport {
  const SettingsUpgradeReport({
    required this.importedSources,
    required this.favoriteCount,
    required this.historyCount,
    required this.changed,
  });

  final int importedSources;
  final int favoriteCount;
  final int historyCount;
  final bool changed;
}

/// Upgrades raw Hive values before any settings controller reads them.
///
/// Versions before 2.1 stored model collections as `List<String>`. Newer
/// controllers store the same data as a JSON object containing `list`. Copying
/// the old Hive file alone therefore made valid follows look empty. This
/// migration understands both layouts and unions data found in previous
/// installation directories.
class SettingsUpgradeMigration {
  static const int schemaVersion = 4;
  static const String _schemaKey = 'settingsUpgradeSchema';
  static const String _sourceLedgerKey = 'settingsUpgradeImportedSources';

  static const Set<String> _objectListKeys = {
    'favoriteRooms',
    'favoriteAreas',
    'historyRooms',
    'webDavConfigs',
  };

  static const Set<String> _stringListKeys = {
    'shieldList',
    'blockedDanmakuUsers',
    'hotAreasList',
    'savedMenuIds',
  };

  static Future<SettingsUpgradeReport> migrate({
    required Box<dynamic> target,
    required Iterable<String> legacyHiveFiles,
    required Directory workingDirectory,
  }) async {
    await workingDirectory.create(recursive: true);

    final targetData = <String, dynamic>{
      for (final key in target.keys.whereType<String>()) key: target.get(key),
    };
    final hadLegacyShape = _objectListKeys.any((key) => targetData[key] is List);
    final importedFingerprints = _readLedger(targetData[_sourceLedgerKey]);
    final sources = <_SettingsSource>[];

    var sourceIndex = 0;
    for (final sourcePath in legacyHiveFiles.toSet()) {
      final source = File(sourcePath);
      if (!await source.exists()) continue;
      final fingerprint = await _fingerprint(source);
      if (importedFingerprints.contains(fingerprint)) continue;

      final boxName = 'settings_upgrade_source_${sourceIndex++}';
      final copiedFile = File(p.join(workingDirectory.path, '$boxName.hive'));
      Box<dynamic>? sourceBox;
      try {
        await source.copy(copiedFile.path);
        sourceBox = await Hive.openBox<dynamic>(boxName, path: workingDirectory.path);
        final data = <String, dynamic>{
          for (final key in sourceBox.keys.whereType<String>()) key: sourceBox.get(key),
        };
        sources.add(
          _SettingsSource(fingerprint: fingerprint, data: data, score: _sourceScore(data)),
        );
      } catch (_) {
        // A damaged or currently locked legacy box must not block startup. Its
        // fingerprint is intentionally omitted so a later launch retries it.
      } finally {
        await sourceBox?.close();
        if (await copiedFile.exists()) await copiedFile.delete();
        final lock = File(p.join(workingDirectory.path, '$boxName.lock'));
        if (await lock.exists()) await lock.delete();
      }
    }

    sources.sort((a, b) => b.score.compareTo(a.score));
    final merged = mergeRawSettings(
      targetData,
      sources.map((source) => source.data),
      preferRichestSourceScalars: hadLegacyShape,
    );

    importedFingerprints.addAll(sources.map((source) => source.fingerprint));
    merged[_schemaKey] = schemaVersion;
    merged[_sourceLedgerKey] = jsonEncode(importedFingerprints.toList()..sort());
    merged['legacy_settings_migrated_to_v2'] = true;

    final changed = !_mapsEqual(targetData, merged);
    if (changed) {
      await target.putAll(merged);
      await target.flush();
    }

    return SettingsUpgradeReport(
      importedSources: sources.length,
      favoriteCount: _decodeObjectList(merged['favoriteRooms']).length,
      historyCount: _decodeObjectList(merged['historyRooms']).length,
      changed: changed,
    );
  }

  static Map<String, dynamic> mergeRawSettings(
    Map<String, dynamic> current,
    Iterable<Map<String, dynamic>> sources, {
    bool preferRichestSourceScalars = false,
  }) {
    final sourceList = sources.toList();
    final result = Map<String, dynamic>.from(current);

    if (preferRichestSourceScalars && sourceList.isNotEmpty) {
      final richest = sourceList.reduce((a, b) => _sourceScore(a) >= _sourceScore(b) ? a : b);
      for (final entry in richest.entries) {
        if (_isMigrationKey(entry.key) ||
            _objectListKeys.contains(entry.key) ||
            _stringListKeys.contains(entry.key)) {
          continue;
        }
        result[entry.key] = entry.value;
      }
    }

    for (final source in sourceList) {
      for (final entry in source.entries) {
        if (_isMigrationKey(entry.key)) continue;
        if (!result.containsKey(entry.key)) result[entry.key] = entry.value;
      }
    }

    for (final key in _objectListKeys) {
      final lists = <List<Map<String, dynamic>>>[
        _decodeObjectList(current[key]),
        ...sourceList.map((source) => _decodeObjectList(source[key])),
      ];
      final mergedList = _mergeObjectLists(key, lists);
      if (mergedList.isNotEmpty || lists.any((list) => list.isNotEmpty)) {
        result[key] = jsonEncode({'list': mergedList});
      } else if (current.containsKey(key) || sourceList.any((source) => source.containsKey(key))) {
        result[key] = jsonEncode({'list': <dynamic>[]});
      }
    }

    for (final key in _stringListKeys) {
      final values = <String>[];
      final seen = <String>{};
      for (final raw in [current[key], ...sourceList.map((source) => source[key])]) {
        if (raw is! List) continue;
        for (final value in raw) {
          final text = value?.toString() ?? '';
          if (text.isNotEmpty && seen.add(text)) values.add(text);
        }
      }
      if (values.isNotEmpty ||
          current.containsKey(key) ||
          sourceList.any((source) => source.containsKey(key))) {
        result[key] = values;
      }
    }

    return result;
  }

  static List<Map<String, dynamic>> _mergeObjectLists(
    String key,
    Iterable<List<Map<String, dynamic>>> lists,
  ) {
    final merged = <String, Map<String, dynamic>>{};
    final order = <String>[];
    for (final list in lists) {
      for (final item in list) {
        final identity = _itemIdentity(key, item);
        if (!merged.containsKey(identity)) {
          merged[identity] = Map<String, dynamic>.from(item);
          order.add(identity);
          continue;
        }
        final existing = merged[identity]!;
        for (final entry in item.entries) {
          final oldValue = existing[entry.key];
          if (_isEmpty(oldValue) && !_isEmpty(entry.value)) {
            existing[entry.key] = entry.value;
          }
        }
        if (key == 'favoriteRooms') {
          final tags = <String>{
            ..._stringValues(existing['tagIds']),
            ..._stringValues(item['tagIds']),
          };
          existing['tagIds'] = tags.toList();
        }
      }
    }
    return order.map((identity) => merged[identity]!).toList();
  }

  static List<Map<String, dynamic>> _decodeObjectList(dynamic raw) {
    dynamic decoded = raw;
    if (raw is String) {
      try {
        decoded = jsonDecode(raw);
      } catch (_) {
        return const [];
      }
    }
    if (decoded is Map) decoded = decoded['list'];
    if (decoded is! List) return const [];

    final result = <Map<String, dynamic>>[];
    for (final item in decoded) {
      dynamic value = item;
      if (item is String) {
        try {
          value = jsonDecode(item);
        } catch (_) {
          continue;
        }
      }
      if (value is Map) result.add(Map<String, dynamic>.from(value));
    }
    return result;
  }

  static String _itemIdentity(String key, Map<String, dynamic> item) {
    String fields(List<String> names) =>
        names.map((name) => item[name]?.toString().trim() ?? '').join('|');
    final identity = switch (key) {
      'favoriteRooms' || 'historyRooms' => fields(['platform', 'roomId']),
      'favoriteAreas' => fields(['platform', 'areaId']),
      'webDavConfigs' => fields(['name', 'url']),
      _ => '',
    };
    return identity.replaceAll('|', '').isNotEmpty ? identity : jsonEncode(item);
  }

  static Iterable<String> _stringValues(dynamic value) =>
      value is List ? value.map((item) => item.toString()) : const <String>[];

  static bool _isEmpty(dynamic value) =>
      value == null || value == '' || (value is List && value.isEmpty);

  static bool _isMigrationKey(String key) => key == _schemaKey || key == _sourceLedgerKey;

  static int _sourceScore(Map<String, dynamic> data) {
    var score = data.length;
    for (final key in _objectListKeys) {
      score += _decodeObjectList(data[key]).length * 10;
      if (data[key] is String) score += 4;
    }
    return score;
  }

  static Set<String> _readLedger(dynamic value) {
    if (value is! String || value.isEmpty) return <String>{};
    try {
      return Set<String>.from(jsonDecode(value) as List);
    } catch (_) {
      return <String>{};
    }
  }

  static Future<String> _fingerprint(File file) async {
    final stat = await file.stat();
    return '${file.absolute.path}|${stat.size}|${stat.modified.millisecondsSinceEpoch}';
  }

  static bool _mapsEqual(Map<String, dynamic> a, Map<String, dynamic> b) {
    try {
      return jsonEncode(a) == jsonEncode(b);
    } catch (_) {
      return false;
    }
  }
}

class _SettingsSource {
  const _SettingsSource({required this.fingerprint, required this.data, required this.score});

  final String fingerprint;
  final Map<String, dynamic> data;
  final int score;
}
