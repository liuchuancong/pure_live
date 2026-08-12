import 'package:flutter_test/flutter_test.dart';
import 'package:pure_live/common/services/settings/backup_controller.dart';

void main() {
  test('remote backup redacts cookies and WebDAV credentials', () {
    final source = <String, dynamic>{
      'backupVersion': 3,
      'cookie': {'bilibiliCookie': 'session-secret'},
      'webdav': {
        'webDavConfigs': [
          {'username': 'user', 'password': 'password'},
        ],
      },
      'player': {'engine': 'mediaKit'},
    };

    final redacted = BackupController.redactSensitiveData(source);

    expect(redacted, isNot(contains('cookie')));
    expect(redacted, isNot(contains('webdav')));
    expect(redacted['sensitiveDataIncluded'], isFalse);
    expect(redacted['player'], {'engine': 'mediaKit'});
    expect(
      source,
      contains('cookie'),
      reason: 'the caller-owned map must not be mutated',
    );
  });
}
