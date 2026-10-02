import 'dart:convert';

import 'hls_retained_window.dart';

/// Rendering is separate from fetching: a caller must select a contiguous,
/// fully available prefix and hold its resource leases before publishing it.
/// A local URI identifies the original resource; BYTERANGE stays absolute.
String renderHlsRetainedManifest(
  HlsRetainedWindow window, {
  required Uri Function(Uri upstream) localUri,
  Uri Function(HlsSegmentDescriptor segment)? segmentUri,
  Uri Function(HlsMapDescriptor initialization)? initializationUri,
  Uri Function(HlsKeyDescriptor key)? keyUri,
  int? throughSequence,
  bool finish = false,
  bool startAtFirst = false,
  int maximumBytes = 8 * 1024 * 1024,
}) {
  if (maximumBytes < 1 || maximumBytes > 8 * 1024 * 1024) {
    throw ArgumentError.value(maximumBytes, 'maximumBytes');
  }
  final all = window.segments;
  if (throughSequence != null && !all.any((s) => s.sequence == throughSequence)) {
    throw ArgumentError.value(throughSequence, 'throughSequence');
  }
  final segments = throughSequence == null ? all : all.takeWhile((s) => s.sequence <= throughSequence).toList();
  final output = StringBuffer();
  var bytes = 0;
  void line(String value) {
    bytes += utf8.encode(value).length + 1;
    if (bytes > maximumBytes) throw const FormatException('Rendered HLS exceeds publication budget');
    output.writeln(value);
  }

  String resource(Uri upstream, [Uri? mapped]) {
    final uri = mapped ?? localUri(upstream);
    final value = uri.toString();
    if (!const {'http', 'https'}.contains(uri.scheme) ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        uri.hasFragment ||
        value.length > 65536 ||
        value.contains(RegExp('["\r\n]'))) {
      throw const FormatException('Invalid published HLS resource URI');
    }
    return value;
  }

  line('#EXTM3U');
  // Non-I-frame MAP requires version 6. Keeping a higher declared version
  // avoids weakening other supported feature contracts during retention.
  line('#EXT-X-VERSION:${window.version < 6 ? 6 : window.version}');
  if (startAtFirst && segments.isNotEmpty) line('#EXT-X-START:TIME-OFFSET=0,PRECISE=NO');
  line('#EXT-X-TARGETDURATION:${window.targetDuration}');
  line('#EXT-X-MEDIA-SEQUENCE:${segments.isEmpty ? 0 : segments.first.sequence}');
  line('#EXT-X-DISCONTINUITY-SEQUENCE:${segments.isEmpty ? 0 : segments.first.discontinuity}');
  if (window.independentSegments) line('#EXT-X-INDEPENDENT-SEGMENTS');
  if (window.dateRanges.isNotEmpty) {
    if (!segments.any((segment) => segment.programTime != null)) {
      throw const FormatException('Published date ranges require a program time anchor');
    }
    for (final range in window.dateRanges) {
      line(range.manifestLine);
    }
  }
  // Render a normal media playlist, not EVENT: a bounded retained prefix can
  // eventually be removed. ENDLIST still carries the actual terminal state.
  var currentKeys = <HlsKeyDescriptor>[];
  void keys(List<HlsKeyDescriptor> wanted) {
    String identity(List<HlsKeyDescriptor> values) => jsonEncode(values.map((key) => key.identity).toList()..sort());
    if (identity(currentKeys) == identity(wanted)) return;
    if (currentKeys.isNotEmpty) line('#EXT-X-KEY:METHOD=NONE');
    for (final key in wanted) {
      final fields = <String>[];
      for (final entry in key.attributes.entries) {
        final name = entry.key;
        if (!const {'METHOD', 'URI', 'IV', 'KEYFORMAT', 'KEYFORMATVERSIONS'}.contains(name)) {
          throw const FormatException('Unsupported key attribute in retained publication');
        }
        final value = name == 'URI' ? resource(key.uri!, keyUri?.call(key)) : entry.value;
        if (value.contains(RegExp('["\r\n]'))) throw const FormatException('Invalid key attribute');
        if ((name == 'METHOD' && !RegExp(r'^[A-Z0-9-]+$').hasMatch(value)) ||
            (name == 'IV' && !RegExp(r'^0[xX][0-9a-fA-F]{1,32}$').hasMatch(value))) {
          throw const FormatException('Invalid unquoted key attribute');
        }
        fields.add(const {'METHOD', 'IV'}.contains(name) ? '$name=$value' : '$name="$value"');
      }
      line('#EXT-X-KEY:${fields.join(',')}');
    }
    currentKeys = wanted;
  }

  HlsSegmentDescriptor? previous;
  HlsMapDescriptor? map;
  for (final segment in segments) {
    if (previous != null) {
      final delta = segment.discontinuity - previous.discontinuity;
      if (delta < 0 || delta > 512) throw const FormatException('Unsupported discontinuity interval');
      for (var i = 0; i < delta; i++) {
        line('#EXT-X-DISCONTINUITY');
      }
    }
    final initialization = segment.initialization;
    if (initialization?.identity != map?.identity) {
      if (initialization == null) {
        // HLS has no MAP=NONE. Never accidentally apply the old CMAF header.
        throw const FormatException('Initialization disappeared within retained publication');
      }
      keys(initialization.keys);
      final range = initialization.range;
      line(
        '#EXT-X-MAP:URI="${resource(initialization.uri, initializationUri?.call(initialization))}"'
        '${range == null ? '' : ',BYTERANGE="${range.identity}"'}',
      );
      map = initialization;
    }
    keys(segment.keys);
    if (segment.programTime != null &&
        (previous == null ||
            segment.explicitProgramTime ||
            previous.discontinuity != segment.discontinuity ||
            previous.programTime == null)) {
      line('#EXT-X-PROGRAM-DATE-TIME:${segment.programTime!.toUtc().toIso8601String()}');
    }
    line(segment.extinf);
    if (segment.range != null) line('#EXT-X-BYTERANGE:${segment.range!.identity}');
    if (segment.gap) line('#EXT-X-GAP');
    line(resource(segment.uri, segmentUri?.call(segment)));
    previous = segment;
  }
  if (finish || (window.ended && (throughSequence == null || throughSequence == all.last.sequence))) {
    line('#EXT-X-ENDLIST');
  }
  return output.toString();
}
