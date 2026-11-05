import 'package:live_sites/src/platforms/sixroom/parsers/sixroom_failure.dart';
import 'package:live_sites/src/platforms/sixroom/parsers/sixroom_json.dart';
import 'package:test/test.dart';

/// A call that throws the failure [kind], and that message when the test names
/// one.
Matcher _fails(SixroomFailureKind kind, [Object? message = anything]) => throwsA(
  isA<SixroomFailure>()
      .having((failure) => failure.kind, 'kind', kind)
      .having((failure) => failure.message, 'message', message),
);

const int _limit = 8 * 1024 * 1024;

void main() {
  group('the gates', () {
    test('checkStatus treats a redirect as the site refusing', () {
      for (final status in [200, 204, 299]) {
        expect(() => SixroomJson.checkStatus(status, 'room'), returnsNormally, reason: '$status');
      }
      expect(() => SixroomJson.checkStatus(404, 'room'), _fails(SixroomFailureKind.notFound, 'room: HTTP 404'));
      expect(() => SixroomJson.checkStatus(410, 'room'), _fails(SixroomFailureKind.notFound, 'room: HTTP 410'));
      expect(() => SixroomJson.checkStatus(429, 'room'), _fails(SixroomFailureKind.rateLimited, 'room: HTTP 429'));
      expect(() => SixroomJson.checkStatus(401, 'room'), _fails(SixroomFailureKind.riskControl, 'room: HTTP 401'));
      expect(() => SixroomJson.checkStatus(403, 'api'), _fails(SixroomFailureKind.riskControl, 'api: HTTP 403'));
      // The site sends its refusals as redirects, so they are not a breakdown.
      for (final status in [301, 302, 307]) {
        expect(
          () => SixroomJson.checkStatus(status, 'api'),
          _fails(SixroomFailureKind.riskControl, 'api: HTTP $status'),
          reason: '$status',
        );
      }
      expect(() => SixroomJson.checkStatus(500, 'api'), _fails(SixroomFailureKind.network, 'api: HTTP 500'));
      expect(() => SixroomJson.checkStatus(418, 'api'), _fails(SixroomFailureKind.network, 'api: HTTP 418'));
      expect(() => SixroomJson.checkStatus(100, 'api'), _fails(SixroomFailureKind.network, 'api: HTTP 100'));
    });

    test('checkBody counts UTF-8 bytes, and only encodes when it must', () {
      expect(() => SixroomJson.checkBody('{}', 'room', 200), returnsNormally);
      // The status is asked before the size.
      expect(() => SixroomJson.checkBody('{}', 'room', 429), _fails(SixroomFailureKind.rateLimited));
      expect(
        () => SixroomJson.checkBody('x' * (_limit + 1), 'room', 200),
        _fails(SixroomFailureKind.apiChanged, 'room: answer over $_limit bytes'),
      );
      expect(() => SixroomJson.checkBody('x' * _limit, 'room', 200), returnsNormally);
      // Three bytes per character is the guess: under it nothing is encoded,
      // so wide text of that size passes without a count.
      expect(() => SixroomJson.checkBody('汉' * 2000000, 'room', 200), returnsNormally);
      // Past the guess the real count decides — and 2.9M characters of narrow
      // text is only 2.9M bytes, so it passes.
      expect(
        () => SixroomJson.checkBody('汉' * 2800000, 'room', 200),
        _fails(SixroomFailureKind.apiChanged, 'room: answer over $_limit bytes'),
      );
      expect(() => SixroomJson.checkBody('x' * 2900000, 'room', 200), returnsNormally);
    });

    test('json decodes an object and names what it is not', () {
      final root = <String, dynamic>{'a': 1};
      expect(SixroomJson.json('{"a":1}', 'room', 200), root);
      expect(
        () => SixroomJson.json('sorry', 'room', 200),
        _fails(SixroomFailureKind.apiChanged, 'room: not JSON (sorry)'),
      );
      expect(() => SixroomJson.json('', 'room', 200), _fails(SixroomFailureKind.apiChanged, 'room: not JSON ()'));
      expect(
        () => SixroomJson.json('[1,2]', 'room', 200),
        _fails(SixroomFailureKind.apiChanged, 'room: expected an object'),
      );
      expect(
        () => SixroomJson.json('null', 'room', 200),
        _fails(SixroomFailureKind.apiChanged, 'room: expected an object'),
      );
      expect(
        () => SixroomJson.json('42', 'room', 200),
        _fails(SixroomFailureKind.apiChanged, 'room: expected an object'),
      );
      // The gates come first, so a broken status never reads the text.
      expect(() => SixroomJson.json('sorry', 'room', 404), _fails(SixroomFailureKind.notFound));
    });

    test('object re-keys and map refuses nothing', () {
      final typed = <String, dynamic>{'a': 1};
      expect(identical(SixroomJson.object(typed, 'card'), typed), isTrue);
      expect(SixroomJson.object(<int, Object?>{1: 2}, 'card'), {'1': 2});
      expect(() => SixroomJson.object([1], 'card'), _fails(SixroomFailureKind.apiChanged, 'card: expected an object'));
      expect(() => SixroomJson.object(null, 'card'), _fails(SixroomFailureKind.apiChanged, 'card: expected an object'));
      expect(SixroomJson.map(<int, Object?>{1: 2}), {'1': 2});
      expect(SixroomJson.map([1]), isNull);
      expect(SixroomJson.map(null), isNull);
      expect(SixroomJson.map('a'), isNull);
    });
  });

  group('the readers', () {
    test('string trims anything and text also folds the spaces', () {
      expect(SixroomJson.string(' a  b '), 'a  b');
      expect(SixroomJson.string(null), '');
      expect(SixroomJson.string(30), '30');
      expect(SixroomJson.string([1, 2]), '[1, 2]');
      expect(SixroomJson.text(' a  b '), 'a b');
      expect(SixroomJson.text('  \t\n '), '');
      expect(SixroomJson.text(null), '');
      expect(SixroomJson.text(30.5), '30.5');
    });

    test('firstText takes the first line with something in it', () {
      expect(SixroomJson.firstText([null, '', '   ', ' 甲 乙 ', '丙']), '甲 乙');
      expect(SixroomJson.firstText([12, '甲']), '12');
      expect(SixroomJson.firstText([]), '');
      expect(SixroomJson.firstText([null, '']), '');
    });

    test('count truncates a number and accepts thousands separators', () {
      expect(SixroomJson.count(30), 30);
      expect(SixroomJson.count(30.9), 30);
      expect(SixroomJson.count('1,234'), 1234);
      expect(SixroomJson.count(' 12 '), 12);
      expect(SixroomJson.count('1,2,3'), 123);
      expect(SixroomJson.count(0), 0);
      expect(SixroomJson.count('0'), 0);
      expect(SixroomJson.count(-1), isNull);
      expect(SixroomJson.count(-0.5), isNull);
      expect(SixroomJson.count('-3'), isNull);
      expect(SixroomJson.count('1.5'), isNull);
      expect(SixroomJson.count(''), isNull);
      expect(SixroomJson.count(null), isNull);
      expect(SixroomJson.count(true), isNull);
    });

    test('time is epoch seconds with no window, and 0 is nothing', () {
      expect(SixroomJson.time(1760000000)!.millisecondsSinceEpoch, 1760000000000);
      expect(SixroomJson.time('1760000000')!.isUtc, isTrue);
      // The reader is `count`, so a number truncates and separators pass.
      expect(SixroomJson.time(1760000000.9)!.millisecondsSinceEpoch, 1760000000000);
      expect(SixroomJson.time('1,760,000,000')!.millisecondsSinceEpoch, 1760000000000);
      expect(SixroomJson.time(0), isNull);
      expect(SixroomJson.time('0'), isNull);
      expect(SixroomJson.time(-1), isNull);
      expect(SixroomJson.time(null), isNull);
      // Nothing asks whether the date is plausible.
      expect(SixroomJson.time(99999999999)!.year, greaterThan(2100));
    });

    test('truthy is true, 1 or the text 1', () {
      expect(SixroomJson.truthy(true), isTrue);
      expect(SixroomJson.truthy(1), isTrue);
      // A double one equals the int one.
      expect(SixroomJson.truthy(1.0), isTrue);
      expect(SixroomJson.truthy('1'), isTrue);
      expect(SixroomJson.truthy(' 1 '), isTrue);
      expect(SixroomJson.truthy(false), isFalse);
      expect(SixroomJson.truthy(0), isFalse);
      expect(SixroomJson.truthy('true'), isFalse);
      expect(SixroomJson.truthy('yes'), isFalse);
      expect(SixroomJson.truthy('01'), isFalse);
      expect(SixroomJson.truthy(null), isFalse);
    });
  });

  group('the addresses', () {
    test('image is normalized, not returned as written', () {
      for (final host in ['6.cn', 'p6.6.cn', '6rooms.com', 's.6rooms.com', 'xiu123.cn', 'a.xiu123.cn']) {
        expect(SixroomJson.image('https://$host/a.png'), 'https://$host/a.png', reason: host);
      }
      expect(SixroomJson.image('//p6.6.cn/a.png'), 'https://p6.6.cn/a.png');
      expect(SixroomJson.image('http://p6.6.cn/a.png'), 'https://p6.6.cn/a.png');
      expect(SixroomJson.image('  https://6.cn/a.png  '), 'https://6.cn/a.png');
      // What comes back is the parsed URI, not the text: the parser writes the
      // scheme and the host in lower case, while the path keeps its case.
      expect(SixroomJson.image('HTTPS://6.CN/A.PNG'), 'https://6.cn/A.PNG');
      expect(SixroomJson.image('https://6.cn/a.png?x=1'), 'https://6.cn/a.png?x=1');
    });

    test('image refuses a port that is not the default, user info, a fragment and another host', () {
      // A written default port is not a port to the parser (`hasPort` false),
      // so it passes the gate and drops out of the answer — where showroom
      // keeps a written 443.
      expect(SixroomJson.image('https://6.cn:443/a.png'), 'https://6.cn/a.png');
      // The scheme is rewritten on the text before it is parsed, so an http
      // address on its own port 80 arrives as https on a non-default port.
      expect(SixroomJson.image('http://6.cn:80/a.png'), '');
      expect(SixroomJson.image('http://6.cn/a.png'), 'https://6.cn/a.png');
      expect(SixroomJson.image('https://6.cn:8080/a.png'), '');
      expect(SixroomJson.image('https://me@6.cn/a.png'), '');
      expect(SixroomJson.image('https://6.cn/a.png#f'), '');
      expect(SixroomJson.image('http://evil.test/a.png'), '');
      expect(SixroomJson.image('https://6.cn.evil.test/a.png'), '');
      expect(SixroomJson.image('https://x6.cn/a.png'), '');
      expect(SixroomJson.image('a.png'), '');
      expect(SixroomJson.image('/a.png'), '');
      expect(SixroomJson.image(''), '');
      expect(SixroomJson.image(null), '');
      expect(SixroomJson.image(30), '');
    });

    test('firstImage takes the address that survives the gate', () {
      expect(
        SixroomJson.firstImage(['', null, 'evil.test', '//p6.6.cn/a.png', 'https://6.cn/b.png']),
        'https://p6.6.cn/a.png',
      );
      expect(SixroomJson.firstImage(['https://6.cn:8080/a.png', 'https://xiu123.cn/b.png']), 'https://xiu123.cn/b.png');
      expect(SixroomJson.firstImage([]), '');
      expect(SixroomJson.firstImage([null, '', 'oops']), '');
    });

    test('snippet is one line and at most 80 characters', () {
      expect(SixroomJson.snippet(' a\tb\nc  '), 'a b c');
      expect(SixroomJson.snippet('   '), '');
      final long = 'x' * 80;
      expect(SixroomJson.snippet(long), long);
      expect(SixroomJson.snippet('x' * 81), '${'x' * 80}…');
    });
  });
}
