// Dart port of hongguoTV's DeviceRegister + PlaybackDeviceSession
// (kotlin-tv/core), adapted from charlie901208/HGTV; GPL-3.0-only.
//
// The platform's content endpoints admit a device the applog service has
// registered — anonymous, no account, no signing on the register request
// itself (a signed register reads as a broken client and is refused).
import 'dart:async' show unawaited;
import 'dart:convert' show jsonDecode, jsonEncode, utf8;
import 'dart:io' show gzip;
import 'dart:math' as math;
import 'dart:typed_data' show Uint8List;

import 'package:crypto/crypto.dart' as crypto;
import 'package:live_net/live_net.dart' show LiveHttp, LiveRequest;
import 'package:live_storage/live_storage.dart' show StoragePrefs;

import 'package:pure_live/modules/hongguo/official/hongguo_media_crypto.dart' show HongguoMediaCrypto;
import 'package:pure_live/modules/hongguo/official/hongguo_signer.dart' show hongguoAesCbc;
import 'package:pure_live/modules/hongguo/official/hongguo_vendor.dart' show HongguoVendor;

/// What the applog service handed back: the device identity the content
/// endpoints want, plus the cookies the player API's request carries.
final class HongguoRegistered {
  /// Creates the registration.
  const HongguoRegistered({
    required this.deviceId,
    required this.installId,
    this.deviceToken = '',
    this.newUser = false,
    this.cookies = const {},
  });

  /// The platform's device id.
  final String deviceId;

  /// The platform's install id.
  final String installId;

  /// The device token, when one was issued.
  final String deviceToken;

  /// Whether the platform created a new device this time.
  final bool newUser;

  /// The cookies worth sending back (`install_id`, `ttreq`, `store-region`…).
  final Map<String, String> cookies;
}

/// ttEncrypt: `magic || rnd[32] || AES-128-CBC(derived, PKCS7(sha512(data)
/// || data))`, the `libEncryptor.so` envelope.
Uint8List _ttEncrypt(Uint8List data) {
  final rnd = Uint8List(32);
  final random = math.Random.secure();
  for (var i = 0; i < rnd.length; i++) {
    rnd[i] = random.nextInt(256);
  }
  final derived = crypto.sha512.convert([...crypto.sha512.convert(rnd).bytes, ...HongguoMediaCrypto.kdfSalt]).bytes;
  final body = Uint8List.fromList([...crypto.sha512.convert(data).bytes, ...data]);
  final padding = 16 - body.length % 16;
  final padded = Uint8List.fromList([...body, ...List.filled(padding, padding)]);
  final encrypted = hongguoAesCbc(
    Uint8List.fromList(derived.sublist(0, 16)),
    Uint8List.fromList(derived.sublist(16, 32)),
    padded,
    decrypt: false,
  );
  return Uint8List.fromList([
    0x74, 0x63, 0x05, 0x10, 0x00, 0x00,
    ...rnd,
    ...encrypted,
  ]);
}

String _hexOf(List<int> bytes) => bytes.map((b) => (b & 0xFF).toRadixString(16).padLeft(2, '0')).join();

String _uuid() {
  final random = math.Random.secure();
  const chars = '0123456789abcdef';
  final out = List<String>.generate(36, (i) {
    if (i == 8 || i == 13 || i == 18 || i == 23) return '-';
    if (i == 14) return '4';
    return chars[random.nextInt(16)];
  });
  return out.join();
}

/// Builds the register request body: `ttEncrypt(gzip(json))`, the fields
/// matched to the capture field for field.
Uint8List hongguoDevicePayload(Map<String, String> device, {int? now}) {
  final time = now ?? DateTime.now().millisecondsSinceEpoch;
  String value(String key, String fallback) {
    final stored = device[key];
    return stored == null || stored.trim().isEmpty ? fallback : stored;
  }

  final header = <String, Object?>{
    'display_name': '红果免费短剧',
    'update_version_code': 73932,
    'manifest_version_code': 73932,
    'app_version_minor': '7.3.9.32',
    'aid': 8662,
    'channel': value('channel', '69310258a'),
    'package': 'com.phoenix.read',
    'app_version': '7.3.9.32',
    'version_code': 73932,
    'sdk_version': '3.7.0-rc.34-fanqie-xiaoshuo',
    'sdk_target_version': 29,
    'git_hash': '3a88f4e',
    'os': 'Android',
    'os_version': value('os_version', '12'),
    'os_api': int.tryParse(value('os_api', '32')) ?? 32,
    'device_model': value('device_type', 'AOSP on Intel Platform'),
    'device_brand': value('device_brand', 'SAMSUNG'),
    'device_manufacturer': value('device_brand', 'Intel'),
    'cpu_abi': value('host_abi', 'arm64-v8a'),
    'release_build': 'b5e187f',
    'density_dpi': int.tryParse(value('dpi', '360')) ?? 360,
    'display_density': 'mdpi',
    'resolution': value('resolution', '1440x2560').replaceAll('*', 'x'),
    'language': 'zh',
    'timezone': 8,
    'access': 'wifi',
    'not_request_sender': 0,
    'carrier': 'CHINA MOBILE',
    'mcc_mnc': '46000',
    'rom': 'eng.root.20231116.160340',
    'rom_version': value('rom_version', 'W528JS release-keys'),
    'cdid': value('cdid', _uuid()),
    'sig_hash': '56a962410c494bbaf0b58dba20cae56f',
    'openudid': value('openudid', _uuid().replaceAll('-', '').substring(0, 16)),
    'clientudid': _uuid(),
    'ipv6_list': <Object?>[],
    'region': 'CN',
    'tz_name': 'Asia/Shanghai',
    'tz_offset': 28800,
    'sim_region': 'cn',
    'sim_serial_number': <Object?>[],
    'oaid_may_support': false,
    'req_id': _uuid(),
    'device_platform': 'android',
    'custom': {'account_region_src': 'fallback', 'host_bit': 64, 'account_region': 'cn', 'dragon_device_type': value('dragon_device_type', 'pad')},
    'pre_installed_channel': '',
    'apk_first_install_time': time,
    'is_system_app': 0,
    'sdk_flavor': 'china',
    'guest_mode': 0,
  };
  final json = jsonEncode({'magic_tag': 'ss_app_log', 'header': header, '_gen_time': time});
  return _ttEncrypt(Uint8List.fromList(gzip.encode(utf8.encode(json))));
}

/// The register request's headers — deliberately unsigned.
Map<String, String> hongguoDeviceHeaders(Uint8List body, Map<String, String> device, {int? now}) {
  final time = now ?? DateTime.now().millisecondsSinceEpoch;
  return {
    'User-Agent': HongguoVendor.appUa,
    'Content-Type': 'application/octet-stream;tt-data=a',
    'log-encode-type': 'gzip',
    'x-ss-dp': '8662',
    'x-ss-req-ticket': '$time',
    'x-vc-bdturing-sdk-version': '4.0.3.cn',
    'lc': '101',
    'sdk-version': '2',
    'passport-sdk-version': '5051452',
    'x-neptune': '-8|50:51:59:30:40:47:49:39',
    'x-ss-stub': _hexOf(crypto.md5.convert(body).bytes).toUpperCase(),
  };
}

/// The register endpoint's address.
const String hongguoDeviceRegisterUrl =
    'https://log5-applog-lf.fqnovel.com/service/2/device_register/'
    '?tt_data=a&cronet_version=8d40f833_2026-03-03&ttnet_version=4.2.243.31-douyin&use_store_region_cookie=1';

/// Parses the register answer; null when the service refused.
HongguoRegistered? hongguoParseRegistered(String body, List<String> setCookies) {
  Object? decoded;
  try {
    decoded = jsonDecode(body);
  } on Object {
    return null;
  }
  if (decoded is! Map<String, Object?>) return null;
  final json = decoded;
  String pick(String key) {
    final value = json[key];
    if (value is String && value.trim().isNotEmpty) return value;
    if (value is num) return value.toString();
    return '';
  }

  final device = pick('device_id_str').isNotEmpty ? pick('device_id_str') : pick('device_id');
  final install = pick('install_id_str').isNotEmpty ? pick('install_id_str') : pick('install_id');
  if (device.isEmpty || install.isEmpty || device == '0' || install == '0') return null;
  final cookies = <String, String>{};
  for (final header in setCookies) {
    final pair = header.split(';').first.trim();
    final at = pair.indexOf('=');
    if (at <= 0) continue;
    final name = pair.substring(0, at).trim();
    final value = pair.substring(at + 1).trim();
    if (name.isNotEmpty && value.isNotEmpty) cookies[name] = value;
  }
  return HongguoRegistered(
    deviceId: device,
    installId: install,
    deviceToken: pick('device_token'),
    newUser: decoded['new_user'] == 1 || decoded['new_user'] == true,
    cookies: cookies,
  );
}

const String _kStoreKey = 'hongguo.device.identity';

/// The playback identity: register once (anonymously), keep the same
/// identity for the process and across restarts, and answer the query
/// values + cookie the player API's request carries.
final class HongguoDeviceSession {
  /// Creates the session over [_http].
  HongguoDeviceSession({required this._http});

  final LiveHttp _http;
  ({Map<String, String> values, String cookie})? _profile;

  /// The query values and cookie a playback request signs with, registering
  /// (or re-reading the stored registration) when there is no profile yet.
  Future<({Map<String, String> values, String cookie})> profile() async {
    final cached = _profile;
    if (cached != null) return cached;
    final stored = _readStored();
    if (stored != null) {
      return _profile = _profileOf(stored);
    }
    final body = hongguoDevicePayload(HongguoVendor.device);
    final response = await _http.send(
      LiveRequest.custom(
        method: 'POST',
        url: Uri.parse(hongguoDeviceRegisterUrl),
        bodyBytes: body,
        headers: hongguoDeviceHeaders(body, HongguoVendor.device),
        timeout: const Duration(seconds: 20),
      ),
    );
    if (!response.isOk) {
      throw HongguoDeviceException('HTTP ${response.statusCode}');
    }
    final registered = hongguoParseRegistered(response.text, response.setCookies);
    if (registered == null || !RegExp(r'^[1-9][0-9]{0,29}$').hasMatch(registered.deviceId) || !RegExp(r'^[1-9][0-9]{0,29}$').hasMatch(registered.installId)) {
      throw const HongguoDeviceException('播放设备注册失败');
    }
    final identity = _Identity(
      deviceId: registered.deviceId,
      installId: registered.installId,
      cdid: _uuid(),
      cookies: registered.cookies,
    );
    _writeStored(identity);
    return _profile = _profileOf(identity);
  }

  ({Map<String, String> values, String cookie}) _profileOf(_Identity identity) {
    final keep = {'install_id', 'ttreq', 'store-region', 'store-region-src'};
    return (
      values: {
        ...HongguoVendor.device,
        'device_id': identity.deviceId,
        'iid': identity.installId,
        'cdid': identity.cdid,
      },
      cookie: identity.cookies.entries
          .where((entry) => keep.contains(entry.key))
          .map((entry) => '${entry.key}=${entry.value}')
          .join('; '),
    );
  }

  /// Forgets the stored identity so the next playback registers a new one.
  Future<void> reset() async {
    _profile = null;
    try {
      await StoragePrefs.remove(_kStoreKey);
    } on Object {
      // A closed store keeps the old identity; the next register overwrites.
    }
  }

  static _Identity? _readStored() {
    try {
      final raw = StoragePrefs.getString(_kStoreKey);
      if (raw == null || raw.isEmpty) return null;
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, Object?>) return null;
      final deviceId = decoded['deviceId'];
      final installId = decoded['installId'];
      final cdid = decoded['cdid'];
      if (deviceId is! String || installId is! String || cdid is! String) return null;
      if (!RegExp(r'^[1-9][0-9]{0,29}$').hasMatch(deviceId) || !RegExp(r'^[1-9][0-9]{0,29}$').hasMatch(installId)) {
        return null;
      }
      final cookies = <String, String>{};
      final rawCookies = decoded['cookies'];
      if (rawCookies is Map<String, Object?>) {
        for (final entry in rawCookies.entries) {
          if (entry.value is String) cookies[entry.key] = entry.value! as String;
        }
      }
      return _Identity(deviceId: deviceId, installId: installId, cdid: cdid, cookies: cookies);
    } on Object {
      return null;
    }
  }

  static void _writeStored(_Identity identity) {
    try {
      unawaited(StoragePrefs.setString(
        _kStoreKey,
        jsonEncode({
          'deviceId': identity.deviceId,
          'installId': identity.installId,
          'cdid': identity.cdid,
          'cookies': identity.cookies,
        }),
      ));
    } on Object {
      // A closed store loses the identity; the next start registers again.
    }
  }
}

final class _Identity {
  const _Identity({required this.deviceId, required this.installId, required this.cdid, required this.cookies});

  final String deviceId;
  final String installId;
  final String cdid;
  final Map<String, String> cookies;
}

/// The playback identity could not be established.
final class HongguoDeviceException implements Exception {
  /// Creates the failure.
  const HongguoDeviceException(this.message);

  /// One line on what went wrong.
  final String message;

  @override
  String toString() => message;
}
