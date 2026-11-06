import 'package:live_sites/src/platforms/kilakila/parsers/kilakila_html.dart';
import 'package:test/test.dart';

void main() {
  group('what is gone before the tree is built', () {
    test('a comment takes its tags with it, an open one runs to the end', () {
      final page = KilakilaHtml.parse('<div><!-- a <b> c -->x</div>');
      expect(page.children.single.name, 'div');
      expect(page.children.single.children, isEmpty);
      expect(page.children.single.text, 'x');
      // The open comment is eaten from its own delimiter on.
      expect(KilakilaHtml.parse('<div>a<!--b').children.single.text, 'a');
    });

    test('a script or a style loses its body and never leaks a tag', () {
      final page = KilakilaHtml.parse('<p>a</p><script>var a="</b>";</script><p>b</p>');
      expect(page.children.map((element) => element.name).toList(), ['p', 'p']);
      expect(page.children.map((element) => element.text).toList(), ['a', 'b']);
      // The names are read in any case, and an open block runs to the end.
      expect(KilakilaHtml.parse('<i>a</i><STYLE>b{color:red}</STYLE>').children.length, 1);
      expect(KilakilaHtml.parse('<div>x</div><script>oops').children.length, 1);
    });
  });

  group('the tree', () {
    test('names are lower-cased and a void element holds nothing', () {
      final page = KilakilaHtml.parse('<DIV CLASS="card"><BR><SPAN>x</SPAN></DIV>');
      final div = page.children.single;
      expect(div.name, 'div');
      expect(div.attributes['class'], 'card');
      expect(div.children.map((element) => element.name).toList(), ['br', 'span']);
      expect(div.children.first.children, isEmpty);
      expect(div.children.first.end, div.children.first.start);
      expect(div.text, 'x');
    });

    test('nesting follows tag names and an outer closer ends what is open', () {
      final page = KilakilaHtml.parse('<div><p>a<p>b</div>');
      final outer = page.first('p')!;
      // There is no "a new p closes the open p", so the second nests inside
      // and the outer span runs through it.
      expect(outer.children.map((element) => element.name).toList(), ['p']);
      expect(outer.text, 'ab');
      expect(outer.children.single.text, 'b');
      // A closer of another name ends the element inside it all the same.
      final implicit = KilakilaHtml.parse('<div><span>x</div>');
      expect(implicit.first('span')!.text, 'x');
      expect(implicit.first('div')!.text, 'x');
      // A closer with nothing open changes nothing.
      expect(KilakilaHtml.parse('<div>a</div></p><p>b</p>').children.map((element) => element.name).toList(), [
        'div',
        'p',
      ]);
    });

    test('an element left open runs to the end of the page', () {
      final page = KilakilaHtml.parse('<div><span>a');
      expect(page.first('div')!.text, 'a');
      expect(page.first('span')!.text, 'a');
      expect(page.end, page.source.length);
      // A self-closing slash is an attribute the reader cannot read, so a
      // non-void element written that way stays open.
      final selfClosed = KilakilaHtml.parse('<i>x</i><span/>y');
      expect(selfClosed.first('span')!.text, 'y');
      expect(selfClosed.first('span')!.attributes, isEmpty);
    });

    test('the root names nothing and holds the document', () {
      final page = KilakilaHtml.parse('<div>a</div>');
      expect(page.name, '');
      expect(page.attributes, isEmpty);
      expect(page.start, 0);
      expect(page.text, 'a');
      // This reader's surface is only `first`/`firstWithClass` down the tree:
      // it carries no parent link and no class test of its own, so a card's
      // picture is found by searching down, never by walking up.
      expect(page.children.single.text, 'a');
      expect(page.children.single.children, isEmpty);
    });
  });

  group('the text and the attributes', () {
    test('text is the span stripped, so an ancestor answers the same words', () {
      expect(KilakilaHtml.parse('<div>a<b>c</b>d</div>').children.single.text, 'acd');
      final nested = KilakilaHtml.parse('<div><p><span>s</span></p></div>');
      expect(nested.children.map((element) => element.name).toList(), ['div']);
      // Every element whose content is only that span carries its text.
      expect(nested.first('span')!.text, 's');
      expect(nested.first('p')!.text, 's');
      expect(nested.children.single.text, 's');
    });

    test('references are decoded by the shared table, in text and in values', () {
      final page = KilakilaHtml.parse('<div title="a&nbsp;b">x&nbsp;y &#x41; &#zz;&fjell;</div>');
      final div = page.children.single;
      expect(div.text, 'x\u{A0}y A &#zz;&fjell;');
      expect(div.attributes['title'], 'a\u{A0}b');
      expect(page.children.single.first('div'), isNull);
    });

    test('attribute names are lower-cased and values read in any quoting', () {
      final anchor = KilakilaHtml.parse('''<a HREF="/h?x=1&amp;y=2" DATA-X=y title='a b' disabled>t</a>''')
          .children
          .single;
      expect(anchor.attributes.keys.toList(), ['href', 'data-x', 'title', 'disabled']);
      expect(anchor.attributes['href'], '/h?x=1&y=2');
      expect(anchor.attributes['data-x'], 'y');
      expect(anchor.attributes['title'], 'a b');
      expect(anchor.attributes['disabled'], '');
      // A quoted value may hold what separates attributes.
      expect(KilakilaHtml.parse('<a title="a>b" href="/h">t</a>').children.single.attributes['title'], 'a>b');
      // The first answer of a repeated attribute is kept.
      expect(KilakilaHtml.parse('<a href="/one" href="/two">t</a>').children.single.attributes['href'], '/one');
      // A bare slash is nothing at all.
      expect(KilakilaHtml.parse('<br / ><span>x</span>').children.length, 2);
    });
  });

  group('the searches', () {
    test('first asks the lower-cased tag and never the root', () {
      final page = KilakilaHtml.parse('<DIV><p><a href="/x">t</a></p></DIV>');
      expect(page.first('div')!.name, 'div');
      expect(page.first('DIV'), isNull);
      expect(page.first(''), isNull);
      expect(page.first('a')!.text, 't');
      expect(page.first('nothing'), isNull);
    });

    test('firstWithClass takes the first descendant that carries it', () {
      final page = KilakilaHtml.parse(
        '<div class="live"><div class="thumb"><img src="a.png"></div><div class="thumb"><img src="b.png"></div></div>',
      );
      final thumb = page.firstWithClass('thumb')!;
      expect(thumb.attributes['class'], 'thumb');
      expect(thumb.first('img')!.attributes['src'], 'a.png');
      final mixed = KilakilaHtml.parse('<div class="b"><span class="a b">x</span></div>');
      expect(mixed.firstWithClass('a')!.name, 'span');
      expect(mixed.firstWithClass('b')!.name, 'div');
      expect(mixed.firstWithClass('c'), isNull);
      // The name is compared as written, and an element without the attribute
      // carries the empty name.
      expect(mixed.firstWithClass('b '), isNull);
      expect(page.firstWithClass('')!.name, 'img');
    });

    test('the class of a page is split on any run of whitespace', () {
      final card = KilakilaHtml.parse('<div class="a  b\tc">x</div>').children.single;
      expect(card.firstWithClass('a'), isNull);
      expect(KilakilaHtml.parse('<div><p class="a  b">x</p></div>').firstWithClass('b')!.name, 'p');
      expect(KilakilaHtml.parse('<div><p class="a  b">x</p></div>').firstWithClass('a')!.text, 'x');
      expect(KilakilaHtml.parse('<div><p class="a b">x</p></div>').firstWithClass('ab'), isNull);
    });

    test('a hand-made element carries no span until the page gives one', () {
      final plain = KilakilaHtml('<p>x</p>', 'p', const <String, String>{}, 3);
      expect(plain.name, 'p');
      expect(plain.end, 0);
      expect(plain.children, isEmpty);
      expect(plain.first('p'), isNull);
      expect(() => plain.text, throwsRangeError);
      plain.end = 4;
      expect(plain.text, 'x');
    });
  });
}
