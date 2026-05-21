import 'dart:io';
import 'dart:convert';
import 'package:xml/xml.dart';
import 'package:archive/archive.dart';
import 'package:pure_live/core/iptv/models/epg.dart';

class XmltvParser {
  /// Parse XMLTV content from a raw XML string.
  XmltvResult parse(String xmlContent, {required String sourceId}) {
    final document = XmlDocument.parse(xmlContent);
    final tv = document.rootElement;

    final channels = <EpgChannel>[];
    final programmes = <EpgProgramme>[];

    // Parse channels
    for (final element in tv.findElements('channel')) {
      final channel = _parseChannel(element, sourceId);
      if (channel != null) channels.add(channel);
    }

    // Parse programmes
    for (final element in tv.findElements('programme')) {
      final programme = _parseProgramme(element, sourceId);
      if (programme != null) programmes.add(programme);
    }

    return XmltvResult(channels: channels, programmes: programmes);
  }

  /// Parse XMLTV from bytes (handles gzip decompression automatically).
  XmltvResult parseBytes(List<int> bytes, {required String sourceId}) {
    List<int> decompressed;
    try {
      decompressed = GZipDecoder().decodeBytes(bytes);
    } catch (_) {
      // Not gzipped, use as-is
      decompressed = bytes;
    }
    final xmlContent = utf8.decode(decompressed, allowMalformed: true);
    return parse(xmlContent, sourceId: sourceId);
  }

  /// Parse XMLTV from a local file.
  Future<XmltvResult> parseFile(File file, {required String sourceId}) async {
    final bytes = await file.readAsBytes();
    return parseBytes(bytes, sourceId: sourceId);
  }

  EpgChannel? _parseChannel(XmlElement element, String sourceId) {
    final id = element.getAttribute('id');
    if (id == null || id.isEmpty) return null;

    final displayNames = element
        .findElements('display-name')
        .map((e) => e.innerText.trim())
        .where((name) => name.isNotEmpty)
        .toList();

    final iconElement = element.findElements('icon').firstOrNull;
    final iconUrl = iconElement?.getAttribute('src');

    // Some XMLTV sources include channel number in display-name
    String? number;
    for (final name in displayNames) {
      if (RegExp(r'^\d+$').hasMatch(name)) {
        number = name;
        break;
      }
    }

    return EpgChannel(id: id, sourceId: sourceId, displayNames: displayNames, iconUrl: iconUrl, number: number);
  }

  EpgProgramme? _parseProgramme(XmlElement element, String sourceId) {
    final channelId = element.getAttribute('channel');
    final startStr = element.getAttribute('start');
    final stopStr = element.getAttribute('stop');

    if (channelId == null || startStr == null || stopStr == null) return null;

    final start = _parseXmltvDate(startStr);
    final stop = _parseXmltvDate(stopStr);
    if (start == null || stop == null) return null;

    final title = element.findElements('title').firstOrNull?.innerText.trim();
    if (title == null || title.isEmpty) return null;

    final subtitle = element.findElements('sub-title').firstOrNull?.innerText.trim();
    final description = element.findElements('desc').firstOrNull?.innerText.trim();
    final category = element.findElements('category').firstOrNull?.innerText.trim();

    final iconElement = element.findElements('icon').firstOrNull;
    final iconUrl = iconElement?.getAttribute('src');

    final episodeNum = element.findElements('episode-num').firstOrNull?.innerText.trim();

    final rating = element.findElements('rating').firstOrNull?.findElements('value').firstOrNull?.innerText.trim();

    final isNew = element.findElements('new').isNotEmpty;

    return EpgProgramme(
      channelId: channelId,
      sourceId: sourceId,
      start: start,
      stop: stop,
      title: title,
      subtitle: subtitle,
      description: description,
      category: category,
      iconUrl: iconUrl,
      episodeNum: episodeNum,
      rating: rating,
      isNew: isNew,
    );
  }

  /// Parse XMLTV date format: "20260221120000 +0000" or "20260221120000"
  DateTime? _parseXmltvDate(String dateStr) {
    try {
      dateStr = dateStr.trim();

      // Extract timezone offset if present
      Duration tzOffset = Duration.zero;
      final tzMatch = RegExp(r'([+-]\d{4})$').firstMatch(dateStr);
      if (tzMatch != null) {
        final tz = tzMatch.group(1)!;
        final sign = tz[0] == '+' ? 1 : -1;
        final hours = int.parse(tz.substring(1, 3));
        final minutes = int.parse(tz.substring(3, 5));
        tzOffset = Duration(hours: hours * sign, minutes: minutes * sign);
        dateStr = dateStr.substring(0, tzMatch.start).trim();
      }

      // Parse the date part: "20260221120000"
      if (dateStr.length < 14) {
        dateStr = dateStr.padRight(14, '0');
      }

      final year = int.parse(dateStr.substring(0, 4));
      final month = int.parse(dateStr.substring(4, 6));
      final day = int.parse(dateStr.substring(6, 8));
      final hour = int.parse(dateStr.substring(8, 10));
      final minute = int.parse(dateStr.substring(10, 12));
      final second = int.parse(dateStr.substring(12, 14));

      return DateTime.utc(year, month, day, hour, minute, second).subtract(tzOffset);
    } catch (_) {
      return null;
    }
  }
}

/// Result of parsing an XMLTV document.
class XmltvResult {
  final List<EpgChannel> channels;
  final List<EpgProgramme> programmes;

  const XmltvResult({required this.channels, required this.programmes});
}
