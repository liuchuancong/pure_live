import 'package:flutter_test/flutter_test.dart';
import 'package:pure_live/core/site/yy/yy_site.dart';

void main() {
  group('YY category metadata', () {
    test('parses the embedded JavaScript literal without a JS runtime', () {
      const html = '''
        <script>
          var pageInfo = {
            pageBar: {totalPages: 8, moduleId: 308, biz: 'sing', subBiz: "idx"},
            position: 'secondary'
          };
        </script>
      ''';

      expect(YYSite.parseCategoryPageInfo(html), <String, dynamic>{'moduleId': 308, 'biz': 'sing', 'subBiz': 'idx'});
    });

    test('rejects incomplete metadata and upgrades public URLs to HTTPS', () {
      expect(YYSite.parseCategoryPageInfo('var pageInfo = {biz: "sing"};'), isNull);
      expect(YYSite.normalizeWebUrl('http://www.yy.com/music/'), 'https://www.yy.com/music/');
      expect(YYSite.normalizeWebUrl('//image.yy.com/a.jpg'), 'https://image.yy.com/a.jpg');
    });

    test('normalizes string and boolean live-state fields', () {
      expect(YYSite.isLiveValue('1'), isTrue);
      expect(YYSite.isLiveValue(true), isTrue);
      expect(YYSite.isLiveValue('0'), isFalse);
      expect(YYSite.isLiveValue(null), isFalse);
    });
  });
}
