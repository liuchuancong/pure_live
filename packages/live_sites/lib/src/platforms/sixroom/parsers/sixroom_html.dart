import 'package:live_sites/src/common/normalization/html_entities.dart';

// Platform-internal code: constructor-name and doc verbosity rules that
// govern the public surface are relaxed here.
// ignore_for_file: unnecessary_type_name_in_constructor

/// Enough of an HTML tree for the search and room pages, in place of
/// package:html: comments, scripts and styles are dropped, elements nest by
/// their tags (void elements never hold children, end tags close the nearest
/// open element of their name), and text and attribute values have their
/// character references decoded. Unlike KilaKila's reader, an element knows
/// its parent — the search page tells a card's picture by an ancestor of the
/// image.
final class SixroomHtml {
  /// One element (or the root) of a parsed page.
  SixroomHtml(this.source, this.name, this.attributes, this.parent, this.start);

  /// The tree of [html] under a nameless root.
  factory SixroomHtml.parse(String html) {
    final source = html
        .replaceAll(RegExp(r'<!--[\s\S]*?(?:-->|$)'), '')
        .replaceAll(RegExp(r'<(script|style)\b[^>]*>[\s\S]*?(?:</\1\s*>|$)', caseSensitive: false), '');
    final root = SixroomHtml(source, '', const {}, null, 0);
    final open = <SixroomHtml>[root];
    for (final tag in _tag.allMatches(source)) {
      final name = tag.group(2)!.toLowerCase();
      if (tag.group(1)!.isEmpty) {
        final element = SixroomHtml(source, name, _attributes(tag.group(3)!), open.last, tag.end);
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

  /// The element's parent, or null for the root.
  final SixroomHtml? parent;

  /// Where the element's content starts.
  final int start;

  /// Where the element's content ends.
  int end = 0;

  /// The element's children, in document order.
  final List<SixroomHtml> children = [];

  /// The text inside the element, tags removed and references decoded.
  String get text => decodeHtmlEntities(source.substring(start, end).replaceAll(RegExp('<[^>]*>'), ''));

  /// Whether the element carries class [name].
  bool hasClass(String name) => (attributes['class'] ?? '').split(RegExp(r'\s+')).contains(name);

  Iterable<SixroomHtml> get _descendants sync* {
    for (final child in children) {
      yield child;
      yield* child._descendants;
    }
  }

  /// The descendants, in document order.
  Iterable<SixroomHtml> get descendants => _descendants;

  /// The first descendant, in document order, with class [name].
  SixroomHtml? firstWithClass(String name) => _descendants.where((element) => element.hasClass(name)).firstOrNull;

  /// The first descendant element called [tag].
  SixroomHtml? first(String tag) => _descendants.where((element) => element.name == tag).firstOrNull;
}
