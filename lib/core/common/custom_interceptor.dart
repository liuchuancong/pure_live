import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:pure_live/core/common/log.dart';
import 'package:pure_live/core/common/core_log.dart';

class CustomLogInterceptor extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    options.extra["ts"] = DateTime.now().millisecondsSinceEpoch;
    super.onRequest(options, handler);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    var time = DateTime.now().millisecondsSinceEpoch - err.requestOptions.extra["ts"];
    if (!kReleaseMode) {
      Log.e('''【HTTP请求错误-${err.type}】 耗时:${time}ms
${err.message}

Request Method：${err.requestOptions.method}
Response Code：${err.response?.statusCode}
Request URL：${err.requestOptions.uri}
Request Query：${err.requestOptions.queryParameters}
Request Data：${err.requestOptions.data}
Request Headers：${err.requestOptions.headers}
Response Headers：${err.response?.headers.map}
Response Data：${err.response?.data}''', err.stackTrace);
    } else {
      CoreLog.e('''[HTTP Error] [${err.type}] [Time:${time}ms]
${err.message}

Request Method：${err.requestOptions.method}
Response Code：${err.response?.statusCode}
Request URL：${err.requestOptions.uri}
Request Query：${err.requestOptions.queryParameters}
Request Data：${err.requestOptions.data}
Request Headers：${_maskHeader(err.requestOptions.headers)}
Response Headers：${err.response?.headers.map}
Response Data：${err.response?.data}''', err.stackTrace);
    }

    super.onError(err, handler);
  }

  // Header脱敏
  String _maskHeader(Map<String, dynamic> header) {
    var result = <String, dynamic>{};
    header.forEach((key, value) {
      var k = key.toLowerCase();
      if (k == "cookie" || k == "authorization") {
        result[key] = "******";
      } else {
        result[key] = value;
      }
    });
    return result.toString();
  }
}
