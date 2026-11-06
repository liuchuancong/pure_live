import 'package:live_sites/src/platforms/inke/parsers/inke_failure.dart';
import 'package:live_sites/src/platforms/inke/parsers/inke_json.dart';
import 'package:test/test.dart';

/// A call that throws the failure [kind], and that message when the test names
/// one.
Matcher _fails(InkeFailureKind kind, [Object? message]) => throwsA(
  isA<InkeFailure>()
      .having((failure) => failure.kind, 'kind', kind)
      .having((failure) => failure.message, 'message', message ?? anything),
);

const int _limit = 1024 * 1024;

void main() {
  group('the gates', () {
    test('checkStatus calls only 200 an answer and 400 a breakdown', () {
      expect(() => InkeJson.checkStatus(200, 'hot'), returnsNormally);
      // A 204 is not 200 here, and a 400 is not the shape changed either.
      expect(() => InkeJson.checkStatus(204, 'hot'), _fails(InkeFailureKind.network, 'hot: HTTP 204'));
      expect(() => InkeJson.checkStatus(400, 'hot'), _fails(InkeFailureKind.network, 'hot: HTTP 400'));
      expect(() => InkeJson.checkStatus(401, 'hot'), _fails(InkeFailureKind.riskControl, 'hot: HTTP 401'));
      expect(() => InkeJson.checkStatus(403, 'room'), _fails(InkeFailureKind.riskControl, 'room: HTTP 403'));
      expect(() => InkeJson.checkStatus(404, 'room'), _fails(InkeFailureKind.notFound, 'room: HTTP 404'));
      expect(() => InkeJson.checkStatus(429, 'room'), _fails(InkeFailureKind.rateLimited, 'room: HTTP 429'));
      expect(() => InkeJson.checkStatus(302, 'room'), _fails(InkeFailureKind.network, 'room: HTTP 302'));
      expect(() => InkeJson.checkStatus(500, 'room'), _fails(InkeFailureKind.network, 'room: HTTP 500'));
    });

    test('checkBody counts one mebibyte in UTF-8 bytes', () {
      expect(() => InkeJson.checkBody('{}', 'hot', 200), returnsNormally);
      expect(() => InkeJson.checkBody('{}', 'hot', 429), _fails(InkeFailureKind.rateLimited));
      expect(
        () => InkeJson.checkBody('x' * (_limit + 1), 'hot', 200),
        _fails(InkeFailureKind.apiChanged, 'hot: answer over $_limit bytes'),
      );
      expect(() => InkeJson.checkBody('x' * _limit, 'hot', 200), returnsNormally);
      // Three bytes per unit is the guess: under it nothing is encoded.
      expect(() => InkeJson.checkBody('汉' * 300000, 'hot', 200), returnsNormally);
      // Past the guess the real count decides, in either direction.
      expect(
        () => InkeJson.checkBody('汉' * 400000, 'hot', 200),
        _fails(InkeFailureKind.apiChanged, 'hot: answer over $_limit bytes'),
      );
      expect(() => InkeJson.checkBody('x' * 400000, 'hot', 200), returnsNormally);
    });

    test('json wants an object of the decoded shape', () {
      expect(InkeJson.json('{"a":1}', 'hot', 200), {'a': 1});
      expect(() => InkeJson.json('sorry', 'hot', 200), _fails(InkeFailureKind.apiChanged, 'hot: not JSON'));
      // No snippet joins the message here.
      expect(() => InkeJson.json('', 'hot', 200), _fails(InkeFailureKind.apiChanged, 'hot: not JSON'));
      expect(() => InkeJson.json('[1,2]', 'hot', 200), _fails(InkeFailureKind.apiChanged, 'hot: expected an object'));
      expect(() => InkeJson.json('42', 'hot', 200), _fails(InkeFailureKind.apiChanged, 'hot: expected an object'));
      expect(() => InkeJson.json('null', 'hot', 200), _fails(InkeFailureKind.apiChanged, 'hot: expected an object'));
      expect(() => InkeJson.json('sorry', 'hot', 404), _fails(InkeFailureKind.notFound));
    });

    test('object accepts nothing that is not a decoded map', () {
      final typed = <String, dynamic>{'a': 1};
      expect(identical(InkeJson.object(typed, 'card'), typed), isTrue);
      // Unlike the other platforms' readers, no re-keying: a hand-made map of
      // other keys is not an answer.
      expect(
        () => InkeJson.object(<int, Object?>{1: 2}, 'card'),
        _fails(InkeFailureKind.apiChanged, 'card: expected an object'),
      );
      expect(() => InkeJson.object([1], 'card'), _fails(InkeFailureKind.apiChanged, 'card: expected an object'));
      expect(() => InkeJson.object('a', 'card'), _fails(InkeFailureKind.apiChanged, 'card: expected an object'));
      expect(() => InkeJson.object(null, 'card'), _fails(InkeFailureKind.apiChanged, 'card: expected an object'));
    });
  });

  group('the readers', () {
    test('text takes only a string', () {
      expect(InkeJson.text(' a b '), 'a b');
      expect(InkeJson.text(''), '');
      expect(InkeJson.text(null), '');
      expect(InkeJson.text(30), '');
      expect(InkeJson.text([1, 2]), '');
      expect(InkeJson.text(true), '');
    });

    test('integer reads an int or digit text, never a float', () {
      expect(InkeJson.integer(30), 30);
      expect(InkeJson.integer('30'), 30);
      expect(InkeJson.integer('-4'), -4);
      expect(InkeJson.integer(30.0), isNull);
      expect(InkeJson.integer('30.0'), isNull);
      expect(InkeJson.integer('x'), isNull);
      expect(InkeJson.integer(null), isNull);
      expect(InkeJson.integer(true), isNull);
    });

    test('count keeps what is not negative', () {
      expect(InkeJson.count(0), 0);
      expect(InkeJson.count('12'), 12);
      expect(InkeJson.count(-1), isNull);
      expect(InkeJson.count('-1'), isNull);
      expect(InkeJson.count(12.0), isNull);
      expect(InkeJson.count(null), isNull);
    });

    test('rows caps the list and skips a row it cannot read', () {
      expect(
        InkeJson.rows([
          {'a': 1},
          {'b': 2},
        ], 'list'),
        [
          {'a': 1},
          {'b': 2},
        ],
      );
      // A bad entry is lost, not a failure.
      expect(
        InkeJson.rows([
          {'a': 1},
          'oops',
          null,
          42,
          <String, dynamic>{'b': 2},
        ], 'list').length,
        2,
      );
      expect(InkeJson.rows([], 'list'), isEmpty);
      // The cap is on the list as it came, before the skips.
      expect(
        () => InkeJson.rows(['a', 'b', 'c'], 'list', max: 2),
        _fails(InkeFailureKind.apiChanged, 'list: expected a list of rows'),
      );
      expect(
        InkeJson.rows(
          [
            'a',
            {'b': 1},
          ],
          'list',
          max: 2,
        ).length,
        1,
      );
      // A map of other keys is not a row either.
      expect(
        InkeJson.rows([
          <int, Object?>{1: 2},
        ], 'list'),
        isEmpty,
      );
      expect(() => InkeJson.rows('oops', 'list'), _fails(InkeFailureKind.apiChanged, 'list: expected a list of rows'));
      expect(() => InkeJson.rows(null, 'list'), _fails(InkeFailureKind.apiChanged, 'list: expected a list of rows'));
      expect(InkeJson.rows(List.generate(1000, (index) => {'i': index}), 'list').length, 1000);
      expect(
        () => InkeJson.rows(List.generate(1001, (index) => {'i': index}), 'list'),
        _fails(InkeFailureKind.apiChanged),
      );
    });

    test('an id is 1 to 18 digits without a leading zero, in either spelling', () {
      expect(InkeJson.idOrNull('12345'), '12345');
      expect(InkeJson.idOrNull(12345), '12345');
      expect(InkeJson.idOrNull(' 12345 '), '12345');
      expect(InkeJson.idOrNull('1' * 18), '1' * 18);
      expect(InkeJson.idOrNull('1' * 19), isNull);
      // An `int` answer cannot reach 18 digits without losing exactness in
      // JavaScript, so the largest one worth writing is 9007199254740991.
      expect(InkeJson.idOrNull(9007199254740991), '9007199254740991');
      expect(InkeJson.idOrNull('0'), isNull);
      expect(InkeJson.idOrNull('012345'), isNull);
      expect(InkeJson.idOrNull('12345.0'), isNull);
      expect(InkeJson.idOrNull(12345.0), isNull);
      expect(InkeJson.idOrNull(null), isNull);
      expect(InkeJson.idOrNull(''), isNull);
      expect(InkeJson.idOf('12345', 'room'), '12345');
      expect(() => InkeJson.idOf('0', 'room'), _fails(InkeFailureKind.apiChanged, 'room: 0'));
      expect(() => InkeJson.idOf(null, 'room'), _fails(InkeFailureKind.apiChanged, 'room: null'));
    });

    test('a start is Unix seconds inside 2000 to 2100, both bounds kept', () {
      expect(InkeJson.startedAt(946684800)!.millisecondsSinceEpoch, 946684800000);
      expect(InkeJson.startedAt(4102444800)!.millisecondsSinceEpoch, 4102444800000);
      // The window is closed at both ends, unlike another platform's.
      expect(InkeJson.startedAt(946684799), isNull);
      expect(InkeJson.startedAt(4102444801), isNull);
      expect(InkeJson.startedAt(1760000000)!.isUtc, isTrue);
      expect(InkeJson.startedAt('1760000000')!.millisecondsSinceEpoch, 1760000000000);
      expect(InkeJson.startedAt(0), isNull);
      expect(InkeJson.startedAt(-1), isNull);
      // Milliseconds never read as a start.
      expect(InkeJson.startedAt(1760000000000), isNull);
      expect(InkeJson.startedAt(1760000000.0), isNull);
      expect(InkeJson.startedAt(null), isNull);
    });

    test('picture is the shared normalizer, which does not upgrade http', () {
      expect(InkeJson.picture('//img.test/a.png'), 'https://img.test/a.png');
      expect(InkeJson.picture('https://img.test/a.png'), 'https://img.test/a.png');
      // The shared reader leaves an http address as it was written.
      expect(InkeJson.picture('http://img.test/a.png'), 'http://img.test/a.png');
      expect(InkeJson.picture('"https://img.test/a.png"'), 'https://img.test/a.png');
      expect(InkeJson.picture('img.test/a.png'), 'https://img.test/a.png');
      expect(InkeJson.picture(null), '');
      expect(InkeJson.picture('null'), '');
      expect(InkeJson.picture(''), '');
      expect(InkeJson.picture('/a.png'), '');
      expect(InkeJson.picture(30), '');
    });
  });
}
