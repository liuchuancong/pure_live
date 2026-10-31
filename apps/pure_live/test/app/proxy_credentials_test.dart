// What dart:io actually puts on the wire for an authenticated HTTP proxy,
// measured against loopback proxies rather than taken from the SDK's shape.
//
// The four facts below are what a proxy-credential setting would be built on:
//
//  * `addProxyCredentials` is honoured **eagerly and correctly**: a request goes
//    out with `Proxy-Authorization: Basic …` on the first try, so a proxy that
//    answers an uncredentialed request with `407 + Proxy-Authenticate: Basic
//    realm="…"` is satisfied by that first request — no challenge round-trip is
//    needed, and none is taken.
//  * The same header reaches the **CONNECT** of a tunnel, which is the case every
//    HTTPS site request in this app depends on. (What follows an authorised
//    CONNECT here is a TLS handshake into a fake proxy that does not speak TLS,
//    so the tunneled request itself does not complete; the tunnel being
//    authorised is what is measured.)
//  * The credential is **bound to the host:port** it was registered for. Routing
//    the same client to a second proxy — same host, other port — presents
//    nothing to it, which is the property a stored credential has to have before
//    it can be offered at all.
//  * The route-string form `PROXY http://user:pass@host:port` is **not** usable
//    as typed: `_ProxyConfiguration` cuts the userinfo at the last `@` and then
//    at the first colon, so the scheme lands inside the username and the proxy
//    is handed `Basic` of `http://user:pass`. The schemeless
//    `PROXY user:pass@host:port` is what that parser wants — and what
//    `findProxyFromEnvironment` builds after stripping the scheme itself.
//
// So proxy credentials are expressible on this stack through the registered
// credentials. What is left before a setting could ship is a decision, not a
// capability: where the password lives, and how the consumers outside dart:io —
// mpv's `http-proxy` and FFmpeg's `-http_proxy`, which takes no credential at
// all — are given the same answer instead of a control only some requests
// honour.
//
// The fake proxies never close a socket, and the credential is matched
// case-insensitively on both sides: Basic's base64 alphabet is mixed-case, and
// comparing a lowercased line against the mixed-case constant hides the very
// header these tests exist to see — which is exactly how an earlier run of this
// probe came out looking like a client that could never answer a challenge.
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data' show BytesBuilder;

import 'package:flutter_test/flutter_test.dart';

/// The Basic encoding of `user:secret`.
/// The header as it is matched: compared case-insensitively on both sides,
/// because Basic's base64 alphabet is mixed-case and lowercasing only one side
/// would hide the very header these tests are looking for.
const String _credential = 'proxy-authorization: basic dxnlcjpzzwnyzxq=';


/// How long one request is given before it counts as never completing.
const Duration _patience = Duration(seconds: 3);

/// A loopback proxy that records every complete request line it was sent,
/// headers joined on so a credential riding anywhere in the block is visible.
final class _FakeProxy {
  _FakeProxy._(this.port, this.host, this.server, this._seen);

  /// Listens on [port]. With [challenge], a request that carries no credential
  /// is answered with a 407 and a Basic realm — the shape a real authenticated
  /// proxy uses. Sockets are never closed: a client cut off mid-retry loops
  /// against a fresh connection instead, and the log stops being readable.
  static Future<_FakeProxy> start({required int port, required bool challenge}) async {
    final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, port);
    final seen = <String>[];
    server.listen((socket) {
      final buffer = BytesBuilder(copy: false);
      socket.listen((bytes) async {
        buffer.add(bytes);
        final chunk = const Utf8Decoder(allowMalformed: true).convert(buffer.toBytes());
        final block = _firstRequest(chunk);
        if (block == null) return;
        buffer.clear();
        seen.add(block);
        if (challenge && !_presentsCredential(block)) {
          socket.write(
            'HTTP/1.1 407 Proxy Authentication Required\r\n'
            'Proxy-Authenticate: Basic realm="probe"\r\n'
            'content-length: 0\r\n\r\n',
          );
          await socket.flush();
          return;
        }
        socket.write(
          block.startsWith('CONNECT ')
              ? 'HTTP/1.1 200 Connection established\r\n\r\n'
              : 'HTTP/1.1 200 OK\r\ncontent-length: 2\r\n\r\nhi',
        );
        await socket.flush();
      });
    });
    return _FakeProxy._(port, server.address.host, server, seen);
  }

  final int port;
  final String host;
  final ServerSocket server;
  final List<String> _seen;

  /// The recorded requests.
  List<String> get requests => List.unmodifiable(_seen);

  /// The route string for this proxy with nothing attached.
  String get plainRoute => 'PROXY $host:$port';

  /// The route string with credentials in it, in the form the SDK's own
  /// documentation suggests for an authenticated proxy.
  String get routeStringCredentials => 'PROXY http://user:secret@$host:$port';

  /// How many recorded requests carried the exact credential.
  int get credentialCount => _seen.where(_presentsCredential).length;

  /// How many carried *some* Proxy-Authorization, right or wrong.
  int get anyCredentialCount => _seen.where((line) => line.toLowerCase().contains('proxy-authorization:')).length;

  Future<void> close() => server.close();
}

/// The first complete request in [chunk], or null until its blank line arrives.
String? _firstRequest(String chunk) {
  final end = chunk.indexOf('\r\n\r\n');
  if (end < 0) return null;
  final lines = chunk.substring(0, end).split('\r\n').where((line) => line.trim().isNotEmpty).toList();
  return lines.isEmpty ? null : lines.join(' | ');
}

/// Whether [block] presents the expected credential.
bool _presentsCredential(String block) => block.toLowerCase().contains(_credential);

/// GETs [url] through [client]; answers the status, or null when it never
/// completed inside [_patience]. The client is left open: a caller routes the
/// same client at a second proxy, which is what the scope test measures.
Future<int?> _get(HttpClient client, String url) async {
  try {
    final request = await client.openUrl('GET', Uri.parse(url)).timeout(_patience);
    final response = await request.close().timeout(_patience);
    await response.drain<void>();
    return response.statusCode;
  } on Object {
    return null;
  }
}

void main() {
  test('a registered credential satisfies a challenging proxy in one attempt', () async {
    final proxy = await _FakeProxy.start(port: 18160, challenge: true);
    final client = HttpClient()
      ..findProxy = ((uri) => proxy.plainRoute)
      ..addProxyCredentials(proxy.host, proxy.port, '', HttpClientBasicCredentials('user', 'secret'));

    expect(await _get(client, 'http://forwarded.example.invalid/x'), 200, reason: '${proxy.requests}');
    expect(proxy.requests.length, 1, reason: 'eagerly, with no challenge round: ${proxy.requests}');
    expect(proxy.credentialCount, 1);

    client.close(force: true);
    await proxy.close();
  });

  test('a registered credential reaches the CONNECT of a tunnel', () async {
    final proxy = await _FakeProxy.start(port: 18161, challenge: true);
    final client = HttpClient()
      ..findProxy = ((uri) => proxy.plainRoute)
      ..addProxyCredentials(proxy.host, proxy.port, '', HttpClientBasicCredentials('user', 'secret'));

    // The request itself cannot complete: what follows an authorised CONNECT is a
    // TLS handshake into a fake proxy that does not speak TLS. What is measured
    // here is that the tunnel was authorised at all — the case every HTTPS site
    // request in this app depends on.
    expect(await _get(client, 'https://tunneled.example.invalid/x'), isNull);
    expect(proxy.requests.first, startsWith('CONNECT '));
    expect(proxy.credentialCount, 1, reason: 'the CONNECT carried it: ${proxy.requests}');

    client.close(force: true);
    await proxy.close();
  });

  test('a credential is bound to the host:port it was registered for', () async {
    final first = await _FakeProxy.start(port: 18162, challenge: false);
    final second = await _FakeProxy.start(port: 18163, challenge: false);
    final client = HttpClient()
      ..findProxy = ((uri) => first.plainRoute)
      ..addProxyCredentials(first.host, first.port, '', HttpClientBasicCredentials('user', 'secret'));

    expect(await _get(client, 'http://first.example.invalid/x'), 200);
    expect(first.credentialCount, 1);
    // The same client, routed to a proxy nothing was registered for. Both
    // proxies are this same host on another port — the narrowest case the SDK
    // has to get right before a credential could be stored anywhere.
    client.findProxy = (uri) => second.plainRoute;
    expect(await _get(client, 'http://second.example.invalid/x'), 200);
    expect(second.anyCredentialCount, 0, reason: 'a credential never travels on: ${second.requests}');

    client.close(force: true);
    await first.close();
    await second.close();
  });

  test('the route-string form puts the scheme inside the username', () async {
    final tunnel = await _FakeProxy.start(port: 18164, challenge: false);
    final client = HttpClient()..findProxy = ((uri) => tunnel.routeStringCredentials);

    await _get(client, 'https://route-string.example.invalid/x');
    expect(tunnel.requests.first, startsWith('CONNECT '));
    expect(tunnel.anyCredentialCount, 1, reason: 'a credential was sent: ${tunnel.requests}');
    expect(tunnel.credentialCount, 0, reason: 'and it was the wrong one — Basic of "http://user:secret"');

    client.close(force: true);
    await tunnel.close();
  });
}
