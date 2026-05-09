import 'package:get/get.dart';
import 'package:pure_live/core/sites.dart';
import 'package:pure_live/recorder/consts/resolution_mapper.dart';

class StreamResolverService extends GetxService {
  static StreamResolverService get to => Get.find();

  final Map<String, String> _cache = {};

  Future<String> resolveStream({
    required String roomId,
    required String platform,
    required String preferredQuality,
  }) async {
    final key = "$platform-$roomId";

    if (_cache.containsKey(key)) {
      return _cache[key]!;
    }

    final detail = await Sites.of(platform).liveSite.getRoomDetail(roomId: roomId, platform: platform);
    final qualities = await Sites.of(platform).liveSite.getPlayQualites(detail: detail);
    if (qualities.isEmpty) {
      throw Exception("无清晰度");
    }
    int targetLevel = ResolutionMapper.getLevel(preferredQuality);
    qualities.sort((a, b) {
      int la = ResolutionMapper.getLevel(a.quality);
      int lb = ResolutionMapper.getLevel(b.quality);
      return (lb - targetLevel).abs().compareTo((la - targetLevel).abs());
    });
    for (final q in qualities) {
      try {
        final urls = await Sites.of(platform).liveSite.getPlayUrls(detail: detail, quality: q);

        if (urls.isNotEmpty) {
          _cache[key] = urls.first;
          return urls.first;
        }
      } catch (_) {
        continue;
      }
    }

    throw Exception("所有清晰度线路失败");
  }

  void invalidate(String roomId) {
    _cache.removeWhere((k, v) => k.contains(roomId));
  }
}
