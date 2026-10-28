import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:live_net/live_net.dart';
import 'package:live_sites/src/capabilities/live_cookie_refusal_feed.dart';
import 'package:live_sites/src/platforms/twitch/api/twitch_http.dart';
import 'package:live_sites/src/platforms/twitch/capabilities/twitch_cookie_refusal_feed.dart';
import 'package:live_sites/src/platforms/twitch/twitch_site.dart';
import 'package:test/test.dart';

/// The stored cookie the tests hand the site (it holds an `auth-token`).
const String _cookie = 'auth-token=token; login=someone';

/// One canned GraphQL answer.
typedef _Answer = ({int status, String body});

LiveResponse _response(_Answer answer) =>
    LiveResponse(statusCode: answer.status, headers: const {}, bodyBytes: Uint8List.fromList(utf8.encode(answer.body)));

/// A transport that answers [answers] in order and records the requests.
final class _FakeHttp implements LiveHttp {
  new(this.answers);

  final List<_Answer> answers;
  final List<LiveRequest> requests = [];

  @override
  Future<LiveResponse> send(LiveRequest request) async {
    requests.add(request);
    return _response(answers.removeAt(0));
  }

  @override
  Future<LiveStreamedResponse> open(LiveRequest request) => throw UnimplementedError();

  @override
  void close() {}
}

/// A `PlaybackAccessToken` answer with an unrestricted token.
const String _token = '{"data":{"streamPlaybackAccessToken":{"value":"{}","signature":"sig"}}}';

void main() {
  group('cookie refusals', () {
    test('a 401 for the stored session reports one event and falls back anonymously', () async {
      final http = _FakeHttp([(status: 401, body: ''), (status: 200, body: _token), (status: 200, body: _token)]);
      final site = TwitchSite(http: TwitchHttp(http), loginCookie: () => _cookie);
      final feed = site.capability<LiveCookieRefusalFeed>();
      expect(feed, isA<TwitchCookieRefusalFeed>());
      final refusals = <void>[];
      final subscription = feed!.cookieRefusals.listen(refusals.add);
      addTearDown(subscription.cancel);

      final token = await site.accessToken('somechannel');
      await pumpEventQueue();

      expect(token.signature, 'sig');
      expect(refusals, hasLength(1));
      expect(http.requests, hasLength(2));
      expect(http.requests.first.headers['cookie'], _cookie);
      expect(http.requests.last.headers.containsKey('cookie'), isFalse);

      await site.accessToken('somechannel');
      expect(refusals, hasLength(1), reason: 'the refused cookie is not sent again');
      expect(http.requests, hasLength(3));
    });

    test('an accepted session reports nothing', () async {
      final http = _FakeHttp([(status: 200, body: _token)]);
      final site = TwitchSite(http: TwitchHttp(http), loginCookie: () => _cookie);
      final refusals = <void>[];
      final subscription = site.cookieRefusals.listen(refusals.add);
      addTearDown(subscription.cancel);

      await site.accessToken('somechannel');
      await pumpEventQueue();

      expect(refusals, isEmpty);
      expect(http.requests.single.headers['cookie'], _cookie);
    });
  });
}
