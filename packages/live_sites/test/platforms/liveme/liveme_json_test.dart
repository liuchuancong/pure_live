import 'dart:convert';

import 'package:live_sites/src/platforms/liveme/api/liveme_endpoints.dart';
import 'package:live_sites/src/platforms/liveme/parsers/liveme_failure.dart';
import 'package:live_sites/src/platforms/liveme/parsers/liveme_json.dart';
import 'package:test/test.dart';

/// A call that throws the failure [kind], and that message when the test names
/// one.
Matcher _fails(LivemeFailureKind kind, [Object? message = anything]) => throwsA(
  isA<LivemeFailure>()
      .having((failure) => failure.kind, 'kind', kind)
      .having((failure) => failure.message, 'message', message),
);

const int _limit = LivemeEndpoints.responseLimit;

/// An answer whose business `status` is [code], with a `msg` when named.
String _body(Object? code, {String? msg}) => jsonEncode({'status': code, 'msg': ?msg});

void main() {
  group('the status', () {
    test('checkStatus calls only 200 an answer', () {
      expect(() => LivemeJson.checkStatus(200, 'hot'), returnsNormally);
      // Every other status is a failure, 2xx included: the reference read no
      // body for anything but 200.
      expect(() => LivemeJson.checkStatus(204, 'hot'), _fails(LivemeFailureKind.network, 'hot: HTTP 204'));
      expect(() => LivemeJson.checkStatus(299, 'hot'), _fails(LivemeFailureKind.network, 'hot: HTTP 299'));
      expect(() => LivemeJson.checkStatus(400, 'hot'), _fails(LivemeFailureKind.apiChanged, 'hot: HTTP 400'));
      expect(() => LivemeJson.checkStatus(401, 'hot'), _fails(LivemeFailureKind.riskControl, 'hot: HTTP 401'));
      expect(() => LivemeJson.checkStatus(403, 'room'), _fails(LivemeFailureKind.riskControl, 'room: HTTP 403'));
      expect(() => LivemeJson.checkStatus(404, 'room'), _fails(LivemeFailureKind.notFound, 'room: HTTP 404'));
      // 420 is the site's own "calm down".
      expect(() => LivemeJson.checkStatus(420, 'room'), _fails(LivemeFailureKind.rateLimited, 'room: HTTP 420'));
      expect(() => LivemeJson.checkStatus(429, 'room'), _fails(LivemeFailureKind.rateLimited, 'room: HTTP 429'));
      expect(() => LivemeJson.checkStatus(302, 'room'), _fails(LivemeFailureKind.network, 'room: HTTP 302'));
      expect(() => LivemeJson.checkStatus(500, 'room'), _fails(LivemeFailureKind.network, 'room: HTTP 500'));
      expect(() => LivemeJson.checkStatus(199, 'room'), _fails(LivemeFailureKind.network, 'room: HTTP 199'));
    });

    test('envelope asks the status before it reads a byte', () {
      expect(LivemeJson.envelope(_body(200), 'hot', 200), {'status': 200});
      for (final (status, kind) in [
        (400, LivemeFailureKind.apiChanged),
        (404, LivemeFailureKind.notFound),
        (401, LivemeFailureKind.riskControl),
        (429, LivemeFailureKind.rateLimited),
        (503, LivemeFailureKind.network),
      ]) {
        expect(() => LivemeJson.envelope('sorry', 'hot', status), _fails(kind, 'hot: HTTP $status'), reason: '$status');
      }
    });

    test('envelope counts the answer in UTF-8 bytes', () {
      expect(
        () => LivemeJson.envelope('x' * (_limit + 1), 'hot', 200),
        _fails(LivemeFailureKind.apiChanged, 'hot: answer over $_limit bytes'),
      );
      expect(LivemeJson.envelope('{"status":200,"msg":"${'汉' * 2000000}"}', 'hot', 200)['status'], 200);
      // The estimate is only a gate for the real count: wide text past three
      // bytes per unit is encoded and refused, narrow text of that size passes.
      expect(
        () => LivemeJson.envelope('{"status":1,"m":"${'汉' * 2800000}"}', 'hot', 200),
        _fails(LivemeFailureKind.apiChanged, 'hot: answer over $_limit bytes'),
      );
      // The narrow text of that size passes the gate and is read as an answer.
      expect(
        () => LivemeJson.envelope('{"status":1,"m":"${'x' * 2900000}"}', 'hot', 200),
        _fails(LivemeFailureKind.apiChanged, 'hot: status 1 '),
      );
    });

    test('the business status is what the answer means', () {
      // The site sends it as text too, and only 200 is an answer.
      expect(LivemeJson.envelope(_body('200'), 'hot', 200)['status'], '200');
      expect(LivemeJson.envelope('{"status":200,"data":{"a":1}}', 'hot', 200)['data'], {'a': 1});
      // A float 200.0 is not an integer, so the answer has no status.
      expect(
        () => LivemeJson.envelope(_body(200.0), 'hot', 200),
        _fails(LivemeFailureKind.apiChanged, 'hot: no status'),
      );
      expect(() => LivemeJson.envelope('{}', 'hot', 200), _fails(LivemeFailureKind.apiChanged, 'hot: no status'));
      expect(
        () => LivemeJson.envelope('{"status":"x"}', 'hot', 200),
        _fails(LivemeFailureKind.apiChanged, 'hot: no status'),
      );
      expect(() => LivemeJson.envelope('sorry', 'hot', 200), _fails(LivemeFailureKind.apiChanged, 'hot: not JSON'));
      expect(
        () => LivemeJson.envelope('[1,2]', 'hot', 200),
        _fails(LivemeFailureKind.apiChanged, 'hot: expected an object'),
      );
      expect(() => LivemeJson.envelope('', 'hot', 200), _fails(LivemeFailureKind.apiChanged, 'hot: not JSON'));
    });

    test('the business code answers with its own kind and its msg', () {
      expect(() => LivemeJson.envelope(_body(400), 'room', 200), _fails(LivemeFailureKind.notFound, 'room: 400 '));
      expect(
        () => LivemeJson.envelope(_body(404, msg: 'no such live'), 'room', 200),
        _fails(LivemeFailureKind.notFound, 'room: 404 no such live'),
      );
      expect(
        () => LivemeJson.envelope(_body('400', msg: 'bad'), 'room', 200),
        _fails(LivemeFailureKind.notFound, 'room: 400 bad'),
      );
      expect(
        () => LivemeJson.envelope(_body(403, msg: 'blocked'), 'room', 200),
        _fails(LivemeFailureKind.riskControl, 'room: 403 blocked'),
      );
      expect(
        () => LivemeJson.envelope(_body(429, msg: 'slow down'), 'room', 200),
        _fails(LivemeFailureKind.rateLimited, 'room: 429 slow down'),
      );
      // A `msg` that is not text is simply left out of the answer.
      expect(
        () => LivemeJson.envelope('{"status":400,"msg":7}', 'room', 200),
        _fails(LivemeFailureKind.notFound, 'room: 400 '),
      );
    });

    test('a five hundred about a user is the site saying nobody is there', () {
      expect(
        () => LivemeJson.envelope(_body(500, msg: 'user not exist'), 'room', 200),
        _fails(LivemeFailureKind.notFound, 'room: user not exist'),
      );
      // The phrase is read as written, and the code drops out of that message.
      expect(
        () => LivemeJson.envelope(_body(500, msg: 'User Not Exist'), 'room', 200),
        _fails(LivemeFailureKind.network, 'room: 500 User Not Exist'),
      );
      expect(
        () => LivemeJson.envelope(_body(500, msg: 'boom'), 'room', 200),
        _fails(LivemeFailureKind.network, 'room: 500 boom'),
      );
      expect(
        () => LivemeJson.envelope(_body(503, msg: 'user not exist'), 'room', 200),
        _fails(LivemeFailureKind.network, 'room: 503 user not exist'),
      );
      // A code below five hundred that no arm names is a shape changed.
      expect(
        () => LivemeJson.envelope(_body(1, msg: 'x'), 'room', 200),
        _fails(LivemeFailureKind.apiChanged, 'room: status 1 x'),
      );
      expect(
        () => LivemeJson.envelope(_body(302), 'room', 200),
        _fails(LivemeFailureKind.apiChanged, 'room: status 302 '),
      );
    });
  });

  group('the readers', () {
    test('object re-keys and list caps without truncating', () {
      final typed = <String, dynamic>{'a': 1};
      expect(identical(LivemeJson.object(typed, 'card'), typed), isTrue);
      expect(LivemeJson.object(<int, Object?>{1: 2}, 'card'), {'1': 2});
      expect(() => LivemeJson.object([1], 'card'), _fails(LivemeFailureKind.apiChanged, 'card: expected an object'));
      expect(() => LivemeJson.object(null, 'card'), _fails(LivemeFailureKind.apiChanged, 'card: expected an object'));
      expect(LivemeJson.list([1, 'a'], 'rows', max: 2), [1, 'a']);
      expect(LivemeJson.list([], 'rows', max: 0), isEmpty);
      expect(
        () => LivemeJson.list([1, 2, 3], 'rows', max: 2),
        _fails(LivemeFailureKind.apiChanged, 'rows: expected a list of at most 2'),
      );
      expect(
        () => LivemeJson.list('abc', 'rows', max: 2),
        _fails(LivemeFailureKind.apiChanged, 'rows: expected a list of at most 2'),
      );
      // The list that passes is the one the answer carried.
      final rows = <Object?>[1];
      expect(identical(LivemeJson.list(rows, 'rows', max: 2), rows), isTrue);
    });

    test('integer reads a number or its text, never a float', () {
      expect(LivemeJson.integer(30), 30);
      expect(LivemeJson.integer('30'), 30);
      expect(LivemeJson.integer(' 30 '), 30);
      expect(LivemeJson.integer('-4'), -4);
      expect(LivemeJson.integer(30.0), isNull);
      expect(LivemeJson.integer('30.0'), isNull);
      expect(LivemeJson.integer(''), isNull);
      expect(LivemeJson.integer(null), isNull);
      expect(LivemeJson.integer(true), isNull);
      // No separator handling here either.
      expect(LivemeJson.integer('1,234'), isNull);
    });

    test('count allows the field to be absent and nothing else', () {
      expect(LivemeJson.count(null, 'online'), isNull);
      expect(LivemeJson.count('', 'online'), isNull);
      expect(LivemeJson.count(0, 'online'), 0);
      expect(LivemeJson.count('12', 'online'), 12);
      // Unlike sixroom, a float or a separator text is a failure, not a guess.
      expect(() => LivemeJson.count(30.5, 'online'), _fails(LivemeFailureKind.apiChanged, 'online: 30.5'));
      expect(() => LivemeJson.count('1,234', 'online'), _fails(LivemeFailureKind.apiChanged, 'online: 1,234'));
      expect(() => LivemeJson.count(-1, 'online'), _fails(LivemeFailureKind.apiChanged, 'online: -1'));
      expect(() => LivemeJson.count('x', 'online'), _fails(LivemeFailureKind.apiChanged, 'online: x'));
    });

    test('text takes a trimmed string and allows a blank', () {
      expect(LivemeJson.text(' a b ', 'title'), 'a b');
      expect(LivemeJson.text('  ', 'title'), '');
      expect(LivemeJson.text(null, 'title'), '');
      expect(LivemeJson.text('x' * 131072, 'title').length, 131072);
      expect(() => LivemeJson.text('x' * 131073, 'title'), _fails(LivemeFailureKind.apiChanged, 'title: not text'));
      expect(() => LivemeJson.text(30, 'title'), _fails(LivemeFailureKind.apiChanged, 'title: not text'));
      expect(() => LivemeJson.text([1], 'title'), _fails(LivemeFailureKind.apiChanged, 'title: not text'));
    });

    test('firstText fails when nothing in the list has text', () {
      expect(LivemeJson.firstText(['  ', '甲', '乙'], 'title'), '甲');
      expect(LivemeJson.firstText([null, '', '  乙  '], 'title'), '乙');
      expect(
        () => LivemeJson.firstText([null, '', '  '], 'title'),
        _fails(LivemeFailureKind.apiChanged, 'title: missing'),
      );
      expect(() => LivemeJson.firstText([], 'title'), _fails(LivemeFailureKind.apiChanged, 'title: missing'));
      // Each candidate is read as text, so a number is the answer's shape
      // changed rather than something to skip.
      expect(() => LivemeJson.firstText([30, '甲'], 'title'), _fails(LivemeFailureKind.apiChanged, 'title: not text'));
    });

    test('shortId is 5 to 12 digits and longId 13 to 24, neither with a leading zero', () {
      expect(LivemeJson.shortId('12345', 'room'), '12345');
      expect(LivemeJson.shortId(' 12345 ', 'room'), '12345');
      expect(LivemeJson.shortId(123456789012, 'room'), '123456789012');
      expect(() => LivemeJson.shortId('1234', 'room'), _fails(LivemeFailureKind.apiChanged, 'room: 1234'));
      expect(() => LivemeJson.shortId('012345', 'room'), _fails(LivemeFailureKind.apiChanged, 'room: 012345'));
      expect(LivemeEndpoints.isShortId('123456789012'), isTrue);
      expect(() => LivemeJson.shortId('x', 'room'), _fails(LivemeFailureKind.apiChanged, 'room: x'));
      expect(() => LivemeJson.shortId(null, 'room'), _fails(LivemeFailureKind.apiChanged, 'room: null'));
      expect(LivemeJson.longId('1' * 13, 'user').length, 13);
      expect(LivemeJson.longId('1' * 24, 'user').length, 24);
      expect(LivemeJson.longId('1234567890123', 'user'), '1234567890123');
      final tooLong = '1' * 25;
      final tooShort = '1' * 12;
      expect(() => LivemeJson.longId(tooLong, 'user'), _fails(LivemeFailureKind.apiChanged, 'user: $tooLong'));
      expect(() => LivemeJson.longId(tooShort, 'user'), _fails(LivemeFailureKind.apiChanged, 'user: $tooShort'));
      expect(
        () => LivemeJson.longId('0123456789012', 'user'),
        _fails(LivemeFailureKind.apiChanged, 'user: 0123456789012'),
      );
      // A long id is not a room id and the other way around.
      expect(() => LivemeJson.shortId('1' * 13, 'room'), _fails(LivemeFailureKind.apiChanged, 'room: ${'1' * 13}'));
      expect(() => LivemeJson.longId('12345', 'user'), _fails(LivemeFailureKind.apiChanged, 'user: 12345'));
    });

    test('countryCode names itself in the failure, not the caller', () {
      expect(LivemeJson.countryCode('cn'), 'CN');
      expect(LivemeJson.countryCode('  Ch '), 'CH');
      expect(LivemeJson.countryCode(null), '');
      expect(LivemeJson.countryCode('CHN'), '');
      expect(LivemeJson.countryCode('C1'), '');
      expect(LivemeJson.countryCode(''), '');
      // The reader is called with its own field name, whatever the caller wants.
      expect(() => LivemeJson.countryCode(30), _fails(LivemeFailureKind.apiChanged, 'countryCode: not text'));
    });
  });
}
