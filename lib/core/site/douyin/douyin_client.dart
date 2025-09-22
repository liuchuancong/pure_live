import 'dart:math';
import 'dart:developer' as developer;
import 'package:http/http.dart' as http;
import 'package:flutter_js/flutter_js.dart';
import 'package:pure_live/common/utils/js_engine.dart';

final String host = 'https://www.douyin.com';

Map<String, String> commonParams = {
  'device_platform': 'webapp',
  'aid': '6383',
  'channel': 'channel_pc_web',
  'update_version_code': '170400',
  'pc_client_type': '1', // Windows
  'version_code': '190500',
  'version_name': '19.5.0',
  'cookie_enabled': 'true',
  'screen_width': '2560',
  'screen_height': '1440',
  'browser_language': 'zh-CN',
  'browser_platform': 'Win32',
  'browser_name': 'Chrome',
  'browser_version': '126.0.0.0',
  'browser_online': 'true',
  'engine_name': 'Blink',
  'engine_version': '126.0.0.0',
  'os_name': 'Windows',
  'os_version': '10',
  'cpu_core_num': '24',
  'device_memory': '8',
  'platform': 'PC',
  'downlink': '10',
  'effective_type': '4g',
  'round_trip_time': '50',
};

Map<String, String> commonHeaders = {
  "User-Agent":
  "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36",
  "sec-fetch-site": "same-origin",
  "sec-fetch-mode": "cors",
  "sec-fetch-dest": "empty",
  "sec-ch-ua-platform": "Windows",
  "sec-ch-ua-mobile": "?0",
  "sec-ch-ua": '"Not/A)Brand";v="8", "Chromium";v="126", "Google Chrome";v="126"',
  "referer": "https://www.douyin.com/?recommend=1",
  "priority": "u=1, i",
  "pragma": "no-cache",
  "cache-control": "no-cache",
  "accept-language": "zh-CN,zh;q=0.9,en;q=0.8",
  "accept": "application/json, text/plain, */*",
  "dnt": "1",
};

class DouyinClient {
  final JavascriptRuntime _jsRuntime;
  bool _isJsLoaded = false;

  // 构造函数，初始化JS运行时
  DouyinClient() : _jsRuntime = getJavascriptRuntime() {
    _initJsRuntime();
  }
  // 初始化JS运行时并加载签名脚本
  Future<void> _initJsRuntime() async {
    if (_isJsLoaded) return;

    try {
      JsEngine.init();
      await JsEngine.loadDouyinExEcutorSdk();

      _isJsLoaded = true;
    } catch (e) {
      developer.log("初始化JS运行时失败: $e");
      rethrow;
    }
  }

  Future<String?> getWebid(Map<String, dynamic> headers) async {
    final url = Uri.parse('$host/?recommend=1');

    var requestHeaders = Map<String, String>.from(headers);
    requestHeaders['sec-fetch-dest'] = 'document';

    try {
      final response = await http.get(url, headers: requestHeaders);

      if (response.statusCode != 200 || response.body.isEmpty) {
        developer.log('获取webid失败，状态码: ${response.statusCode}');
        return null;
      }

      final pattern = RegExp(r'\\\"user_unique_id\\\":\\\"(\d+)\\\"');
      final match = pattern.firstMatch(response.body);

      return match?.group(1);
    } catch (e) {
      developer.log('getWebid错误: $e');
      return null;
    }
  }

  Map<String, String> cookiesToDict(String cookieString) {
    final cookies = <String, String>{};
    if (cookieString.isEmpty) return cookies;

    final parts = cookieString.split('; ');
    for (final part in parts) {
      if (part.isEmpty || part == 'douyin.com') continue;

      final separatorIndex = part.indexOf('=');
      if (separatorIndex == -1) {
        cookies[part] = '';
        continue;
      }

      final key = part.substring(0, separatorIndex);
      final value = part.substring(separatorIndex + 1);
      cookies[key] = value;
    }

    return cookies;
  }

  // 修改为返回Map<String, String>以解决类型错误
  Future<Map<String, String>> dealParams(Map<String, String> params, Map<String, dynamic> headers) async {
    final cookie = headers['cookie'] ?? headers['Cookie'] ?? '';
    if (cookie.isEmpty) return params;

    final cookieDict = cookiesToDict(cookie);
    final newParams = Map<String, String>.from(params);

    newParams['msToken'] = getMsToken();
    newParams['screen_width'] = cookieDict['dy_swidth'] ?? '2560';
    newParams['screen_height'] = cookieDict['dy_sheight'] ?? '1440';
    newParams['cpu_core_num'] = cookieDict['device_web_cpu_core'] ?? '24';
    newParams['device_memory'] = cookieDict['device_web_memory_size'] ?? '8';
    newParams['verifyFp'] = cookieDict['s_v_web_id'] ?? '';
    newParams['fp'] = cookieDict['s_v_web_id'] ?? '';

    final webId = await getWebid(headers);
    if (webId != null) {
      newParams['webid'] = webId;
    }

    return newParams;
  }

  String getMsToken({int randomLength = 120}) {
    final random = Random.secure();
    const baseStr = 'ABCDEFGHIGKLMNOPQRSTUVWXYZabcdefghigklmnopqrstuvwxyz0123456789=';
    final length = baseStr.length;

    final buffer = StringBuffer();
    for (var i = 0; i < randomLength; i++) {
      buffer.write(baseStr[random.nextInt(length)]);
    }

    return buffer.toString();
  }

  Future<Map<String, dynamic>> commonRequest(Map<String, String> params, Map<String, dynamic> headers) async {
    // 确保JS已加载
    if (!_isJsLoaded) {
      await _initJsRuntime();
    }
    // 合并参数和请求头，确保类型正确
    final newParams = Map<String, String>.from(commonParams)..addAll(params);
    final newHeaders = Map<String, dynamic>.from(commonHeaders)..addAll(headers);

    final processedParams = await dealParams(newParams, newHeaders);

    // 构建查询字符串
    final queryString = Uri(queryParameters: processedParams).query;
    final callName = 'sign_datail';
    JsEvalResult jsEvalResult = await JsEngine.evaluateAsync(
      '$callName("$queryString", "${newHeaders['User-Agent']}")',
    );
    final aBogus = jsEvalResult.stringResult;
    processedParams['a_bogus'] = aBogus;
    return {'headers': newHeaders, 'params': processedParams};
  }

  // 释放资源
  void dispose() {
    _jsRuntime.dispose();
  }
}