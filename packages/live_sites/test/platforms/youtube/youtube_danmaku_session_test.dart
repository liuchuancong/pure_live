import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:live_net/live_net.dart';
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

// The private helpers spell their own class name in their constructors, as the
// package's value wrappers do.
// ignore_for_file: unnecessary_type_name_in_constructor

/// A transport breakdown a handler can hand back without throwing it here.
final class _Breaks {
  const _Breaks(this.error);

  final Exception error;
}

/// The transport as the chat reads it: every request recorded, one answer per
/// call.
final class _FakeHttp implements LiveHttp {
  _FakeHttp(this.answer);

  final FutureOr<Object> Function(LiveRequest request, int call) answer;

  /// Every request that went through, in order.
  final List<LiveRequest> sent = [];

  /// The continuation each request asked for, in order.
  List<String> get asked => [for (final request in sent) _body(request)['continuation']! as String];

  @override
  Future<LiveResponse> send(LiveRequest request) async {
    final call = sent.length;
    sent.add(request);
    final result = await answer(request, call);
    if (result is _Breaks) throw result.error;
    if (result is LiveResponse) return result;
    throw StateError('a chat request is answered with a response or a breakdown');
  }

  @override
  Future<LiveStreamedResponse> open(LiveRequest request) async => throw UnimplementedError();

  @override
  void close() {}
}

/// A 2xx answer holding this JSON body.
LiveResponse _ok(Object? body) => LiveResponse(
  statusCode: 200,
  headers: const <String, String>{},
  bodyBytes: Uint8List.fromList(utf8.encode(jsonEncode(body))),
);

/// An answer with this status (bad ones are ordinary responses here).
LiveResponse _status(int code) => LiveResponse(
  statusCode: code,
  headers: const <String, String>{},
  bodyBytes: Uint8List.fromList(utf8.encode('{"a":1}')),
);

/// The decoded JSON body of a request.
Map<String, Object?> _body(LiveRequest request) =>
    (jsonDecode(request.body!) as Map<String, Object?>).cast<String, Object?>();

Map<String, Object?> _label(String text) => {
  'runs': [
    {'text': text},
  ],
};

Map<String, Object?> _chatAction(String text, {String id = 'm1'}) => {
  'addChatItemAction': {
    'item': {
      'liveChatTextMessageRenderer': {
        'id': id,
        'authorName': 'Ann',
        'message': _label(text),
        'timestampUsec': '1790519893202000',
      },
    },
  },
};

/// A ticker item with time left: the join reports it, the chat lines it follows
/// are history.
Map<String, Object?> _tickerAction(String id) => {
  'addLiveChatTickerItemAction': {
    'item': {
      'liveChatTickerPaidMessageItemRenderer': {
        'id': id,
        'fullDurationSec': 315,
        'durationSec': '60',
        'showItemEndpoint': {
          'showLiveChatItemEndpoint': {
            'renderer': {
              'liveChatPaidMessageRenderer': {
                'id': id,
                'authorName': 'Ann',
                'purchaseAmountText': r'$5.00',
                'message': _label('still pinned'),
                'headerBackgroundColor': 0xFF00BFA5,
                'timestampUsec': '1790519893202000',
              },
            },
          },
        },
      },
    },
  },
};

Map<String, Object?> _timed(String token, {String timeoutMs = '1000'}) => {
  'timedContinuationData': {'continuation': token, 'timeoutMs': timeoutMs},
};

/// One `get_live_chat` answer.
Map<String, Object?> _answer(List<Object?> actions, {List<Object?>? continuations}) => {
  'continuationContents': {
    'liveChatContinuation': {
      'actions': actions,
      'continuations': continuations ?? <Object?>[_timed('next')],
    },
  },
};

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

YoutubeDanmakuSession _session(LiveHttp http, {String continuation = 'join', bool allChat = false, int? viewers}) =>
    YoutubeDanmakuSession(
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
      final http = _FakeHttp((request, call) => _ok(_answer([_chatAction('from the history'), _tickerAction('p1')])));
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
      final http = _FakeHttp(
        (request, call) => _ok(_answer([_chatAction('live')], continuations: [_timed(call == 0 ? 'c2' : 'next')])),
      );
      final session = _session(http);
      final seen = <LiveMessage>[];
      final subscription = session.events.listen(seen.add);
      addTearDown(session.dispose);

      await session.connect();
      expect(http.asked, ['join']);
      await _until(() => http.sent.length >= 2);
      expect(http.asked, ['join', 'c2'], reason: 'the join answer handed out c2');
      await _until(() => http.sent.length >= 3);
      expect(http.asked.last, 'next', reason: 'the second answer handed out next and the third ask uses it');
      expect(
        seen.where((message) => message.type == LiveMessageType.chat),
        hasLength(2),
        reason: 'both polls after the join are reported',
      );
      await subscription.cancel();
    });

    test('an answer to a reload continuation is history again and is not reported', () async {
      final http = _FakeHttp((request, call) {
        final body = [
          _ok(
            _answer(
              [_chatAction('join history')],
              continuations: [
                {
                  'reloadContinuationData': {'continuation': 'r1'},
                },
              ],
            ),
          ),
          _ok(_answer([_chatAction('restarted history')], continuations: [_timed('r2')])),
          _ok(_answer([_chatAction('reported')], continuations: [_timed('r3')])),
        ][call];
        return body;
      });
      final session = _session(http);
      final seen = <LiveMessage>[];
      final subscription = session.events.listen(seen.add);
      addTearDown(session.dispose);

      await session.connect();
      await _until(() => http.asked.length >= 3);
      expect(http.asked, ['join', 'r1', 'r2']);
      expect(
        seen.where((message) => message.text == 'restarted history'),
        isEmpty,
        reason: 'the reload answer is history',
      );
      expect(seen.map((message) => message.text), contains('reported'));
      await subscription.cancel();
    });

    test('the request is an InnerTube post for the watch page, capped at 15 seconds', () async {
      final http = _FakeHttp((request, call) => _ok(_answer(const [])));
      final session = _session(http);
      final subscription = session.events.listen((_) {});
      addTearDown(session.dispose);

      await session.connect();
      final request = http.sent.single;
      expect(request.method, 'POST');
      expect(request.site, 'youtube');
      expect(request.url.pathSegments.contains('get_live_chat'), isTrue);
      expect(request.timeout, YoutubeDanmakuCodec.requestTimeout);
      expect(request.headers['referer'], YoutubeEndpoints.watchUrl('vid1'));
      expect(_body(request)['context'], isNotNull, reason: 'every InnerTube call names its context');
      await subscription.cancel();
    });

    test('a second connect does not start a second loop', () async {
      final http = _FakeHttp(
        (request, call) => _ok(_answer(const [], continuations: [_timed('next', timeoutMs: '5000')])),
      );
      final session = _session(http);
      final subscription = session.events.listen((_) {});
      addTearDown(session.dispose);

      expect(await session.connect(), isNull);
      expect(await session.connect(), isNull);
      expect(http.sent, hasLength(1));
      await subscription.cancel();
    });

    test('a room that names no continuation is never polled, and a disposed session says so', () async {
      final http = _FakeHttp((request, call) => _ok(_answer(const [])));
      final session = _session(http, continuation: '  ');
      expect(await session.connect(), isA<LiveSiteContentUnavailable>());
      expect(http.sent, isEmpty);

      await session.dispose();
      expect(await session.connect(), isA<LiveSiteUnsupported>());
    });
  });

  test('a chat the feed says is over ends the session with its notice', () async {
    final http = _FakeHttp(
      (request, call) => _ok({
        'continuations': [
          {
            'messageRenderer': {'text': _label('This live chat replay ended.')},
          },
        ],
      }),
    );
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
    expect(http.sent, hasLength(1), reason: 'it is not asked again');
    await subscription.cancel();
  });

  group('when an answer does not come', () {
    test('a not-found or a risk-control refusal ends it at once, and is not retried', () async {
      for (final status in [404, 403]) {
        final http = _FakeHttp((request, call) => _status(status));
        final session = _session(http);
        final subscription = session.events.listen((_) {});
        addTearDown(session.dispose);

        final error = await session.connect();
        expect(error, isA<LiveSiteError>(), reason: 'HTTP $status');
        expect(http.sent, hasLength(1), reason: 'HTTP $status is terminal');
        await subscription.cancel();
      }
    });

    test('a rate limit is retried three times and then the chat says it never began', () async {
      final http = _FakeHttp((request, call) => _status(429));
      final session = _session(http);
      final subscription = session.events.listen((_) {});
      addTearDown(session.dispose);

      final error = await session.connect();
      expect(error, isA<LiveSiteNetworkError>());
      expect(error!.message, contains('live chat failed to start'));
      expect(http.sent, hasLength(YoutubeDanmakuCodec.startAttempts));
      await subscription.cancel();
    });

    test('disconnect stops the poll and the join is not a failure', () async {
      final http = _FakeHttp((request, call) async {
        await request.cancelToken.whenCancel;
        return const _Breaks(CancelledFailure());
      });
      final session = _session(http);
      final subscription = session.events.listen((_) {});
      addTearDown(session.dispose);

      final joining = session.connect();
      await _until(() => http.sent.isNotEmpty);
      await session.disconnect();
      expect(await joining, isNull, reason: 'a stopped join is not a failed one');
      expect(http.sent, hasLength(1), reason: 'the cancelled request is not retried or re-asked');
      await subscription.cancel();
    });
  });

  group('the every-message view', () {
    test('a restart is asked in the live view first', () async {
      final top = _topChatToken();
      final live = YoutubeDanmakuCodec.allChatContinuation(top)!;
      expect(live, isNot(top));
      final http = _FakeHttp((request, call) => _ok(_answer(const [])));
      final session = _session(http, continuation: top, allChat: true);
      final subscription = session.events.listen((_) {});
      addTearDown(session.dispose);

      await session.connect();
      expect(http.asked.single, live, reason: 'the join is a restart: it asks for every message');
      await _until(() => http.sent.length >= 2);
      expect(http.asked.last, 'next', reason: 'a continuation from the live view is not rewritten again');
      await subscription.cancel();
    });

    test('a refusal turns the view off for the rest of the run and asks as it came', () async {
      final top = _topChatToken();
      final live = YoutubeDanmakuCodec.allChatContinuation(top)!;
      final http = _FakeHttp(
        (request, call) => _body(request)['continuation'] == live
            ? _status(400)
            : _ok(_answer([_chatAction('as it came')], continuations: [_timed('second', timeoutMs: '5000')])),
      );
      final session = _session(http, continuation: top, allChat: true);
      final seen = <LiveMessage>[];
      final subscription = session.events.listen(seen.add);
      addTearDown(session.dispose);

      expect(await session.connect(), isNull, reason: 'the original continuation still joins');
      expect(http.asked, [live, top]);
      await subscription.cancel();
    });

    test('a transport breakdown is not a refusal: the live view stays on', () async {
      final first = _topChatToken();
      final second = _topChatToken(filler: 2);
      final liveFirst = YoutubeDanmakuCodec.allChatContinuation(first)!;
      final liveSecond = YoutubeDanmakuCodec.allChatContinuation(second)!;
      final http = _FakeHttp(
        (request, call) => call == 0
            ? const _Breaks(ConnectFailure('down'))
            : _ok(
                _answer(
                  const [],
                  continuations: [
                    {
                      'reloadContinuationData': {'continuation': second},
                    },
                  ],
                ),
              ),
      );
      final session = _session(http, continuation: first, allChat: true);
      final subscription = session.events.listen((_) {});
      addTearDown(session.dispose);

      expect(await session.connect(), isNull);
      expect(http.asked, [liveFirst, liveFirst], reason: 'the breakdown was retried, not answered with the other view');

      await _until(() => http.sent.length >= 3);
      expect(http.asked.last, liveSecond, reason: 'the reload restart is still asked in the live view');
      expect(liveSecond, isNot(liveFirst));
      await subscription.cancel();
    });
  });
}
