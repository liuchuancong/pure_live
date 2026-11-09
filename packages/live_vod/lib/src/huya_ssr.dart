import 'dart:convert';

import 'package:live_vod/src/vod_models.dart' show VodFailure;

/// The envelope Huya's video pages carry their data in: one assignment to
/// `window.HNF_GLOBAL_INIT` holding TAF's own notation — every list and map
/// wrapped as `{_proto:function(){…}, _bValue:0, value:…}`, every record
/// carrying its `_classname`, and a bare `undefined` where the page has no
/// answer. Those functions are field metadata, never data, and are discarded
/// without being evaluated.
///
/// One reader for the station's pages, so the video station and the replay
/// archive cannot disagree about a field the station spells once.
abstract final class HuyaSsr {
  /// The largest page this reader accepts.
  static const int _maxHtml = 8388608;

  /// The deepest object the envelope may nest.
  static const int _maxDepth = 64;

  /// The pages' data assignment.
  static final RegExp _assignment = RegExp(r'window\.HNF_GLOBAL_INIT\s*=');

  /// The keys whose value is field metadata rather than data.
  static const List<String> _metadata = ['_proto', '_write', '_read'];

  /// The bare literals JSON does not carry; `-Infinity` stands first so its
  /// minus is consumed with the word.
  static const List<String> _bare = ['undefined', 'NaN', '-Infinity', 'Infinity'];

  /// The decoded envelope of [html]; a page without one, or one whose literal
  /// is not the station's, refuses with [VodFailure].
  static Map<String, Object?> parse(String html) {
    if (html.length > _maxHtml) {
      throw const VodFailure('the page answer broke its bounds');
    }
    final assignment = _assignment.firstMatch(html);
    if (assignment == null) {
      throw const VodFailure('the page carries none of the station data');
    }
    final Object? decoded;
    try {
      decoded = jsonDecode(sanitize(literal(html.substring(assignment.end))));
    } on FormatException {
      throw const VodFailure('the page carries data the station does not send');
    }
    if (decoded is! Map) {
      throw const VodFailure('the page data is not an object');
    }
    return decoded.cast<String, Object?>();
  }

  /// The balanced object literal [text] opens with, quotes and escapes
  /// respected; anything else in the way refuses.
  static String literal(String text) {
    final start = text.indexOf('{');
    if (start < 0 || text.substring(0, start).trim().isNotEmpty) {
      throw const VodFailure('the page data is missing');
    }
    var depth = 0;
    var quote = 0;
    var escape = false;
    for (var i = start; i < text.length; i++) {
      final unit = text.codeUnitAt(i);
      if (quote != 0) {
        if (escape) {
          escape = false;
        } else if (unit == 0x5C) {
          escape = true;
        } else if (unit == quote) {
          quote = 0;
        }
      } else if (unit == 0x22 || unit == 0x27) {
        quote = unit;
      } else if (unit == 0x7B) {
        if (++depth > _maxDepth) {
          throw const VodFailure('the page data nests too deep');
        }
      } else if (unit == 0x7D && --depth == 0) {
        return text.substring(start, i + 1);
      }
    }
    throw const VodFailure('the page data is truncated');
  }

  /// [text] as JSON: the metadata functions dropped, every bare literal made
  /// `null`, and quoted strings copied without being read as structure.
  static String sanitize(String text) {
    final out = StringBuffer();
    var i = 0;
    while (i < text.length) {
      final unit = text.codeUnitAt(i);
      var matched = false;
      for (final key in _metadata) {
        if (!text.startsWith('"$key"', i)) continue;
        var cursor = i + key.length + 2;
        while (cursor < text.length && _space(text.codeUnitAt(cursor))) {
          cursor++;
        }
        if (cursor >= text.length || text[cursor] != ':') continue;
        cursor++;
        while (cursor < text.length && _space(text.codeUnitAt(cursor))) {
          cursor++;
        }
        if (!text.startsWith('function', cursor)) continue;
        final body = text.indexOf('{', cursor);
        if (body < 0) {
          throw const VodFailure('the station sent a metadata function without a body');
        }
        var depth = 0;
        var quote = 0;
        var escape = false;
        var end = -1;
        for (var p = body; p < text.length; p++) {
          final inner = text.codeUnitAt(p);
          if (quote != 0) {
            if (escape) {
              escape = false;
            } else if (inner == 0x5C) {
              escape = true;
            } else if (inner == quote) {
              quote = 0;
            }
          } else if (inner == 0x22 || inner == 0x27) {
            quote = inner;
          } else if (inner == 0x7B) {
            if (++depth > _maxDepth) {
              throw const VodFailure('the station metadata nests too deep');
            }
          } else if (inner == 0x7D && --depth == 0) {
            end = p;
            break;
          }
        }
        if (end < 0) {
          throw const VodFailure('the station metadata is truncated');
        }
        out.write('"$key":null');
        i = end + 1;
        matched = true;
        break;
      }
      if (matched) continue;
      if (unit == 0x22 || unit == 0x27) {
        i = _string(text, i, unit, out);
        continue;
      }
      for (final bare in _bare) {
        if (!text.startsWith(bare, i)) continue;
        final after = i + bare.length;
        final before = i > 0 ? text.codeUnitAt(i - 1) : 0;
        if (after < text.length && _word(text.codeUnitAt(after))) continue;
        if (_word(before)) continue;
        out.write('null');
        i = after;
        matched = true;
        break;
      }
      if (matched) continue;
      out.writeCharCode(unit);
      i++;
    }
    return out.toString();
  }

  /// Copies the string at [start] into [out] as a JSON string, returning the
  /// index after its closing quote.
  static int _string(String text, int start, int quote, StringBuffer out) {
    out.writeCharCode(0x22);
    var i = start + 1;
    while (i < text.length) {
      final unit = text.codeUnitAt(i);
      if (unit == 0x5C) {
        if (i + 1 >= text.length) break;
        final next = text.codeUnitAt(i + 1);
        // A single-quoted literal escapes its own quote; JSON does not, and
        // the character needs no escape once the string is double-quoted.
        if (quote == 0x27 && next == 0x27) {
          out.writeCharCode(0x27);
        } else {
          out
            ..writeCharCode(unit)
            ..writeCharCode(next);
        }
        i += 2;
        continue;
      }
      if (unit == quote) {
        out.writeCharCode(0x22);
        return i + 1;
      }
      if (quote == 0x27 && unit == 0x22) {
        out.write(r'\"');
        i++;
        continue;
      }
      out.writeCharCode(unit);
      i++;
    }
    throw const VodFailure('the page data holds an unterminated string');
  }

  static bool _space(int unit) => unit == 0x20 || unit == 0x09 || unit == 0x0A || unit == 0x0D;

  static bool _word(int unit) =>
      (unit >= 0x30 && unit <= 0x39) ||
      (unit >= 0x41 && unit <= 0x5A) ||
      (unit >= 0x61 && unit <= 0x7A) ||
      unit == 0x5F ||
      unit == 0x24;

  /// The payload of a TAF wrapper (`{_bValue:0, value:…}`), or [node] itself
  /// when it is not one.
  static Object? value(Object? node) {
    if (node is Map && node.containsKey('value') && (node.containsKey('_bValue') || node.containsKey('_classname'))) {
      return node['value'];
    }
    return node;
  }

  /// One node as a record; null for anything else.
  static Map<String, Object?>? record(Object? node) => node is Map ? node.cast<String, Object?>() : null;

  /// One wrapped list's records, in the station's order.
  static List<Map<String, Object?>> rows(Object? node) {
    final data = value(node);
    if (data is! List) return const [];
    return [
      for (final row in data)
        if (row is Map) row.cast<String, Object?>(),
    ];
  }

  /// A scalar as text: the station sends the same id as a number on one page
  /// and a string on another.
  static String text(Object? node) => switch (node) {
    final String value => value,
    final num value when value.isFinite && value == value.roundToDouble() => '${value.toInt()}',
    final num value => '$value',
    _ => '',
  };

  /// A scalar as an integer; null when it is not one.
  static int? integer(Object? node) => switch (node) {
    final int value => value,
    final num value when value.isFinite && value == value.roundToDouble() => value.toInt(),
    final String value => int.tryParse(value.trim()),
    _ => null,
  };

  /// A clock the station prints ("28:21" or "1:02:03"), or a raw seconds
  /// count; zero when it prints neither.
  static Duration duration(Object? node) {
    if (node is num) {
      return node.isFinite && node > 0 && node < 864000 ? Duration(milliseconds: (node * 1000).round()) : Duration.zero;
    }
    final parts = text(node).split(':');
    if (parts.length < 2 || parts.length > 3) return Duration.zero;
    final seconds = int.tryParse(parts.last.trim());
    final minutes = int.tryParse(parts[parts.length - 2].trim());
    final hours = parts.length == 3 ? int.tryParse(parts.first.trim()) : 0;
    if (seconds == null || minutes == null || hours == null) return Duration.zero;
    if (seconds < 0 || seconds > 59 || minutes < 0 || hours < 0 || hours > 1000) return Duration.zero;
    if (minutes > (parts.length == 3 ? 59 : 999)) return Duration.zero;
    return Duration(hours: hours, minutes: minutes, seconds: seconds);
  }

  /// A picture address made absolute where the station's own form allows;
  /// empty for anything else.
  static String image(Object? node) {
    final raw = text(node).trim();
    if (raw.isEmpty || raw.toLowerCase() == 'null') return '';
    final absolute = raw.startsWith('//') ? 'https:$raw' : raw;
    final uri = Uri.tryParse(absolute);
    if (uri == null || (uri.scheme != 'http' && uri.scheme != 'https') || uri.host.isEmpty) return '';
    return absolute;
  }

  /// A recording's own address: an http(s) `.mp4` or `.m3u8` on the station's
  /// hosts, `http://` upgraded to https (the VOD CDN serves both). Null for
  /// anything else, so a live stream's bit rate is never taken for a
  /// recording.
  static String? media(Object? node) {
    final raw = text(node).trim();
    if (raw.isEmpty) return null;
    final uri = Uri.tryParse(raw);
    if (uri == null || uri.userInfo.isNotEmpty || uri.hasPort) return null;
    final path = uri.path.toLowerCase();
    if (!path.endsWith('.mp4') && !path.endsWith('.m3u8')) return null;
    final host = uri.host.toLowerCase();
    final station =
        host == 'huya.com' || host.endsWith('.huya.com') || host == 'msstatic.com' || host.endsWith('.msstatic.com');
    if (!station) return null;
    if (uri.scheme == 'https') return raw;
    if (uri.scheme == 'http') return uri.replace(scheme: 'https').toString();
    return null;
  }

  /// The station escapes titles for HTML; the viewer reads them unescaped.
  static String entities(String text) {
    if (!text.contains('&')) return text;
    return text.replaceAllMapped(_entity, (match) {
      final named = _names[match.group(1)];
      if (named != null) return named;
      final numeric = match.group(2);
      if (numeric != null) {
        final code = numeric.startsWith('x') || numeric.startsWith('X')
            ? int.tryParse(numeric.substring(1), radix: 16)
            : int.tryParse(numeric);
        final scalar = code != null && code >= 0 && code <= 0x10FFFF ? String.fromCharCode(code) : null;
        if (scalar != null) return scalar;
      }
      return match.group(0)!;
    });
  }

  static final RegExp _entity = RegExp('&([a-zA-Z][a-zA-Z0-9]{1,31});|&#([xX][0-9a-fA-F]+|[0-9]+);');

  static const Map<String, String> _names = {
    'amp': '&',
    'lt': '<',
    'gt': '>',
    'quot': '"',
    'apos': "'",
    'nbsp': '\u00a0',
    'copy': '\u00a9',
    'middot': '\u00b7',
    'hellip': '\u2026',
    'mdash': '\u2014',
    'ndash': '\u2013',
    'laquo': '\u00ab',
    'raquo': '\u00bb',
    'times': '\u00d7',
  };

  /// A published time the station prints as seconds since the epoch; null
  /// outside the years this reader accepts.
  static DateTime? epoch(Object? node) {
    final seconds = integer(node);
    if (seconds == null || seconds < 946684800 || seconds > 4102444800) return null;
    return DateTime.fromMillisecondsSinceEpoch(seconds * 1000);
  }

  /// A wall clock the station prints ("2026-11-05 18:46:18" or
  /// "2026-11-09 08:16"), read as local time; null when it prints another.
  static DateTime? stamp(Object? node) {
    final match = _stamp.firstMatch(text(node).trim());
    if (match == null) return null;
    final year = int.tryParse(match.group(1)!);
    final month = int.tryParse(match.group(2)!);
    final day = int.tryParse(match.group(3)!);
    final hour = int.tryParse(match.group(4)!);
    final minute = int.tryParse(match.group(5)!);
    final second = int.tryParse(match.group(6) ?? '0');
    if (year == null ||
        month == null ||
        day == null ||
        hour == null ||
        minute == null ||
        second == null ||
        month < 1 ||
        month > 12 ||
        day < 1 ||
        day > 31 ||
        hour > 23 ||
        minute > 59 ||
        second > 59) {
      return null;
    }
    final parsed = DateTime(year, month, day, hour, minute, second);
    return parsed.month == month && parsed.day == day ? parsed : null;
  }

  static final RegExp _stamp = RegExp(r'^(\d{4})-(\d{2})-(\d{2})[ T](\d{2}):(\d{2})(?::(\d{2}))?$');
}
