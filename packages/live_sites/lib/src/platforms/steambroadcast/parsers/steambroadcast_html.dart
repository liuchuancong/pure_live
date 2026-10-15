import 'package:live_sites/src/common/normalization/html_entities.dart';

// Platform-internal code: constructor-name and doc verbosity rules that
// govern the public surface are relaxed here.
// ignore_for_file: unnecessary_type_name_in_constructor

/// Enough of an HTML tree for the trending broadcasts and the watch page, in
/// place of package:html: comments, scripts and styles are dropped, elements
/// nest by their tags (void elements never hold children, end tags close the
/// nearest open element of their name), and text and attribute values have
/// their character references decoded.
final class SteambroadcastHtml {
  /// One element (or the root) of a parsed page.
  SteambroadcastHtml(this.source, this.name, this.attributes, this.start);

  /// The tree of [html] under a nameless root.
  factory SteambroadcastHtml.parse(String html) {
    final source = html
        .replaceAll(RegExp(r'<!--[\s\S]*?(?:-->|$)'), '')
        .replaceAll(RegExp(r'<(script|style)\b[^>]*>[\s\S]*?(?:</\1\s*>|$)', caseSensitive: false), '');
    final root = SteambroadcastHtml(source, '', const {}, 0);
    final open = <SteambroadcastHtml>[root];
    for (final tag in _tag.allMatches(source)) {
      final name = tag.group(2)!.toLowerCase();
      if (tag.group(1)!.isEmpty) {
        final element = SteambroadcastHtml(source, name, _attributes(tag.group(3)!), tag.end)..parent = open.last;
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

  /// The element's parent, null for the root.
  SteambroadcastHtml? parent;

  /// The element's children, in document order.
  final List<SteambroadcastHtml> children = [];

  /// The text inside the element, tags removed and references decoded.
  String get text => decodeHtmlEntities(source.substring(start, end).replaceAll(RegExp('<[^>]*>'), ''));

  /// Whether the element's `class` names [name].
  bool hasClass(String name) => (attributes['class'] ?? '').split(RegExp(r'\s+')).contains(name);

  /// Whether an element above this one (the root excluded) has class [name].
  bool insideClass(String name) {
    for (var element = parent; element != null && element.name.isNotEmpty; element = element.parent) {
      if (element.hasClass(name)) return true;
    }
    return false;
  }

  Iterable<SteambroadcastHtml> get _descendants sync* {
    for (final child in children) {
      yield child;
      yield* child._descendants;
    }
  }

  /// The descendants, in document order, that satisfy [test].
  List<SteambroadcastHtml> all(bool Function(SteambroadcastHtml element) test) =>
      _descendants.where(test).toList(growable: false);

  /// The first descendant, in document order, that satisfies [test].
  SteambroadcastHtml? first(bool Function(SteambroadcastHtml element) test) => _descendants.where(test).firstOrNull;
}
