part of 'hls_retained_window.dart';

/// Immutable, bounded DATERANGE metadata. Values retain their wire type and
/// quoting so commas, hex data and decimal extensions round-trip unchanged.
/// This is metadata retention, not a SCTE-35 decoder or an asset scheduler.
final class HlsDateRange {
  HlsDateRange._(Map<String, String> attributes, [this._followingId, this._followingStart])
    : attributes = Map.unmodifiable(attributes);

  final Map<String, String> attributes;
  final String? _followingId;
  final BigInt? _followingStart;
  String? attribute(String name) {
    final value = attributes[name];
    return value != null && value.startsWith('"') ? value.substring(1, value.length - 1) : value;
  }

  String get id => attribute('ID')!;
  String get manifestLine => '#EXT-X-DATERANGE:${attributes.entries.map((e) => '${e.key}=${e.value}').join(',')}';
  int get retainedBytes =>
      utf8.encode(manifestLine).length +
      1 +
      utf8.encode(_followingId ?? '').length +
      (_followingStart?.toString().length ?? 0);
  BigInt? get _start => attributes.containsKey('START-DATE') ? _dateNanoseconds(attribute('START-DATE')!) : null;
  BigInt? get _end {
    if (_followingStart != null) return _followingStart;
    if (attributes.containsKey('END-DATE')) return _dateNanoseconds(attribute('END-DATE')!);
    if (_start != null && attributes.containsKey('DURATION')) {
      return _start! + _decimalNanoseconds(attributes['DURATION']!);
    }
    return null; // PLANNED-DURATION never closes an event.
  }

  static HlsDateRange _parse(String text) {
    if (text.length > 16384 || utf8.encode(text).length > 16384 || text.contains(RegExp(r'[\x00-\x1f\x7f]'))) {
      throw const FormatException('Date range exceeds attribute text contract');
    }
    final attributes = <String, String>{};
    final pattern = RegExp(r'([A-Z0-9-]+)=("[^"]*"|[^,\s"]+)');
    var offset = 0;
    while (offset < text.length) {
      final match = pattern.matchAsPrefix(text, offset);
      if (match == null || attributes.containsKey(match.group(1)) || attributes.length >= 64) {
        throw const FormatException('Invalid date range attributes');
      }
      attributes[match.group(1)!] = match.group(2)!;
      offset = match.end;
      if (offset == text.length) break;
      if (text[offset++] != ',' || offset == text.length) throw const FormatException('Invalid date range separator');
    }
    final range = HlsDateRange._(attributes);
    range._validate(requireStart: false);
    return range;
  }

  void _validate({required bool requireStart}) {
    if (!attributes.containsKey('ID') || (requireStart && _start == null)) {
      throw const FormatException('Incomplete date range identity');
    }
    if (attributes.length > 64 || retainedBytes > 16384) {
      throw const FormatException('Date range metadata exceeds limit');
    }
    for (final entry in attributes.entries) {
      final name = entry.key;
      final raw = entry.value;
      final quoted = raw.startsWith('"');
      final value = attribute(name)!;
      switch (name) {
        case 'ID':
        case 'CLASS':
          if (!quoted || value.isEmpty) throw const FormatException('Invalid date range identifier');
        case 'START-DATE':
        case 'END-DATE':
          if (!quoted) throw const FormatException('Date range date must be quoted');
          _dateNanoseconds(value);
        case 'DURATION':
        case 'PLANNED-DURATION':
          _decimalNanoseconds(raw);
        case 'END-ON-NEXT':
          if (raw != 'YES') throw const FormatException('Invalid END-ON-NEXT');
        case 'CUE':
          final cues = value.split(',');
          if (!quoted ||
              cues.toSet().length != cues.length ||
              cues.any((c) => !const {'PRE', 'POST', 'ONCE'}.contains(c)) ||
              (cues.contains('PRE') && cues.contains('POST'))) {
            throw const FormatException('Invalid date range cue');
          }
        case 'SCTE35-CMD':
        case 'SCTE35-OUT':
        case 'SCTE35-IN':
          if (!_dateHex.hasMatch(raw)) throw const FormatException('Invalid SCTE-35 hex data');
        default:
          if (!name.startsWith('X-') ||
              name.length <= 2 ||
              (!quoted && !_dateHex.hasMatch(raw) && !_dateSignedDecimal.hasMatch(raw))) {
            throw const FormatException('Unsupported date range attribute');
          }
      }
    }
    if (attributes.containsKey('END-ON-NEXT')) {
      if ((requireStart && !attributes.containsKey('CLASS')) ||
          attributes.containsKey('DURATION') ||
          attributes.containsKey('END-DATE')) {
        throw const FormatException('Conflicting END-ON-NEXT attributes');
      }
    }
    final start = _start;
    final end = _end;
    if (start != null && end != null) {
      if (end < start ||
          (attributes.containsKey('DURATION') && end != start + _decimalNanoseconds(attributes['DURATION']!))) {
        throw const FormatException('Conflicting date range extent');
      }
    }
  }
}

final _dateHex = RegExp(r'^0[xX][0-9a-fA-F]+$');
final _dateSignedDecimal = RegExp(r'^-?\d+(?:\.\d+)?$');
final _nanosPerMicrosecond = BigInt.from(1000);
final _nanosPerSecond = BigInt.from(1000000000);
BigInt _nanoseconds(DateTime time) => BigInt.from(time.microsecondsSinceEpoch) * _nanosPerMicrosecond;

BigInt _dateNanoseconds(String value) {
  final withZone = RegExp(r'(Z|[+-]\d{2}:\d{2})$').hasMatch(value) ? value : '${value}Z';
  final date = _programTime(withZone);
  final fraction = RegExp(r'\.(\d+)').firstMatch(value)?.group(1) ?? '';
  // DateTime stores microseconds. Keep the remaining nanoseconds for exact
  // duration equality and conservative event retirement, without float math.
  return _nanoseconds(date) + BigInt.parse(fraction.padRight(9, '0').substring(6));
}

BigInt _decimalNanoseconds(String value) {
  if (!RegExp(r'^\d{1,12}(?:\.\d{1,9})?$').hasMatch(value)) {
    throw const FormatException('Unsupported date range duration precision or size');
  }
  final parts = value.split('.');
  return BigInt.parse(parts.first) * _nanosPerSecond +
      BigInt.parse((parts.length == 1 ? '' : parts.last).padRight(9, '0'));
}

List<HlsDateRange> _mergeDateRanges(List<HlsDateRange> previous, List<HlsDateRange> updates) {
  final byId = {for (final range in previous) range.id: range};
  for (final update in updates) {
    final old = byId[update.id];
    final attributes = {...?old?.attributes};
    for (final entry in update.attributes.entries) {
      if (attributes.containsKey(entry.key) && attributes[entry.key] != entry.value) {
        throw const FormatException('Date range attribute changed within an ID');
      }
      attributes[entry.key] = entry.value;
    }
    final merged = HlsDateRange._(attributes, old?._followingId, old?._followingStart);
    merged._validate(requireStart: true);
    byId[merged.id] = merged;
  }
  final sorted = byId.values.toList()..sort((a, b) => a._start!.compareTo(b._start!));
  final constrainedClasses = sorted
      .where((r) => r.attributes.containsKey('END-ON-NEXT'))
      .map((r) => r.attribute('CLASS'))
      .toSet();
  for (final name in constrainedClasses) {
    final group = sorted.where((r) => r.attribute('CLASS') == name).toList();
    for (var i = 0; i < group.length; i++) {
      var range = group[i];
      final next = i + 1 < group.length ? group[i + 1] : null;
      if (range.attributes.containsKey('END-ON-NEXT') && next != null) {
        if (next._start == range._start || (range._followingStart != null && range._followingStart != next._start)) {
          throw const FormatException('Following date range changed');
        }
        range = HlsDateRange._(range.attributes, next.id, next._start);
        byId[range.id] = range;
      }
      if (next != null && (range._start == next._start || range._end == null || range._end! > next._start!)) {
        throw const FormatException('Overlapping END-ON-NEXT class');
      }
    }
  }
  return List.unmodifiable(byId.values);
}

/// Retire only closed events entirely before all known retained program times.
/// Unknown clocks, open/planned ranges and lifecycle cues remain charged. A
/// retained END-ON-NEXT also retains the following tag that defines its end.
(List<HlsDateRange>, BigInt?) _pruneDateRanges(List<HlsDateRange> ranges, List<HlsSegmentDescriptor> segments) {
  if (ranges.isEmpty || segments.isEmpty || segments.any((s) => s._programTimeFloor == null)) {
    return (List.unmodifiable(ranges), null);
  }
  final floor = segments.map((s) => _nanoseconds(s._programTimeFloor!)).reduce((a, b) => a < b ? a : b);
  final byId = {for (final range in ranges) range.id: range};
  final keep = <String>{};
  for (final range in ranges) {
    final end = range._end;
    if (end == null ||
        end > floor ||
        (end == range._start && end == floor) ||
        (range.attribute('CUE')?.split(',').any((c) => c == 'PRE' || c == 'POST') ?? false)) {
      keep.add(range.id);
    }
  }
  final pending = keep.toList();
  while (pending.isNotEmpty) {
    final following = byId[pending.removeLast()]?._followingId;
    if (following != null && keep.add(following)) pending.add(following);
  }
  return (List.unmodifiable(ranges.where((r) => keep.contains(r.id))), keep.length < ranges.length ? floor : null);
}
