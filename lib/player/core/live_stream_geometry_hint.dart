import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:pure_live/common/models/live_room.dart';

/// Platform-declared geometry for the programme carried by a live stream.
///
/// This is deliberately separate from decoder dimensions: a platform may
/// declare a 1080x1920 portrait programme while a CDN or decoder exposes a
/// 1920x1080 transport canvas with symmetric pillar bars.
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

  static LiveStreamGeometryHint? resolve(LiveRoom? room) {
    if (room == null) return null;
    return switch (room.normalizedPlatformId) {
      'douyin' => resolveDouyin(room.data),
      _ => null,
    };
  }

  /// Resolves the current Douyin stream contract in descending evidence order:
  /// top-level `extra`, default quality descriptor, default stream sdk_params,
  /// consensus quality resolution, then the platform orientation flag.
  @visibleForTesting
  static LiveStreamGeometryHint? resolveDouyin(dynamic rawStreamUrl) {
    if (rawStreamUrl is! Map) return null;

    final extra = _mapValue(rawStreamUrl, 'extra');
    final direct = _dimensionsFromMap(extra, confidence: 0.99, source: 'douyin.extra');
    if (direct != null) return direct;

    final liveCore = _mapValue(rawStreamUrl, 'live_core_sdk_data');
    final pullData = liveCore is Map ? _mapValue(liveCore, 'pull_data') : null;
    final options = pullData is Map ? _mapValue(pullData, 'options') : null;
    final defaultQuality = options is Map ? _mapValue(options, 'default_quality') : null;
    var defaultKey = defaultQuality is Map
        ? _mapValue(defaultQuality, 'sdk_key')?.toString().trim().toLowerCase() ?? ''
        : '';
    if (defaultKey.isEmpty) {
      defaultKey = _mapValue(rawStreamUrl, 'default_resolution')?.toString().trim().toLowerCase() ?? '';
    }
    final rawQualities = options is Map ? _mapValue(options, 'qualities') : null;
    final qualities = rawQualities is List ? rawQualities.whereType<Map>().toList(growable: false) : const <Map>[];

    if (defaultKey.isNotEmpty) {
      for (final quality in qualities) {
        final key = _mapValue(quality, 'sdk_key')?.toString().trim().toLowerCase() ?? '';
        if (key != defaultKey) continue;
        final resolution = _parseResolution(
          _mapValue(quality, 'resolution'),
          confidence: 0.97,
          source: 'douyin.default_quality',
        );
        if (resolution != null) return resolution;
      }
    }

    Map<dynamic, dynamic> streams = const <dynamic, dynamic>{};
    final streamData = pullData is Map ? _mapValue(pullData, 'stream_data') : null;
    final decodedStreamData = _decodeMap(streamData);
    final decodedData = decodedStreamData == null ? null : _mapValue(decodedStreamData, 'data');
    if (decodedData is Map) streams = decodedData;

    if (defaultKey.isNotEmpty) {
      final defaultStream = _caseInsensitiveValue(streams, defaultKey);
      final sdkHint = _dimensionsFromStream(defaultStream, confidence: 0.96, source: 'douyin.default_sdk_params');
      if (sdkHint != null) return sdkHint;
    }

    final candidates = <LiveStreamGeometryHint>[];
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
        final hint = _parseResolution(value, confidence: 0.92, source: 'douyin.candidate_resolution');
        if (hint != null) candidates.add(hint);
      }
    }
    final consensus = _selectAspectConsensus(candidates);
    if (consensus != null) return consensus;

    final orientation = int.tryParse(_mapValue(rawStreamUrl, 'stream_orientation')?.toString() ?? '');
    return switch (orientation) {
      1 => const LiveStreamGeometryHint(
        width: 1080,
        height: 1920,
        confidence: 0.78,
        source: 'douyin.stream_orientation',
      ),
      2 => const LiveStreamGeometryHint(
        width: 1920,
        height: 1080,
        confidence: 0.78,
        source: 'douyin.stream_orientation',
      ),
      _ => null,
    };
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
        _parseResolution(_mapValue(sdkParams, 'resolution'), confidence: confidence, source: source);
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

  static LiveStreamGeometryHint? _parseResolution(dynamic value, {required double confidence, required String source}) {
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
    if (width == null || height == null || width < 120 || height < 120 || width > 16384 || height > 16384) {
      return null;
    }
    final ratio = width / height;
    if (!ratio.isFinite || ratio < 0.30 || ratio > 3.50) return null;
    return LiveStreamGeometryHint(width: width, height: height, confidence: confidence, source: source);
  }

  static LiveStreamGeometryHint? _selectAspectConsensus(List<LiveStreamGeometryHint> candidates) {
    if (candidates.isEmpty) return null;
    candidates.sort((left, right) => (right.width * right.height).compareTo(left.width * left.height));
    final reference = candidates.first;
    final matching = candidates
        .where((candidate) => (candidate.aspectRatio - reference.aspectRatio).abs() / reference.aspectRatio <= 0.08)
        .length;
    if (candidates.length > 1 && matching * 2 <= candidates.length) return null;
    return reference;
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
