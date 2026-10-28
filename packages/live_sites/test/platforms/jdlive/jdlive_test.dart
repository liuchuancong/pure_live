import 'dart:convert';
import 'dart:math';

import 'package:live_sites/src/models/audience/live_audience_update/live_audience_update.dart';
import 'package:live_sites/src/models/enums/live_audience_signal_kind.dart';
import 'package:live_sites/src/models/enums/live_message_type.dart';
import 'package:live_sites/src/platforms/jdlive/danmaku/jdlive_danmaku_codec.dart';
import 'package:live_sites/src/platforms/jdlive/parsers/jdlive_failure.dart';
import 'package:test/test.dart';

const String _liveId = '12345678';
const int _millis = 1790733600000;

String _authAnswer({Object? url = 'wss://live.jd.com/ws', Object? token = 'abc', String? mask, int code = 0}) =>
    jsonEncode({
      'code': code,
      'msg': 'ok',
      'data': {'liveUrl': url, 'token': token, 'msgMaskKey': ?mask},
    });

Map<Object?, Object?> _chat({
  String type = 'viewer_send_message',
  String nick = 'Ann',
  String content = ' hello ',
  Object? group = _liveId,
  Object? id = 'm1',
  Object? datetime = _millis,
}) => {
  'type': 'chat_group_message',
  'id': ?id,
  'datetime': ?datetime,
  'from': {'pinmd5': 'hash1'},
  'body': {'groupid': ?group, 'type': type, 'nickName': nick, 'content': content},
};

String _statistics({Object? current = 10, Object? total = '20', Object? group = _liveId}) => jsonEncode({
  'type': 'get_statistics_result',
  'body': {'groupid': ?group, 'current_viewer': current, 'total_viwer': total},
});

void main() {
  group('liveauth', () {
    test('the answer turns into a socket URL with the token, and keeps the mask', () {
      final auth = JdliveDanmakuCodec.auth(_authAnswer(mask: 'k'));
      expect(auth.socketUrl, Uri.parse('wss://live.jd.com/ws?token=abc'));
      expect(auth.maskKey, 'k');
      expect(JdliveDanmakuCodec.auth(_authAnswer()).maskKey, isNull);
    });

    test('a refusal keeps its reason, and a bad status or non-JSON is a failure', () {
      expect(
        () => JdliveDanmakuCodec.auth(
          jsonEncode({
            'code': 1,
            'msg': '鉴权失败',
            'data': {'error': '解密失败!'},
          }),
        ),
        throwsA(isA<JdliveFailure>().having((failure) => failure.message, 'message', contains('解密失败'))),
      );
      expect(() => JdliveDanmakuCodec.auth('no json'), throwsA(isA<JdliveFailure>()));
      expect(
        () => JdliveDanmakuCodec.auth('{}', status: 500),
        throwsA(isA<JdliveFailure>().having((failure) => failure.kind, 'kind', JdliveFailureKind.network)),
      );
    });

    test('a socket must be a bare wss URL on jd.com with a usable token', () {
      for (final answer in [
        _authAnswer(url: 'ws://live.jd.com/ws'),
        _authAnswer(url: 'wss://live.evil.example/ws'),
        _authAnswer(url: 'wss://live.jd.com/ws?x=1'),
        _authAnswer(url: 'wss://user@live.jd.com/ws'),
        _authAnswer(token: ''),
        _authAnswer(token: 'a b'),
      ]) {
        expect(() => JdliveDanmakuCodec.auth(answer), throwsA(isA<JdliveFailure>()));
      }
    });

    test('the endpoint carries the broadcast, and only there is it read back', () {
      final endpoint = JdliveDanmakuCodec.endpoint(_liveId);
      expect(endpoint.queryParameters, {'functionId': 'liveauth', 'groupId': _liveId});
      expect(JdliveDanmakuCodec.liveIdOf(endpoint), _liveId);
      expect(
        JdliveDanmakuCodec.liveIdOf(Uri.parse('https://api.m.jd.com/api?functionId=other&groupId=$_liveId')),
        isNull,
      );
      expect(
        JdliveDanmakuCodec.liveIdOf(Uri.parse('https://api.m.jd.com/api?functionId=liveauth&groupId=0123')),
        isNull,
      );
    });

    test("the encrypted body is the page's, and the token is redacted", () {
      final now = DateTime.utc(2026, 9, 27, 12);
      final content = jsonDecode(JdliveDanmakuCodec.content(_liveId, now: now, nonce: '123456'));
      expect(content, {
        'appId': 'jd.mall',
        'secretKey': JdliveDanmakuCodec.secretKey,
        'groupId': _liveId,
        'clientType': 'm',
        'timestamp': now.millisecondsSinceEpoch,
        'origin': -100,
        'encryptPin': true,
        'random': '123456',
      });
      final encrypted = base64.decode(JdliveDanmakuCodec.encrypt('{"a":1}'));
      expect(encrypted.length % 16, 0);
      expect(utf8.decode(encrypted, allowMalformed: true), isNot('{"a":1}'));

      final fields = JdliveDanmakuCodec.authFields(_liveId, now: now, nonce: '123456');
      expect(fields['t'], '${now.millisecondsSinceEpoch}');
      final body = jsonDecode(fields['body']!) as Map<String, dynamic>;
      expect(body, containsPair('appId', JdliveDanmakuCodec.appId));
      expect((body['content'] as String).length, greaterThan(0));
      expect(JdliveDanmakuCodec.redact('wss://a/ws?token=secret&x=1'), 'wss://a/ws?token=…&x=1');
      expect(JdliveDanmakuCodec.nonce(Random(7)), matches(RegExp(r'^[0-9]{6}$')));
    });
  });

  group('statistics', () {
    test('the viewers now and the cumulative views are typed apart', () {
      final frame = JdliveDanmakuCodec.decode(_statistics(), liveId: _liveId);
      expect(frame.messages, hasLength(2));
      final online = frame.messages.first.payload! as LiveAudienceUpdate;
      final total = frame.messages.last.payload! as LiveAudienceUpdate;
      expect(online.kind, LiveAudienceSignalKind.onlineViewers);
      expect(online.value, 10);
      expect(total.kind, LiveAudienceSignalKind.totalViewers);
      expect(total.value, 20);
    });

    test('a figure that is not a whole number, or of another group, is left out', () {
      expect(JdliveDanmakuCodec.decode(_statistics(current: -1, total: 'many'), liveId: _liveId).messages, isEmpty);
      expect(JdliveDanmakuCodec.decode(_statistics(group: 999), liveId: _liveId).messages, isEmpty);
    });
  });

  group('chat', () {
    test('a viewer message is chat with the hashed account and the event id', () {
      final message = JdliveDanmakuCodec.decode(jsonEncode(_chat()), liveId: _liveId).messages.single;
      expect(message.type, LiveMessageType.chat);
      expect(message.text, 'hello');
      expect(message.messageId, 'm1');
      expect(message.sentAt, DateTime.fromMillisecondsSinceEpoch(_millis));
      expect(message.sender?.userId, 'hash1');
      expect(message.sender?.userName, 'Ann');
    });

    test('an anchor message is named as the page names it', () {
      final message = JdliveDanmakuCodec.decode(
        jsonEncode(_chat(type: 'anchor_send_message')),
        liveId: _liveId,
      ).messages.single;
      expect(message.sender?.userName, JdliveDanmakuCodec.anchorName);
    });

    test('entries, likes and blank text are nothing; a missing group id counts as this group', () {
      expect(JdliveDanmakuCodec.decode(jsonEncode(_chat(type: 'viewer_enter')), liveId: _liveId).messages, isEmpty);
      expect(JdliveDanmakuCodec.decode(jsonEncode(_chat(content: '  ')), liveId: _liveId).messages, isEmpty);
      expect(JdliveDanmakuCodec.decode(jsonEncode(_chat(group: null)), liveId: _liveId).messages, hasLength(1));
      expect(JdliveDanmakuCodec.decode(jsonEncode(_chat(group: 999)), liveId: _liveId).messages, isEmpty);
    });

    test('the end of the broadcast is flagged, and other types are ignored', () {
      final ended = JdliveDanmakuCodec.decode(
        jsonEncode({
          'type': 'chat_group_message',
          'body': {'groupid': _liveId, 'type': 'stop_live_broadcast'},
        }),
        liveId: _liveId,
      );
      expect(ended.ended, isTrue);
      expect(ended.messages, isEmpty);
      expect(JdliveDanmakuCodec.decode(jsonEncode({'type': 'ping'}), liveId: _liveId).ended, isFalse);
    });
  });

  group('binary frames', () {
    test("a masked frame is XORed back with the answer's key", () {
      final plain = utf8.encode(jsonEncode(_chat()));
      final key = 'mask'.codeUnits;
      final masked = [for (var i = 0; i < plain.length; i++) plain[i] ^ key[i % key.length]];
      final message = JdliveDanmakuCodec.decode(masked, liveId: _liveId, maskKey: 'mask').messages.single;
      expect(message.text, 'hello');
      expect(JdliveDanmakuCodec.decode(masked, liveId: _liveId).messages, isEmpty);
    });

    test('bytes that are not UTF-8, and a body that is not JSON, give nothing', () {
      expect(JdliveDanmakuCodec.decode([0xFF, 0xFE], liveId: _liveId).messages, isEmpty);
      expect(JdliveDanmakuCodec.decode('not json', liveId: _liveId).messages, isEmpty);
      expect(JdliveDanmakuCodec.decode('[1,2]', liveId: _liveId).messages, isEmpty);
      expect(JdliveDanmakuCodec.decode(42, liveId: _liveId).messages, isEmpty);
    });
  });
}
