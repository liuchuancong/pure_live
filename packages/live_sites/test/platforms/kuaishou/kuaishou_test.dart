import 'dart:convert';

import 'package:live_sites/src/models/audience/live_audience_update/live_audience_update.dart';
import 'package:live_sites/src/models/enums/live_audience_signal_kind.dart';
import 'package:live_sites/src/models/enums/live_message_type.dart';
import 'package:live_sites/src/platforms/kuaishou/danmaku/kuaishou_danmaku_codec.dart';
import 'package:test/test.dart';

Map<Object?, Object?> _comment({
  Object? content = 'hello',
  Object? id = 'c1',
  Object? time = 1790733600000,
  String userName = 'Ann',
  String userId = 'u1',
  String type = 'comment',
}) => {
  'type': type,
  'content': content,
  'id': id,
  'time': time,
  'author': {'userName': userName, 'userId': userId},
};

Map<Object?, Object?> _answer({
  Object? result = 1,
  Object? feeds,
  String cursor = 'next',
  int? pullCycle = 3,
  Object? watching = '76',
}) => {
  'result': result,
  'cursor': cursor,
  'pullCycleSeconds': ?pullCycle,
  'currentWatchingCount': ?watching,
  'liveStreamFeeds': feeds ?? [_comment()],
};

void main() {
  group('parse', () {
    test('the feed body may be a JSON string inside a JSON string, and data is unwrapped', () {
      final batch = KuaishouDanmakuCodec.parse(jsonEncode(jsonEncode(_answer())));
      expect(batch.cursor, 'next');
      expect(batch.pullDelay, const Duration(seconds: 3));
      expect(batch.messages.single.text, 'hello');
      expect(batch.onlineViewers, 76);

      final wrapped = KuaishouDanmakuCodec.parse(jsonEncode({'data': _answer()}));
      expect(wrapped.messages.single.text, 'hello');
    });

    test('the pull cycle is clamped to 1–10 seconds, and the audience figure parsed', () {
      expect(KuaishouDanmakuCodec.parse(_answer(pullCycle: 0)).pullDelay, const Duration(seconds: 1));
      expect(KuaishouDanmakuCodec.parse(_answer(pullCycle: 60)).pullDelay, const Duration(seconds: 10));
      expect(KuaishouDanmakuCodec.parse(_answer(pullCycle: null)).pullDelay, KuaishouDanmakuCodec.defaultPullDelay);
      expect(KuaishouDanmakuCodec.parse(_answer(watching: '1.2万')).onlineViewers, 12000);
      expect(KuaishouDanmakuCodec.parse(_answer(watching: ' ')).onlineViewers, isNull);
    });

    test('a refused feed names its result code; an invalid shape is a FormatException', () {
      expect(
        () => KuaishouDanmakuCodec.parse(_answer(result: 2)),
        throwsA(isA<KuaishouFeedRejected>().having((rejected) => rejected.result, 'result', 2)),
      );
      expect(() => KuaishouDanmakuCodec.parse('[1,2]'), throwsA(isA<FormatException>()));
      expect(() => KuaishouDanmakuCodec.parse('not json'), throwsA(isA<FormatException>()));
    });

    test('the batch reports the audience before its comments', () {
      final batch = KuaishouDanmakuCodec.parse(_answer());
      final reported = batch.reported;
      expect(reported.first.type, LiveMessageType.audienceUpdate);
      expect((reported.first.payload! as LiveAudienceUpdate).value, 76);
      expect(reported.last.text, 'hello');
    });
  });

  group('comments', () {
    test('a comment is white chat with its author, id and time', () {
      final message = KuaishouDanmakuCodec.parse(_answer()).messages.single;
      expect(message.type, LiveMessageType.chat);
      expect(message.text, 'hello');
      expect(message.messageId, 'kuaishou:c1');
      expect(message.sentAt, DateTime.fromMillisecondsSinceEpoch(1790733600000));
      expect(message.sender?.userId, 'u1');
      expect(message.sender?.userName, 'Ann');
      expect(message.emotes, isEmpty);
    });

    test('a nameless commenter is the platform user, and the type is case-insensitive', () {
      final message = KuaishouDanmakuCodec.parse(
        _answer(
          feeds: [_comment(userName: ' ', type: 'COMMENT')],
        ),
      ).messages.single;
      expect(message.sender?.userName, KuaishouDanmakuCodec.anonymousUserName);
    });

    test('a comment without an id gets a stable content hash', () {
      final first = KuaishouDanmakuCodec.parse(_answer(feeds: [_comment(id: '')])).messages.single;
      final second = KuaishouDanmakuCodec.parse(_answer(feeds: [_comment(id: '')])).messages.single;
      final other = KuaishouDanmakuCodec.parse(
        _answer(
          feeds: [_comment(id: '', content: 'other')],
        ),
      ).messages.single;
      expect(first.messageId, startsWith('kuaishou:'));
      expect(first.messageId, second.messageId);
      expect(first.messageId, isNot(other.messageId));
    });

    test('gift lines, empty text and unholdable times are skipped without losing the others', () {
      final batch = KuaishouDanmakuCodec.parse(
        _answer(
          feeds: [
            _comment(type: 'gift'),
            _comment(content: '   '),
            _comment(time: double.infinity),
            _comment(time: 9000000000000000),
            _comment(content: 'kept'),
          ],
        ),
      );
      expect(batch.messages.single.text, 'kept');
    });
  });

  group('emotes and pacing', () {
    test('the emote codes of the room table become the comment emotes, once each in order', () {
      const table = {'[笑哭]': 'https://cdn.example/laugh.png', '[赞]': 'https://cdn.example/like.png'};
      final message = KuaishouDanmakuCodec.parse(
        _answer(feeds: [_comment(content: '真好[笑哭][赞][笑哭][未知]')]),
        emotes: table,
      ).messages.single;
      expect(message.emotes.map((emote) => emote.code), ['[笑哭]', '[赞]']);
      expect(message.emotes.first.url, 'https://cdn.example/laugh.png');
      expect(KuaishouDanmakuCodec.codeEmotes('nothing', table), isEmpty);
    });

    test('the request headers, query and backoff', () {
      expect(KuaishouDanmakuCodec.headers(' cookie=1 '), containsPair('cookie', 'cookie=1'));
      expect(KuaishouDanmakuCodec.headers(''), isNot(contains('cookie')));
      expect(KuaishouDanmakuCodec.query('live1', 'c1'), {'liveStreamId': 'live1', 'cursor': 'c1'});
      expect(KuaishouDanmakuCodec.query('live1', ''), {'liveStreamId': 'live1'});
      expect(
        [for (var failures = 1; failures <= 5; failures++) KuaishouDanmakuCodec.backoff(failures).inSeconds],
        [1, 2, 4, 8, 8],
      );
    });

    test('the audience message counts online viewers', () {
      final message = KuaishouDanmakuCodec.audience(2472);
      expect(message.type, LiveMessageType.audienceUpdate);
      final audience = message.payload! as LiveAudienceUpdate;
      expect(audience.kind, LiveAudienceSignalKind.onlineViewers);
      expect(audience.value, 2472);
    });
  });
}
