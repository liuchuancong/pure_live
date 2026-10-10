// Module: test/preferences_store_test.dart
// Purpose: Pin the preference mechanism: envelope, codec strictness, namespace, import reporting and upgrades.
// Author: liuchuancong
// Created: 2026-10-10
//
// This package shipped its 491-line mechanism without a single test (the README says so, at the user's
// instruction for that round). These cases are what makes the documented rules checkable: a read that never
// throws, a write that refuses an out-of-range value, and the one path that decides whether adopting the store
// is safe for existing user data - the legacy upgrade hook.
import 'dart:async';

import 'package:pure_live_storage/pure_live_storage.dart';
import 'package:test/test.dart';

const PreferenceKey<bool> _switch = PreferenceKey<bool>(
  name: 'player.autoPlay',
  codec: PreferenceCodec.boolean,
  defaultValue: false,
);

const PreferenceKey<int> _pageSize = PreferenceKey<int>(
  name: 'feed.pageSize',
  codec: PreferenceCodec.integer,
  defaultValue: 20,
);

const PreferenceKey<double> _opacity = PreferenceKey<double>(
  name: 'background.opacity',
  codec: PreferenceCodec.real,
  defaultValue: 1,
);

const PreferenceKey<String> _label = PreferenceKey<String>(
  name: 'app.quality',
  codec: PreferenceCodec.string,
  defaultValue: 'auto',
);

const PreferenceKey<List<String>> _order = PreferenceKey<List<String>>(
  name: 'home.order',
  codec: PreferenceCodec.stringList,
  defaultValue: <String>[],
);

/// The same key, with the range rule the consumer owns.
const PreferenceKey<int> _boundedPageSize = PreferenceKey<int>(
  name: 'feed.pageSize',
  codec: PreferenceCodec.integer,
  defaultValue: 20,
  validate: _isPageSane,
);

bool _isPageSane(int value) => value >= 1 && value <= 100;

/// The order key with a declared legacy reader: features/home wrote `{v, order, hidden}` before this
/// mechanism existed, and a bare list is what an even older build stored.
PreferenceKey<List<String>> _legacyOrder({Object? Function(Object? raw)? upgrade}) => PreferenceKey<List<String>>(
  name: 'home.order',
  codec: PreferenceCodec.stringList,
  defaultValue: const <String>['live'],
  upgrade:
      upgrade ??
      (Object? raw) {
        if (raw is List) {
          return raw;
        }
        if (raw is Map && raw['order'] is List) {
          return raw['order'];
        }
        return null;
      },
);

void main() {
  late MemoryKeyValueStore disk;
  late PreferencesStore store;

  setUp(() {
    disk = MemoryKeyValueStore();
    store = PreferencesStore(store: disk);
  });

  tearDown(() async {
    await store.dispose();
  });

  group('reads never throw', () {
    test('test_read_absentKey_answersTheDefault', () async {
      expect(await store.read(_switch), isFalse);
      expect(await store.read(_pageSize), 20);
      expect(await store.readIfStored(_pageSize), isNull, reason: 'unset must stay distinguishable from set');
    });

    test('test_read_afterWrite_roundTripsEveryBuiltInCodec', () async {
      await store.write(_switch, true);
      await store.write(_pageSize, 30);
      await store.write(_opacity, 0.5);
      await store.write(_label, 'hd');
      await store.write(_order, <String>['live', 'vod']);

      expect(await store.read(_switch), isTrue);
      expect(await store.read(_pageSize), 30);
      expect(await store.read(_opacity), 0.5);
      expect(await store.read(_label), 'hd');
      expect(await store.read(_order), <String>['live', 'vod']);
    });

    test('test_read_storedDouble_isRefusedByTheIntegerKey', () async {
      // The closed codec set exists so a wrong-type read is not stringified into a plausible value: `'${5}'`
      // turns a stored number into '5' and the next write keeps the wrong type forever.
      await store.write(_opacity, 2.5);

      final intKey = PreferenceKey<int>(name: 'background.opacity', codec: PreferenceCodec.integer, defaultValue: 1);
      expect(await store.read(intKey), 1);
      expect(store.rejections.single.failure, PreferenceFailure.codecMismatch);
    });

    test('test_read_intValueUnderADoubleCodec_isStillANumber', () async {
      // Losing precision only goes the other way, so a writer that stored a whole number under the double
      // codec stays readable. The codec name in the envelope is what gates the read, not the JSON type.
      await disk.write('settings.feed.pageSize', <String, Object?>{'v': 1, 'c': 'double', 'value': 44});

      final doubleKey = PreferenceKey<double>(name: 'feed.pageSize', codec: PreferenceCodec.real, defaultValue: 1);
      expect(await store.read(doubleKey), 44.0);
      expect(store.rejections, isEmpty);
    });

    test('test_read_intWrittenRow_refusedByADoubleKeyBecauseTheCodecNameDiffers', () async {
      await store.write(_pageSize, 44);

      final doubleKey = PreferenceKey<double>(name: 'feed.pageSize', codec: PreferenceCodec.real, defaultValue: 1);
      expect(await store.read(doubleKey), 1);
      expect(store.rejections.single.failure, PreferenceFailure.codecMismatch);
    });

    test('test_read_garbageEnvelope_shapeIsReportedNotThrown', () async {
      await disk.write('settings.app.quality', <String, Object?>{'v': 1, 'c': 'string', 'value': 42});

      expect(await store.read(_label), 'auto');
      expect(store.rejections.single.failure, PreferenceFailure.unreadableEnvelope);
    });

    test('test_read_valueOutsideTheKeysRule_fallsBackAndReports', () async {
      await store.write(_pageSize, 5000);

      expect(await store.read(_boundedPageSize), 20);
      expect(store.rejections.single.failure, PreferenceFailure.invalidValue);
    });
  });

  group('writes refuse', () {
    test('test_write_outOfRange_throwsNamedAndStoresNothing', () async {
      await expectLater(
        store.write(_boundedPageSize, 0),
        throwsA(isA<PreferenceException>().having((error) => error.failure, 'failure', PreferenceFailure.invalidValue)),
      );

      expect(await store.isStored(_boundedPageSize), isFalse);
      expect(store.rejections.single.keyName, 'feed.pageSize');
    });

    test('test_write_storesAnEnvelopeWithVersionAndCodec', () async {
      await store.write(_label, 'hd');

      // The namespace prefix is the only thing separating two apps that share one store file.
      final raw = await disk.read('settings.app.quality');
      expect(raw, <String, Object?>{'v': kPreferenceEnvelopeVersion, 'c': 'string', 'value': 'hd'});
    });

    test('test_write_stringList_keepsAnIdContainingADotRatherThanJoining', () async {
      await store.write(_order, <String>['a.b', 'c']);

      final raw = await disk.read('settings.home.order') as Map;
      expect(raw['value'], <String>['a.b', 'c']);
      expect(await store.read(_order), <String>['a.b', 'c']);
    });
  });

  group('first-run and reset', () {
    test('test_putIfAbsent_answersTrueOnlyForTheUntouchedKey', () async {
      expect(await store.putIfAbsent(_switch, true), isTrue);
      expect(await store.putIfAbsent(_switch, false), isFalse);
      expect(await store.read(_switch), isTrue, reason: 'the first-run value must survive a later default write');
    });

    test('test_putIfAbsent_treatsAGarbageRowAsAbsent', () async {
      // The point of the primitive: a key the user set back to its default is *stored*, so putIfAbsent must
      // not overwrite it, while a key nobody ever wrote is.
      await disk.write('settings.app.quality', 'not an envelope');

      expect(await store.putIfAbsent(_label, 'sd'), isTrue);
      expect(await store.read(_label), 'sd');
    });

    test('test_reset_removesTheRowAndTheKeyAnswersDefaultAgain', () async {
      await store.write(_label, 'hd');
      await store.reset(_label);

      expect(await store.isStored(_label), isFalse);
      expect(await store.read(_label), 'auto');
    });
  });

  group('namespaces', () {
    test('test_namespace_twoAppsWithOneStoreFileDoNotReadEachOther', () async {
      final other = PreferencesStore(store: disk, namespace: 'bili.');
      await store.write(_label, 'hd');

      expect(await other.read(_label), 'auto');
      expect(other.rejections, isEmpty, reason: 'a key that was never written is not a rejection');

      await other.write(_label, 'sd');
      expect(await store.read(_label), 'hd');
      await other.dispose();
    });

    test('test_exportAll_reportsOnlyThisNamespacesRows', () async {
      final other = PreferencesStore(store: disk, namespace: 'bili.');
      await store.write(_label, 'hd');
      await other.write(_label, 'sd');

      // The backup a store hands out is the namespace it owns: a restore that swept another app's rows in
      // would overwrite a different product's settings from a file that never mentioned them.
      expect((await store.exportAll()).keys, <String>['app.quality']);
      expect((await other.exportAll()).keys, <String>['app.quality']);
      await other.dispose();
    });
  });

  group('change stream', () {
    test('test_changes_writeAnnouncesAndResetAnnouncesTheDefault', () async {
      final seen = <PreferenceChange>[];
      final subscription = store.changes.listen(seen.add);

      await store.write(_pageSize, 40);
      await store.reset(_pageSize);
      await Future<void>.delayed(Duration.zero);

      expect(seen.map((change) => change.value), <Object>[40, 20]);
      expect(seen.last.wasDefault, isTrue);
      expect(seen.first.keyName, 'feed.pageSize');
      await subscription.cancel();
    });

    test('test_changes_aLateListenerMissesEarlierWrites', () async {
      // Documented by design: the store is not a log, and a settings screen reads first then subscribes.
      await store.write(_pageSize, 40);

      final seen = <PreferenceChange>[];
      final subscription = store.changes.listen(seen.add);
      await store.write(_pageSize, 50);
      await Future<void>.delayed(Duration.zero);

      expect(seen.map((change) => change.value), <Object>[50]);
      await subscription.cancel();
    });

    test('test_dispose_closesTheStreamAndIsIdempotent', () async {
      final done = Completer<void>();
      final subscription = store.changes.listen((change) {}, onDone: done.complete);

      await store.dispose();
      await store.dispose();
      await done.future.timeout(const Duration(seconds: 1));
      await subscription.cancel();

      // A write after dispose still lands on disk; only the announcement is gone, because the stream is closed.
      await store.write(_pageSize, 60);
      expect(await store.read(_pageSize), 60);
    });
  });

  group('backup round trip', () {
    test('test_exportAll_importAll_roundTripsIntoAFreshStore', () async {
      await store.write(_label, 'hd');
      await store.write(_pageSize, 30);
      final backup = await store.exportAll();

      final restored = PreferencesStore(store: disk);
      final report = await restored.importAll(backup, keys: <PreferenceKeyInfo>[_label, _pageSize]);

      expect(report.accepted, 2);
      expect(report.rejected, 0);
      expect(await restored.read(_label), 'hd');
      await restored.dispose();
    });

    test('test_importAll_unknownName_isRejectedWhileTheRestLands', () async {
      // A partial restore is the useful outcome; all-or-nothing is a restore that never happens.
      final report = await store.importAll(
        <String, Object?>{
          'app.quality': <String, Object?>{'v': 1, 'c': 'string', 'value': 'hd'},
          'not.a.key': <String, Object?>{'v': 1, 'c': 'string', 'value': 'x'},
        },
        keys: <PreferenceKeyInfo>[_label],
      );

      expect(report.accepted, 1);
      expect(report.rejected, 1);
      expect(report.unknownKeys, <String>['not.a.key']);
      expect(await store.read(_label), 'hd');
    });

    test('test_importAll_wrongCodecClaimed_isRejectedNotStored', () async {
      final report = await store.importAll(
        <String, Object?>{
          'app.quality': <String, Object?>{'v': 1, 'c': 'int', 'value': 7},
        },
        keys: <PreferenceKeyInfo>[_label],
      );

      expect(report.rejected, 1);
      expect(await store.isStored(_label), isFalse);
      expect(store.rejections.last.failure, PreferenceFailure.codecMismatch);
    });

    test('test_importAll_withoutOverwrite_leavesAnExistingRowAlone', () async {
      await store.write(_label, 'hd');

      final report = await store.importAll(
        <String, Object?>{
          'app.quality': <String, Object?>{'v': 1, 'c': 'string', 'value': 'sd'},
        },
        keys: <PreferenceKeyInfo>[_label],
        overwrite: false,
      );

      expect(report.skipped, 1);
      expect(await store.read(_label), 'hd');
    });

    test('test_importAll_aValueFromTheFutureIsNotAccepted', () async {
      // Widening the readable version belongs with a migration, not with a failed read.
      final report = await store.importAll(
        <String, Object?>{
          'app.quality': <String, Object?>{'v': kPreferenceEnvelopeVersion + 1, 'c': 'string', 'value': 'hd'},
        },
        keys: <PreferenceKeyInfo>[_label],
      );

      expect(report.rejected, 1);
      expect(await store.isStored(_label), isFalse);
    });
  });

  group('legacy upgrade', () {
    test('test_read_legacyDocument_withoutAnEnvelope_isUpgradedNotDiscarded', () async {
      // This is the case that decides whether adopting the mechanism is safe: without the hook the row is
      // unreadable, the key answers its default, and the next write persists that default as the user's choice.
      await disk.write('settings.home.order', <String, Object?>{
        'v': 1,
        'order': <String>['vod', 'live'],
      });
      final key = _legacyOrder();

      expect(await store.read(key), <String>['vod', 'live']);
      expect(store.rejections, isEmpty);
      expect(store.upgradedKeys, <String>['home.order']);
    });

    test('test_read_aBareListOfStringsIsAlsoRecognisedAsLegacy', () async {
      await disk.write('settings.home.order', <String>['live']);

      expect(await store.read(_legacyOrder()), <String>['live']);
    });

    test('test_read_upgrade_doesNotRewriteTheRow', () async {
      await disk.write('settings.home.order', <String>['live']);
      final key = _legacyOrder();

      await store.read(key);
      await store.read(key);

      // A screen that came to display a value must not be the thing that mutates storage. Rewriting is a
      // SchemaMigrator step's job, and upgradedKeys is how the caller learns there is work to do.
      expect(await disk.read('settings.home.order'), <String>['live']);
      expect(store.upgradedKeys, <String>['home.order'], reason: 'reported once, not once per read');
    });

    test('test_read_upgradeRefused_fallsBackAndReportsAnUnreadableEnvelope', () async {
      await disk.write('settings.home.order', 17);
      final key = _legacyOrder(upgrade: (raw) => null);

      expect(await store.read(key), <String>['live']);
      expect(store.upgradedKeys, isEmpty);
      expect(store.rejections.single.failure, PreferenceFailure.unreadableEnvelope);
    });

    test('test_read_upgradeValueFailingTheCodec_isRejected', () async {
      await disk.write('settings.home.order', <String, Object?>{
        'order': <Object>[1, 2],
      });
      final key = _legacyOrder(upgrade: (raw) => (raw as Map)['order']);

      expect(await store.read(key), <String>['live']);
      expect(store.rejections.single.failure, PreferenceFailure.unreadableEnvelope);
    });

    test('test_read_upgradedValueStillMeetsTheKeysOwnRule', () async {
      await disk.write('settings.feed.pageSize', <String, Object?>{'size': 5000});
      final key = PreferenceKey<int>(
        name: 'feed.pageSize',
        codec: PreferenceCodec.integer,
        defaultValue: 20,
        validate: _isPageSane,
        upgrade: (raw) => raw is Map ? raw['size'] : null,
      );

      expect(await store.read(key), 20);
      expect(store.rejections.single.failure, PreferenceFailure.invalidValue);
    });

    test('test_write_afterAnUpgrade_replacesTheLegacyRowWithAnEnvelope', () async {
      await disk.write('settings.home.order', <String>['vod']);
      final key = _legacyOrder();

      await store.write(key, <String>['vod']);

      final raw = await disk.read('settings.home.order') as Map;
      expect(raw['c'], 'stringList');
      expect(raw['v'], kPreferenceEnvelopeVersion);
    });
  });

  group('codec refusal', () {
    test('test_read_codecRefusesWithValue_reportsItsReasonUnderItsOwnFailure', () async {
      // "unreadable" is several facts with different fixes, so a refusal must not be folded into the shape
      // bucket. A newer row is handled by updating the app; a row missing its list is damage.
      final key = PreferenceKey<int>(
        name: 'feed.pageSize',
        codec: PreferenceCodec.of<int>('storingSize', (Object? raw) {
          if (raw is Map && raw['v'] == 99) {
            throw const PreferenceDecodeReject('written by a newer build (v99)');
          }
          return null;
        }, (int value) => value),
        defaultValue: 20,
      );
      await disk.write('settings.feed.pageSize', <String, Object?>{
        'v': 1,
        'c': 'storingSize',
        'value': {'v': 99},
      });

      expect(await store.read(key), 20);
      expect(store.rejections.single.failure, PreferenceFailure.refusedByCodec);
      expect(store.rejections.single.reason, contains('newer build'));
    });

    test('test_read_codecThrowsSomethingElse_isNotTreatedAsData', () async {
      // Only PreferenceDecodeReject is a refusal. Anything else out of a codec is a bug in it, and turning that
      // into a default value would hide a crash behind a plausible-looking setting.
      final key = PreferenceKey<int>(
        name: 'feed.pageSize',
        codec: PreferenceCodec.of<int>(
          'brokenSize',
          (Object? raw) => throw StateError('codec bug'),
          (int value) => value,
        ),
        defaultValue: 20,
      );
      await disk.write('settings.feed.pageSize', <String, Object?>{'v': 1, 'c': 'brokenSize', 'value': 30});

      expect(() => store.read(key), throwsStateError);
      expect(store.rejections, isEmpty);
    });

    test('test_read_legacyUpgradeRefusal_alsoCarriesTheReason', () async {
      // Both read paths run the same codec, so the reason survives whichever shape the disk holds.
      final key = PreferenceKey<int>(
        name: 'feed.pageSize',
        codec: PreferenceCodec.of<int>('storingSize', (Object? raw) {
          if (raw is Map) {
            throw const PreferenceDecodeReject('legacy row has no size field');
          }
          return null;
        }, (int value) => value),
        defaultValue: 20,
        upgrade: (Object? raw) => raw,
      );
      await disk.write('settings.feed.pageSize', <String, Object>{'old': 1});

      expect(await store.read(key), 20);
      expect(store.rejections.single.failure, PreferenceFailure.refusedByCodec);
      expect(store.rejections.single.reason, contains('no size field'));
      expect(store.upgradedKeys, isEmpty, reason: 'a refused legacy row was never upgraded');
    });

    test('test_preferenceRejection_toString_prefersTheReasonOverTheType', () {
      const withReason = PreferenceRejection(
        keyName: 'a',
        failure: PreferenceFailure.refusedByCodec,
        reason: 'no size field',
      );
      const withType = PreferenceRejection(
        keyName: 'a',
        failure: PreferenceFailure.unreadableEnvelope,
        rawType: 'String',
      );

      expect(withReason.toString(), 'PreferenceRejection(a refusedByCodec: no size field)');
      expect(withType.toString(), 'PreferenceRejection(a unreadableEnvelope: was String)');
    });
  });

  group('diagnostics stay bounded', () {
    test('test_rejections_aRepeatedlyBrokenRow_doesNotGrowTheLog', () async {
      // A screen that polls a preference would otherwise accumulate one entry per read for as long as the row
      // stays broken, and the log grows with how damaged the disk is rather than with anything useful.
      await disk.write('settings.app.quality', 'not an envelope');

      for (var attempt = 0; attempt < kPreferenceRejectionLimit * 3; attempt++) {
        await store.read(_label);
      }

      expect(store.rejections, hasLength(kPreferenceRejectionLimit));
      expect(store.rejections.every((r) => r.keyName == 'app.quality'), isTrue);
    });

    test('test_rejections_theOldestEntriesLeaveFirst', () async {
      for (final name in <String>['one', 'two', 'three']) {
        await disk.write('settings.$name', 'not an envelope');
      }
      final keys = <String>['one', 'two', 'three'];
      for (var index = 0; index < kPreferenceRejectionLimit + 2; index++) {
        await store.read(
          PreferenceKey<String>(name: keys[index % keys.length], codec: PreferenceCodec.string, defaultValue: 'x'),
        );
      }

      expect(store.rejections, hasLength(kPreferenceRejectionLimit));
      // 66 reads pushed the first two out, so the head of the log is the third read - which is 'three', not
      // 'one', because each key keeps reappearing and the cap drops entries, not keys.
      expect(store.rejections.first.keyName, 'three');
      expect(store.rejections.last.keyName, keys[(kPreferenceRejectionLimit + 1) % keys.length]);
    });

    test('test_upgradedKeys_oneKeyPerRow_staysBoundedButKeepsCounting', () async {
      // The shape a watch-progress repository reaches: one key per content reference, so the number of legacy
      // rows it can meet is a user's library, not a fixed settings table.
      final seen = <String>[];
      for (var index = 0; index < kPreferenceUpgradeReportLimit + 12; index++) {
        final name = 'episode${index}_$index';
        await disk.write('settings.$name', <String>['a']);
        final key = PreferenceKey<List<String>>(
          name: name,
          codec: PreferenceCodec.stringList,
          defaultValue: const <String>[],
          upgrade: (Object? raw) => raw is List ? raw : null,
        );

        expect(await store.read(key), <String>['a']);
        seen.add(name);
      }

      expect(store.upgradedKeys, hasLength(kPreferenceUpgradeReportLimit));
      expect(store.upgradedCount, seen.length, reason: 'the overflow is counted, not dropped in silence');
      expect(store.rejections, isEmpty);
    });

    test('test_upgradedCount_anAlreadyListedKeyDoesNotDoubleCount', () async {
      await disk.write('settings.home.order', <String>['a']);
      final key = _legacyOrder();

      await store.read(key);
      await store.read(key);

      expect(store.upgradedCount, 1);
    });
  });

  group('key identity', () {
    test('test_preferenceKey_equalityIsNameAndCodec', () {
      expect(
        _pageSize,
        const PreferenceKey<int>(name: 'feed.pageSize', codec: PreferenceCodec.integer, defaultValue: 8),
      );
      expect(
        _pageSize,
        isNot(const PreferenceKey<String>(name: 'feed.pageSize', codec: PreferenceCodec.string, defaultValue: 'x')),
      );
    });

    test('test_preferenceKeyInfo_letsTypeFreeApisTakeMixedKeys', () {
      final keys = <PreferenceKeyInfo>[_pageSize, _label, _order];

      expect(keys.map((key) => '${key.name}:${key.codecName}'), <String>[
        'feed.pageSize:int',
        'app.quality:string',
        'home.order:stringList',
      ]);
    });
  });
}
