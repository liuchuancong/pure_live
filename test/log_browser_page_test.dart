import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pure_live/core/common/log.dart';

void main() {
  late HttpServer server;
  late HttpClient client;

  setUp(() async {
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen(Log.serveBrowserRequestForTesting);
    client = HttpClient();
  });

  tearDown(() async {
    client.close(force: true);
    await server.close(force: true);
    Log.clearDebugLogs();
  });

  test('browser request policy keeps reads narrow and makes clearing an explicit same-origin action', () {
    expect(Log.classifyBrowserRequest(method: 'GET', path: '/'), LogBrowserRequestAction.page);
    expect(Log.classifyBrowserRequest(method: 'POST', path: '/'), LogBrowserRequestAction.methodNotAllowed);
    expect(Log.classifyBrowserRequest(method: 'GET', path: '/clear'), LogBrowserRequestAction.methodNotAllowed);
    expect(
      Log.classifyBrowserRequest(method: 'POST', path: '/clear', actionHeader: 'clear'),
      LogBrowserRequestAction.clear,
    );
    expect(Log.classifyBrowserRequest(method: 'POST', path: '/clear'), LogBrowserRequestAction.forbidden);
    expect(Log.classifyBrowserRequest(method: 'GET', path: '/favicon.ico'), LogBrowserRequestAction.notFound);
  });

  test('browser responses disable caching, framing and cross-origin reuse', () {
    expect(Log.browserSecurityHeaders['Cache-Control'], contains('no-store'));
    expect(Log.browserSecurityHeaders['X-Content-Type-Options'], 'nosniff');
    expect(Log.browserSecurityHeaders['X-Frame-Options'], 'DENY');
    expect(Log.browserSecurityHeaders['Cross-Origin-Resource-Policy'], 'same-origin');
    expect(Log.browserSecurityHeaders['Referrer-Policy'], 'no-referrer');
    expect(Log.browserSecurityHeaders['Content-Security-Policy'], contains("frame-ancestors 'none'"));
  });

  test('browser page escapes log text and exposes a clear empty state', () {
    expect(Log.renderBrowserPage(), contains('No logs in this session.'));

    Log.addDebugLog('<script>alert("x")</script>\n  tail & value');
    final html = Log.renderBrowserPage();

    expect(html, isNot(contains('<script>alert("x")</script>')));
    expect(html, contains('&lt;script&gt;'));
    expect(html, contains('<br>&nbsp;&nbsp;tail&nbsp;&amp;&nbsp;value'));
    expect(html, contains('Total: 1'));
  });

  test('browser page has responsive actions without inline click handlers', () {
    final html = Log.renderBrowserPage();

    expect(html, contains('@media (max-width: 640px)'));
    expect(html, contains('min-height: 44px'));
    expect(html, contains('<button type="button"'));
    expect(html, isNot(contains('onclick=')));
    expect(html, isNot(contains('border-radius: 2Fpx')));
    expect(html, contains("method: 'POST'"));
    expect(html, contains("'X-PureLive-Log-Action': 'clear'"));
    expect(html, contains('Clear all logs from this session?'));
  });

  test('live browser endpoint enforces route, method, action header and response headers', () async {
    Log.addDebugLog('retained');

    final page = await _request(client, server, method: 'GET', path: '/');
    expect(page.statusCode, HttpStatus.ok);
    expect(page.contentType?.mimeType, 'text/html');
    expect(page.headers.value('Cache-Control'), contains('no-store'));
    expect(page.body, contains('retained'));

    final getClear = await _request(client, server, method: 'GET', path: '/clear');
    expect(getClear.statusCode, HttpStatus.methodNotAllowed);
    expect(getClear.headers.value('Allow'), 'POST');
    expect(Log.allLogs, hasLength(1));

    final missingAction = await _request(client, server, method: 'POST', path: '/clear');
    expect(missingAction.statusCode, HttpStatus.forbidden);
    expect(Log.allLogs, hasLength(1));

    final cleared = await _request(client, server, method: 'POST', path: '/clear', actionHeader: 'clear');
    expect(cleared.statusCode, HttpStatus.ok);
    expect(jsonDecode(cleared.body), {'success': true});
    expect(Log.allLogs, isEmpty);

    final missing = await _request(client, server, method: 'GET', path: '/favicon.ico');
    expect(missing.statusCode, HttpStatus.notFound);
  });
}

Future<_BrowserResponse> _request(
  HttpClient client,
  HttpServer server, {
  required String method,
  required String path,
  String? actionHeader,
}) async {
  final request = await client.openUrl(
    method,
    Uri(scheme: 'http', host: InternetAddress.loopbackIPv4.address, port: server.port, path: path),
  );
  if (actionHeader != null) request.headers.set(Log.browserClearActionHeader, actionHeader);
  final response = await request.close();
  final body = await utf8.decoder.bind(response).join();
  return _BrowserResponse(
    statusCode: response.statusCode,
    contentType: response.headers.contentType,
    headers: response.headers,
    body: body,
  );
}

class _BrowserResponse {
  const _BrowserResponse({
    required this.statusCode,
    required this.contentType,
    required this.headers,
    required this.body,
  });

  final int statusCode;
  final ContentType? contentType;
  final HttpHeaders headers;
  final String body;
}
