import 'dart:convert';

import 'package:live_iptv/src/model/guide_models.dart';
import 'package:xml/xml.dart' show XmlParserException;
import 'package:xml/xml_events.dart';

/// The guide formats a source can deliver.
enum GuideFormat {
  /// XMLTV — the format the ecosystem agrees on (`.xml`, and gzipped it is
  /// still XMLTV once decompressed).
  xmltv,

  /// A JSON guide: the object shape an API delivers directly.
  json;

  /// The format of [text]: a JSON object or array is [json], everything else
  /// XMLTV.
  ///
  /// Decided from the content rather than the file name: sources serve
  /// XMLTV from URLs ending in `.php`, and a source whose extension lies
  /// would otherwise never parse.
  static GuideFormat detect(String text) {
    final start = text.trimLeft();
    return start.startsWith('{') || start.startsWith('[') ? json : xmltv;
  }
}

/// Parses guide [text] in [format], detecting it when null.
///
/// A malformed file throws a [FormatException] rather than returning an
/// empty guide: a broken download must not replace a stored one, and only
/// the caller can decide that — an exception it can catch is a decision it
/// can make.
ParsedGuide parseGuide(String text, {GuideFormat? format}) => switch (format ?? GuideFormat.detect(text)) {
  GuideFormat.xmltv => XmltvParser.parse(text),
  GuideFormat.json => JsonGuideParser.parse(text),
};

/// XMLTV parsing, streamed rather than built into a document.
///
/// A full guide is tens of megabytes of programmes, and a document tree
/// would hold all of it in memory before the first programme is read; the
/// event parser walks the text once and keeps only what is being read.
///
/// Read per element: `<channel id>` with its `<display-name>`s and first
/// `<icon src>`; `<programme channel start stop catchup-id>` with its first
/// `<title>`, `<sub-title>`, `<desc>`, `<category>` and `<episode-num>`.
/// A programme missing an id, a title or a valid start or stop is skipped —
/// it cannot be shown, and one bad row must not cost the rest of the file.
abstract final class XmltvParser {
  static const Set<String> _programmeFields = {'title', 'sub-title', 'desc', 'category', 'episode-num'};

  /// Parses [text] as XMLTV.
  static ParsedGuide parse(String text) {
    final channels = <GuideChannel>[];
    final programmes = <EpgProgramme>[];
    _Channel? channel;
    _Programme? programme;
    String? field;
    final buffer = StringBuffer();
    try {
      for (final event in parseEvents(text, validateNesting: true, validateDocument: true)) {
        switch (event) {
          case final XmlStartElementEvent start:
            final name = start.localName;
            if (name == 'channel' && channel == null && programme == null) {
              final id = _attribute(start, 'id');
              if (start.isSelfClosing) {
                if (id != null) {
                  channels.add(GuideChannel(id: id));
                }
              } else {
                channel = _Channel(id);
              }
            } else if (name == 'programme' && channel == null && programme == null) {
              if (!start.isSelfClosing) {
                programme = _Programme(
                  channel: _attribute(start, 'channel'),
                  start: _attribute(start, 'start'),
                  stop: _attribute(start, 'stop'),
                  catchupId: _attribute(start, 'catchup-id'),
                );
              }
            } else if (name == 'icon' && channel != null) {
              channel.icon ??= _attribute(start, 'src');
            } else if (!start.isSelfClosing &&
                ((channel != null && name == 'display-name') ||
                    (programme != null && _programmeFields.contains(name)))) {
              field = name;
              buffer.clear();
            }
          case final XmlTextEvent text when field != null:
            buffer.write(text.value);
          case final XmlCDATAEvent data when field != null:
            buffer.write(data.value);
          case final XmlEndElementEvent end:
            final name = end.localName;
            if (field != null && name == field) {
              final value = buffer.toString().trim();
              if (value.isNotEmpty) {
                if (channel != null) {
                  channel.names.add(value);
                } else {
                  // The first of each field wins: guides repeat elements for
                  // translations, and the first is the one the source's own
                  // viewers see.
                  programme?.fields.putIfAbsent(name, () => value);
                }
              }
              field = null;
            } else if (name == 'channel' && channel != null) {
              final id = channel.id;
              if (id != null) {
                channels.add(GuideChannel(id: id, displayNames: channel.names, iconUrl: channel.icon));
              }
              channel = null;
            } else if (name == 'programme' && programme != null) {
              final parsed = programme.build();
              if (parsed != null) {
                programmes.add(parsed);
              }
              programme = null;
            }
          default:
            break;
        }
      }
    } on XmlParserException catch (error) {
      throw FormatException('Invalid XMLTV: $error');
    }
    return ParsedGuide(channels: channels, programmes: programmes);
  }

  static String? _attribute(XmlStartElementEvent event, String name) {
    for (final attribute in event.attributes) {
      if (attribute.localName == name) {
        final value = attribute.value.trim();
        return value.isEmpty ? null : value;
      }
    }
    return null;
  }
}

final RegExp _xmltvTime = RegExp(
  r'^(\d{4})(\d{2})(\d{2})(\d{2})?(\d{2})?(\d{2})?\s*(?:([+-])(\d{2}):?(\d{2})|(Z))?$',
  caseSensitive: false,
);

/// An XMLTV time as UTC, or null when it is not a time.
///
/// The format is compact and full of tolerated spellings — `20260927200000
/// +0800`, `202609272000`, `+08:00`, `Z` — and a guide without a zone means
/// UTC, which is what the format says rather than a guess. Impossible
/// calendar values are rejected here instead of by `DateTime`, which would
/// silently roll a 32nd of the month into the next one and invent a
/// programme at the wrong time.
DateTime? parseXmltvTime(String? text) {
  final match = _xmltvTime.firstMatch(text?.trim() ?? '');
  if (match == null) {
    return null;
  }
  int part(int group) => int.parse(match.group(group) ?? '0');
  final month = part(2);
  final day = part(3);
  if (month < 1 || month > 12 || day < 1 || day > 31 || part(4) > 23 || part(5) > 59 || part(6) > 59) {
    return null;
  }
  final time = DateTime.utc(part(1), month, day, part(4), part(5), part(6));
  final sign = match.group(7);
  if (sign == null) {
    return time;
  }
  final offset = Duration(hours: part(8), minutes: part(9));
  return sign == '+' ? time.subtract(offset) : time.add(offset);
}

/// The accumulating state of the channel being read.
class _Channel {
  new(this.id);

  final String? id;
  final List<String> names = [];
  String? icon;
}

/// The accumulating state of the programme being read.
class _Programme {
  new({required this.channel, required this.start, required this.stop, required this.catchupId});

  final String? channel;
  final String? start;
  final String? stop;
  final String? catchupId;
  final Map<String, String> fields = {};

  EpgProgramme? build() {
    final startTime = parseXmltvTime(start);
    final stopTime = parseXmltvTime(stop);
    final title = fields['title'];
    if (channel == null || startTime == null || stopTime == null || title == null) {
      return null;
    }
    return EpgProgramme(
      channelId: channel!,
      start: startTime,
      stop: stopTime,
      title: title,
      subtitle: fields['sub-title'],
      description: fields['desc'],
      category: fields['category'],
      episodeNum: fields['episode-num'],
      catchupId: catchupId,
    );
  }
}

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
