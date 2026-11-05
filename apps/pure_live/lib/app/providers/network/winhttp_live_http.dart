import 'dart:async' show Future, Stream;
import 'dart:ffi' as ffi;
import 'dart:isolate' show Isolate;
import 'dart:typed_data' show Uint8List;

// `ffi` is already in the workspace graph (live_platform declares it); the
// adapter stays here so only Windows pays for it.
// ignore: depend_on_referenced_packages
import 'package:ffi/ffi.dart';
import 'package:live_net/live_net.dart';

/// A Windows HTTP channel over WinHTTP/Schannel.
///
/// Cloudflare refuses Flutter's dart:io TLS handshake on some hosts
/// (Kick is the one this app needs); Windows' own stack answers 200 for the
/// same request. This transport is the Windows half of the reference's
/// "native TLS channel" seam: the app hands it only to the sites that need
/// it, everything else keeps the shared Dio transport.
///
/// Requests are buffered and run in an isolate, because the WinHTTP calls are
/// synchronous and must never block the UI isolate.
final class WinHttpLiveHttp implements LiveHttp {
  /// A transport whose proxy is read at each request.
  WinHttpLiveHttp({required this.route, this.agent = 'PureLive'});

  /// The proxy route in force for this request.
  final ProxyRoute Function() route;

  /// The user agent WinHTTP sends.
  final String agent;

  bool _closed = false;

  @override
  Future<LiveResponse> send(LiveRequest request) async {
    if (_closed) throw const ConnectFailure('the WinHTTP transport is closed');
    final cancel = request.cancelToken;
    if (cancel.isCancelled) throw const CancelledFailure();
    final method = request.method;
    final url = request.url.toString();
    final headers = request.headers;
    final body = request.bodyBytes;
    final timeoutMs = (request.timeout ?? const Duration(seconds: 30)).inMilliseconds;
    final agentName = agent;
    final proxy = route();
    final result = await Isolate.run(
      () => _winHttpGet(
        method: method,
        url: url,
        headers: headers,
        body: body,
        timeoutMs: timeoutMs,
        agent: agentName,
        proxy: proxy,
      ),
    );
    if (cancel.isCancelled) throw const CancelledFailure();
    return LiveResponse(
      statusCode: result.status,
      headers: result.headers,
      bodyBytes: result.body,
      setCookies: result.setCookies,
    );
  }

  @override
  Future<LiveStreamedResponse> open(LiveRequest request) async {
    final response = await send(request);
    return _BufferedResponse(response);
  }

  @override
  void close() {
    _closed = true;
  }
}

final class _BufferedResponse implements LiveStreamedResponse {
  _BufferedResponse(this.response);

  final LiveResponse response;

  @override
  int get statusCode => response.statusCode;

  @override
  Map<String, String> get headers => response.headers;

  @override
  Stream<Uint8List> get stream => Stream.value(response.bodyBytes);

  @override
  Future<void> close() async {}
}

// ---------------------------------------------------------------------------
// The isolate half: plain ffi, no Dart objects from the app's state.

final class _WinHttpResult {
  const _WinHttpResult({required this.status, required this.headers, required this.setCookies, required this.body});

  final int status;
  final Map<String, String> headers;
  final List<String> setCookies;
  final Uint8List body;
}

const int _accessNoProxy = 1;
const int _accessNamedProxy = 3;
const int _flagSecure = 0x00800000;
const int _queryStatusCode = 19;
const int _queryRawHeaders = 22;
const int _queryFlagNumber = 0x20000000;
const int _authTargetProxy = 1;
const int _authSchemeBasic = 1;

void _free(ffi.Pointer<ffi.NativeType> pointer) => malloc.free(pointer);

_WinHttpResult _winHttpGet({
  required String method,
  required String url,
  required Map<String, String> headers,
  required Uint8List? body,
  required int timeoutMs,
  required String agent,
  required ProxyRoute proxy,
}) {
  final winhttp = ffi.DynamicLibrary.open('winhttp.dll');
  final kernel32 = ffi.DynamicLibrary.open('kernel32.dll');

  final open = winhttp
      .lookupFunction<
        ffi.IntPtr Function(ffi.Pointer<Utf16>, ffi.Uint32, ffi.Pointer<Utf16>, ffi.Pointer<Utf16>, ffi.Uint32),
        int Function(ffi.Pointer<Utf16>, int, ffi.Pointer<Utf16>, ffi.Pointer<Utf16>, int)
      >('WinHttpOpen');
  final connect = winhttp
      .lookupFunction<
        ffi.IntPtr Function(ffi.IntPtr, ffi.Pointer<Utf16>, ffi.Uint16, ffi.Uint32),
        int Function(int, ffi.Pointer<Utf16>, int, int)
      >('WinHttpConnect');
  final openRequest = winhttp
      .lookupFunction<
        ffi.IntPtr Function(
          ffi.IntPtr,
          ffi.Pointer<Utf16>,
          ffi.Pointer<Utf16>,
          ffi.Pointer<Utf16>,
          ffi.Pointer<Utf16>,
          ffi.Pointer<ffi.Pointer<Utf16>>,
          ffi.Uint32,
        ),
        int Function(
          int,
          ffi.Pointer<Utf16>,
          ffi.Pointer<Utf16>,
          ffi.Pointer<Utf16>,
          ffi.Pointer<Utf16>,
          ffi.Pointer<ffi.Pointer<Utf16>>,
          int,
        )
      >('WinHttpOpenRequest');
  final sendRequest = winhttp
      .lookupFunction<
        ffi.Int32 Function(
          ffi.IntPtr,
          ffi.Pointer<Utf16>,
          ffi.Uint32,
          ffi.Pointer<ffi.Void>,
          ffi.Uint32,
          ffi.Uint32,
          ffi.IntPtr,
        ),
        int Function(int, ffi.Pointer<Utf16>, int, ffi.Pointer<ffi.Void>, int, int, int)
      >('WinHttpSendRequest');
  final receive = winhttp
      .lookupFunction<ffi.Int32 Function(ffi.IntPtr, ffi.Pointer<ffi.Void>), int Function(int, ffi.Pointer<ffi.Void>)>(
        'WinHttpReceiveResponse',
      );
  final queryHeaders = winhttp
      .lookupFunction<
        ffi.Int32 Function(
          ffi.IntPtr,
          ffi.Uint32,
          ffi.Pointer<Utf16>,
          ffi.Pointer<ffi.Void>,
          ffi.Pointer<ffi.Uint32>,
          ffi.Pointer<ffi.Uint32>,
        ),
        int Function(
          int,
          int,
          ffi.Pointer<Utf16>,
          ffi.Pointer<ffi.Void>,
          ffi.Pointer<ffi.Uint32>,
          ffi.Pointer<ffi.Uint32>,
        )
      >('WinHttpQueryHeaders');
  final queryData = winhttp
      .lookupFunction<
        ffi.Int32 Function(ffi.IntPtr, ffi.Pointer<ffi.Uint32>),
        int Function(int, ffi.Pointer<ffi.Uint32>)
      >('WinHttpQueryDataAvailable');
  final readData = winhttp
      .lookupFunction<
        ffi.Int32 Function(ffi.IntPtr, ffi.Pointer<ffi.Void>, ffi.Uint32, ffi.Pointer<ffi.Uint32>),
        int Function(int, ffi.Pointer<ffi.Void>, int, ffi.Pointer<ffi.Uint32>)
      >('WinHttpReadData');
  final setTimeouts = winhttp
      .lookupFunction<
        ffi.Int32 Function(ffi.IntPtr, ffi.Int32, ffi.Int32, ffi.Int32, ffi.Int32),
        int Function(int, int, int, int, int)
      >('WinHttpSetTimeouts');
  final setCredentials = winhttp
      .lookupFunction<
        ffi.Int32 Function(
          ffi.IntPtr,
          ffi.Uint32,
          ffi.Uint32,
          ffi.Pointer<Utf16>,
          ffi.Pointer<Utf16>,
          ffi.Pointer<ffi.Void>,
        ),
        int Function(int, int, int, ffi.Pointer<Utf16>, ffi.Pointer<Utf16>, ffi.Pointer<ffi.Void>)
      >('WinHttpSetCredentials');
  final closeHandle = winhttp.lookupFunction<ffi.Int32 Function(ffi.IntPtr), int Function(int)>('WinHttpCloseHandle');
  final getLastError = kernel32.lookupFunction<ffi.Uint32 Function(), int Function()>('GetLastError');

  String? proxyHostPort;
  String? proxyUser;
  String? proxyPassword;
  switch (proxy) {
    case HttpProxyRoute():
      proxyHostPort = '${proxy.host}:${proxy.port}';
      if (proxy.isAuthenticationRequired) {
        proxyUser = proxy.username;
        proxyPassword = proxy.password;
      }
    case DirectRoute():
      break;
    case SystemProxyRoute():
      // The app resolves the system route before handing it in; a raw
      // SystemProxyRoute here means the caller did not, and WinHTTP's own
      // automatic proxy is the honest answer.
      proxyHostPort = null;
  }

  final agentPtr = agent.toNativeUtf16();
  final proxyPtr = proxyHostPort == null ? ffi.nullptr : proxyHostPort.toNativeUtf16();
  var session = 0;
  var connection = 0;
  var request = 0;
  try {
    session = open(agentPtr, proxyHostPort == null ? _accessNoProxy : _accessNamedProxy, proxyPtr, ffi.nullptr, 0);
    if (session == 0) {
      throw const ConnectFailure('WinHTTP could not open a session');
    }
    setTimeouts(session, timeoutMs, timeoutMs, timeoutMs, timeoutMs);
    final uri = Uri.parse(url);
    final port = uri.hasPort ? uri.port : (uri.scheme == 'https' ? 443 : 80);
    final hostPtr = uri.host.toNativeUtf16();
    try {
      connection = connect(session, hostPtr, port, 0);
    } finally {
      _free(hostPtr);
    }
    if (connection == 0) {
      throw ConnectFailure('WinHTTP could not connect to ${uri.host}');
    }
    final path = uri.hasQuery ? '${uri.path}?${uri.query}' : (uri.path.isEmpty ? '/' : uri.path);
    final pathPtr = path.toNativeUtf16();
    final verbPtr = method.toUpperCase().toNativeUtf16();
    try {
      request = openRequest(
        connection,
        verbPtr,
        pathPtr,
        ffi.nullptr,
        ffi.nullptr,
        ffi.nullptr,
        uri.scheme == 'https' ? _flagSecure : 0,
      );
    } finally {
      _free(pathPtr);
      _free(verbPtr);
    }
    if (request == 0) {
      throw const ConnectFailure('WinHTTP could not build the request');
    }
    if (proxyHostPort != null && proxyUser != null && proxyPassword != null) {
      final userPtr = proxyUser.toNativeUtf16();
      final passPtr = proxyPassword.toNativeUtf16();
      try {
        setCredentials(request, _authTargetProxy, _authSchemeBasic, userPtr, passPtr, ffi.nullptr);
      } finally {
        _free(userPtr);
        _free(passPtr);
      }
    }
    final headerText = [
      for (final entry in headers.entries)
        if (entry.key.toLowerCase() != 'host' && entry.key.toLowerCase() != 'content-length')
          '${entry.key}: ${entry.value}',
    ].join('\r\n');
    final headerPtr = headerText.isEmpty ? ffi.nullptr : headerText.toNativeUtf16();
    final bodyPtr = body == null || body.isEmpty ? ffi.nullptr : calloc<ffi.Uint8>(body.length);
    if (body != null && body.isNotEmpty) {
      bodyPtr.asTypedList(body.length).setAll(0, body);
    }
    final sent = sendRequest(
      request,
      headerPtr,
      headerText.isEmpty ? 0 : -1,
      bodyPtr.cast<ffi.Void>(),
      body?.length ?? 0,
      body?.length ?? 0,
      0,
    );
    if (headerPtr != ffi.nullptr) _free(headerPtr);
    if (bodyPtr != ffi.nullptr) _free(bodyPtr);
    if (sent == 0) {
      final error = getLastError();
      if (error == 12002) throw const TimeoutFailure('WinHTTP timed out');
      throw ProtocolFailure('WinHTTP send failed (${error == 0 ? 'unknown' : error})');
    }
    if (receive(request, ffi.nullptr) == 0) {
      final error = getLastError();
      if (error == 12002) throw const TimeoutFailure('WinHTTP timed out');
      throw ProtocolFailure('WinHTTP receive failed (${error == 0 ? 'unknown' : error})');
    }

    final statusPtr = calloc<ffi.Uint32>();
    final lengthPtr = calloc<ffi.Uint32>()..value = 4;
    var status = 0;
    try {
      if (queryHeaders(
            request,
            _queryStatusCode | _queryFlagNumber,
            ffi.nullptr,
            statusPtr.cast(),
            lengthPtr,
            ffi.nullptr,
          ) !=
          0) {
        status = statusPtr.value;
      }
    } finally {
      _free(statusPtr);
      _free(lengthPtr);
    }

    final rawHeaders = _rawHeaders(request, queryHeaders);
    final parsed = _parseHeaders(rawHeaders);

    final chunks = <int>[];
    final availablePtr = calloc<ffi.Uint32>();
    final readPtr = calloc<ffi.Uint32>();
    final buffer = calloc<ffi.Uint8>(64 * 1024);
    try {
      while (true) {
        final has = queryData(request, availablePtr);
        if (has == 0) break;
        var left = availablePtr.value;
        if (left == 0) break;
        while (left > 0) {
          final want = left > 64 * 1024 ? 64 * 1024 : left;
          final read = readData(request, buffer.cast(), want, readPtr);
          if (read == 0) {
            final error = getLastError();
            throw ProtocolFailure('WinHTTP read failed (${error == 0 ? 'unknown' : error})');
          }
          final got = readPtr.value;
          if (got == 0) break;
          chunks.addAll(buffer.asTypedList(got));
          left -= got;
        }
      }
    } finally {
      _free(availablePtr);
      _free(readPtr);
      _free(buffer);
    }
    return _WinHttpResult(status: status, headers: parsed.$1, setCookies: parsed.$2, body: Uint8List.fromList(chunks));
  } finally {
    if (request != 0) closeHandle(request);
    if (connection != 0) closeHandle(connection);
    if (session != 0) closeHandle(session);
    _free(agentPtr);
    if (proxyPtr != ffi.nullptr) _free(proxyPtr);
  }
}

String _rawHeaders(
  int request,
  int Function(int, int, ffi.Pointer<Utf16>, ffi.Pointer<ffi.Void>, ffi.Pointer<ffi.Uint32>, ffi.Pointer<ffi.Uint32>)
  queryHeaders,
) {
  const capacity = 64 * 1024;
  final buffer = calloc<ffi.Uint16>(capacity);
  final length = calloc<ffi.Uint32>()..value = capacity;
  try {
    final ok = queryHeaders(request, _queryRawHeaders, ffi.nullptr, buffer.cast(), length, ffi.nullptr);
    if (ok == 0) return '';
    final units = buffer.asTypedList(length.value ~/ 2);
    return String.fromCharCodes(units);
  } finally {
    _free(buffer);
    _free(length);
  }
}

(Map<String, String>, List<String>) _parseHeaders(String raw) {
  final headers = <String, String>{};
  final setCookies = <String>[];
  for (final line in raw.split('\r\n')) {
    final separator = line.indexOf(':');
    if (separator <= 0) continue;
    final name = line.substring(0, separator).trim().toLowerCase();
    final value = line.substring(separator + 1).trim();
    if (name.isEmpty) continue;
    if (name == 'set-cookie') {
      setCookies.add(value);
      headers[name] = [headers[name], value].whereType<String>().join(', ');
      continue;
    }
    headers[name] = headers.containsKey(name) ? '${headers[name]}, $value' : value;
  }
  return (headers, setCookies);
}
