// Module: test/douyu_sign_test.dart
// Purpose: Pin the descriptor rules and the md5 chain the play request is built from.
// Author: liuchuancong
// Created: 2026-10-10
import 'dart:math';

import 'package:pure_live_douyu/pure_live_douyu.dart';
import 'package:pure_live_network/pure_live_network.dart';
import 'package:pure_live_utils/pure_live_utils.dart';
import 'package:test/test.dart';

import 'support/canned_http.dart';

/// The v1 chain, recomputed independently for these inputs, so a change here is a change against Douyu rather
/// than against this file.
const String _authForRoom123 = 'a6e3764d07fafff6d72003bf2430e9d0';
const String _authForSpecial = 'd1a9c0a9e6151c1a53cb832f680ec804';

DouyuEncryptionDescriptor _descriptor({
  int encTime = 3,
  int expireAt = 2000000000,
  bool isSpecial = false,
  String? key,
  String? randStr,
  String? encData,
}) => DouyuEncryptionDescriptor(
  key: key ?? 'k3y',
  randStr: randStr ?? 'rnd',
  encData: encData ?? 'EDATA',
  encTime: encTime,
  expireAt: expireAt,
  isSpecial: isSpecial,
);

void main() {
  group('douyuSignedForm', () {
    test('test_signedForm_reproducesTheServerChain', () {
      final form = douyuSignedForm(
        descriptor: _descriptor(),
        roomId: '123',
        timestampSeconds: 1700000000,
        deviceId: 'did',
      );

      expect(
        form,
        // `cdn` carries no `=` because Uri renders an empty value that way, and that is the body the v1 line
        // has been sending with Uri all along: the endpoint accepts it.
        'enc_data=EDATA&tt=1700000000&did=did&auth=$_authForRoom123'
        '&cdn&rate=-1&hevc=0&fa=0&ive=0&ver=Douyu_new&iar=0',
      );
    });

    test('test_signedForm_specialDescriptor_dropsTheRoomSalt', () {
      final form = douyuSignedForm(
        descriptor: _descriptor(isSpecial: true),
        roomId: '123',
        timestampSeconds: 1700000000,
        deviceId: 'did',
      );

      expect(form, contains('auth=$_authForSpecial'));
    });

    test('test_signedForm_expiredDescriptor_refusesToSign', () {
      expect(
        () => douyuSignedForm(
          descriptor: _descriptor(expireAt: 1000),
          roomId: '123',
          timestampSeconds: 1700000000,
          deviceId: 'did',
        ),
        throwsStateError,
      );
    });

    test('test_signedForm_roundCountIsWhatTheDescriptorStates', () {
      // One round and three rounds cannot produce the same auth; a hard-coded round count would have been the
      // first thing to break when the server changed it.
      final one = douyuSignedForm(
        descriptor: _descriptor(encTime: 1),
        roomId: '123',
        timestampSeconds: 1700000000,
        deviceId: 'did',
      );
      final three = douyuSignedForm(
        descriptor: _descriptor(encTime: 3),
        roomId: '123',
        timestampSeconds: 1700000000,
        deviceId: 'did',
      );

      expect(one, isNot(equals(three)));
      expect(three, contains('auth=$_authForRoom123'));
    });
  });

  group('DouyuEncryptionDescriptor', () {
    test('test_fromJson_missingField_namesIt', () {
      expect(
        () => DouyuEncryptionDescriptor.fromJson(<String, Object?>{'key': 'k', 'enc_data': 'd'}),
        throwsA(isA<FormatException>().having((error) => error.message, 'message', contains('rand_str'))),
      );
    });

    test('test_isUsable_refusesADeadlineInsideTheSafetyWindow', () {
      final descriptor = _descriptor(expireAt: 1000 + kDouyuDescriptorSafetySeconds - 1);

      expect(descriptor.isUsable(nowSeconds: 1000), isFalse);
      // Past the window the same descriptor is fine: the safety margin is about the request still being valid
      // when the player opens it, not about the number itself.
      expect(descriptor.isUsable(nowSeconds: 1000, safetySeconds: 0), isTrue);
    });

    test('test_isUsable_refusesAnAbsurdRoundCount', () {
      expect(_descriptor(encTime: 0).isUsable(nowSeconds: 1000), isFalse);
      expect(_descriptor(encTime: kDouyuMaxEncryptionRounds + 1).isUsable(nowSeconds: 1000), isFalse);
      expect(_descriptor(encTime: kDouyuMaxEncryptionRounds).isUsable(nowSeconds: 1000), isTrue);
    });
  });

  group('DouyuDevice', () {
    test('test_device_cookieAndQueryCarryTheSameDid', () {
      final device = DouyuDevice(deviceId: 'abc');

      expect(device.cookieHeader, 'dy_did=abc; acf_did=abc');
      expect(device.headers(roomId: '123'), <String, String>{
        'accept': 'application/json, text/plain, */*',
        'accept-language': 'zh-CN,zh;q=0.9,en;q=0.7',
        'origin': 'https://www.douyu.com',
        'referer': 'https://www.douyu.com/123',
        'user-agent': douyuUserAgent,
        'cookie': 'dy_did=abc; acf_did=abc',
      });
    });

    test('test_deviceId_generatedIsThirtyTwoHexCharacters', () {
      final device = DouyuDevice(random: Random(7));

      expect(device.deviceId, matches(RegExp(r'^[0-9a-f]{32}$')));
    });

    test('test_deviceId_blankInputIsReplacedNotPassedThrough', () {
      // A blank DID is what an unset stored cookie decodes to, and Douyu answers a plain 403 for it.
      expect(DouyuDevice(deviceId: '').deviceId, isNotEmpty);
    });
  });

  group('DouyuSigner caching', () {
    test('test_sign_secondCallReusesTheDescriptorWithinItsAge', () async {
      final now = DateTime.utc(2026, 10, 10, 12);
      final nowSeconds = now.millisecondsSinceEpoch ~/ 1000;
      final adapter = CannedHttp(<String, String>{
        kDouyuEncryptionEndpoint:
            '{"data":{"key":"k3y","rand_str":"rnd","enc_time":3,"enc_data":"EDATA",'
            '"expire_at":${nowSeconds + 600},"is_special":0}}',
      });
      final signer = DouyuSigner(
        client: NetworkClient(adapter: adapter),
        device: DouyuDevice(deviceId: 'did'),
        clock: FixedClock(now).call,
      );

      await signer.sign('123');
      await signer.sign('456');

      expect(adapter.callsMatching(kDouyuEncryptionEndpoint), 1);
    });

    test('test_sign_forcedRefreshFetchesAgain', () async {
      final now = DateTime.utc(2026, 10, 10, 12);
      final adapter = CannedHttp(<String, String>{
        kDouyuEncryptionEndpoint:
            '{"data":{"key":"k3y","rand_str":"rnd","enc_time":3,"enc_data":"EDATA",'
            '"expire_at":${now.millisecondsSinceEpoch ~/ 1000 + 600},"is_special":0}}',
      });
      final signer = DouyuSigner(
        client: NetworkClient(adapter: adapter),
        device: DouyuDevice(deviceId: 'did'),
        clock: FixedClock(now).call,
      );

      await signer.sign('123');
      await signer.sign('123', forceRefresh: true);

      expect(adapter.callsMatching(kDouyuEncryptionEndpoint), 2);
    });

    test('test_sign_descriptorWithoutData_failsByName', () async {
      final adapter = CannedHttp(<String, String>{kDouyuEncryptionEndpoint: '{"error":1}'});
      final signer = DouyuSigner(
        client: NetworkClient(adapter: adapter),
        device: DouyuDevice(deviceId: 'did'),
        clock: FixedClock(DateTime.utc(2026)).call,
      );

      await expectLater(signer.sign('123'), throwsA(isA<FormatException>()));
    });
  });
}
