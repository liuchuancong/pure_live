import 'package:flutter_test/flutter_test.dart';
import 'package:pure_live/core/site/douyu/douyu_utils.dart';
import 'package:pure_live/core/utils/douyin/douyin_utils.dart';

void main() {
  group('DouyuUtils', () {
    final descriptor = <String, dynamic>{
      'key': 'key',
      'rand_str': 'rand',
      'enc_time': 1,
      'expire_at': 2000,
      'is_special': 0,
      'enc_data': 'a+/=',
    };

    test('encryption expiry is compared in Unix seconds', () {
      expect(DouyuUtils.isEncryptionKeyUsable(descriptor, nowSeconds: 1000), isTrue);
      expect(DouyuUtils.isEncryptionKeyUsable(descriptor, nowSeconds: 1970), isFalse);
      expect(DouyuUtils.isEncryptionKeyUsable(descriptor, nowSeconds: 1000000), isFalse);
    });

    test('signed form body is deterministic and percent-safe', () {
      final body = DouyuUtils.buildSignedData(
        encryptionKey: descriptor,
        roomId: '123',
        timestampSeconds: 1000,
        rate: 2,
        cdn: 'ali line',
      );
      final values = Uri.splitQueryString(body);

      expect(values['enc_data'], 'a+/=');
      expect(values['tt'], '1000');
      expect(values['did'], DouyuUtils.defaultDeviceId);
      expect(values['rate'], '2');
      expect(values['cdn'], 'ali line');
      expect(values['auth'], '1834439993932d590bceb2593c1c0cd0');
    });

    test('invalid or unbounded encryption descriptors fail fast', () {
      expect(() => DouyuUtils.sign('123'), throwsFormatException);
    });

    test('session identity and playback headers stay internally consistent', () {
      expect(DouyuUtils.deviceId, matches(RegExp(r'^[0-9a-f]{32}$')));

      final headers = DouyuUtils.playbackHeaders('123');
      expect(headers['referer'], 'https://www.douyu.com/123');
      expect(headers['origin'], 'https://www.douyu.com');
      expect(headers['user-agent'], isNotEmpty);
      expect(headers['cookie'], contains('dy_did=${DouyuUtils.deviceId}'));
      expect(headers['cookie'], contains('acf_did=${DouyuUtils.deviceId}'));
    });
  });

  group('DouyinUtils', () {
    test('token generation is bounded and uses the expected alphabet', () {
      final token = DouyinUtils.getMSToken(randomLength: 256);

      expect(token, hasLength(256));
      expect(token, matches(RegExp(r'^[A-Za-z0-9=]+$')));
      expect(() => DouyinUtils.getMSToken(randomLength: -1), throwsArgumentError);
    });

    test('signed URL preserves base query and does not mutate caller params', () {
      final params = <String, dynamic>{'room_id': '42', 'msToken': 'fixed-token'};
      final before = Map<String, dynamic>.from(params);

      final url = DouyinUtils.buildRequestUrl('https://live.douyin.com/api?existing=1', params);
      final parsed = Uri.parse(url);

      expect(params, before);
      expect(parsed.queryParameters['existing'], '1');
      expect(parsed.queryParameters['room_id'], '42');
      expect(parsed.queryParameters['msToken'], 'fixed-token');
      expect(parsed.queryParameters['aid'], '6383');
      expect(parsed.queryParameters['a_bogus'], isNotEmpty);
    });
  });
}
