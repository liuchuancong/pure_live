import 'dart:convert';
import 'dart:math';

import 'package:pure_live/core/logging/core_log.dart';
import 'package:pure_live/core/network/http_client.dart';

import 'abogus.dart';
import 'douyin_request_params.dart';

class DouyinUtils {
  static String getMSToken({int randomLength = 184}) {
    if (randomLength < 0) throw ArgumentError.value(randomLength, 'randomLength');
    const baseStr = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789=';
    final random = Random.secure();
    final sb = StringBuffer();
    for (var i = 0; i < randomLength; i++) {
      sb.write(baseStr[random.nextInt(baseStr.length)]);
    }
    return sb.toString();
  }

  static String buildRequestUrl(String baseUrl, Map<String, dynamic> params) {
    final abogus = ABogus(userAgent: DouyinRequestParams.kDefaultUserAgent);
    final parsedUrl = Uri.parse(baseUrl);
    final exParams = <String, dynamic>{...parsedUrl.queryParameters, ...params};
    exParams['aid'] = DouyinRequestParams.aidValue;
    exParams['compress'] = 'gzip';
    exParams['device_platform'] = 'web';
    exParams['browser_language'] = 'zh-CN';
    exParams['browser_platform'] = 'Win32';
    exParams['browser_name'] = 'Edge';
    exParams['browser_version'] = '125.0.0.0';
    if (!exParams.containsKey('msToken')) {
      exParams['msToken'] = getMSToken();
    }
    final newQueryStr = Uri(queryParameters: exParams).query;
    final signedQueryStr = abogus.generateAbogus(newQueryStr).first;
    final newUrl = parsedUrl.replace(query: signedQueryStr);
    return newUrl.toString();
  }

  Future<Map<String, String>> getTtwidWebid({required String reqUrl}) async {
    final headers = <String, String>{
      "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/125.0.0.0 Safari/537.36 Edg/125.0.0.0",
      "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8,application/signed-exchange;v=b3;q=0.7",
      "Accept-Language": "zh-CN,zh;q=0.9,en;q=0.8",
    };

    String? ttwid;
    String? webid;

    try {
      final headResp = await HttpClient.instance.head(reqUrl, header: headers);
      final setCookies = headResp.headers["set-cookie"];
      if (setCookies != null) {
        for (final cookieLine in setCookies) {
          final cookie = cookieLine.split(";").first;
          if (cookie.startsWith("ttwid=")) {
            ttwid = cookie.substring("ttwid=".length);
            break;
          }
        }
      }

      final html = await HttpClient.instance.getText(reqUrl, header: headers);

      final renderMatches = RegExp(
        r'<script id=\"RENDER_DATA\" type=\"application\/json\">(.*?)<\/script>',
        dotAll: true,
      ).allMatches(html);
      if (renderMatches.isNotEmpty) {
        var renderDataText = renderMatches.first.group(1) ?? "";
        try {
          renderDataText = Uri.decodeComponent(renderDataText);
        } catch (_) {}
        try {
          final data = jsonDecode(renderDataText) as Map<String, dynamic>;
          final app = data['app'] as Map<String, dynamic>?;
          final odin = app?['odin'] as Map<String, dynamic>?;
          final uid = odin?['user_unique_id'];
          if (uid != null) {
            webid = uid.toString();
          }
        } catch (e) {
          CoreLog.error('解析 RENDER_DATA 失败: $e');
        }
      }
    } catch (e) {
      CoreLog.error('get_ttwid_webid 错误: $e');
    }

    return {'ttwid': ttwid ?? '', 'webid': webid ?? ''};
  }
}
