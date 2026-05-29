import 'package:pure_live/common/index.dart';
import 'package:pure_live/core/site/huya_site.dart';

class FFmpegHeaderFactory {
  static Future<Map<String, String>> build({required String platform}) async {
    final headers = <String, String>{};

    switch (platform.toLowerCase()) {
      case "bilibili":
        headers.addAll(_buildBilibiliHeaders());
        break;
      case "huya":
        headers.addAll(await _buildHuyaHeaders());
        break;
      default:
        break;
    }
    return headers;
  }

  static Map<String, String> _buildBilibiliHeaders() {
    return {
      "cookie": SettingsService.to.cookieManager.bilibiliCookie.v,
      "authority": "api.bilibili.com",
      "accept": "*",
      "accept-language": "zh-CN,zh;q=0.9",
      "cache-control": "no-cache",
      "dnt": "1",
      "pragma": "no-cache",
      // "sec-ch-ua": '"Not A(Brand";v="99", "Google Chrome";v="121", "Chromium";v="121"',
      // "sec-ch-ua-mobile": "?0",
      // "sec-ch-ua-platform": '"macOS"',
      // "sec-fetch-dest": "document",
      // "sec-fetch-mode": "navigate",
      // "sec-fetch-site": "none",
      // "sec-fetch-user": "?1",
      "upgrade-insecure-requests": "1",
      "user-agent":
          "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/121.0.0.0 Safari/537.36",
      "referer": "https://live.bilibili.com",
    };
  }

  static Future<Map<String, String>> _buildHuyaHeaders() async {
    final String kUserAgent =
        "Mozilla/5.0 (Windows NT 10.0; WOW64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/102.0.0.0 Safari/537.36";
    String ua;
    try {
      ua = await HuyaSite().getHuYaUA();
    } catch (e) {
      ua = kUserAgent;
    }

    return {"user-agent": ua, "origin": "https://www.huya.com"};
  }
}
