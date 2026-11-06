import 'package:live_net/testing.dart';
import 'package:live_sites/src/capabilities/live_cookie_refusal_feed.dart';
import 'package:live_sites/src/platforms/twitch/api/twitch_endpoints.dart';
import 'package:live_sites/src/platforms/twitch/api/twitch_http.dart';
import 'package:live_sites/src/platforms/twitch/capabilities/twitch_cookie_refusal_feed.dart';
import 'package:live_sites/src/platforms/twitch/twitch_site.dart';
import 'package:test/test.dart';

/// The stored cookie the tests hand the site (it holds an `auth-token`).
const String _cookie = 'auth-token=token; login=someone';

/// The samples of the replayed tests, one GraphQL sequence each (the answers
/// are given in call order and the last repeats): `S01` the refused session
/// then the anonymous token twice, `S02` the accepted session, `S03` the
/// Chinese tags, the English ask and the directory batch, `S04` the walk
/// whose English ask fails, `S05` the walk where every tag is named.
const String _samples = 'test/fixtures/twitch';

/// The transport under the site: [samples] answer, every request is recorded.
ReplayHttp _replay(List<String> samples) => ReplayHttp.fixtures(_samples, samples);

void main() {
  group('cookie refusals', () {
    test('a 401 for the stored session reports one event and falls back anonymously', () async {
      final http = _replay(['S01-gql-refused-then-anonymous']);
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
      final http = _replay(['S02-gql-token-ok']);
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

  group('the catalog languages', () {
    test('a tag with no Chinese name asks a second time in English', () async {
      final http = _replay(['S03-gql-tags-cn-en-directories']);
      final site = TwitchSite(http: TwitchHttp(http));

      final areas = await site.categories();

      expect(http.requests, hasLength(3));
      expect(http.requests.first.headers['accept-language'], TwitchEndpoints.acceptLanguage);
      expect(http.requests[1].headers['accept-language'], TwitchEndpoints.englishLanguage);
      expect(http.requests[1].headers.containsKey('cookie'), isFalse, reason: 'the English ask stays anonymous');
      expect(
        [for (final area in areas) if (area.parentAreaId == 't2') area.parentAreaName],
        ['Gambling'],
      );
    });

    test('a failed English ask keeps the empty names', () async {
      final http = _replay(['S04-gql-tags-en-fails']);
      final site = TwitchSite(http: TwitchHttp(http));

      final areas = await site.categories();

      expect(http.requests, hasLength(3));
      expect([for (final area in areas) if (area.parentAreaId == 't2') area.parentAreaName], ['']);
    });

    test('every tag named asks once', () async {
      final http = _replay(['S05-gql-tags-party-directories']);
      final site = TwitchSite(http: TwitchHttp(http));

      await site.categories();

      expect(http.requests, hasLength(2));
      expect(http.requests.first.headers['accept-language'], TwitchEndpoints.acceptLanguage);
    });
  });
}
