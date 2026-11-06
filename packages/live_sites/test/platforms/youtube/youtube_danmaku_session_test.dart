import 'dart:async';
import 'dart:convert';

import 'package:live_net/live_net.dart';
import 'package:live_net/testing.dart';
import 'package:live_sites/src/core/live_site_error.dart';
import 'package:live_sites/src/models/enums/live_message_type.dart';
import 'package:live_sites/src/models/message/live_message/live_message.dart';
import 'package:live_sites/src/platforms/youtube/api/youtube_endpoints.dart';
import 'package:live_sites/src/platforms/youtube/api/youtube_http.dart';
import 'package:live_sites/src/platforms/youtube/danmaku/youtube_danmaku_codec.dart';
import 'package:live_sites/src/platforms/youtube/danmaku/youtube_danmaku_session.dart';
import 'package:live_sites/src/platforms/youtube/parsers/youtube_protobuf.dart';
import 'package:live_sites/src/platforms/youtube/youtube_site.dart';
import 'package:test/test.dart';

/// The samples of the replayed tests, under the platform's fixture directory.
/// Each names one chat answer sequence (the answers are given in call order
/// and the last repeats): `S01` the join history, `S02` the continuation the
/// join hands out then `next`, `S03` the walk through a reload restart,
/// `S04` the plain 1 s answer, `S05` the same with a 5 s poll, `S06` the chat
/// the feed says is over, `S07`/`S08` the 404 and 429 refusals, `S09` the
/// request that never answers, `S10` the refused live view and `S11` the
/// transport breakdown before the reload restart.
const String _samples = 'test/fixtures/youtube';

/// The transport under the replayed tests: [samples] answer, every request is
/// recorded.
ReplayHttp _replay(List<String> samples) => ReplayHttp.fixtures(_samples, samples);

/// The decoded JSON body of a request.
Map<String, Object?> _body(LiveRequest request) =>
    (jsonDecode(request.body!) as Map<String, Object?>).cast<String, Object?>();

/// The continuation each recorded request asked for, in order.
List<String> _asked(ReplayHttp http) => [for (final request in http.requests) _body(request)['continuation']! as String];

/// The page's "Top chat" continuation token, which the codec rewrites to "Live
/// chat" (field 1 of field 16 of field 119693434: 4 to 1).
String _topChatToken({int filler = 1}) {
  final view = YoutubeProtoWriter()..integer(1, 4);
  final wrapper =
      (YoutubeProtoWriter()
            ..bytes(16, view.toBytes())
            ..integer(7, filler))
          .toBytes();
  final outer = YoutubeProtoWriter()..bytes(119693434, wrapper);
  return base64Url.encode(outer.toBytes()).replaceAll('=', '%3D');
}

YoutubeDanmakuSession _session(
  LiveHttp http, {
  String continuation = 'join',
  bool allChat = false,
  int? viewers,
}) => YoutubeDanmakuSession(
  args: YoutubeDanmakuArgs(videoId: 'vid1', continuation: continuation, viewers: viewers),
  http: YouTubeHttp(http),
  allChat: allChat,
);

Future<void> _until(bool Function() test, {int seconds = 8}) async {
  for (var tick = 0; tick < seconds * 20; tick++) {
    if (test()) return;
    await Future<void>.delayed(const Duration(milliseconds: 50));
  }
  throw StateError('never happened');
}

void main() {
  group('joining', () {
    test('the first answer is history: only the viewers and the pinned super chats are reported', () async {
      final http = _replay(['S01-chat-history']);
      final session = _session(http, viewers: 1250);
      final seen = <LiveMessage>[];
      final subscription = session.events.listen(seen.add);
      addTearDown(session.dispose);

      expect(await session.connect(), isNull);
      await _until(() => seen.length >= 2);
      expect(seen.map((message) => message.type), [LiveMessageType.audienceUpdate, LiveMessageType.superChat]);
      expect(seen.first.payload, isNotNull);
      expect(seen.last.text, 'still pinned', reason: 'the ticker still holds it up');
      expect(seen.last.replayed, isTrue);
      expect(seen.where((message) => message.text == 'from the history'), isEmpty, reason: 'history is not replayed');
      await subscription.cancel();
    });

    test('the next request asks for the continuation the answer gave', () async {
      final http = _replay(['S02-chat-c2-then-next']);
      final session = _session(http);
      final seen = <LiveMessage>[];
      final subscription = session.events.listen(seen.add);
      addTearDown(session.dispose);

      await session.connect();
      expect(_asked(http), ['join']);
      await _until(() => http.requests.length >= 2);
      expect(_asked(http), ['join', 'c2'], reason: 'the join answer handed out c2');
      await _until(() => http.requests.length >= 3);
      expect(_asked(http).last, 'next', reason: 'the second answer handed out next and the third ask uses it');
      expect(
        seen.where((message) => message.type == LiveMessageType.chat),
        hasLength(2),
        reason: 'both polls after the join are reported',
      );
      await subscription.cancel();
    });

    test('an answer to a reload continuation is history again and is not reported', () async {
      final http = _replay(['S03-chat-reload']);
      final session = _session(http);
      final seen = <LiveMessage>[];
      final subscription = session.events.listen(seen.add);
      addTearDown(session.dispose);

      await session.connect();
      await _until(() => _asked(http).length >= 3);
      expect(_asked(http), ['join', 'r1', 'r2']);
      expect(
        seen.where((message) => message.text == 'restarted history'),
        isEmpty,
        reason: 'the reload answer is history',
      );
      expect(seen.map((message) => message.text), contains('reported'));
      await subscription.cancel();
    });

    test('the request is an InnerTube post for the watch page, capped at 15 seconds', () async {
      final http = _replay(['S04-chat-empty']);
      final session = _session(http);
      final subscription = session.events.listen((_) {});
      addTearDown(session.dispose);

      await session.connect();
      final request = http.requests.single;
      expect(request.method, 'POST');
      expect(request.site, 'youtube');
      expect(request.url.pathSegments.contains('get_live_chat'), isTrue);
      expect(request.timeout, YoutubeDanmakuCodec.requestTimeout);
      expect(request.headers['referer'], YoutubeEndpoints.watchUrl('vid1'));
      expect(_body(request)['context'], isNotNull, reason: 'every InnerTube call names its context');
      await subscription.cancel();
    });

    test('a second connect does not start a second loop', () async {
      final http = _replay(['S05-chat-empty-slow']);
      final session = _session(http);
      final subscription = session.events.listen((_) {});
      addTearDown(session.dispose);

      expect(await session.connect(), isNull);
      expect(await session.connect(), isNull);
      expect(http.requests, hasLength(1));
      await subscription.cancel();
    });

    test('a room that names no continuation is never polled, and a disposed session says so', () async {
      final http = _replay(['S04-chat-empty']);
      final session = _session(http, continuation: '  ');
      expect(await session.connect(), isA<LiveSiteContentUnavailable>());
      expect(http.requests, isEmpty);

      await session.dispose();
      expect(await session.connect(), isA<LiveSiteUnsupported>());
    });
  });

  test('a chat the feed says is over ends the session with its notice', () async {
    final http = _replay(['S06-chat-ended']);
    final session = _session(http);
    final seen = <LiveMessage>[];
    final done = Completer<void>();
    final subscription = session.events.listen(seen.add, onDone: done.complete);
    addTearDown(session.dispose);

    expect(await session.connect(), isNull, reason: 'an ended chat is not a failed start');
    await done.future;
    expect(seen.map((message) => message.type), [LiveMessageType.notice, LiveMessageType.system]);
    expect(seen.first.text, 'This live chat replay ended.');
    expect(seen.last.text, contains('直播聊天已结束'));
    expect(http.requests, hasLength(1), reason: 'it is not asked again');
    await subscription.cancel();
  });

  group('when an answer does not come', () {
    test('a not-found or a risk-control refusal ends it at once, and is not retried', () async {
      for (final (sample, status) in [('S07-chat-404', 404), ('S12-chat-403', 403)]) {
        final http = _replay([sample]);
        final session = _session(http);
        final subscription = session.events.listen((_) {});
        addTearDown(session.dispose);

        final error = await session.connect();
        expect(error, isA<LiveSiteError>(), reason: 'HTTP $status');
        expect(http.requests, hasLength(1), reason: 'HTTP $status is terminal');
        await subscription.cancel();
      }
    });

    test('a rate limit is retried three times and then the chat says it never began', () async {
      final http = _replay(['S08-chat-429']);
      final session = _session(http);
      final subscription = session.events.listen((_) {});
      addTearDown(session.dispose);

      final error = await session.connect();
      expect(error, isA<LiveSiteNetworkError>());
      expect(error!.message, contains('live chat failed to start'));
      expect(http.requests, hasLength(YoutubeDanmakuCodec.startAttempts));
      await subscription.cancel();
    });

    test('disconnect stops the poll and the join is not a failure', () async {
      final http = _replay(['S09-chat-hang']);
      final session = _session(http);
      final subscription = session.events.listen((_) {});
      addTearDown(session.dispose);

      final joining = session.connect();
      await _until(() => http.requests.isNotEmpty);
      await session.disconnect();
      expect(await joining, isNull, reason: 'a stopped join is not a failed one');
      expect(http.requests, hasLength(1), reason: 'the cancelled request is not retried or re-asked');
      await subscription.cancel();
    });
  });

  group('the every-message view', () {
    test('a restart is asked in the live view first', () async {
      final top = _topChatToken();
      final live = YoutubeDanmakuCodec.allChatContinuation(top)!;
      expect(live, isNot(top));
      final http = _replay(['S04-chat-empty']);
      final session = _session(http, continuation: top, allChat: true);
      final subscription = session.events.listen((_) {});
      addTearDown(session.dispose);

      await session.connect();
      expect(_asked(http).single, live, reason: 'the join is a restart: it asks for every message');
      await _until(() => http.requests.length >= 2);
      expect(_asked(http).last, 'next', reason: 'a continuation from the live view is not rewritten again');
      await subscription.cancel();
    });

    test('a refusal turns the view off for the rest of the run and asks as it came', () async {
      final top = _topChatToken();
      final live = YoutubeDanmakuCodec.allChatContinuation(top)!;
      final http = _replay(['S10-chat-live-refused']);
      final session = _session(http, continuation: top, allChat: true);
      final seen = <LiveMessage>[];
      final subscription = session.events.listen(seen.add);
      addTearDown(session.dispose);

      expect(await session.connect(), isNull, reason: 'the original continuation still joins');
      expect(_asked(http), [live, top]);
      await subscription.cancel();
    });

    test('a transport breakdown is not a refusal: the live view stays on', () async {
      final first = _topChatToken();
      final second = _topChatToken(filler: 2);
      final liveFirst = YoutubeDanmakuCodec.allChatContinuation(first)!;
      final liveSecond = YoutubeDanmakuCodec.allChatContinuation(second)!;
      final http = _replay(['S11-chat-connect-then-reload']);
      final session = _session(http, continuation: first, allChat: true);
      final subscription = session.events.listen((_) {});
      addTearDown(session.dispose);

      expect(await session.connect(), isNull);
      expect(_asked(http), [liveFirst, liveFirst], reason: 'the breakdown was retried, not answered with the other view');

      await _until(() => http.requests.length >= 3);
      expect(_asked(http).last, liveSecond, reason: 'the reload restart is still asked in the live view');
      expect(liveSecond, isNot(liveFirst));
      await subscription.cancel();
    });
  });
}
