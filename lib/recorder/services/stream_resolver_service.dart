import 'package:get/get.dart';
import 'package:pure_live/core/sites.dart';
import 'package:pure_live/common/models/live_room.dart';
import 'package:pure_live/model/live_play_quality.dart';
import 'package:pure_live/recorder/consts/resolution_mapper.dart';

enum StreamErrorType { roomNotFound, notLive, noQuality, cdnFailed, networkError, loginExpired, banned, unknown }

class StreamException implements Exception {
  final StreamErrorType type;

  final String message;

  /// 是否允许自动重试
  final bool retryable;

  const StreamException({required this.type, required this.message, this.retryable = true});

  @override
  String toString() {
    return 'StreamException(type: $type, message: $message, retryable: $retryable)';
  }
}

class StreamResolverService extends GetxService {
  static StreamResolverService get to => Get.find();

  final Map<String, String> _cache = {};

  Future<String> resolveStream({
    required String roomId,
    required String platform,
    required String preferredQuality,
  }) async {
    final key = "$platform-$roomId";

    /// 缓存
    if (_cache.containsKey(key)) {
      return _cache[key]!;
    }

    try {
      final detail = await Sites.of(platform).liveSite.getRoomDetail(roomId: roomId, platform: platform);

      /// 未开播
      if (detail.liveStatus != LiveStatus.live) {
        throw const StreamException(type: StreamErrorType.notLive, message: "主播未开播", retryable: false);
      }

      List<LivePlayQuality> qualities = [];

      try {
        qualities = await Sites.of(platform).liveSite.getPlayQualites(detail: detail);
      } catch (e) {
        throw const StreamException(type: StreamErrorType.noQuality, message: "获取清晰度失败", retryable: false);
      }

      /// 无清晰度
      if (qualities.isEmpty) {
        throw const StreamException(type: StreamErrorType.noQuality, message: "无可用清晰度", retryable: false);
      }

      /// 根据用户目标清晰度排序
      final targetLevel = ResolutionMapper.getLevel(preferredQuality);

      qualities.sort((a, b) {
        final la = ResolutionMapper.getLevel(a.quality);

        final lb = ResolutionMapper.getLevel(b.quality);

        return (lb - targetLevel).abs().compareTo((la - targetLevel).abs());
      });

      /// 尝试所有线路
      for (final q in qualities) {
        try {
          final urls = await Sites.of(platform).liveSite.getPlayUrls(detail: detail, quality: q);

          if (urls.isNotEmpty) {
            final url = urls.first;

            _cache[key] = url;

            return url;
          }
        } catch (_) {
          continue;
        }
      }

      /// 所有线路失败
      throw const StreamException(type: StreamErrorType.cdnFailed, message: "所有清晰度线路失败", retryable: true);
    }
    /// 已知业务异常
    on StreamException {
      rethrow;
    }
    /// 未知异常
    catch (e) {
      throw StreamException(type: StreamErrorType.unknown, message: e.toString(), retryable: true);
    }
  }

  void invalidate(String roomId) {
    _cache.removeWhere((k, v) => k.contains(roomId));
  }
}
