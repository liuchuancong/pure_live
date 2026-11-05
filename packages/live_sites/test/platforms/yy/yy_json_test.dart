import 'package:live_sites/src/platforms/yy/api/yy_endpoints.dart';
import 'package:live_sites/src/platforms/yy/parsers/yy_failure.dart';
import 'package:live_sites/src/platforms/yy/parsers/yy_json.dart';
import 'package:test/test.dart';

/// A call that throws the failure [kind], and that message when the test names
/// one.
Matcher _fails(YyFailureKind kind, [Object? message = anything]) => throwsA(
  isA<YyFailure>()
      .having((failure) => failure.kind, 'kind', kind)
      .having((failure) => failure.message, 'message', message),
);

void main() {
  group('the answer gates', () {
    test('decoded throws on the status and only on the status', () {
      expect(YyJson.decoded('{"resultCode":0}', status: 200, what: 'hot'), {'resultCode': 0});
      // A 2xx that is not JSON is no answer, not a breakdown: the caller decides.
      expect(YyJson.decoded('sorry', status: 200, what: 'hot'), isNull);
      expect(YyJson.decoded('', status: 204, what: 'hot'), isNull);
      expect(() => YyJson.decoded('x', status: 429, what: 'hot'), _fails(YyFailureKind.rateLimited, 'hot: HTTP 429'));
      expect(() => YyJson.decoded('x', status: 401, what: 'hot'), _fails(YyFailureKind.riskControl, 'hot: HTTP 401'));
      expect(() => YyJson.decoded('x', status: 403, what: 'page'), _fails(YyFailureKind.riskControl, 'page: HTTP 403'));
      expect(() => YyJson.decoded('x', status: 500, what: 'hot'), _fails(YyFailureKind.network, 'hot: HTTP 500'));
      expect(() => YyJson.decoded('x', status: 503, what: 'hot'), _fails(YyFailureKind.network, 'hot: HTTP 503'));
      // A redirect on an API request and a 1xx are neither of the known shapes.
      expect(
        () => YyJson.decoded('Moved', status: 302, what: 'hot'),
        _fails(YyFailureKind.apiChanged, 'hot: HTTP 302 (Moved)'),
      );
      expect(() => YyJson.decoded('x', status: 199, what: 'hot'), _fails(YyFailureKind.apiChanged));
    });

    test('a decoded answer is only read as an object', () {
      // The list and the bare text still reach the caller as themselves.
      expect(YyJson.decoded('[1,2]', status: 200, what: 'hot'), [1, 2]);
      expect(YyJson.decoded('null', status: 200, what: 'hot'), isNull);
      expect(YyJson.decoded('"text"', status: 200, what: 'hot'), 'text');
    });

    test('checked wants resultCode 0, as a number or as its text', () {
      expect(YyJson.checked('{"resultCode":0,"data":{}}', status: 200, what: 'detail'), {
        'resultCode': 0,
        'data': <String, Object?>{},
      });
      expect(YyJson.checked('{"resultCode":"0"}', status: 200, what: 'detail'), {'resultCode': '0'});
      expect(YyJson.checked('{"resultCode":" 0 "}', status: 200, what: 'detail'), {'resultCode': ' 0 '});
      expect(
        () => YyJson.checked('{"resultCode":5}', status: 200, what: 'detail'),
        _fails(YyFailureKind.apiChanged, 'detail: resultCode 5 ({"resultCode":5})'),
      );
      // A missing, an unparsable or a floating code all read as "not 0".
      expect(
        () => YyJson.checked('{}', status: 200, what: 'detail'),
        _fails(YyFailureKind.apiChanged, 'detail: resultCode null ({})'),
      );
      expect(
        () => YyJson.checked('{"resultCode":0.0}', status: 200, what: 'detail'),
        _fails(YyFailureKind.apiChanged, 'detail: resultCode null ({"resultCode":0.0})'),
      );
      expect(
        () => YyJson.checked('{"resultCode":"x"}', status: 200, what: 'detail'),
        _fails(YyFailureKind.apiChanged, 'detail: resultCode null ({"resultCode":"x"})'),
      );
      // The status is asked before the envelope, so a throttle stays a throttle.
      expect(() => YyJson.checked('{"resultCode":0}', status: 429, what: 'detail'), _fails(YyFailureKind.rateLimited));
    });

    test('a body that is not a JSON object means the shape changed', () {
      for (final body in ['', '[]', 'sorry', '42']) {
        expect(
          () => YyJson.checked(body, status: 200, what: 'hot'),
          _fails(YyFailureKind.apiChanged, 'hot: not a JSON object ($body)'),
          reason: 'body <$body>',
        );
      }
      // `null` decodes to nothing, so it too is the object that is missing.
      expect(
        () => YyJson.checked('null', status: 200, what: 'hot'),
        _fails(YyFailureKind.apiChanged, 'hot: not a JSON object (null)'),
      );
    });

    test('checkPage reads the same table without the body', () {
      expect(() => YyJson.checkPage(200, 'room'), returnsNormally);
      expect(() => YyJson.checkPage(204, 'room'), returnsNormally);
      // A real 404 is the shape changed here: the page YY answers for a gone
      // room is a 200 carrying yycom_404, which is the room parser's to tell.
      expect(() => YyJson.checkPage(404, 'room'), _fails(YyFailureKind.apiChanged, 'room: HTTP 404'));
      expect(() => YyJson.checkPage(429, 'room'), _fails(YyFailureKind.rateLimited, 'room: HTTP 429'));
      expect(() => YyJson.checkPage(403, 'room'), _fails(YyFailureKind.riskControl, 'room: HTTP 403'));
      expect(() => YyJson.checkPage(500, 'room'), _fails(YyFailureKind.network, 'room: HTTP 500'));
      expect(() => YyJson.checkPage(405, 'page'), _fails(YyFailureKind.apiChanged, 'page: HTTP 405'));
      expect(() => YyJson.checkPage(301, 'page'), _fails(YyFailureKind.apiChanged, 'page: HTTP 301'));
    });
  });

  group('the readers', () {
    test('object, field and list', () {
      expect(YyJson.object({'a': 1}), {'a': 1});
      expect(YyJson.object(<String, Object?>{}), isEmpty);
      expect(YyJson.object([1]), isNull);
      expect(YyJson.object('a'), isNull);
      expect(YyJson.object(null), isNull);
      expect(YyJson.field({'a': 1}, 'card'), {'a': 1});
      expect(() => YyJson.field([1], 'card'), _fails(YyFailureKind.apiChanged, 'card: expected an object'));
      expect(YyJson.list([1, 'a']), [1, 'a']);
      expect(YyJson.list([]), isEmpty);
      expect(YyJson.list(null), isEmpty);
      expect(YyJson.list('a'), isEmpty);
      expect(YyJson.list(42), isEmpty);
    });

    test('text wants a word and scalar also takes a number', () {
      // YY sends ids and counts as numbers in the directory and the detail and
      // as text on search and the room page, so `scalar` is the id reader.
      expect(YyJson.text('  a b  '), 'a b');
      expect(YyJson.text(30), '');
      expect(YyJson.text(null), '');
      expect(YyJson.scalar(30), '30');
      expect(YyJson.scalar(' 30 '), '30');
      expect(YyJson.scalar(30.5), '30.5');
      expect(YyJson.scalar(0), '0');
      expect(YyJson.scalar(true), '');
      expect(YyJson.scalar(null), '');
    });

    test('integer takes an int or an integer text, never a float', () {
      expect(YyJson.integer(42), 42);
      expect(YyJson.integer(' 42 '), 42);
      expect(YyJson.integer('-1'), -1);
      expect(YyJson.integer(42.0), isNull);
      expect(YyJson.integer('42.0'), isNull);
      expect(YyJson.integer('x'), isNull);
      expect(YyJson.integer(''), isNull);
      expect(YyJson.integer(null), isNull);
      expect(YyJson.integer(true), isNull);
    });

    test('a channel is 1 to 16 digits without a leading zero', () {
      expect(YyEndpoints.isChannel('1234567890123456'), isTrue);
      expect(YyJson.channel('1234567890123456'), '1234567890123456');
      expect(YyJson.channel(' 123 '), '123');
      expect(YyJson.channel(123), '123');
      expect(YyJson.channel('12345678901234567'), isNull);
      expect(YyJson.channel('0'), isNull);
      expect(YyJson.channel('01'), isNull);
      expect(YyJson.channel(''), isNull);
      expect(YyJson.channel('a123'), isNull);
      expect(YyJson.channel(30.5), isNull);
    });

    test('url only refuses what is not a non-empty string', () {
      expect(YyJson.url('https://a.test/p'), Uri.parse('https://a.test/p'));
      expect(YyJson.url('foo/bar')?.toString(), 'foo/bar');
      expect(YyJson.url(''), isNull);
      expect(YyJson.url(null), isNull);
      expect(YyJson.url(42), isNull);
    });

    test('liveOn and friends: 1, true or live', () {
      expect(YyJson.isLive(true), isTrue);
      expect(YyJson.isLive(false), isFalse);
      expect(YyJson.isLive(1), isTrue);
      expect(YyJson.isLive('1'), isTrue);
      expect(YyJson.isLive(' LIVE '), isTrue);
      expect(YyJson.isLive('True'), isTrue);
      expect(YyJson.isLive(0), isFalse);
      expect(YyJson.isLive('yes'), isFalse);
      expect(YyJson.isLive('on'), isFalse);
      expect(YyJson.isLive(null), isFalse);
    });

    test('a start is Unix seconds, and never milliseconds', () {
      expect(YyJson.startedAt(1760000000)!.millisecondsSinceEpoch, 1760000000000);
      expect(YyJson.startedAt('1760000000')!.isUtc, isTrue);
      expect(YyJson.startedAt(1), isNotNull);
      expect(YyJson.startedAt(0), isNull);
      expect(YyJson.startedAt(-1), isNull);
      // The bound is exclusive: a millisecond stamp is far past it, while one
      // second under it still reads as a date the site could mean.
      expect(YyJson.startedAt(1760000000000), isNull);
      expect(YyJson.startedAt(99999999999), isNotNull);
      expect(YyJson.startedAt(100000000000), isNull);
      expect(YyJson.startedAt(null), isNull);
      expect(YyJson.startedAt(1.0), isNull);
    });
  });

  group('the text of the site', () {
    test('a title loses the suffix the site adds itself, with or without the space', () {
      expect(YyJson.title('甲 正在直播'), '甲');
      expect(YyJson.title('甲正在直播'), '甲');
      expect(YyJson.title('  乙 正在直播  '), '乙');
      expect(YyJson.title('正在直播'), '');
      expect(YyJson.title('日常标题'), '日常标题');
      // The suffix only counts at the end.
      expect(YyJson.title('正在直播的甲'), '正在直播的甲');
      expect(YyJson.title(null), '');
      expect(YyJson.title(30), '');
    });

    test('a streamer named by the placeholder is nobody', () {
      expect(YyJson.name(YyEndpoints.placeholderName), '');
      expect(YyJson.name(' YY用户 '), '');
      expect(YyJson.name('甲'), '甲');
      expect(YyJson.name(''), '');
      expect(YyJson.name(null), '');
    });

    test('an image is made absolute and served over https', () {
      expect(YyJson.image('http://a.test/x.png'), 'https://a.test/x.png');
      expect(YyJson.image('//a.test/x.png'), 'https://a.test/x.png');
      expect(YyJson.image('https://a.test/x.png'), 'https://a.test/x.png');
      // A JSON string that arrived still quoted, and a bare host/path.
      expect(YyJson.image('"https://a.test/x.png"'), 'https://a.test/x.png');
      expect(YyJson.image('a.test/x.png'), 'https://a.test/x.png');
      expect(YyJson.image(null), '');
      expect(YyJson.image('null'), '');
      expect(YyJson.image('x y'), '');
      expect(YyJson.image('/p/x.png'), '');
      expect(YyJson.image(30), '');
      expect(YyJson.image(''), '');
    });

    test('https rewrites two spellings and leaves the rest', () {
      expect(YyJson.https('  http://a.test  '), 'https://a.test');
      expect(YyJson.https('//a.test/p'), 'https://a.test/p');
      // A single-slash scheme and an upper-case one are not rewritten.
      expect(YyJson.https('http:/a.test'), 'http:/a.test');
      expect(YyJson.https('HTTP://A.TEST'), 'HTTP://A.TEST');
      expect(YyJson.https('https://a.test'), 'https://a.test');
      expect(YyJson.https(''), '');
    });

    test('a snippet is one line and at most 80 characters', () {
      expect(YyJson.snippet(' a\tb\nc  '), 'a b c');
      final long = 'x' * 80;
      expect(YyJson.snippet(long), long);
      expect(YyJson.snippet('x' * 81), '${'x' * 80}…');
      expect(YyJson.snippet('   '), '');
    });
  });

  group('percentDecode', () {
    test('it decodes what the browser would and keeps the rest', () {
      expect(YyJson.percentDecode('%41a%42'), 'AaB');
      expect(YyJson.percentDecode('%e4%bd%a0%e5%a5%bd'), '你好');
      expect(YyJson.percentDecode('%25'), '%');
      expect(YyJson.percentDecode('%2f%2F'), '//');
      expect(YyJson.percentDecode('plain'), 'plain');
      // A malformed escape stays written as it came, and malformed UTF-8
      // becomes U+FFFD instead of throwing the way Uri.decodeComponent does.
      expect(YyJson.percentDecode('%zz'), '%zz');
      expect(YyJson.percentDecode('a%41%4'), 'aA%4');
      expect(YyJson.percentDecode('%ff'), '\u{FFFD}');
      expect(YyJson.percentDecode('100%'), '100%');
      expect(YyJson.percentDecode(''), '');
    });
  });
}
