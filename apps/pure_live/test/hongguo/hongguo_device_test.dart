import 'dart:convert' show jsonEncode, utf8;
import 'dart:typed_data' show Uint8List;

import 'package:crypto/crypto.dart' as crypto;
import 'package:flutter_test/flutter_test.dart';
import 'package:live_net/live_net.dart' show LiveHttp, LiveRequest, LiveResponse, LiveStreamedResponse;
import 'package:live_storage/live_storage.dart';
import 'package:pure_live/modules/hongguo/official/hongguo_device.dart';

/// The playback device's own affairs, argued over a stubbed applog service
/// and an in-memory store: the body carries the ttEncrypt envelope with a
/// fresh salt each time, the register headers are deliberately unsigned,
/// the answer's ids and cookies are picked apart (and the refusals
/// refused), the identity is registered once, kept for the process,
/// carried across restarts with its cookies, and forgotten on demand.
Future<void> _settle() async {
  for (var i = 0; i < 5; i++) {
    await pumpEventQueue();
  }
}

String _answer() => jsonEncode({
  'device_id_str': '710000123456',
  'install_id_str': '710000654321',
  'device_token': 'tok-1',
  'new_user': 1,
});

const _setCookies = ['install_id=710000654321; Path=/; HttpOnly', 'ttreq=1; Path=/', 'other=x; Path=/'];

void main() {
  group('the register body', () {
    test('the body carries the ttEncrypt magic, a fresh salt and block-aligned cipher', () {
      final body = hongguoDevicePayload(const {}, now: 1700000000000);
      expect(body.sublist(0, 6), [0x74, 0x63, 0x05, 0x10, 0x00, 0x00]); // the envelope's own magic
      expect(body.length, greaterThan(38)); // magic, the 32-byte salt, then blocks
      expect((body.length - 38) % 16, 0); // whole AES blocks
      expect(hongguoDevicePayload(const {}, now: 1700000000000), isNot(equals(body))); // a fresh salt each ask
    });

    test('the headers are deliberately unsigned, the ticket stamps the ask', () {
      final body = hongguoDevicePayload(const {}, now: 1);
      final headers = hongguoDeviceHeaders(body, const {}, now: 1700000000000);
      expect(headers['x-ss-req-ticket'], '1700000000000');
      expect(headers['Content-Type'], 'application/octet-stream;tt-data=a');
      expect(headers['x-ss-dp'], '8662');
      expect(headers['x-ss-stub'], crypto.md5.convert(body).toString().toUpperCase()); // the body's own checksum
      expect(headers.containsKey('x-gorgon'), isFalse); // a signed register reads as a broken client
      expect(headers.containsKey('x-ladon'), isFalse);
      expect(headers.containsKey('x-argus'), isFalse);
    });
  });

  group('the register answer', () {
    test('the answer names the device, keeps the cookies it should and flags a fresh device', () {
      final registered = hongguoParseRegistered(_answer(), _setCookies);
      expect(registered!.deviceId, '710000123456');
      expect(registered.installId, '710000654321');
      expect(registered.deviceToken, 'tok-1');
      expect(registered.newUser, isTrue); // new_user == 1
      // The parse keeps every well-formed pair; the session keeps only its own names.
      expect(registered.cookies, {'install_id': '710000654321', 'ttreq': '1', 'other': 'x'});
    });

    test('a numeric id falls back, and the refusals refuse', () {
      expect(
        hongguoParseRegistered(
          jsonEncode({'device_id': 710000123456, 'install_id': '710000654321'}),
          const [],
        )!.deviceId,
        '710000123456', // the numeric form reads too
      );
      expect(hongguoParseRegistered(jsonEncode({'device_id': '0', 'install_id': '1'}), const []), isNull);
      expect(hongguoParseRegistered(jsonEncode({'device_id': '', 'install_id': '1'}), const []), isNull);
      expect(hongguoParseRegistered(jsonEncode({'install_id': '1'}), const []), isNull);
      expect(hongguoParseRegistered('not-json', const []), isNull);
      expect(hongguoParseRegistered('[]', const []), isNull);
      expect(
        hongguoParseRegistered(jsonEncode({'device_id': '7', 'install_id': '8', 'new_user': true}), const [])!.newUser,
        isTrue,
      );
    });
  });

  group('the session', () {
    late StorageStores stores;

    setUp(() async {
      stores = await StorageStores.openInMemory();
      await StoragePrefs.init();
    });

    tearDown(() => stores.close());

    test('the first playback registers unsigned, answers the profile and asks nothing again', () async {
      final stub = _Stub(_answer(), setCookies: _setCookies);
      final session = HongguoDeviceSession(http: stub);

      final profile = await session.profile();
      expect(stub.calls, hasLength(1));
      final request = stub.calls.single;
      expect(request.url.toString(), contains('device_register'));
      expect(request.headers.containsKey('x-gorgon'), isFalse); // the register is unsigned
      expect(request.bodyBytes!.sublist(0, 6), [0x74, 0x63, 0x05, 0x10, 0x00, 0x00]); // the envelope flew
      expect(profile.values['device_id'], '710000123456');
      expect(profile.values['iid'], '710000654321');
      expect(
        RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[0-9a-f]{4}-[0-9a-f]{12}$')
            .hasMatch(profile.values['cdid'] ?? ''),
        isTrue,
      );
      expect(profile.values['aid'], '8662'); // the vendor fingerprint rides along
      expect(profile.cookie, 'install_id=710000654321; ttreq=1'); // only the kept names

      await session.profile(); // the same session keeps its identity
      expect(stub.calls, hasLength(1));
    });

    test('the stored identity survives a restart, cookies and cdid with it', () async {
      final first = HongguoDeviceSession(http: _Stub(_answer(), setCookies: _setCookies));
      final before = await first.profile();
      await _settle(); // the write is fire-and-forget; let it land

      final second = HongguoDeviceSession(http: _Stub(_answer(), setCookies: _setCookies));
      final after = await second.profile();
      expect(after.values, before.values); // device_id, iid and the cdid all came from the store
      expect(after.cookie, before.cookie);
    });

    test('a stored identity unreadable registers anew', () async {
      await StoragePrefs.setString('hongguo.device.identity', 'not-json');
      final stub = _Stub(_answer(), setCookies: _setCookies);
      final session = HongguoDeviceSession(http: stub);

      final profile = await session.profile();
      expect(stub.calls, hasLength(1)); // the broken store read as none
      expect(profile.values['device_id'], '710000123456');
    });

    test('a refused service or a refused answer throws the device error', () async {
      final down = HongguoDeviceSession(http: _Stub('', status: 503));
      await expectLater(down.profile(), throwsA(_device('HTTP 503')));

      final empty = HongguoDeviceSession(http: _Stub(jsonEncode({'device_id_str': '0', 'install_id_str': '1'})));
      await expectLater(empty.profile(), throwsA(_device('播放设备注册失败')));
    });

    test('reset forgets the identity, and the next ask registers again', () async {
      final stub = _Stub(_answer(), setCookies: _setCookies);
      final session = HongguoDeviceSession(http: stub);
      await session.profile();
      await session.reset();

      await session.profile();
      expect(stub.calls, hasLength(2)); // the identity went with the reset
    });
  });
}

Matcher _device(String message) => isA<HongguoDeviceException>().having((error) => error.message, 'message', message);

/// The applog service the device's tests code against: one register answer,
/// its status and its cookies, with every ask remembered.
final class _Stub implements LiveHttp {
  _Stub(this.body, {this.setCookies = const [], this.status = 200});

  final String body;
  final List<String> setCookies;
  final int status;
  final calls = <LiveRequest>[];

  @override
  Future<LiveResponse> send(LiveRequest request) async {
    calls.add(request);
    return LiveResponse(
      statusCode: status,
      headers: const {},
      bodyBytes: Uint8List.fromList(utf8.encode(body)),
      setCookies: setCookies,
    );
  }

  @override
  Future<LiveStreamedResponse> open(LiveRequest request) => throw UnsupportedError('the register asks once');

  @override
  void close() {}
}
