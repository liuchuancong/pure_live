import 'package:pure_live/common/index.dart';
import 'package:pure_live/core/interface/live_site.dart';
import 'package:pure_live/model/live_play_quality.dart';
import 'package:pure_live/player/utils/player_consts.dart';

enum StreamErrorType { roomNotFound, notLive, noQuality, cdnFailed, networkError, loginExpired, banned, unknown }

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
    required this.lineIndex,
    required this.candidateUrls,
  });

  final String url;
  final LivePlayQuality quality;
  final int lineIndex;
  final List<String> candidateUrls;

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
    String? previousUrl,
    int lineOffset = 0,
  }) async {
    final normalizedPlatform = platform.trim().toLowerCase();
    final normalizedRoomId = roomId.trim();
    if (normalizedRoomId.isEmpty) {
      throw const StreamException(type: StreamErrorType.roomNotFound, message: 'Room id is empty', retryable: false);
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
        throw StreamException(type: StreamErrorType.networkError, message: '${i18n('stream_get_room_failed')}: $error');
      }

      if (detail.liveStatus == LiveStatus.banned) {
        throw StreamException(type: StreamErrorType.banned, message: i18n('stream_room_banned'), retryable: false);
      }
      final explicitlyPlayable =
          detail.liveStatus == LiveStatus.live ||
          detail.liveStatus == LiveStatus.replay ||
          detail.status == true ||
          detail.isRecord == true;
      if (!explicitlyPlayable && detail.liveStatus == LiveStatus.offline) {
        throw StreamException(type: StreamErrorType.notLive, message: i18n('stream_not_live'), retryable: false);
      }
      if (!explicitlyPlayable) {
        throw StreamException(type: StreamErrorType.networkError, message: i18n('stream_room_state_unknown'));
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
        throw StreamException(type: StreamErrorType.noQuality, message: i18n('stream_no_available_quality'));
      }

      final orderedQualities = orderQualities(qualities, preferredQuality);
      Object? lastError;
      for (final requestedQuality in orderedQualities) {
        try {
          final resolution = await site.resolvePlayUrls(detail: detail, quality: requestedQuality);
          final validUrls = resolution.urls.where(_isRecordableUrl).toList(growable: false);
          if (validUrls.isEmpty) continue;

          final appliedQuality = _appliedQuality(orderedQualities, requestedQuality, resolution.appliedQualityData);
          final selectedIndex = _selectLineIndex(validUrls, previousUrl: previousUrl, lineOffset: lineOffset);
          final selectedUrl = validUrls[selectedIndex];
          final rotatedUrls = <String>[
            selectedUrl,
            for (var offset = 1; offset < validUrls.length; offset++)
              validUrls[(selectedIndex + offset) % validUrls.length],
          ];
          return ResolvedRecordStream(
            url: selectedUrl,
            quality: appliedQuality,
            lineIndex: selectedIndex,
            candidateUrls: List<String>.unmodifiable(rotatedUrls),
          );
        } catch (error) {
          lastError = error;
        }
      }

      throw StreamException(
        type: StreamErrorType.cdnFailed,
        message: lastError == null ? i18n('stream_all_cdn_failed') : '${i18n('stream_all_cdn_failed')}: $lastError',
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
  static List<LivePlayQuality> orderQualities(List<LivePlayQuality> source, String preferredQuality) {
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

  static String _normalizeQualityLabel(String value) => value.toLowerCase().replaceAll(RegExp(r'[\s_-]+'), '');

  static LivePlayQuality _appliedQuality(
    List<LivePlayQuality> qualities,
    LivePlayQuality requested,
    Object? appliedId,
  ) {
    if (appliedId == null) return requested;
    final normalized = appliedId.toString();
    return qualities.firstWhere((quality) => quality.selectionId.toString() == normalized, orElse: () => requested);
  }

  static int _selectLineIndex(List<String> urls, {String? previousUrl, required int lineOffset}) {
    if (urls.length == 1) return 0;
    final previousIndex = previousUrl == null ? -1 : urls.indexOf(previousUrl);
    if (previousIndex >= 0) return (previousIndex + 1) % urls.length;
    return lineOffset.abs() % urls.length;
  }

  static bool _isRecordableUrl(String rawUrl) {
    final uri = Uri.tryParse(rawUrl.trim());
    return uri != null && uri.hasScheme && _recordableSchemes.contains(uri.scheme.toLowerCase());
  }
}
