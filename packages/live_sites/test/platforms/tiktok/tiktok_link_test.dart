import 'package:live_sites/src/platforms/tiktok/parsers/tiktok_link.dart';
import 'package:test/test.dart';

/// What a link is read as. `TiktokLink` has no equality of its own, so a test
/// asks the two fields at once.
Matcher _names(TiktokLinkKind kind, String id) =>
    isA<TiktokLink>().having((link) => link.kind, 'kind', kind).having((link) => link.id, 'id', id);

final Matcher _user = _names(TiktokLinkKind.username, 'user');
final Matcher _room = _names(TiktokLinkKind.liveRoom, '123456789012345');

void main() {
  group('the two shapes', () {
    test('normalizeUsername trims, lower-cases and keeps a dot inside', () {
      expect(TiktokLink.normalizeUsername(' User '), 'user');
      expect(TiktokLink.normalizeUsername('a'), 'a');
      expect(TiktokLink.normalizeUsername('_a.b_c'), '_a.b_c');
      expect(TiktokLink.normalizeUsername('x' * 24), 'x' * 24);
      expect(TiktokLink.normalizeUsername('x' * 25), isNull);
      // A dot may sit inside a name but never open or close it — and a doubled
      // dot is still inside.
      expect(TiktokLink.normalizeUsername('.ab'), isNull);
      expect(TiktokLink.normalizeUsername('ab.'), isNull);
      expect(TiktokLink.normalizeUsername('a..b'), 'a..b');
      expect(TiktokLink.normalizeUsername('a-b'), isNull);
      expect(TiktokLink.normalizeUsername('a b'), isNull);
      expect(TiktokLink.normalizeUsername(''), isNull);
      expect(TiktokLink.normalizeUsername('   '), isNull);
      // Digits are letters enough for a username.
      expect(TiktokLink.normalizeUsername('123456789012345678901234'), '123456789012345678901234');
    });

    test('normalizeLiveRoomId wants 15 to 25 digits without a leading zero', () {
      expect(TiktokLink.normalizeLiveRoomId(' 123456789012345 '), '123456789012345');
      expect(TiktokLink.normalizeLiveRoomId('1' * 15), '1' * 15);
      expect(TiktokLink.normalizeLiveRoomId('1' * 25), '1' * 25);
      expect(TiktokLink.normalizeLiveRoomId('1' * 14), isNull);
      expect(TiktokLink.normalizeLiveRoomId('1' * 26), isNull);
      expect(TiktokLink.normalizeLiveRoomId('012345678901234'), isNull);
      expect(TiktokLink.normalizeLiveRoomId('12345678901234a'), isNull);
      expect(TiktokLink.normalizeLiveRoomId('123456789012345.0'), isNull);
      expect(TiktokLink.normalizeLiveRoomId(''), isNull);
    });
  });

  group('a link', () {
    test('the three web hosts name a room by their one at-segment', () {
      for (final host in ['tiktok.com', 'www.tiktok.com', 'm.tiktok.com']) {
        expect(TiktokLink.parse('https://$host/@user'), _user, reason: host);
        expect(TiktokLink.parse('http://$host/@user/live'), _user, reason: host);
      }
      // The user is normalized and the word live is read in any case.
      expect(TiktokLink.parse('https://WWW.TIKTOK.COM/@User'), _user);
      expect(TiktokLink.parse('https://tiktok.com/@user/LIVE'), _user);
      expect(TiktokLink.parse('https://tiktok.com/@user/'), _user);
      // A percent-encoded at-sign is decoded before the name is read.
      expect(TiktokLink.parse('https://tiktok.com/@%75ser'), _user);
    });

    test('anything beside the live word is not a room', () {
      expect(TiktokLink.parse('https://tiktok.com/@user/video/1234'), isNull);
      expect(TiktokLink.parse('https://tiktok.com/@user/profile'), isNull);
      // Three segments match neither shape.
      expect(TiktokLink.parse('https://tiktok.com/@user/live/extra'), isNull);
      expect(TiktokLink.parse('https://tiktok.com/@user/live/'), _user);
      expect(TiktokLink.parse('https://tiktok.com/@'), isNull);
      expect(TiktokLink.parse('https://tiktok.com/@a.b'), _names(TiktokLinkKind.username, 'a.b'));
      expect(TiktokLink.parse('https://tiktok.com/@a-b'), isNull);
      expect(TiktokLink.parse('https://tiktok.com/user'), isNull);
      expect(TiktokLink.parse('https://tiktok.com/'), isNull);
    });

    test('the share path names a LIVE room and only with a whole id', () {
      expect(TiktokLink.parse('https://tiktok.com/share/live/123456789012345'), _room);
      expect(TiktokLink.parse('https://www.tiktok.com/SHARE/LIVE/123456789012345'), _room);
      expect(TiktokLink.parse('https://m.tiktok.com/share/live/123456789012345/'), _room);
      expect(TiktokLink.parse('https://tiktok.com/share/live/1234'), isNull);
      expect(TiktokLink.parse('https://tiktok.com/share/live/'), isNull);
      expect(TiktokLink.parse('https://tiktok.com/share/123456789012345'), isNull);
      // A name-shaped id on this path is read as a room id, and fails as one.
      expect(TiktokLink.parse('https://tiktok.com/share/live/user'), isNull);
    });

    test('the text that is no link at all', () {
      expect(TiktokLink.parse('https://vm.tiktok.com/abc123'), isNull);
      expect(TiktokLink.parse('https://vt.tiktok.com/@user'), isNull);
      expect(TiktokLink.parse('https://tiktok.com.evil.test/@user'), isNull);
      expect(TiktokLink.parse('https://evil.test/@user'), isNull);
      expect(TiktokLink.parse('tiktok.com/@user'), isNull);
      expect(TiktokLink.parse('ftp://tiktok.com/@user'), isNull);
      expect(TiktokLink.parse(''), isNull);
      expect(TiktokLink.parse('  https://tiktok.com/@user  '), _user);
    });

    test('user info, a fragment and a dot segment refuse the whole link', () {
      expect(TiktokLink.parse('https://me@tiktok.com/@user'), isNull);
      expect(TiktokLink.parse('https://:@tiktok.com/@user'), isNull);
      expect(TiktokLink.parse('https://tiktok.com/@user#share'), isNull);
      // A query is nobody's business.
      expect(TiktokLink.parse('https://tiktok.com/@user?x=1'), _user);
      // The parser removes dot segments — written or escaped — before this
      // reader looks, so its own `.`/`..` guard is out of reach: what is left
      // decides. Up one from the room is the bare site, which names nothing.
      expect(TiktokLink.parse('https://tiktok.com/./@user'), _user);
      expect(TiktokLink.parse('https://tiktok.com/../@user'), _user);
      expect(TiktokLink.parse('https://tiktok.com/%2E%2E/@user'), _user);
      expect(TiktokLink.parse('https://tiktok.com/@user/..'), isNull);
      expect(TiktokLink.parse('https://tiktok.com/@user/%2E%2E'), isNull);
      expect(TiktokLink.parse('https://tiktok.com/share/live/123456789012345?x=1'), _room);
    });
  });

  group('a search keyword', () {
    test('a link answers as the link would', () {
      expect(TiktokLink.lookup('https://tiktok.com/@user/live'), _user);
      expect(TiktokLink.lookup('https://www.tiktok.com/share/live/123456789012345'), _room);
    });

    test('otherwise the keyword is a username, with or without the at-sign', () {
      expect(TiktokLink.lookup('user'), _user);
      expect(TiktokLink.lookup('@user'), _user);
      expect(TiktokLink.lookup('  @User  '), _user);
      expect(TiktokLink.lookup('123456789012345'), _names(TiktokLinkKind.username, '123456789012345'));
      // What cannot be a name is nothing at all.
      expect(TiktokLink.lookup('@'), isNull);
      expect(TiktokLink.lookup('a.b.'), isNull);
      expect(TiktokLink.lookup('@user/video'), isNull);
      expect(TiktokLink.lookup('share/live/123456789012345'), isNull);
      expect(TiktokLink.lookup(''), isNull);
      expect(TiktokLink.lookup('   '), isNull);
      expect(TiktokLink.lookup('x' * 25), isNull);
    });
  });

  group('the share short link', () {
    test('the two short hosts carry any code', () {
      expect(TiktokLink.shortLink('https://vm.tiktok.com/abc123')?.path, '/abc123');
      expect(TiktokLink.shortLink('https://vt.tiktok.com/abc123')?.path, '/abc123');
      expect(TiktokLink.shortLink('http://vm.tiktok.com/abc123')?.scheme, 'http');
      // The parser writes the host lower case, whatever the page asked with.
      expect(TiktokLink.shortLink('https://VM.TIKTOK.COM/abc123')?.host, 'vm.tiktok.com');
      // A fragment is left for the redirect to lose, unlike a room link.
      expect(TiktokLink.shortLink('https://vm.tiktok.com/abc123#f')?.fragment, 'f');
      expect(TiktokLink.shortLink('https://vm.tiktok.com/abc123?x=1')?.query, 'x=1');
      // Nothing to follow the host is no code, so no short link.
      expect(TiktokLink.shortLink('https://vm.tiktok.com'), isNull);
      expect(TiktokLink.shortLink('https://vm.tiktok.com/'), isNull);
    });

    test('the web hosts only in the newer t form', () {
      expect(TiktokLink.shortLink('https://www.tiktok.com/t/abc123')?.path, '/t/abc123');
      expect(TiktokLink.shortLink('https://tiktok.com/t/abc123')?.path, '/t/abc123');
      expect(TiktokLink.shortLink('https://m.tiktok.com/t/abc123')?.path, '/t/abc123');
      // The `t` is read as written, and only one segment follows it.
      expect(TiktokLink.shortLink('https://www.tiktok.com/T/abc123'), isNull);
      expect(TiktokLink.shortLink('https://www.tiktok.com/t/abc123/extra'), isNull);
      expect(TiktokLink.shortLink('https://www.tiktok.com/t'), isNull);
      expect(TiktokLink.shortLink('https://www.tiktok.com/@user'), isNull);
      expect(TiktokLink.shortLink('https://www.tiktok.com/'), isNull);
      expect(TiktokLink.shortLink('https://evil.test/t/abc123'), isNull);
      expect(TiktokLink.shortLink('https://me@vm.tiktok.com/abc123'), isNull);
      expect(TiktokLink.shortLink('ftp://vm.tiktok.com/abc123'), isNull);
      expect(TiktokLink.shortLink('vm.tiktok.com/abc123'), isNull);
      expect(TiktokLink.shortLink(''), isNull);
    });
  });

  group('whose host, and which value', () {
    test('ownsHost takes anything under tiktok.com, as written', () {
      for (final host in ['tiktok.com', 'www.tiktok.com', 'm.tiktok.com', 'vm.tiktok.com', 'vt.tiktok.com']) {
        expect(TiktokLink.ownsHost(host), isTrue, reason: host);
      }
      // A subdomain of the site is TikTok's even when no link shape lives there.
      expect(TiktokLink.ownsHost('anything.tiktok.com'), isTrue);
      expect(TiktokLink.ownsHost('tiktok.com.evil.test'), isFalse);
      expect(TiktokLink.ownsHost('evil.test'), isFalse);
      expect(TiktokLink.ownsHost(''), isFalse);
      // This reader is the one that never lower-cases.
      expect(TiktokLink.ownsHost('WWW.TIKTOK.COM'), isFalse);
      expect(TiktokLink.ownsHost('.tiktok.com'), isTrue);
    });

    test('the value names what it read, and has no equality of its own', () {
      const first = TiktokLink(TiktokLinkKind.username, 'user');
      const second = TiktokLink(TiktokLinkKind.username, 'user');
      expect(identical(first, second), isTrue);
      // A runtime instance of the same link is another value: the class has no
      // `==` override, so only the two fields answer a comparison.
      final fresh = TiktokLink.parse('https://tiktok.com/@user')!;
      expect(fresh, isNot(first));
      expect(fresh, _user);
      expect(const TiktokLink(TiktokLinkKind.liveRoom, '123456789012345'), _room);
      expect('$fresh', isNot(contains('user')));
    });
  });
}
