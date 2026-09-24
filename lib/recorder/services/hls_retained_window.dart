import 'dart:convert';

import 'package:crypto/crypto.dart';

part 'hls_date_range.dart';
part 'hls_low_latency.dart';

/// Immutable request identity. Implicit ranges are resolved at parse time so
/// retiring the preceding segment never changes which bytes are requested.
final class HlsSegmentRange {
  const HlsSegmentRange(this.offset, this.length);
  final int offset;
  final int length;
  String get requestHeader => 'bytes=$offset-${offset + length - 1}';
  String get identity => '$length@$offset';
}

final class HlsKeyDescriptor {
  HlsKeyDescriptor(Map<String, String> attributes, this.uri) : attributes = Map.unmodifiable(attributes);
  final Map<String, String> attributes;
  final Uri? uri;
  String get format => attributes['KEYFORMAT'] ?? 'identity';
  String get identity => jsonEncode([
    {
      for (final key in (attributes.keys.toList()..sort()))
        if (key != 'URI') key: attributes[key],
    },
    uri?.toString(),
  ]);
}

final class HlsMapDescriptor {
  HlsMapDescriptor(this.uri, this.range, List<HlsKeyDescriptor> keys) : keys = List.unmodifiable(keys);
  final Uri uri;
  final HlsSegmentRange? range;
  // A later media-key rotation must not change the initialization key.
  final List<HlsKeyDescriptor> keys;
  String get identity => jsonEncode([uri.toString(), range?.identity, (keys.map((k) => k.identity).toList()..sort())]);
}

final class HlsSegmentDescriptor {
  HlsSegmentDescriptor({
    required this.sequence,
    required this.discontinuity,
    required this.uri,
    required this.duration,
    required this.extinf,
    required this.range,
    required this.initialization,
    required List<HlsKeyDescriptor> keys,
    required this.programTime,
    DateTime? programTimeFloor,
    required this.explicitProgramTime,
    required this.gap,
  }) : keys = List.unmodifiable(keys),
       _programTimeFloor = programTimeFloor ?? programTime;
  final int sequence;
  final int discontinuity;
  final Uri uri;
  final double duration;
  final String extinf;
  final HlsSegmentRange? range;
  final HlsMapDescriptor? initialization;
  final List<HlsKeyDescriptor> keys;
  final DateTime? programTime;
  // Conservative microsecond lower bound derived from decimal EXTINF text.
  // The rounded display time must not retire sub-microsecond event metadata.
  final DateTime? _programTimeFloor;
  final bool explicitProgramTime;
  final bool gap;
  String get identity => jsonEncode([
    sequence,
    discontinuity,
    uri.toString(),
    duration,
    range?.identity,
    initialization?.identity,
    (keys.map((k) => k.identity).toList()..sort()),
    gap,
  ]);
  int get retainedBytes => utf8
      .encode(
        '$identity$extinf${programTime?.toIso8601String() ?? ''}'
        '${_programTimeFloor?.toIso8601String() ?? ''}',
      )
      .length;
}

/// Extraction for a future recording prefetch owner, not a playback parser or
/// a renderer. Unknown stateful tags stay explicit; delta playlists are rejected
/// rather than assigning incorrect media sequence numbers to their segments.
final class HlsMediaSnapshot {
  HlsMediaSnapshot._(
    this.source,
    this.targetDuration,
    this.ended,
    this.version,
    this.independentSegments,
    this.playlistType,
    List<HlsSegmentDescriptor> segments,
    Set<String> unhandledTags,
    List<HlsDateRange> dateRanges,
    this.lowLatency,
    this.reloadFingerprint,
  ) : segments = List.unmodifiable(segments),
      unhandledTags = Set.unmodifiable(unhandledTags),
      dateRanges = List.unmodifiable(dateRanges);
  final Uri source;
  final int targetDuration;
  final bool ended;
  final int version;
  final bool independentSegments;
  final String? playlistType;
  final List<HlsSegmentDescriptor> segments;
  final Set<String> unhandledTags;

  /// Attribute updates in wire order. START-DATE may come from an older
  /// snapshot; only the owning window can validate a consolidated range.
  final List<HlsDateRange> dateRanges;
  final HlsLowLatencyInfo lowLatency;

  /// Fixed-size wire-content identity for reload cadence, not retained media
  /// identity. Comments and metadata changes still make a playlist changed.
  final String reloadFingerprint;

  static HlsMediaSnapshot parse(String text, Uri source, {int maximumSegments = 512}) {
    if (maximumSegments < 1 || maximumSegments > 4096) throw ArgumentError.value(maximumSegments);
    if (text.length > 4 * 1024 * 1024) {
      throw const FormatException('HLS snapshot exceeds text limit');
    }
    final encoded = utf8.encode(text);
    if (encoded.length > 4 * 1024 * 1024) {
      throw const FormatException('HLS snapshot exceeds text limit');
    }
    if (!const {'http', 'https'}.contains(source.scheme) || source.host.isEmpty) {
      throw const FormatException('HLS snapshot needs an HTTP source');
    }
    final lines = const LineSplitter().convert(text);
    if (lines.isEmpty || lines.first != '#EXTM3U') throw const FormatException('Missing HLS header');
    var sequence = 0;
    var discontinuity = 0;
    int? target;
    var ended = false;
    var version = 1;
    var independent = false;
    String? playlistType;
    var gap = false;
    var sawDiscontinuity = false;
    var explicitTime = false;
    DateTime? time;
    DateTime? timeFloor;
    double? duration;
    int? durationFloorMicros;
    String? extinf;
    String? rangeText;
    HlsMapDescriptor? initialization;
    HlsSegmentDescriptor? previous;
    final keys = <String, HlsKeyDescriptor>{};
    final segments = <HlsSegmentDescriptor>[];
    final singletons = <String>{};
    final unhandled = <String>{};
    final dateRanges = <HlsDateRange>[];
    final lowLatency = _LowLatencyBuilder();
    var sawProgramTime = false;
    for (final raw in lines.skip(1)) {
      final line = raw.trim();
      if (line.isEmpty) continue;
      final tag = line.split(':').first;
      final value = line.contains(':') ? line.substring(line.indexOf(':') + 1) : '';
      if (lowLatency.hasPartsFor(sequence) &&
          const {'#EXT-X-KEY', '#EXT-X-MAP', '#EXT-X-DISCONTINUITY', '#EXT-X-PROGRAM-DATE-TIME'}.contains(tag)) {
        throw const FormatException('Parent metadata appears after its first partial segment');
      }
      if (const {'#EXT-X-STREAM-INF', '#EXT-X-MEDIA', '#EXT-X-I-FRAME-STREAM-INF', '#EXT-X-SKIP'}.contains(tag)) {
        throw const FormatException('Master or delta input is not a complete media snapshot');
      }
      if (const {
        '#EXT-X-MEDIA-SEQUENCE',
        '#EXT-X-DISCONTINUITY-SEQUENCE',
        '#EXT-X-TARGETDURATION',
        '#EXT-X-VERSION',
        '#EXT-X-ENDLIST',
        '#EXT-X-PLAYLIST-TYPE',
        '#EXT-X-ALLOW-CACHE',
        '#EXT-X-PART-INF',
        '#EXT-X-SERVER-CONTROL',
      }.contains(tag)) {
        if (!singletons.add(tag)) throw const FormatException('Duplicate playlist property');
      }
      switch (tag) {
        case '#EXT-X-MEDIA-SEQUENCE':
          if (segments.isNotEmpty || lowLatency.parts.isNotEmpty) throw const FormatException('Late media sequence');
          sequence = _unsigned(value);
        case '#EXT-X-DISCONTINUITY-SEQUENCE':
          if (segments.isNotEmpty || sawDiscontinuity || lowLatency.parts.isNotEmpty) {
            throw const FormatException('Late discontinuity sequence');
          }
          discontinuity = _unsigned(value);
        case '#EXT-X-TARGETDURATION':
          target = _unsigned(value);
          if (target == 0 || target > 86400) throw const FormatException('Invalid target duration');
        case '#EXT-X-PART-INF':
          lowLatency.partTarget = _llDecimal(_llAttributes(value, {'PART-TARGET'})['PART-TARGET']);
        case '#EXT-X-SERVER-CONTROL':
          lowLatency.control = HlsServerControl._parse(value);
        case '#EXT-X-PART':
          if (ended) throw const FormatException('Partial media follows ENDLIST');
          lowLatency.addPart(
            value,
            source,
            sequence,
            discontinuity,
            initialization,
            keys.values.toList(),
            time,
            timeFloor,
          );
        case '#EXT-X-PRELOAD-HINT':
          lowLatency.addHint(value, source);
        case '#EXT-X-RENDITION-REPORT':
          lowLatency.addReport(value, source);
        case '#EXT-X-DISCONTINUITY':
          discontinuity = _checkedAdd(discontinuity, 1);
          sawDiscontinuity = true;
          // An explicit anchor already encountered applies to the upcoming
          // segment too; only an inferred time is invalidated by this tag.
          if (!explicitTime) {
            time = null;
            timeFloor = null;
          }
        case '#EXT-X-PROGRAM-DATE-TIME':
          time = _programTime(value);
          timeFloor = time;
          explicitTime = true;
          sawProgramTime = true;
        case '#EXT-X-DATERANGE':
          if (dateRanges.length >= 512) throw const FormatException('Too many date range updates');
          final range = HlsDateRange._parse(value);
          dateRanges.add(range);
          // Asset playback needs its own resource ownership and timeline plan.
          // Retaining ordinary metadata is not an interstitial implementation.
          if (range.attribute('CLASS') == 'com.apple.hls.interstitial' ||
              range.attributes.containsKey('X-ASSET-URI') ||
              range.attributes.containsKey('X-ASSET-LIST')) {
            unhandled.add('#EXT-X-DATERANGE:interstitial');
          }
        case '#EXTINF':
          if (duration != null) throw const FormatException('Missing segment URI');
          final durationText = value.split(',').first;
          if (!RegExp(r'^\d+(?:\.\d+)?$').hasMatch(durationText)) {
            throw const FormatException('Invalid decimal duration');
          }
          duration = double.tryParse(durationText);
          if (duration == null || !duration.isFinite || duration <= 0 || duration > 86400) {
            throw const FormatException('Invalid segment duration');
          }
          final decimal = durationText.split('.');
          durationFloorMicros =
              int.parse(decimal.first) * 1000000 +
              int.parse((decimal.length == 1 ? '' : decimal.last).padRight(6, '0').substring(0, 6));
          extinf = line;
        case '#EXT-X-BYTERANGE':
          if (rangeText != null) throw const FormatException('Duplicate segment range');
          rangeText = value;
        case '#EXT-X-KEY':
          final attributes = _attributes(value);
          final method = attributes['METHOD'];
          if (method == 'NONE') {
            if (attributes.length != 1) throw const FormatException('NONE key has extra attributes');
            keys.clear();
          } else {
            if (method == null || method.isEmpty || attributes['URI'] == null) {
              throw const FormatException('Incomplete key descriptor');
            }
            final key = HlsKeyDescriptor(attributes, _resolve(source, attributes['URI']!));
            keys[key.format] = key;
            if (keys.length > 16) throw const FormatException('Too many key formats');
          }
        case '#EXT-X-MAP':
          final attributes = _attributes(value);
          if (attributes['URI'] == null) throw const FormatException('Missing initialization URI');
          if (attributes.keys.any((key) => key != 'URI' && key != 'BYTERANGE')) {
            unhandled.add('#EXT-X-MAP:attributes');
          }
          final uri = _resolve(source, attributes['URI']!);
          final textRange = attributes['BYTERANGE'];
          // Do not invent an offset for a map with an omitted, ambiguous base.
          final range = textRange == null ? null : _range(textRange, uri, null);
          if (keys.values.any((key) => key.attributes['METHOD'] == 'AES-128' && key.attributes['IV'] == null)) {
            throw const FormatException('Encrypted initialization requires an IV');
          }
          initialization = HlsMapDescriptor(uri, range, keys.values.toList());
        case '#EXT-X-GAP':
          gap = true;
        case '#EXT-X-ENDLIST':
          ended = true;
        case '#EXT-X-VERSION':
          version = _unsigned(value);
          if (version == 0) throw const FormatException('Invalid HLS version');
        case '#EXT-X-PLAYLIST-TYPE':
          if (value != 'EVENT' && value != 'VOD') throw const FormatException('Invalid playlist type');
          playlistType = value;
        case '#EXT-X-ALLOW-CACHE':
          // This legacy tag was removed in HLS version 7. YES carries no
          // media-state restriction; NO must keep the prefetch fallback.
          if (value != 'YES') unhandled.add('#EXT-X-ALLOW-CACHE');
        case '#EXT-X-INDEPENDENT-SEGMENTS':
          independent = true;
        default:
          if (line.startsWith('#')) {
            if (line.startsWith('#EXT')) unhandled.add(tag);
            continue;
          }
          if (ended || duration == null) throw const FormatException('Unexpected media URI');
          if (segments.length >= maximumSegments) throw const FormatException('Too many HLS segments');
          final uri = _resolve(source, line);
          final range = rangeText == null ? null : _range(rangeText, uri, previous);
          final segment = HlsSegmentDescriptor(
            sequence: sequence,
            discontinuity: discontinuity,
            uri: uri,
            duration: duration,
            extinf: extinf!,
            range: range,
            initialization: initialization,
            keys: keys.values.toList(),
            programTime: time,
            programTimeFloor: timeFloor,
            explicitProgramTime: explicitTime,
            gap: gap,
          );
          if (segment.retainedBytes > 64 * 1024) {
            throw const FormatException('Segment dependency metadata exceeds limit');
          }
          lowLatency.validateParent(segment);
          segments.add(segment);
          previous = segment;
          sequence = _checkedAdd(sequence, 1);
          time = time?.add(Duration(microseconds: (duration * 1000000).round()));
          timeFloor = timeFloor?.add(Duration(microseconds: durationFloorMicros!));
          duration = null;
          durationFloorMicros = null;
          extinf = null;
          rangeText = null;
          gap = false;
          explicitTime = false;
      }
    }
    if (target == null || duration != null || rangeText != null || gap) {
      throw const FormatException('Incomplete media snapshot');
    }
    if (segments.any((segment) => segment.duration.round() > target!)) {
      throw const FormatException('Segment exceeds target duration');
    }
    if (dateRanges.isNotEmpty && !sawProgramTime) throw const FormatException('Date ranges require program time');
    return HlsMediaSnapshot._(
      source,
      target,
      ended,
      version,
      independent,
      playlistType,
      segments,
      unhandled,
      dateRanges,
      lowLatency.finish(segments, ended, target, unhandled),
      sha256.convert(encoded).toString(),
    );
  }
}

/// Metadata only. One instance belongs to one selected media playlist and one
/// source generation. A failed refresh is atomic; evictions are explicit and
/// are not evidence that media was downloaded or that the consumer received it.
final class HlsRetainedWindow {
  HlsRetainedWindow(this.source, {this.maximumSegments = 64, this.maximumBytes = 1024 * 1024}) {
    if (maximumSegments < 1 || maximumSegments > 512 || maximumBytes < 1 || maximumBytes > 8 * 1024 * 1024) {
      throw ArgumentError('Invalid HLS retention budget');
    }
  }
  final Uri source;
  final int maximumSegments;
  final int maximumBytes;
  List<HlsSegmentDescriptor> _segments = const [];
  List<HlsSegmentDescriptor> get segments => _segments;
  List<HlsDateRange> _dateRanges = const [];
  List<HlsDateRange> get dateRanges => _dateRanges;
  List<HlsPartialSegment> _pendingParts = const [];
  List<HlsPartialSegment> get pendingParts => _pendingParts;
  double? _partTarget;
  // Once timed history has been pruned, a later backwards clock mapping must
  // fail rather than publish segments whose event metadata was discarded.
  BigInt? _dateRangeFloor;
  int _latestFirst = -1;
  int _retiredBefore = 0;
  bool _ended = false;
  int? _targetDuration;
  int _version = 1;
  bool _independentSegments = false;
  String? _playlistType;
  int get targetDuration => _targetDuration ?? 1;
  int get version => _version;
  bool get independentSegments => _independentSegments;
  bool get ended => _ended;
  int get retainedBytes =>
      _segments.fold<int>(0, (sum, segment) => sum + segment.retainedBytes) +
      _dateRanges.fold<int>(0, (sum, range) => sum + range.retainedBytes) +
      _pendingParts.fold<int>(0, (sum, part) => sum + part.retainedBytes);

  /// The owner keeps published generations and active body leases separately.
  /// Older origin overlap must not reintroduce this explicitly retired prefix.
  void retireBefore(int sequence) {
    if (sequence < 0) throw ArgumentError.value(sequence);
    if (_segments.isNotEmpty && sequence > _segments.last.sequence) throw ArgumentError.value(sequence);
    if (sequence <= _retiredBefore) return;
    _retiredBefore = sequence;
    _segments = List.unmodifiable(_segments.where((s) => s.sequence >= sequence));
    final pruned = _pruneDateRanges(_dateRanges, _segments);
    _dateRanges = pruned.$1;
    if (pruned.$2 != null) _dateRangeFloor = pruned.$2;
  }

  List<HlsSegmentDescriptor> merge(HlsMediaSnapshot snapshot) {
    if (snapshot.source != source || snapshot.unhandledTags.isNotEmpty) {
      throw const FormatException('Snapshot identity or tag contract differs');
    }
    if (_targetDuration != null && _targetDuration != snapshot.targetDuration) {
      throw const FormatException('Target duration changed within a source generation');
    }
    if (_targetDuration != null &&
        (_independentSegments != snapshot.independentSegments || _playlistType != snapshot.playlistType)) {
      throw const FormatException('Playlist contract changed within a source generation');
    }
    final incoming = snapshot.segments;
    if (_partTarget != null &&
        snapshot.lowLatency.partTarget != null &&
        _partTarget != snapshot.lowLatency.partTarget) {
      throw const FormatException('Partial target duration changed within a source generation');
    }
    final pendingParts = _nextPendingParts(_pendingParts, snapshot);
    final pendingBytes = pendingParts.fold<int>(0, (sum, part) => sum + part.retainedBytes);
    if (_dateRangeFloor != null &&
        incoming.any(
          (s) =>
              s.sequence >= _retiredBefore &&
              (s._programTimeFloor == null || _nanoseconds(s._programTimeFloor) < _dateRangeFloor!),
        )) {
      throw const FormatException('Program time crosses retired date range history');
    }
    final ranges = _mergeDateRanges(_dateRanges, snapshot.dateRanges);
    if (incoming.isEmpty) {
      if (_segments.isNotEmpty || ranges.isNotEmpty || pendingParts.isNotEmpty || (_ended && !snapshot.ended)) {
        throw const FormatException('Empty refresh of a retained window');
      }
      _targetDuration = snapshot.targetDuration;
      if (snapshot.version > _version) _version = snapshot.version;
      _independentSegments = snapshot.independentSegments;
      _playlistType = snapshot.playlistType;
      _ended = snapshot.ended;
      return const [];
    }
    if (incoming.first.sequence < _latestFirst ||
        (_segments.isNotEmpty && incoming.last.sequence < _segments.last.sequence) ||
        (_ended && !snapshot.ended)) {
      throw const FormatException('Stale or reopened HLS window');
    }
    final merged = {for (final segment in _segments) segment.sequence: segment};
    for (final segment in incoming) {
      if (segment.sequence < _retiredBefore) continue;
      final existing = merged[segment.sequence];
      if (existing != null &&
          (existing.identity != segment.identity ||
              (existing.programTime != null &&
                  segment.programTime != null &&
                  existing.programTime != segment.programTime))) {
        throw const FormatException('Conflicting HLS segment identity');
      }
      if (_ended && existing == null) throw const FormatException('Ended window grew');
      merged[segment.sequence] = existing ?? segment;
    }
    final values = merged.values.toList()..sort((a, b) => a.sequence.compareTo(b.sequence));
    for (var i = 1; i < values.length; i++) {
      if (values[i].sequence != values[i - 1].sequence + 1) {
        throw const FormatException('Missing HLS sequence interval');
      }
    }
    if (values.any((segment) => segment.retainedBytes > maximumBytes)) {
      throw const FormatException('A segment exceeds retention metadata budget');
    }
    var pruned = _pruneDateRanges(ranges, values);
    var floor = _dateRangeFloor;
    if (pruned.$2 != null) floor = pruned.$2;
    var bytes =
        values.fold<int>(0, (sum, segment) => sum + segment.retainedBytes) +
        pruned.$1.fold<int>(0, (sum, range) => sum + range.retainedBytes) +
        pendingBytes;
    final evicted = <HlsSegmentDescriptor>[];
    while (values.length > maximumSegments || bytes > maximumBytes) {
      if (values.length <= 1) throw const FormatException('Date ranges exceed retention metadata budget');
      final segment = values.removeAt(0);
      bytes -= segment.retainedBytes;
      evicted.add(segment);
      final next = _pruneDateRanges(pruned.$1, values);
      bytes -=
          pruned.$1.fold<int>(0, (sum, r) => sum + r.retainedBytes) -
          next.$1.fold<int>(0, (sum, r) => sum + r.retainedBytes);
      pruned = next;
      if (pruned.$2 != null) floor = pruned.$2;
    }
    if (pruned.$1.length > 256) throw const FormatException('Too many retained date ranges');
    if (snapshot.playlistType == 'VOD' && evicted.isNotEmpty) {
      throw const FormatException('VOD exceeds retained window capacity');
    }
    _segments = List.unmodifiable(values);
    _dateRanges = pruned.$1;
    _pendingParts = pendingParts;
    _partTarget ??= snapshot.lowLatency.partTarget;
    _dateRangeFloor = floor;
    _latestFirst = incoming.first.sequence;
    _targetDuration = snapshot.targetDuration;
    if (snapshot.version > _version) _version = snapshot.version;
    _independentSegments = snapshot.independentSegments;
    _playlistType = snapshot.playlistType;
    _ended = snapshot.ended;
    return List.unmodifiable(evicted);
  }
}

const _maximumInteger = 0x7fffffffffffffff;
int _unsigned(String value) {
  if (!RegExp(r'^\d{1,19}$').hasMatch(value)) throw const FormatException('Invalid HLS integer');
  final parsed = int.tryParse(value);
  if (parsed == null || parsed < 0) throw const FormatException('HLS integer overflow');
  return parsed;
}

int _checkedAdd(int a, int b) {
  if (a > _maximumInteger - b) throw const FormatException('HLS integer overflow');
  return a + b;
}

Uri _resolve(Uri base, String value) {
  final uri = base.resolve(value);
  if (value.isEmpty || !const {'http', 'https'}.contains(uri.scheme) || uri.host.isEmpty || uri.hasFragment) {
    throw const FormatException('Unsupported HLS resource URI');
  }
  return uri;
}

HlsSegmentRange _range(String value, Uri uri, HlsSegmentDescriptor? previous) {
  final parts = value.split('@');
  if (parts.length > 2) throw const FormatException('Invalid byte range');
  final length = _unsigned(parts.first);
  if (length == 0) throw const FormatException('Empty byte range');
  final int offset;
  if (parts.length == 2) {
    offset = _unsigned(parts.last);
  } else {
    if (previous?.uri != uri || previous?.range == null) throw const FormatException('Ambiguous range offset');
    offset = _checkedAdd(previous!.range!.offset, previous.range!.length);
  }
  _checkedAdd(offset, length);
  return HlsSegmentRange(offset, length);
}

Map<String, String> _attributes(String value) {
  final attributes = <String, String>{};
  final pattern = RegExp(r'([A-Z0-9-]+)=("[^"]*"|[^,\s"]+)');
  var offset = 0;
  while (offset < value.length) {
    final match = pattern.matchAsPrefix(value, offset);
    if (match == null || attributes.containsKey(match.group(1))) throw const FormatException('Invalid HLS attributes');
    var text = match.group(2)!;
    if (text.startsWith('"')) text = text.substring(1, text.length - 1);
    attributes[match.group(1)!] = text;
    offset = match.end;
    if (offset == value.length) break;
    if (value[offset++] != ',' || offset == value.length) throw const FormatException('Invalid attribute separator');
  }
  return attributes;
}

DateTime _programTime(String value) {
  final match = RegExp(r'^(\d{4})-(\d{2})-(\d{2})T(\d{2}):(\d{2}):(\d{2})(?:\.\d{1,9})?(Z|[+-](\d{2}):(\d{2}))$')
      .firstMatch(value);
  if (match == null) throw const FormatException('Program time requires a complete date and timezone');
  final parts = [for (var i = 1; i <= 6; i++) int.parse(match.group(i)!)];
  final date = DateTime.utc(parts[0], parts[1], parts[2], parts[3], parts[4], parts[5]);
  if (date.year != parts[0] ||
      date.month != parts[1] ||
      date.day != parts[2] ||
      date.hour != parts[3] ||
      date.minute != parts[4] ||
      date.second != parts[5] ||
      (match.group(8) != null && (int.parse(match.group(8)!) > 23 || int.parse(match.group(9)!) > 59))) {
    throw const FormatException('Invalid calendar time or timezone');
  }
  return DateTime.parse(value).toUtc();
}
