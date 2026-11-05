import 'package:live_net/live_net.dart';
import 'package:live_sites/src/platforms/bilibili/api/bilibili_endpoints.dart';
import 'package:live_sites/src/platforms/bilibili/api/bilibili_http.dart';
import 'package:live_sites/src/platforms/bilibili/bilibili_site.dart';
import 'package:live_sites/src/platforms/bilibili/capabilities/bilibili_play_lease_lookup.dart';
import 'package:live_sites/src/platforms/bilibili/parsers/bilibili_play_parser.dart';
import 'package:test/test.dart';

/// The transport these cases never mean to use; a call is a test failure.
final class _NoHttp implements LiveHttp {
  final List<Uri> asked = [];

  @override
  Future<LiveResponse> send(LiveRequest request) async {
    asked.add(request.url);
    throw StateError('bilibili identity asked for ${request.url}');
  }

  @override
  Future<LiveStreamedResponse> open(LiveRequest request) => throw UnimplementedError();

  @override
  void close() {}
}

/// A site that is a guest, or one that carries [cookie] as its login.
BilibiliSite _site({String? cookie, int storedUid = 0, DateTime Function()? now}) {
  final login = cookie ?? '';
  return BilibiliSite(
    http: BilibiliHttp(_NoHttp()),
    loginCookie: () => login,
    storedUid: () => storedUid,
    now: now,
    sleep: (_) async {},
  );
}

/// An address on the live host.
String _live(String rest) => 'https://live.bilibili.com/$rest';

Uri _play(String query) => Uri.parse('https://d1.example.com/live.flv?$query');

void main() {
  group('which room an address names', () {
    test('a room number is one to eighteen digits and never zero', () {
      expect(BilibiliSite.roomNumber('23058'), '23058');
      expect(BilibiliSite.roomNumber('007'), '7', reason: 'leading zeroes are stripped by the number itself');
      expect(BilibiliSite.roomNumber('0'), isNull);
      expect(BilibiliSite.roomNumber('00'), isNull);
      expect(BilibiliSite.roomNumber('9' * 18), '9' * 18);
      expect(BilibiliSite.roomNumber('9' * 19), isNull, reason: 'an id the platform cannot hold is not an id');
      for (final text in ['', ' ', '1 2', 'a1', '1a', '-1', '1.5', '１２']) {
        expect(BilibiliSite.roomNumber(text), isNull, reason: '"$text" is not a room number');
      }
    });

    test('the live host names a room, its h5 and blanc forms after the prefix', () {
      expect(BilibiliSite.roomIdFromUrl(_live('23058')), '23058');
      expect(BilibiliSite.roomIdFromUrl(_live('23058?spm_id_from=333.1007')), '23058');
      expect(BilibiliSite.roomIdFromUrl(_live('23058/')), '23058', reason: 'a trailing slash is no segment');
      expect(BilibiliSite.roomIdFromUrl(_live('h5/23058')), '23058');
      expect(BilibiliSite.roomIdFromUrl(_live('blanc/23058')), '23058');
      expect(BilibiliSite.roomIdFromUrl(_live('blanc/23058/topic_s?x=1')), '23058');
      expect(BilibiliSite.roomIdFromUrl('https://www.bilibili.com/23058'), '23058', reason: 'the old alias');
      expect(BilibiliSite.roomIdFromUrl('https://bilibili.com/23058'), '23058');
      expect(
        BilibiliSite.roomIdFromUrl('https://live.bilibili.com/23058?roomType=1#/x'),
        '23058',
        reason: 'a query and a fragment are not part of the path',
      );
      expect(
        BilibiliSite.roomIdFromUrl('https://live.bilibili.com/23058/34567'),
        '23058',
        reason: 'the first path segment is the room, whatever follows it',
      );
    });

    test('an address that is not a room names none', () {
      for (final url in [
        'https://live.bilibili.com/',
        'https://live.bilibili.com',
        'https://live.bilibili.com/not-a-number',
        'https://live.bilibili.com/h5/0',
        'https://live.bilibili.com/h5',
        'https://space.bilibili.com/12345',
        'https://m.live.bilibili.com/23058',
        'https://www.bilibili.com/video/BV1xx',
        'not a url at all',
        'https://[bad/',
      ]) {
        expect(BilibiliSite.roomIdFromUrl(url), isNull, reason: '$url is not one room');
      }
    });

    test('a short link has to be followed first', () {
      expect(BilibiliSite.isShortLink('https://b23.tv/abc123'), isTrue);
      expect(BilibiliSite.isShortLink('https://www.b23.tv/abc'), isTrue);
      expect(BilibiliSite.isShortLink('https://B23.TV/abc'), isTrue, reason: 'hosts are matched case-insensitively');
      expect(BilibiliSite.isShortLink('https://b23.tvx/abc'), isFalse);
      expect(BilibiliSite.isShortLink(_live('23058')), isFalse);
      expect(BilibiliSite.isShortLink(''), isFalse);
    });
  });

  group('the cookie the requests go out with', () {
    test('a cookie field is read by its name, not by its ending', () {
      const cookie = 'buvid3=ABC; SESSDATA= x ;DedeUserID=99;buvid4=DEF';
      expect(BilibiliSite.cookieField(cookie, 'buvid3'), 'ABC');
      expect(BilibiliSite.cookieField(cookie, 'buvid4'), 'DEF');
      expect(BilibiliSite.cookieField(cookie, 'DedeUserID'), '99');
      expect(BilibiliSite.cookieField(cookie, 'SESSDATA'), 'x', reason: 'the value is trimmed');
      expect(BilibiliSite.cookieField(cookie, 'sessdata'), isNull, reason: 'the name is matched as written');
      expect(BilibiliSite.cookieField(cookie, 'uvid3'), isNull, reason: 'a name inside a name is not the name');
      expect(BilibiliSite.cookieField('buvid3=;x=1', 'buvid3'), isNull, reason: 'an empty field is no field');
      expect(BilibiliSite.cookieField('', 'buvid3'), isNull);
      expect(BilibiliSite.cookieField('  ', 'buvid3'), isNull);
    });

    test('a known cookie needs no request, and a guest has none', () async {
      expect(_site().knownCookie(), isEmpty);
      expect(_site(cookie: 'buvid3=ABC').knownCookie(), 'buvid3=ABC');
      expect(_NoHttp().asked, isEmpty, reason: 'the media headers ask for the cookie they already have');
    });
  });

  group('the canonical long id of a room', () {
    test('an id answers itself until a detail says otherwise', () {
      final site = _site();
      expect(site.longId('123'), '123');
      expect(site.longId(' 123 '), '123', reason: 'the id is trimmed before it is looked up');
      site.rememberLongId('123', '45678901234567890');
      expect(site.longId('123'), '45678901234567890');
      expect(site.longId('124'), '124', reason: 'another room is not affected');
    });

    test('the memory is bounded, oldest first', () {
      final site = _site();
      for (var id = 0; id < 513; id++) {
        site.rememberLongId('$id', 'long-$id');
      }
      expect(site.longId('0'), '0', reason: 'the first entry made room for the last');
      expect(site.longId('1'), 'long-1');
      expect(site.longId('512'), 'long-512');
      // Re-remembering an id moves it to the end instead of aging out twice.
      site.rememberLongId('1', 'again');
      for (var id = 513; id < 1024; id++) {
        site.rememberLongId('$id', 'long-$id');
      }
      expect(site.longId('1'), 'again');
      expect(site.longId('2'), '2', reason: 'the entry that was never touched again aged out');
    });

    test('a room whose discovery failed gets the gateway and no token, without asking', () async {
      final http = _NoHttp();
      final site = BilibiliSite(
        http: BilibiliHttp(http),
        loginCookie: () => 'buvid3=B3; buvid4=B4; DedeUserID=99',
        sleep: (_) async {},
      );
      final args = await site.emptyDanmakuArgs(' 23058 ');
      expect(args.longId, '23058');
      expect(args.token, isEmpty, reason: 'the session reports this as content-unavailable, not as a join');
      expect(args.servers, [Uri.parse(BilibiliEndpoints.danmakuGateway)]);
      expect(args.uid, 99);
      expect(args.buvid, 'B3');
      expect(args.headers['cookie'], contains('buvid3=B3'));
      expect(http.asked, isEmpty, reason: 'the login cookie already carries its own buvid');
    });
  });

  group('the lease a signed address carries', () {
    final lookup = BilibiliPlayLeaseLookup(now: () => DateTime.fromMillisecondsSinceEpoch(1_790_000_000_000));

    test('an unsigned address has no lease', () {
      expect(lookup.leaseOf(_play('other=1')), isNull);
      expect(lookup.leaseOf(_play('expires=')), isNull);
      expect(lookup.leaseOf(_play('expires=0')), isNull, reason: 'zero is not an expiry');
      expect(lookup.leaseOf(_play('expires=soon')), isNull);
      final twice = lookup.leaseOf(_play('expires=1790000900&expires=1'))!;
      expect(
        twice.expiresAt,
        DateTime.fromMillisecondsSinceEpoch(1790000900000, isUtc: true),
        reason: 'a query that names expires twice is read at its first pair',
      );
    });

    test('the refresh is a quarter before the end, never more than the lead', () {
      final long = lookup.leaseOf(_play('expires=1790003900'))!;
      expect(long.expiresAt, DateTime.fromMillisecondsSinceEpoch(1790003900000, isUtc: true));
      expect(long.refreshAt, long.expiresAt!.subtract(BilibiliPlayParser.leaseLead));

      final short = lookup.leaseOf(_play('expires=1790000030'))!;
      expect(
        short.refreshAt,
        DateTime.fromMillisecondsSinceEpoch(1790000022500, isUtc: true),
        reason: 'a lifetime of a quarter shorter than the lead renews at the quarter',
      );
      expect(short.expiresAt!.difference(short.refreshAt), const Duration(milliseconds: 7500));
    });

    test('an address past its expiry reads as dead, not as immortal', () {
      final past = lookup.leaseOf(_play('expires=1789999000'))!;
      expect(past.expiresAt, DateTime.fromMillisecondsSinceEpoch(1789999000000, isUtc: true));
      expect(past.expiresAt!.isBefore(past.refreshAt), isFalse, reason: 'a dead address keeps the expiry it names');
      expect(past.refreshAt, past.expiresAt!.subtract(BilibiliPlayParser.leaseLead));
    });
  });
}
