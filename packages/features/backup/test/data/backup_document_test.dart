// Module: test/data/backup_document_test.dart
// Purpose: Pins the archive wire format and the documents this build refuses to read.
// Author: liuchuancong
// Created: 2026-10-10

import 'package:pure_live_backup/pure_live_backup.dart';
import 'package:pure_live_backup_feature/pure_live_backup_feature.dart';
import 'package:test/test.dart';

import '../support/backup_fakes.dart';

void main() {
  test('test_backupDocument_roundTripsWithoutCredentials', () async {
    final built = await BackupEngine(
      sources: <DomainSource>[
        FakeSource('settings', <String, Object?>{'quality': '原画', 'auth.token': 'never export me'}),
      ],
      isCredentialKey: fakeIsCredentialKey,
    ).build();

    final read = decodeBackupDocument(encodeBackupBundle(built));

    expect(read.manifest.domainNames, <String>['settings']);
    expect(read.payload['settings'], <String, Object?>{'quality': '原画'});
    expect(read.manifest.includesCredentials, isFalse);
  });

  test('test_backupText_encodeDecode_isTheSameArchive', () async {
    final built = await BackupEngine(
      sources: <DomainSource>[
        FakeSource('history', <String, Object?>{'a': 1}),
      ],
      isCredentialKey: fakeIsCredentialKey,
    ).build();

    final read = decodeBackupDocument(decodeBackupText(encodeBackupText(built)));
    expect(read.manifest.domains.single.keyCount, 1);
    expect(read.payload['history'], <String, Object?>{'a': 1});
  });

  test('test_decodeBackupDocument_refusesAMissingPayload', () {
    expect(
      () => decodeBackupDocument(<String, Object?>{
        'manifest': <String, Object?>{'schemaVersion': 1},
      }),
      throwsA(isA<BackupFormatFailure>()),
    );
  });

  test('test_decodeBackupDocument_refusesAnArchiveClaimingCredentials', () {
    final document = <String, Object?>{
      'manifest': <String, Object?>{
        'schemaVersion': 1,
        'appVersion': '1.0.0',
        'createdAt': '2026-10-10T00:00:00.000Z',
        'includesCredentials': true,
        'domains': <Object?>[
          <String, Object?>{'name': 'settings', 'keyCount': 1, 'bytes': 4},
        ],
      },
      'payload': <String, Object?>{
        'settings': <String, Object?>{'auth.token': 'x'},
      },
    };

    expect(
      () => decodeBackupDocument(document),
      throwsA(isA<BackupFormatFailure>().having((error) => error.reason, 'reason', contains('credentials'))),
    );
  });

  test('test_decodeBackupDocument_refusesAnUnknownSchemaVersion', () {
    final document = <String, Object?>{
      'manifest': <String, Object?>{
        'schemaVersion': 7,
        'appVersion': '9.9.9',
        'createdAt': '2026-10-10T00:00:00.000Z',
        'domains': <Object?>[],
      },
      'payload': <String, Object?>{},
    };

    expect(() => decodeBackupDocument(document), throwsA(isA<BackupFormatFailure>()));
    // Widening the accepted set is a decision with a migration behind it, and the parameter is the only way
    // to make it on purpose.
    expect(() => decodeBackupDocument(document, supportedSchemaVersions: const <int>{7}), returnsNormally);
  });

  test('test_decodeBackupDocument_refusesADomainWithNoValues', () {
    // A domain the manifest lists but the payload lacks would otherwise restore as "empty", overwriting what
    // the device already has with nothing.
    final document = <String, Object?>{
      'manifest': <String, Object?>{
        'schemaVersion': 1,
        'appVersion': '1.0.0',
        'createdAt': '2026-10-10T00:00:00.000Z',
        'domains': <Object?>[
          <String, Object?>{'name': 'favorites', 'keyCount': 3, 'bytes': 8},
        ],
      },
      'payload': <String, Object?>{},
    };

    expect(
      () => decodeBackupDocument(document),
      throwsA(isA<BackupFormatFailure>().having((error) => error.reason, 'reason', contains('favorites'))),
    );
  });

  test('test_decodeBackupText_namesTheShapeThatWasMissing', () {
    expect(
      () => decodeBackupText('[1,2]'),
      throwsA(isA<BackupFormatFailure>().having((error) => error.reason, 'reason', contains('object'))),
    );
    expect(() => decodeBackupText('{not json'), throwsA(isA<BackupFormatFailure>()));
  });
}
