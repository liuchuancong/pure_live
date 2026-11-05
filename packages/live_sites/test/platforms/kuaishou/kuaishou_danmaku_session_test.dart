import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:live_net/live_net.dart';
import 'package:live_sites/src/core/live_site_error.dart';
import 'package:live_sites/src/models/enums/live_message_type.dart';
import 'package:live_sites/src/models/message/live_message/live_message.dart';
import 'package:live_sites/src/platforms/kuaishou/api/kuaishou_endpoints.dart';
import 'package:live_sites/src/platforms/kuaishou/api/kuaishou_http.dart';
import 'package:live_sites/src/platforms/kuaishou/danmaku/kuaishou_danmaku_codec.dart';
import 'package:live_sites/src/platforms/kuaishou/danmaku/kuaishou_danmaku_session.dart';
import 'package:live_sites/src/platforms/kuaishou/kuaishou_manifest.dart';
import 'package:live_sites/src/platforms/kuaishou/kuaishou_site.dart';
import 'package:test/test.dart';

// The private helpers spell their own class name in their constructors, as the
// package's value wrappers do.
// ignore_for_file: unnecessary_type_name_in_constructor

/// The transport as the feed reads it: every request recorded, one answer per
/// call (a handler may throw, which is how a breakdown is written).
final class _FakeHttp implements LiveHttp {
  _FakeHttp(this.answer);

  /// The answer for the request at hand — [LiveRequest.url] says which endpoint.
  final FutureOr<Object> Function(LiveRequest request, int call) answer;

  /// Every request that went through, in order.
  final List<LiveRequest> sent = [];

  @override
  Future<LiveResponse> send(LiveRequest request) async {
    final call = sent.length;
    sent.add(request);
    final result = await answer(request, call);
    if (result is _Breaks) throw result.error;
    if (result is LiveResponse) return result;
    throw StateError('a feed request is answered with a response or a breakdown');
  }

  @override
  Future<LiveStreamedResponse> open(LiveRequest request) async => throw UnimplementedError();

  @override
  void close() {}
}

/// A transport breakdown, so a handler can name one without throwing it here.
final class _Breaks {
  const _Breaks(this.error);

  final Exception error;
}

/// A 2xx answer holding this JSON body.
LiveResponse _ok(Object? body) => LiveResponse(
  statusCode: 200,
  headers: const <String, String>{},
  bodyBytes: Uint8List.fromList(utf8.encode(jsonEncode(body))),
);

/// An answer that is not usable (the transport gives a status, and `feedJson`
/// turns a non-2xx into a failure).
LiveResponse _status(int code) => LiveResponse(
  statusCode: code,
  headers: const <String, String>{},
  bodyBytes: Uint8List.fromList(utf8.encode('nope')),
);

/// One feed answer.
LiveResponse _feed({
  Object? result = 1,
  String cursor = 'next',
  int pull = 1,
  Object? watching = '76',
  List<Object?> feeds = const [
    {
      'type': 'comment',
      'content': 'hello',
      'id': 'c1',
      'time': 1790733600000,
      'author': {'userName': 'Ann', 'userId': 'u1'},
    },
  ],
}) => _ok({
  'result': result,
  'cursor': cursor,
  'pullCycleSeconds': pull,
  'currentWatchingCount': watching,
  'liveStreamFeeds': feeds,
});

/// A session over [http] for the broadcast `live1`.
KuaishouDanmakuSession _session(
  LiveHttp http, {
  Map<String, String> emotes = const {},
  String cookie = '',
  String liveStreamId = 'live1',
}) => KuaishouDanmakuSession(
  args: KuaishouDanmakuArgs(liveStreamId: liveStreamId, cookie: cookie, emotes: emotes),
  http: KuaishouHttp(http),
);

/// Waits until [test] holds or the clock runs out; the poll loop is on real
/// timers, so this is how "the next request went out" is observed.
Future<void> _until(bool Function() test, {int seconds = 6}) async {
  for (var tick = 0; tick < seconds * 20; tick++) {
    if (test()) return;
    await Future<void>.delayed(const Duration(milliseconds: 50));
  }
  throw StateError('never happened');
}

void main() {
  group('joining the feed', () {
    test('the first answer is reported and the next request carries its cursor', () async {
      final http = _FakeHttp((request, call) => _feed(cursor: call == 0 ? 'next' : 'later'));
      final session = _session(http);
      final seen = <LiveMessage>[];
      final subscription = session.events.listen(seen.add);
      addTearDown(session.dispose);

      expect(await session.connect(), isNull);
      await _until(() => seen.length >= 2);
      expect(seen.map((message) => message.type), [LiveMessageType.audienceUpdate, LiveMessageType.chat]);
      expect(seen.last.text, 'hello');
      expect(seen.last.sender?.userName, 'Ann');
      expect(seen.last.messageId, 'kuaishou:c1');

      await _until(() => http.sent.length >= 2);
      expect(http.sent.first.url.queryParameters.containsKey('cursor'), isFalse);
      expect(http.sent.first.url.queryParameters['liveStreamId'], 'live1');
      expect(http.sent[1].url.queryParameters['cursor'], 'next');
      expect(http.sent, hasLength(2), reason: 'one answer at a time: the loop waits for the pull cycle');

      await session.disconnect();
      final after = http.sent.length;
      await Future<void>.delayed(const Duration(milliseconds: 1200));
      expect(http.sent, hasLength(after), reason: 'disconnect stops the loop');
      await subscription.cancel();
    });

    test('a cursor the feed leaves empty keeps the one already held', () async {
      final http = _FakeHttp((request, call) => _feed(cursor: call == 1 ? '' : 'kept'));
      final session = _session(http);
      final subscription = session.events.listen((_) {});
      addTearDown(session.dispose);

      await session.connect();
      await _until(() => http.sent.length >= 3);
      expect(http.sent[1].url.queryParameters['cursor'], 'kept');
      expect(http.sent[2].url.queryParameters['cursor'], 'kept', reason: 'an empty cursor is not a reset');
      await subscription.cancel();
    });

    test(
      'the request says who it is for, waits at most the site cap, and carries the cookie only when there is one',
      () async {
        final withCookie = _FakeHttp((request, call) => _feed(pull: 10));
        final anonymous = _FakeHttp((request, call) => _feed(pull: 10));
        final cookieSession = _session(withCookie, cookie: '  sid=1 ');
        final anonymousSession = _session(anonymous);
        addTearDown(cookieSession.dispose);
        addTearDown(anonymousSession.dispose);

        await cookieSession.connect();
        final request = withCookie.sent.single;
        expect(request.method, 'GET');
        expect(request.site, kuaishouSiteId);
        expect(request.timeout, KuaishouEndpoints.requestTimeout);
        expect(request.headers['cookie'], 'sid=1', reason: 'trimmed as written into the args');
        expect(request.headers['User-Agent'], KuaishouEndpoints.feedUserAgent);
        expect(request.headers['Referer'], KuaishouEndpoints.feedReferer);

        await anonymousSession.connect();
        expect(anonymous.sent.single.headers.containsKey('cookie'), isFalse);
      },
    );

    test('the room page emoji table rides into every reported comment', () async {
      final http = _FakeHttp(
        (request, call) => _feed(
          pull: 10,
          feeds: [
            {
              'type': 'comment',
              'content': '真好[笑哭]',
              'id': 'c9',
              'time': 1790733600000,
              'author': {'userName': 'Ann', 'userId': 'u1'},
            },
          ],
        ),
      );
      final session = _session(http, emotes: const {'[笑哭]': 'https://cdn.example/laugh.png'});
      final seen = <LiveMessage>[];
      final subscription = session.events.listen(seen.add);
      addTearDown(session.dispose);

      await session.connect();
      await _until(() => seen.isNotEmpty);
      expect(seen.last.emotes.map((emote) => emote.code), ['[笑哭]']);
      await subscription.cancel();
    });
  });

  group('when an answer does not come', () {
    test('one pull tries the backup endpoint before it fails', () async {
      final http = _FakeHttp(
        (request, call) =>
            request.url.host == KuaishouDanmakuCodec.endpoints.first.host ? _status(500) : _feed(pull: 10),
      );
      final session = _session(http);
      final seen = <LiveMessage>[];
      final subscription = session.events.listen(seen.add);
      addTearDown(session.dispose);

      expect(await session.connect(), isNull, reason: 'the fallback answer joins the feed');
      expect(http.sent.map((request) => request.url.host), ['livev.m.chenzhongtech.com', 'm.gifshow.com']);
      await _until(() => seen.length >= 2);
      expect(seen, hasLength(2));
      await subscription.cancel();
    });

    test('the first request is asked three times, and then the feed says it never began', () async {
      final http = _FakeHttp((request, call) => _status(500));
      final session = _session(http);
      final subscription = session.events.listen((_) {});
      addTearDown(session.dispose);

      final started = DateTime.now();
      final error = await session.connect();
      expect(error, isA<LiveSiteNetworkError>());
      expect(error!.message, contains('danmaku feed failed to start'));
      expect(
        http.sent,
        hasLength(KuaishouDanmakuCodec.endpoints.length * (KuaishouDanmakuCodec.startRetryDelays.length + 1)),
        reason: 'three attempts of two endpoints each',
      );
      final waited = DateTime.now().difference(started);
      expect(waited.inMilliseconds, greaterThan(1900), reason: 'the 0.6 s and 1.4 s waits are really spent');
      await subscription.cancel();
    });

    test('a cancellation is not passed on to the backup endpoint', () async {
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
      expect(http.sent, hasLength(1), reason: 'the fallback is for a breakdown, not for a cancellation');
      await subscription.cancel();
    });

    test('a room that names no broadcast is never polled', () async {
      final http = _FakeHttp((request, call) => _feed());
      final session = _session(http, liveStreamId: '  ');
      expect(await session.connect(), isA<LiveSiteContentUnavailable>());
      expect(http.sent, isEmpty);

      await session.dispose();
      expect(await session.connect(), isA<LiveSiteUnsupported>());
    });

    test('a body the codec refuses is a failed answer, not a crash', () async {
      final http = _FakeHttp((request, call) => _feed(result: 2, pull: 10));
      final session = _session(http);
      final subscription = session.events.listen((_) {});
      addTearDown(session.dispose);

      expect(await session.connect(), isA<LiveSiteNetworkError>(), reason: 'a refused feed never joined');
      await subscription.cancel();
    });

    test('dispose closes the stream and ends the loop', () async {
      final http = _FakeHttp((request, call) => _feed());
      final session = _session(http);
      final closed = Completer<void>();
      final subscription = session.events.listen((_) {}, onDone: closed.complete);
      await session.connect();
      final sent = http.sent.length;
      await session.dispose();
      await closed.future;
      await Future<void>.delayed(const Duration(milliseconds: 1200));
      expect(http.sent, hasLength(sent), reason: 'nothing is asked after the stream is closed');
      await subscription.cancel();
    });
  });
}
