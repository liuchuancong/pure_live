import 'package:live_iptv/src/model/model.dart';
import 'package:xml/xml.dart' show XmlParserException;
import 'package:xml/xml_events.dart';

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
