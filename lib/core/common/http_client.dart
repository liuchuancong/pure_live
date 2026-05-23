import 'dart:io' as io;
import 'dart:developer';
import 'package:dio/io.dart';
import 'package:dio/dio.dart';
import 'custom_interceptor.dart';
import 'package:pure_live/common/index.dart';
import 'package:pure_live/core/common/core_error.dart';

class HttpClient {
  static HttpClient? _httpUtil;

  static HttpClient get instance {
    _httpUtil ??= HttpClient();
    return _httpUtil!;
  }

  late Dio dio;
  HttpClient() {
    dio = Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 20),
        receiveTimeout: const Duration(seconds: 20),
        sendTimeout: const Duration(seconds: 20),
      ),
    );
    dio.httpClientAdapter = IOHttpClientAdapter(
      createHttpClient: () {
        final client = io.HttpClient();
        client.badCertificateCallback = (io.X509Certificate cert, String host, int port) {
          return true;
        };
        return client;
      },
    );
    dio.interceptors.add(CustomInterceptor());
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
    try {
      queryParameters ??= {};
      header ??= {};
      var result = await dio.get(
        url,
        queryParameters: queryParameters,
        options: Options(responseType: ResponseType.plain, headers: header),
        cancelToken: cancel,
      );
      return result.data;
    } catch (e) {
      log(e.toString());
      if (e is DioException && e.type == DioExceptionType.badResponse) {
        throw CoreError(e.message ?? "", statusCode: e.response?.statusCode ?? 0);
      } else {
        throw CoreError("发送GET请求失败");
      }
    }
  }

  /// 下载文件请求（与 getText 保持一致的异常处理结构）
  /// * [url] 请求链接
  /// * [savePath] 本地保存路径
  /// * [queryParameters] 请求参数
  /// * [cancel] 任务取消Token
  Future<Response<dynamic>> download(
    String url,
    String savePath, {
    Map<String, dynamic>? queryParameters,
    Map<String, dynamic>? header,
    CancelToken? cancel,
  }) async {
    try {
      queryParameters ??= {};
      header ??= {};
      var result = await dio.download(
        url,
        savePath,
        queryParameters: queryParameters,
        options: Options(headers: header),
        cancelToken: cancel,
      );
      return result;
    } catch (e) {
      log(e.toString()); // 保持一致的日志记录
      if (e is DioException && e.type == DioExceptionType.badResponse) {
        throw CoreError(e.message ?? "", statusCode: e.response?.statusCode ?? 0);
      } else {
        throw CoreError("下载网络文件失败"); // 保持一致的默认失败提示
      }
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
    try {
      queryParameters ??= {};
      header ??= {};
      var result = await dio.get(
        url,
        queryParameters: queryParameters,
        options: Options(responseType: ResponseType.json, headers: header),
        cancelToken: cancel,
      );
      return result.data;
    } catch (e) {
      if (e is DioException && e.type == DioExceptionType.badResponse) {
        ToastUtil.show(e.message);
        throw CoreError(e.message ?? "", statusCode: e.response?.statusCode ?? 0);
      } else {
        throw CoreError("发送GET请求失败");
      }
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
        cancelToken: cancel,
      );
      return result.data;
    } catch (e) {
      if (e is DioException && e.type == DioExceptionType.badResponse) {
        throw CoreError(e.message ?? "", statusCode: e.response?.statusCode ?? 0);
      } else {
        throw CoreError("发送POST请求失败");
      }
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
    try {
      queryParameters ??= {};
      header ??= {};
      var result = await dio.head(
        url,
        queryParameters: queryParameters,
        options: Options(headers: header, receiveDataWhenStatusError: true),
        cancelToken: cancel,
      );
      return result;
    } catch (e) {
      if (e is DioException && e.type == DioExceptionType.badResponse) {
        //throw CoreError(e.message, statusCode: e.response?.statusCode ?? 0);
        return e.response!;
      } else {
        throw CoreError("发送HEAD请求失败");
      }
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
    try {
      queryParameters ??= {};
      header ??= {};
      var result = await dio.get(
        url,
        queryParameters: queryParameters,
        options: Options(responseType: ResponseType.json, headers: header),
        cancelToken: cancel,
      );
      return result;
    } catch (e) {
      if (e is DioException && e.type == DioExceptionType.badResponse) {
        return e.response!;
      } else {
        throw CoreError("发送GET请求失败");
      }
    }
  }
}
