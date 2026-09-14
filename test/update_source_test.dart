import 'package:flutter_test/flutter_test.dart';
import 'package:pure_live/plugins/update.dart';

void main() {
  const origin = 'https://github.com/owner/repo/releases/download/v1/app.apk';

  test('GitHub origin mode exposes exactly the official asset URL', () {
    expect(getMirrorUrls(origin, githubOriginOnly: true), [origin]);
  });

  test('accelerated mode keeps a unique official URL as its final fallback', () {
    final urls = getMirrorUrls(origin);

    expect(urls.last, origin);
    expect(urls.toSet(), hasLength(urls.length));
  });

  test('blank release asset does not render unusable mirror actions', () {
    expect(getMirrorUrls(''), isEmpty);
  });

  test('download entry accepts and normalizes complete HTTP targets', () {
    expect(
      updateDownloadUri(' HTTPS://Example.TEST:8443/release.apk?token=a%2Fb '),
      Uri.parse('https://example.test:8443/release.apk?token=a%2Fb'),
    );
    expect(updateDownloadUri('http://localhost:8080/release.apk'), isNotNull);
    expect(updateDownloadUri('http://[::1]:8080/release.apk'), isNotNull);
  });

  test('download entry rejects embedded, credentialed and malformed targets', () {
    for (final value in <String>[
      'prefix https://example.test/release.apk',
      'https://user:token@example.test/release.apk',
      'https://example.test:70000/release.apk',
      'https://example.test/release.apk\nnext',
      'release.apk',
      'file:///tmp/release.apk',
      'javascript:alert(1)',
    ]) {
      expect(updateDownloadUri(value), isNull, reason: value);
    }
    expect(getMirrorUrls('release.apk'), isEmpty);
  });

  test('Android install permission is requested only for APK files', () {
    expect(requiresInstallPackagesPermission(isAndroid: true, fileName: 'PureLive.apk'), isTrue);
    expect(requiresInstallPackagesPermission(isAndroid: true, fileName: 'PureLive.ZIP'), isFalse);
    expect(requiresInstallPackagesPermission(isAndroid: false, fileName: 'PureLive.apk'), isFalse);
  });
}
