// Module: test/backup_test.dart
// Purpose: Verify manifest validation, credential refusal on both ends and per-domain failure isolation.
// Author: liuchuancong
// Created: 2026-10-08
import 'package:pure_live_backup/pure_live_backup.dart';
import 'package:pure_live_utils/pure_live_utils.dart';
import 'package:test/test.dart';

bool _isCredentialKey(String key) => key.startsWith('auth.secret.');

final class _Source implements DomainSource {
  _Source(this.name, this.values);

  @override
  final String name;
  final Map<String, Object?> values;

  @override
  Future<Map<String, Object?>> snapshot() async => values;
}

final class _Target implements DomainTarget {
  _Target(this.name, {this.fail = false});

  @override
  final String name;
  final bool fail;
  Map<String, Object?>? received;

  @override
  Future<void> restore(Map<String, Object?> values) async {
    if (fail) {
      throw StateError('disk full');
    }
    received = values;
  }
}

void main() {
  final clock = FixedClock(DateTime.utc(2026, 10, 8, 9));

  test('test_backupEngine_snapshotsEveryDomainAndTotalsBytes', () async {
    final engine = BackupEngine(
      sources: <DomainSource>[
        _Source('settings', <String, Object?>{'player.engine': 'mpv'}),
        _Source('favorites', <String, Object?>{
          'list': <String>['a', 'b'],
        }),
      ],
      isCredentialKey: _isCredentialKey,
      appVersion: '4.0.0+5000',
    );

    final bundle = await engine.build(clock: clock);

    expect(bundle.manifest.domainNames, <String>['settings', 'favorites']);
    expect(bundle.manifest.appVersion, '4.0.0+5000');
    expect(bundle.manifest.createdAt, DateTime.utc(2026, 10, 8, 9));
    expect(bundle.manifest.totalBytes, greaterThan(0));
    expect(bundle.payload['settings']!['player.engine'], 'mpv');
  });

  test('test_backupEngine_neverWritesCredentialKeys', () async {
    final engine = BackupEngine(
      sources: <DomainSource>[
        _Source('settings', <String, Object?>{'player.engine': 'mpv', 'auth.secret.bilibili.uid': 'super-private'}),
      ],
      isCredentialKey: _isCredentialKey,
    );

    final bundle = await engine.build(clock: clock);
    final text = bundle.payload.values.expand((map) => map.keys).join(',');

    expect(text, isNot(contains('auth.secret.')));
    expect(text, isNot(contains('super-private')));
    expect(bundle.manifest.includesCredentials, isFalse);
  });

  test('test_backupManifest_jsonRoundTrip_keepsDomains', () {
    final manifest = BackupManifest(
      schemaVersion: 1,
      appVersion: '4.0.0+5000',
      createdAt: DateTime.utc(2026, 10, 8, 9),
      domains: const <BackupDomain>[BackupDomain(name: 'settings', keyCount: 2, bytes: 40)],
    );

    final decoded = BackupManifest.fromJson(manifest.toJson());

    expect(decoded.schemaVersion, 1);
    expect(decoded.domains.single.name, 'settings');
    expect(decoded.domains.single.bytes, 40);
    expect(decoded.validate(supportedSchemaVersions: const <int>{1}), isNull);
  });

  test('test_backupManifest_validate_rejectsUnsupportedVersion', () {
    final manifest = BackupManifest(
      schemaVersion: 9,
      appVersion: 'x',
      createdAt: DateTime.utc(2026, 1, 1),
      domains: <BackupDomain>[],
    );

    expect(manifest.validate(supportedSchemaVersions: const <int>{1}), contains('unsupported'));
  });

  test('test_backupManifest_validate_rejectsClaimedCredentialsAndDuplicates', () {
    final claiming = BackupManifest(
      schemaVersion: 1,
      appVersion: 'x',
      createdAt: DateTime.utc(2026),
      includesCredentials: true,
      domains: const <BackupDomain>[],
    );
    final duplicated = BackupManifest(
      schemaVersion: 1,
      appVersion: 'x',
      createdAt: DateTime.utc(2026, 1, 1),
      domains: <BackupDomain>[
        BackupDomain(name: 'a', keyCount: 0, bytes: 0),
        BackupDomain(name: 'a', keyCount: 0, bytes: 0),
      ],
    );

    expect(claiming.validate(supportedSchemaVersions: const <int>{1}), contains('credentials'));
    expect(duplicated.validate(supportedSchemaVersions: const <int>{1}), contains('duplicate'));
  });

  test('test_restoreEngine_appliesEachDomainAndReportsThem', () async {
    final settings = _Target('settings');
    final favorites = _Target('favorites');
    final bundle = await BackupEngine(
      sources: <DomainSource>[
        _Source('settings', <String, Object?>{'a': 1}),
        _Source('favorites', <String, Object?>{'b': 2}),
      ],
      isCredentialKey: _isCredentialKey,
    ).build(clock: clock);

    final report = await RestoreEngine(
      targets: <DomainTarget>[settings, favorites],
      isCredentialKey: _isCredentialKey,
    ).apply(bundle);

    expect(report.isComplete, isTrue);
    expect(report.appliedDomains, <String>['settings', 'favorites']);
    expect(settings.received!['a'], 1);
  });

  test('test_restoreEngine_oneFailingDomain_doesNotStopTheRest', () async {
    final bundle = await BackupEngine(
      sources: <DomainSource>[
        _Source('broken', <String, Object?>{'a': 1}),
        _Source('healthy', <String, Object?>{'b': 2}),
      ],
      isCredentialKey: _isCredentialKey,
    ).build(clock: clock);

    final report = await RestoreEngine(
      targets: <DomainTarget>[_Target('broken', fail: true), _Target('healthy')],
      isCredentialKey: _isCredentialKey,
    ).apply(bundle);

    expect(report.failedDomains, <String>['broken']);
    expect(report.appliedDomains, <String>['healthy']);
    expect(report.isComplete, isFalse);
  });

  test('test_restoreEngine_retryOnlyTheFailedDomain', () async {
    final bundle = await BackupEngine(
      sources: <DomainSource>[
        _Source('one', <String, Object?>{'a': 1}),
        _Source('two', <String, Object?>{'b': 2}),
      ],
      isCredentialKey: _isCredentialKey,
    ).build(clock: clock);
    final retried = _Target('two');

    final report = await RestoreEngine(
      targets: <DomainTarget>[_Target('one'), retried],
      isCredentialKey: _isCredentialKey,
    ).apply(bundle, onlyDomains: <String>{'two'});

    expect(report.results['one'], DomainOutcome.skipped);
    expect(report.results['two'], DomainOutcome.applied);
    expect(retried.received!['b'], 2);
  });

  test('test_restoreEngine_refusesCredentialKeysInAHandEditedArchive', () async {
    final target = _Target('settings');
    final manifest = BackupManifest(
      schemaVersion: 1,
      appVersion: 'x',
      createdAt: DateTime.utc(2026, 1, 1),
      domains: <BackupDomain>[BackupDomain(name: 'settings', keyCount: 2, bytes: 20)],
    );
    final bundle = BackupBundle(
      manifest: manifest,
      payload: <String, Map<String, Object?>>{
        'settings': <String, Object?>{'player.engine': 'mpv', 'auth.secret.bilibili.uid': 'stolen'},
      },
    );

    final report = await RestoreEngine(
      targets: <DomainTarget>[target],
      isCredentialKey: _isCredentialKey,
    ).apply(bundle);

    expect(report.skippedCredentials, 1);
    expect(target.received!.keys, <String>['player.engine']);
  });

  test('test_restoreEngine_unknownDomainIsSkippedNotFailed', () async {
    final bundle = await BackupEngine(
      sources: <DomainSource>[
        _Source('legacy', <String, Object?>{'a': 1}),
      ],
      isCredentialKey: _isCredentialKey,
    ).build(clock: clock);

    final report = await RestoreEngine(
      targets: <DomainTarget>[_Target('settings')],
      isCredentialKey: _isCredentialKey,
    ).apply(bundle);

    expect(report.results['legacy'], DomainOutcome.skipped);
    expect(report.isComplete, isTrue);
  });

  test('test_restoreEngine_unsupportedVersion_throwsBeforeTouchingAnything', () async {
    final target = _Target('settings');
    final bundle = BackupBundle(
      manifest: BackupManifest(
        schemaVersion: 7,
        appVersion: 'x',
        createdAt: DateTime.utc(2026),
        domains: const <BackupDomain>[BackupDomain(name: 'settings', keyCount: 1, bytes: 1)],
      ),
      payload: const <String, Map<String, Object?>>{
        'settings': <String, Object?>{'a': 1},
      },
    );

    await expectLater(
      RestoreEngine(targets: <DomainTarget>[target], isCredentialKey: _isCredentialKey).apply(bundle),
      throwsA(isA<FormatException>()),
    );
    expect(target.received, isNull);
  });
}
