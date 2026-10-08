import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pure_live/domains/live/data/stream/playback_source_transport.dart';
import 'package:pure_live/shared/platforms/live_site.dart';

/// 仿 TwitCasting 的 `tc-hls`：清单 200 并下发一个限定在流路径下的会话 cookie，
/// 子条目写**绝对路径**，分片不带那个 cookie 就 401。
final class _SessionCookieProvider {
  _SessionCookieProvider._(this._server);

  static const String cookie = 'lvhls_ssid_841801664=db5bc7f9439ee9db50b54ea5ba9d4dec';
  static const String streamPath = '/tc.livehls/v1/streams/841801664/hls/1008.96';

  static Future<_SessionCookieProvider> start() async {
    final HttpServer server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0, shared: false);
    final _SessionCookieProvider provider = _SessionCookieProvider._(server);
    server.listen(provider._handle);
    return provider;
  }

  final HttpServer _server;
  int segmentWithCookie = 0;
  int segmentWithoutCookie = 0;

  String get manifestUrl => 'http://${InternetAddress.loopbackIPv4.address}:${_server.port}$streamPath/media.m3u8';

  Future<void> _handle(HttpRequest request) async {
    final HttpResponse response = request.response;
    if (request.uri.path.endsWith('media.m3u8')) {
      response.headers.add('set-cookie', '$cookie; Path=$streamPath/; Max-Age=600; HttpOnly');
      response.headers.contentType = ContentType('application', 'vnd.apple.mpegurl');
      response.write(
        '#EXTM3U\n'
        '#EXT-X-VERSION:6\n'
        '#EXT-X-TARGETDURATION:2\n'
        '#EXT-X-MEDIA-SEQUENCE:1744\n'
        '#EXT-X-MAP:URI="$streamPath/init.2.mp4"\n'
        '#EXTINF:2.000,\n'
        '$streamPath/media.1744.mp4\n',
      );
      await response.close();
      return;
    }
    final bool authorized = request.headers.value(HttpHeaders.cookieHeader)?.contains(cookie) ?? false;
    if (authorized) {
      segmentWithCookie++;
    } else {
      segmentWithoutCookie++;
    }
    response.statusCode = authorized ? HttpStatus.ok : HttpStatus.unauthorized;
    if (authorized) response.add(utf8.encode('init-payload'));
    await response.close();
  }

  Future<void> close() => _server.close(force: true);
}

Future<(int, String)> _get(Uri uri) async {
  final HttpClient client = HttpClient();
  try {
    final HttpClientResponse response = await (await client.getUrl(uri)).close();
    return (response.statusCode, await response.transform(utf8.decoder).join());
  } finally {
    client.close(force: true);
  }
}

void main() {
  test('回环中继把清单下发的会话 cookie 带到分片上', () async {
    final _SessionCookieProvider provider = await _SessionCookieProvider.start();
    addTearDown(provider.close);
    final PlaybackSourceTransport transport = PlaybackSourceTransport();
    addTearDown(transport.close);

    final lease = await transport.prepare(
      url: provider.manifestUrl,
      headers: const {'Referer': 'https://twitcasting.tv/'},
      facts: (format: LiveStreamFormat.hls, codec: null, unresolvedChildren: true),
    );
    expect(lease, isNotNull, reason: '声明了 unresolvedChildren 的清单必须走回环改写');

    // 播放器看到的清单：子条目已经被换成本机地址，绝对路径不会再被当成本地文件。
    final (int manifestStatus, String manifest) = await _get(lease!.uri);
    expect(manifestStatus, HttpStatus.ok);
    expect(manifest, isNot(contains(_SessionCookieProvider.streamPath)));
    final Uri child = Uri.parse(RegExp(r'#EXT-X-MAP:URI="([^"]+)"').firstMatch(manifest)!.group(1)!);
    expect(child.host, InternetAddress.loopbackIPv4.address);

    // 分片：中继必须把清单那一次响应里的 Set-Cookie 带上，否则上游 401。
    final (int childStatus, String body) = await _get(child);
    expect(childStatus, HttpStatus.ok);
    expect(body, 'init-payload');
    expect(provider.segmentWithCookie, 1);
    expect(provider.segmentWithoutCookie, 0);
  });
}
