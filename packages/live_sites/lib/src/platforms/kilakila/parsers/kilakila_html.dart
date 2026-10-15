// Platform-internal code: constructor-name and doc verbosity rules that
// govern the public surface are relaxed here.
// ignore_for_file: unnecessary_type_name_in_constructor

/// Enough of an HTML tree for the search page, in place of package:html:
/// comments, scripts and styles are dropped, elements nest by their tags
/// (void elements never hold children, end tags close the nearest open
/// element of their name), and text and attribute values have their
/// character references decoded.
final class KilakilaHtml {
  /// One element (or the root) of a parsed page.
  KilakilaHtml(this.source, this.name, this.attributes, this.start);

  /// The tree of [html] under a nameless root.
  factory KilakilaHtml.parse(String html) {
    final source = html
        .replaceAll(RegExp(r'<!--[\s\S]*?(?:-->|$)'), '')
        .replaceAll(RegExp(r'<(script|style)\b[^>]*>[\s\S]*?(?:</\1\s*>|$)', caseSensitive: false), '');
    final root = KilakilaHtml(source, '', const {}, 0);
    final open = <KilakilaHtml>[root];
    for (final tag in _tag.allMatches(source)) {
      final name = tag.group(2)!.toLowerCase();
      if (tag.group(1)!.isEmpty) {
        final element = KilakilaHtml(source, name, _attributes(tag.group(3)!), tag.end);
        open.last.children.add(element);
        if (_void.contains(name)) {
          element.end = tag.end;
        } else {
          open.add(element);
        }
        continue;
      }
      final index = open.lastIndexWhere((element) => element.name == name);
      if (index <= 0) continue;
      while (open.length > index) {
        open.removeLast().end = tag.start;
      }
    }
    for (final element in open) {
      element.end = source.length;
    }
    return root;
  }

  static final RegExp _tag = RegExp('<(/?)([A-Za-z][A-Za-z0-9:-]*)((?:[^>"\']|"[^"]*"|\'[^\']*\')*)>');
  static final RegExp _attribute = RegExp(r'''([^\s"'>/=]+)(?:\s*=\s*(?:"([^"]*)"|'([^']*)'|([^\s"'=<>`]+)))?''');
  static const Set<String> _void = {
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
    'source',
    'track',
    'wbr',
  };

  static Map<String, String> _attributes(String text) {
    final attributes = <String, String>{};
    for (final match in _attribute.allMatches(text)) {
      final value = match.group(2) ?? match.group(3) ?? match.group(4) ?? '';
      attributes.putIfAbsent(match.group(1)!.toLowerCase(), () => decodeHtmlEntities(value));
    }
    return attributes;
  }

  /// The page the element came from, its name, attributes and span.
  final String source;

  /// The element's tag, `''` for the root.
  final String name;

  /// The element's attributes, lower-cased names.
  final Map<String, String> attributes;

  /// Where the element's content starts.
  final int start;

  /// Where the element's content ends.
  int end = 0;

  /// The element's children, in document order.
  final List<KilakilaHtml> children = [];

  /// The text inside the element, tags removed and references decoded.
  String get text => decodeHtmlEntities(source.substring(start, end).replaceAll(RegExp('<[^>]*>'), ''));

  Iterable<KilakilaHtml> get _descendants sync* {
    for (final child in children) {
      yield child;
      yield* child._descendants;
    }
  }

  /// The first descendant, in document order, with class [name].
  KilakilaHtml? firstWithClass(String name) => _descendants
      .where((element) => (element.attributes['class'] ?? '').split(RegExp(r'\s+')).contains(name))
      .firstOrNull;

  /// The first descendant element called [tag].
  KilakilaHtml? first(String tag) => _descendants.where((element) => element.name == tag).firstOrNull;
}

/// Decodes the character references of a text or an attribute value (the
/// named ones the search page uses, and the numeric forms); the text itself
/// where nothing matches.
String decodeHtmlEntities(String text) {
  if (!text.contains('&')) return text;
  return text.replaceAllMapped(_entity, (match) {
    final named = _names[match.group(1)];
    if (named != null) return named;
    final numeric = match.group(2);
    if (numeric != null) {
      final code = numeric.startsWith('x') || numeric.startsWith('X')
          ? int.tryParse(numeric.substring(1), radix: 16)
          : int.tryParse(numeric);
      final scalar = code != null && code >= 0 && code <= 0x10FFFF ? String.fromCharCode(code) : null;
      if (scalar != null) return scalar;
    }
    return match.group(0)!;
  });
}

final RegExp _entity = RegExp('&([a-zA-Z][a-zA-Z0-9]{1,31});|&#([xX][0-9a-fA-F]+|[0-9]+);');

const Map<String, String> _names = {
  'amp': '&',
  'lt': '<',
  'gt': '>',
  'quot': '"',
  'apos': "'",
  'nbsp': '\u00a0',
  'copy': '\u00a9',
  'middot': '\u00b7',
  'hellip': '\u2026',
  'mdash': '\u2014',
  'ndash': '\u2013',
  'laquo': '\u00ab',
  'raquo': '\u00bb',
  'times': '\u00d7',
};
