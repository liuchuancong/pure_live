import 'dart:convert';

import 'package:live_iptv/src/model/model.dart';

/// JSON guide parsing.
///
/// Every field is read under the several names the ecosystem uses —
/// `channelId` or `channel`, `title` or `name` or `programme`, `startTime`
/// or `start` or `starttime` or `time` — because a guide is whatever the
/// provider wrote, and refusing a file over a field spelling would leave the
/// viewer without programmes.
abstract final class JsonGuideParser {
  /// Parses [text] as a JSON guide.
  static ParsedGuide parse(String text) {
    final Object? decoded;
    try {
      decoded = jsonDecode(text);
    } on FormatException catch (error) {
      throw FormatException('Invalid JSON guide: ${error.message}');
    }
    final channels = <GuideChannel>[];
    final programmes = <EpgProgramme>[];
    if (decoded is Map<String, Object?>) {
      if (decoded['channels'] case final List<Object?> list) {
        for (final item in list) {
          final channel = _channel(item);
          if (channel != null) {
            channels.add(channel);
          }
        }
      }
      final programmeList = decoded['programmes'] ?? decoded['epg'] ?? decoded['events'];
      if (programmeList case final List<Object?> list) {
        for (final item in list) {
          final programme = _programme(item);
          if (programme != null) {
            programmes.add(programme);
          }
        }
      }
    }
    return ParsedGuide(channels: channels, programmes: programmes);
  }

  static String? _text(Map<String, Object?> item, List<String> keys) {
    for (final key in keys) {
      final value = item[key];
      if (value != null) {
        return value.toString();
      }
    }
    return null;
  }

  static GuideChannel? _channel(Object? item) {
    if (item is! Map<String, Object?>) {
      return null;
    }
    final id = _text(item, const ['id', 'channelId', 'name']);
    if (id == null || id.isEmpty) {
      return null;
    }
    return GuideChannel(
      id: id,
      displayNames: [
        _text(item, const ['displayName', 'name']) ?? id,
      ],
      iconUrl: _text(item, const ['icon', 'iconUrl', 'logo']),
    );
  }

  static EpgProgramme? _programme(Object? item) {
    if (item is! Map<String, Object?>) {
      return null;
    }
    final channel = _text(item, const ['channelId', 'channel']);
    final title = _text(item, const ['title', 'name', 'programme']);
    if (channel == null || channel.isEmpty || title == null || title.isEmpty) {
      return null;
    }
    final start = _time(item['startTime'] ?? item['start'] ?? item['starttime'] ?? item['time']);
    if (start == null) {
      return null;
    }
    final duration = item['duration'];
    final stop =
        _time(item['endTime'] ?? item['end'] ?? item['endtime'] ?? item['stop']) ??
        start.add(Duration(minutes: duration is int ? duration : 30));
    return EpgProgramme(
      channelId: channel,
      start: start,
      stop: stop,
      title: title,
      description: _text(item, const ['description', 'desc', 'summary']),
      subtitle: _text(item, const ['subtitle', 'subTitle']),
      episodeNum: _text(item, const ['episodeNum', 'episode']),
      category: _text(item, const ['category', 'genre']),
      catchupId: _text(item, const ['catchupId', 'catchup-id']),
    );
  }

  /// A guide time: ISO 8601 (no zone means local, as the format says), Unix
  /// seconds or Unix milliseconds.
  ///
  /// Digits are read as epoch first: `1790000000` parses as a valid *year*
  /// in `DateTime.tryParse`, and a guide that stored such a time would put a
  /// programme two thousand years out rather than fail.
  static DateTime? _time(Object? value) {
    DateTime epoch(int number) =>
        DateTime.fromMillisecondsSinceEpoch(number < 10000000000 ? number * 1000 : number, isUtc: true);
    return switch (value) {
      final int number => epoch(number),
      final String text when RegExp(r'^(\d{10}|\d{13})$').hasMatch(text.trim()) => epoch(int.parse(text.trim())),
      final String text => DateTime.tryParse(text) ?? (int.tryParse(text) == null ? null : epoch(int.parse(text))),
      _ => null,
    };
  }
}
