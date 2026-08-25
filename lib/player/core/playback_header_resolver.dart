import 'package:pure_live/common/services/settings_service.dart';
import 'package:pure_live/core/site/bilibili/bilibili_site.dart';
import 'package:pure_live/core/site/douyu/douyu_utils.dart';
import 'package:pure_live/core/site/huya/huya_site.dart';
import 'package:pure_live/core/sites.dart';

/// Resolves the HTTP headers used to read a platform's media stream.
///
/// Playback, multiview, audio-only playback and recording must share this
/// policy. Keeping a second recorder-specific switch caused Douyu recording
/// to omit its anti-hotlink Referer/Cookie even though the same stream played
/// correctly in the player.
class PlaybackHeaderResolver {
  const PlaybackHeaderResolver._();

  static Future<Map<String, String>> resolve({required String platform, String roomId = ''}) async {
    final normalizedPlatform = platform.trim().toLowerCase();

    if (normalizedPlatform == Sites.bilibiliSite) {
      final cookie = SettingsService.to.cookieManager.bilibiliCookie.value.trim();
      return <String, String>{
        'user-agent': BiliBiliSite.kDefaultUserAgent,
        'origin': 'https://live.bilibili.com',
        'referer': 'https://live.bilibili.com/$roomId',
        if (cookie.isNotEmpty) 'cookie': cookie,
      };
    }

    if (normalizedPlatform == Sites.douyuSite) {
      return DouyuUtils.playbackHeaders(roomId);
    }

    if (normalizedPlatform == Sites.huyaSite) {
      String userAgent;
      try {
        userAgent = await HuyaSite().getHuYaUA();
      } catch (_) {
        userAgent =
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) '
            'AppleWebKit/537.36 (KHTML, like Gecko) '
            'Chrome/128.0.0.0 Safari/537.36';
      }
      return <String, String>{'user-agent': userAgent, 'origin': 'https://www.huya.com'};
    }

    if (normalizedPlatform == Sites.yySite) {
      return const <String, String>{
        'origin': 'https://www.yy.com',
        'referer': 'https://www.yy.com/',
        'user-agent':
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) '
            'AppleWebKit/537.36 (KHTML, like Gecko) '
            'Chrome/128.0.0.0 Safari/537.36',
      };
    }

    if (normalizedPlatform == Sites.iptvSite) {
      final userAgent = SettingsService.to.iptv.customIptvUserAgent.value.trim();
      return userAgent.isEmpty ? const <String, String>{} : <String, String>{'user-agent': userAgent};
    }

    return const <String, String>{};
  }
}
