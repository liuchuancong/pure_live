// Module: test/storage_test.dart
// Purpose: Verify typed store reads, key mapping migration and the versioned schema chain.
// Author: liuchuancong
// Created: 2026-10-08
import 'package:pure_live_storage/pure_live_storage.dart';
import 'package:test/test.dart';

Object? _half(Object? value) => value is int ? value ~/ 2 : value;

void _noop(KeyValueStore store) {}

void _explode(KeyValueStore store) => throw StateError('step failed');

void main() {
  group('KeyValueStore typed reads', () {
    test('test_readInt_storedString_parsesBecauseOlderStoresWroteText', () async {
      final store = MemoryKeyValueStore();
      await store.write('volume', '42');

      expect(await store.readInt('volume', fallback: -1), 42);
    });

    test('test_readInt_wrongType_fallsBack', () async {
      final store = MemoryKeyValueStore();
      await store.write('volume', 'loud');

      expect(await store.readInt('volume', fallback: -1), -1);
    });

    test('test_readBool_absentKey_returnsFallbackNotFalse', () async {
      final store = MemoryKeyValueStore();

      expect(await store.readBool('hw', fallback: true), isTrue);
    });

    test('test_readDouble_intValue_widens', () async {
      final store = MemoryKeyValueStore();
      await store.write('scale', 2);

      expect(await store.readDouble('scale'), 2.0);
    });

    test('test_keysUnder_filtersByNamespacePrefix', () async {
      final store = MemoryKeyValueStore();
      await store.write('player.engine', 'mpv');
      await store.write('player.speed', 1);
      await store.write('theme.accent', 'blue');

      expect(await keysUnder(await store.keys(), 'player'), <String>['player.engine', 'player.speed']);
    });

    test('test_memoryStore_removeAndClear_dropValues', () async {
      final store = MemoryKeyValueStore();
      await store.write('a', 1);
      await store.remove('a');
      await store.write('b', 2);
      await store.clear();

      expect(await store.read('a'), isNull);
      expect(await store.keys(), isEmpty);
    });

    test('test_secureStore_roundTripsAndListsKeys', () async {
      final secrets = MemorySecureStore();
      await secrets.writeSecret('bilibili.token', 'abc');

      expect(await secrets.readSecret('bilibili.token'), 'abc');
      expect(await secrets.secretKeys(), <String>['bilibili.token']);
      await secrets.removeSecret('bilibili.token');
      expect(await secrets.readSecret('bilibili.token'), isNull);
    });
  });

  group('SettingsMigrator', () {
    test('test_settingsMigrator_mappedKeys_landInTargetWithConversion', () async {
      final source = MemoryKeyValueStore();
      final target = MemoryKeyValueStore();
      await source.write('v1.brightness', 50);
      await source.write('v1.engine', 'mpv');

      final report = await const SettingsMigrator(
        mappings: <KeyMapping>[
          KeyMapping(from: 'v1.brightness', to: 'player.brightness', convert: _half),
          KeyMapping(from: 'v1.engine', to: 'player.engine'),
        ],
      ).run(source: source, target: target);

      expect(report.migrated, containsAll(<String>['player.brightness', 'player.engine']));
      expect(await target.readInt('player.brightness'), 25);
      expect(await target.readString('player.engine'), 'mpv');
    });

    test('test_settingsMigrator_unknownKeys_areRecordedNotDropped', () async {
      final source = MemoryKeyValueStore();
      await source.write('v1.orphan', 1);

      final report = await const SettingsMigrator(mappings: <KeyMapping>[]).run(
        source: source,
        target: MemoryKeyValueStore(),
      );

      expect(report.ignored, <String>['v1.orphan']);
      expect(report.isClean, isFalse);
    });

    test('test_settingsMigrator_failingConversion_continuesWithTheRest', () async {
      final source = MemoryKeyValueStore();
      await source.write('bad', 'x');
      await source.write('good', 'y');

      final report = await SettingsMigrator(
        mappings: <KeyMapping>[
          KeyMapping(from: 'bad', to: 'target.bad', convert: _explodeValue),
          const KeyMapping(from: 'good', to: 'target.good'),
        ],
      ).run(source: source, target: MemoryKeyValueStore());

      expect(report.failures.keys, <String>['target.bad']);
      expect(report.migrated, <String>['target.good']);
    });
  });

  group('SchemaMigrator', () {
    test('test_schemaMigrator_appliesStepsInOrderAndRecordsVersion', () async {
      final store = MemoryKeyValueStore();

      final applied = await const SchemaMigrator(
        steps: <SchemaStep>[
          SchemaStep(fromVersion: 0, describe: 'add engine key', apply: _noop),
          SchemaStep(fromVersion: 1, describe: 'widen volume', apply: _noop),
        ],
      ).migrate(store);

      expect(applied, <int>[0, 1]);
      expect(await store.readInt(schemaVersionKey), 2);
    });

    test('test_schemaMigrator_secondRun_appliesNothing', () async {
      final store = MemoryKeyValueStore();
      const migrator = SchemaMigrator(
        steps: <SchemaStep>[SchemaStep(fromVersion: 0, describe: 'first', apply: _noop)],
      );

      await migrator.migrate(store);
      final again = await migrator.migrate(store);

      expect(again, isEmpty);
      expect(await store.readInt(schemaVersionKey), 1);
    });

    test('test_schemaMigrator_midChainFailure_leavesVersionAtLastGoodStep', () async {
      final store = MemoryKeyValueStore();

      await expectLater(
        const SchemaMigrator(
          steps: <SchemaStep>[
            SchemaStep(fromVersion: 0, describe: 'ok', apply: _noop),
            SchemaStep(fromVersion: 1, describe: 'broken', apply: _explode),
          ],
        ).migrate(store),
        throwsA(isA<StateError>()),
      );

      // A retry can resume: the first step is recorded as done and the chain stops at the second again.
      expect(await store.readInt(schemaVersionKey), 1);
    });

    test('test_schemaMigrator_gapInChain_isRejectedBeforeApplying', () async {
      final store = MemoryKeyValueStore();

      await expectLater(
        const SchemaMigrator(
          steps: <SchemaStep>[
            SchemaStep(fromVersion: 0, describe: 'zero', apply: _noop),
            SchemaStep(fromVersion: 2, describe: 'skipped one', apply: _noop),
          ],
        ).migrate(store),
        throwsA(isA<StateError>().having((error) => error.message, 'message', contains('gap'))),
      );
      expect(await store.read(schemaVersionKey), isNull);
    });

    test('test_schemaMigrator_duplicateVersion_isRejected', () async {
      await expectLater(
        const SchemaMigrator(
          steps: <SchemaStep>[
            SchemaStep(fromVersion: 0, describe: 'a', apply: _noop),
            SchemaStep(fromVersion: 0, describe: 'b', apply: _noop),
          ],
        ).migrate(MemoryKeyValueStore()),
        throwsA(isA<StateError>().having((error) => error.message, 'message', contains('duplicate'))),
      );
    });

    test('test_schemaMigrator_stepsGivenOutOfOrder_stillApplyInOrder', () async {
      final store = MemoryKeyValueStore();
      final trail = <int>[];

      await SchemaMigrator(
        steps: <SchemaStep>[
          SchemaStep(fromVersion: 1, describe: 'second', apply: (s) => trail.add(1)),
          SchemaStep(fromVersion: 0, describe: 'first', apply: (s) => trail.add(0)),
        ],
      ).migrate(store);

      expect(trail, <int>[0, 1]);
    });
  });
}

Object? _explodeValue(Object? value) => throw StateError('unmappable');
