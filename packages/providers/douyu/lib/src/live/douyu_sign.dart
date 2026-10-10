// Module: lib/src/live/douyu_sign.dart
// Purpose: Douyu's websec encryption descriptor and the signed play form built from it.
// Author: liuchuancong
// Created: 2026-10-10
//
// Provenance: the endpoint, the descriptor fields and the md5 chain follow the v1-maintained Douyu line
// (origin/master lib/core/network/douyu_utils.dart). This is a fresh implementation against the v2
// capability contracts, not a merge (UPSTREAM_REVIEW_POLICY.md). Deliberately smaller than the v1 line for
// this first slice: no pasted login cookie, no passport/JWT renewal, no quality or line picking - an
// anonymous viewer only, which is what the feed-to-room chain needs to be real end to end.

import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:pure_live_network/pure_live_network.dart';
import 'package:pure_live_utils/pure_live_utils.dart';

import '../models/douyu_row.dart';

/// The desktop Chrome user agent the web endpoints answer to without a login.
const String douyuUserAgent =
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) '
    'Chrome/128.0.0.0 Safari/537.36';

/// Where the signing material comes from.
const String kDouyuEncryptionEndpoint = 'https://www.douyu.com/wgapi/livenc/liveweb/websec/getEncryption';

/// A descriptor is refused this close to its own expiry: signing with one that dies mid-request hands the
/// player a url that stops before the stream is opened.
const int kDouyuDescriptorSafetySeconds = 30;

/// How long one descriptor may be reused regardless of what it claims about its own expiry.
const int kDouyuDescriptorMaxAgeSeconds = 5 * 60;

/// `enc_time` is a round count the server chooses; v1 refused anything outside 1..16 rather than loop an
/// unbounded number of times on a hostile answer.
const int kDouyuMaxEncryptionRounds = 16;

/// The device a descriptor is issued to.
///
/// Douyu validates the signed request against the same device the descriptor was handed to, and a mismatch is
/// answered with a plain 403 from its edge - no API error to name - so the id has to reach the descriptor
/// query, the form field and the cookie from one place.
final class DouyuDevice {
  DouyuDevice({String? deviceId, Random? random})
    : deviceId = (deviceId == null || deviceId.isEmpty) ? generateDouyuDeviceId(random ?? Random.secure()) : deviceId;

  final String deviceId;

  /// The two cookie fields Douyu reads the device from; an anonymous session has nothing else to send.
  String get cookieHeader => 'dy_did=$deviceId; acf_did=$deviceId';

  Map<String, String> headers({String roomId = ''}) => <String, String>{
    'accept': 'application/json, text/plain, */*',
    'accept-language': 'zh-CN,zh;q=0.9,en;q=0.7',
    'origin': 'https://www.douyu.com',
    'referer': roomId.isEmpty ? 'https://www.douyu.com/' : 'https://www.douyu.com/$roomId',
    'user-agent': douyuUserAgent,
    'cookie': cookieHeader,
  };
}

/// A 32-character hex device id, the shape the web client generates per session.
String generateDouyuDeviceId(Random random) =>
    List<String>.generate(32, (_) => random.nextInt(16).toRadixString(16)).join();

/// The server-side signing material for one device.
final class DouyuEncryptionDescriptor {
  const DouyuEncryptionDescriptor({
    required this.key,
    required this.randStr,
    required this.encData,
    required this.encTime,
    required this.expireAt,
    required this.isSpecial,
  });

  factory DouyuEncryptionDescriptor.fromJson(Map<String, Object?> json) {
    final missing = <String>[
      for (final field in const <String>['key', 'rand_str', 'enc_data'])
        if ('${json[field] ?? ''}'.trim().isEmpty) field,
    ];
    if (missing.isNotEmpty) {
      throw FormatException('Douyu encryption descriptor is missing ${missing.join(', ')}');
    }
    return DouyuEncryptionDescriptor(
      key: '${json['key']}',
      randStr: '${json['rand_str']}',
      encData: '${json['enc_data']}',
      encTime: douyuInt(json['enc_time']),
      expireAt: douyuInt(json['expire_at']),
      isSpecial: douyuInt(json['is_special']) == 1,
    );
  }

  final String key;
  final String randStr;
  final String encData;

  /// md5 rounds to run. Server-chosen, not a local constant.
  final int encTime;

  /// Absolute unix seconds, not a lifetime.
  final int expireAt;

  /// The descriptor family that omits the room+timestamp salt.
  final bool isSpecial;

  bool isUsable({required int nowSeconds, int safetySeconds = kDouyuDescriptorSafetySeconds}) =>
      expireAt > nowSeconds + safetySeconds &&
      encTime > 0 &&
      encTime <= kDouyuMaxEncryptionRounds &&
      key.isNotEmpty &&
      randStr.isNotEmpty &&
      encData.isNotEmpty;
}

/// The form body one play request is made of, in the order the web client sends it.
///
/// The chain is the server's, not a local convention: `enc_time` md5 rounds over `rand_str` and `key`, then a
/// final round with the salt, which is the room id plus the timestamp except for [isSpecial] descriptors.
/// Re-ordering the concatenation yields an `auth` the API answers `error != 0` for, with no reason given.
String douyuSignedForm({
  required DouyuEncryptionDescriptor descriptor,
  required String roomId,
  required int timestampSeconds,
  required String deviceId,
  int rate = -1,
  String cdn = '',
}) {
  if (!descriptor.isUsable(nowSeconds: timestampSeconds, safetySeconds: 0)) {
    throw StateError('Douyu encryption descriptor is expired or incomplete');
  }
  var secret = descriptor.randStr;
  for (var round = 0; round < descriptor.encTime; round++) {
    secret = md5.convert(utf8.encode('$secret${descriptor.key}')).toString();
  }
  final salt = descriptor.isSpecial ? '' : '$roomId$timestampSeconds';
  final auth = md5.convert(utf8.encode('$secret${descriptor.key}$salt')).toString();
  return Uri(
    queryParameters: <String, String>{
      'enc_data': descriptor.encData,
      'tt': '$timestampSeconds',
      'did': deviceId,
      'auth': auth,
      'cdn': cdn,
      'rate': '$rate',
      'hevc': '0',
      'fa': '0',
      'ive': '0',
      'ver': 'Douyu_new',
      'iar': '0',
    },
  ).query;
}

/// Fetches and caches the descriptor, then answers signed forms.
final class DouyuSigner {
  DouyuSigner({required this.client, required this.device, Clock? clock}) : _clock = clock ?? systemClock;

  final NetworkClient client;
  final DouyuDevice device;
  final Clock _clock;

  DouyuEncryptionDescriptor? _cached;
  int? _fetchedAtSeconds;

  /// The refresh in flight, so two rooms opening at once share one descriptor fetch instead of asking twice
  /// for a document the edge issues per device.
  Future<DouyuEncryptionDescriptor>? _refresh;

  Future<String> sign(String roomId, {int rate = -1, String cdn = '', bool forceRefresh = false}) async {
    final descriptor = await _descriptorFor(forceRefresh: forceRefresh);
    return douyuSignedForm(
      descriptor: descriptor,
      roomId: roomId,
      timestampSeconds: _nowSeconds(),
      deviceId: device.deviceId,
      rate: rate,
      cdn: cdn,
    );
  }

  Future<DouyuEncryptionDescriptor> _descriptorFor({bool forceRefresh = false}) async {
    final now = _nowSeconds();
    final cached = _cached;
    final fetchedAt = _fetchedAtSeconds;
    if (!forceRefresh &&
        cached != null &&
        fetchedAt != null &&
        now - fetchedAt < kDouyuDescriptorMaxAgeSeconds &&
        cached.isUsable(nowSeconds: now)) {
      return cached;
    }
    final running = _refresh;
    // A caller that asks for a forced refresh must not be served the in-flight one it is trying to replace.
    if (!forceRefresh && running != null) {
      return running;
    }
    final refresh = _fetch();
    _refresh = refresh;
    try {
      return await refresh;
    } finally {
      if (identical(_refresh, refresh)) {
        _refresh = null;
      }
    }
  }

  Future<DouyuEncryptionDescriptor> _fetch() async {
    final json = await client.getJson(
      kDouyuEncryptionEndpoint,
      queryParameters: <String, dynamic>{'did': device.deviceId},
      headers: device.headers(),
    );
    final data = json['data'];
    if (data is! Map) {
      throw const FormatException('Douyu encryption response carries no data object');
    }
    final descriptor = DouyuEncryptionDescriptor.fromJson(Map<String, Object?>.from(data));
    final now = _nowSeconds();
    if (!descriptor.isUsable(nowSeconds: now)) {
      throw const FormatException('Douyu encryption descriptor is incomplete or expired');
    }
    _cached = descriptor;
    _fetchedAtSeconds = now;
    return descriptor;
  }

  int _nowSeconds() => _clock().millisecondsSinceEpoch ~/ 1000;
}
