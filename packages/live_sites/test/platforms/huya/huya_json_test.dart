import 'package:live_sites/src/platforms/huya/parsers/huya_json.dart';
import 'package:test/test.dart';

void main() {
  group('the numbers and the text', () {
    test('jsonInt takes an integral number in either spelling', () {
      expect(jsonInt(30), 30);
      expect(jsonInt(30.0), 30);
      expect(jsonInt(-4), -4);
      expect(jsonInt(' 30 '), 30);
      expect(jsonInt('30'), 30);
      expect(jsonInt(30.5), isNull);
      expect(jsonInt('30.0'), isNull);
      expect(jsonInt(double.infinity), isNull);
      expect(jsonInt(double.nan), isNull);
      expect(jsonInt(true), isNull);
      expect(jsonInt(null), isNull);
      expect(jsonInt(const <String, Object?>{}), isNull);
    });

    test('jsonCount asks for more than nothing, so 0 is nothing', () {
      expect(jsonCount(1), 1);
      expect(jsonCount('1234'), 1234);
      expect(jsonCount(12.0), 12);
      // The other platforms' counts keep 0; this one reads it as absent.
      expect(jsonCount(0), isNull);
      expect(jsonCount('0'), isNull);
      expect(jsonCount(-1), isNull);
      expect(jsonCount(null), isNull);
    });

    test('jsonString is the value as text, untrimmed, and null stays null', () {
      expect(jsonString(' a '), ' a ');
      expect(jsonString(30), '30');
      expect(jsonString([1, 2]), '[1, 2]');
      expect(jsonString(null), isNull);
    });

    test('jsonFlag reads the two spellings of a switch', () {
      expect(jsonFlag(true), isTrue);
      expect(jsonFlag(false), isFalse);
      expect(jsonFlag('true'), isTrue);
      expect(jsonFlag('false'), isFalse);
      expect(jsonFlag(1), isTrue);
      expect(jsonFlag(0), isFalse);
      expect(jsonFlag('1'), isTrue);
      expect(jsonFlag('0'), isFalse);
      expect(jsonFlag(2), isNull);
      expect(jsonFlag('yes'), isNull);
      expect(jsonFlag(''), isNull);
      expect(jsonFlag(null), isNull);
    });
  });

  group('the containers', () {
    test('jsonUrl wants a scheme, not a host', () {
      expect(jsonUrl('https://a.test/x')?.host, 'a.test');
      expect(jsonUrl('http://a.test/x')?.scheme, 'http');
      expect(jsonUrl('HTTPS://A.TEST/x')?.scheme, 'https');
      expect(jsonUrl('  https://a.test/x  ')?.toString(), 'https://a.test/x');
      expect(jsonUrl('//a.test/x'), isNull);
      expect(jsonUrl('a.test/x'), isNull);
      expect(jsonUrl('ftp://a.test/x'), isNull);
      expect(jsonUrl(''), isNull);
      expect(jsonUrl(null), isNull);
      expect(jsonUrl(30), isNull);
    });

    test('jsonObject takes a decoded map only, jsonList is total', () {
      final map = <String, dynamic>{'a': 1};
      expect(identical(jsonObject(map), map), isTrue);
      expect(jsonObject(<int, Object?>{1: 2}), isNull);
      expect(jsonObject([1]), isNull);
      expect(jsonObject('a'), isNull);
      expect(jsonObject(null), isNull);
      expect(jsonList([1, 'a']), [1, 'a']);
      expect(jsonList(null), isEmpty);
      expect(jsonList('a'), isEmpty);
      expect(jsonList(const <String, Object?>{}), isEmpty);
    });

    test('decodeJson answers null for anything it cannot read', () {
      expect(decodeJson('{"a":1}'), {'a': 1});
      expect(decodeJson('[1,2]'), [1, 2]);
      expect(decodeJson('sorry'), isNull);
      expect(decodeJson(''), isNull);
      expect(decodeJson('null'), isNull);
    });

    test('jsonSnippet is one line and at most 80 characters', () {
      expect(jsonSnippet(' a\tb\nc  '), 'a b c');
      expect(jsonSnippet('   '), '');
      final long = 'x' * 80;
      expect(jsonSnippet(long), long);
      expect(jsonSnippet('x' * 81), '${'x' * 80}…');
    });
  });

  group('the entities, which are undone in the order they are written', () {
    test('the eight the platform bakes into its titles', () {
      expect(decodeHtmlEntities('a&mdash;b'), 'a—b');
      expect(decodeHtmlEntities('a&ndash;b'), 'a–b');
      expect(decodeHtmlEntities('&lt;a&gt;'), '<a>');
      expect(decodeHtmlEntities('&quot;x&quot;'), '"x"');
      expect(decodeHtmlEntities('&#39;'), "'");
      expect(decodeHtmlEntities('&amp;'), '&');
      // `nbsp` here is a plain space, and an unknown name stays written.
      expect(decodeHtmlEntities('a&nbsp;b'), 'a b');
      expect(decodeHtmlEntities('&hellip;'), '&hellip;');
      expect(decodeHtmlEntities('&#x41;'), '&#x41;');
      expect(decodeHtmlEntities(''), '');
    });

    test('amp is undone in the middle, so only what follows it decodes twice', () {
      // The passes after `&amp;` see the text it produced.
      expect(decodeHtmlEntities('&amp;lt;'), '<');
      expect(decodeHtmlEntities('&amp;quot;'), '"');
      expect(decodeHtmlEntities('&amp;nbsp;'), ' ');
      // The passes before it have already run, so those stay escaped.
      expect(decodeHtmlEntities('&amp;mdash;'), '&mdash;');
      expect(decodeHtmlEntities('&amp;ndash;'), '&ndash;');
    });
  });

  group('the addresses and the error page', () {
    test('normalizeImageUrl completes only the protocol-relative form', () {
      expect(normalizeImageUrl('//a.test/x.png'), 'https://a.test/x.png');
      // Everything else is handed back as written: this is not the shared
      // normalizer, and it accepts a relative path or the text `null`.
      expect(normalizeImageUrl('https://a.test/x.png'), 'https://a.test/x.png');
      expect(normalizeImageUrl('http://a.test/x.png'), 'http://a.test/x.png');
      expect(normalizeImageUrl('a.test/x.png'), 'a.test/x.png');
      expect(normalizeImageUrl('/x.png'), '/x.png');
      expect(normalizeImageUrl('"https://a.test/x.png"'), '"https://a.test/x.png"');
      expect(normalizeImageUrl('null'), 'null');
      expect(normalizeImageUrl('  https://a.test/x.png  '), 'https://a.test/x.png');
      expect(normalizeImageUrl(null), '');
      expect(normalizeImageUrl(''), '');
      expect(normalizeImageUrl(30), '30');
    });

    test('htmlPageText opens the tags with spaces and cuts the line', () {
      // Every tag becomes a space, so words the tags separated stay apart
      // instead of being glued into one.
      expect(htmlPageText('<div>oops</div>'), 'oops');
      expect(htmlPageText('a<b>b</b>c'), 'a b c');
      expect(htmlPageText('<script>var a=1;</script>oops'), 'oops');
      expect(htmlPageText('<SCRIPT>var a=1;</SCRIPT>oops'), 'oops');
      // An unclosed block is not removed: its tag still goes, its body stays.
      expect(htmlPageText('<script>oops'), 'oops');
      expect(htmlPageText('   '), '');
      final long = '${'x' * 70}<br>${'y' * 20}';
      expect(htmlPageText(long).length, 81);
      expect(htmlPageText(long).endsWith('…'), isTrue);
    });
  });
}
