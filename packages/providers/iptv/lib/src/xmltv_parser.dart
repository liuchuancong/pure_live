// Module: lib/src/xmltv_parser.dart
// Purpose: Parses XMLTV EPG documents into a guide that answers "what is on now" and "what is next".
// Author: liuchuancong
// Created: 2026-10-09
//
// XMLTV is the one EPG format IPTV lists ship (docs/sources/iptv/). The parser walks elements with a
// lightweight scan instead of a full XML stack because the DTD fixes the element names; malformed entries are
// skipped and counted, never half-parsed.
//
// The scan reads attributes **by name, in any order**, and accepts a self-closing element. Both were load
// bearing: the previous patterns hard-coded `<programme start=… stop=… channel=…>` order and required a closing
// tag, and real guides write `channel=` first or omit the description entirely - a normal file parsed into zero
// programmes and reported nothing wrong, which is the worst shape a parser can have.

/// One channel declaration: its xmltv id, display names and icon.
final class XmltvChannel {
  const XmltvChannel({required this.id, required this.names, this.icon});

  final String id;
  final List<String> names;

  /// Best display name: the first declared one.
  String get name => names.isEmpty ? id : names.first;
  final String? icon;
}

/// One programme row, times already parsed to UTC.
final class XmltvProgramme {
  const XmltvProgramme({
    required this.channelId,
    required this.start,
    required this.stop,
    required this.title,
    this.description,
    this.icon,
    this.category,
  });

  final String channelId;
  final DateTime start;
  final DateTime stop;
  final String title;
  final String? description;
  final String? icon;

  /// The first `<category>`, which is how a guide labels "News" or "Movies".
  final String? category;

  bool airsAt(DateTime at) => !at.isBefore(start) && at.isBefore(stop);

  /// Inclusive end minus start, for a grid cell.
  Duration get length => stop.difference(start);

  @override
  String toString() => 'XmltvProgramme($channelId $start..$stop $title)';
}

/// The whole guide: channels plus programmes grouped by channel id.
final class XmltvGuide {
  const XmltvGuide({required this.channels, required this.programmes, this.skippedEntries = 0, this.truncated = false});

  final List<XmltvChannel> channels;
  final Map<String, List<XmltvProgramme>> programmes;

  /// Elements the parser could not use - a programme with no parsable start, a channel with no id.
  ///
  /// Counted rather than silent, because "the guide is empty" and "the guide is 40 % malformed" look identical
  /// on screen and need different fixes.
  final int skippedEntries;

  /// True when a bound stopped the parse, so the guide covers only the head of the document.
  final bool truncated;

  bool get isEmpty => channels.isEmpty && programmes.isEmpty;

  int get programmeCount => programmes.values.fold(0, (sum, rows) => sum + rows.length);

  /// What airs on [channelId] at [at], when the guide knows.
  XmltvProgramme? nowOn(String channelId, DateTime at) {
    final rows = programmes[channelId];
    if (rows == null) {
      return null;
    }
    final wanted = at.toUtc();
    for (final row in rows) {
      if (row.airsAt(wanted)) {
        return row;
      }
    }
    return null;
  }

  /// The rows on [channelId] from [from] on, soonest first, capped at [limit].
  ///
  /// Bounded by argument: a day of one channel is a list, a two-week guide across 300 channels is not one
  /// anything can render.
  List<XmltvProgramme> upcoming(String channelId, DateTime from, {int limit = 24}) {
    final rows = programmes[channelId];
    if (rows == null || limit < 1) {
      return const <XmltvProgramme>[];
    }
    final wanted = from.toUtc();
    final out = <XmltvProgramme>[];
    for (final row in rows) {
      if (row.start.isBefore(wanted)) {
        continue;
      }
      out.add(row);
      if (out.length >= limit) {
        break;
      }
    }
    return List<XmltvProgramme>.unmodifiable(out);
  }

  /// Every channel's row for [at], keyed by channel id - the grid's single "now" column.
  Map<String, XmltvProgramme> onAir(DateTime at, {int? limit}) {
    final wanted = at.toUtc();
    final out = <String, XmltvProgramme>{};
    for (final entry in programmes.entries) {
      for (final row in entry.value) {
        if (row.airsAt(wanted)) {
          out[entry.key] = row;
          break;
        }
      }
      if (limit != null && out.length >= limit) {
        break;
      }
    }
    return Map<String, XmltvProgramme>.unmodifiable(out);
  }

  /// The rows starting inside [from]..[to], across channels, soonest first, capped.
  List<XmltvProgramme> between(DateTime from, DateTime to, {int limit = 500}) {
    final start = from.toUtc();
    final stop = to.toUtc();
    if (!stop.isAfter(start)) {
      return const <XmltvProgramme>[];
    }
    final out = <XmltvProgramme>[];
    for (final rows in programmes.values) {
      for (final row in rows) {
        if (!row.start.isBefore(start) && row.start.isBefore(stop)) {
          out.add(row);
        }
      }
    }
    out.sort((left, right) => left.start.compareTo(right.start));
    return List<XmltvProgramme>.unmodifiable(out.take(limit < 1 ? 0 : limit));
  }

  /// The channel whose id or any display name matches [nameOrId].
  ///
  /// An M3U list says "CCTV-1综合" and the guide declares "CCTV 1 综合" plus a numeric id: joining on the name
  /// is the only key an M3U carries, so the lookup has to be forgiving about exactly that.
  XmltvChannel? channelFor(String nameOrId) {
    final wanted = nameOrId.trim();
    if (wanted.isEmpty) {
      return null;
    }
    final exact = wanted.toLowerCase();
    for (final channel in channels) {
      if (channel.id.toLowerCase() == exact) {
        return channel;
      }
    }
    for (final channel in channels) {
      final looseWanted = _loose(wanted);
      if (channel.names.any((name) => _loose(name) == looseWanted) || _loose(channel.id) == looseWanted) {
        return channel;
      }
    }
    return null;
  }

  /// The id to look programmes up under for a name an M3U gave.
  String? channelIdFor(String nameOrId) => channelFor(nameOrId)?.id;

  static String _loose(String value) => value.toLowerCase().replaceAll(RegExp(r'[\s\-_·•|]'), '');
}

/// Parses an XMLTV document.
final class XmltvParser {
  const XmltvParser({this.maxChannels = 20000, this.maxProgrammes = 200000});

  /// An EPG document is untrusted input fetched from a stranger's server: a bound is the only thing standing
  /// between a 300 MB guide and the app being killed for it.
  final int maxChannels;
  final int maxProgrammes;

  XmltvGuide parse(String text) {
    final channels = <XmltvChannel>[];
    final programmes = <XmltvProgramme>[];
    var skipped = 0;
    var truncated = false;

    for (final element in _scanElements(text, 'channel')) {
      final id = element.attributes['id'] ?? '';
      if (id.isEmpty) {
        skipped++;
        continue;
      }
      if (channels.length >= maxChannels) {
        truncated = true;
        break;
      }
      final names = <String>[
        for (final child in _scanElements(element.body, 'display-name'))
          if (child.text.isNotEmpty) _clean(child.text),
      ];
      final icons = _scanElements(element.body, 'icon');
      channels.add(XmltvChannel(id: id, names: names, icon: icons.isEmpty ? null : icons.first.attributes['src']));
    }

    for (final element in _scanElements(text, 'programme')) {
      final channelId = element.attributes['channel'] ?? '';
      final start = parseXmltvTime(element.attributes['start'] ?? '');
      final stop = parseXmltvTime(element.attributes['stop'] ?? '');
      final titles = _scanElements(element.body, 'title');
      final title = titles.isEmpty ? '' : _clean(titles.first.text);
      if (channelId.isEmpty || start == null || stop == null || title.isEmpty || !stop.isAfter(start)) {
        // A row whose end is not after its start would sit in every `between` query forever, and an
        // all-day placeholder row is common in free guides.
        skipped++;
        continue;
      }
      if (programmes.length >= maxProgrammes) {
        truncated = true;
        break;
      }
      final descriptions = _scanElements(element.body, 'desc');
      final categories = _scanElements(element.body, 'category');
      final icons = _scanElements(element.body, 'icon');
      programmes.add(
        XmltvProgramme(
          channelId: channelId,
          start: start,
          stop: stop,
          title: title,
          description: descriptions.isEmpty ? null : _emptyToNull(_clean(descriptions.first.text)),
          category: categories.isEmpty ? null : _emptyToNull(_clean(categories.first.text)),
          icon: icons.isEmpty ? null : icons.first.attributes['src'],
        ),
      );
    }

    final byChannel = <String, List<XmltvProgramme>>{};
    for (final row in programmes) {
      byChannel.putIfAbsent(row.channelId, () => <XmltvProgramme>[]).add(row);
    }
    for (final rows in byChannel.values) {
      rows.sort((a, b) => a.start.compareTo(b.start));
    }
    return XmltvGuide(channels: channels, programmes: byChannel, skippedEntries: skipped, truncated: truncated);
  }
}

/// XMLTV times are `20260109120000 +0800` - naive local plus an offset - and answers must be comparable, so
/// everything comes back UTC.
///
/// A guide whose stamps are 12 hours off is not caught by any other check here: it renders, and every "now"
/// query answers with the wrong programme.
DateTime? parseXmltvTime(String text) {
  final match = RegExp(r'^(\d{4})(\d{2})?(\d{2})?(\d{2})?(\d{2})?(\d{2})?(?:\s*([+-]\d{4}))?').firstMatch(text.trim());
  if (match == null) {
    return null;
  }
  final year = int.tryParse(match.group(1)!);
  final month = int.tryParse(match.group(2) ?? '1');
  final day = int.tryParse(match.group(3) ?? '1');
  final hour = int.tryParse(match.group(4) ?? '0');
  final minute = int.tryParse(match.group(5) ?? '0');
  final second = int.tryParse(match.group(6) ?? '0');
  if (year == null || month == null || day == null || hour == null || minute == null || second == null) {
    return null;
  }
  final DateTime naive;
  try {
    naive = DateTime.utc(year, month, day, hour, minute, second);
  } on ArgumentError {
    return null;
  }
  if (naive.year != year || naive.month != month || naive.day != day) {
    return null;
  }
  final offsetText = match.group(7);
  if (offsetText == null) {
    return naive;
  }
  final sign = offsetText.startsWith('-') ? -1 : 1;
  final offsetHours = int.tryParse(offsetText.substring(1, 3)) ?? 0;
  final offsetMinutes = int.tryParse(offsetText.substring(3, 5)) ?? 0;
  // A local time plus its offset is UTC by definition: subtract the offset the file declared.
  return naive.subtract(Duration(hours: sign * offsetHours, minutes: sign * offsetMinutes));
}

/// One scanned element: its attributes, its inner text and its raw body.
final class _XmlElement {
  const _XmlElement({required this.openTag, required this.attributes, required this.body, required this.text});

  final String openTag;
  final Map<String, String> attributes;

  /// Everything between the start and end tags; empty for a self-closing element.
  final String body;

  /// The element's own character data, child tags stripped.
  final String text;
}

/// Finds [name] elements in document order.
List<_XmlElement> _scanElements(String text, String name) {
  final out = <_XmlElement>[];
  final opener = '<$name';
  var from = 0;
  while (from < text.length) {
    final startTag = text.indexOf(opener, from);
    if (startTag < 0) {
      break;
    }
    final afterName = startTag + opener.length;
    if (afterName >= text.length) {
      break;
    }
    final after = text[afterName];
    if (after != ' ' && after != '\t' && after != '\n' && after != '\r' && after != '>' && after != '/') {
      // `<programme-guide>` is not `<programme>`; matching on the prefix alone turns every long name into a
      // false element.
      from = afterName;
      continue;
    }
    final tagEnd = text.indexOf('>', afterName);
    if (tagEnd < 0) {
      break;
    }
    final openTag = text.substring(startTag, tagEnd + 1);
    if (openTag.endsWith('/>')) {
      out.add(_XmlElement(openTag: openTag, attributes: _attributes(openTag), body: '', text: ''));
      from = tagEnd + 1;
      continue;
    }
    final closeAt = text.indexOf('</$name', tagEnd + 1);
    if (closeAt < 0) {
      // An element nobody closed is skipped rather than swallowing the rest of the file: one broken row must
      // not delete the guide that follows it.
      from = tagEnd + 1;
      continue;
    }
    final bodyEnd = text.indexOf('>', closeAt);
    if (bodyEnd < 0) {
      break;
    }
    final body = text.substring(tagEnd + 1, closeAt);
    out.add(_XmlElement(openTag: openTag, attributes: _attributes(openTag), body: body, text: _textOf(body)));
    from = bodyEnd + 1;
  }
  return out;
}

final RegExp _attributePattern = RegExp(r'([A-Za-z_:][-A-Za-z0-9_:.]*)\s*=\s*"([^"]*)"');

Map<String, String> _attributes(String openTag) {
  final out = <String, String>{};
  for (final match in _attributePattern.allMatches(openTag)) {
    final name = match.group(1)!;
    out[name.toLowerCase()] = match.group(2) ?? '';
  }
  return out;
}

final RegExp _tagPattern = RegExp(r'<[^>]*>');

String _stripTags(String body) => body.replaceAll(_tagPattern, ' ');

/// The character data of an element, with a whole-body CDATA section unwrapped **before** tags are stripped.
///
/// The order is the bug: `<![CDATA[新闻]]>` matches the tag pattern end to end, so stripping first deletes the
/// text along with the wrapper and every CDATA description on the guide comes back empty.
String _textOf(String body) {
  final trimmed = body.trim();
  if (trimmed.startsWith('<![CDATA[') && trimmed.endsWith(']]>')) {
    return trimmed.substring('<![CDATA['.length, trimmed.length - 3).trim();
  }
  return _stripTags(body).trim();
}

/// Unwraps CDATA, then resolves the five XML entities a guide uses, then collapses the whitespace CDATA and
/// pretty-printing introduce.
String _clean(String text) {
  var out = text.trim();
  if (out.startsWith('<![CDATA[')) {
    out = out.substring('<![CDATA['.length);
    if (out.endsWith(']]>')) {
      out = out.substring(0, out.length - 3);
    }
  }
  out = out
      .replaceAll('&amp;', '&')
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&quot;', '"')
      .replaceAll('&apos;', "'")
      .replaceAll(RegExp(r'\s+'), ' ');
  return out.trim();
}

String? _emptyToNull(String text) => text.isEmpty ? null : text;
