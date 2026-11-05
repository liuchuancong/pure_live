import 'package:live_sites/src/platforms/steambroadcast/parsers/steambroadcast_html.dart';
import 'package:test/test.dart';

void main() {
  group('what is gone before the tree is built', () {
    test('a comment takes its tags with it, to the end when left open', () {
      final page = SteambroadcastHtml.parse('<div><!-- a <b> c -->x</div>');
      expect(page.all((element) => true).map((element) => element.name).toList(), ['div']);
      expect(page.first((element) => element.name == 'div')!.text, 'x');
      // An open comment is eaten from its own delimiter on, so the text that
      // came before it stays.
      expect(SteambroadcastHtml.parse('<div>a<!--b').first((element) => element.name == 'div')!.text, 'a');
    });

    test('a script or a style loses its body, and so does an unterminated one', () {
      final page = SteambroadcastHtml.parse('<p>a</p><script>var a="</b>";</script><p>b</p>');
      expect(page.all((element) => true).map((element) => element.name).toList(), ['p', 'p']);
      expect(page.all((element) => true).map((element) => element.text).toList(), ['a', 'b']);
      expect(
        SteambroadcastHtml.parse('<p>a</p><STYLE TYPE="text/css">b{color:red}</STYLE>').all((element) => true).length,
        1,
      );
      // The pattern also eats to the end of the page when the closer is missing.
      expect(SteambroadcastHtml.parse('<div>x</div><script>oops').first((element) => element.name == 'div')!.text, 'x');
      expect(SteambroadcastHtml.parse('<div>x</div><script>oops').all((element) => true).length, 1);
    });
  });

  group('the tree', () {
    test('names are lower-cased and a void element holds nothing', () {
      final page = SteambroadcastHtml.parse('<DIV><BR><SPAN>x</SPAN></DIV>');
      final div = page.first((element) => element.name == 'div')!;
      expect(div.children.map((element) => element.name).toList(), ['br', 'span']);
      expect(div.children.first.children, isEmpty);
      expect(div.text, 'x');
      // A void tag written with a slash is the same element, not a child.
      expect(
        SteambroadcastHtml.parse('<div><img src="a.png"/><i>y</i></div>')
            .first((e) => e.name == 'div')!
            .children
            .length,
        2,
      );
    });

    test('an end tag closes the nearest open element of its name', () {
      final page = SteambroadcastHtml.parse('<div><p>a<p>b</div>');
      final div = page.first((element) => element.name == 'div')!;
      final outer = div.children.single;
      // Only tag names nest here: the browser's "a new p closes the open p" is
      // not known, so the second paragraph lands inside the first, and the
      // first one's span — and so its text — runs through it.
      expect(div.children.map((element) => element.name).toList(), ['p']);
      expect(outer.children.map((element) => element.name).toList(), ['p']);
      expect(outer.text, 'ab');
      expect(outer.children.single.text, 'b');
      expect(div.text, 'ab');
    });

    test('a closer of another name ends what is open inside it', () {
      final page = SteambroadcastHtml.parse('<div><span>x</div>');
      final div = page.first((element) => element.name == 'div')!;
      final span = page.first((element) => element.name == 'span')!;
      expect(span.text, 'x');
      expect(div.text, 'x');
    });

    test('a stray closer and a name that is no tag change nothing', () {
      final page = SteambroadcastHtml.parse('<div>a</div></span><p>b</p>');
      expect(page.all((element) => true).map((element) => element.name).toList(), ['div', 'p']);
      // A tag name has to start with a letter, so the parser leaves this text
      // — but the text getter strips anything that looks like a tag anyway.
      expect(SteambroadcastHtml.parse('<div><1x>text</div>').first((element) => element.name == 'div')!.text, 'text');
    });

    test('an element left open runs to the end of the page', () {
      final page = SteambroadcastHtml.parse('<div><span>a');
      final div = page.first((element) => element.name == 'div')!;
      expect(page.first((element) => element.name == 'span')!.text, 'a');
      expect(div.text, 'a');
      expect(page.end, page.source.length);
      // A non-void self-closing tag is not understood: the element stays open.
      final selfClosed = SteambroadcastHtml.parse('<i>x</i><span/>y');
      expect(selfClosed.first((element) => element.name == 'span')!.text, 'y');
      expect(selfClosed.first((element) => element.name == 'span')!.attributes, isEmpty);
    });

    test('the root names nothing and holds the document', () {
      final page = SteambroadcastHtml.parse('<div>a</div>');
      expect(page.name, '');
      expect(page.parent, isNull);
      expect(page.attributes, isEmpty);
      expect(page.text, 'a');
      // The root is not a descendant of itself.
      expect(page.first((element) => element.name.isEmpty), isNull);
    });
  });

  group('the text and the attributes', () {
    test('tags inside the element are removed and the references decoded', () {
      expect(SteambroadcastHtml.parse('<div>a&nbsp;b&lt;c</div>').first((e) => e.name == 'div')!.text, 'a\u{A0}b<c');
      expect(SteambroadcastHtml.parse('<div>a<b>c</b>d</div>').first((e) => e.name == 'div')!.text, 'acd');
      // The shared table reads hex, and leaves what it cannot resolve written.
      final decoded = SteambroadcastHtml.parse('<div>&#x41;&#66;&#zz;&fjell;</div>').text;
      expect(decoded, 'AB&#zz;&fjell;');
      expect(SteambroadcastHtml.parse('<div>&#1114112;</div>').text, '&#1114112;');
    });

    test('attribute names are lower-cased and values read in any quoting', () {
      final anchor = SteambroadcastHtml.parse('<a HREF="http://x.test/?a=1&amp;b=2" data-x="y&#x41;" disabled>z</a>')
          .first((element) => element.name == 'a')!;
      expect(anchor.attributes['href'], 'http://x.test/?a=1&b=2');
      expect(anchor.attributes['data-x'], 'yA');
      expect(anchor.attributes['disabled'], '');
      expect(anchor.attributes.keys.toList(), ['href', 'data-x', 'disabled']);
      expect(SteambroadcastHtml.parse('<a href=x.png>z</a>').first((e) => e.name == 'a')!.attributes['href'], 'x.png');
      // The value may hold what separates attributes, if it is quoted — in
      // either kind of quotes.
      expect(
        SteambroadcastHtml.parse('<a title="a>b" href="/h">z</a>').first((e) => e.name == 'a')!.attributes['title'],
        'a>b',
      );
      expect(
        SteambroadcastHtml.parse("<a title='a b'>z</a>").first((element) => element.name == 'a')!.attributes['title'],
        'a b',
      );
    });

    test('a repeated attribute keeps the first answer', () {
      final anchor = SteambroadcastHtml.parse('<a href="/one" href="/two">z</a>')
          .first((element) => element.name == 'a')!;
      expect(anchor.attributes['href'], '/one');
    });
  });

  group('the class tests', () {
    test('hasClass splits the class attribute on whitespace', () {
      final card = SteambroadcastHtml.parse('<div class="a  b">x</div>').first((element) => element.name == 'div')!;
      expect(card.hasClass('a'), isTrue);
      expect(card.hasClass('b'), isTrue);
      expect(card.hasClass('ab'), isFalse);
      expect(card.hasClass('c'), isFalse);
      // An element without the attribute still matches the empty name.
      final plain = SteambroadcastHtml.parse('<div>x</div>').first((element) => element.name == 'div')!;
      expect(plain.hasClass(''), isTrue);
      expect(plain.hasClass('a'), isFalse);
      expect(SteambroadcastHtml.parse('<div class="">x</div>').first((e) => e.name == 'div')!.hasClass(''), isTrue);
    });

    test('insideClass walks the ancestors, never this element', () {
      final page = SteambroadcastHtml.parse('<div class="card"><span class="card">x</span></div>');
      final outer = page.first((element) => element.name == 'div')!;
      final inner = page.first((element) => element.name == 'span')!;
      expect(inner.insideClass('card'), isTrue);
      expect(outer.insideClass('card'), isFalse);
      expect(inner.insideClass('other'), isFalse);
      // A class two levels up still reaches, and the name is compared as
      // written: a trailing space matches nothing.
      final deep = SteambroadcastHtml.parse('<div class="watch"><p><span>x</span></p></div>');
      expect(deep.first((element) => element.name == 'span')!.insideClass('watch'), isTrue);
      expect(deep.first((element) => element.name == 'span')!.insideClass('watch '), isFalse);
    });
  });

  group('the searches', () {
    test('all and first walk the descendants in document order', () {
      final page = SteambroadcastHtml.parse('<div><p><span>s</span></p><em>e</em></div>');
      expect(page.all((element) => true).map((element) => element.name).toList(), ['div', 'p', 'span', 'em']);
      // `text` is the span stripped, so the paragraph whose content is only
      // the span answers the same text as the span itself.
      expect(page.all((element) => element.text == 's').map((element) => element.name).toList(), ['p', 'span']);
      expect(page.first((element) => element.name == 'span')!.text, 's');
      expect(page.first((element) => element.name == 'nothing'), isNull);
      expect(page.all((element) => element.name == 'nothing'), isEmpty);
      // A child answers before its own descendant.
      final nested = SteambroadcastHtml.parse('<div><p><i>x</i></p></div>');
      expect(nested.all((element) => element.children.isNotEmpty).map((element) => element.name).toList(), [
        'div',
        'p',
      ]);
    });

    test('a search finds what the page carries in an attribute', () {
      final page = SteambroadcastHtml.parse('<li data-id="7"><a href="/watch/7">x</a></li><li data-id="8"></li>');
      expect(
        page
            .all((element) => element.attributes['data-id'] != null)
            .map((element) => element.attributes['data-id'])
            .toList(),
        ['7', '8'],
      );
      expect(page.first((element) => element.attributes['data-id'] == '8')!.text, '');
      expect(page.first((element) => element.name == 'a')!.attributes['href'], '/watch/7');
    });
  });
}
