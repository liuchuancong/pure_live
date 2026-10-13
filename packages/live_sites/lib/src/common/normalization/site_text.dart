/// Text normalization shared by every adapter.
///
/// Platforms hand back titles and names as HTML: markup from a search hit
/// (`<em>keyword</em>`) and escaped entities (`&quot;`, `&amp;`, `&#39;`).
/// Rendering either literally is the most common cosmetic defect in a live
/// client, so both live here instead of being re-derived per site — the
/// copies that existed before disagreed on which entities they knew.
abstract final class SiteText {
  /// The entity replacements, longest first so `&amp;quot;` decodes once.
  static const Map<String, String> _entities = {
    '&amp;': '&',
    '&quot;': '"',
    '&#39;': "'",
    '&apos;': "'",
    '&nbsp;': ' ',
    '&lt;': '<',
    '&gt;': '>',
  };

  static final RegExp _highlight = RegExp('<em[^>]*>|</em>', caseSensitive: false);
  static final RegExp _anyTag = RegExp('<[^>]+>');

  /// A field as text, with null and non-string values flattened.
  static String text(Object? value) => value?.toString() ?? '';

  /// [value] as text, trimmed; the empty string when there is nothing.
  static String trimmed(Object? value) => text(value).trim();

  /// Decodes the HTML entities a platform escaped into a text field.
  ///
  /// Applied after tag stripping, so `&amp;lt;` still ends up as `&lt;`
  /// rather than as a tag.
  static String unescape(String value) {
    if (!value.contains('&')) {
      return value;
    }
    var result = value;
    for (final entry in _entities.entries) {
      result = result.replaceAll(entry.key, entry.value);
    }
    return result;
  }

  /// Removes the `<em>` highlights a search result wraps its keywords in.
  static String stripHighlights(String value) => value.replaceAll(_highlight, '');

  /// Strips every tag, for a platform that returns markup rather than a
  /// highlighted plain string.
  static String stripTags(String value) => value.replaceAll(_anyTag, '');

  /// The usual title pipeline: strip highlights, strip leftover tags, decode
  /// entities, collapse whitespace.
  static String title(String value) =>
      unescape(stripTags(stripHighlights(value))).replaceAll(RegExp(r'\s+'), ' ').trim();

  /// The first non-empty of [primary] and [fallback], each cleaned by
  /// [title]; the empty string when both are.
  static String titleFrom(Object? primary, Object? fallback) {
    final first = title(trimmed(primary));
    return first.isNotEmpty ? first : title(trimmed(fallback));
  }

  /// Code units a platform leaves in display text where it had a picture or a
  /// control, and that fonts draw as a box: the object replacement char (0xFFFC,
  /// Kuaishou keeps it for an embedded image), the interlinear annotation marks
  /// (0xFFF9..0xFFFB), the noncharacters (0xFFFE, 0xFFFF) and the C0/C1 controls
  /// except tab, line feed and carriage return. Meaningful invisible units stay:
  /// the zero-width space and joiners, the BOM, and the visible replacement char.
  static final Set<int> _invisiblePlaceholderCodes = {
    for (var code = 0x00; code <= 0x08; code++) code,
    0x0B,
    0x0C,
    for (var code = 0x0E; code <= 0x1F; code++) code,
    for (var code = 0x7F; code <= 0x9F; code++) code,
    for (var code = 0xFFF9; code <= 0xFFFC; code++) code,
    0xFFFE,
    0xFFFF,
  };

  /// [text] without invisible placeholder characters; the same string when it
  /// has none. Applied to titles, names, introductions and notices so no
  /// platform has to.
  static String stripInvisiblePlaceholders(String text) {
    if (!text.runes.any(_invisiblePlaceholderCodes.contains)) return text;
    final buffer = StringBuffer();
    for (final code in text.runes) {
      if (!_invisiblePlaceholderCodes.contains(code)) buffer.writeCharCode(code);
    }
    return buffer.toString();
  }

  /// [stripInvisiblePlaceholders] of a nullable [text].
  static String? stripInvisiblePlaceholdersOrNull(String? text) =>
      text == null ? null : stripInvisiblePlaceholders(text);
}
