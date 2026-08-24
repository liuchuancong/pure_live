import 'package:flutter_test/flutter_test.dart';
import 'package:pure_live/core/site/douyu/douyu_utils.dart';
import 'package:pure_live/core/utils/douyin/douyin_utils.dart';

void main() {
  group('DouyuUtils', () {
    test('invalid or unbounded encryption descriptors fail fast', () {
      expect(() => DouyuUtils.sign('123'), throwsFormatException);
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
