import 'package:live_sites/src/platforms/fc2live/api/fc2live_endpoints.dart';
import 'package:live_sites/src/platforms/fc2live/parsers/fc2live_failure.dart';
import 'package:live_sites/src/platforms/fc2live/parsers/fc2live_json.dart';
import 'package:test/test.dart';

Object? _kindOf(void Function() read) {
  try {
    read();
    return null;
  } on Fc2LiveFailure catch (failure) {
    return failure.kind;
  }
}

Fc2LiveFailure _failure(void Function() read) {
  try {
    read();
  } on Fc2LiveFailure catch (failure) {
    return failure;
  }
  throw StateError('the value was accepted');
}

/// A JSON object whose only field is [text].
String _padded(String text) => '{"a":"$text"}';

void main() {
  group('the answer gate', () {
    test('the status table', () {
      expect(
        {
          for (final status in [200, 201, 204, 302, 400, 401, 403, 404, 422, 429, 500])
            status: Fc2LiveJson.statusFailure(status, 'x')?.kind,
        },
        {
          200: null,
          201: Fc2LiveFailureKind.network,
          204: Fc2LiveFailureKind.network,
          302: Fc2LiveFailureKind.network,
          400: Fc2LiveFailureKind.apiChanged,
          401: Fc2LiveFailureKind.riskControl,
          403: Fc2LiveFailureKind.riskControl,
          404: Fc2LiveFailureKind.notFound,
          422: Fc2LiveFailureKind.apiChanged,
          429: Fc2LiveFailureKind.rateLimited,
          500: Fc2LiveFailureKind.network,
        },
        reason: 'these requests never follow a redirect, so a 3xx is the service not answering',
      );
      expect(Fc2LiveJson.statusFailure(418, 'x')?.message, 'x: HTTP 418');
    });
    test('an answer must be a JSON object, of a size the adapter will read', () {
      expect(Fc2LiveJson.object('{"a":1}', 'member'), {'a': 1});
      expect(_kindOf(() => Fc2LiveJson.object('{}', 'x', status: 404)), Fc2LiveFailureKind.notFound);
      expect(_failure(() => Fc2LiveJson.object('[]', 'x')).message, 'x: not an object');
      expect(_failure(() => Fc2LiveJson.object('"a string"', 'x')).message, 'x: not an object');
      expect(_failure(() => Fc2LiveJson.object('', 'x')).message, 'x: not JSON');
      expect(_failure(() => Fc2LiveJson.object('<html>', 'x')).message, 'x: not JSON');
      expect(_failure(() => Fc2LiveJson.object('null', 'x')).message, 'x: not an object');
    });
    test('four mebibytes, counted twice', () {
      final over = 'x' * (Fc2LiveEndpoints.responseLimit + 1);
      expect(_failure(() => Fc2LiveJson.object(over, 'x')).message, 'x: over 4 MiB');
      expect(Fc2LiveJson.object(_padded('x' * (Fc2LiveEndpoints.responseLimit - 12)), 'x'), isNotNull);
      expect(
        _kindOf(() => Fc2LiveJson.object(_padded('漢' * 1500000), 'x')),
        Fc2LiveFailureKind.apiChanged,
        reason: 'the character count passes but the UTF-8 bytes are over the cap',
      );
    });
    test('map and list', () {
      expect(Fc2LiveJson.map({'a': 1}, 'x'), {'a': 1});
      expect(Fc2LiveJson.map(const <int, String>{1: 'a', 2: 'b'}, 'x'), {'1': 'a', '2': 'b'});
      expect(_kindOf(() => Fc2LiveJson.map([1, 2], 'x')), Fc2LiveFailureKind.apiChanged);
      expect(_kindOf(() => Fc2LiveJson.map(null, 'x')), Fc2LiveFailureKind.apiChanged);
      expect(Fc2LiveJson.list([1, 'a']), [1, 'a']);
      expect(Fc2LiveJson.list('not a list'), isEmpty, reason: 'a row reader that skips what it cannot read uses this');
      expect(Fc2LiveJson.list(null), isEmpty);
    });
  });
  group('the numbers the platform means as integers', () {
    test('integer: an int, a truncated number or a text of one', () {
      expect(Fc2LiveJson.integer(7, 'x'), 7);
      expect(Fc2LiveJson.integer(7.9, 'x'), 7, reason: 'a finite num is truncated, as PHP would');
      expect(Fc2LiveJson.integer(3.5, 'x'), 3, reason: 'the strict reader truncates; only jsonInt demands an integer');
      expect(Fc2LiveJson.integer(' 42 ', 'x'), 42);
      expect(Fc2LiveJson.integer(-3, 'x'), -3);
      for (final bad in [null, true, 'x', '3.5', const <Object?>[], const <String, Object?>{}]) {
        expect(_failure(() => Fc2LiveJson.integer(bad, 'field')).message, 'field: $bad', reason: '$bad');
      }
    });
    test('integer keeps to 32 bits, anyInteger does not', () {
      expect(Fc2LiveJson.integer(0x7fffffff, 'x'), 0x7fffffff);
      expect(Fc2LiveJson.integer(-0x7fffffff, 'x'), -0x7fffffff);
      expect(_kindOf(() => Fc2LiveJson.integer(0x80000000, 'x')), Fc2LiveFailureKind.apiChanged);
      expect(_kindOf(() => Fc2LiveJson.integer('-2147483649', 'x')), Fc2LiveFailureKind.apiChanged);
      expect(Fc2LiveJson.anyInteger(1 << 40, 'x'), 1 << 40);
      expect(_failure(() => Fc2LiveJson.anyInteger(null, 'status')).message, 'status: null');
    });
    test('jsonInt never fails, and only an integral number counts', () {
      expect(Fc2LiveJson.jsonInt(30), 30);
      expect(Fc2LiveJson.jsonInt(30.0), 30);
      expect(Fc2LiveJson.jsonInt(30.5), isNull);
      expect(Fc2LiveJson.jsonInt('30'), 30);
      expect(Fc2LiveJson.jsonInt(' 30 '), 30);
      expect(Fc2LiveJson.jsonInt(double.infinity), isNull);
      expect(Fc2LiveJson.jsonInt(null), isNull);
      expect(Fc2LiveJson.jsonInt(true), isNull);
      expect(Fc2LiveJson.jsonInt(-5), -5);
    });
    test('count: a missing or negative figure is nothing, a broken one still fails', () {
      expect(Fc2LiveJson.count(null, 'viewers'), isNull);
      expect(Fc2LiveJson.count(0, 'viewers'), 0);
      expect(Fc2LiveJson.count(-1, 'viewers'), isNull, reason: 'the site once answered -1');
      expect(Fc2LiveJson.count('12', 'viewers'), 12);
      expect(_kindOf(() => Fc2LiveJson.count('abc', 'viewers')), Fc2LiveFailureKind.apiChanged);
    });
    test("category: the site's own 0–99", () {
      expect(Fc2LiveJson.category(0, 'channel'), 0);
      expect(Fc2LiveJson.category('99', 'channel'), 99);
      expect(_failure(() => Fc2LiveJson.category(100, 'channel')).message, 'channel: category 100');
      expect(_failure(() => Fc2LiveJson.category(-1, 'channel')).message, 'channel: category -1');
      expect(_failure(() => Fc2LiveJson.category(null, 'channel')).message, 'channel category: null');
    });
    test('startTime: Unix milliseconds inside 2000–2100', () {
      expect(Fc2LiveJson.startTime(1730000000000), DateTime.fromMillisecondsSinceEpoch(1730000000000, isUtc: true));
      expect(Fc2LiveJson.startTime('1730000000000'), isNotNull);
      expect(Fc2LiveJson.startTime(0), isNull);
      expect(Fc2LiveJson.startTime(null), isNull);
      expect(Fc2LiveJson.startTime(1730000000), isNull, reason: 'seconds are not milliseconds');
      expect(Fc2LiveJson.startTime(946684799999), isNull, reason: 'before 2000');
      expect(Fc2LiveJson.startTime(4102444800001), isNull, reason: 'past 2100: the far-future date the site sent once');
      expect(Fc2LiveJson.startTime(1730000000000.5), isNull);
    });
  });
  group('the text readers', () {
    test('text: absent is empty, another type fails, whitespace collapses', () {
      expect(Fc2LiveJson.text(null, 'title'), isEmpty);
      expect(Fc2LiveJson.text('  a  b  ', 'title'), 'a b');
      expect(Fc2LiveJson.text('\n\ta b\n', 'title'), 'a b', reason: 'a non-breaking space is whitespace too');
      expect(_failure(() => Fc2LiveJson.text(7, 'title')).message, 'title: not a string');
      expect(_failure(() => Fc2LiveJson.text('x' * 11, 'title', limit: 10)).message, 'title: over 10 characters');
      expect(Fc2LiveJson.text('x' * 10, 'title', limit: 10), isNotEmpty);
      expect(Fc2LiveJson.text('x' * 1000, 'title'), isNotEmpty, reason: "the default limit is the field's own 64 KiB");
    });
    test('displayText decodes the references, then collapses again', () {
      expect(Fc2LiveJson.displayText('A&amp;B', 'title'), 'A&B');
      expect(Fc2LiveJson.displayText('&lt;b&gt;', 'title'), '<b>');
      expect(Fc2LiveJson.displayText('a&#13;&#10;b', 'title'), 'a b', reason: 'a decoded CRLF is new whitespace');
      expect(
        Fc2LiveJson.displayText('a&nbsp;b', 'title'),
        'a b',
        reason: 'this table folds the spacing names to a plain space',
      );
      expect(Fc2LiveJson.displayText('&nbsp;', 'title'), isEmpty, reason: 'and a lone one is then trimmed away');
      expect(Fc2LiveJson.displayText('&unknown;', 'title'), '&unknown;');
      expect(Fc2LiveJson.displayText('plain', 'title'), 'plain');
      expect(Fc2LiveJson.displayText(null, 'title'), isEmpty);
      expect(_kindOf(() => Fc2LiveJson.displayText(7, 'title')), Fc2LiveFailureKind.apiChanged);
    });
    test('htmlEntities reads names and numbers in either radix', () {
      expect(Fc2LiveJson.htmlEntities('&amp;&lt;&gt;&quot;&apos;'), '&<>"\'');
      expect(Fc2LiveJson.htmlEntities('&#38; &#x26;'), '& &');
      expect(Fc2LiveJson.htmlEntities('&#x110000;'), '&#x110000;', reason: 'nothing above U+10FFFF decodes');
      expect(Fc2LiveJson.htmlEntities('&#1114112;'), '&#1114112;');
      expect(Fc2LiveJson.htmlEntities('&copy;&reg;&trade;&deg;'), '©®™°');
      expect(Fc2LiveJson.htmlEntities('&euro;&pound;&yen;'), '€£¥');
      expect(Fc2LiveJson.htmlEntities('&larr;&rarr;&uarr;&darr;&harr;'), '←→↑↓↔');
      expect(Fc2LiveJson.htmlEntities('&minus;&times;&divide;&sect;&para;'), '−×÷§¶');
      expect(Fc2LiveJson.htmlEntities('&bull;&hellip;&mdash;&ndash;&middot;'), '•…—–·');
      expect(Fc2LiveJson.htmlEntities('&laquo;&raquo;&lsquo;&rsquo;&ldquo;&rdquo;'), '«»‘’“”');
      expect(Fc2LiveJson.htmlEntities('&amp'), '&amp', reason: 'a reference without its semicolon is left alone');
      expect(Fc2LiveJson.htmlEntities('no ampersand'), 'no ampersand');
    });
    test('firstText, bounded and optionalId', () {
      expect(Fc2LiveJson.firstText(['', 'b', 'c']), 'b');
      expect(Fc2LiveJson.firstText(const []), isEmpty);
      expect(Fc2LiveJson.bounded('token', 64, 'grant'), 'token');
      expect(_failure(() => Fc2LiveJson.bounded('', 64, 'grant')).message, 'grant: missing or too long');
      expect(_failure(() => Fc2LiveJson.bounded(null, 64, 'grant')).message, 'grant: missing or too long');
      expect(_failure(() => Fc2LiveJson.bounded('   ', 64, 'grant')).message, 'grant: missing or too long');
      expect(_failure(() => Fc2LiveJson.bounded('x' * 10, 8, 'grant')).message, 'grant: over 8 characters');
      expect(Fc2LiveJson.optionalId(null), isNull);
      expect(Fc2LiveJson.optionalId('   '), isNull);
      expect(Fc2LiveJson.optionalId(7), '7', reason: 'the site once sent a userid as a number');
    });
    test("channelNumber: the site's own shape, written as text", () {
      expect(Fc2LiveJson.channelNumber('123456', 'channel'), '123456');
      for (final bad in ['0', '0123456', '', '1234567890123', 'abc']) {
        expect(_failure(() => Fc2LiveJson.channelNumber(bad, 'channel')).message, 'channel: $bad', reason: bad);
      }
      expect(
        _failure(() => Fc2LiveJson.channelNumber(7, 'channel')).message,
        'channel: not a string',
        reason: 'a number is the wrong type, not a wrong shape',
      );
    });
    test("image: only an https link on the platform's own hosts", () {
      expect(Fc2LiveJson.image('https://img.live.fc2.com/a.png'), 'https://img.live.fc2.com/a.png');
      expect(Fc2LiveJson.image('https://fc2.com/a.png'), 'https://fc2.com/a.png');
      expect(Fc2LiveJson.image('http://img.fc2.com/a.png'), isEmpty);
      expect(Fc2LiveJson.image('//img.fc2.com/a.png'), isEmpty);
      expect(Fc2LiveJson.image('https://user@img.fc2.com/a.png'), isEmpty);
      expect(Fc2LiveJson.image('https://img.fc2.com/a.png#f'), isEmpty);
      expect(Fc2LiveJson.image('https://img.evil.test/a.png'), isEmpty);
      expect(Fc2LiveJson.image('https://img.fc2.com.evil.test/a.png'), isEmpty);
      expect(Fc2LiveJson.image(''), isEmpty);
      expect(Fc2LiveJson.image(null), isEmpty);
      expect(_kindOf(() => Fc2LiveJson.image(7)), Fc2LiveFailureKind.apiChanged);
    });
    test('isFc2Live is a host test, not a string match', () {
      expect(Fc2LiveJson.isFc2Live('live.fc2.com'), isTrue);
      expect(Fc2LiveJson.isFc2Live('LIVE.FC2.COM'), isTrue);
      expect(Fc2LiveJson.isFc2Live('a.b.live.fc2.com'), isTrue);
      expect(Fc2LiveJson.isFc2Live('fc2.com'), isFalse);
      expect(Fc2LiveJson.isFc2Live('live.fc2.com.evil.test'), isFalse);
      expect(Fc2LiveJson.isFc2Live('fc2live.com'), isFalse);
    });
  });
  test('a failure names the endpoint, never the body', () {
    final failure = _failure(() => Fc2LiveJson.object('{"a":${'1' * 60}}', 'member', status: 422));
    expect(failure.kind, Fc2LiveFailureKind.apiChanged);
    expect(failure.message, 'member: HTTP 422');
    expect(failure.toString(), 'Fc2LiveFailure(apiChanged: member: HTTP 422)');
  });
}
