
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:pure_live/core/common/core_log.dart';
import 'package:pure_live/plugins/dns4flutter/dns_helper.dart';

class CustomIOHttpClientAdapter {

  static IOHttpClientAdapter get instance {
    return IOHttpClientAdapter(createHttpClient: () {
      var httpClient = HttpClient();
      httpClient.badCertificateCallback =
          (X509Certificate cert, String host, int port) => true;
      return httpClient;
    });
  }
}

class GlobalHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    var client = super.createHttpClient(context)
      ..badCertificateCallback =
          (X509Certificate cert, String host, int port) => true;
    return client;
  }
}

class DomainHttpClientAdapter implements HttpClientAdapter {
  @override
  void close({bool force = false}) {
  }

  @override
  Future<ResponseBody> fetch(
      RequestOptions options, Stream<Uint8List>? requestStream, Future<dynamic>? cancelFuture) async {
    // 自定义 DNS 解析
    CoreLog.d("DomainHttpClientAdapter------------>fetch-->${options.uri.host}");
    Uri newUri = options.uri;
    String host = options.uri.host;
    String ipAddress = await _resolveHostToIp(host);
    int port = options.uri.port;
    String scheme = options.uri.scheme;
    String newPath = '$scheme://$ipAddress:$port${options.uri.path}${options.uri.query}';
    CoreLog.d("DomainHttpClientAdapter------------>newPath->$newPath-->");
    options.baseUrl = newPath;
    options.path = "";

    final HttpClient httpClient = HttpClient();
    httpClient.badCertificateCallback =
        (X509Certificate cert, String host, int port) => true;

    CoreLog.d("DomainHttpClientAdapter------------>openUrl-newUri->$newUri--baseUrl->${options.baseUrl}");
    final HttpClientRequest httpRequest = await httpClient.openUrl(options.method, newUri);
    // 设置请求头
    options.headers.forEach((key, value) {
      httpRequest.headers.set(key, value);
    });

    // 写入请求体
    if (requestStream != null) {
      await requestStream.forEach(httpRequest.add);
    }

    final HttpClientResponse httpResponse = await httpRequest.close();

    // 读取响应数据
    final List<int> responseBody = await httpResponse.fold([], (List<int> a, List<int> b) => a..addAll(b));

    return ResponseBody.fromBytes(
      responseBody,
      httpResponse.statusCode,
      headers: convertHeaders(httpResponse.headers),
      statusMessage: httpResponse.reasonPhrase,
    );
  }

  // 将 HttpHeaders 转换为 Dio 需要的 headers 格式
  Map<String, List<String>> convertHeaders(HttpHeaders headers) {
    Map<String, List<String>> convertedHeaders = {};
    headers.forEach((name, values) {
      convertedHeaders[name] = values;
    });
    return convertedHeaders;
  }

  ///使用通道，发送消息到原生进行DNS解析
  Future<String> _resolveHostToIp(String host) async {
    try{
      await DnsHelper.lookupARecords(host);
      var ip =  await DnsHelper.lookupARecords(host);
      CoreLog.d("DomainHttpClientAdapter------------>_resolveHostToIp-->$ip");
      return ip[0];
    }catch(e){
      return host;
    }
  }
}