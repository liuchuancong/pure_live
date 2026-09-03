import 'package:flutter_test/flutter_test.dart';
import 'package:pure_live/common/utils/githup_mirror.dart';

void main() {
  test('mirror list is ordered, unique, and keeps direct GitHub first', () {
    final urls = GitHubMirror(
      owner: 'owner',
      repo: 'repo',
      branch: 'main',
    ).mirrors('assets/config.json');

    expect(urls.first, 'https://raw.githubusercontent.com/owner/repo/main/assets/config.json');
    expect(urls.toSet(), hasLength(urls.length));
    expect(urls, everyElement(startsWith('https://')));
  });
}
