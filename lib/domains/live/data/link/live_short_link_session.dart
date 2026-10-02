import 'package:dio/dio.dart';

/// Owns only this parsing operation's client, budget and cancellation token.
/// A supplied factory must return a fresh client, never an application singleton.
class LiveShortLinkSession {
  LiveShortLinkSession({required this.timeout, Dio Function()? clientFactory})
    : _clientFactory = clientFactory ?? (() => Dio());

  final Duration timeout;
  final Dio Function() _clientFactory;
  final _cancel = CancelToken();
  final _visited = <String>{};
  Dio? _client;
  bool _closed = false;
  bool get isClosed => _closed;
  static const maxRequests = 8;
  static const redirectStatuses = {301, 302, 303, 307, 308};

  static bool isHttpUri(Uri uri) =>
      (uri.scheme == 'https' || uri.scheme == 'http') && uri.host.isNotEmpty && uri.userInfo.isEmpty;

  Future<Response<dynamic>?> get(Uri uri, {bool json = false, Map<String, dynamic>? headers}) async {
    final requestUri = uri.removeFragment();
    if (_closed || !isHttpUri(uri) || _visited.length >= maxRequests || !_visited.add(requestUri.toString())) {
      return null;
    }
    final client = _client ??= _clientFactory();
    client.options.connectTimeout = timeout;
    client.options.sendTimeout = timeout;
    client.options.receiveTimeout = timeout;
    try {
      final response = await client.get<dynamic>(
        requestUri.toString(),
        cancelToken: _cancel,
        options: Options(
          followRedirects: false,
          responseType: json ? ResponseType.json : ResponseType.stream,
          receiveDataWhenStatusError: false,
          validateStatus: (status) => status != null && status >= 200 && status < 400,
          headers: headers,
        ),
      );
      // Redirect resolution only needs headers; do not download a landing page.
      if (response.data case final ResponseBody body) {
        await body.stream.listen(null).cancel();
      }
      return _closed ? null : response;
    } on DioException {
      return null;
    } on FormatException {
      return null;
    }
  }

  static Uri? redirectTarget(Uri current, Response<dynamic>? response) {
    if (response == null || !redirectStatuses.contains(response.statusCode)) return null;
    final values = response.headers['location'];
    if (values == null || values.length != 1 || values.single.trim().isEmpty) return null;
    try {
      final target = current.resolve(values.single.trim());
      return isHttpUri(target) ? target : null;
    } on FormatException {
      return null;
    }
  }

  void close() {
    if (_closed) return;
    _closed = true;
    _cancel.cancel('Short-link parsing finished');
    _client?.close(force: true);
  }
}
