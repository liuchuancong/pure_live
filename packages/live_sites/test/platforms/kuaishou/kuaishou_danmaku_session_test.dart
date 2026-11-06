import 'dart:async';

import 'package:live_net/live_net.dart';
import 'package:live_net/testing.dart';
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

/// The samples of the replayed tests, under the platform's fixture directory.
/// Each names one feed answer sequence (the answers are given in call order
/// and the last repeats): `S01` the cursor `next` then `later`, `S02` the
/// cursor the feed leaves empty, `S03`/`S07` the slow polls on the two feed
/// endpoints, `S04` the emoji comment, `S05`/`S06` the 500 refusals,
/// `S08` the endpoint that never answers, `S09`/`S10` the refused feeds and
/// `S11` the plain 1 s feed.
const String _samples = 'test/fixtures/kuaishou';

/// What differs per poll: the cursor the previous answer handed out; the
/// samples carry the stand-in value the first request was recorded with.
const Set<String> _perPoll = {'cursor'};

/// The transport under the replayed tests: [samples] answer, every request is
/// recorded.
ReplayHttp _replay(List<String> samples) => ReplayHttp.fixtures(_samples, samples, ignoredQuery: _perPoll);

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
      final http = _replay(['S01-feed-next-then-later']);
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

      await _until(() => http.requests.length >= 2);
      expect(http.requests.first.url.queryParameters.containsKey('cursor'), isFalse);
      expect(http.requests.first.url.queryParameters['liveStreamId'], 'live1');
      expect(http.requests[1].url.queryParameters['cursor'], 'next');
      expect(http.requests, hasLength(2), reason: 'one answer at a time: the loop waits for the pull cycle');

      await session.disconnect();
      final after = http.requests.length;
      await Future<void>.delayed(const Duration(milliseconds: 1200));
      expect(http.requests, hasLength(after), reason: 'disconnect stops the loop');
      await subscription.cancel();
    });

    test('a cursor the feed leaves empty keeps the one already held', () async {
      final http = _replay(['S02-feed-kept-empty-kept']);
      final session = _session(http);
      final subscription = session.events.listen((_) {});
      addTearDown(session.dispose);

      await session.connect();
      await _until(() => http.requests.length >= 3);
      expect(http.requests[1].url.queryParameters['cursor'], 'kept');
      expect(http.requests[2].url.queryParameters['cursor'], 'kept', reason: 'an empty cursor is not a reset');
      await subscription.cancel();
    });

    test(
      'the request says who it is for, waits at most the site cap, and carries the cookie only when there is one',
      () async {
        final withCookie = _replay(['S03-feed-slow']);
        final anonymous = _replay(['S03-feed-slow']);
        final cookieSession = _session(withCookie, cookie: '  sid=1 ');
        final anonymousSession = _session(anonymous);
        addTearDown(cookieSession.dispose);
        addTearDown(anonymousSession.dispose);

        await cookieSession.connect();
        final request = withCookie.requests.single;
        expect(request.method, 'GET');
        expect(request.site, kuaishouSiteId);
        expect(request.timeout, KuaishouEndpoints.requestTimeout);
        expect(request.headers['cookie'], 'sid=1', reason: 'trimmed as written into the args');
        expect(request.headers['User-Agent'], KuaishouEndpoints.feedUserAgent);
        expect(request.headers['Referer'], KuaishouEndpoints.feedReferer);

        await anonymousSession.connect();
        expect(anonymous.requests.single.headers.containsKey('cookie'), isFalse);
      },
    );

    test('the room page emoji table rides into every reported comment', () async {
      final http = _replay(['S04-feed-emote']);
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
      final http = _replay(['S05-feed-primary-500', 'S07-feed-backup-slow']);
      final session = _session(http);
      final seen = <LiveMessage>[];
      final subscription = session.events.listen(seen.add);
      addTearDown(session.dispose);

      expect(await session.connect(), isNull, reason: 'the fallback answer joins the feed');
      expect(http.requests.map((request) => request.url.host), ['livev.m.chenzhongtech.com', 'm.gifshow.com']);
      await _until(() => seen.length >= 2);
      expect(seen, hasLength(2));
      await subscription.cancel();
    });

    test('the first request is asked three times, and then the feed says it never began', () async {
      final http = _replay(['S05-feed-primary-500', 'S06-feed-backup-500']);
      final session = _session(http);
      final subscription = session.events.listen((_) {});
      addTearDown(session.dispose);

      final started = DateTime.now();
      final error = await session.connect();
      expect(error, isA<LiveSiteNetworkError>());
      expect(error!.message, contains('danmaku feed failed to start'));
      expect(
        http.requests,
        hasLength(KuaishouDanmakuCodec.endpoints.length * (KuaishouDanmakuCodec.startRetryDelays.length + 1)),
        reason: 'three attempts of two endpoints each',
      );
      final waited = DateTime.now().difference(started);
      expect(waited.inMilliseconds, greaterThan(1900), reason: 'the 0.6 s and 1.4 s waits are really spent');
      await subscription.cancel();
    });

    test('a cancellation is not passed on to the backup endpoint', () async {
      final http = _replay(['S08-feed-hang']);
      final session = _session(http);
      final subscription = session.events.listen((_) {});
      addTearDown(session.dispose);

      final joining = session.connect();
      await _until(() => http.requests.isNotEmpty);
      await session.disconnect();
      expect(await joining, isNull, reason: 'a stopped join is not a failed one');
      expect(http.requests, hasLength(1), reason: 'the fallback is for a breakdown, not for a cancellation');
      await subscription.cancel();
    });

    test('a room that names no broadcast is never polled', () async {
      final http = _replay(['S11-feed-default']);
      final session = _session(http, liveStreamId: '  ');
      expect(await session.connect(), isA<LiveSiteContentUnavailable>());
      expect(http.requests, isEmpty);

      await session.dispose();
      expect(await session.connect(), isA<LiveSiteUnsupported>());
    });

    test('a body the codec refuses is a failed answer, not a crash', () async {
      final http = _replay(['S09-feed-primary-refused', 'S10-feed-backup-refused']);
      final session = _session(http);
      final subscription = session.events.listen((_) {});
      addTearDown(session.dispose);

      expect(await session.connect(), isA<LiveSiteNetworkError>(), reason: 'a refused feed never joined');
      await subscription.cancel();
    });

    test('dispose closes the stream and ends the loop', () async {
      final http = _replay(['S11-feed-default']);
      final session = _session(http);
      final closed = Completer<void>();
      final subscription = session.events.listen((_) {}, onDone: closed.complete);
      await session.connect();
      final sent = http.requests.length;
      await session.dispose();
      await closed.future;
      await Future<void>.delayed(const Duration(milliseconds: 1200));
      expect(http.requests, hasLength(sent), reason: 'nothing is asked after the stream is closed');
      await subscription.cancel();
    });
  });
}
