import 'package:live_sites/src/platforms/sixroom/parsers/sixroom_html.dart';
import 'package:test/test.dart';

void main() {
  group('what is gone before the tree is built', () {
    test('a comment and a script leave nothing behind', () {
      final page = SixroomHtml.parse('<div><!-- a <b> c -->x</div>');
      expect(page.descendants.map((element) => element.name).toList(), ['div']);
      expect(page.descendants.single.text, 'x');
      // An open comment is eaten from its own delimiter on.
      expect(SixroomHtml.parse('<div>a<!--b').descendants.single.text, 'a');
      final scripted = SixroomHtml.parse('<p>a</p><script>var a="</b>";</script><STYLE>b{}</STYLE><p>c</p>');
      expect(scripted.descendants.map((element) => element.name).toList(), ['p', 'p']);
      // Without a closer the block runs to the end of the page.
      expect(SixroomHtml.parse('<div>x</div><script>oops').descendants.length, 1);
    });
  });

  group('the parent chain', () {
    test('every element knows its parent and the root knows none', () {
      final page = SixroomHtml.parse('<div class="card"><p><img src="a.png"></p></div>');
      final div = page.descendants.first;
      final paragraph = page.first('p')!;
      final image = page.first('img')!;
      expect(page.name, '');
      expect(page.parent, isNull);
      expect(div.parent, page);
      expect(paragraph.parent, div);
      expect(image.parent, paragraph);
      // A void element is a child like any other, and holds nothing.
      expect(image.children, isEmpty);
      expect(image.attributes['src'], 'a.png');
    });

    test('a void tag and a self-closed one both stay siblings', () {
      final page = SixroomHtml.parse('<div><br><i>y</i><img src="a.png"><span/></div>');
      final div = page.descendants.first;
      expect(div.children.map((element) => element.name).toList(), ['br', 'i', 'img', 'span']);
      // The self-closing slash is an attribute the reader cannot read, so the
      // span stays open to the end of the page.
      final span = page.first('span')!;
      expect(span.text, '');
      expect(span.attributes, isEmpty);
    });
  });

  group('the searches', () {
    test('descendants are in document order and can be walked again', () {
      final page = SixroomHtml.parse('<div><p><span>s</span></p><em>e</em></div>');
      expect(page.descendants.map((element) => element.name).toList(), ['div', 'p', 'span', 'em']);
      expect(page.descendants.map((element) => element.name).toList(), ['div', 'p', 'span', 'em']);
      // The root is not a descendant of itself.
      expect(page.descendants.any((element) => element.parent == null), isFalse);
    });

    test('first asks the lower-cased tag and never the root', () {
      final page = SixroomHtml.parse('<DIV class="A"><p><a href="/x">t</a></p></DIV>');
      expect(page.first('div')!.attributes['class'], 'A');
      // The names are stored lower-cased, so an upper-case question misses.
      expect(page.first('DIV'), isNull);
      expect(page.first(''), isNull);
      expect(page.first('a')!.text, 't');
      expect(page.first('nothing'), isNull);
    });

    test('firstWithClass takes the first descendant that carries it', () {
      final page = SixroomHtml.parse(
        '<div class="live"><div class="thumb"><img src="a.png"></div><div class="thumb"><img src="b.png"></div></div>',
      );
      final thumb = page.firstWithClass('thumb')!;
      expect(thumb.attributes['class'], 'thumb');
      expect(thumb.first('img')!.attributes['src'], 'a.png');
      // Two classes on one element, and the order of the page decides.
      final mixed = SixroomHtml.parse('<div class="b"><span class="a b">x</span></div>');
      expect(mixed.firstWithClass('a')!.name, 'span');
      expect(mixed.firstWithClass('b')!.name, 'div');
      expect(mixed.firstWithClass('c'), isNull);
      // An element without the attribute carries the empty name, so the first
      // descendant with no class answers an empty question.
      expect(page.firstWithClass('')!.name, 'img');
    });

    test('hasClass splits the class attribute on whitespace', () {
      final card = SixroomHtml.parse('<div class="a  b">x</div>').descendants.first;
      expect(card.hasClass('a'), isTrue);
      expect(card.hasClass('b'), isTrue);
      expect(card.hasClass('ab'), isFalse);
      expect(card.hasClass('a '), isFalse);
      expect(SixroomHtml.parse('<div>x</div>').descendants.first.hasClass(''), isTrue);
    });
  });

  group('the tree', () {
    test('nesting follows tag names and an outer closer ends what is open', () {
      final page = SixroomHtml.parse('<div><p>a<p>b</div>');
      final outer = page.first('p')!;
      // There is no "a new p closes the open p": the second nests inside.
      expect(outer.children.map((element) => element.name).toList(), ['p']);
      expect(outer.text, 'ab');
      expect(outer.children.single.text, 'b');
      // A closer of another name ends the element inside it all the same.
      final implicit = SixroomHtml.parse('<div><span>x</div>');
      expect(implicit.first('span')!.text, 'x');
      expect(implicit.first('div')!.text, 'x');
      // A closer with nothing open changes nothing.
      expect(SixroomHtml.parse('<div>a</div></p><p>b</p>').descendants.map((element) => element.name).toList(), [
        'div',
        'p',
      ]);
    });

    test('an element left open runs to the end of the page', () {
      final page = SixroomHtml.parse('<div><span>a');
      expect(page.first('div')!.text, 'a');
      expect(page.first('span')!.text, 'a');
      expect(page.end, page.source.length);
    });

    test('text is the span stripped, so an ancestor answers the same words', () {
      final page = SixroomHtml.parse('<div>a<b>c</b>d</div>');
      expect(page.descendants.first.text, 'acd');
      expect(page.descendants.length, 2);
      // Every ancestor whose content is only that span carries its text too,
      // so a text search reaches up to the root's child.
      final nested = SixroomHtml.parse('<div><p><span>s</span></p></div>');
      expect(nested.descendants.where((element) => element.text == 's').map((element) => element.name).toList(), [
        'div',
        'p',
        'span',
      ]);
    });

    test('references in text and attributes are decoded by the shared table', () {
      final page = SixroomHtml.parse('<div title="a&nbsp;b">x&nbsp;y &#x41; &#zz;</div>');
      final div = page.descendants.first;
      expect(div.text, 'x\u{A0}y A &#zz;');
      expect(div.attributes['title'], 'a\u{A0}b');
    });
  });

  group('the attributes', () {
    test('names are lower-cased and values read in any quoting', () {
      final anchor = SixroomHtml.parse('''<a HREF="/h?x=1&amp;y=2" DATA-X=y title='a b' disabled>t</a>''')
          .descendants
          .first;
      expect(anchor.attributes.keys.toList(), ['href', 'data-x', 'title', 'disabled']);
      expect(anchor.attributes['href'], '/h?x=1&y=2');
      expect(anchor.attributes['data-x'], 'y');
      expect(anchor.attributes['title'], 'a b');
      expect(anchor.attributes['disabled'], '');
      // A quoted value may hold what separates attributes.
      expect(SixroomHtml.parse('<a title="a>b" href="/h">t</a>').descendants.first.attributes['title'], 'a>b');
      // The first answer of a repeated attribute is kept.
      expect(SixroomHtml.parse('<a href="/one" href="/two">t</a>').descendants.first.attributes['href'], '/one');
    });

    test('an element can be made by hand and answers nothing', () {
      final plain = SixroomHtml('<p>x</p>', 'p', const <String, String>{'class': 'a'}, null, 3);
      expect(plain.name, 'p');
      expect(plain.parent, isNull);
      expect(plain.start, 3);
      expect(plain.end, 0);
      expect(plain.descendants, isEmpty);
      expect(plain.hasClass('a'), isTrue);
    });
  });
}
