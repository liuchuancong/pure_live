import 'package:live_sites/src/platforms/tiktok/api/tiktok_endpoints.dart';
import 'package:live_sites/src/platforms/tiktok/parsers/tiktok_failure.dart';
import 'package:live_sites/src/platforms/tiktok/parsers/tiktok_json.dart';
import 'package:test/test.dart';

/// A trusted media host of the platform.
const String _cdn = 'https://v16-webapp.tiktokcdn.com/live/a.flv';

Object? _kindOf(void Function() read) {
  try {
    read();
    return null;
  } on TiktokFailure catch (failure) {
    return failure.kind;
  }
}

TiktokFailure _failure(void Function() read) {
  try {
    read();
  } on TiktokFailure catch (failure) {
    return failure;
  }
  throw StateError('the answer was accepted');
}

void main() {
  group('the answer gates', () {
    test('the status table', () {
      expect(
        {
          for (final status in [200, 201, 204, 302, 400, 401, 403, 404, 420, 429, 500])
            status: _kindOf(() => TiktokJson.checkStatus(status, 'x')),
        },
        {
          200: null,
          201: TiktokFailureKind.network,
          204: TiktokFailureKind.network,
          302: TiktokFailureKind.network,
          400: TiktokFailureKind.apiChanged,
          401: TiktokFailureKind.riskControl,
          403: TiktokFailureKind.riskControl,
          404: TiktokFailureKind.notFound,
          420: TiktokFailureKind.rateLimited,
          429: TiktokFailureKind.rateLimited,
          500: TiktokFailureKind.network,
        },
        reason: '420 is TikTok\'s own "enhance your calm", beside 429',
      );
      expect(_failure(() => TiktokJson.checkStatus(201, 'room')).message, 'room: HTTP 201');
      expect(_failure(() => TiktokJson.checkStatus(400, 'room')).message, 'room: HTTP 400');
    });

    test('twelve mebibytes, counted in UTF-8 bytes', () {
      const limit = TiktokEndpoints.responseLimit;
      expect(_failure(() => TiktokJson.checkBody('x' * (limit + 1), 'x', 200)).message, 'x: answer over $limit bytes');
      expect(() => TiktokJson.checkBody('{"a":1}', 'x', 200), returnsNormally);
      expect(
        _kindOf(() => TiktokJson.checkBody('漢' * (limit ~/ 3 + 1), 'x', 200)),
        TiktokFailureKind.apiChanged,
        reason: 'the character count is under the cap but the bytes are over it',
      );
      expect(
        _kindOf(() => TiktokJson.checkBody('漢' * (limit ~/ 4), 'x', 200)),
        isNull,
        reason: 'the cheap check skips encoding while the count cannot reach the cap',
      );
      expect(_kindOf(() => TiktokJson.checkBody('{}', 'x', 404)), TiktokFailureKind.notFound, reason: 'status first');
    });

    test('the envelope: an empty 200 is the anonymous refusal', () {
      expect(TiktokJson.envelope('{"code":0}', status: 200, what: 'room'), {'code': 0});
      expect(_failure(() => TiktokJson.envelope('', status: 200, what: 'room')).message, 'room: empty answer');
      expect(_kindOf(() => TiktokJson.envelope('', status: 200, what: 'room')), TiktokFailureKind.riskControl);
      expect(_failure(() => TiktokJson.envelope('nope', status: 200, what: 'room')).message, 'room: not JSON');
      expect(_failure(() => TiktokJson.envelope('[1]', status: 200, what: 'room')).message, 'room: expected an object');
      expect(
        _failure(() => TiktokJson.envelope('null', status: 200, what: 'room')).message,
        'room: expected an object',
      );
    });

    test('object, lenientObject and decode', () {
      expect(TiktokJson.object(const <String, Object?>{'a': 1}, 'x'), {'a': 1});
      expect(TiktokJson.object(const <int, String>{1: 'a'}, 'x'), {'1': 'a'});
      expect(_kindOf(() => TiktokJson.object('text', 'x')), TiktokFailureKind.apiChanged);
      expect(TiktokJson.lenientObject({'a': 1}), {'a': 1});
      expect(TiktokJson.lenientObject('text'), isEmpty, reason: 'a broken stats block only loses itself');
      expect(TiktokJson.lenientObject(null), isEmpty);
      expect(TiktokJson.decode('{"a":1}', 'x'), {'a': 1});
      expect(_kindOf(() => TiktokJson.decode('{', 'x')), TiktokFailureKind.apiChanged);
    });
  });

  group('the numbers', () {
    test('integer: an int, an integral number, or text without spaces', () {
      expect(TiktokJson.integer(7), 7);
      expect(TiktokJson.integer(7.0), 7);
      expect(TiktokJson.integer(7.5), isNull, reason: 'a fraction is not a count here');
      expect(TiktokJson.integer('7'), 7);
      expect(TiktokJson.integer(' 7 '), 7, reason: 'int.tryParse tolerates surrounding spaces');
      expect(TiktokJson.integer(null), isNull);
      expect(TiktokJson.integer(true), isNull);
      expect(TiktokJson.integer(double.infinity), isNull);
    });

    test('lenientCount: a negative figure is nothing', () {
      expect(TiktokJson.lenientCount(0), 0);
      expect(TiktokJson.lenientCount('12'), 12);
      expect(TiktokJson.lenientCount(-1), isNull, reason: 'the site once answered -1 for an empty room');
      expect(TiktokJson.lenientCount(null), isNull);
      expect(TiktokJson.lenientCount('x'), isNull);
    });

    test('optionalBool: only a real bool or nothing', () {
      expect(TiktokJson.optionalBool(null, 'status'), isNull);
      expect(TiktokJson.optionalBool(true, 'status'), isTrue);
      expect(TiktokJson.optionalBool(false, 'status'), isFalse);
      expect(_failure(() => TiktokJson.optionalBool('true', 'status')).message, 'status: true');
      expect(_kindOf(() => TiktokJson.optionalBool(1, 'status')), TiktokFailureKind.apiChanged);
    });

    test('startTime: Unix seconds inside 2000–2100', () {
      expect(TiktokJson.startTime(1730000000), DateTime.fromMillisecondsSinceEpoch(1730000000 * 1000, isUtc: true));
      expect(TiktokJson.startTime('1730000000'), isNotNull);
      expect(TiktokJson.startTime(1730000000.0), isNotNull);
      expect(TiktokJson.startTime(0), isNull);
      expect(TiktokJson.startTime(null), isNull);
      expect(TiktokJson.startTime(946684799), isNull, reason: 'before 2000');
      expect(TiktokJson.startTime(4102444801), isNull, reason: 'past 2100');
      expect(TiktokJson.startTime(1730000000000), isNull, reason: 'milliseconds are not seconds');
    });
  });

  group('the identifiers', () {
    test('username: letters, digits, dot and underscore, not at either end', () {
      expect(TiktokJson.username(' A.B_c ', 'uniqueId'), 'a.b_c');
      expect(TiktokJson.username('a', 'uniqueId'), 'a');
      expect(TiktokJson.username('ab', 'uniqueId'), 'ab');
      expect(_failure(() => TiktokJson.username('.abc', 'uniqueId')).message, 'uniqueId: .abc is no username');
      expect(_kindOf(() => TiktokJson.username('abc.', 'uniqueId')), TiktokFailureKind.apiChanged);
      expect(_kindOf(() => TiktokJson.username('a' * 25, 'uniqueId')), TiktokFailureKind.apiChanged);
      expect(_kindOf(() => TiktokJson.username('a-b', 'uniqueId')), TiktokFailureKind.apiChanged);
      expect(_kindOf(() => TiktokJson.username('', 'uniqueId')), TiktokFailureKind.apiChanged);
      expect(_kindOf(() => TiktokJson.username(7, 'uniqueId')), TiktokFailureKind.apiChanged);
      expect(TiktokJson.username('a' * 24, 'uniqueId').length, 24);
    });

    test('longId: 15 to 25 digits, written as text', () {
      const id = '1234567890123456';
      expect(TiktokJson.longId(id, 'roomId'), id);
      expect(TiktokJson.longId(int.parse(id), 'roomId'), id);
      expect(TiktokJson.longId(' $id ', 'roomId'), id);
      expect(_failure(() => TiktokJson.longId('12345678901234', 'roomId')).message, 'roomId: 12345678901234');
      expect(_kindOf(() => TiktokJson.longId('0234567890123456', 'roomId')), TiktokFailureKind.apiChanged);
      expect(_kindOf(() => TiktokJson.longId(null, 'roomId')), TiktokFailureKind.apiChanged);
      expect(TiktokJson.lenientLongId(id), id);
      expect(TiktokJson.lenientLongId('short'), isEmpty);
      expect(TiktokJson.lenientLongId(null), isEmpty);
    });

    test('tier: a lower-case key of letters, digits and underscore', () {
      expect(TiktokJson.tier(' Origin_Quality ', 'quality'), 'origin_quality');
      expect(TiktokJson.tier('720p', 'quality'), '720p');
      expect(_failure(() => TiktokJson.tier('origin-q', 'quality')).message, 'quality: tier "origin-q"');
      expect(_kindOf(() => TiktokJson.tier('q' * 25, 'quality')), TiktokFailureKind.apiChanged);
    });

    test('codec: the four names the site writes, else nothing', () {
      expect(TiktokJson.codec('', 'h264', 'g0'), 'h264', reason: "an empty VCodec means the tier's own name");
      expect(TiktokJson.codec(null, 'h265', 'g0'), 'h265');
      expect(TiktokJson.codec('AVC', 'h265', 'g0'), 'h264');
      expect(TiktokJson.codec('h264', 'h265', 'g0'), 'h264');
      expect(TiktokJson.codec('ByteVC1', 'h264', 'g0'), 'h265');
      expect(_failure(() => TiktokJson.codec('av1', 'h264', 'g0')).message, 'g0: codec av1');
      expect(_failure(() => TiktokJson.codec(7, 'h264', 'g0')).message, 'g0.VCodec: expected a string');
    });
  });

  group('the text and the addresses', () {
    test('lenientText: 8 KiB of trimmed text or nothing', () {
      expect(TiktokJson.lenientText('  hi  '), 'hi');
      expect(TiktokJson.lenientText('x' * 8192), isNotEmpty);
      expect(TiktokJson.lenientText('x' * 8193), isEmpty);
      expect(TiktokJson.lenientText(7), isEmpty);
      expect(TiktokJson.lenientText(null), isEmpty);
    });

    test('optionalText: absent is empty, another type is a change', () {
      expect(TiktokJson.optionalText(null, 'nickname'), isEmpty);
      expect(TiktokJson.optionalText('', 'nickname'), isEmpty);
      expect(TiktokJson.optionalText(' hi ', 'nickname'), 'hi');
      expect(_failure(() => TiktokJson.optionalText(7, 'nickname')).message, 'nickname: expected a string');
      expect(
        _kindOf(() => TiktokJson.optionalText('x' * (4 * 1024 * 1024 + 1), 'nickname')),
        TiktokFailureKind.apiChanged,
      );
    });

    test('resolution: 720x1280 or 720p, and nothing else', () {
      expect(TiktokJson.resolution(' 720X1280 '), '720x1280');
      expect(TiktokJson.resolution('1080p'), '1080p');
      expect(TiktokJson.resolution('720P'), '720p');
      expect(TiktokJson.resolution('720000x1280'), isEmpty, reason: 'five digits is not a video edge');
      expect(TiktokJson.resolution('7x1280'), isEmpty);
      expect(TiktokJson.resolution('72p'), isEmpty, reason: 'a p-tier needs at least three digits');
      expect(TiktokJson.resolution('auto'), isEmpty);
      expect(TiktokJson.resolution(720), isEmpty);
      expect(TiktokJson.resolution(null), isEmpty);
    });

    test('mediaUrl: only a clean https address on a trusted host', () {
      expect(TiktokJson.mediaUrl(_cdn, 'url').host, 'v16-webapp.tiktokcdn.com');
      expect(TiktokJson.mediaUrl('https://tiktokv.com/x', 'url').host, 'tiktokv.com');
      for (final bad in [
        'http://v16-webapp.tiktokcdn.com/a.flv',
        'https://user@v16-webapp.tiktokcdn.com/a.flv',
        'https://v16-webapp.tiktokcdn.com/a.flv#t',
        'https://v16-webapp.tiktokcdn.com/a b.flv',
        'https://evil.test/a.flv',
        'https://tiktokcdn.com.evil.test/a.flv',
        'not a url',
        'x' * 65537,
      ]) {
        expect(_failure(() => TiktokJson.mediaUrl(bad, 'url')).message, 'url: not a TikTok media URL', reason: bad);
      }
    });

    test('image: the first trusted https candidate, made absolute', () {
      expect(TiktokJson.image([_cdn]), _cdn);
      expect(TiktokJson.image(['//p16.tiktokcdn.com/a.jpg']), 'https://p16.tiktokcdn.com/a.jpg');
      expect(TiktokJson.image(['https://evil.test/a.jpg', _cdn]), _cdn, reason: 'an untrusted address loses its place');
      expect(TiktokJson.image(['http://p16.tiktokcdn.com/a.jpg']), isEmpty, reason: 'http is never upgraded');
      expect(TiktokJson.image(['x' * 16385, _cdn]), _cdn, reason: 'an over-long candidate is not even parsed');
      expect(TiktokJson.image(const <Object?>[]), isEmpty);
      expect(TiktokJson.image([null, 7]), isEmpty);
    });
  });

  test("the answer limit the body gate reads is the endpoint's own", () {
    expect(TiktokEndpoints.responseLimit, 12 * 1024 * 1024);
    expect(TiktokEndpoints.missingUserCode, 19881007);
  });
}
