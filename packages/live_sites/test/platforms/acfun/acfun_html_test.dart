import 'package:live_sites/src/platforms/acfun/parsers/acfun_html.dart';
import 'package:test/test.dart';

/// An author-search `html` fragment of the shape the acfun search endpoint
/// returns: a result count, then one `.search-up` card per author, each nesting
/// the avatar, the name link and the follower count the parser reads. The second
/// card and the entities in the exposure log mirror what the real page escapes.
const _searchFragment = '''
<div class="total-num" data-total="71">共71条结果</div>
<div class="search-up" data-up-exposure-log="{&quot;cid&quot;:1,&quot;uid&quot;:123,&quot;from&quot;:&quot;search&amp;page=1&quot;}">
  <div class="up__main">
    <div class="up__main__head">
      <img class="up__avatar" src="https://s/1.jpg">
      <div class="up__main__name">
        <a class="up__main__name__title" href="//www.acfun.cn/u/123">名字</a>
      </div>
      <div class="info__danmaku-count"><span>353.9万</span> 粉丝</div>
    </div>
  </div>
</div>
<div class="search-up" data-up-exposure-log="{&quot;cid&quot;:2,&quot;uid&quot;:456}">
  <div class="up__main">
    <div class="up__main__head">
      <img class="up__avatar" src="https://s/2.jpg">
      <div class="up__main__name">
        <a class="up__main__name__title" href="//www.acfun.cn/u/456">另一个名字</a>
      </div>
      <div class="info__danmaku-count"><span>12</span> 粉丝</div>
    </div>
  </div>
</div>
''';

/// The no-result answer: a zero count and the `empty-page` marker instead of
/// cards, so the parser can tell "no authors" from a broken fragment.
const _emptyFragment = '''
<div class="total-num" data-total="0">共0条结果</div>
<div class="empty-page">没有找到相关的UP主</div>
''';

void main() {
  group('search fragment', () {
    test('queryAll finds both cards in document order', () {
      final fragment = AcfunHtmlElement.parseFragment(_searchFragment);
      final cards = fragment.queryAll((element) => element.hasClass('search-up')).toList();
      expect(cards, hasLength(2));
      final hrefs = [for (final card in cards) card.query((element) => element.tag == 'a')!.attributes['href']];
      expect(hrefs, ['//www.acfun.cn/u/123', '//www.acfun.cn/u/456']);
    });

    test('query reads the result count from total-num', () {
      final fragment = AcfunHtmlElement.parseFragment(_searchFragment);
      final total = fragment.query((element) => element.hasClass('total-num'));
      expect(total, isNotNull);
      expect(total!.attributes['data-total'], '71');
      expect(total.text, '共71条结果');
    });

    test('the name link and avatar are read from a card', () {
      final fragment = AcfunHtmlElement.parseFragment(_searchFragment);
      final card = fragment.query((element) => element.hasClass('search-up'))!;
      final link = card.query((element) => element.hasClass('up__main__name__title'))!;
      expect(link.text, '名字');
      expect(link.attributes['href'], '//www.acfun.cn/u/123');
      expect(card.query((element) => element.hasClass('up__avatar'))!.attributes['src'], 'https://s/1.jpg');
    });

    test('text of a nested element concatenates its descendants', () {
      final fragment = AcfunHtmlElement.parseFragment(_searchFragment);
      final count = fragment.query((element) => element.hasClass('info__danmaku-count'))!;
      expect(count.text, '353.9万 粉丝');
    });

    test('the exposure log keeps its JSON with quotes and ampersands decoded', () {
      final fragment = AcfunHtmlElement.parseFragment(_searchFragment);
      final card = fragment.query((element) => element.hasClass('search-up'))!;
      expect(card.attributes['data-up-exposure-log'], '{"cid":1,"uid":123,"from":"search&page=1"}');
    });

    test('the empty-page variant has no cards but still a zero total', () {
      final fragment = AcfunHtmlElement.parseFragment(_emptyFragment);
      expect(fragment.queryAll((element) => element.hasClass('search-up')), isEmpty);
      expect(fragment.query((element) => element.hasClass('empty-page')), isNotNull);
      expect(fragment.query((element) => element.hasClass('total-num'))!.attributes['data-total'], '0');
    });
  });

  group('character references', () {
    test('attribute values decode named, decimal and hex references', () {
      final fragment = AcfunHtmlElement.parseFragment('<a data-info="A&amp;B&#39;&#x4e2d;&unknown;">x</a>');
      expect(fragment.query((element) => element.tag == 'a')!.attributes['data-info'], "A&B'中&unknown;");
    });

    test('text nodes are decoded too', () {
      final fragment = AcfunHtmlElement.parseFragment('<p>a &amp; b &nbsp;c</p>');
      expect(fragment.query((element) => element.tag == 'p')!.text, 'a & b \u{A0}c');
    });

    test('the helper decodes codes and leaves unknown names as written', () {
      expect(acfunHtmlEntities('&lt;&gt;&quot;&#39;&#x4e2d;&nbsp;&hellip;'), '<>"\'\u{4E2D}\u{A0}\u{2026}');
      expect(acfunHtmlEntities('&unknown; & no-ref'), '&unknown; & no-ref');
    });

    test('a code above U+10FFFF is left as written rather than corrupted', () {
      expect(acfunHtmlEntities('&#x110000;&#x4e2d;'), '&#x110000;中');
    });
  });

  group('tolerant tokenizer', () {
    test('a void img does not swallow its siblings', () {
      final fragment = AcfunHtmlElement.parseFragment('<p><img src="a.jpg">after</p>');
      final p = fragment.query((element) => element.tag == 'p')!;
      expect(p.children.map((element) => element.tag), ['img']);
      expect(p.text, 'after');
      expect(p.query((element) => element.tag == 'img')!.attributes['src'], 'a.jpg');
    });

    test('a raw script runs to its own close tag and its body is not decoded', () {
      final fragment = AcfunHtmlElement.parseFragment(
        '<div>one</div><script>if (a<b) { var s = "&amp;"; }</script><div>two</div>',
      );
      final divs = fragment.queryAll((element) => element.tag == 'div').toList();
      expect(divs, hasLength(2));
      expect(divs.first.text, 'one');
      expect(divs.last.text, 'two');
      final script = fragment.query((element) => element.tag == 'script')!;
      expect(script.text, 'if (a<b) { var s = "&amp;"; }');
    });

    test('a raw textarea keeps its close tag boundary but is decoded', () {
      final fragment = AcfunHtmlElement.parseFragment('<textarea>a &amp; b</textarea>');
      expect(fragment.query((element) => element.tag == 'textarea')!.text, 'a & b');
    });

    test('a stray end tag with no matching open element is ignored', () {
      final fragment = AcfunHtmlElement.parseFragment('<p>hi</p></div><span>ok</span>');
      expect(fragment.query((element) => element.tag == 'p')!.text, 'hi');
      expect(fragment.query((element) => element.tag == 'span')!.text, 'ok');
    });

    test('an unclosed element ends with the fragment', () {
      final fragment = AcfunHtmlElement.parseFragment('<div class="open"><b>1</b>2');
      final div = fragment.query((element) => element.hasClass('open'))!;
      expect(div.text, '12');
      expect(div.children.map((element) => element.tag), ['b']);
    });

    test('a lone < that starts no tag stays text', () {
      expect(AcfunHtmlElement.parseFragment('a < b').text, 'a < b');
    });

    test('a comment is skipped', () {
      final fragment = AcfunHtmlElement.parseFragment('<p>before<!-- note -->after</p>');
      expect(fragment.query((element) => element.tag == 'p')!.text, 'beforeafter');
    });

    test('a quoted attribute may contain the tag-closing >', () {
      final fragment = AcfunHtmlElement.parseFragment('<a title="x > y" class="q">t</a>');
      final a = fragment.query((element) => element.hasClass('q'))!;
      expect(a.attributes['title'], 'x > y');
      expect(a.text, 't');
    });

    test('the first of two repeated attributes wins', () {
      final fragment = AcfunHtmlElement.parseFragment('<div class="first" class="second">x</div>');
      final div = fragment.query((element) => element.tag == 'div')!;
      expect(div.attributes['class'], 'first');
      expect(div.hasClass('first'), isTrue);
      expect(div.hasClass('second'), isFalse);
    });

    test('a self-closing tag closes at once', () {
      final fragment = AcfunHtmlElement.parseFragment('<span class="s"/>tail');
      expect(fragment.query((element) => element.hasClass('s'))!.children, isEmpty);
      expect(fragment.text, 'tail');
    });
  });

  group('traversal', () {
    test('ancestors yields the enclosing elements nearest first', () {
      final fragment = AcfunHtmlElement.parseFragment(_searchFragment);
      final link = fragment.query((element) => element.hasClass('up__main__name__title'))!;
      expect(link.tag, 'a');
      expect(link.ancestors.first.hasClass('up__main__name'), isTrue);
      expect(link.ancestors.map((element) => element.tag).toList(), ['div', 'div', 'div', 'div', '#fragment']);
    });

    test('the fragment root reports its tag and has no parent', () {
      final fragment = AcfunHtmlElement.parseFragment(_searchFragment);
      expect(fragment.tag, '#fragment');
      expect(fragment.parent, isNull);
      expect(fragment.attributes, isEmpty);
      expect(fragment.children.first.tag, 'div');
      expect('$fragment', 'AcfunHtmlElement(#fragment)');
    });

    test("descendants are a card's elements in document order", () {
      final fragment = AcfunHtmlElement.parseFragment(_searchFragment);
      final card = fragment.query((element) => element.hasClass('search-up'))!;
      expect(card.descendants.map((element) => element.tag).toList(), ['div', 'div', 'img', 'div', 'a', 'div', 'span']);
    });
  });
}
