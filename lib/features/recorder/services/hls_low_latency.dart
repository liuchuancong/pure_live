part of 'hls_retained_window.dart';

/// Parallel low-latency channel metadata. Recording consumes complete parent
/// segments, never both parents and parts. No hint/report is a download grant.
final class HlsPartialSegment {
  const HlsPartialSegment(this.media, this.independent);
  // Sequence and programTime identify the parent, not a part's own timestamp.
  final HlsSegmentDescriptor media;
  final bool independent;
  String get identity => '${media.identity}:$independent';
  int get retainedBytes => media.retainedBytes + 6;
}

final class HlsPreloadHint {
  const HlsPreloadHint(this.type, this.uri, this.offset, this.length);
  final String type;
  final Uri uri;
  final int offset;
  final int? length; // An open hint is not an unbounded Range request here.
}

final class HlsRenditionReport {
  const HlsRenditionReport(this.uri, this.lastSequence, this.lastPart);
  final Uri uri;
  final int lastSequence;
  final int? lastPart;
}

final class HlsServerControl {
  const HlsServerControl._(this.canBlockReload, this.skipUntil, this.skipDateRanges, this.holdBack, this.partHoldBack);
  final bool canBlockReload;
  final double? skipUntil;
  final bool skipDateRanges;
  final double? holdBack;
  final double? partHoldBack;
  factory HlsServerControl._parse(String value) {
    final a = _llAttributes(value, {
      'CAN-BLOCK-RELOAD',
      'CAN-SKIP-UNTIL',
      'CAN-SKIP-DATERANGES',
      'HOLD-BACK',
      'PART-HOLD-BACK',
    });
    return HlsServerControl._(
      _llYes(a, 'CAN-BLOCK-RELOAD'),
      _llOptionalDecimal(a, 'CAN-SKIP-UNTIL'),
      _llYes(a, 'CAN-SKIP-DATERANGES'),
      _llOptionalDecimal(a, 'HOLD-BACK'),
      _llOptionalDecimal(a, 'PART-HOLD-BACK'),
    );
  }
}

final class HlsLowLatencyInfo {
  HlsLowLatencyInfo._(
    this.partTarget,
    this.control,
    List<HlsPartialSegment> parts,
    List<HlsPartialSegment> pending,
    List<HlsPreloadHint> hints,
    List<HlsRenditionReport> reports,
  ) : parts = List.unmodifiable(parts),
      pendingParts = List.unmodifiable(pending),
      preloadHints = List.unmodifiable(hints),
      renditionReports = List.unmodifiable(reports);
  final double? partTarget;
  final HlsServerControl? control;
  final List<HlsPartialSegment> parts;
  final List<HlsPartialSegment> pendingParts;
  final List<HlsPreloadHint> preloadHints;
  final List<HlsRenditionReport> renditionReports;
}

Map<String, String> _llAttributes(String text, Set<String> allowed, {Set<String> quoted = const {}}) {
  if (text.length > 16384 || utf8.encode(text).length > 16384 || text.contains(RegExp(r'[\x00-\x1f\x7f]'))) {
    throw const FormatException('Low latency attribute text exceeds contract');
  }
  final values = _attributes(text);
  if (values.keys.any((k) => !allowed.contains(k))) throw const FormatException('Unsupported low latency attribute');
  for (final match in RegExp(r'([A-Z0-9-]+)=("[^"]*"|[^,\s"]+)').allMatches(text)) {
    if (match.group(2)!.startsWith('"') != quoted.contains(match.group(1))) {
      throw const FormatException('Invalid low latency attribute type');
    }
  }
  return values;
}

double _llDecimal(String? value) {
  if (value == null || !RegExp(r'^\d+(?:\.\d+)?$').hasMatch(value)) {
    throw const FormatException('Missing or invalid low latency duration');
  }
  final result = double.tryParse(value);
  if (result == null || !result.isFinite || result <= 0 || result > 86400) {
    throw const FormatException('Invalid low latency duration');
  }
  return result;
}

double? _llOptionalDecimal(Map<String, String> a, String key) => a.containsKey(key) ? _llDecimal(a[key]) : null;
bool _llYes(Map<String, String> a, String key) {
  if (a[key] != null && a[key] != 'YES') throw const FormatException('Invalid low latency flag');
  return a[key] == 'YES';
}

String _partContext(HlsSegmentDescriptor s) =>
    jsonEncode([s.discontinuity, s.initialization?.identity, (s.keys.map((k) => k.identity).toList()..sort())]);
void _validatePartParent(HlsPartialSegment part, HlsSegmentDescriptor parent) {
  if (part.media.sequence != parent.sequence ||
      _partContext(part.media) != _partContext(parent) ||
      (part.media.programTime != null && parent.programTime != null && part.media.programTime != parent.programTime)) {
    throw const FormatException('Partial segment and parent metadata conflict');
  }
}

final class _LowLatencyBuilder {
  double? partTarget;
  HlsServerControl? control;
  final parts = <HlsPartialSegment>[];
  final hints = <HlsPreloadHint>[];
  final reports = <(Uri, Map<String, String>)>[];
  var bytes = 0;
  bool hasPartsFor(int sequence) => parts.isNotEmpty && parts.last.media.sequence == sequence;
  void charge(int size) {
    bytes += size;
    if (bytes > 256 * 1024) throw const FormatException('Low latency snapshot metadata exceeds budget');
  }

  void addPart(
    String value,
    Uri source,
    int sequence,
    int discontinuity,
    HlsMapDescriptor? initialization,
    List<HlsKeyDescriptor> keys,
    DateTime? time,
    DateTime? timeFloor,
  ) {
    if (parts.length >= 1024 || parts.where((p) => p.media.sequence == sequence).length >= 256) {
      throw const FormatException('Too many partial segments');
    }
    final a = _llAttributes(
      value,
      {'URI', 'DURATION', 'INDEPENDENT', 'GAP', 'BYTERANGE'},
      quoted: {'URI', 'BYTERANGE'},
    );
    final uri = _resolve(source, a['URI'] ?? '');
    final prior = hasPartsFor(sequence) ? parts.last.media : null;
    final media = HlsSegmentDescriptor(
      sequence: sequence,
      discontinuity: discontinuity,
      uri: uri,
      duration: _llDecimal(a['DURATION']),
      extinf: '#EXT-X-PART:$value',
      range: a['BYTERANGE'] == null ? null : _range(a['BYTERANGE']!, uri, prior),
      initialization: initialization,
      keys: keys,
      programTime: time,
      programTimeFloor: timeFloor,
      explicitProgramTime: false,
      gap: _llYes(a, 'GAP'),
    );
    final part = HlsPartialSegment(media, _llYes(a, 'INDEPENDENT'));
    charge(part.retainedBytes);
    parts.add(part);
  }

  void addHint(String value, Uri source) {
    final a = _llAttributes(value, {'TYPE', 'URI', 'BYTERANGE-START', 'BYTERANGE-LENGTH'}, quoted: {'URI'});
    final type = a['TYPE'];
    if (!const {'PART', 'MAP'}.contains(type) || hints.any((h) => h.type == type)) {
      throw const FormatException('Unsupported or duplicate preload type');
    }
    final offset = a['BYTERANGE-START'] == null ? 0 : _unsigned(a['BYTERANGE-START']!);
    final length = a['BYTERANGE-LENGTH'] == null ? null : _unsigned(a['BYTERANGE-LENGTH']!);
    if (length != null) {
      if (length == 0) throw const FormatException('Empty preload range');
      _checkedAdd(offset, length);
    }
    final uri = _resolve(source, a['URI'] ?? '');
    charge(utf8.encode(value).length + utf8.encode(uri.toString()).length);
    hints.add(HlsPreloadHint(type!, uri, offset, length));
  }

  void addReport(String value, Uri source) {
    if (reports.length >= 16) throw const FormatException('Too many rendition reports');
    final a = _llAttributes(value, {'URI', 'LAST-MSN', 'LAST-PART'}, quoted: {'URI'});
    final uri = _resolve(source, a['URI'] ?? '');
    if (reports.any((r) => r.$1 == uri)) throw const FormatException('Duplicate rendition report');
    if (a['LAST-MSN'] != null) _unsigned(a['LAST-MSN']!);
    if (a['LAST-PART'] != null) _unsigned(a['LAST-PART']!);
    charge(utf8.encode(value).length + utf8.encode(uri.toString()).length);
    reports.add((uri, a));
  }

  void validateParent(HlsSegmentDescriptor parent) {
    final children = parts.where((p) => p.media.sequence == parent.sequence);
    for (final child in children) {
      _validatePartParent(child, parent);
    }
    // Old completed parents can have an already-removed prefix of PART tags.
    // A visible subset may be shorter, but must not exceed the complete media.
    if (children.fold<double>(0, (sum, p) => sum + p.media.duration) > parent.duration + 0.001) {
      throw const FormatException('Partial duration exceeds its complete parent');
    }
  }

  HlsLowLatencyInfo finish(List<HlsSegmentDescriptor> segments, bool ended, int target, Set<String> unhandled) {
    final pending = parts.where((p) => segments.isEmpty || p.media.sequence > segments.last.sequence).toList();
    if (parts.isNotEmpty && partTarget == null) unhandled.add('#EXT-X-PART');
    if (partTarget != null && control?.partHoldBack == null) unhandled.add('#EXT-X-SERVER-CONTROL:part-hold-back');
    if (ended && hints.isNotEmpty) throw const FormatException('Terminal playlist contains preload hints');
    if (ended && pending.isNotEmpty) unhandled.add('#EXT-X-PART:unfinished-terminal');
    if ((control?.skipUntil != null && control!.skipUntil! < 6 * target) ||
        (control?.skipDateRanges == true && control?.skipUntil == null) ||
        (control?.holdBack != null && control!.holdBack! < 3 * target) ||
        (partTarget != null && control?.partHoldBack != null && control!.partHoldBack! < 2 * partTarget!)) {
      throw const FormatException('Invalid server control bounds');
    }
    for (var i = 0; i < parts.length; i++) {
      final p = parts[i];
      if (partTarget == null) continue;
      if (p.media.duration > partTarget! + 0.000001) throw const FormatException('Partial duration exceeds target');
      final next = i + 1 < parts.length ? parts[i + 1] : null;
      if (next != null &&
          next.media.sequence == p.media.sequence &&
          !p.independent &&
          !p.media.gap &&
          !next.media.gap &&
          p.media.duration + 0.000001 < partTarget! * 0.85) {
        throw const FormatException('Non-final partial duration is too short');
      }
    }
    if (pending.fold<double>(0, (sum, p) => sum + p.media.duration) > target + 0.5) {
      throw const FormatException('Unfinished parent exceeds target extent');
    }
    final lastSequence = pending.isNotEmpty ? pending.last.media.sequence : segments.lastOrNull?.sequence;
    final lastGroup = parts.where((p) => p.media.sequence == lastSequence).toList();
    final resolved = <HlsRenditionReport>[];
    for (final (uri, a) in reports) {
      final last = a['LAST-MSN'] == null ? lastSequence : _unsigned(a['LAST-MSN']!);
      if (last == null) throw const FormatException('Rendition report has no sequence base');
      final part = a['LAST-PART'] == null
          ? (lastGroup.isEmpty ? null : lastGroup.length - 1)
          : _unsigned(a['LAST-PART']!);
      resolved.add(HlsRenditionReport(uri, last, part));
    }
    return HlsLowLatencyInfo._(partTarget, control, parts, pending, hints, resolved);
  }
}

List<HlsPartialSegment> _nextPendingParts(List<HlsPartialSegment> previous, HlsMediaSnapshot snapshot) {
  final next = snapshot.lowLatency.pendingParts;
  if (previous.isEmpty) return next;
  final sequence = previous.first.media.sequence;
  final parents = snapshot.segments.where((s) => s.sequence == sequence);
  if (parents.isNotEmpty) {
    for (final part in previous) {
      _validatePartParent(part, parents.single);
    }
    if (previous.fold<double>(0, (sum, p) => sum + p.media.duration) > parents.single.duration + 0.001) {
      throw const FormatException('Published parent is shorter than its earlier parts');
    }
    return next;
  }
  if (snapshot.ended || (next.isNotEmpty && next.first.media.sequence != sequence)) {
    throw const FormatException('Unfinished parent was skipped');
  }
  if (next.isEmpty) return previous; // A temporary omission is not a completed parent.
  if (next.length < previous.length) throw const FormatException('Unfinished partial prefix disappeared');
  for (var i = 0; i < previous.length; i++) {
    if (previous[i].identity != next[i].identity ||
        (previous[i].media.programTime != null &&
            next[i].media.programTime != null &&
            previous[i].media.programTime != next[i].media.programTime)) {
      throw const FormatException('Unfinished partial identity changed');
    }
  }
  return next;
}
