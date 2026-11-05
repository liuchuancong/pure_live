import 'package:live_sites/src/platforms/showroom/api/showroom_endpoints.dart';
import 'package:live_sites/src/platforms/showroom/parsers/showroom_failure.dart';
import 'package:live_sites/src/platforms/showroom/parsers/showroom_json.dart';
import 'package:test/test.dart';

/// A call that throws the failure [kind], and that message when the test names
/// one.
Matcher _fails(ShowroomFailureKind kind, [Object? message = anything]) => throwsA(
  isA<ShowroomFailure>()
      .having((failure) => failure.kind, 'kind', kind)
      .having((failure) => failure.message, 'message', message),
);

void main() {
  group('the envelope', () {
    test('checked lets only 200 through and names every other status', () {
      expect(ShowroomJson.checked('{"a":1}', status: 200, what: 'room'), {'a': 1});
      expect(ShowroomJson.checked('{}', status: 200, what: 'room'), isEmpty);
      // A redirect and a 204 are not answers, and the body is never read.
      for (final status in [201, 204, 301, 302, 418, 500, 503]) {
        expect(
          () => ShowroomJson.checked('{"a":1}', status: status, what: 'room'),
          _fails(ShowroomFailureKind.network, 'room: HTTP $status'),
          reason: '$status',
        );
      }
      expect(
        () => ShowroomJson.checked('x', status: 401, what: 'room'),
        _fails(ShowroomFailureKind.riskControl, 'room: HTTP 401'),
      );
      expect(
        () => ShowroomJson.checked('x', status: 403, what: 'api'),
        _fails(ShowroomFailureKind.riskControl, 'api: HTTP 403'),
      );
      expect(
        () => ShowroomJson.checked('x', status: 404, what: 'api'),
        _fails(ShowroomFailureKind.notFound, 'api: HTTP 404'),
      );
      expect(
        () => ShowroomJson.checked('x', status: 429, what: 'api'),
        _fails(ShowroomFailureKind.rateLimited, 'api: HTTP 429'),
      );
    });

    test('a 200 that is not JSON, or not an object, changed shape', () {
      expect(
        () => ShowroomJson.checked('sorry', status: 200, what: 'room'),
        _fails(ShowroomFailureKind.apiChanged, 'room: not JSON (sorry)'),
      );
      // The body arrives with the failure, on one line.
      expect(
        () => ShowroomJson.checked('<html>\n  <body>oops</body>', status: 200, what: 'room'),
        _fails(ShowroomFailureKind.apiChanged, 'room: not JSON (<html> <body>oops</body>)'),
      );
      expect(
        () => ShowroomJson.checked('[1,2]', status: 200, what: 'room'),
        _fails(ShowroomFailureKind.apiChanged, 'room: not an object'),
      );
      expect(
        () => ShowroomJson.checked('"text"', status: 200, what: 'room'),
        _fails(ShowroomFailureKind.apiChanged, 'room: not an object'),
      );
      expect(
        () => ShowroomJson.checked('null', status: 200, what: 'room'),
        _fails(ShowroomFailureKind.apiChanged, 'room: not an object'),
      );
      expect(
        () => ShowroomJson.checked('', status: 200, what: 'room'),
        _fails(ShowroomFailureKind.apiChanged, 'room: not JSON ()'),
      );
    });

    test('object re-keys any map and refuses anything else', () {
      expect(ShowroomJson.object(<int, Object?>{1: 2}, 'card'), {'1': 2});
      expect(ShowroomJson.object(const <Object?, Object?>{}, 'card'), isEmpty);
      expect(() => ShowroomJson.object([1], 'card'), _fails(ShowroomFailureKind.apiChanged, 'card: not an object'));
      expect(() => ShowroomJson.object('a', 'card'), _fails(ShowroomFailureKind.apiChanged, 'card: not an object'));
      expect(() => ShowroomJson.object(42, 'card'), _fails(ShowroomFailureKind.apiChanged, 'card: not an object'));
      expect(() => ShowroomJson.object(null, 'card'), _fails(ShowroomFailureKind.apiChanged, 'card: not an object'));
    });

    test('list caps by count and throws rather than truncating', () {
      expect(ShowroomJson.list([1, 'a'], 'rows', max: 2), [1, 'a']);
      expect(ShowroomJson.list([], 'rows', max: 0), isEmpty);
      expect(
        () => ShowroomJson.list([1, 2, 3], 'rows', max: 2),
        _fails(ShowroomFailureKind.apiChanged, 'rows is 3 items'),
      );
      expect(
        () => ShowroomJson.list('abc', 'rows', max: 2),
        _fails(ShowroomFailureKind.apiChanged, 'rows is not a list'),
      );
      expect(
        () => ShowroomJson.list(null, 'rows', max: 2),
        _fails(ShowroomFailureKind.apiChanged, 'rows is not a list'),
      );
      expect(
        () => ShowroomJson.list({'a': 1}, 'rows', max: 2),
        _fails(ShowroomFailureKind.apiChanged, 'rows is not a list'),
      );
    });
  });

  group('the numbers and the text', () {
    test('integer is the reference reading: an int or an integer string', () {
      expect(ShowroomJson.integer(30), 30);
      expect(ShowroomJson.integer('30'), 30);
      // No explicit trim: `int.tryParse` eats the space itself.
      expect(ShowroomJson.integer(' 30 '), 30);
      expect(ShowroomJson.integer('-4'), -4);
      expect(ShowroomJson.integer(''), isNull);
      expect(ShowroomJson.integer(null), isNull);
      expect(ShowroomJson.integer(true), isNull);
      // A `0x` text is read as hex: `int.tryParse` without a radix allows the
      // prefix, so this reader takes it too.
      expect(ShowroomJson.integer('0x1A'), 26);
      expect(ShowroomJson.integer('3e3'), isNull);
      // A JSON float is not an integer here, whole as it looks.
      expect(ShowroomJson.integer(30.0), isNull);
      expect(ShowroomJson.integer('30.0'), isNull);
    });

    test('positive wants more than nothing and count allows it', () {
      expect(ShowroomJson.positive(1, 'id'), 1);
      expect(ShowroomJson.positive('12', 'id'), 12);
      for (final value in [0, -1, '0', null, '', 'x', 30.0]) {
        expect(
          () => ShowroomJson.positive(value, 'id'),
          _fails(ShowroomFailureKind.apiChanged, 'id is $value'),
          reason: '$value',
        );
      }
      expect(ShowroomJson.count(0, 'watchers'), 0);
      expect(ShowroomJson.count('12', 'watchers'), 12);
      for (final value in [-1, '-1', null, 'x']) {
        expect(
          () => ShowroomJson.count(value, 'watchers'),
          _fails(ShowroomFailureKind.apiChanged, 'watchers is $value'),
          reason: '$value',
        );
      }
    });

    test('optionalCount allows the answer to leave the field out', () {
      expect(ShowroomJson.optionalCount(null, 'gifts'), isNull);
      expect(ShowroomJson.optionalCount('', 'gifts'), isNull);
      expect(ShowroomJson.optionalCount(0, 'gifts'), 0);
      expect(ShowroomJson.optionalCount('7', 'gifts'), 7);
      expect(() => ShowroomJson.optionalCount(-1, 'gifts'), _fails(ShowroomFailureKind.apiChanged, 'gifts is -1'));
      expect(() => ShowroomJson.optionalCount('x', 'gifts'), _fails(ShowroomFailureKind.apiChanged, 'gifts is x'));
    });

    test('text wants a non-blank string within 8192 and trims it', () {
      expect(ShowroomJson.text('  タイトル  ', 'title'), 'タイトル');
      expect(ShowroomJson.text('x' * 8192, 'title'), 'x' * 8192);
      // An oversized text is echoed whole into the message: no snippet here.
      final oversized = 'x' * 8193;
      expect(
        () => ShowroomJson.text(oversized, 'title'),
        _fails(ShowroomFailureKind.apiChanged, 'title is $oversized'),
      );
      // The gate is on the text as written: blanks trimmed to nothing fail too.
      expect(() => ShowroomJson.text('   ', 'title'), _fails(ShowroomFailureKind.apiChanged, 'title is    '));
      expect(() => ShowroomJson.text('', 'title'), _fails(ShowroomFailureKind.apiChanged, 'title is '));
      expect(() => ShowroomJson.text(null, 'title'), _fails(ShowroomFailureKind.apiChanged, 'title is null'));
      expect(() => ShowroomJson.text(30, 'title'), _fails(ShowroomFailureKind.apiChanged, 'title is 30'));
    });

    test('optionalText allows a blank and caps at 131072', () {
      expect(ShowroomJson.optionalText(null, 'detail'), '');
      expect(ShowroomJson.optionalText('  ', 'detail'), '');
      expect(ShowroomJson.optionalText(' a b ', 'detail'), 'a b');
      expect(ShowroomJson.optionalText('x' * 131072, 'detail').length, 131072);
      expect(
        () => ShowroomJson.optionalText('x' * 131073, 'detail'),
        _fails(ShowroomFailureKind.apiChanged, 'detail is not text'),
      );
      // Any other type is the same answer, whatever it holds.
      expect(
        () => ShowroomJson.optionalText(30, 'detail'),
        _fails(ShowroomFailureKind.apiChanged, 'detail is not text'),
      );
      expect(
        () => ShowroomJson.optionalText([1], 'detail'),
        _fails(ShowroomFailureKind.apiChanged, 'detail is not text'),
      );
    });

    test('key trims first and then asks the room-key shape', () {
      expect(ShowroomJson.key(' abc-1_2 ', 'room'), 'abc-1_2');
      expect(ShowroomJson.key('x' * 128, 'room').length, 128);
      final tooLong = 'x' * 129;
      expect(
        () => ShowroomJson.key(tooLong, 'room'),
        _fails(ShowroomFailureKind.apiChanged, 'room "$tooLong" is not a room key'),
      );
      expect(
        () => ShowroomJson.key('a.b', 'room'),
        _fails(ShowroomFailureKind.apiChanged, 'room "a.b" is not a room key'),
      );
      expect(
        () => ShowroomJson.key('a b', 'room'),
        _fails(ShowroomFailureKind.apiChanged, 'room "a b" is not a room key'),
      );
      expect(() => ShowroomJson.key('', 'room'), _fails(ShowroomFailureKind.apiChanged, 'room is '));
      expect(() => ShowroomJson.key(30, 'room'), _fails(ShowroomFailureKind.apiChanged, 'room is 30'));
      expect(ShowroomEndpoints.keyPattern.hasMatch('abc-1_2'), isTrue);
    });

    test('optionalString never fails', () {
      expect(ShowroomJson.optionalString(' a '), 'a');
      expect(ShowroomJson.optionalString(''), isNull);
      expect(ShowroomJson.optionalString('   '), isNull);
      expect(ShowroomJson.optionalString(null), isNull);
      expect(ShowroomJson.optionalString(30), isNull);
      expect(ShowroomJson.optionalString([1]), isNull);
    });
  });

  group('the addresses', () {
    test('image gives the address back as written or nothing', () {
      for (final host in [
        'showroom-live.com',
        'p.showroom-live.com',
        'showroom-txlive.com',
        'a.b.showroom-txlive.com',
      ]) {
        expect(ShowroomJson.image('https://$host/a.png'), 'https://$host/a.png', reason: host);
      }
      // Nothing is normalized: the query, the fragment and the case stay.
      expect(ShowroomJson.image('https://showroom-live.com/a?x=1#f'), 'https://showroom-live.com/a?x=1#f');
      expect(ShowroomJson.image('HTTPS://SHOWROOM-LIVE.COM/a.png'), 'HTTPS://SHOWROOM-LIVE.COM/a.png');
      // An untrusted host, another scheme, user info or a relative text is none.
      expect(ShowroomJson.image('http://showroom-live.com/a.png'), '');
      expect(ShowroomJson.image('https://evil.test/a.png'), '');
      expect(ShowroomJson.image('https://showroom-live.com.evil.test/a.png'), '');
      expect(ShowroomJson.image('https://me@showroom-live.com/a.png'), '');
      expect(ShowroomJson.image('a.png'), '');
      expect(ShowroomJson.image(''), '');
      // A broken address never fails the room: it is simply nothing.
      expect(ShowroomJson.image(null), '');
      expect(ShowroomJson.image(30), '');
      expect(ShowroomJson.image('x' * 8193), '');
    });

    test('mediaUrl asks the same host and refuses what image tolerates', () {
      expect(
        ShowroomJson.mediaUrl('https://showroom-txlive.com/live/a.m3u8', 'line'),
        'https://showroom-txlive.com/live/a.m3u8',
      );
      expect(ShowroomJson.mediaUrl('https://showroom-live.com/a?x=1', 'line'), 'https://showroom-live.com/a?x=1');
      expect(
        () => ShowroomJson.mediaUrl('https://showroom-live.com/a#f', 'line'),
        _fails(ShowroomFailureKind.apiChanged, 'line: url https://showroom-live.com/a#f'),
      );
      expect(
        () => ShowroomJson.mediaUrl('http://showroom-live.com/a', 'line'),
        _fails(ShowroomFailureKind.apiChanged, 'line: url http://showroom-live.com/a'),
      );
      expect(
        () => ShowroomJson.mediaUrl('https://evil.test/a', 'line'),
        _fails(ShowroomFailureKind.apiChanged, 'line: url https://evil.test/a'),
      );
      expect(
        () => ShowroomJson.mediaUrl('https://me@showroom-live.com/a', 'line'),
        _fails(ShowroomFailureKind.apiChanged, 'line: url https://me@showroom-live.com/a'),
      );
      expect(
        () => ShowroomJson.mediaUrl('https://', 'line'),
        _fails(ShowroomFailureKind.apiChanged, 'line: url https://'),
      );
      // Spaces and controls fail before the URL is even parsed.
      expect(
        () => ShowroomJson.mediaUrl('https://showroom-live.com/a b', 'line'),
        _fails(ShowroomFailureKind.apiChanged, 'line: url https://showroom-live.com/a b'),
      );
      expect(
        () => ShowroomJson.mediaUrl('https://showroom-live.com/a\nb', 'line'),
        _fails(ShowroomFailureKind.apiChanged, 'line: url https://showroom-live.com/a b'),
      );
      expect(() => ShowroomJson.mediaUrl(null, 'line'), _fails(ShowroomFailureKind.apiChanged, 'line: url null'));
      expect(() => ShowroomJson.mediaUrl(30, 'line'), _fails(ShowroomFailureKind.apiChanged, 'line: url 30'));
      expect(
        () => ShowroomJson.mediaUrl('x' * 8193, 'line'),
        _fails(ShowroomFailureKind.apiChanged, 'line: url ${'x' * 80}…'),
      );
    });

    test('snippet is one line and at most 80 characters', () {
      expect(ShowroomJson.snippet(' a\tb\nc  '), 'a b c');
      expect(ShowroomJson.snippet('   '), '');
      final long = 'x' * 80;
      expect(ShowroomJson.snippet(long), long);
      expect(ShowroomJson.snippet('x' * 81), '${'x' * 80}…');
    });
  });
}
