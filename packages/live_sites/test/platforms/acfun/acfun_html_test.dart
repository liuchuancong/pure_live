import 'package:live_sites/src/platforms/acfun/parsers/acfun_html.dart';
import 'package:test/test.dart';

AcfunHtmlElement _root(String html) => AcfunHtmlElement.parseFragment(html);

AcfunHtmlElement _first(String html, String tag) => _root(html).query((element) => element.tag == tag)!;

void main() {
  group('the character references', () {
    test('the named ones AcFun was seen using', () {
      expect(acfunHtmlEntities('&amp;&lt;&gt;&quot;&apos;'), '&<>"\'');
      expect(acfunHtmlEntities('&nbsp;'), String.fromCharCode(0xA0), reason: 'a spacing entity is not a plain space');
      expect(acfunHtmlEntities('&ensp;&emsp;&thinsp;'), String.fromCharCodes([0x2002, 0x2003, 0x2009]));
      expect(acfunHtmlEntities('&mdash;&ndash;&hellip;&middot;&times;'), '—–…·×');
      expect(acfunHtmlEntities('&ldquo;&rdquo;&lsquo;&rsquo;'), '“”‘’');
      expect(acfunHtmlEntities('&yen;&copy;&reg;'), '¥©®');
      expect(acfunHtmlEntities('&AMP;'), '&AMP;', reason: 'the table is written in lower case');
    });

    test('the numeric ones, in either radix', () {
      expect(acfunHtmlEntities('&#39;'), "'");
      expect(acfunHtmlEntities('&#x4e2d;'), '中');
      expect(
        acfunHtmlEntities('&#X4E2D;'),
        '&#X4E2D;',
        reason: 'the pattern only opens a hex reference with a lower-case x, so the upper-case guard never runs',
      );
      expect(acfunHtmlEntities('&#0;'), String.fromCharCode(0));
      expect(acfunHtmlEntities('&#1114112;'), '&#1114112;', reason: 'no UTF scalar sits above U+10FFFF');
      expect(acfunHtmlEntities('&#x110000;'), '&#x110000;');
      expect(acfunHtmlEntities('&#xD800;').codeUnitAt(0), 0xD800, reason: 'a lone surrogate still decodes to one unit');
      expect(acfunHtmlEntities('&#xzz;'), '&#xzz;');
      expect(acfunHtmlEntities('#39;'), '#39;', reason: 'a reference needs the ampersand');
    });

    test('what is not a reference stays as it came', () {
      expect(acfunHtmlEntities('&unknown;'), '&unknown;');
      expect(acfunHtmlEntities('&amp'), '&amp', reason: 'a reference without its semicolon is left alone');
      expect(acfunHtmlEntities('a & b &amp; c'), 'a & b & c');
      expect(acfunHtmlEntities('no ampersand'), 'no ampersand');
    });
  });

  group('the fragment tree', () {
    test('the root is reported as a tag no page uses', () {
      final root = _root('<div>a</div>');
      expect(root.tag, '#fragment');
      expect(root.parent, isNull);
      expect(root.attributes, isEmpty);
      expect(root.text, 'a');
      expect(root.children.map((child) => child.tag), ['div']);
      expect(root.toString(), 'AcfunHtmlElement(#fragment)');
    });

    test('names are lower-cased, values are decoded', () {
      final div = _first('<DIV CLASS="Card" Data-Id="7">&amp;nbsp;</DIV>', 'div');
      expect(div.attributes['class'], 'Card');
      expect(div.attributes['data-id'], '7');
      expect(div.classes, {'Card'}, reason: 'class names keep the case the server wrote');
      expect(div.hasClass('card'), isFalse);
      expect(div.hasClass('Card'), isTrue);
      expect(div.text, '&nbsp;', reason: 'one pass of decoding, so a doubled reference stays written');
      expect(div.toString(), 'AcfunHtmlElement(div {class: Card, data-id: 7})');
    });

    test('a class attribute is read as a set', () {
      expect(_first('<div class=" a  b ">x</div>', 'div').classes, {'a', 'b'});
      expect(_first('<div class="">x</div>', 'div').classes, isEmpty);
      expect(_first('<div>x</div>', 'div').classes, isEmpty);
      expect(_first('<div class="a&nbsp;b">x</div>', 'div').classes, {'a', 'b'}, reason: 'the value is decoded first');
    });

    test('text is read with the tags stripped', () {
      final div = _first('<div>粉丝 <span class="n">1,2&nbsp;万</span> 人</div>', 'div');
      expect(div.text, '粉丝 1,2${String.fromCharCode(0xA0)}万 人', reason: 'the decoded spacing character is not a space');
      expect(div.children.single.text, '1,2${String.fromCharCode(0xA0)}万');
      expect(_first('<img src="a.png">x', 'img').text, isEmpty);
    });

    test('a void element cannot swallow its siblings', () {
      final root = _root('<div><img src="a.png">text<br><span>s</span></div>');
      final div = root.children.single;
      expect(div.children.map((child) => child.tag), ['img', 'br', 'span']);
      expect(div.text, 'texts');
      expect(div.parent, root);
      expect(div.children.last.parent, div);
    });

    test('a self-closing tag ends where it opens', () {
      final root = _root('<div/><span>a</span>');
      expect(root.children.map((child) => child.tag), ['div', 'span']);
      expect(root.children.first.children, isEmpty);
    });

    test('an unclosed element ends with the fragment', () {
      final root = _root('<div class="outer"><span class="mid">text');
      final div = root.children.single;
      final span = div.children.single;
      expect(span.text, 'text');
      expect(root.children.length, 1, reason: 'nothing opens beside an element never closed');
      expect(span.ancestors.map((node) => node.tag), ['div', '#fragment']);
    });

    test('a stray end tag is dropped, not an error', () {
      expect(_root('</div>text').children, isEmpty);
      expect(_root('</div>text').text, 'text');
      expect(_root('<div><span>a</span></span></div>').children.single.text, 'a');
      expect(_root('<span>a</div>b').children.map((child) => child.tag), ['span']);
      expect(_root('<span>a</div>b').text, 'ab', reason: 'the unmatched end tag closes nothing');
    });

    test('a `<` that begins no tag is text', () {
      expect(_root('a < b').text, 'a < b');
      expect(_root('<1abc>').text, '<1abc>');
      expect(_root('</1abc>x').text, '</1abc>x');
      expect(_root('a </ b>').text, 'a </ b>');
    });

    test('comments, doCTypes and processing instructions are skipped', () {
      expect(_root('<div>a<!-- <span>gone</span> -->b</div>').children.single.text, 'ab');
      expect(_root('<!DOCTYPE html><div>a</div>').children.single.tag, 'div');
      expect(_root('<?xml version="1.0"?><div>a</div>').children.single.tag, 'div');
      expect(_root('<div>a<!-- never closed').children.single.text, 'a');
      expect(_root('a<!-- -->b').text, 'ab');
    });

    test('a raw-text body is not re-tokenized and not decoded', () {
      expect(
        _first('<script>if (a < b && c) { x("</span>"); }</script>after', 'script').text,
        'if (a < b && c) { x("</span>"); }',
      );
      expect(
        _first('<script>a < b</script>', 'script').children,
        isEmpty,
        reason: 'markup inside a script is not a child',
      );
      expect(_root('<script>a</script>after').text, 'aafter', reason: "a root's text includes its children's");
      expect(_root('<script src="a.js"></script>').children.single.text, isEmpty);
      expect(
        _root('<script>a < b').children.single.text,
        'a < b',
        reason: 'an unterminated script ends with the fragment',
      );
      expect(_first('<SCRIPT>a < b</SCRIPT>', 'script').text, 'a < b');
      expect(
        _first('<style>.a > .b { content: "&amp;" }</style>', 'style').text,
        '.a > .b { content: "&amp;" }',
        reason: 'a style body is code, not prose',
      );
      expect(_first('<textarea>&amp; &lt;</textarea>', 'textarea').text, '& <');
      expect(_first('<title>&amp; 房间</title>', 'title').text, '& 房间');
    });

    test("an attribute value keeps the tag's own delimiters when quoted", () {
      final div = _first('<div title="a > b" alt=\'c &amp; d\' data-x=plain data-y>y</div>', 'div');
      expect(div.attributes['title'], 'a > b');
      expect(div.attributes['alt'], 'c & d');
      expect(div.attributes['data-x'], 'plain');
      expect(div.attributes['data-y'], isEmpty, reason: 'a name with no value reads as empty text');
      expect(_first('<div data-x=>y</div>', 'div').attributes['data-x'], isEmpty);
      expect(
        _first('<div data-x=a>b data-y="never closed">y</div>', 'div').attributes['data-x'],
        'a',
        reason: 'an unquoted value stops at the first `>`',
      );
      expect(
        _first('<div a="1" a="2">y</div>', 'div').attributes['a'],
        '1',
        reason: 'the first of a repeated attribute wins',
      );
    });

    test('junk between attributes is stepped over', () {
      final div = _first('<div =oops class="a" ! b="2">y</div>', 'div');
      expect(div.attributes['class'], 'a');
      expect(div.attributes['b'], '2');
      expect(div.attributes['oops'], isEmpty, reason: 'a bare name that never reaches an `=` is read as an attribute');
    });

    test('an unterminated quoted value runs to the end of the fragment', () {
      final div = _first('<div title="never ended', 'div');
      expect(div.attributes['title'], 'never ended');
      expect(div.children, isEmpty);
    });

    test('the attributes are not writable', () {
      expect(() => _first('<div a="1">y</div>', 'div').attributes['a'] = '2', throwsUnsupportedError);
    });
  });

  group('the selection', () {
    final root = _root(
      '<div class="card"><a class="name" href="/u/1"><span>张三</span></a><span class="count">12</span></div><div class="card"><a class="name" href="/u/2"><span>李四</span></a></div>',
    );

    test('descendants come in document order, each child before its own', () {
      expect(root.descendants.map((element) => element.tag), ['div', 'a', 'span', 'span', 'div', 'a', 'span']);
    });

    test('query takes the first, queryAll every one', () {
      expect(root.query((element) => element.hasClass('name'))?.attributes['href'], '/u/1');
      expect(root.queryAll((element) => element.hasClass('card')), hasLength(2));
      expect(root.queryAll((element) => element.tag == 'span').map((element) => element.text), ['张三', '12', '李四']);
      expect(root.query((element) => element.tag == '#fragment'), isNull, reason: 'the root never selects itself');
      expect(root.queryAll((element) => false), isEmpty);
    });

    test('ancestors walk out from the node', () {
      final span = root.query((element) => element.attributes['href'] == '/u/2')!.children.single;
      expect(span.ancestors.map((node) => node.tag), ['a', 'div', '#fragment']);
      expect(span.ancestors.last.parent, isNull);
      expect(root.ancestors, isEmpty);
    });

    test('a card is read by class, attribute and text together', () {
      final cards = root.queryAll((element) => element.hasClass('card')).toList();
      expect(cards, hasLength(2));
      expect(
        [for (final card in cards) (card.query((element) => element.hasClass('name'))?.text ?? '', card.text)],
        [('张三', '张三12'), ('李四', '李四')],
      );
    });
  });
}
