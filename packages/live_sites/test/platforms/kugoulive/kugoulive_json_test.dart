import 'dart:convert';

import 'package:live_sites/src/platforms/kugoulive/parsers/kugoulive_failure.dart';
import 'package:live_sites/src/platforms/kugoulive/parsers/kugoulive_json.dart';
import 'package:test/test.dart';

/// A call that throws the failure [kind], and that message when the test names
/// one.
Matcher _fails(KugouliveFailureKind kind, [Object? message = anything]) => throwsA(
  isA<KugouliveFailure>()
      .having((error) => error.kind, 'kind', kind)
      .having((error) => error.message, 'message', message),
);

/// The session id Kugou writes for a broadcast of [seconds] owned by [owner].
String _session(int owner, {int seconds = 1760000000}) =>
    '${seconds.toRadixString(16).padLeft(8, '0')}h${owner.toRadixString(16)}';

DateTime _at(int seconds) => DateTime.fromMillisecondsSinceEpoch(seconds * 1000, isUtc: true);

void main() {
  group('the status and the answer', () {
    test('statusError names the status and stays silent for 2xx', () {
      for (final status in [200, 201, 204, 299]) {
        expect(KugouliveJson.statusError(status, 'hot'), isNull, reason: '$status');
      }
      expect(KugouliveJson.statusError(400, 'hot')?.kind, KugouliveFailureKind.apiChanged);
      expect(KugouliveJson.statusError(422, 'hot')?.kind, KugouliveFailureKind.apiChanged);
      expect(KugouliveJson.statusError(401, 'hot')?.kind, KugouliveFailureKind.riskControl);
      final refused = KugouliveJson.statusError(403, 'room');
      expect(refused?.kind, KugouliveFailureKind.riskControl);
      expect(refused?.message, 'room: HTTP 403');
      // The blocked answer is its own kind here, whatever the boundary makes it.
      expect(KugouliveJson.statusError(451, 'room')?.kind, KugouliveFailureKind.regionBlocked);
      expect(KugouliveJson.statusError(451, 'room')?.message, 'room: HTTP 451');
      expect(KugouliveJson.statusError(404, 'room')?.kind, KugouliveFailureKind.notFound);
      expect(KugouliveJson.statusError(410, 'room')?.kind, KugouliveFailureKind.notFound);
      expect(KugouliveJson.statusError(429, 'room')?.kind, KugouliveFailureKind.rateLimited);
      // A redirect, a teapot and every 5xx say the service did not answer.
      expect(KugouliveJson.statusError(302, 'room')?.kind, KugouliveFailureKind.network);
      expect(KugouliveJson.statusError(418, 'room')?.kind, KugouliveFailureKind.network);
      final broke = KugouliveJson.statusError(503, 'room');
      expect(broke?.kind, KugouliveFailureKind.network);
      expect(broke?.message, 'room: HTTP 503');
    });

    test('decode asks the status first and the size in characters', () {
      expect(KugouliveJson.decode('{"code":0}', what: 'hot', status: 200), {'code': 0});
      // A top level that is not an object still decodes: the caller decides.
      expect(KugouliveJson.decode('[1,2]', what: 'hot', status: 200), [1, 2]);
      expect(KugouliveJson.decode('"text"', what: 'hot', status: 200), 'text');
      expect(() => KugouliveJson.decode('{"code":0}', what: 'hot', status: 404), _fails(KugouliveFailureKind.notFound));
      expect(
        () => KugouliveJson.decode('sorry', what: 'hot', status: 200),
        _fails(KugouliveFailureKind.apiChanged, 'hot: not JSON'),
      );
      // An empty body is not JSON either; the limit counts UTF-16 units.
      expect(
        () => KugouliveJson.decode('', what: 'room', status: 200),
        _fails(KugouliveFailureKind.apiChanged, 'room: not JSON'),
      );
      expect(
        () => KugouliveJson.decode('x' * (4 * 1024 * 1024 + 1), what: 'room', status: 200),
        _fails(KugouliveFailureKind.apiChanged, 'room: answer over the size limit'),
      );
      // The limit is exclusive: exactly 4 MiB is still read, and a body of it
      // that is not JSON fails as JSON, not as size.
      final exact = '{"a":"${'x' * (4 * 1024 * 1024 - 8)}"}';
      expect(exact.length, 4 * 1024 * 1024);
      expect(KugouliveJson.decode(exact, what: 'room', status: 200), isNotNull);
      expect(
        () => KugouliveJson.decode('x' * (4 * 1024 * 1024), what: 'room', status: 200),
        _fails(KugouliveFailureKind.apiChanged, 'room: not JSON'),
      );
    });

    test('map re-keys and list stays lenient', () {
      expect(KugouliveJson.map({'a': 1}), {'a': 1});
      // Any map is a map: keys that are not text become their text.
      expect(KugouliveJson.map(<int, Object?>{1: 2}), {'1': 2});
      expect(KugouliveJson.map(jsonDecode('{"1":2}')), {'1': 2});
      expect(KugouliveJson.map([1, 2]), isNull);
      expect(KugouliveJson.map('a'), isNull);
      expect(KugouliveJson.map(null), isNull);
      expect(KugouliveJson.list([1, 'a']), [1, 'a']);
      expect(KugouliveJson.list(null), isEmpty);
      expect(KugouliveJson.list('a'), isEmpty);
      expect(KugouliveJson.list(42), isEmpty);
    });

    test('answer wants code 0 and a data that is not empty', () {
      final envelope = KugouliveJson.answer('{"code":0,"data":{"a":1}}', what: 'hot', status: 200);
      expect(envelope.root, {
        'code': 0,
        'data': {'a': 1},
      });
      expect(envelope.data, {'a': 1});
      // The code arrives as the text too, and `msg` is only wanted in a failure.
      expect(
        KugouliveJson.answerOf({
          'code': '0',
          'data': {'a': 1},
        }, what: 'hot').data,
        {'a': 1},
      );
      expect(
        () => KugouliveJson.answer('{"code":2,"msg":"bad"}', what: 'hot', status: 200),
        _fails(KugouliveFailureKind.apiChanged, 'hot: code 2 bad'),
      );
      // A missing code, a null root and an unparsable code are all "not 0".
      expect(
        () => KugouliveJson.answerOf({}, what: 'room'),
        _fails(KugouliveFailureKind.apiChanged, 'room: code null'),
      );
      expect(
        () => KugouliveJson.answerOf(null, what: 'room'),
        _fails(KugouliveFailureKind.apiChanged, 'room: code null'),
      );
      expect(
        () => KugouliveJson.answerOf({
          'code': 'x',
          'data': {'a': 1},
        }, what: 'room'),
        _fails(KugouliveFailureKind.apiChanged, 'room: code null'),
      );
      // `data` must be there, be an object, and have something in it.
      for (final data in [null, const <Object?, Object?>{}, <Object?>[], 'text', 0]) {
        expect(
          () => KugouliveJson.answerOf({'code': 0, 'data': data}, what: 'room'),
          _fails(KugouliveFailureKind.apiChanged, 'room: no data'),
          reason: '$data',
        );
      }
    });
  });

  group('the readers', () {
    test('integer wants a whole number, in text or not', () {
      expect(KugouliveJson.integer(30), 30);
      expect(KugouliveJson.integer(30.0), 30);
      expect(KugouliveJson.integer(30.5), isNull);
      expect(KugouliveJson.integer(double.infinity), isNull);
      expect(KugouliveJson.integer(' 30 '), 30);
      expect(KugouliveJson.integer('30.0'), isNull);
      expect(KugouliveJson.integer('-1'), -1);
      expect(KugouliveJson.integer(true), isNull);
      expect(KugouliveJson.integer(null), isNull);
    });

    test('count keeps only the non-negative whole numbers', () {
      expect(KugouliveJson.count(0), 0);
      expect(KugouliveJson.count('5'), 5);
      expect(KugouliveJson.count(5.0), 5);
      expect(KugouliveJson.count(-1), isNull);
      expect(KugouliveJson.count('-1'), isNull);
      expect(KugouliveJson.count(5.5), isNull);
      expect(KugouliveJson.count(null), isNull);
    });

    test('text reads any value and refuses the word null', () {
      expect(KugouliveJson.text(' a b '), 'a b');
      expect(KugouliveJson.text('null'), '');
      expect(KugouliveJson.text(null), '');
      expect(KugouliveJson.text(30), '30');
      // Anything else is its Dart text — a list included.
      expect(KugouliveJson.text([1, 2]), '[1, 2]');
      expect(KugouliveJson.text(true), 'true');
    });

    test('firstText takes the first value with something in it', () {
      expect(KugouliveJson.firstText([null, '', '  ', 'null', '乙', '甲']), '乙');
      expect(KugouliveJson.firstText([30, '甲']), '30');
      expect(KugouliveJson.firstText([]), '');
      expect(KugouliveJson.firstText([null, '', 'null']), '');
    });
  });

  group('the clock', () {
    test('plausible keeps 2000 to 2099 and nothing after the answer', () {
      expect(KugouliveJson.plausible(DateTime.utc(2026, 5, 5), null), isNotNull);
      expect(KugouliveJson.plausible(DateTime.utc(2000), null), DateTime.utc(2000));
      expect(KugouliveJson.plausible(DateTime.utc(1999, 12, 31, 23, 59, 59), null), isNull);
      // The window is half open: 2100 itself is out.
      expect(KugouliveJson.plausible(DateTime.utc(2100), null), isNull);
      expect(KugouliveJson.plausible(DateTime.utc(2099, 12, 31, 23, 59, 59), null), isNotNull);
      final answered = DateTime.utc(2026, 5, 5, 12);
      expect(KugouliveJson.plausible(answered, answered), isNotNull);
      // Five minutes of clock skew are allowed, to the second.
      expect(KugouliveJson.plausible(answered.add(const Duration(minutes: 5)), answered), isNotNull);
      expect(KugouliveJson.plausible(answered.add(const Duration(minutes: 5, seconds: 1)), answered), isNull);
      // Without the answer's own time nothing is ever in the future.
      expect(KugouliveJson.plausible(DateTime.utc(2099), null), isNotNull);
    });

    test('answeredAt reads `times` before `time`, seconds or milliseconds', () {
      expect(KugouliveJson.answeredAt({'times': 1760000000}), _at(1760000000));
      expect(KugouliveJson.answeredAt({'times': 1760000000000}), _at(1760000000));
      expect(KugouliveJson.answeredAt({'time': 1760000000}), _at(1760000000));
      // `times` wins when the root writes both.
      expect(KugouliveJson.answeredAt({'times': 1760000000, 'time': 1000000000}), _at(1760000000));
      expect(KugouliveJson.answeredAt({'times': '1760000000'}), _at(1760000000));
      expect(KugouliveJson.answeredAt({}), isNull);
      expect(KugouliveJson.answeredAt({'times': 0}), isNull);
      expect(KugouliveJson.answeredAt({'times': -1}), isNull);
      expect(KugouliveJson.answeredAt({'times': 'x'}), isNull);
      // Below 1e11 the number counts as seconds, at or above it as
      // milliseconds — and both edges can land out of the window.
      expect(KugouliveJson.answeredAt({'times': 1000000000}), _at(1000000000));
      expect(KugouliveJson.answeredAt({'times': 1000000000000}), _at(1000000000));
      expect(KugouliveJson.answeredAt({'times': 100000000000}), isNull);
      expect(KugouliveJson.answeredAt({'times': 99999999999}), isNull);
    });

    test('sessionStart takes the eight hex digits, and the owner after h', () {
      final session = _session(12345);
      expect(KugouliveJson.sessionStart(session), _at(1760000000));
      // The hex digits may be written either way, but the `h` between them is
      // the site's own literal: an `H` is no session at all.
      final upperHex = '${1760000000.toRadixString(16).toUpperCase()}h${12345.toRadixString(16).toUpperCase()}';
      expect(KugouliveJson.sessionStart(upperHex), _at(1760000000));
      expect(KugouliveJson.sessionStart(session.toUpperCase()), isNull);
      expect(KugouliveJson.sessionStart('  $session  '), _at(1760000000));
      // The owner is the hex text of the id, and 0 means it was not given.
      expect(KugouliveJson.sessionStart(session, ownerId: 12345), isNotNull);
      expect(KugouliveJson.sessionStart(session, ownerId: '12345'), isNotNull);
      expect(KugouliveJson.sessionStart(session, ownerId: 0), isNotNull);
      expect(KugouliveJson.sessionStart(session, ownerId: 999), isNull);
      // The start is exactly eight hex digits, and it must name a plausible
      // moment: 1978 written in hex is a session the site would not answer.
      expect(KugouliveJson.sessionStart('f000000h1'), isNull);
      expect(KugouliveJson.sessionStart(_session(1, seconds: 251658240)), isNull);
      expect(KugouliveJson.sessionStart('${'0' * 8}h1'), isNull);
      expect(KugouliveJson.sessionStart('${1760000000.toRadixString(16)}h'), isNull);
      expect(KugouliveJson.sessionStart('${1760000000.toRadixString(16)}h1h2'), isNull);
      expect(KugouliveJson.sessionStart(''), isNull);
      expect(KugouliveJson.sessionStart(null), isNull);
      // A session written in the future (past the skew) is no start.
      final answered = DateTime.utc(2026, 5, 5, 12);
      expect(
        KugouliveJson.sessionStart(
          _session(7, seconds: answered.millisecondsSinceEpoch ~/ 1000 + 120),
          answered: answered,
        ),
        isNotNull,
      );
      expect(
        KugouliveJson.sessionStart(
          _session(7, seconds: answered.millisecondsSinceEpoch ~/ 1000 + 3600),
          answered: answered,
        ),
        isNull,
      );
    });

    test('unixStart and listStart end where plausible says', () {
      expect(KugouliveJson.unixStart(1760000000, null), _at(1760000000));
      expect(KugouliveJson.unixStart('1760000000', null), _at(1760000000));
      expect(KugouliveJson.unixStart(0, null), isNull);
      expect(KugouliveJson.unixStart(-5, null), isNull);
      expect(KugouliveJson.unixStart(1760000000.5, null), isNull);
      final answered = DateTime.utc(2026, 5, 5, 12);
      expect(KugouliveJson.listStart(3600, answered), answered.subtract(const Duration(hours: 1)));
      // A broadcast of no length started when the answer was written.
      expect(KugouliveJson.listStart(0, answered), answered);
      expect(KugouliveJson.listStart('3600', answered), answered.subtract(const Duration(hours: 1)));
      expect(KugouliveJson.listStart(-1, answered), isNull);
      expect(KugouliveJson.listStart(3600, null), isNull);
      expect(KugouliveJson.listStart(null, answered), isNull);
      // Ten years of live time reaches under the year 2000 and is no start.
      expect(KugouliveJson.listStart(900000000, answered), isNull);
    });
  });

  group('the image addresses', () {
    test('the host test is on the root or a subdomain of it', () {
      expect(kugouliveImageRoots, {'kgimg.com', 'kugou.com'});
      for (final host in ['kgimg.com', 'KGIMG.COM', 'p3.fx.kgimg.com', 'kugou.com', 'a.b.kugou.com']) {
        expect(kugouliveHostIs(host, 'kgimg.com') || kugouliveHostIs(host, 'kugou.com'), isTrue, reason: host);
      }
      // A suffix that only shares the text is not the root.
      expect(kugouliveHostIs('kgimg.com.evil.test', 'kgimg.com'), isFalse);
      expect(kugouliveHostIs('xkgimg.com', 'kgimg.com'), isFalse);
      expect(kugouliveHostIs('', 'kgimg.com'), isFalse);
    });

    test('an image is folded, made absolute and put on https', () {
      expect(KugouliveJson.image('https://p3.fx.kgimg.com/a.jpg'), 'https://p3.fx.kgimg.com/a.jpg');
      expect(KugouliveJson.image('//fs.kgimg.com/a.jpg'), 'https://fs.kgimg.com/a.jpg');
      expect(KugouliveJson.image('/a.jpg'), 'https://p3.fx.kgimg.com/a.jpg');
      expect(KugouliveJson.image('http://p3.fx.kgimg.com/a.jpg'), 'https://p3.fx.kgimg.com/a.jpg');
      // The doubled prefix the site sometimes writes is folded once.
      expect(
        KugouliveJson.image('https://p3.fx.kgimg.com/v2/fxuserlogo//v2/fxuserlogo/a.jpg'),
        'https://p3.fx.kgimg.com/v2/fxuserlogo/a.jpg',
      );
      expect(KugouliveJson.image('/v2/fxuserlogo//v2/fxuserlogo/a.jpg'), 'https://p3.fx.kgimg.com/v2/fxuserlogo/a.jpg');
      expect(
        KugouliveJson.image(
          'https://p3.fx.kgimg.com/v2/fxuserlogo//v2/fxuserlogo/x/v2/fxuserlogo//v2/fxuserlogo/a.jpg',
        ),
        'https://p3.fx.kgimg.com/v2/fxuserlogo/x/v2/fxuserlogo//v2/fxuserlogo/a.jpg',
      );
    });

    test('an image on another host, with user info or an odd port is none', () {
      expect(KugouliveJson.image('https://evil.test/a.jpg'), '');
      expect(KugouliveJson.image('https://kgimg.com.evil.test/a.jpg'), '');
      expect(KugouliveJson.image('https://me@p3.fx.kgimg.com/a.jpg'), '');
      expect(KugouliveJson.image('https://p3.fx.kgimg.com:8443/a.jpg'), '');
      // The default ports pass the gate; the rewrite drops port 80 with the
      // old scheme and leaves a written 443 as it came.
      expect(KugouliveJson.image('https://p3.fx.kgimg.com:443/a.jpg'), 'https://p3.fx.kgimg.com:443/a.jpg');
      expect(KugouliveJson.image('http://p3.fx.kgimg.com:80/a.jpg'), 'https://p3.fx.kgimg.com/a.jpg');
      expect(KugouliveJson.image('a.jpg'), '');
      expect(KugouliveJson.image(''), '');
      expect(KugouliveJson.image(null), '');
      expect(KugouliveJson.image('null'), '');
      expect(KugouliveJson.image(30), '');
    });
  });
}
