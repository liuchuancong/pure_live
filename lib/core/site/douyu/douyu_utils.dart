import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:pure_live/core/common/http_client.dart';

class DouyuUtils {
  static const String defaultDeviceId = '10000000000000000000000000001501';
  static const String _apiDouyuEnc =
      'https://www.douyu.com/wgapi/livenc/liveweb/websec/getEncryption';
  static const int _expirySafetySeconds = 30;
  static const int _maximumCacheAgeSeconds = 5 * 60;
  static const String userAgent =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) '
      'AppleWebKit/537.36 (KHTML, like Gecko) '
      'Chrome/128.0.0.0 Safari/537.36';

  static Map<String, dynamic> _encKey = <String, dynamic>{};
  static Future<void>? _encKeyRefresh;
  static int? _encKeyFetchedAtSeconds;
  static final String _sessionDeviceId = generateDeviceId();

  static String get deviceId => _sessionDeviceId;

  static int _nowSeconds() => DateTime.now().millisecondsSinceEpoch ~/ 1000;

  /// Validates the server encryption descriptor using second-based Unix time.
  static bool isEncryptionKeyUsable(
    Map<String, dynamic> value, {
    required int nowSeconds,
    int safetySeconds = _expirySafetySeconds,
  }) {
    final expiresAt = _asInt(value['expire_at']);
    final encTime = _asInt(value['enc_time']);
    return expiresAt != null &&
        expiresAt > nowSeconds + safetySeconds &&
        encTime != null &&
        encTime > 0 &&
        encTime <= 16 &&
        _nonEmpty(value['key']) &&
        _nonEmpty(value['rand_str']) &&
        _nonEmpty(value['enc_data']);
  }

  static bool _isCachedEncryptionKeyUsable(int nowSeconds) {
    final fetchedAt = _encKeyFetchedAtSeconds;
    return fetchedAt != null &&
        nowSeconds - fetchedAt < _maximumCacheAgeSeconds &&
        isEncryptionKeyUsable(_encKey, nowSeconds: nowSeconds);
  }

  static Future<void> _encKeyUpdate({bool forceRefresh = false}) async {
    final nowSeconds = _nowSeconds();
    if (!forceRefresh && _isCachedEncryptionKeyUsable(nowSeconds)) return;

    final activeRefresh = _encKeyRefresh;
    if (activeRefresh != null) {
      await activeRefresh;
      if (_isCachedEncryptionKeyUsable(_nowSeconds())) return;
    }

    final refresh = _fetchEncryptionKey();
    _encKeyRefresh = refresh;
    try {
      await refresh;
    } finally {
      if (identical(_encKeyRefresh, refresh)) _encKeyRefresh = null;
    }
  }

  static Future<void> _fetchEncryptionKey() async {
    final response = await HttpClient.instance.getJson(
      _apiDouyuEnc,
      queryParameters: {'did': deviceId},
      header: requestHeaders(),
    );
    final rawData = response is Map ? response['data'] : null;
    if (rawData is! Map) {
      throw const FormatException('Douyu encryption response is missing data');
    }
    final data = Map<String, dynamic>.from(rawData);
    if (!isEncryptionKeyUsable(data, nowSeconds: _nowSeconds())) {
      throw const FormatException('Douyu encryption descriptor is incomplete or expired');
    }
    _encKey = data;
    _encKeyFetchedAtSeconds = _nowSeconds();
  }

  /// Creates the browser DID used by a single app process.
  static String generateDeviceId({Random? random}) {
    final source = random ?? Random.secure();
    return List<String>.generate(32, (_) => source.nextInt(16).toRadixString(16)).join();
  }

  static Map<String, String> requestHeaders([String roomId = '']) {
    final referer = roomId.isEmpty ? 'https://www.douyu.com/' : 'https://www.douyu.com/$roomId';
    return <String, String>{
      'accept': 'application/json, text/plain, */*',
      'accept-language': 'zh-CN,zh;q=0.9,en;q=0.7',
      'origin': 'https://www.douyu.com',
      'referer': referer,
      'user-agent': userAgent,
      'cookie': 'dy_did=$deviceId; acf_did=$deviceId',
    };
  }

  static Map<String, String> playbackHeaders(String roomId) => <String, String>{
    'origin': 'https://www.douyu.com',
    'referer': 'https://www.douyu.com/$roomId',
    'user-agent': userAgent,
    'cookie': 'dy_did=$deviceId; acf_did=$deviceId',
  };

  /// Builds the form body from an already validated encryption descriptor.
  /// Exposed as a deterministic unit-test seam for the platform signing path.
  static String buildSignedData({
    required Map<String, dynamic> encryptionKey,
    required String roomId,
    required int timestampSeconds,
    int rate = -1,
    String cdn = '',
    String deviceId = defaultDeviceId,
  }) {
    if (!isEncryptionKeyUsable(encryptionKey, nowSeconds: timestampSeconds, safetySeconds: 0)) {
      throw const FormatException('Douyu encryption descriptor is incomplete or expired');
    }
    final key = encryptionKey['key'].toString();
    final randStr = encryptionKey['rand_str'].toString();
    final encTime = _asInt(encryptionKey['enc_time'])!;
    final salt = _asInt(encryptionKey['is_special']) == 1 ? '' : '$roomId$timestampSeconds';

    var secret = randStr;
    for (var index = 0; index < encTime; index++) {
      secret = md5.convert(utf8.encode('$secret$key')).toString();
    }
    final auth = md5.convert(utf8.encode('$secret$key$salt')).toString();
    return Uri(
      queryParameters: <String, String>{
        'enc_data': encryptionKey['enc_data'].toString(),
        'tt': timestampSeconds.toString(),
        'did': deviceId,
        'auth': auth,
        'cdn': cdn,
        'rate': rate.toString(),
        'hevc': '0',
        'fa': '0',
        'ive': '0',
        'ver': 'Douyu_new',
        'iar': '0',
      },
    ).query;
  }

  static Future<String> sign(
    String roomId, {
    int rate = -1,
    String cdn = '',
    bool forceRefresh = false,
  }) async {
    await _encKeyUpdate(forceRefresh: forceRefresh);
    return buildSignedData(
      encryptionKey: _encKey,
      roomId: roomId,
      timestampSeconds: _nowSeconds(),
      rate: rate,
      cdn: cdn,
      deviceId: deviceId,
    );
  }

  static int? _asInt(dynamic value) {
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '');
  }

  static bool _nonEmpty(dynamic value) => value?.toString().trim().isNotEmpty == true;
}
