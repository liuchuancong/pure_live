import 'package:flutter_test/flutter_test.dart';
import 'package:pure_live/shared/platforms/live_short_link_session.dart';
import 'package:pure_live/shared/platforms/xiaohongshu/xiaohongshu_link.dart';

void main() {
  group('小红书分享文本里的链接提取', () {
    test('官方分享文案整段粘贴能抽出 xhslink 短链', () {
      final raw = '小红书，你的生活指南#不吃皮小蛋正在直播，来和我一起支持ta吧。 https://xhslink.com/o/4579SzZ9hgZ 复制本条信息，打开【小红书】，直接观看直播！';
      expect(XiaohongshuLink.extractUrls(raw), ['https://xhslink.com/o/4579SzZ9hgZ']);
    });

    test('链接后紧跟中文标点会被截断，句点剪掉', () {
      expect(XiaohongshuLink.extractUrls('看这个 https://xhslink.com/o/AbCd1234。'), ['https://xhslink.com/o/AbCd1234']);
      expect(XiaohongshuLink.extractUrls('https://xhslink.com/o/AbCd1234，来吧'), ['https://xhslink.com/o/AbCd1234']);
    });

    test('/o/ 前缀短链与 /m/ 同样被认', () {
      expect(XiaohongshuLink.shortUri('https://xhslink.com/o/4579SzZ9hgZ'), isNotNull);
      expect(XiaohongshuLink.shortUri('https://xhslink.com/m/AbCd1234'), isNotNull);
      expect(XiaohongshuLink.shortUri('https://xhslink.com/AbCd1234'), isNotNull);
      // 多级路径或别的站点仍然不认。
      expect(XiaohongshuLink.shortUri('https://xhslink.com/o/AbCd1234/extra'), isNull);
      expect(XiaohongshuLink.shortUri('https://example.com/o/AbCd1234'), isNull);
    });

    test('长链与裸房间号照旧直解', () {
      expect(XiaohongshuLink.parse('https://www.xiaohongshu.com/livestream/570484217626596278'), '570484217626596278');
      expect(
        XiaohongshuLink.parse(
          'https://www.xiaohongshu.com/livestream/dynpathO33uEURW/570484217626596278?share_source=share_link',
        ),
        '570484217626596278',
      );
      expect(XiaohongshuLink.parse('570484217626596278'), '570484217626596278');
    });

    test('resolve 对纯文本且无链接的输入返回空', () async {
      final session = LiveShortLinkSession(timeout: const Duration(seconds: 2));
      try {
        expect(await XiaohongshuLink.resolve('不吃皮小蛋', session: session), isNull);
      } finally {
        session.close();
      }
    });
  });
}
