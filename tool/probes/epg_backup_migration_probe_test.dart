import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pure_live/domains/iptv/data/local/database.dart';

typedef _Rows = Map<String, List<Map<String, Object?>>>;

// This reader operates only on the rehearsal copy. It never opens the input
// snapshot with SQLite and never creates or upgrades a database implicitly.
class _SchemaSixReader extends AppDatabase {
  _SchemaSixReader(super.executor) : super.forTesting();
  @override
  int get schemaVersion => 6;
  @override
  drift.MigrationStrategy get migration => drift.MigrationStrategy(
    onCreate: (_) async => throw StateError('A verified schema 6 snapshot is required'),
    onUpgrade: (_, _, _) async => throw StateError('A verified schema 6 snapshot is required'),
  );
}

Future<_Rows> _snapshot(AppDatabase db) async {
  final tables = await db
      .customSelect(
        "SELECT name FROM sqlite_master WHERE type='table' "
        "AND (name NOT LIKE 'sqlite_%' OR name='sqlite_sequence') ORDER BY name",
      )
      .get();
  final result = <String, List<Map<String, Object?>>>{};
  for (final table in tables) {
    final name = table.read<String>('name');
    result[name] = [
      for (final row in await db.customSelect('SELECT * FROM "${name.replaceAll('"', '""')}"').get())
        Map<String, Object?>.from(row.data),
    ];
  }
  return result;
}

Map<String, String> _fingerprints(_Rows rows) => {
  for (final table in rows.entries)
    table.key: sha256
        .convert(
          utf8.encode(
            jsonEncode(
              [
                for (final row in table.value) jsonEncode({for (final key in row.keys.toList()..sort()) key: row[key]}),
              ]..sort(),
            ),
          ),
        )
        .toString(),
};

// Independent expectation from the documented schema 7 contract, without
// invoking the production identity helper or migration on the baseline rows.
_Rows _expectedSchemaSeven(_Rows before) {
  final aliases = <(String, String), String>{};
  String key(String source, String raw) => 'epg:${jsonEncode([source, raw])}';
  for (final row in before['epg_channels']!) {
    aliases[(row['source_id'] as String, row['id'] as String)] = key(
      row['source_id'] as String,
      row['channel_id'] as String,
    );
  }
  for (final row in before['epg_channels']!) {
    aliases.putIfAbsent((
      row['source_id'] as String,
      row['channel_id'] as String,
    ), () => key(row['source_id'] as String, row['channel_id'] as String));
  }
  for (final table in ['epg_programmes', 'epg_mappings']) {
    final sourceColumn = table == 'epg_mappings' ? 'epg_source_id' : 'source_id';
    for (final row in before[table]!) {
      final source = row[sourceColumn] as String;
      final old = row['epg_channel_id'] as String;
      aliases.putIfAbsent((source, old), () => key(source, old));
    }
  }
  final global = <String, Set<String>>{};
  for (final alias in aliases.entries) {
    global.putIfAbsent(alias.key.$2, () => {}).add(alias.value);
  }
  String actionReference(Map<String, Object?> action) {
    final old = action['epg_channel_id'] as String;
    final linked = <String>{};
    for (final mapping in before['epg_mappings']!) {
      if (mapping['channel_id'] != action['channel_id']) continue;
      final source = mapping['epg_source_id'] as String;
      final actionTarget = aliases[(source, old)];
      final mappingTarget = aliases[(source, mapping['epg_channel_id'] as String)];
      if (actionTarget != null && actionTarget == mappingTarget) linked.add(actionTarget);
    }
    if (linked.length == 1) return linked.single;
    final candidates = global[old];
    return candidates?.length == 1 ? candidates!.single : old;
  }

  return {
    for (final table in before.entries)
      table.key: [
        for (final row in table.value)
          {
            ...row,
            if (table.key == 'epg_channels') 'id': key(row['source_id'] as String, row['channel_id'] as String),
            if (table.key == 'epg_programmes' || table.key == 'epg_mappings')
              'epg_channel_id':
                  aliases[(
                    row[table.key == 'epg_mappings' ? 'epg_source_id' : 'source_id'] as String,
                    row['epg_channel_id'] as String,
                  )],
            if (table.key == 'epg_reminders' || table.key == 'scheduled_recordings')
              'epg_channel_id': actionReference(row),
          },
      ],
  };
}

Future<int> _version(AppDatabase db) async =>
    (await db.customSelect('PRAGMA user_version').get()).single.read<int>('user_version');

Future<void> _integrity(AppDatabase db) async {
  final rows = await db.customSelect('PRAGMA integrity_check').get();
  expect(rows.map((r) => r.data.values.single).toList(), ['ok']);
  expect(await db.customSelect('PRAGMA foreign_key_check').get(), isEmpty);
}

void main() {
  final inputPath = Platform.environment['PURELIVE_EPG_BACKUP_DB'];
  final outputRoot = Platform.environment['PURELIVE_EPG_MIGRATION_OUTPUT'];
  test(
    'verified local schema 6 backup migrates without unrelated data loss',
    () async {
      final input = File(inputPath!);
      final root = Directory(outputRoot!);
      expect(input.isAbsolute, isTrue);
      expect(root.isAbsolute, isTrue);
      expect(await input.exists(), isTrue);
      expect(await root.exists(), isTrue);
      final work = await root.createTemp('schema7-rehearsal-');
      final copy = File('${work.path}/rehearsal.db');
      final inputHashes = <String, String>{};
      for (final suffix in ['', '-wal', '-shm', '-journal']) {
        final source = File('$inputPath$suffix');
        if (!await source.exists()) continue;
        final bytes = await source.readAsBytes();
        inputHashes[suffix] = sha256.convert(bytes).toString();
        await File('${copy.path}$suffix').writeAsBytes(bytes, flush: true);
      }
      final legacy = _SchemaSixReader(NativeDatabase(copy));
      late final _Rows before;
      try {
        expect(await _version(legacy), 6);
        await _integrity(legacy);
        before = await _snapshot(legacy);
      } finally {
        await legacy.close();
      }
      final expected = _fingerprints(_expectedSchemaSeven(before));
      final watch = Stopwatch()..start();
      final db = AppDatabase.forTesting(NativeDatabase(copy));
      late final Map<String, String> actual;
      try {
        expect(await _version(db), 7);
        watch.stop();
        await _integrity(db);
        actual = _fingerprints(await _snapshot(db));
        expect(actual.keys.toSet(), expected.keys.toSet());
        for (final table in expected.keys) {
          // Hash comparisons keep private source URLs, titles and credentials
          // out of failure output. The original snapshot remains local only.
          expect(actual[table], expected[table], reason: 'table contract: $table');
        }
      } finally {
        await db.close();
      }
      final reopened = AppDatabase.forTesting(NativeDatabase(copy));
      try {
        expect(await _version(reopened), 7);
        expect(_fingerprints(await _snapshot(reopened)), actual);
        await _integrity(reopened);
      } finally {
        await reopened.close();
      }
      for (final entry in inputHashes.entries) {
        expect(sha256.convert(await File('$inputPath${entry.key}').readAsBytes()).toString(), entry.value);
      }
      final report = {
        'utc': DateTime.now().toUtc().toIso8601String(),
        'sourceVersion': 6,
        'targetVersion': 7,
        'productionMigrationElapsedMs': watch.elapsedMilliseconds,
        'tableCounts': {for (final table in before.entries) table.key: table.value.length},
        'inputHashes': inputHashes,
        'afterTableFingerprints': actual,
        'exactExpectedFieldChanges': true,
        'reopenStable': true,
        'integrityAndForeignKeys': true,
        'originalSnapshotUnchanged': true,
        'input': inputPath,
        'rehearsalCopy': copy.path,
        'deviceDatabaseMigrated': false,
        'nativeAndroidAcceptance': false,
      };
      await File('${work.path}/report.json').writeAsString('${const JsonEncoder.withIndent('  ').convert(report)}\n');
      // ignore: avoid_print
      print(
        jsonEncode({
          'result': 'passed',
          'report': '${work.path}/report.json',
          'tableCounts': report['tableCounts'],
          'productionMigrationElapsedMs': watch.elapsedMilliseconds,
        }),
      );
    },
    skip: inputPath == null || outputRoot == null,
    timeout: const Timeout(Duration(minutes: 3)),
  );
}
