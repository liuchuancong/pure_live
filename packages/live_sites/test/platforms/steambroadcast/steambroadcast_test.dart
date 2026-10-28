import 'dart:convert';

import 'package:live_sites/src/models/audience/live_audience_update/live_audience_update.dart';
import 'package:live_sites/src/models/enums/live_audience_signal_kind.dart';
import 'package:live_sites/src/models/enums/live_message_type.dart';
import 'package:live_sites/src/platforms/steambroadcast/danmaku/steambroadcast_danmaku_codec.dart';
import 'package:live_sites/src/platforms/steambroadcast/parsers/steambroadcast_failure.dart';
import 'package:test/test.dart';

const String _template =
    'https://steambroadcastchat.akamaized.net/chat/abc/messages/{0}?chat_origin=https://steamcommunity.com';

String _chatInfo({Object? success = 1, Object? template = _template}) =>
    jsonEncode({'success': success, 'view_url_template': ?template});

String _windowAnswer({Object? next = 2000, Object? delay, Object? messages = const []}) =>
    jsonEncode({'next_request': next, 'initial_delay': ?delay, 'messages': messages});

void main() {
  group('getchatinfo', () {
    test('a template with {0} on the chat CDN is the chat log', () {
      final chat = SteambroadcastDanmakuCodec.chat(_chatInfo(), broadcastId: '123');
      expect(chat.broadcastId, '123');
      expect(chat.template, _template);
      expect(chat.window(456), Uri.parse(_template.replaceFirst('{0}', '456')));
      expect(SteambroadcastDanmakuCodec.chat(_chatInfo(success: '1'), broadcastId: '123').template, _template);
    });

    test('a refused or foreign answer is api-changed, and a bad status keeps its kind', () {
      expect(
        () => SteambroadcastDanmakuCodec.chat(_chatInfo(success: 2), broadcastId: '123'),
        throwsA(isA<SteambroadcastFailure>()),
      );
      expect(
        () => SteambroadcastDanmakuCodec.chat(_chatInfo(template: 'https://example.com/chat'), broadcastId: '123'),
        throwsA(isA<SteambroadcastFailure>()),
      );
      expect(
        () => SteambroadcastDanmakuCodec.chat(_chatInfo(template: 'https://evil.example/{0}'), broadcastId: '123'),
        throwsA(isA<SteambroadcastFailure>()),
      );
      expect(
        () => SteambroadcastDanmakuCodec.chat(_chatInfo(), broadcastId: '123', status: 500),
        throwsA(
          isA<SteambroadcastFailure>().having((failure) => failure.kind, 'kind', SteambroadcastFailureKind.network),
        ),
      );
    });

    test('only https addresses on Steam hosts or the chat CDN are read', () {
      expect(SteambroadcastDanmakuCodec.isChatLog(Uri.parse('https://steambroadcastchat.akamaized.net/x')), isTrue);
      expect(SteambroadcastDanmakuCodec.isChatLog(Uri.parse('https://steambroadcast-foo.akamaized.net/x')), isTrue);
      expect(SteambroadcastDanmakuCodec.isChatLog(Uri.parse('https://steamcommunity.com/x')), isTrue);
      expect(SteambroadcastDanmakuCodec.isChatLog(Uri.parse('https://chat.steamcommunity.com/x')), isTrue);
      expect(SteambroadcastDanmakuCodec.isChatLog(Uri.parse('http://steambroadcastchat.akamaized.net/x')), isFalse);
      expect(
        SteambroadcastDanmakuCodec.isChatLog(Uri.parse('https://steambroadcastchat.akamaized.net:444/x')),
        isFalse,
      );
      expect(SteambroadcastDanmakuCodec.isChatLog(Uri.parse('https://user@steamcommunity.com/x')), isFalse);
      expect(SteambroadcastDanmakuCodec.isChatLog(Uri.parse('https://steamcommunity.com/x#f')), isFalse);
      expect(SteambroadcastDanmakuCodec.isChatLog(Uri.parse('https://evil.example/x')), isFalse);
    });

    test('a broadcast id is digits without a leading zero', () {
      expect(SteambroadcastDanmakuCodec.broadcastIdOf('123'), '123');
      expect(SteambroadcastDanmakuCodec.broadcastIdOf(' 42 '), '42');
      expect(SteambroadcastDanmakuCodec.broadcastIdOf('0'), isNull);
      expect(SteambroadcastDanmakuCodec.broadcastIdOf('0123'), isNull);
      expect(SteambroadcastDanmakuCodec.broadcastIdOf('12a'), isNull);
      expect(SteambroadcastDanmakuCodec.broadcastIdOf(null), isNull);
    });
  });

  group('windows', () {
    test('a window names the next time, the delay and its chat lines', () {
      final window = SteambroadcastDanmakuCodec.window(
        _windowAnswer(
          delay: 500,
          messages: [
            {'msg': ' hi ', 'persona_name': ' Ann ', 'steamid': '765'},
            {'msg': '   '},
            'not a map',
          ],
        ),
        time: 1000,
      );
      expect(window.next, 2000);
      expect(window.initialDelay, const Duration(milliseconds: 500));
      expect(window.messages.single.text, 'hi');
      expect(window.messages.single.sender?.userName, 'Ann');
      expect(window.messages.single.sender?.userId, '765');
    });

    test('a negative or absent delay is none, and window 0 accepts an early next', () {
      final negative = SteambroadcastDanmakuCodec.window(_windowAnswer(delay: -1), time: 0);
      expect(negative.initialDelay, isNull);
      expect(negative.messages, isEmpty);
      expect(SteambroadcastDanmakuCodec.window(_windowAnswer(next: 1), time: 0).next, 1);
    });

    test('a next request that does not move past the window is api-changed', () {
      for (final next in <Object?>[null, 0, -1, 1000, 'later']) {
        expect(
          () => SteambroadcastDanmakuCodec.window(_windowAnswer(next: next), time: 1000),
          throwsA(isA<SteambroadcastFailure>()),
        );
      }
      expect(
        () => SteambroadcastDanmakuCodec.window('{}', time: 0, status: 404),
        throwsA(
          isA<SteambroadcastFailure>().having((failure) => failure.kind, 'kind', SteambroadcastFailureKind.notFound),
        ),
      );
    });

    test('a message needs text; the sender may be absent', () {
      expect(SteambroadcastDanmakuCodec.message({'msg': 'hi'})?.sender?.userName, '');
      expect(SteambroadcastDanmakuCodec.message({'msg': 'hi', 'steamid': 765})?.sender?.userId, '765');
      expect(SteambroadcastDanmakuCodec.message({'msg': 5}), isNull);
      expect(SteambroadcastDanmakuCodec.message({'msg': ' '}), isNull);
      expect(SteambroadcastDanmakuCodec.message('hi'), isNull);
    });
  });

  group('timing', () {
    test('the wait is the retry delay, then 1, 2, 4 and 8 seconds', () {
      expect(
        [for (var failures = 1; failures <= 12; failures++) SteambroadcastDanmakuCodec.wait(failures).inMilliseconds],
        [500, 500, 500, 500, 500, 500, 500, 1000, 2000, 4000, 8000, 8000],
      );
    });

    test('the clock starts at window 0 and syncs to the answer delay, clamped', () {
      final clock = SteambroadcastChatClock();
      expect(clock.isSynced, isFalse);
      expect(clock.window, 0);
      expect(clock.sync(1000, const Duration(seconds: 5), Duration.zero), const Duration(seconds: 5));
      expect(clock.isSynced, isTrue);
      expect(clock.window, 1000);
      expect(
        SteambroadcastChatClock().sync(1, const Duration(minutes: 2), Duration.zero),
        SteambroadcastDanmakuCodec.maxWait,
      );
    });

    test('later windows are due as far past the first as their time, plus the nudge', () {
      final clock = SteambroadcastChatClock()..sync(1000, const Duration(seconds: 5), Duration.zero);
      expect(clock.advance(2000, const Duration(seconds: 5)), const Duration(seconds: 1));
      clock.miss();
      expect(clock.advance(2000, const Duration(seconds: 5)), const Duration(milliseconds: 1010));
      for (var i = 0; i < 200; i++) {
        clock.miss();
      }
      expect(clock.nudge, SteambroadcastDanmakuCodec.maxNudge);
      expect(clock.advance(2000, const Duration(seconds: 5)), const Duration(seconds: 2));
    });

    test('a resync starts over from window 0 and keeps the nudge', () {
      final clock = SteambroadcastChatClock()
        ..sync(1000, Duration.zero, Duration.zero)
        ..miss()
        ..resync();
      expect(clock.window, 0);
      expect(clock.isSynced, isFalse);
      expect(clock.sync(1000, Duration.zero, Duration.zero), Duration.zero);
      expect(clock.advance(2000, Duration.zero), const Duration(milliseconds: 1010));
    });

    test('the audience message counts concurrent viewers', () {
      final message = SteambroadcastDanmakuCodec.audience(2557);
      expect(message.type, LiveMessageType.audienceUpdate);
      final audience = message.payload! as LiveAudienceUpdate;
      expect(audience.kind, LiveAudienceSignalKind.onlineViewers);
      expect(audience.value, 2557);
    });
  });

  group('wiring', () {
    test('the chat info URL names the account and broadcast', () {
      final url = SteambroadcastDanmakuCodec.chatInfoUrl('765', '123');
      expect(url.host, 'steamcommunity.com');
      expect(url.path, '/broadcast/getchatinfo/');
      expect(url.queryParameters, {'steamid': '765', 'broadcastid': '123', 'viewertoken': '0', 'sessionid': ''});
    });

    test('the chat log request carries the watch page as origin and referer', () {
      final headers = SteambroadcastDanmakuCodec.chatHeaders('765');
      expect(headers['origin'], 'https://steamcommunity.com');
      expect(headers['referer'], contains('765'));
      expect(headers['accept'], contains('application/json'));
    });
  });
}
