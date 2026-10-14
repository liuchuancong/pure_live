/// A small, tolerant reader of server-rendered HTML fragments for the AcFun
/// adapter. AcFun's author search (`www.acfun.cn/search?...&ajaxpipe=1`) answers
/// with BigPipe JSON whose `html` field is a fragment of author cards, not a
/// document; this builds an element tree from that fragment so the search parser
/// can find cards by class, read their attributes and take their text. It stays
/// dependency-free on purpose (this package deliberately pulls in no
/// `package:html`), it never runs scripts (their bodies are kept as text), and it
/// is lenient about the platform's own markup: unclosed elements end with the
/// fragment and stray end tags are dropped rather than raising.
library;

// Platform-internal code: the constructor-name rule that governs the public
// surface is relaxed here, as elsewhere in the acfun adapter.
// ignore_for_file: unnecessary_type_name_in_constructor

/// Elements that never have content or an end tag; opening one closes it at once,
/// so a void `img` or `br` cannot swallow its siblings.
const _voidElements = {
  'area',
  'base',
  'br',
  'col',
  'embed',
  'hr',
  'img',
  'input',
  'link',
  'meta',
  'param',
  'source',
  'track',
  'wbr',
};

/// Elements whose content is raw text up to their own end tag; their bodies are
/// not re-tokenized, which is why a `<script>` holding `a < b` does not break the
/// tree.
const _rawTextElements = {'script', 'style', 'textarea', 'title'};

/// The leading characters of a tag name: a letter, then anything that is not
/// whitespace, `/` or `>`; matched as a prefix so a name stops at the next
/// delimiter.
final RegExp _tagName = RegExp(r'[a-zA-Z][^\s/>]*');

/// A bare attribute name: not whitespace, a quote, `>`, `/` or `=`, so it stops
/// at the `=` that introduces its value.
final RegExp _attributeName = RegExp('[^\\s"\'>/=]+');

/// An unquoted attribute value: run to the next whitespace or the tag's `>`, so a
/// `>` inside the value would end it (a quoted value is used for those).
final RegExp _unquoted = RegExp(r'[^\s>]+');

/// The separators between the names of a `class` attribute.
final RegExp _spaces = RegExp(r'\s+');

/// The character-reference pattern the reference reader recognised: a `&#x…;`
/// hexadecimal code, a `&#…;` decimal code or a `&name;`. The body is captured so
/// [acfunHtmlEntities] can tell which of the three it is; a reference with no
/// closing `;` is left alone, as are unknown names.
final RegExp _entity = RegExp('&(#x[0-9a-fA-F]+|#[0-9]+|[a-zA-Z]+);');

/// The named character references AcFun's fragments were observed to use, ported
/// from the reference reader's table; anything outside it stays written as the
/// server sent it. Values are written as code points so the spacing entities
/// decode to their real characters (`&nbsp;` to U+00A0, not a plain space) that a
/// later text comparison would otherwise silently mistake for one another.
const Map<String, String> _namedEntities = {
  'amp': '&',
  'lt': '<',
  'gt': '>',
  'quot': '"',
  'apos': "'",
  'nbsp': '\u{A0}',
  'ensp': '\u{2002}',
  'emsp': '\u{2003}',
  'thinsp': '\u{2009}',
  'mdash': '\u{2014}',
  'ndash': '\u{2013}',
  'hellip': '\u{2026}',
  'middot': '\u{B7}',
  'times': '\u{D7}',
  'ldquo': '\u{201C}',
  'rdquo': '\u{201D}',
  'lsquo': '\u{2018}',
  'rsquo': '\u{2019}',
  'yen': '\u{A5}',
  'copy': '\u{A9}',
  'reg': '\u{AE}',
};

/// Decodes HTML character references in [text] so the search parser compares
/// readable text: `&amp;`, `&nbsp;`, `&ensp;` and the like from [_namedEntities],
/// plus numeric `&#39;` and `&#x4e2d;`. A code above U+10FFFF (a value no UTF
/// scalar can hold) and an unknown name such as `&unknown;` are left written as
/// they came, so a mis-decode never corrupts the card's own text.
///
/// Fragment text and attribute values are decoded by [AcfunHtmlElement]; a raw
/// `<script>` or `<style>` body is the one place [text] keeps them undecoded,
/// because that markup is code rather than prose.
String acfunHtmlEntities(String text) {
  if (!text.contains('&')) return text;
  return text.replaceAllMapped(_entity, (match) {
    final body = match.group(1)!;
    if (body.startsWith('#x') || body.startsWith('#X')) {
      final code = int.tryParse(body.substring(2), radix: 16);
      return code == null || code > 0x10FFFF ? match.group(0)! : String.fromCharCode(code);
    }
    if (body.startsWith('#')) {
      final code = int.tryParse(body.substring(1));
      return code == null || code > 0x10FFFF ? match.group(0)! : String.fromCharCode(code);
    }
    return _namedEntities[body] ?? match.group(0)!;
  });
}

/// One element of an AcFun HTML fragment, the unit the search parser selects on.
///
/// A node owns its [tag], [attributes] and the [children] built while it was the
/// innermost open element; [parent] links back up so a card can ask what encloses
/// a link. The tree is assembled by [parseFragment], never on its own, so a
/// [AcfunHtmlElement] always belongs to a parsed fragment (rooted at `#fragment`).
final class AcfunHtmlElement {
  /// A node of [tag] with [attributes] inside [parent]; the tree is grown by
  /// [parseFragment], which is the only way to obtain one.
  AcfunHtmlElement._(this.tag, this.attributes, this.parent);

  /// Parses the AcFun fragment [html] into a root reported as tag `#fragment`.
  ///
  /// Tolerant by design, because the fragment is machine-generated markup this
  /// adapter cannot fix: unclosed elements simply end with the fragment, a stray
  /// end tag with no matching open element is ignored, and a `<` that begins no
  /// tag (as inside a `script` body, which runs untouched to its own close tag)
  /// is kept as text. Comments, doCTYPEs and processing instructions are skipped;
  /// `/>` closes an element at once.
  static AcfunHtmlElement parseFragment(String html) {
    final root = AcfunHtmlElement._('#fragment', const {}, null);
    final open = <AcfunHtmlElement>[root];
    var index = 0;
    final text = StringBuffer();

    void flushText() {
      if (text.isEmpty) return;
      open.last._content.add(acfunHtmlEntities(text.toString()));
      text.clear();
    }

    while (index < html.length) {
      final lt = html.indexOf('<', index);
      if (lt < 0) {
        text.write(html.substring(index));
        break;
      }
      text.write(html.substring(index, lt));
      index = lt;
      if (html.startsWith('<!--', index)) {
        flushText();
        final end = html.indexOf('-->', index + 4);
        index = end < 0 ? html.length : end + 3;
        continue;
      }
      if (html.startsWith('</', index)) {
        final name = _tagName.matchAsPrefix(html, index + 2);
        if (name == null) {
          text.write('<');
          index++;
          continue;
        }
        flushText();
        final end = html.indexOf('>', name.end);
        index = end < 0 ? html.length : end + 1;
        final tag = name.group(0)!.toLowerCase();
        final at = open.lastIndexWhere((element) => element.tag == tag);
        // `at > 0` keeps the fragment root (index 0) always open, so a stray end
        // tag for a never-opened element (`at < 0`) is just dropped.
        if (at > 0) open.removeRange(at, open.length);
        continue;
      }
      if (html.startsWith('<!', index) || html.startsWith('<?', index)) {
        flushText();
        final end = html.indexOf('>', index);
        index = end < 0 ? html.length : end + 1;
        continue;
      }
      final name = _tagName.matchAsPrefix(html, index + 1);
      if (name == null) {
        text.write('<');
        index++;
        continue;
      }
      flushText();
      final tag = name.group(0)!.toLowerCase();
      final attributes = <String, String>{};
      var cursor = name.end;
      var selfClosing = false;
      while (cursor < html.length) {
        while (cursor < html.length && html[cursor].trim().isEmpty) {
          cursor++;
        }
        if (cursor >= html.length) break;
        if (html[cursor] == '>') {
          cursor++;
          break;
        }
        if (html.startsWith('/>', cursor)) {
          selfClosing = true;
          cursor += 2;
          break;
        }
        final attribute = _attributeName.matchAsPrefix(html, cursor);
        if (attribute == null) {
          cursor++;
          continue;
        }
        cursor = attribute.end;
        var value = '';
        var probe = cursor;
        while (probe < html.length && html[probe].trim().isEmpty) {
          probe++;
        }
        if (probe < html.length && html[probe] == '=') {
          probe++;
          while (probe < html.length && html[probe].trim().isEmpty) {
            probe++;
          }
          if (probe < html.length && (html[probe] == '"' || html[probe] == "'")) {
            // A quoted value may hold the tag's own `>`; read to the matching
            // quote so `title="a > b"` stays one attribute.
            final close = html.indexOf(html[probe], probe + 1);
            final end = close < 0 ? html.length : close;
            value = html.substring(probe + 1, end);
            cursor = close < 0 ? html.length : close + 1;
          } else {
            final bare = _unquoted.matchAsPrefix(html, probe);
            value = bare?.group(0) ?? '';
            cursor = bare?.end ?? probe;
          }
        }
        // putIfAbsent: the first of a repeated attribute wins, matching browsers.
        attributes.putIfAbsent(attribute.group(0)!.toLowerCase(), () => acfunHtmlEntities(value));
      }
      index = cursor;
      final element = AcfunHtmlElement._(tag, Map.unmodifiable(attributes), open.last);
      open.last._content.add(element);
      if (selfClosing || _voidElements.contains(tag)) continue;
      if (_rawTextElements.contains(tag)) {
        final close = RegExp('</$tag', caseSensitive: false).allMatches(html, index);
        final start = close.isEmpty ? -1 : close.first.start;
        final end = start < 0 ? html.length : start;
        if (end > index) {
          final raw = html.substring(index, end);
          // script and style hold code, not prose, so their body is kept as the
          // server wrote it; textarea and title are text and get decoded.
          element._content.add(tag == 'script' || tag == 'style' ? raw : acfunHtmlEntities(raw));
        }
        final after = start < 0 ? -1 : html.indexOf('>', start);
        index = after < 0 ? html.length : after + 1;
        continue;
      }
      open.add(element);
    }
    flushText();
    return root;
  }

  /// The tag name in lower case; `#fragment` for a [parseFragment] root, which is
  /// never a real tag so it can be told from the elements it holds.
  final String tag;

  /// Attributes by lower-case name with character references decoded through
  /// [acfunHtmlEntities]; the first of a repeated attribute wins, as in browsers,
  /// so a card's `class` cannot be overridden by a later duplicate.
  final Map<String, String> attributes;

  /// The enclosing element, or null for a [parseFragment] root; [ancestors] walks
  /// this chain so a selected node can ask what encloses it.
  final AcfunHtmlElement? parent;

  /// Content in document order: text ([String]) and child elements interleaved as
  /// parsed, so [text] can read the element's prose with the tags it strips.
  final List<Object> _content = [];

  /// The child elements in document order, text nodes skipped.
  Iterable<AcfunHtmlElement> get children => _content.whereType<AcfunHtmlElement>();

  /// Every element inside this one in document order, breadth-then-depth per
  /// child; the pool [query] and [queryAll] select from.
  Iterable<AcfunHtmlElement> get descendants sync* {
    for (final child in children) {
      yield child;
      yield* child.descendants;
    }
  }

  /// The enclosing elements, nearest first, up to but excluding this one; lets a
  /// card match an `<a>` by whether its ancestor chain touches a known wrapper.
  Iterable<AcfunHtmlElement> get ancestors sync* {
    for (var node = parent; node != null; node = node.parent) {
      yield node;
    }
  }

  /// The names in the `class` attribute as a set; the search parser identifies a
  /// card by [hasClass] rather than comparing the raw, ordering-sensitive string.
  Set<String> get classes => {
    for (final name in (attributes['class'] ?? '').split(_spaces))
      if (name.isNotEmpty) name,
  };

  /// Whether the `class` attribute lists [name].
  bool hasClass(String name) => classes.contains(name);

  /// The element's text with its descendants' text concatenated (the DOM's
  /// `textContent`), references already decoded — so a follower count spread over
  /// a nested span reads back as one string.
  String get text {
    final buffer = StringBuffer();
    void collect(AcfunHtmlElement element) {
      for (final node in element._content) {
        if (node is String) {
          buffer.write(node);
        } else {
          collect(node as AcfunHtmlElement);
        }
      }
    }

    collect(this);
    return buffer.toString();
  }

  /// The first descendant in document order that passes [test], or null; used for
  /// a single value such as a card's result count.
  AcfunHtmlElement? query(bool Function(AcfunHtmlElement element) test) {
    for (final element in descendants) {
      if (test(element)) return element;
    }
    return null;
  }

  /// Every descendant in document order that passes [test], lazily; the search
  /// parser maps each matching card to a room in the order the server sent them.
  Iterable<AcfunHtmlElement> queryAll(bool Function(AcfunHtmlElement element) test) => descendants.where(test);

  @override
  String toString() => 'AcfunHtmlElement($tag${attributes.isEmpty ? '' : ' $attributes'})';
}
