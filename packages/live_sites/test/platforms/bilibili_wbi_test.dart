// Bilibili's WBI signature, pinned by vectors: the permutation, the query
// shape and the digest pipeline are all pure, and every signed request the
// room, the danmaku and the search make rides on them — a table transcribed
// wrong or a sort dropped must fail here, not on a live room.

import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:live_sites/src/platforms/bilibili/api/bilibili_wbi.dart';
import 'package:live_sites/src/platforms/bilibili/parsers/bilibili_failure.dart';
import 'package:test/test.dart';

void main() {
  // md5('a') and md5('b') — 32 + 32 characters, the shortest honest key pair.
  const imgKey = '0cc175b9c0f1b6a831c399e269772661';
  const subKey = '92eb5ffee6ae2fec3ad71c777531578f';

  group('mixinKey', () {
    test('the known pair permutes to the hand-derived vector', () {
      // Hand-derived from the table: take origin[46,47,18,2,53,8,23,32,15,50,
      // 10,31,58,3,45,35,27,43,5,49,33,9,42,19,29,28,14,39,12,38,41,13].
      expect(BilibiliWbi.mixinKey(imgKey, subKey), 'eccccc298df131fb7e5a20a362aebf66');
    });

    test('the permutation keeps the first 32 characters only', () {
      expect(BilibiliWbi.mixinKey(imgKey, subKey).length, 32);
    });

    test('a key pair shorter than 64 characters means the nav answer changed', () {
      expect(() => BilibiliWbi.mixinKey('short', 'also-short'), throwsA(isA<BilibiliFailure>()));
    });
  });

  group('query', () {
    test('sorts by key, appends wts and strips the unsafe marks', () {
      final signed = BilibiliWbi.query({'b': 'a b!c', 'a': 'z*'}, wts: 1700000000);
      expect(signed, 'a=z&b=a%20bc&wts=1700000000');
    });

    test('percent-encodes the JavaScript way', () {
      final signed = BilibiliWbi.query({'q': '弹幕 (test)'}, wts: 7);
      // The parens are stripped as unsafe; the CJK survives as UTF-8 percents.
      expect(signed, contains('q=%E5%BC%B9%E5%B9%95%20test'));
      expect(signed, endsWith('&wts=7'));
    });
  });

  group('sign', () {
    test('w_rid is the digest of the query and the mixin key', () {
      final signed = BilibiliWbi.sign({'room_id': '23058'}, imgKey: imgKey, subKey: subKey, wts: 1234);
      const mixin = 'eccccc298df131fb7e5a20a362aebf66';
      const unsigned = 'room_id=23058&wts=1234';
      final rid = md5.convert(utf8.encode('$unsigned$mixin')).toString();
      expect(signed, '$unsigned&w_rid=$rid');
    });
  });

  group('tryNavKeys', () {
    test('reads the two file names out of the nav answer', () {
      final body = jsonEncode({
        'code': -101,
        'data': {
          'wbi_img': {
            'img_url': 'https://i0.hdslb.com/bfs/wbi/7cd084941ed1937515e1c3fb101fd498.png',
            'sub_url': 'https://i0.hdslb.com/bfs/wbi/4932ccb0e25a285d258fff88eb095f9c.png',
          },
        },
      });
      final keys = BilibiliWbi.tryNavKeys(body);
      expect(keys, isNotNull);
      expect(keys!.imgKey, '7cd084941ed1937515e1c3fb101fd498');
      expect(keys.subKey, '4932ccb0e25a285d258fff88eb095f9c');
    });

    test('an answer without the picture pair is the null answer', () {
      expect(BilibiliWbi.tryNavKeys('{"code":0,"data":{}}'), isNull);
    });
  });

  group('accessId', () {
    test('reads the escaped access_id out of the lol page', () {
      final id = BilibiliWbi.accessId(r'var x = "access_id":"abc\/def";');
      expect(id, 'abc/def');
    });

    test('a page without one is the api-changed failure', () {
      expect(() => BilibiliWbi.accessId('<html></html>'), throwsA(isA<BilibiliFailure>()));
    });
  });
}
