// Module: test/data/webdav_backup_service_test.dart
// Purpose: Pins push reporting, listing order, restore retry, and the snapshot-name guard.
// Author: liuchuancong
// Created: 2026-10-10

import 'package:pure_live_backup/pure_live_backup.dart';
import 'package:pure_live_backup_feature/pure_live_backup_feature.dart';
import 'package:test/test.dart';

import '../support/backup_fakes.dart';

void main() {
  late InMemoryRemote remote;
  late List<DomainSource> sources;
  late List<DomainTarget> targets;
  late WebDavBackupService service;

  setUp(() {
    remote = InMemoryRemote();
    sources = <DomainSource>[
      FakeSource('settings', <String, Object?>{'quality': '原画', 'auth.token': 'nope'}),
      FakeSource('favorites', <String, Object?>{'a': 1, 'b': 2}),
    ];
    targets = <DomainTarget>[FakeTarget('settings'), FakeTarget('favorites')];
    service = WebDavBackupService(
      remote: remote,
      engine: BackupEngine(sources: sources, isCredentialKey: fakeIsCredentialKey),
      restoreEngine: RestoreEngine(targets: targets, isCredentialKey: fakeIsCredentialKey),
      snapshotName: 'purelive-backup.json',
    );
  });

  test('test_webDavBackupService_push_reportsWhatItWrote', () async {
    final contents = await service.push();

    expect(contents.domains, <String>['settings', 'favorites']);
    expect(contents.keyCount, 3, reason: 'the credential key was excluded by the engine');
    expect(contents.snapshotName, 'purelive-backup.json');
    expect(remote.files['purelive-backup.json'], isNotNull);
  });

  test('test_webDavBackupService_pushFailure_isNamedAndKeepsTheCause', () async {
    remote.failNextUpload = StateError('401 from dav.example.com');

    await expectLater(
      service.push(),
      throwsA(
        isA<BackupServiceFailure>()
            .having((error) => error.cause, 'cause', isA<StateError>())
            .having((error) => error.reason, 'reason', contains('purelive-backup.json')),
      ),
    );
    expect(remote.uploadCount, 0);
  });

  test('test_webDavBackupService_preview_uploadsNothing', () async {
    final contents = await service.preview();

    expect(contents.domains, hasLength(2));
    expect(remote.uploadCount, 0);
  });

  test('test_webDavBackupService_listRemote_isNewestFirst', () async {
    remote.listings.addAll(<SnapshotListing>[
      SnapshotListing(name: 'old.json', sizeBytes: 10, modifiedAt: DateTime.utc(2026, 1, 1)),
      SnapshotListing(name: 'new.json', sizeBytes: 20, modifiedAt: DateTime.utc(2026, 9, 9)),
      SnapshotListing(name: 'mid.json', sizeBytes: 15, modifiedAt: DateTime.utc(2026, 5, 5)),
    ]);

    final listed = await service.listRemote();
    expect(listed.map((snapshot) => snapshot.name), <String>['new.json', 'mid.json', 'old.json']);
    expect(listed.first.size.humanReadable, '20 B');
  });

  test('test_webDavBackupService_restore_appliesEveryDomainAndRefusesCredentials', () async {
    await service.push();
    final report = await service.restore('purelive-backup.json');

    expect(report.isComplete, isTrue);
    expect(report.applied, <String>['settings', 'favorites']);
    expect((targets.first as FakeTarget).restored.single, <String, Object?>{'quality': '原画'});
    expect(report.refusedCredentialKeys, 0, reason: 'they never entered the archive in the first place');
  });

  test('test_webDavBackupService_restoreNewest_picksTheLatestListing', () async {
    await service.push();
    remote.listings.add(
      SnapshotListing(name: 'older-sibling.json', sizeBytes: 5, modifiedAt: DateTime.utc(2020, 1, 1)),
    );

    final report = await service.restoreNewest();
    expect(report.applied, contains('settings'));
  });

  test('test_webDavBackupService_restoreNewest_withoutAnySnapshot_isNamed', () async {
    await expectLater(service.restoreNewest(), throwsA(isA<BackupServiceFailure>()));
  });

  test('test_webDavBackupService_retry_touchesOnlyWhatFailed', () async {
    await service.push();
    final bundle = await decodeBackupDocument(await remote.download('purelive-backup.json'));

    (targets.first as FakeTarget).failOnce = true;
    final failed = await service.restore('purelive-backup.json');
    expect(failed.failed, <String>['settings']);
    expect(failed.retrySet, <String>{'settings'});

    final retried = await service.retry(bundle, failed);
    expect(retried.applied, <String>['settings']);
    expect(retried.isComplete, isTrue);
    // 'favorites' landed on the first pass and must not be re-written by the retry.
    expect((targets.last as FakeTarget).restored, hasLength(1));
  });

  test('test_webDavBackupService_retry_ofACompleteReport_doesNotTouchDataAgain', () async {
    await service.push();
    final bundle = await decodeBackupDocument(await remote.download('purelive-backup.json'));
    final complete = await service.restore('purelive-backup.json');

    final repeated = await service.retry(bundle, complete);
    expect(repeated, same(complete));
    expect((targets.last as FakeTarget).restored, hasLength(1), reason: 'favorites was not re-applied');
  });

  test('test_webDavBackupService_rejectsANameThatWouldLeaveTheDirectory', () {
    for (final name in <String>['../escape.json', 'a/b.json', r'a\b.json', '..', 'x\ndata.json', '  ']) {
      expect(
        () => WebDavBackupService(
          remote: remote,
          engine: BackupEngine(sources: sources, isCredentialKey: fakeIsCredentialKey),
          restoreEngine: RestoreEngine(targets: targets, isCredentialKey: fakeIsCredentialKey),
          snapshotName: name,
        ),
        throwsA(anyOf(isA<BackupServiceFailure>(), isA<ArgumentError>())),
        reason: '"$name" must not become a path component',
      );
    }
  });

  test('test_webDavBackupService_downloadFailure_isNamed', () async {
    await service.push();
    remote.failNextDownload = StateError('connection reset');

    await expectLater(
      service.restore('purelive-backup.json'),
      throwsA(isA<BackupServiceFailure>().having((error) => error.cause, 'cause', isA<StateError>())),
    );
  });
}
