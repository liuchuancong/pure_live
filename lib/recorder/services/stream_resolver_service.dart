import 'package:get/get.dart';
import 'package:pure_live/core/sites.dart';
import 'package:pure_live/common/models/live_room.dart';
import 'package:pure_live/model/live_play_quality.dart';
import 'package:pure_live/player/utils/player_consts.dart';

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
  Future<String> resolveStream({
    required String roomId,
    required String platform,
    required String preferredQuality,
  }) async {
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
      List<String> systemResolutions = PlayerConsts.resolutions;
      int preferIndex = systemResolutions.indexOf(preferredQuality);
      if (preferIndex == -1) preferIndex = 0;
      double targetRatio = preferIndex / (systemResolutions.length - 1).clamp(1, 999);
      final Map<LivePlayQuality, int> originalIndexMap = {for (int i = 0; i < qualities.length; i++) qualities[i]: i};
      qualities.sort((a, b) {
        int indexA = originalIndexMap[a]!;
        int indexB = originalIndexMap[b]!;
        double ratioA = indexA / (qualities.length - 1).clamp(1, 999);
        double ratioB = indexB / (qualities.length - 1).clamp(1, 999);
        return (ratioA - targetRatio).abs().compareTo((ratioB - targetRatio).abs());
      });

      /// 尝试所有线路
      for (final q in qualities) {
        try {
          final urls = await Sites.of(platform).liveSite.getPlayUrls(detail: detail, quality: q);

          if (urls.isNotEmpty) {
            final url = urls.first;
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
}
