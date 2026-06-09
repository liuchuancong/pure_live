import 'package:dio/dio.dart';
import 'package:pure_live/core/common/log.dart';

class CustomLogInterceptor extends Interceptor {
  static const String _keyTimestamp = "ts";

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    options.extra[_keyTimestamp] = DateTime.now().millisecondsSinceEpoch;
    super.onRequest(options, handler);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    var time = DateTime.now().millisecondsSinceEpoch - err.requestOptions.extra[_keyTimestamp];

    Log.e('''[HTTP Error] [${err.type}] [Time:${time}ms]
${err.message}
Request Method：${err.requestOptions.method}
Response Code：${err.response?.statusCode}
Request URL：${err.requestOptions.uri}
Request Query：${err.requestOptions.queryParameters}
Request Data：${err.requestOptions.data}
Request Headers：${_maskHeader(err.requestOptions.headers)}
Response Headers：${err.response?.headers.map}
Response Data：${err.response?.data}''', err.stackTrace);

    super.onError(err, handler);
  }

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
