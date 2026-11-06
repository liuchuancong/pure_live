import 'package:live_sites/src/platforms/liveme/parsers/liveme_link.dart';
import 'package:test/test.dart';

const String _uid = '1234567890123';
const String _vid = '123456789012345678901234';
const String _short = '12345';

void main() {
  group('the host and the port', () {
    test('the two hosts, in any case and on any port', () {
      expect(LivemeLink.parse('https://liveme.com/u/$_uid')?.kind, LivemeLinkKind.userId);
      expect(LivemeLink.parse('http://www.liveme.com/u/$_uid')?.id, _uid);
      expect(LivemeLink.parse('https://LIVEME.COM/u/$_uid')?.kind, LivemeLinkKind.userId);
      expect(LivemeLink.parse('https://WWW.liveme.com/livehot/streaming/$_short')?.kind, LivemeLinkKind.shortId);
      // No port gate at all: any port is the site's own.
      expect(LivemeLink.parse('https://liveme.com:8443/u/$_uid')?.id, _uid);
      expect(LivemeLink.parse('http://www.liveme.com:80/v/$_vid')?.kind, LivemeLinkKind.videoId);
    });

    test('what is not the site', () {
      expect(LivemeLink.parse('https://m.liveme.com/u/$_uid'), isNull);
      expect(LivemeLink.parse('https://liveme.com.evil.test/u/$_uid'), isNull);
      expect(LivemeLink.parse('https://evil.test/u/$_uid'), isNull);
      expect(LivemeLink.parse('liveme.com/u/$_uid'), isNull);
      expect(LivemeLink.parse('ftp://liveme.com/u/$_uid'), isNull);
      expect(LivemeLink.parse('https://me@liveme.com/u/$_uid'), isNull);
      expect(LivemeLink.parse(''), isNull);
      expect(LivemeLink.parse('  https://liveme.com/u/$_uid  '), isNotNull);
    });
  });

  group('the four shapes', () {
    test('a room is livehot/streaming with a short id', () {
      expect(
        LivemeLink.parse('https://liveme.com/livehot/streaming/$_short'),
        const LivemeLink(LivemeLinkKind.shortId, _short),
      );
      expect(
        LivemeLink.parse('https://liveme.com/LiveHot/Streaming/123456789012'),
        const LivemeLink(LivemeLinkKind.shortId, '123456789012'),
      );
      // Five to twelve digits, no leading zero, and nothing else.
      expect(LivemeLink.parse('https://liveme.com/livehot/streaming/1234'), isNull);
      expect(LivemeLink.parse('https://liveme.com/livehot/streaming/1234567890123'), isNull);
      expect(LivemeLink.parse('https://liveme.com/livehot/streaming/012345'), isNull);
      expect(LivemeLink.parse('https://liveme.com/livehot/streaming/user'), isNull);
      expect(LivemeLink.parse('https://liveme.com/livehot/streaming/'), isNull);
      expect(LivemeLink.parse('https://liveme.com/livehot/streaming/$_short/extra'), isNull);
    });

    test('an anchor is u with a thirteen to twenty-four digit id', () {
      expect(LivemeLink.parse('https://liveme.com/u/$_uid'), const LivemeLink(LivemeLinkKind.userId, _uid));
      expect(LivemeLink.parse('https://www.liveme.com/U/$_vid'), const LivemeLink(LivemeLinkKind.userId, _vid));
      expect(LivemeLink.parse('https://liveme.com/u/12345'), isNull);
      expect(LivemeLink.parse('https://liveme.com/u/$_uid/extra'), isNull);
      expect(LivemeLink.parse('https://liveme.com/u/'), isNull);
    });

    test('a broadcast is v, or the share page with its exact tail', () {
      expect(LivemeLink.parse('https://liveme.com/v/$_vid'), const LivemeLink(LivemeLinkKind.videoId, _vid));
      expect(
        LivemeLink.parse('https://liveme.com/m/v/$_vid/index.html'),
        const LivemeLink(LivemeLinkKind.videoId, _vid),
      );
      expect(LivemeLink.parse('https://liveme.com/M/V/$_vid/INDEX.HTML')?.kind, LivemeLinkKind.videoId);
      // The last word is part of the shape.
      expect(LivemeLink.parse('https://liveme.com/m/v/$_vid/index.htm'), isNull);
      expect(LivemeLink.parse('https://liveme.com/m/v/$_vid'), isNull);
      expect(LivemeLink.parse('https://liveme.com/m/v/$_vid/index.html/'), isNotNull);
      expect(LivemeLink.parse('https://liveme.com/m/$_vid/index.html'), isNull);
      expect(LivemeLink.parse('https://liveme.com/v/12345'), isNull);
    });

    test('the id is read from the decoded segment, spaces and all', () {
      expect(LivemeLink.parse('https://liveme.com/u/%20$_uid%20')?.id, _uid);
      expect(LivemeLink.parse('https://liveme.com/livehot/streaming/%20$_short%20')?.kind, LivemeLinkKind.shortId);
      // Query and fragment are nobody's business.
      expect(LivemeLink.parse('https://liveme.com/u/$_uid?x=1#share')?.id, _uid);
    });
  });

  group('the locale segment', () {
    test('a two-letter opening segment is eaten before the shape is read', () {
      expect(LivemeLink.parse('https://liveme.com/us/u/$_uid')?.kind, LivemeLinkKind.userId);
      expect(LivemeLink.parse('https://liveme.com/zh-tw/v/$_vid')?.id, _vid);
      expect(LivemeLink.parse('https://liveme.com/ZH-TW/livehot/streaming/$_short')?.kind, LivemeLinkKind.shortId);
      // The test is a shape, not a list: any two letters pass for a locale.
      expect(LivemeLink.parse('https://liveme.com/ab/u/$_uid')?.id, _uid);
      expect(LivemeLink.parse('https://liveme.com/zh-twp/v/$_vid')?.kind, LivemeLinkKind.videoId);
      // A longer, or shorter, opening word is not a locale, and the shape
      // then reads the first segment itself.
      expect(LivemeLink.parse('https://liveme.com/zh-tw-x/u/$_uid'), isNull);
      expect(LivemeLink.parse('https://liveme.com/u/v/$_vid'), isNull);
      expect(LivemeLink.parse('https://liveme.com/us'), isNull);
      expect(LivemeLink.parse('https://liveme.com/us/'), isNull);
    });

    test('an empty path or a dot leading it names nothing', () {
      expect(LivemeLink.parse('https://liveme.com/'), isNull);
      expect(LivemeLink.parse('https://liveme.com'), isNull);
      // The parser resolves dot segments on its own, so `/./u/…` arrives as
      // `/u/…`; up one from a shape is the bare site, which names nothing.
      expect(LivemeLink.parse('https://liveme.com/./u/$_uid')?.id, _uid);
      expect(LivemeLink.parse('https://liveme.com/u/$_uid/..'), isNull);
    });
  });

  group('the search form and the value', () {
    test('parseOrShortId takes a link first and a bare room id second', () {
      expect(LivemeLink.parseOrShortId('https://liveme.com/u/$_uid')?.kind, LivemeLinkKind.userId);
      expect(LivemeLink.parseOrShortId('https://liveme.com/v/$_vid')?.id, _vid);
      expect(LivemeLink.parseOrShortId(_short), const LivemeLink(LivemeLinkKind.shortId, _short));
      expect(LivemeLink.parseOrShortId(' $_short '), const LivemeLink(LivemeLinkKind.shortId, _short));
      expect(LivemeLink.parseOrShortId('99999'), isNotNull);
      // A bare anchor id is not searched as one: only a short id answers.
      expect(LivemeLink.parseOrShortId(_uid), isNull);
      expect(LivemeLink.parseOrShortId(_vid), isNull);
      expect(LivemeLink.parseOrShortId('012345'), isNull);
      expect(LivemeLink.parseOrShortId('user'), isNull);
      expect(LivemeLink.parseOrShortId(''), isNull);
    });

    test('the value compares by kind and id and says both', () {
      expect(LivemeLink.parse('https://liveme.com/livehot/streaming/$_short'), LivemeLink.parseOrShortId(_short));
      expect(
        const LivemeLink(LivemeLinkKind.userId, _uid).hashCode,
        LivemeLink.parse('https://liveme.com/u/$_uid')?.hashCode,
      );
      expect(const LivemeLink(LivemeLinkKind.videoId, _uid), isNot(const LivemeLink(LivemeLinkKind.userId, _uid)));
      expect(
        const LivemeLink(LivemeLinkKind.shortId, '99999'),
        isNot(const LivemeLink(LivemeLinkKind.shortId, _short)),
      );
      expect(const LivemeLink(LivemeLinkKind.shortId, _short).toString(), 'LivemeLink(shortId, $_short)');
      expect(const LivemeLink(LivemeLinkKind.userId, _uid).toString(), 'LivemeLink(userId, $_uid)');
    });
  });
}
