import 'package:live_sites/src/platforms/bilibili/parsers/bilibili_json.dart';
import 'package:test/test.dart';

void main() {
  group('the total readers', () {
    test('jsonInt takes a whole number in either spelling', () {
      expect(jsonInt(30), 30);
      expect(jsonInt(30.0), 30);
      expect(jsonInt(-4), -4);
      expect(jsonInt(' 30 '), 30);
      expect(jsonInt('-4'), -4);
      // A fraction is not a whole number, in text or as a number.
      expect(jsonInt(30.5), isNull);
      expect(jsonInt('30.0'), isNull);
      expect(jsonInt(double.infinity), isNull);
      expect(jsonInt(double.nan), isNull);
      expect(jsonInt('x'), isNull);
      expect(jsonInt(''), isNull);
      expect(jsonInt(true), isNull);
      expect(jsonInt(null), isNull);
      expect(jsonInt(const <String, Object?>{}), isNull);
    });

    test('jsonString turns anything into its text, and never trims', () {
      expect(jsonString('a'), 'a');
      expect(jsonString(30), '30');
      expect(jsonString([1, 2]), '[1, 2]');
      expect(jsonString(null), isNull);
      // The doc says trimmed; the reader hands back what came.
      expect(jsonString(' a b '), ' a b ');
    });

    test('jsonCount keeps only what the site can show', () {
      expect(jsonCount(0), 0);
      expect(jsonCount('1234'), 1234);
      expect(jsonCount(12.0), 12);
      expect(jsonCount(-1), isNull);
      expect(jsonCount('-1'), isNull);
      expect(jsonCount(''), isNull);
      expect(jsonCount(null), isNull);
    });

    test('jsonList is total and jsonDecode answers null for a broken body', () {
      expect(jsonList([1, 'a']), [1, 'a']);
      expect(jsonList(null), isEmpty);
      expect(jsonList('a'), isEmpty);
      expect(jsonList(const <String, Object?>{}), isEmpty);
      expect(decodeJson('{"a":1}'), {'a': 1});
      expect(decodeJson('[1,2]'), [1, 2]);
      expect(decodeJson('sorry'), isNull);
      expect(decodeJson(''), isNull);
      // A body of `null` is valid JSON and reads as nothing either way.
      expect(decodeJson('null'), isNull);
    });

    test('jsonObject takes a map as it is or decodes it out of text', () {
      final map = <String, dynamic>{'a': 1};
      expect(identical(jsonObject(map), map), isTrue);
      // A map of other keys is still a map; its keys become their text.
      expect(jsonObject(<int, Object?>{1: 2}), {'1': 2});
      // Bilibili hides the rich chat user as JSON text inside an answer.
      expect(jsonObject('{"a":{"b":1}}'), {
        'a': {'b': 1},
      });
      expect(jsonObject('  {"a":1}'), {'a': 1});
      expect(jsonObject('{"a":'), isNull);
      // A list of text is a list of text, not an object.
      expect(jsonObject('[1,2]'), isNull);
      expect(jsonObject('a'), isNull);
      expect(jsonObject([1, 2]), isNull);
      expect(jsonObject(null), isNull);
    });
  });

  group('the entities the site bakes into its text', () {
    test('the named ones fold to what the page shows', () {
      expect(decodeHtmlEntities('&lt;a&gt;'), '<a>');
      expect(decodeHtmlEntities('&quot;x&quot;'), '"x"');
      expect(decodeHtmlEntities('a&nbsp;b'), 'a b');
      // `nbsp` is a plain space here, not U+00A0.
      expect(decodeHtmlEntities('&nbsp;').codeUnitAt(0), 0x20);
      expect(decodeHtmlEntities('&mdash;&ndash;&hellip;&middot;'), '—–…·');
      expect(decodeHtmlEntities('&times;&divide;&deg;&plusmn;'), '×÷°±');
      expect(decodeHtmlEntities('&copy;&reg;&trade;&euro;&pound;&yen;&sect;&para;'), '©®™€£¥§¶');
      expect(decodeHtmlEntities('&larr;&rarr;&uarr;&darr;&harr;'), '←→↑↓↔');
      expect(decodeHtmlEntities('&laquo;&raquo;'), '«»');
    });

    test('the numeric ones are decimal only, and stay out of the control range', () {
      expect(decodeHtmlEntities('&#35;&#37;&#64;'), '#%@');
      expect(decodeHtmlEntities('&#32;'), ' ');
      // 31 and below stays written, 32 is allowed.
      expect(decodeHtmlEntities('&#31;'), '&#31;');
      expect(decodeHtmlEntities('&#0;'), '&#0;');
      expect(decodeHtmlEntities('&#128129;'), '\u{1F481}');
      expect(decodeHtmlEntities('&#1114112;'), '&#1114112;');
      // A hexadecimal reference is not read at all.
      expect(decodeHtmlEntities('&#x41;'), '&#x41;');
      expect(decodeHtmlEntities('&#;'), '&#;');
      expect(decodeHtmlEntities('&fjell;'), '&fjell;');
      // The names are read as written: the table is lower case.
      expect(decodeHtmlEntities('&AMP;&Lt;'), '&AMP;&Lt;');
    });

    test('amp is undone last, so a doubly escaped name stays escaped', () {
      expect(decodeHtmlEntities('&amp;'), '&');
      expect(decodeHtmlEntities('A &amp;amp; B'), 'A & B');
      // Only the `&amp;` text survives a second reading; the others do not.
      expect(decodeHtmlEntities('&amp;lt;'), '&lt;');
      expect(decodeHtmlEntities('&amp;quot;'), '&quot;');
      // A numeric reference the first pass leaves behind is read by the next.
      expect(decodeHtmlEntities('&#38;#38;'), '&');
      expect(decodeHtmlEntities('&amp;#38;'), '&');
    });

    test('text without an entity is returned as it came', () {
      const plain = '直播中 & 1234 人气';
      expect(decodeHtmlEntities(plain), plain);
      expect(decodeHtmlEntities(''), '');
      expect(decodeHtmlEntities('&'), '&');
      expect(decodeHtmlEntities('&&'), '&&');
    });
  });

  group('the addresses', () {
    test('imageUrl makes the protocol-relative one https and checks the rest', () {
      expect(imageUrl('//i0.hdslb.com/a.png'), 'https://i0.hdslb.com/a.png');
      expect(imageUrl('https://i0.hdslb.com/a.png'), 'https://i0.hdslb.com/a.png');
      // http stays http wherever it is; the reader only asks for a scheme.
      expect(imageUrl('http://a.test/x.png'), 'http://a.test/x.png');
      expect(imageUrl('HTTP://A.TEST/x.png'), 'HTTP://A.TEST/x.png');
      expect(imageUrl('  https://i0.hdslb.com/a.png  '), 'https://i0.hdslb.com/a.png');
      expect(imageUrl('a.png'), '');
      expect(imageUrl('/a.png'), '');
      expect(imageUrl('https://'), '');
      expect(imageUrl('ftp://a.test/x'), '');
      expect(imageUrl(''), '');
      expect(imageUrl(null), '');
      expect(imageUrl(30), '');
    });

    test('sizedImage puts the CDN hint on the end without judging it', () {
      expect(sizedImage('//i0.hdslb.com/a.png', '@400w.jpg'), 'https://i0.hdslb.com/a.png@400w.jpg');
      expect(sizedImage('https://i0.hdslb.com/a.png'), 'https://i0.hdslb.com/a.png');
      // Nothing is checked about the hint, and a broken address loses the hint too.
      expect(sizedImage('https://i0.hdslb.com/a.png', ' anything '), 'https://i0.hdslb.com/a.png anything ');
      expect(sizedImage('a.png', '@400w.jpg'), '');
      expect(sizedImage(null, '@400w.jpg'), '');
    });

    test('jsonSnippet is one line and at most 80 characters', () {
      expect(jsonSnippet(' a\tb\nc  '), 'a b c');
      final long = 'x' * 80;
      expect(jsonSnippet(long), long);
      expect(jsonSnippet('x' * 81), '${'x' * 80}…');
      expect(jsonSnippet('   '), '');
    });
  });
}
