import 'package:live_sites/src/core/live_site_error.dart';
import 'package:test/test.dart';

LiveSiteError _network() => const LiveSiteError.network(siteId: 'x', message: 'timed out');
LiveSiteError _limited() => const LiveSiteError.rateLimit(siteId: 'x', message: '412');

void main() {
  group('what a failure means for the next attempt', () {
    test('only a blinked transport and a throttle are worth retrying', () {
      expect(_network().isTransient, isTrue);
      expect(_limited().isTransient, isTrue);
      for (final error in <LiveSiteError>[
        const LiveSiteError.notFound(siteId: 'x', message: 'gone'),
        const LiveSiteError.unsupported(siteId: 'x', message: 'no capability'),
        const LiveSiteError.parse(siteId: 'x', message: 'shape changed'),
        const LiveSiteError.authentication(siteId: 'x', message: 'needs a login'),
        const LiveSiteError.contentUnavailable(siteId: 'x', message: 'no stream'),
        const LiveSiteError.invalidArgument(siteId: 'x', message: 'not this site'),
        const LiveSiteError.unexpected(siteId: 'x', message: 'unclassified'),
      ]) {
        expect(error.isTransient, isFalse, reason: '${error.runtimeType} must not be retried blindly');
      }
    });

    test('a rate limit carries the wait the platform named', () {
      expect(
        const LiveSiteError.rateLimit(siteId: 'x', message: '429', retryAfter: Duration(seconds: 30)).retryAfter,
        const Duration(seconds: 30),
      );
      expect(_limited().retryAfter, isNull);
      expect(_network().retryAfter, isNull);
    });

    test('a refused login says whether the stored cookie is the cause', () {
      expect(const LiveSiteError.authentication(siteId: 'x', message: 'no login applied').cookieSuspect, isFalse);
      expect(
        const LiveSiteError.authentication(
          siteId: 'x',
          message: 'signature expired',
          cookieSuspect: true,
        ).cookieSuspect,
        isTrue,
      );
      // Only a failure that had a login to doubt can blame it.
      expect(_limited().cookieSuspect, isFalse);
    });

    test('the new fields are part of what makes two failures the same one', () {
      expect(
        const LiveSiteError.rateLimit(siteId: 'x', message: '429', retryAfter: Duration(seconds: 30)),
        isNot(const LiveSiteError.rateLimit(siteId: 'x', message: '429')),
      );
      expect(
        const LiveSiteError.authentication(siteId: 'x', message: 'refused', cookieSuspect: true),
        isNot(const LiveSiteError.authentication(siteId: 'x', message: 'refused')),
      );
    });

    test('the union still answers a switch by variant', () {
      String nameOf(LiveSiteError error) => switch (error) {
        LiveSiteNotFound() => 'notFound',
        LiveSiteUnsupported() => 'unsupported',
        LiveSiteNetworkError() => 'network',
        LiveSiteParseError() => 'parse',
        LiveSiteAuthenticationError() => 'authentication',
        LiveSiteRateLimitError() => 'rateLimit',
        LiveSiteContentUnavailable() => 'contentUnavailable',
        LiveSiteInvalidArgument() => 'invalidArgument',
        LiveSiteUnexpectedError() => 'unexpected',
      };

      expect(nameOf(_network()), 'network');
      expect(nameOf(_limited()), 'rateLimit');
      expect(
        nameOf(const LiveSiteError.authentication(siteId: 'x', message: 'm', cookieSuspect: true)),
        'authentication',
      );
    });
  });
}
