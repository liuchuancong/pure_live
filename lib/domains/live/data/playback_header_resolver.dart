import 'package:pure_live/shared/platforms/xiaohongshu/xiaohongshu_api.dart';
import 'package:pure_live/shared/platforms/bilibili/bilibili_site.dart';
import 'package:pure_live/shared/platforms/douyin/douyin_site.dart';
import 'package:pure_live/core/network/douyu_utils.dart';
import 'package:pure_live/shared/platforms/huya/huya_site.dart';
import 'package:pure_live/shared/platforms/twitch/twitch_site.dart';
import 'package:pure_live/shared/platforms/acfun/acfun_api.dart';
import 'package:pure_live/domains/live/data/platforms/sites.dart';
import 'package:pure_live/shared/platforms/picarto/picarto_api.dart';
import 'package:pure_live/shared/platforms/twitcasting/twitcasting_api.dart';
import 'package:pure_live/shared/platforms/missevan/missevan_api.dart';
import 'package:pure_live/shared/platforms/inke/inke_api.dart';
import 'package:pure_live/shared/platforms/kilakila/kilakila_api.dart';
import 'package:pure_live/shared/platforms/showroom/showroom_api.dart';
import 'package:pure_live/shared/platforms/chzzk/chzzk_api.dart';
import 'package:pure_live/shared/platforms/liveme/liveme_api.dart';
import 'package:pure_live/shared/platforms/tiktok/tiktok_api.dart';
import 'package:pure_live/shared/platforms/youtube/youtube_api.dart';
import 'package:pure_live/shared/platforms/bigo/bigo_api.dart';
import 'package:pure_live/shared/platforms/pandalive/pandalive_api.dart';
import 'package:pure_live/shared/platforms/seventeenlive/seventeenlive_api.dart';
import 'package:pure_live/core/network/http_header_policy.dart';
import 'package:pure_live/core/config/cookie_settings_controller.dart';
import 'package:pure_live/domains/iptv/data/iptv_settings_controller.dart';

/// Resolves the HTTP headers used to read a platform's media stream.
///
/// Playback, multiview, audio-only playback and recording share this policy.
/// Header values are produced only for the selected platform and normalized
/// before they are passed to native players or FFmpeg.
class PlaybackHeaderResolver {
  const PlaybackHeaderResolver._();

  static const String _desktopUserAgent =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) '
      'AppleWebKit/537.36 (KHTML, like Gecko) '
      'Chrome/140.0.0.0 Safari/537.36';

  static const String _kuaishouUserAgent =
      'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) '
      'AppleWebKit/537.36 (KHTML, like Gecko) '
      'Chrome/140.0.0.0 Safari/537.36';

  static Future<Map<String, String>> resolve({
    required String platform,
    String roomId = '',
    Map<String, String> roomHeaders = const <String, String>{},
  }) async {
    final normalizedPlatform = platform.trim().toLowerCase();
    final normalizedRoomId = Uri.encodeComponent(roomId.trim());
    Map<String, String> headers;

    switch (normalizedPlatform) {
      case Sites.bilibiliSite:
        final cookie = _configuredCookie((cookies) => cookies.bilibiliCookie.value);
        final anonymousCookie = <String>[
          if (BiliBiliSite.buvid3.isNotEmpty) 'buvid3=${BiliBiliSite.buvid3}',
          if (BiliBiliSite.buvid4.isNotEmpty) 'buvid4=${BiliBiliSite.buvid4}',
        ].join(';');
        headers = <String, String>{
          'user-agent': BiliBiliSite.kDefaultUserAgent,
          'origin': 'https://live.bilibili.com',
          'referer': normalizedRoomId.isEmpty
              ? BiliBiliSite.kDefaultReferer
              : 'https://live.bilibili.com/$normalizedRoomId',
          if (cookie.isNotEmpty) 'cookie': cookie else if (anonymousCookie.isNotEmpty) 'cookie': anonymousCookie,
        };
        break;
      case Sites.douyuSite:
        headers = DouyuUtils.playbackHeaders(roomId.trim());
        break;
      case Sites.huyaSite:
        // Huya's URL signer refreshes this process-wide value while resolving
        // the stream. Falling back here avoids a second network request solely
        // for headers and keeps deterministic callers offline-safe.
        final userAgent = HuyaSite.playUserAgent ?? HuyaSite.nativePlayUserAgent;
        final cookie = _configuredCookie((cookies) => cookies.huyaCookie.value);
        headers = <String, String>{
          'user-agent': userAgent,
          'origin': 'https://www.huya.com',
          'referer': normalizedRoomId.isEmpty ? 'https://www.huya.com/' : 'https://www.huya.com/$normalizedRoomId',
          if (cookie.isNotEmpty) 'cookie': cookie,
        };
        break;
      case Sites.douyinSite:
        final configuredCookie = _configuredCookie((cookies) => cookies.douyinCookie.value);
        final cookie = configuredCookie.isNotEmpty ? configuredCookie : DouyinSite.cookie.trim();
        headers = <String, String>{
          'user-agent': _desktopUserAgent,
          'origin': 'https://live.douyin.com',
          'referer': normalizedRoomId.isEmpty
              ? 'https://live.douyin.com/'
              : 'https://live.douyin.com/$normalizedRoomId',
          if (cookie.isNotEmpty) 'cookie': cookie,
        };
        break;
      case Sites.kuaishouSite:
        final cookie = _configuredCookie((cookies) => cookies.kuaishouCookie.value);
        headers = <String, String>{
          'user-agent': _kuaishouUserAgent,
          'origin': 'https://live.kuaishou.com',
          'referer': normalizedRoomId.isEmpty
              ? 'https://live.kuaishou.com/'
              : 'https://live.kuaishou.com/u/$normalizedRoomId',
          if (cookie.isNotEmpty) 'cookie': cookie,
        };
        break;
      case Sites.ccSite:
        headers = <String, String>{
          'user-agent': _desktopUserAgent,
          'origin': 'https://cc.163.com',
          'referer': normalizedRoomId.isEmpty ? 'https://cc.163.com/' : 'https://cc.163.com/$normalizedRoomId/',
        };
        break;
      case Sites.twitchSite:
        // 不把登录 Cookie 发给视频 CDN（上游 8-7）：媒体线路的授权在 usher 返回
        // 的签名里，CDN 不需要账号 Cookie，发过去等于把登录凭据交给第三方。
        headers = <String, String>{
          'user-agent': TwitchSite.defaultUa,
          'origin': TwitchSite.baseUrl,
          'referer': normalizedRoomId.isEmpty ? '${TwitchSite.baseUrl}/' : '${TwitchSite.baseUrl}/$normalizedRoomId',
        };
        break;
      case Sites.soopSite:
        final cookie = _configuredCookie((cookies) => cookies.soopCookie.value);
        headers = <String, String>{
          'user-agent': _desktopUserAgent,
          'origin': 'https://www.sooplive.co.kr',
          'referer': normalizedRoomId.isEmpty
              ? 'https://www.sooplive.co.kr/'
              : 'https://play.sooplive.co.kr/$normalizedRoomId',
          if (cookie.isNotEmpty) 'cookie': cookie,
        };
        break;
      case Sites.yySite:
        final cookie = _configuredCookie((cookies) => cookies.yyCookie.value);
        headers = <String, String>{
          'origin': 'https://www.yy.com',
          'referer': 'https://www.yy.com/',
          'user-agent': _desktopUserAgent,
          if (cookie.isNotEmpty) 'cookie': cookie,
        };
        break;
      case Sites.iptvSite:
        final userAgent = _configuredValue(() => IptvSettingsController.to.customIptvUserAgent.value);
        headers = <String, String>{
          if (userAgent.isNotEmpty) 'user-agent': userAgent,
          ...HttpHeaderPolicy.normalize(roomHeaders),
        };
        break;
      case Sites.picartoSite:
        headers = {...PicartoApi.playHeaders, 'User-Agent': _desktopUserAgent};
        break;
      case Sites.twitcastingSite:
        headers = TwitcastingApi.playHeaders;
        break;
      case Sites.missevanSite:
        headers = MissevanApi.playHeaders;
        break;
      case Sites.xiaohongshuSite:
        headers = XiaohongshuApi.headers;
        break;
      case Sites.kilakilaSite:
        headers = KilakilaApi.playHeaders;
        break;
      case Sites.inkeSite:
        headers = InkeApi.playHeaders;
        break;
      case Sites.acfunSite:
        headers = {...AcfunApi.playHeaders, 'origin': AcfunApi.origin};
        break;
      case Sites.showroomSite:
        headers = ShowroomApi.mediaHeaders;
        break;
      case Sites.chzzkSite:
        headers = ChzzkApi.mediaHeaders;
        break;
      case Sites.seventeenLiveSite:
        headers = SeventeenLiveApi.mediaHeaders(roomId);
        break;
      case Sites.liveMeSite:
        headers = LiveMeApi.mediaHeaders(roomId);
        break;
      case Sites.tiktokSite:
        headers = TikTokApi.mediaHeaders(roomId);
        break;
      case Sites.youtubeSite:
        headers = YouTubeApi.mediaHeaders(roomId);
        break;
      case Sites.bigoSite:
        headers = BigoApi.headers;
        break;
      case Sites.pandaLiveSite:
        headers = PandaLiveApi.mediaHeaders(roomId);
        break;
      default:
        headers = const <String, String>{};
    }

    return HttpHeaderPolicy.normalize(headers);
  }

  static String _configuredCookie(String Function(CookieSettingsController cookies) read) =>
      _configuredValue(() => read(CookieSettingsController.to));

  static String _configuredValue(String Function() read) {
    try {
      return read().trim();
    } catch (_) {
      return '';
    }
  }
}
