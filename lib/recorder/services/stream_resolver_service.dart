import 'package:pure_live/common/index.dart';
import 'package:pure_live/model/live_play_quality.dart';
import 'package:pure_live/core/interface/live_site.dart';
import 'package:pure_live/player/utils/player_consts.dart';

enum StreamErrorType {
  roomNotFound,
  notLive,
  noQuality,
  cdnFailed,
  networkError,
  loginExpired,
  banned,
  unknown,
}

class StreamException implements Exception {
  final StreamErrorType type;

  final String message;

  /// Whether a fresh room/quality request can recover this failure.
  final bool retryable;

  const StreamException({required this.type, required this.message, this.retryable = true});

  @override
  String toString() {
    return 'StreamException(type: $type, message: $message, retryable: $retryable)';
  }
}

/// One recorder input selected from the platform's current quality and CDN
/// response. Keeping this metadata with the URL lets retries rotate away from
/// the failed CDN and keeps the recorder UI honest about the applied quality.
class ResolvedRecordStream {
  const ResolvedRecordStream({
    required this.url,
    required this.quality,
    required this.qualityCursorId,
    required this.lineIndex,
    required this.candidateUrls,
    this.refreshAt,
    this.invalidAt,
  });

  final String url;
  final LivePlayQuality quality;

  /// Identifier of the quality request that produced [url]. This is kept
  /// separate from [quality] because a platform may transparently downgrade
  /// the applied quality while the retry cursor must still advance through the
  /// request tiers deterministically.
  final String qualityCursorId;
  final int lineIndex;
  final List<String> candidateUrls;

  /// Platform-advertised instant to acquire a new signed transport. This is
  /// metadata, never a persisted credential. A null value keeps ordinary
  /// long-lived platforms on the error-driven recorder path.
  final DateTime? refreshAt;

  /// Last safe instant for opening this exact URL, when the adapter can derive
  /// one. It is retained for diagnostics and future bounded retry decisions.
  final DateTime? invalidAt;

  String get lineLabel => '线路${lineIndex + 1}';
}

typedef RecorderLiveSiteResolver = LiveSite Function(String platform);

class StreamResolverService extends GetxService {
  StreamResolverService({RecorderLiveSiteResolver? siteResolver})
    : _siteResolver = siteResolver ?? ((platform) => Sites.of(platform).liveSite);

  static StreamResolverService get to => Get.find();

  static const Set<String> _recordableSchemes = {
    'http',
    'https',
    'rtmp',
    'rtmps',
    'rtsp',
    'rtp',
    'udp',
    'tcp',
    'srt',
    'file',
  };

  final RecorderLiveSiteResolver _siteResolver;

  Future<ResolvedRecordStream> resolveStream({
    required String roomId,
    required String platform,
    required String preferredQuality,
    String? previousQualityId,
    int? previousLineIndex,
    bool renewCurrent = false,
  }) async {
    final normalizedPlatform = platform.trim().toLowerCase();
    final normalizedRoomId = roomId.trim();
    if (normalizedRoomId.isEmpty) {
      throw const StreamException(
        type: StreamErrorType.roomNotFound,
        message: 'Room id is empty',
        retryable: false,
      );
    }
    if (!Sites.isSupported(normalizedPlatform)) {
      throw StreamException(
        type: StreamErrorType.unknown,
        message: 'Unsupported live site: $normalizedPlatform',
        retryable: false,
      );
    }

    try {
      final site = _siteResolver(normalizedPlatform);
      late final LiveRoom detail;
      try {
        detail = site is LiveSiteRecordRoomResolver
            ? await (site as LiveSiteRecordRoomResolver).getRoomDetailForRecording(
                roomId: normalizedRoomId,
                platform: normalizedPlatform,
              )
            : await site.getRoomDetail(roomId: normalizedRoomId, platform: normalizedPlatform);
      } catch (error) {
        // UI room loaders commonly preserve the previous card on request
        // failure. Recording uses a strict capability so a transient metadata
        // error enters bounded retry instead of becoming a false offline stop.
        throw StreamException(
          type: StreamErrorType.networkError,
          message: '${i18n('stream_get_room_failed')}: $error',
        );
      }

      if (detail.effectiveLiveStatus == LiveStatus.banned) {
        throw StreamException(
          type: StreamErrorType.banned,
          message: i18n('stream_room_banned'),
          retryable: false,
        );
      }
      final explicitlyPlayable = detail.isPlayableNow;
      if (!explicitlyPlayable && detail.isExplicitlyOfflineNow) {
        throw StreamException(
          type: StreamErrorType.notLive,
          message: i18n('stream_not_live'),
          retryable: false,
        );
      }
      if (!explicitlyPlayable) {
        throw StreamException(
          type: StreamErrorType.networkError,
          message: i18n('stream_room_state_unknown'),
        );
      }

      late final List<LivePlayQuality> qualities;
      try {
        qualities = await site.getPlayQualites(detail: detail);
      } on StreamException {
        rethrow;
      } catch (error) {
        throw StreamException(
          type: StreamErrorType.networkError,
          message: '${i18n('stream_get_quality_failed')}: $error',
        );
      }

      if (qualities.isEmpty) {
        // A live room can temporarily return an empty quality envelope while
        // its CDN is being assigned. Use the bounded recorder retry policy
        // instead of turning that transient state into a permanent stop.
        throw StreamException(
          type: StreamErrorType.noQuality,
          message: i18n('stream_no_available_quality'),
        );
      }

      final orderedQualities = orderQualities(qualities, preferredQuality);
      // Stream URLs are often signed and short lived. Resolving every quality
      // and every CDN before FFmpeg starts used to perform N sequential API
      // calls, delaying first byte and aging the first URL. Resolve only the
      // cursor tier needed for this attempt: next CDN of the same quality,
      // then the first CDN of the next quality. A complete failure may wrap to
      // line 1 of the previous tier with a fresh signature.
      Object? lastError;
      final usesLineCursor = site is LivePlayUrlCursorResolver;
      final previousQualityIndex = previousQualityId == null
          ? -1
          : orderedQualities.indexWhere(
              (quality) => quality.selectionId.toString() == previousQualityId,
            );
      _ResolvedQuality? previousResolution;

      if (previousQualityIndex >= 0) {
        if (renewCurrent) {
          try {
            final renewed = await _resolveQuality(
              site: site,
              detail: detail,
              orderedQualities: orderedQualities,
              requestedQuality: orderedQualities[previousQualityIndex],
              lineIndex: usesLineCursor ? (previousLineIndex ?? 0).clamp(0, 1 << 20).toInt() : null,
            );
            if (renewed.urls.isNotEmpty) {
              final sameLinePosition = usesLineCursor
                  ? 0
                  : (previousLineIndex ?? 0).clamp(0, renewed.urls.length - 1).toInt();
              return renewed.select(sameLinePosition);
            }
          } catch (error) {
            // Renewal prefers the current quality/CDN so codecs and output
            // remain stable. If that exact route vanished, continue through
            // the ordinary bounded line/quality fallback below.
            lastError = error;
          }
        }
        try {
          final nextLine = (previousLineIndex ?? -1) + 1;
          previousResolution = await _resolveQuality(
            site: site,
            detail: detail,
            orderedQualities: orderedQualities,
            requestedQuality: orderedQualities[previousQualityIndex],
            lineIndex: usesLineCursor ? nextLine : null,
          );
          if (usesLineCursor && previousResolution.urls.isNotEmpty) {
            return previousResolution.select(0);
          }
          if (!usesLineCursor && nextLine >= 0 && nextLine < previousResolution.urls.length) {
            return previousResolution.select(nextLine);
          }
        } catch (error) {
          lastError = error;
        }
      }

      final startQualityIndex = previousQualityIndex < 0 ? 0 : previousQualityIndex + 1;
      final qualitiesToTry = previousQualityIndex < 0
          ? orderedQualities.length
          : orderedQualities.length - 1;
      for (var offset = 0; offset < qualitiesToTry; offset++) {
        final qualityIndex = (startQualityIndex + offset) % orderedQualities.length;
        try {
          final resolved = await _resolveQuality(
            site: site,
            detail: detail,
            orderedQualities: orderedQualities,
            requestedQuality: orderedQualities[qualityIndex],
            lineIndex: usesLineCursor ? 0 : null,
          );
          if (resolved.urls.isNotEmpty) return resolved.select(0);
        } catch (error) {
          lastError = error;
        }
      }

      if (previousQualityIndex >= 0) {
        try {
          final wrapped = usesLineCursor
              ? await _resolveQuality(
                  site: site,
                  detail: detail,
                  orderedQualities: orderedQualities,
                  requestedQuality: orderedQualities[previousQualityIndex],
                  lineIndex: 0,
                )
              : previousResolution;
          if (wrapped?.urls.isNotEmpty == true) return wrapped!.select(0);
        } catch (error) {
          lastError = error;
        }
      }

      throw StreamException(
        type: StreamErrorType.cdnFailed,
        message: lastError == null
            ? i18n('stream_all_cdn_failed')
            : '${i18n('stream_all_cdn_failed')}: $lastError',
      );
    } on StreamException {
      rethrow;
    } catch (error) {
      throw StreamException(type: StreamErrorType.unknown, message: error.toString());
    }
  }

  /// Returns a new list in best-to-worst platform order, then moves the tier
  /// closest to the user's five-level preference to the front. Platform
  /// adapters expose incomparable identifiers (qn, bitrate, sdk_key, gear),
  /// so recorder selection must never compare those identifiers directly.
  static List<LivePlayQuality> orderQualities(
    List<LivePlayQuality> source,
    String preferredQuality,
  ) {
    final seenIds = <String>{};
    final indexed = source.indexed
        .where((entry) => seenIds.add(entry.$2.selectionId.toString()))
        .toList(growable: false);
    if (indexed.isEmpty) return const <LivePlayQuality>[];
    final hasSortSignal = indexed.any((entry) => entry.$2.sort != 0);
    final ordered = [...indexed];
    if (hasSortSignal) {
      ordered.sort((left, right) {
        final bySort = right.$2.sort.compareTo(left.$2.sort);
        return bySort != 0 ? bySort : left.$1.compareTo(right.$1);
      });
    }
    final qualities = ordered.map((entry) => entry.$2).toList(growable: false);
    if (qualities.length < 2) return qualities;

    final normalizedPreference = _normalizeQualityLabel(preferredQuality);
    final exactIndex = qualities.indexWhere(
      (quality) => _normalizeQualityLabel(quality.quality) == normalizedPreference,
    );
    if (exactIndex >= 0) return _moveToFront(qualities, exactIndex);

    var preferenceIndex = PlayerConsts.resolutions.indexOf(preferredQuality);
    if (preferenceIndex < 0) preferenceIndex = 0;
    final targetRatio = preferenceIndex / (PlayerConsts.resolutions.length - 1);
    var closestIndex = 0;
    var closestDistance = double.infinity;
    for (var index = 0; index < qualities.length; index++) {
      final ratio = index / (qualities.length - 1);
      final distance = (ratio - targetRatio).abs();
      if (distance < closestDistance) {
        closestIndex = index;
        closestDistance = distance;
      }
    }
    return _moveToFront(qualities, closestIndex);
  }

  static List<LivePlayQuality> _moveToFront(List<LivePlayQuality> qualities, int index) {
    if (index <= 0) return List<LivePlayQuality>.unmodifiable(qualities);
    return List<LivePlayQuality>.unmodifiable([
      qualities[index],
      ...qualities.take(index),
      ...qualities.skip(index + 1),
    ]);
  }

  static String _normalizeQualityLabel(String value) =>
      value.toLowerCase().replaceAll(RegExp(r'[\s_-]+'), '');

  static LivePlayQuality _appliedQuality(
    List<LivePlayQuality> qualities,
    LivePlayQuality requested,
    Object? appliedId,
  ) {
    if (appliedId == null) return requested;
    final normalized = appliedId.toString();
    return qualities.firstWhere(
      (quality) => quality.selectionId.toString() == normalized,
      orElse: () => requested,
    );
  }

  static Future<_ResolvedQuality> _resolveQuality({
    required LiveSite site,
    required LiveRoom detail,
    required List<LivePlayQuality> orderedQualities,
    required LivePlayQuality requestedQuality,
    int? lineIndex,
  }) async {
    final resolution = site is LivePlayUrlCursorResolver && lineIndex != null
        ? await (site as LivePlayUrlCursorResolver).resolvePlayUrlAtRaw(
            detail: detail,
            quality: requestedQuality,
            lineIndex: lineIndex,
          )
        : await site.resolvePlayUrls(detail: detail, quality: requestedQuality);
    final seen = <String>{};
    final validUrls = resolution.urls
        .map((url) => url.trim())
        .where(_isRecordableUrl)
        .where((url) => seen.add(_streamIdentity(url)))
        .toList(growable: false);
    final appliedQuality = _appliedQuality(
      orderedQualities,
      requestedQuality,
      resolution.appliedQualityData,
    );
    final leaseMetadata = site is LivePlayLeaseMetadata ? site as LivePlayLeaseMetadata : null;
    return _ResolvedQuality(
      requestedQualityId: requestedQuality.selectionId.toString(),
      appliedQuality: appliedQuality,
      urls: validUrls,
      refreshTimes: validUrls
          .map((url) => leaseMetadata?.getPlayUrlRefreshAt(url)?.toUtc())
          .toList(growable: false),
      invalidTimes: validUrls
          .map((url) => leaseMetadata?.getPlayUrlInvalidAt(url)?.toUtc())
          .toList(growable: false),
      lineIndexes: lineIndex == null
          ? List<int>.generate(validUrls.length, (index) => index, growable: false)
          : List<int>.filled(validUrls.length, lineIndex, growable: false),
    );
  }

  /// Signed query parameters are refreshed on every platform resolve. Compare
  /// only scheme/host/path so a retry can still identify the failed CDN and
  /// move to the next line or quality instead of repeatedly selecting the same
  /// freshly-signed URL.
  static String _streamIdentity(String rawUrl) {
    final normalized = rawUrl.trim();
    final uri = Uri.tryParse(normalized);
    if (uri == null) return normalized;
    return normalized.split('#').first.split('?').first;
  }

  static bool _isRecordableUrl(String rawUrl) {
    final uri = Uri.tryParse(rawUrl.trim());
    return uri != null && uri.hasScheme && _recordableSchemes.contains(uri.scheme.toLowerCase());
  }
}

class _ResolvedQuality {
  const _ResolvedQuality({
    required this.requestedQualityId,
    required this.appliedQuality,
    required this.urls,
    required this.lineIndexes,
    required this.refreshTimes,
    required this.invalidTimes,
  });

  final String requestedQualityId;
  final LivePlayQuality appliedQuality;
  final List<String> urls;
  final List<int> lineIndexes;
  final List<DateTime?> refreshTimes;
  final List<DateTime?> invalidTimes;

  ResolvedRecordStream select(int position) {
    final normalizedPosition = position.clamp(0, urls.length - 1);
    return ResolvedRecordStream(
      url: urls[normalizedPosition],
      quality: appliedQuality,
      qualityCursorId: requestedQualityId,
      lineIndex: lineIndexes[normalizedPosition],
      candidateUrls: List<String>.unmodifiable([
        ...urls.skip(normalizedPosition),
        ...urls.take(normalizedPosition),
      ]),
      refreshAt: refreshTimes[normalizedPosition],
      invalidAt: invalidTimes[normalizedPosition],
    );
  }
}
