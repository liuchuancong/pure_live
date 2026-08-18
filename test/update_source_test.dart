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
}
