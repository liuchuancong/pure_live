import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:pure_live/modules/remote_receiver/remote_sync_protocol.dart';
import 'package:pure_live/modules/remote_receiver/remote_sync_service.dart';

void main() {
  group('protocol', () {
    test('pairing codes are six digits and compare exactly', () {
      final code = RemoteSyncProtocol.newPairingCode(Random(1));
      expect(code, matches(RegExp(r'^\d{6}$')));
      expect(RemoteSyncProtocol.pairingCodesMatch(code, ' ${code.substring(0, 3)} ${code.substring(3)} '), isTrue);
      expect(RemoteSyncProtocol.pairingCodesMatch(code, '000000' == code ? '111111' : '000000'), isFalse);
      expect(RemoteSyncProtocol.pairingCodesMatch(code, null), isFalse);
      expect(RemoteSyncProtocol.pairingCodesMatch('', ''), isFalse, reason: 'a server without a code accepts nothing');
    });

    test('the QR code carries address and pairing code', () {
      final uri = RemoteSyncProtocol.createQrUri(ip: '192.168.1.20', port: 39888, code: '123456');
      final parsed = RemoteSyncProtocol.parseQr(uri.toString())!;
      expect((parsed.ip, parsed.port, parsed.code), ('192.168.1.20', 39888, '123456'));
      expect(RemoteSyncProtocol.parseQr('purelive://192.168.1.20:39888/sync?code=12')!.code, isNull);
      expect(RemoteSyncProtocol.parseQr('192.168.1.20:39900')!.code, isNull);
      expect(RemoteSyncProtocol.parseHttpAddress('192.168.1.20')!.port, RemoteSyncProtocol.defaultHttpPort);
      expect(RemoteSyncProtocol.parseQr('not a code'), isNull);
    });
  });

  group('server access', () {
    late HttpServer server;
    late RemoteSyncService service;
    final asked = <String>[];
    var allow = false;

    setUp(() async {
      asked.clear();
      allow = false;
      service = RemoteSyncService()
        ..pairingCode.value = '482913'
        ..confirmRequest = (action, remote) async {
          asked.add('$action from $remote');
          return allow;
        };
      server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      server.listen(service.handleRequest);
    });

    tearDown(() => server.close(force: true));

    Future<HttpClientResponse> send(String method, String path, {String? code, String? body}) async {
      final client = HttpClient();
      addTearDown(() => client.close(force: true));
      final request = await client.openUrl(method, Uri.parse('http://127.0.0.1:${server.port}$path'));
      if (code != null) request.headers.set(RemoteSyncProtocol.pairingHeader, code);
      if (body != null) request.write(body);
      return request.close();
    }

    Future<Map<String, dynamic>> json(HttpClientResponse response) async =>
        jsonDecode(await utf8.decoder.bind(response).join()) as Map<String, dynamic>;

    test('settings need the pairing code before the user is even asked', () async {
      for (final method in ['GET', 'POST']) {
        for (final code in [null, '000000', '48291']) {
          final response = await send(
            method,
            RemoteSyncProtocol.apiSettings,
            code: code,
            body: method == 'POST' ? '{}' : null,
          );
          expect(response.statusCode, HttpStatus.forbidden, reason: '$method code=$code');
          await response.drain<void>();
        }
      }
      expect(asked, isEmpty);
    });

    test('a correct code still needs the user to allow the request', () async {
      final read = await send('GET', RemoteSyncProtocol.apiSettings, code: '482913');
      expect(read.statusCode, HttpStatus.forbidden);
      await read.drain<void>();
      final write = await send(
        'POST',
        RemoteSyncProtocol.apiSettings,
        code: '482913',
        body: jsonEncode(RemoteSyncProtocol.settingsPacket(settings: {'theme': 'dark'})),
      );
      expect(write.statusCode, HttpStatus.forbidden);
      await write.drain<void>();
      expect(asked, ['export from 127.0.0.1', 'import from 127.0.0.1']);
    });

    test('no CORS: browser pages on the network cannot read responses', () async {
      final preflight = await send('OPTIONS', RemoteSyncProtocol.apiSettings);
      expect(preflight.headers.value('access-control-allow-origin'), isNull);
      await preflight.drain<void>();
      final status = await send('GET', RemoteSyncProtocol.apiStatus);
      expect(status.statusCode, HttpStatus.ok);
      expect(status.headers.value('access-control-allow-origin'), isNull);
      expect((await json(status))['data'], isNot(contains('settings')));
    });
  });
}
