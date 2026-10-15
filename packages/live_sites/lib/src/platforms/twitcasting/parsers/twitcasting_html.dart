// Platform-internal code: constructor-name and doc verbosity rules that
// govern the public surface are relaxed here.
// ignore_for_file: unnecessary_type_name_in_constructor

/// A start tag of a [TwitcastingHtml] page.
final class TwitcastingTag {
  /// Creates the tag.
  TwitcastingTag(this.name, this.attributes, this.contentStart);

  /// Lower-case element name.
  final String name;

  /// Attributes by lower-case name, values with character references decoded.
  final Map<String, String> attributes;

  /// Where the element's content starts (after `>`).
  final int contentStart;

  /// Whether the element's class attribute names [name].
  bool hasClass(String name) => (attributes['class'] ?? '').split(TwitcastingHtml.space).contains(name);
}

/// Just enough of an HTML reader for the TwitCasting pages' selectors (tag,
/// class, attribute, descendant), in place of package:html; 3.x used the same
/// readings on them. Scripts, styles and comments are blanked first, so
/// markup inside them never matches.
final class TwitcastingHtml {
  /// Reads [source]; line breaks are normalized first, as an HTML parser
  /// does (CR LF and CR become LF).
  factory TwitcastingHtml(String source) {
    final normalized = source.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
    return TwitcastingHtml._(normalized.replaceAllMapped(_raw, (match) => ' ' * match.group(0)!.length), normalized);
  }

  TwitcastingHtml._(this.text, this.source);

  /// The page with scripts, styles and comments blanked.
  final String text;

  /// The page as it came, references still encoded.
  final String source;

  final Map<TwitcastingTag, int> _ends = {};

  /// Whitespace, split by [TwitcastingTag.hasClass].
  static final RegExp space = RegExp(r'\s+');

  static final RegExp _raw = RegExp(r'<!--[\s\S]*?-->|<(script|style)\b[^>]*>[\s\S]*?</\1\s*>', caseSensitive: false);
  static final RegExp _startTag = RegExp('''<([a-zA-Z][a-zA-Z0-9-]*)((?:[^>"']|"[^"]*"|'[^']*')*)>''');
  static final RegExp _attribute = RegExp(r'''([^\s=/>"']+)(?:\s*=\s*(?:"([^"]*)"|'([^']*)'|([^\s>"']+)))?''');
  static final RegExp _anyTag = RegExp('<[^>]*>');
  static final RegExp _tagToken = RegExp('''<(/?)([a-zA-Z][a-zA-Z0-9-]*)((?:[^>"']|"[^"]*"|'[^']*')*)>''');
  static const Set<String> _void = {
    'area', 'base', 'br', 'col', 'embed', 'hr', 'img', //
    'input', 'link', 'meta', 'source', 'wbr',
  };

  /// Start tags between [from] and [to], in document order.
  Iterable<TwitcastingTag> tags({int from = 0, int? to}) sync* {
    for (final match in _startTag.allMatches(text, from)) {
      if (to != null && match.start >= to) return;
      final attributes = <String, String>{};
      for (final attribute in _attribute.allMatches(match.group(2)!)) {
        final value = attribute.group(2) ?? attribute.group(3) ?? attribute.group(4) ?? '';
        attributes.putIfAbsent(attribute.group(1)!.toLowerCase(), () => decodeHtmlEntities(value));
      }
      yield TwitcastingTag(match.group(1)!.toLowerCase(), attributes, match.end);
    }
  }

  /// The first tag passing [test], inside [within] when given.
  TwitcastingTag? first(bool Function(TwitcastingTag tag) test, {TwitcastingTag? within}) {
    for (final tag in _scope(within)) {
      if (test(tag)) return tag;
    }
    return null;
  }

  /// Every tag passing [test], inside [within] when given.
  List<TwitcastingTag> all(bool Function(TwitcastingTag tag) test, {TwitcastingTag? within}) => [
    for (final tag in _scope(within))
      if (test(tag)) tag,
  ];

  Iterable<TwitcastingTag> _scope(TwitcastingTag? within) =>
      within == null ? tags() : tags(from: within.contentStart, to: _end(within));

  /// The text of [tag]'s element, character references decoded.
  String textOf(TwitcastingTag tag) =>
      decodeHtmlEntities(source.substring(tag.contentStart, _end(tag)).replaceAll(_anyTag, ''));

  /// The text directly inside [tag]'s element, not inside the elements it
  /// holds (scripts, styles and comments count as blank), character
  /// references decoded.
  String ownText(TwitcastingTag tag) {
    final end = _end(tag);
    final buffer = StringBuffer();
    var depth = 0;
    var position = tag.contentStart;
    for (final match in _tagToken.allMatches(text, tag.contentStart)) {
      if (match.start >= end) break;
      if (depth == 0) buffer.write(text.substring(position, match.start));
      position = match.end;
      final name = match.group(2)!.toLowerCase();
      if (match.group(1)!.isNotEmpty) {
        if (depth > 0) depth--;
      } else if (!_void.contains(name) && !match.group(3)!.trimRight().endsWith('/')) {
        depth++;
      }
    }
    if (depth == 0 && position < end) buffer.write(text.substring(position, end));
    return decodeHtmlEntities(buffer.toString());
  }

  /// Where [tag]'s element closes: its matching end tag, counting nested
  /// elements of the same name; the end of the page when it never closes.
  int _end(TwitcastingTag tag) => _ends[tag] ??= () {
    if (_void.contains(tag.name)) return tag.contentStart;
    final pattern = RegExp('<(/?)${RegExp.escape(tag.name)}(?=[\\s/>])[^>]*>', caseSensitive: false);
    var depth = 1;
    for (final match in pattern.allMatches(text, tag.contentStart)) {
      depth += match.group(1)!.isEmpty ? 1 : -1;
      if (depth == 0) return match.start;
    }
    return text.length;
  }();
}

/// Decodes the character references of a text or an attribute value (the
/// named ones the TwitCasting pages use, and the numeric forms); the text
/// itself where nothing matches.
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
