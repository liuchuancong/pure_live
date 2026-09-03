import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:pure_live/common/models/live_room.dart';

/// Platform-declared geometry for the programme carried by a live stream.
///
/// This is deliberately separate from decoder dimensions. It may classify the
/// initial programme before the first frame, but it never supplies crop pixel
/// coordinates or overrides a plausible post-rotation decoder display size.
@immutable
class LiveStreamGeometryHint {
  const LiveStreamGeometryHint({
    required this.width,
    required this.height,
    required this.confidence,
    required this.source,
  });

  final int width;
  final int height;
  final double confidence;
  final String source;

  double get aspectRatio => width / height;
}

class LiveStreamGeometryHintResolver {
  const LiveStreamGeometryHintResolver._();

  static LiveStreamGeometryHint? resolve(LiveRoom? room, {String? selectedUrl}) {
    if (room == null) return null;
    return switch (room.normalizedPlatformId) {
      'douyin' => resolveDouyin(room.data, selectedUrl: selectedUrl),
      _ => null,
    };
  }

  /// Resolves the current Douyin programme geometry from stream-specific data.
  ///
  /// `stream_orientation` selects the normal/alternate composition of a
  /// dual-screen room; it is not a portrait/landscape dimension. Likewise,
  /// top-level `extra.width/height` is also used by square audio placeholders.
  /// Neither field is therefore treated as aspect evidence. The selected URL
  /// is joined back to its stable sdk key first. Default-stream and consensus
  /// fallbacks are used only before a concrete URL is selected; applying them
  /// to an unmatched URL could crop a different dual-screen composition.
  @visibleForTesting
  static LiveStreamGeometryHint? resolveDouyin(dynamic rawStreamUrl, {String? selectedUrl}) {
    if (rawStreamUrl is! Map) return null;

    final liveCore = _mapValue(rawStreamUrl, 'live_core_sdk_data');
    final pullData = liveCore is Map ? _mapValue(liveCore, 'pull_data') : null;
    final options = pullData is Map ? _mapValue(pullData, 'options') : null;
    final defaultQuality = options is Map ? _mapValue(options, 'default_quality') : null;
    var defaultKey = defaultQuality is Map
        ? _mapValue(defaultQuality, 'sdk_key')?.toString().trim().toLowerCase() ?? ''
        : '';
    if (defaultKey.isEmpty) {
      defaultKey =
          _mapValue(rawStreamUrl, 'default_resolution')?.toString().trim().toLowerCase() ?? '';
    }
    final rawQualities = options is Map ? _mapValue(options, 'qualities') : null;
    final qualities = rawQualities is List
        ? rawQualities.whereType<Map>().toList(growable: false)
        : const <Map>[];

    Map<dynamic, dynamic> streams = const <dynamic, dynamic>{};
    final streamData = pullData is Map ? _mapValue(pullData, 'stream_data') : null;
    final decodedStreamData = _decodeMap(streamData);
    final decodedData = decodedStreamData == null ? null : _mapValue(decodedStreamData, 'data');
    if (decodedData is Map) streams = decodedData;

    final selectedKey = _findSelectedStreamKey(
      rawStreamUrl: rawStreamUrl,
      streams: streams,
      selectedUrl: selectedUrl,
    );
    final hasSelectedUrl = selectedUrl?.trim().isNotEmpty == true;
    if (selectedKey.isNotEmpty) {
      final selectedStream = _caseInsensitiveValue(streams, selectedKey);
      final sdkHint = _dimensionsFromStream(
        selectedStream,
        confidence: 0.995,
        source: 'douyin.selected_sdk_params',
      );
      if (sdkHint != null) return sdkHint;

      final qualityHint = _qualityResolutionForKey(
        qualities,
        selectedKey,
        confidence: 0.99,
        source: 'douyin.selected_quality',
      );
      if (qualityHint != null) return qualityHint;
      if (selectedKey == defaultKey && defaultQuality is Map) {
        final declaredDefault = _parseResolution(
          _mapValue(defaultQuality, 'resolution'),
          confidence: 0.985,
          source: 'douyin.selected_default_quality',
        );
        if (declaredDefault != null) return declaredDefault;
      }
    }

    // Once playback has selected a concrete URL, geometry from another quality
    // or from the default dual-screen composition is worse than no hint. The
    // decoder and active-frame probe remain authoritative in this case.
    if (hasSelectedUrl && selectedKey.isEmpty) return null;

    if (defaultKey.isNotEmpty && !hasSelectedUrl) {
      if (defaultQuality is Map) {
        final declaredDefault = _parseResolution(
          _mapValue(defaultQuality, 'resolution'),
          confidence: 0.975,
          source: 'douyin.default_quality',
        );
        if (declaredDefault != null) return declaredDefault;
      }
      final qualityHint = _qualityResolutionForKey(
        qualities,
        defaultKey,
        confidence: 0.97,
        source: 'douyin.default_quality',
      );
      if (qualityHint != null) return qualityHint;
    }

    if (defaultKey.isNotEmpty && !hasSelectedUrl) {
      final defaultStream = _caseInsensitiveValue(streams, defaultKey);
      final sdkHint = _dimensionsFromStream(
        defaultStream,
        confidence: 0.96,
        source: 'douyin.default_sdk_params',
      );
      if (sdkHint != null) return sdkHint;
    }

    final candidates = <LiveStreamGeometryHint>[];
    if (defaultQuality is Map) {
      final resolution = _parseResolution(
        _mapValue(defaultQuality, 'resolution'),
        confidence: 0.95,
        source: 'douyin.default_quality',
      );
      if (resolution != null) candidates.add(resolution);
    }
    for (final quality in qualities) {
      final resolution = _parseResolution(
        _mapValue(quality, 'resolution'),
        confidence: 0.94,
        source: 'douyin.quality_resolution',
      );
      if (resolution != null) candidates.add(resolution);
    }
    for (final stream in streams.values) {
      final sdkHint = _dimensionsFromStream(stream, confidence: 0.93, source: 'douyin.sdk_params');
      if (sdkHint != null) candidates.add(sdkHint);
    }
    final candidateResolution = _mapValue(rawStreamUrl, 'candidate_resolution');
    if (candidateResolution is List) {
      for (final value in candidateResolution) {
        final hint = _parseResolution(
          value,
          confidence: 0.92,
          source: 'douyin.candidate_resolution',
        );
        if (hint != null) candidates.add(hint);
      }
    }
    final consensus = _selectAspectConsensus(candidates);
    if (consensus != null) return consensus;
    return null;
  }

  static LiveStreamGeometryHint? _qualityResolutionForKey(
    List<Map> qualities,
    String requestedKey, {
    required double confidence,
    required String source,
  }) {
    final normalizedKey = requestedKey.trim().toLowerCase();
    if (normalizedKey.isEmpty) return null;
    for (final quality in qualities) {
      final key = _mapValue(quality, 'sdk_key')?.toString().trim().toLowerCase() ?? '';
      if (key != normalizedKey) continue;
      return _parseResolution(
        _mapValue(quality, 'resolution'),
        confidence: confidence,
        source: source,
      );
    }
    return null;
  }

  static String _findSelectedStreamKey({
    required Map rawStreamUrl,
    required Map<dynamic, dynamic> streams,
    required String? selectedUrl,
  }) {
    final target = selectedUrl?.trim() ?? '';
    if (target.isEmpty) return '';

    for (final entry in streams.entries) {
      final main = entry.value is Map ? _mapValue(entry.value as Map, 'main') : null;
      if (main is! Map) continue;
      if (_samePlayableUrl(target, _mapValue(main, 'flv')) ||
          _samePlayableUrl(target, _mapValue(main, 'hls'))) {
        return entry.key?.toString().trim().toLowerCase() ?? '';
      }
    }

    for (final mapName in const ['flv_pull_url', 'hls_pull_url_map']) {
      final urls = _mapValue(rawStreamUrl, mapName);
      if (urls is! Map) continue;
      for (final entry in urls.entries) {
        if (_samePlayableUrl(target, entry.value)) {
          return entry.key?.toString().trim().toLowerCase() ?? '';
        }
      }
    }
    return '';
  }

  static bool _samePlayableUrl(String selectedUrl, dynamic candidate) {
    final value = candidate?.toString().trim() ?? '';
    if (value.isEmpty) return false;
    if (selectedUrl == value) return true;
    final selected = Uri.tryParse(selectedUrl);
    final other = Uri.tryParse(value);
    if (selected == null || other == null) return false;
    // Some extractors append a codec selector after reading sdk_params. It does
    // not change which stable quality entry owns the URL.
    return selected.scheme == other.scheme &&
        selected.host == other.host &&
        selected.path == other.path &&
        _queryWithoutCodec(selected) == _queryWithoutCodec(other);
  }

  static String _queryWithoutCodec(Uri uri) {
    final entries =
        uri.queryParametersAll.entries
            .where((entry) => entry.key.toLowerCase() != 'codec')
            .map((entry) => MapEntry(entry.key, List<String>.from(entry.value)))
            .toList(growable: false)
          ..sort((left, right) => left.key.compareTo(right.key));
    return entries.expand((entry) => entry.value.map((value) => '${entry.key}=$value')).join('&');
  }

  static LiveStreamGeometryHint? _dimensionsFromStream(
    dynamic stream, {
    required double confidence,
    required String source,
  }) {
    if (stream is! Map) return null;
    final main = _mapValue(stream, 'main');
    if (main is! Map) return null;
    final direct = _dimensionsFromMap(main, confidence: confidence, source: source);
    if (direct != null) return direct;
    final sdkParams = _decodeMap(_mapValue(main, 'sdk_params'));
    if (sdkParams == null) return null;
    return _dimensionsFromMap(sdkParams, confidence: confidence, source: source) ??
        _parseResolution(
          _mapValue(sdkParams, 'resolution'),
          confidence: confidence,
          source: source,
        );
  }

  static LiveStreamGeometryHint? _dimensionsFromMap(
    dynamic value, {
    required double confidence,
    required String source,
  }) {
    if (value is! Map) return null;
    final width = _positiveInt(_mapValue(value, 'width'));
    final height = _positiveInt(_mapValue(value, 'height'));
    return _validatedHint(width, height, confidence: confidence, source: source);
  }

  static LiveStreamGeometryHint? _parseResolution(
    dynamic value, {
    required double confidence,
    required String source,
  }) {
    final text = value?.toString().trim() ?? '';
    final match = RegExp(r'(\d{2,5})\s*[xX×*]\s*(\d{2,5})').firstMatch(text);
    if (match == null) return null;
    return _validatedHint(
      int.tryParse(match.group(1)!),
      int.tryParse(match.group(2)!),
      confidence: confidence,
      source: source,
    );
  }

  static LiveStreamGeometryHint? _validatedHint(
    int? width,
    int? height, {
    required double confidence,
    required String source,
  }) {
    if (width == null ||
        height == null ||
        width < 120 ||
        height < 120 ||
        width > 16384 ||
        height > 16384) {
      return null;
    }
    final ratio = width / height;
    if (!ratio.isFinite || ratio < 0.30 || ratio > 3.50) return null;
    return LiveStreamGeometryHint(
      width: width,
      height: height,
      confidence: confidence,
      source: source,
    );
  }

  static LiveStreamGeometryHint? _selectAspectConsensus(List<LiveStreamGeometryHint> candidates) {
    if (candidates.isEmpty) return null;
    candidates.sort(
      (left, right) => (right.width * right.height).compareTo(left.width * left.height),
    );
    final reference = candidates.first;
    final matching = candidates
        .where(
          (candidate) =>
              (candidate.aspectRatio - reference.aspectRatio).abs() / reference.aspectRatio <= 0.08,
        )
        .length;
    if (candidates.length > 1 && matching * 2 <= candidates.length) return null;
    return LiveStreamGeometryHint(
      width: reference.width,
      height: reference.height,
      confidence: reference.confidence,
      source: 'douyin.stream_consensus',
    );
  }

  static Map<dynamic, dynamic>? _decodeMap(dynamic value) {
    if (value is Map) return value;
    final text = value?.toString().trim() ?? '';
    if (!text.startsWith('{')) return null;
    try {
      final decoded = json.decode(text);
      return decoded is Map ? decoded : null;
    } on FormatException {
      return null;
    }
  }

  static int? _positiveInt(dynamic value) {
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '');
  }

  static dynamic _mapValue(Map<dynamic, dynamic> map, String key) {
    final direct = map[key];
    if (direct != null) return direct;
    return _caseInsensitiveValue(map, key);
  }

  static dynamic _caseInsensitiveValue(Map<dynamic, dynamic> map, String key) {
    final normalized = key.toLowerCase();
    for (final entry in map.entries) {
      if (entry.key?.toString().toLowerCase() == normalized) return entry.value;
    }
    return null;
  }
}
