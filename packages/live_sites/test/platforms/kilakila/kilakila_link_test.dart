import 'dart:convert';

import 'package:crypto/crypto.dart' as crypto;
import 'package:live_sites/src/common/crypto/aes_cbc.dart';
import 'package:live_sites/src/platforms/kilakila/parsers/kilakila_link.dart';
import 'package:test/test.dart';

/// The website's published share codec (`uxin-security-url-crypto-v2.min.js`):
/// the two read keys, the one IV and the prefix of the signed base. They are
/// public constants of the page, not credentials; the tests re-seal with them
/// to pin what the parser refuses.
const String _key0 = '7cdyGRc6Sa93ilPt';
const String _key1 = 'c98be79a4347bc97';
const String _iv = '93x0ue23c2c9h8km';
const String _prefix = r'pR@Wv%Wju@Pl&bKc$GyUrPeO';

const String _room = 'https://live.kilakila.cn';
const String _site = 'http://www.hongdoufm.com';
const String _owner = 'https://live.hongrenshuo.com.cn';
const String _detail = '/PcLive/index/detail';
const String _uid = '501';
const String _id = '7001';

const KilakilaLink _broadcast = KilakilaLink(KilakilaLinkKind.broadcast, _id);
const KilakilaLink _anchor = KilakilaLink(KilakilaLinkKind.owner, _uid);

String _md5(String value) => crypto.md5.convert(utf8.encode(value)).toString();

/// `<k>=<v>` joined by `&` in key order — the text a seal signs.
String _canonical(Map<String, String> params) =>
    (params.keys.toList()..sort()).map((key) => '$key=${params[key]}').join('&');

/// AES-128-CBC with PKCS#7 over [plain], as URL-safe base64.
String _seal(String plain, {String key = _key0}) =>
    base64Url.encode(AesCbc.encrypt(utf8.encode(plain), key: utf8.encode(key), iv: utf8.encode(_iv)));

/// A path seal: the plaintext is `<id>?<pairs>` with URL-encoded values (the
/// site's URLSearchParams) while the signature covers the decoded ones, over
/// the base `origin + route + id` — with the id alone after the `?` when the
/// payload carries nothing else.
String _pathSeal(
  String origin,
  String route,
  String id, {
  Map<String, String> extra = const {},
  String key = _key0,
  String? sign,
}) {
  final signature =
      sign ?? _md5(extra.isEmpty ? '$_prefix$origin$route$id' : '$_prefix$origin$route$id?${_canonical(extra)}');
  final pairs = {
    for (final entry in extra.entries) Uri.encodeQueryComponent(entry.key): Uri.encodeQueryComponent(entry.value),
    'sign': signature,
  };
  return _seal('$id?${_canonical(pairs)}', key: key);
}

/// The detail page's seal: raw `k=v` pairs (nothing URL-encoded), the sign over
/// every pair but itself, with the route as written in the base.
String _detailSeal(String origin, {required Map<String, String> params, String route = _detail, String key = _key0}) {
  final others = Map<String, String>.of(params)..remove('sign');
  final signature = _md5('$_prefix$origin$route?${_canonical(others)}');
  return _seal(_canonical({...params, 'sign': signature}), key: key);
}

void main() {
  group('an id written in the open', () {
    test('a broadcast path on either website host, over http or https', () {
      expect(KilakilaLink.parse('$_room/room/$_id'), _broadcast);
      expect(KilakilaLink.parse('$_site/room/$_id'), _broadcast);
      expect(KilakilaLink.parse('http://live.kilakila.cn/room/$_id'), _broadcast);
      expect(KilakilaLink.parse('https://www.hongdoufm.com/room/$_id'), _broadcast);
    });

    test('the explicit default port stands, any other port does not', () {
      expect(KilakilaLink.parse('https://live.kilakila.cn:443/room/$_id'), _broadcast);
      expect(KilakilaLink.parse('http://live.kilakila.cn:80/room/$_id'), _broadcast);
      expect(KilakilaLink.parse('https://live.kilakila.cn:8443/room/$_id'), isNull);
    });

    test('the detail page names a broadcast by its id parameter', () {
      expect(KilakilaLink.parse('$_room$_detail?id=$_id'), _broadcast);
      expect(KilakilaLink.parse('$_site$_detail?id=$_id'), _broadcast);
      expect(KilakilaLink.parse('$_room$_detail/?id=$_id'), _broadcast);
      // An unrelated parameter does not hurt; another name for the id does.
      expect(KilakilaLink.parse('$_room$_detail?id=$_id&from=share'), _broadcast);
      expect(KilakilaLink.parse('$_room$_detail?uid=$_id'), isNull);
      expect(KilakilaLink.parse('$_room$_detail'), isNull);
      expect(KilakilaLink.parse('$_room$_detail?id='), isNull);
    });

    test('an anchor page: /zhubo/ wants a bare route, the uid route does not', () {
      expect(KilakilaLink.parse('$_room/zhubo/$_uid'), _anchor);
      expect(KilakilaLink.parse('$_site/zhubo/$_uid'), _anchor);
      expect(KilakilaLink.parse('$_room/zhubo/$_uid?from=1'), isNull);
      expect(KilakilaLink.parse('$_owner/index/roomuser/uid/$_uid'), _anchor);
      expect(KilakilaLink.parse('$_owner/index/roomuser/uid/$_uid?from=1'), _anchor);
      // The anchor host serves https only, and its one route is the uid one.
      expect(KilakilaLink.parse('http://live.hongrenshuo.com.cn/index/roomuser/uid/$_uid'), isNull);
      expect(KilakilaLink.parse('$_owner/zhubo/$_uid'), isNull);
      expect(KilakilaLink.parse('$_owner/room/$_id'), isNull);
      expect(KilakilaLink.parse('$_room/index/roomuser/uid/$_uid'), isNull);
    });

    test('an id is 1 to 32 digits without a leading zero', () {
      expect(KilakilaLink.parse('$_room/room/$_uid'), const KilakilaLink(KilakilaLinkKind.broadcast, _uid));
      expect(KilakilaLink.parse('$_room/room/0$_uid'), isNull);
      expect(KilakilaLink.parse('$_room/room/12345678901234567890123456789012'), isNotNull);
      expect(KilakilaLink.parse('$_room/room/123456789012345678901234567890123'), isNull);
      expect(KilakilaLink.parse('$_room/room/7001a'), isNull);
      expect(KilakilaLink.parse('$_room/room/'), isNull);
    });

    test('the routes, hosts and shapes that are no link', () {
      expect(KilakilaLink.parse('https://live.kilakila.cn/'), isNull);
      expect(KilakilaLink.parse('https://evil.test/room/$_id'), isNull);
      expect(KilakilaLink.parse('https://live.kilakila.cn.evil.test/room/$_id'), isNull);
      expect(KilakilaLink.parse('live.kilakila.cn/room/$_id'), isNull);
      expect(KilakilaLink.parse('ftp://live.kilakila.cn/room/$_id'), isNull);
      expect(KilakilaLink.parse('$_room/aboutus/serach/kw/hello'), isNull);
      expect(KilakilaLink.parse('$_room/rooms/$_id'), isNull);
      expect(KilakilaLink.parse('$_room/room/70/1'), isNull);
      // A path id carries no query of its own.
      expect(KilakilaLink.parse('$_room/room/$_id?id=$_id'), isNull);
      expect(KilakilaLink.parse('$_room/room/$_id?uid=$_uid'), isNull);
      expect(KilakilaLink.parse('$_room/room/$_id?_specific_parameter=x'), isNull);
      // Only one URL, never a share text.
      expect(KilakilaLink.parse('$_room/room/$_id 看看这个'), isNull);
      expect(KilakilaLink.parse('$_room/room/70 01'), isNull);
    });

    test('the text itself: length, escapes, fragment, user info and repeats', () {
      expect(KilakilaLink.parse('  $_room/room/$_id  '), _broadcast);
      expect(KilakilaLink.parse('$_room/room/$_id?x=${'y' * 8200}'), isNull);
      expect(KilakilaLink.parse('$_room/room/%zz'), isNull);
      expect(KilakilaLink.parse('$_room/room/70%01'), isNull);
      expect(KilakilaLink.parse('$_room/room/$_id\n'), _broadcast);
      expect(KilakilaLink.parse('$_room/room/70\n01'), isNull);
      expect(KilakilaLink.parse('$_room/room/$_id#top'), isNull);
      expect(KilakilaLink.parse('https://me@live.kilakila.cn/room/$_id'), isNull);
      expect(KilakilaLink.parse('$_room$_detail?id=$_id&id=$_id'), isNull);
    });
  });

  group('a sealed id', () {
    test('a path seal opens the broadcast under either published key', () {
      final sealed = _pathSeal(_room, '/room/', _id);
      expect(KilakilaLink.parse('$_room/room/$sealed'), _broadcast);
      expect(KilakilaLink.parse('$_site/room/${_pathSeal(_site, '/room/', _id)}'), _broadcast);
      expect(KilakilaLink.parse('$_room/room/${_pathSeal(_room, '/room/', _id, key: _key1)}'), _broadcast);
      // The payload is cut from the route as written, so an encoded seal reads
      // the same as an open one.
      expect(KilakilaLink.parse('$_room/room/${Uri.encodeComponent(sealed)}'), _broadcast);
    });

    test('a path seal opens an anchor route, with the origin in the signature', () {
      final sealed = _pathSeal(_room, '/room/', _id);
      expect(KilakilaLink.parse('$_room/zhubo/${_pathSeal(_room, '/zhubo/', _uid)}'), _anchor);
      final uidSeal = _pathSeal(_owner, '/index/roomuser/uid/', _uid);
      expect(KilakilaLink.parse('$_owner/index/roomuser/uid/$uidSeal'), _anchor);
      // The same seal asked of another host or scheme does not open; a written
      // default port is not part of the origin, so it changes nothing.
      expect(KilakilaLink.parse('$_site/room/$sealed'), isNull);
      expect(KilakilaLink.parse('http://live.kilakila.cn/room/$sealed'), isNull);
      expect(KilakilaLink.parse('https://live.kilakila.cn:443/room/$sealed'), _broadcast);
      expect(KilakilaLink.parse('$_owner/index/roomuser/uid/$sealed'), isNull);
    });

    test('a path seal with parameters signs the id in the base and the rest sorted', () {
      final extra = {'b': '2', 'a': '1'};
      expect(KilakilaLink.parse('$_room/room/${_pathSeal(_room, '/room/', _id, extra: extra)}'), _broadcast);
      // The pairs are signed in key order, so their written order is not it.
      final unsorted = _md5('$_prefix$_room/room/$_id?b=2&a=1');
      expect(
        KilakilaLink.parse('$_room/room/${_pathSeal(_room, '/room/', _id, extra: extra, sign: unsorted)}'),
        isNull,
      );
      // With a parameter the id belongs to the base, not to the signed pairs.
      final withId = _md5('$_prefix$_room/room/?id=$_id&a=1&b=2');
      expect(KilakilaLink.parse('$_room/room/${_pathSeal(_room, '/room/', _id, extra: extra, sign: withId)}'), isNull);
    });

    test('a path seal decodes its parameter values before signing them', () {
      final extra = {'u': 'a b'};
      expect(KilakilaLink.parse('$_room/room/${_pathSeal(_room, '/room/', _id, extra: extra)}'), _broadcast);
      // Signed over the encoded text instead of the decoded value: no link.
      final encoded = _md5('$_prefix$_room/room/$_id?u=a%20b');
      expect(KilakilaLink.parse('$_room/room/${_pathSeal(_room, '/room/', _id, extra: extra, sign: encoded)}'), isNull);
    });

    test('the detail page signs raw pairs and the route as written', () {
      final seal = _detailSeal(_room, params: {'id': _id, 't': 'x'});
      expect(KilakilaLink.parse('$_room$_detail?_specific_parameter=$seal'), _broadcast);
      expect(KilakilaLink.parse('$_room$_detail?_specific_parameter=${Uri.encodeQueryComponent(seal)}'), _broadcast);
      // The trailing slash is another route, so it needs its own signature.
      final slashed = _detailSeal(_room, route: '$_detail/', params: {'id': _id});
      expect(KilakilaLink.parse('$_room$_detail/?_specific_parameter=$slashed'), _broadcast);
      expect(KilakilaLink.parse('$_room$_detail?_specific_parameter=$slashed'), isNull);
      expect(KilakilaLink.parse('$_room$_detail/?_specific_parameter=$seal'), isNull);
      // A seal beside an open id or sign is refused before it is read.
      expect(KilakilaLink.parse('$_room$_detail?_specific_parameter=$seal&id=$_id'), isNull);
      expect(KilakilaLink.parse('$_room$_detail?_specific_parameter=$seal&sign=x'), isNull);
      // The room host's seal never opens the anchor host, nor the other way.
      expect(KilakilaLink.parse('$_owner/index/roomuser/uid/$seal'), isNull);
      final anchorSeal = _detailSeal(_owner, params: {'id': _uid});
      expect(KilakilaLink.parse('$_owner/index/roomuser/uid/$anchorSeal'), isNull);
      expect(KilakilaLink.parse('$_room$_detail?_specific_parameter=$anchorSeal'), isNull);
    });

    test('a seal that does not open or does not match is no link', () {
      // Sealed under a key the website does not publish.
      expect(KilakilaLink.parse('$_room/room/${_pathSeal(_room, '/room/', _id, key: '0000000000000000')}'), isNull);
      // Right text, wrong signature.
      final wrong = _pathSeal(_room, '/room/', _id, sign: _md5('$_prefix$_room/room/9999'));
      expect(KilakilaLink.parse('$_room/room/$wrong'), isNull);
      // An uppercase or a short signature fails the shape gate, not the hash.
      final upper = _pathSeal(_room, '/room/', _id, sign: _md5('$_prefix$_room/room/$_id').toUpperCase());
      expect(KilakilaLink.parse('$_room/room/$upper'), isNull);
      final short = _pathSeal(_room, '/room/', _id, sign: 'abc');
      expect(KilakilaLink.parse('$_room/room/$short'), isNull);
      // Not whole AES blocks, not base64, or no ciphertext at all.
      expect(KilakilaLink.parse('$_room/room/${base64Url.encode(List.filled(24, 7))}'), isNull);
      expect(KilakilaLink.parse('$_room/room/${base64Url.encode(const <int>[])}'), isNull);
      expect(KilakilaLink.parse('$_room/room/not_base_64!!'), isNull);
      expect(KilakilaLink.parse('$_room/room/${_pathSeal(_room, '/room/', _id)}x'), isNull);
    });

    test('the parameter text has its own shape', () {
      final cases = {
        'two questions': '$_id?x=1?y=2',
        'a pair without =': '$_id?x=1&y',
        'a repeated key': '$_id?x=1&x=2',
        'a leading-zero id': '0$_id?x=1',
        'a newline in a value': '$_id?x=1&y=a\nb',
        'a pair with no key': '$_id?=1',
        'a key that is no name': '$_id?1x=2',
        'the sign missing': '$_id?x=1',
        'the id missing': 'x=1&sign=${'0' * 32}',
      };
      for (final entry in cases.entries) {
        expect(KilakilaLink.parse('$_room/room/${_seal(entry.value)}'), isNull, reason: entry.key);
      }
      // The detail page takes raw values: a `=` inside one is malformed.
      expect(KilakilaLink.parse('$_room$_detail?_specific_parameter=${_seal('id=$_id&s=1=2')}'), isNull);
      expect(KilakilaLink.parse('$_room$_detail?_specific_parameter=${_seal('')}'), isNull);
    });

    test('the parameter text is capped at 32 pairs and 4096 characters', () {
      Map<String, String> data(int n) => {'id': _id, for (var i = 0; i < n; i++) 'k$i': '$i'};
      // The sign is one of the 32, so 30 pairs beside id and sign still open.
      expect(
        KilakilaLink.parse('$_room$_detail?_specific_parameter=${_detailSeal(_room, params: data(30))}'),
        _broadcast,
      );
      expect(KilakilaLink.parse('$_room$_detail?_specific_parameter=${_detailSeal(_room, params: data(31))}'), isNull);
      expect(KilakilaLink.parse('$_room/room/${_seal('$_id?${'x' * 4100}=1')}'), isNull);
      // The encoded payload is capped too.
      expect(KilakilaLink.parse('$_room/room/${'A' * 4097}'), isNull);
      expect(KilakilaLink.parse('$_room/room/${'A' * 4096}'), isNull);
    });

    test('the id of a seal is checked before its signature', () {
      const zero = '0$_id';
      expect(
        KilakilaLink.parse('$_room/room/${_pathSeal(_room, '/room/', zero, sign: _md5('$_prefix$_room/room/$zero'))}'),
        isNull,
      );
      final long = '1' * 33;
      expect(
        KilakilaLink.parse('$_room/room/${_pathSeal(_room, '/room/', long, sign: _md5('$_prefix$_room/room/$long'))}'),
        isNull,
      );
    });
  });

  group('the link value', () {
    test('two parses of the same id are one link', () {
      expect(KilakilaLink.parse('$_room/room/$_id'), KilakilaLink.parse('$_site/room/$_id'));
      expect(
        KilakilaLink.parse('$_room/room/$_id')?.hashCode,
        const KilakilaLink(KilakilaLinkKind.broadcast, _id).hashCode,
      );
      expect(const KilakilaLink(KilakilaLinkKind.owner, _id), isNot(_broadcast));
      expect(const KilakilaLink(KilakilaLinkKind.broadcast, _uid), isNot(_anchor));
    });

    test('its text names the kind and the id', () {
      expect(_broadcast.toString(), 'KilakilaLink(broadcast, $_id)');
      expect(_anchor.toString(), 'KilakilaLink(owner, $_uid)');
    });
  });
}
