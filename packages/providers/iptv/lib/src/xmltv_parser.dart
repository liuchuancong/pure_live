// Module: lib/src/xmltv_parser.dart
// Purpose: Parses XMLTV EPG documents: channels and their programmes.
// Author: liuchuancong
// Created: 2026-10-09
//
// XMLTV is the one EPG format IPTV lists ship (docs/sources/iptv/). The
// parser walks the elements with a lightweight scan instead of a full XML
// stack because the document shape is fixed by the DTD; malformed entries are
// skipped, never half-parsed.

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
  });

  final String channelId;
  final DateTime start;
  final DateTime stop;
  final String title;
  final String? description;

  bool airsAt(DateTime at) => !at.isBefore(start) && at.isBefore(stop);
}

/// The whole guide: channels plus programmes grouped by channel id.
final class XmltvGuide {
  const XmltvGuide({required this.channels, required this.programmes});

  final List<XmltvChannel> channels;
  final Map<String, List<XmltvProgramme>> programmes;

  /// What airs on [channelId] at [at], when the guide knows.
  XmltvProgramme? nowOn(String channelId, DateTime at) {
    final rows = programmes[channelId];
    if (rows == null) {
      return null;
    }
    for (final row in rows) {
      if (row.airsAt(at)) {
        return row;
      }
    }
    return null;
  }
}

/// Parses an XMLTV document.
final class XmltvParser {
  const XmltvParser();

  XmltvGuide parse(String text) {
    final channels = <XmltvChannel>[];
    final programmes = <XmltvProgramme>[];

    for (final match in _channelPattern.allMatches(text)) {
      final id = match.group(1) ?? '';
      if (id.isEmpty) {
        continue;
      }
      final names = <String>[
        for (final name in _displayNamePattern.allMatches(match.group(0) ?? ''))
          if ((name.group(1) ?? '').trim().isNotEmpty) _unescape(name.group(1)!),
      ];
      final icon = _iconPattern.firstMatch(match.group(0) ?? '')?.group(1);
      channels.add(XmltvChannel(id: id, names: names, icon: icon));
    }

    for (final match in _programmePattern.allMatches(text)) {
      final channelId = match.group(1) ?? '';
      final start = _parseXmltvTime(match.group(2) ?? '');
      final stop = _parseXmltvTime(match.group(3) ?? '');
      final block = match.group(0) ?? '';
      final title = _unescape(_titlePattern.firstMatch(block)?.group(1) ?? '');
      if (channelId.isEmpty || start == null || stop == null || title.isEmpty) {
        continue;
      }
      final description = _descPattern.firstMatch(block)?.group(1);
      programmes.add(
        XmltvProgramme(
          channelId: channelId,
          start: start,
          stop: stop,
          title: title,
          description: description == null || description.isEmpty ? null : _unescape(description),
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
    return XmltvGuide(channels: channels, programmes: byChannel);
  }

  /// XMLTV times are "20260109120000 +0800" - naive local plus an offset.
  static DateTime? _parseXmltvTime(String text) {
    final match = RegExp(r'^(\d{4})(\d{2})(\d{2})(\d{2})?(\d{2})?(\d{2})?(?: ([+-]\d{4}))?').firstMatch(text.trim());
    if (match == null) {
      return null;
    }
    final year = int.parse(match.group(1)!);
    final month = int.parse(match.group(2)!);
    final day = int.parse(match.group(3)!);
    final hour = int.tryParse(match.group(4) ?? '0') ?? 0;
    final minute = int.tryParse(match.group(5) ?? '0') ?? 0;
    final second = int.tryParse(match.group(6) ?? '0') ?? 0;
    final naive = DateTime.utc(year, month, day, hour, minute, second);
    final offsetText = match.group(7);
    if (offsetText == null) {
      return naive;
    }
    final sign = offsetText.startsWith('-') ? -1 : 1;
    final offsetHours = int.parse(offsetText.substring(1, 3));
    final offsetMinutes = int.parse(offsetText.substring(3, 5));
    return naive.subtract(Duration(hours: sign * offsetHours, minutes: sign * offsetMinutes));
  }

  static String _unescape(String text) => text
      .replaceAll('&amp;', '&')
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&quot;', '"')
      .replaceAll('&apos;', "'");
}

final RegExp _channelPattern = RegExp(r'<channel[^>]*\bid="([^"]*)"[^>]*>.*?</channel>', dotAll: true);
final RegExp _programmePattern = RegExp(
  r'<programme[^>]*\bchannel="([^"]*)"[^>]*\bstart="([^"]*)"(?:[^>]*\bstop="([^"]*)")?[^>]*>.*?</programme>',
  dotAll: true,
);
final RegExp _displayNamePattern = RegExp(r'<display-name[^>]*>(.*?)</display-name>', dotAll: true);
final RegExp _iconPattern = RegExp(r'<icon[^>]*\bsrc="([^"]*)"');
final RegExp _titlePattern = RegExp(r'<title[^>]*>(.*?)</title>', dotAll: true);
final RegExp _descPattern = RegExp(r'<desc[^>]*>(.*?)</desc>', dotAll: true);
