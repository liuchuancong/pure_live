import 'package:pure_live/common/services/settings_service.dart';
import 'package:pure_live/core/site/bilibili/bilibili_site.dart';
import 'package:pure_live/core/site/douyin/douyin_site.dart';
import 'package:pure_live/core/site/douyu/douyu_utils.dart';
import 'package:pure_live/core/site/huya/huya_site.dart';
import 'package:pure_live/core/site/twitch/twitch_site.dart';
import 'package:pure_live/core/sites.dart';

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

  static Future<Map<String, String>> resolve({required String platform, String roomId = ''}) async {
    final normalizedPlatform = platform.trim().toLowerCase();
    final normalizedRoomId = Uri.encodeComponent(roomId.trim());
    Map<String, String> headers;

    switch (normalizedPlatform) {
      case Sites.bilibiliSite:
        final cookie = _configuredCookie((settings) => settings.cookieManager.bilibiliCookie.value);
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
        final userAgent = HuyaSite.playUserAgent ?? HuyaSite.fallbackPlayUserAgent;
        final cookie = _configuredCookie((settings) => settings.cookieManager.huyaCookie.value);
        headers = <String, String>{
          'user-agent': userAgent,
          'origin': 'https://www.huya.com',
          'referer': normalizedRoomId.isEmpty ? 'https://www.huya.com/' : 'https://www.huya.com/$normalizedRoomId',
          if (cookie.isNotEmpty) 'cookie': cookie,
        };
        break;
      case Sites.douyinSite:
        final configuredCookie = _configuredCookie((settings) => settings.cookieManager.douyinCookie.value);
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
        final cookie = _configuredCookie((settings) => settings.cookieManager.kuaishouCookie.value);
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
        final cookie = _configuredCookie((settings) => settings.cookieManager.twitchCookie.value);
        headers = <String, String>{
          'user-agent': TwitchSite.defaultUa,
          'origin': TwitchSite.baseUrl,
          'referer': normalizedRoomId.isEmpty ? '${TwitchSite.baseUrl}/' : '${TwitchSite.baseUrl}/$normalizedRoomId',
          if (cookie.isNotEmpty) 'cookie': cookie,
        };
        break;
      case Sites.soopSite:
        final cookie = _configuredCookie((settings) => settings.cookieManager.soopCookie.value);
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
        final cookie = _configuredCookie((settings) => settings.cookieManager.yyCookie.value);
        headers = <String, String>{
          'origin': 'https://www.yy.com',
          'referer': 'https://www.yy.com/',
          'user-agent': _desktopUserAgent,
          if (cookie.isNotEmpty) 'cookie': cookie,
        };
        break;
      case Sites.iptvSite:
        final userAgent = _configuredValue((settings) => settings.iptv.customIptvUserAgent.value);
        headers = userAgent.isEmpty ? const <String, String>{} : <String, String>{'user-agent': userAgent};
        break;
      default:
        headers = const <String, String>{};
    }

    return _sanitize(headers);
  }

  static String _configuredCookie(String Function(SettingsService settings) read) => _configuredValue(read);

  static String _configuredValue(String Function(SettingsService settings) read) {
    try {
      return read(SettingsService.to).trim();
    } catch (_) {
      return '';
    }
  }

  static Map<String, String> _sanitize(Map<String, String> source) {
    final result = <String, String>{};
    final validName = RegExp(r'^[A-Za-z0-9-]+$');
    for (final entry in source.entries) {
      final name = entry.key.trim().toLowerCase();
      final value = entry.value.replaceAll(RegExp(r'[\r\n\u0000]+'), ' ').trim();
      if (name.isNotEmpty && value.isNotEmpty && validName.hasMatch(name)) {
        result[name] = value;
      }
    }
    return Map<String, String>.unmodifiable(result);
  }
}
