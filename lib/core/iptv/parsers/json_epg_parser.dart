import 'dart:convert';
import 'package:pure_live/core/iptv/models/epg.dart';

class JsonEpgParser {
  const JsonEpgParser();

  JsonEpgResult parse(String jsonContent, {required String sourceId}) {
    final decoded = jsonDecode(jsonContent);

    final channels = <EpgChannel>[];
    final programmes = <EpgProgramme>[];

    // =========================================================
    // channels
    // =========================================================

    if (decoded is Map<String, dynamic>) {
      final channelList = decoded['channels'];

      if (channelList is List) {
        for (final item in channelList) {
          final ch = _parseChannel(item, sourceId);

          if (ch != null) {
            channels.add(ch);
          }
        }
      }

      // =========================================================
      // programmes
      // =========================================================

      final programmeList = decoded['programmes'] ?? decoded['epg'] ?? decoded['events'];

      if (programmeList is List) {
        for (final item in programmeList) {
          final p = _parseProgramme(item, sourceId);

          if (p != null) {
            programmes.add(p);
          }
        }
      }
    }

    return JsonEpgResult(channels: channels, programmes: programmes);
  }

  // =========================================================
  // parse channel
  // =========================================================

  EpgChannel? _parseChannel(dynamic item, String sourceId) {
    if (item is! Map<String, dynamic>) {
      return null;
    }
    final channelId = item['id']?.toString() ?? item['channelId']?.toString() ?? item['name']?.toString();
    if (channelId == null || channelId.isEmpty) {
      return null;
    }
    final displayName = item['displayName']?.toString() ?? item['name']?.toString() ?? channelId;
    final iconUrl = item['icon']?.toString() ?? item['iconUrl']?.toString() ?? item['logo']?.toString();
    final number = item['number']?.toString() ?? item['channelNumber']?.toString();
    return EpgChannel(id: channelId, sourceId: sourceId, displayNames: [displayName], iconUrl: iconUrl, number: number);
  }

  // =========================================================
  // parse programme
  // =========================================================

  EpgProgramme? _parseProgramme(dynamic item, String sourceId) {
    if (item is! Map<String, dynamic>) {
      return null;
    }

    final channelId = item['channelId']?.toString() ?? item['channel']?.toString();

    if (channelId == null || channelId.isEmpty) {
      return null;
    }

    final title = item['title']?.toString() ?? item['name']?.toString() ?? item['programme']?.toString();

    if (title == null || title.isEmpty) {
      return null;
    }

    final start = _parseDate(item['startTime'] ?? item['start'] ?? item['starttime'] ?? item['time']);

    if (start == null) {
      return null;
    }

    DateTime? stop = _parseDate(item['endTime'] ?? item['end'] ?? item['endtime'] ?? item['stop']);

    // fallback duration
    if (stop == null) {
      final duration = item['duration'];

      int minutes = 30;

      if (duration is int) {
        minutes = duration;
      }

      stop = start.add(Duration(minutes: minutes));
    }

    final description = item['description']?.toString() ?? item['desc']?.toString() ?? item['summary']?.toString();

    final subtitle = item['subtitle']?.toString() ?? item['subTitle']?.toString();

    final episodeNum = item['episodeNum']?.toString() ?? item['episode']?.toString();

    final category = item['category']?.toString() ?? item['genre']?.toString();

    return EpgProgramme(
      channelId: channelId,
      sourceId: sourceId,
      title: title,
      description: description,
      subtitle: subtitle,
      episodeNum: episodeNum,
      category: category,
      start: start,
      stop: stop,
    );
  }

  // =========================================================
  // parse datetime
  // =========================================================

  DateTime? _parseDate(dynamic value) {
    if (value == null) {
      return null;
    }

    try {
      // already DateTime
      if (value is DateTime) {
        return value;
      }

      // unix timestamp
      if (value is int) {
        if (value < 10000000000) {
          return DateTime.fromMillisecondsSinceEpoch(value * 1000);
        }

        return DateTime.fromMillisecondsSinceEpoch(value);
      }

      // string
      if (value is String) {
        final dt = DateTime.tryParse(value);

        if (dt != null) {
          return dt;
        }

        final unix = int.tryParse(value);

        if (unix != null) {
          if (unix < 10000000000) {
            return DateTime.fromMillisecondsSinceEpoch(unix * 1000);
          }

          return DateTime.fromMillisecondsSinceEpoch(unix);
        }
      }
    } catch (_) {}

    return null;
  }
}

class JsonEpgResult {
  final List<EpgChannel> channels;

  final List<EpgProgramme> programmes;

  const JsonEpgResult({required this.channels, required this.programmes});
}
