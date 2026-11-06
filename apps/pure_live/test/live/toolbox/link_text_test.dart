import 'package:flutter_test/flutter_test.dart';

import 'package:pure_live/modules/live/toolbox/link_text.dart';

void main() {
  group('LinkText.httpUrls', () {
    test('a bare host takes https and keeps its spelling', () {
      expect(LinkText.httpUrls('live.bilibili.com/21452505').single, 'https://live.bilibili.com/21452505');
    });

    test('prose after Chinese punctuation is not part of the link', () {
      expect(LinkText.httpUrls('https://live.douyu.com/123。快来直播间呀').single, 'https://live.douyu.com/123');
    });

    test('trailing ASCII punctuation is dropped, the signed query kept', () {
      // A path-final slash is URL structure; only the comma goes.
      expect(LinkText.httpUrls('快看 https://v.douyin.com/abcD12/,').single, 'https://v.douyin.com/abcD12/');
      expect(LinkText.httpUrls('https://live.bilibili.com/6?s=1&t=2).').single, 'https://live.bilibili.com/6?s=1&t=2');
    });

    test('a xiaohongshu dot segment is route structure, not a stray dot', () {
      expect(LinkText.httpUrls('https://www.xiaohongshu.com/user/profile/.').single,
          'https://www.xiaohongshu.com/user/profile/.');
    });

    test('a link with user info or a foreign scheme is skipped', () {
      expect(LinkText.httpUrls('https://user:pass@example.com/room'), isEmpty);
      expect(LinkText.httpUrls('ftp://example.com/room'), isEmpty);
      expect(LinkText.httpUrls('xhsdiscover://room/123'), isEmpty);
    });

    test('share texts yield their links in order, more than one is fine', () {
      final urls = LinkText.httpUrls('A https://live.kuaishou.com/u/abc B https://live.douyu.com/9 C');
      expect(urls, ['https://live.kuaishou.com/u/abc', 'https://live.douyu.com/9']);
    });
  });
}
