// Module: lib/src/model/huya_stream_entry.dart
// Purpose: One CDN entry in a huya room's stream list - the same content, a different delivery path.
// Author: liuchuancong
// Created: 2026-10-11
//
// Spec: docs/sources/live/huya.md. `baseSteamInfoList` is the endpoint's own field name (with its own typo), and
// an entry carries both an flv and an hls url plus a different anti-code per container: picking a line means
// picking one of these, so the pair has to stay together rather than being flattened into two url lists that can
// drift apart.

/// One `baseSteamInfoList` row.
final class HuyaStreamEntry {
  const HuyaStreamEntry({
    required this.streamName,
    this.hlsUrl,
    this.flvUrl,
    this.hlsSuffix,
    this.flvSuffix,
    this.hlsAntiCode = '',
    this.flvAntiCode = '',
  });

  factory HuyaStreamEntry.fromJson(Map<String, Object?> json) => HuyaStreamEntry(
    streamName: '${json['sStreamName'] ?? ''}',
    hlsUrl: _url(json['sHlsUrl']),
    flvUrl: _url(json['sFlvUrl']),
    hlsSuffix: _text(json['sHlsUrlSuffix']),
    flvSuffix: _text(json['sFlvUrlSuffix']),
    hlsAntiCode: '${json['sHlsAntiCode'] ?? ''}',
    flvAntiCode: '${json['sFlvAntiCode'] ?? ''}',
  );

  /// The stream name inside the path; the manifest file is `<streamName>.<suffix>`.
  final String streamName;

  /// The HLS base url. Null when the entry ships only an flv one, which happens on the less common CDNs -
  /// preferring it is why this package stopped rewriting `flv` into `hls` textually.
  final String? hlsUrl;
  final String? flvUrl;

  /// The container suffix the source itself names (`m3u8` / `flv`). Only trusted for the url it came with.
  final String? hlsSuffix;
  final String? flvSuffix;

  /// The lease material, per container. An hls answer signs with [hlsAntiCode]; the flv fallback with
  /// [flvAntiCode] - they are not interchangeable, and the anti-code carries the container in its own fields.
  final String hlsAntiCode;
  final String flvAntiCode;

  /// Whether this row can produce a stream at all: a name and some base url.
  bool get isUsable => streamName.isNotEmpty && (hlsUrl != null || flvUrl != null);

  static String? _url(Object? value) {
    final text = '${value ?? ''}';
    return text.isEmpty ? null : text;
  }

  static String? _text(Object? value) {
    final text = '${value ?? ''}';
    return text.isEmpty ? null : text;
  }
}
