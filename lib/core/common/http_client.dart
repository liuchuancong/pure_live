import 'dart:io';

import 'package:async_locks/async_locks.dart';
import 'package:dio/dio.dart';
import 'package:dio_cache_interceptor/dio_cache_interceptor.dart';
import 'package:dio_cache_interceptor_db_store/dio_cache_interceptor_db_store.dart';
import 'package:dio_compatibility_layer/dio_compatibility_layer.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pure_live/core/common/core_error.dart';
import 'package:pure_live/core/common/core_log.dart';
import 'package:rhttp/rhttp.dart' as rhttp;

import '../../plugins/dns4flutter/dns_helper.dart';
import 'custom_dio_cache_interceptor.dart';
import 'custom_interceptor.dart';
import 'custom_io_http_client_adapter.dart';

class HttpClient {
  static HttpClient? _httpUtil;

  static HttpClient get instance {
    _httpUtil ??= HttpClient();
    return _httpUtil!;
  }

  ///  重置 HttpClient
  static Future<HttpClient> resetHttpClient() async {
    await initHttpExt();
    _httpUtil = HttpClient();
    return _httpUtil!;
  }

  static CacheStore? getCacheStore() {
    getTemporaryDirectory().then((dir) {
      return DbCacheStore(databasePath: dir.path, logStatements: true);
    });
    sleep(const Duration(seconds: 1));
    return null;
  }

  static CacheOptions cacheOptions = CacheOptions(
    // A default store is required for interceptor.
    store: MemCacheStore(),

    // All subsequent fields are optional.

    // Default.
    policy: CachePolicy.request,
    // Returns a cached response on error but for statuses 401 & 403.
    // Also allows to return a cached response on network errors (e.g. offline usage).
    // Defaults to [null].
    hitCacheOnErrorExcept: const [401, 403],
    // Overrides any HTTP directive to delete entry past this duration.
    // Useful only when origin server has no cache config or custom behaviour is desired.
    // Defaults to [null].
    maxStale: const Duration(minutes: 2),
    // Default. Allows 3 cache sets and ease cleanup.
    priority: CachePriority.normal,
    // Default. Body and headers encryption with your own algorithm.
    cipher: null,
    // Default. Key builder to retrieve requests.
    keyBuilder: CacheOptions.defaultCacheKeyBuilder,
    // Default. Allows to cache POST requests.
    // Overriding [keyBuilder] is strongly recommended when [true].
    allowPostMethod: true,
  );

  late Dio dio;
  static late rhttp.RhttpCompatibleClient compatibleClient;

  static Future<void> initHttp() async {
    await rhttp.Rhttp.init();
    await initHttpExt();
  }

  static Future<void> initHttpExt() async {
    compatibleClient = await rhttp.RhttpCompatibleClient.create(
        settings: rhttp.ClientSettings(
      dnsSettings: rhttp.DnsSettings.dynamic(resolver: (String host) async {
        return await DnsHelper.lookupARecords(host);
      }),
      redirectSettings: rhttp.RedirectSettings.limited(20),
      tlsSettings: rhttp.TlsSettings(
        verifyCertificates: false,
      ),
    ));
  }

  HttpClient() {
    dio = Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 20),
        sendTimeout: const Duration(seconds: 20),
      ),
    );
    dio.interceptors.add(CustomInterceptor());
    dio.interceptors.add(CustomDioCacheInterceptor(options: cacheOptions));
    dio.httpClientAdapter = CustomIOHttpClientAdapter.instance;
    dio.httpClientAdapter = ConversionLayerAdapter(compatibleClient);

    HttpOverrides.global = GlobalHttpOverrides();
  }

  /// 用于存放 取消任务操作
  static Map<int, CancelToken> cancelTokenMap = {};
  static final cancelTokenLock = Lock();

  // 最大排队请求队列
  static const maxCancelTokenLen = 20;

  static int getCancelTokenKey() {
    return DateTime.now().microsecondsSinceEpoch;
  }

  /// 尝试取消请求
  static Future<void> tryToCancelRequest() async {
    if (cancelTokenMap.length <= maxCancelTokenLen) {
      return;
    }

    await cancelTokenLock.run(() async {
      if (cancelTokenMap.length <= maxCancelTokenLen) {
        return;
      }
      await releaseCancelTokenMap();
    });
  }

  /// 释放 请求
  static Future<void> releaseCancelTokenMap() async {
    await Future.delayed(const Duration(seconds: 3)).then((value) {
      if (cancelTokenMap.length <= maxCancelTokenLen) {
        return;
      }
      CoreLog.d("release Request: ${cancelTokenMap.length}");
      for (var value in cancelTokenMap.values) {
        value.cancel();
      }
      cancelTokenMap.clear();
    });
  }

  /// Get请求，返回String
  /// * [url] 请求链接
  /// * [queryParameters] 请求参数
  /// * [cancel] 任务取消Token
  Future<String> getText(
    String url, {
    Map<String, dynamic>? queryParameters,
    Map<String, dynamic>? header,
    CancelToken? cancel,
  }) async {
    await tryToCancelRequest();
    var cancelToken = cancel ?? CancelToken();
    var cancelTokenKey = getCancelTokenKey();
    cancelTokenMap[cancelTokenKey] = cancelToken;
    try {
      queryParameters ??= {};
      header ??= {};
      var result = await dio.get(
        url,
        queryParameters: queryParameters,
        options: Options(
          responseType: ResponseType.plain,
          headers: header,
        ),
        cancelToken: cancelToken,
      );
      cancelTokenMap.remove(cancelTokenKey);
      return result.data;
    } catch (e) {
      await handleDioException(e);
      throw CoreError("发送Http请求失败!\n$e");
    } finally {
      cancelTokenMap.remove(cancelTokenKey);
    }
  }

  /// Get请求，返回Map
  /// * [url] 请求链接
  /// * [queryParameters] 请求参数
  /// * [cancel] 任务取消Token
  Future<dynamic> getJson(
    String url, {
    Map<String, dynamic>? queryParameters,
    Map<String, dynamic>? header,
    CancelToken? cancel,
  }) async {
    await tryToCancelRequest();
    var cancelToken = cancel ?? CancelToken();
    var cancelTokenKey = getCancelTokenKey();
    cancelTokenMap[cancelTokenKey] = cancelToken;
    try {
      queryParameters ??= {};
      header ??= {};
      var result = await dio.get(
        url,
        queryParameters: queryParameters,
        options: Options(
          responseType: ResponseType.json,
          headers: header,
        ),
        cancelToken: cancelToken,
      );
      return result.data;
    } catch (e) {
      await handleDioException(e);
      throw CoreError("发送Http请求失败!\n$e");

    } finally {
      cancelTokenMap.remove(cancelTokenKey);
    }
  }

  /// Post请求，返回Map
  /// * [url] 请求链接
  /// * [queryParameters] 请求参数
  /// * [data] 内容
  /// * [cancel] 任务取消Token
  Future<dynamic> postJson(
    String url, {
    Map<String, dynamic>? queryParameters,
    dynamic data,
    Map<String, dynamic>? header,
    bool formUrlEncoded = false,
    CancelToken? cancel,
  }) async {
    await tryToCancelRequest();
    var cancelToken = cancel ?? CancelToken();
    var cancelTokenKey = getCancelTokenKey();
    cancelTokenMap[cancelTokenKey] = cancelToken;
    try {
      queryParameters ??= {};
      header ??= {};
      data ??= {};
      var result = await dio.post(
        url,
        queryParameters: queryParameters,
        data: data,
        options: Options(
          responseType: ResponseType.json,
          headers: header,
          contentType: formUrlEncoded ? Headers.formUrlEncodedContentType : null,
        ),
        cancelToken: cancelToken,
      );
      return result.data;
    } catch (e) {
      await handleDioException(e);
      throw CoreError("发送Http请求失败!\n$e");
    } finally {
      cancelTokenMap.remove(cancelTokenKey);
    }
  }

  /// Head请求，返回Response
  /// * [url] 请求链接
  /// * [queryParameters] 请求参数
  /// * [cancel] 任务取消Token
  Future<Response> head(
    String url, {
    Map<String, dynamic>? queryParameters,
    Map<String, dynamic>? header,
    CancelToken? cancel,
  }) async {
    await tryToCancelRequest();
    var cancelToken = cancel ?? CancelToken();
    var cancelTokenKey = getCancelTokenKey();
    cancelTokenMap[cancelTokenKey] = cancelToken;
    try {
      queryParameters ??= {};
      header ??= {};
      var result = await dio.head(
        url,
        queryParameters: queryParameters,
        options: Options(
          headers: header,
          receiveDataWhenStatusError: true,
        ),
        cancelToken: cancelToken,
      );
      return result;
    } catch (e) {
      await handleDioException(e);
      throw CoreError("发送Http请求失败!\n$e");
    } finally {
      cancelTokenMap.remove(cancelTokenKey);
    }
  }

  /// Get请求，返回Response
  /// * [url] 请求链接
  /// * [queryParameters] 请求参数
  /// * [cancel] 任务取消Token
  Future<Response<dynamic>> get(
    String url, {
    Map<String, dynamic>? queryParameters,
    Map<String, dynamic>? header,
    CancelToken? cancel,
  }) async {
    await tryToCancelRequest();
    var cancelToken = cancel ?? CancelToken();
    var cancelTokenKey = getCancelTokenKey();
    cancelTokenMap[cancelTokenKey] = cancelToken;
    try {
      queryParameters ??= {};
      header ??= {};
      var result = await dio.get(
        url,
        queryParameters: queryParameters,
        options: Options(
          responseType: ResponseType.json,
          headers: header,
        ),
        cancelToken: cancelToken,
      );
      return result;
    } catch (e) {
      await handleDioException(e);
      throw CoreError("发送Http请求失败!\n$e");
    } finally {
      cancelTokenMap.remove(cancelTokenKey);
    }
  }

  Future<void> handleDioException(dynamic e) async {
    CoreLog.error(e);
    if (e is DioException) {
      var string = e.toString();
      if(string.contains("Network unreachable")) {
        CoreLog.w("resetHttpClient ....");
        await resetHttpClient();
      }
      if(e.type == DioExceptionType.badResponse) {
        throw CoreError(e.message ?? "", statusCode: e.response?.statusCode ?? 0);
      }
    }
  }
}
