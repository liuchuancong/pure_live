// The TV sign-in: passport.bilibili.com issues a QR, the app scans it, and the
// poll hands back an access token beside the site cookies. The token is what
// the app interface (gRPC) speaks; the web interface does not need it.
import 'dart:convert' show jsonDecode, utf8;
import 'dart:math' as math;

import 'package:crypto/crypto.dart' show md5;
import 'package:live_net/live_net.dart';

/// The app key pair the TV login signs with — the reference's own client.
const String _appKey = 'dfca71928277209b';
const String _appSecret = 'b5475a8825547a4fc26c7d518eaaa02e';
const String _tvLoginUa = 'Mozilla/5.0 BiliDroid/2.2.0 (bbcallen@gmail.com) os/android model/android_hd';

/// One issued QR: the URL the viewer scans and the code the poll names.
typedef TvLoginQr = ({String url, String authCode});

/// One poll's answer: `state` is the platform's own code (0 signed in, 86101
/// waiting for the scan, 86090 scanned and waiting for the phone's confirm,
/// 86038 expired).
typedef TvLoginPoll = ({int state, String message, TvLoginResult? result});

/// What a confirmed TV sign-in hands back.
final class TvLoginResult {
  /// Creates the result.
  // ignore: unnecessary_type_name_in_constructor
  const TvLoginResult({
    required this.mid,
    required this.accessToken,
    required this.refreshToken,
    required this.expiresIn,
    this.cookies = const {},
  });

  /// The account's uid.
  final int mid;

  /// The access token the app interface signs with.
  final String accessToken;

  /// The token that renews [accessToken] when it expires.
  final String refreshToken;

  /// How long [accessToken] lasts, in seconds.
  final int expiresIn;

  /// The cookies the sign-in granted, by name (SESSDATA, bili_jct…).
  final Map<String, String> cookies;

  /// The cookie line the web interface takes.
  String get cookieLine => cookies.entries.map((entry) => '${entry.key}=${entry.value}').join('; ');
}

/// Signs the TV login's form fields the way the app does: sorted, URL-encoded,
/// the app secret appended, MD5.
Map<String, String> _signedFields(Map<String, String> fields, {required int now}) {
  final values = <String, String>{...fields, 'appkey': _appKey, 'ts': '$now'};
  final sorted = values.keys.toList()..sort();
  final query = sorted.map((key) => '$key=${Uri.encodeQueryComponent(values[key]!)}').join('&');
  final sign = md5.convert(utf8.encode('$query$_appSecret')).toString();
  return {...values, 'sign': sign};
}

/// The TV sign-in over the shared transport.
final class BilibiliTvLogin {
  /// Creates the sign-in.
  // ignore: unnecessary_type_name_in_constructor
  const BilibiliTvLogin(this._http);

  final LiveHttp _http;

  /// A device id the platform accepts as this viewer's: a fresh random one is
  /// enough for a first sign-in, and the token is what later calls use.
  static String newDeviceId() {
    final random = math.Random.secure();
    const chars = '0123456789ABCDEF';
    return List.generate(32, (_) => chars[random.nextInt(chars.length)]).join();
  }

  /// Issues a QR for [deviceId].
  Future<TvLoginQr> requestQr({required String deviceId}) async {
    final body = _signedFields(
      {'local_id': deviceId, 'mobi_app': 'android_hd', 'platform': 'android'},
      now: DateTime.now().millisecondsSinceEpoch ~/ 1000,
    );
    final data = await _post('/x/passport-tv-login/qrcode/auth_code', body, what: 'qrcode/auth_code');
    final url = '${data['url'] ?? ''}'.trim();
    final authCode = '${data['auth_code'] ?? ''}'.trim();
    if (url.isEmpty || authCode.isEmpty) {
      throw const VodTvLoginFailure('登录二维码格式异常');
    }
    return (url: url, authCode: authCode);
  }

  /// Polls [authCode] once.
  Future<TvLoginPoll> poll({required String authCode, required String deviceId}) async {
    final body = _signedFields(
      {'auth_code': authCode, 'local_id': deviceId, 'mobi_app': 'android_hd', 'platform': 'android'},
      now: DateTime.now().millisecondsSinceEpoch ~/ 1000,
    );
    final data = await _post('/x/passport-tv-login/qrcode/poll', body, what: 'qrcode/poll', validateCode: false);
    final state = (data['code'] as num?)?.toInt() ?? -1;
    final message = '${data['message'] ?? ''}'.trim();
    if (state != 0) return (state: state, message: message, result: null);
    final token = '${data['access_token'] ?? ''}'.trim();
    final mid = (data['mid'] as num?)?.toInt() ?? 0;
    if (token.isEmpty) throw const VodTvLoginFailure('登录没有返回 access_key');
    final cookies = <String, String>{};
    final info = data['cookie_info'];
    final rows = info is Map ? info['cookies'] : null;
    if (rows is List) {
      for (final row in rows) {
        if (row is! Map) continue;
        final name = '${row['name'] ?? ''}'.trim();
        final value = '${row['value'] ?? ''}'.trim();
        if (name.isNotEmpty && value.isNotEmpty) cookies[name] = value;
      }
    }
    return (
      state: 0,
      message: message,
      result: TvLoginResult(
        mid: mid,
        accessToken: token,
        refreshToken: '${data['refresh_token'] ?? ''}',
        expiresIn: (data['expires_in'] as num?)?.toInt() ?? 0,
        cookies: cookies,
      ),
    );
  }

  Future<Map<String, Object?>> _post(String path, Map<String, String> body, {required String what, bool validateCode = true}) async {
    final response = await _http.send(
      LiveRequest.custom(
        method: 'POST',
        url: Uri.https('passport.bilibili.com', path),
        body: body.entries.map((entry) => '${entry.key}=${Uri.encodeQueryComponent(entry.value)}').join('&'),
        contentType: 'application/x-www-form-urlencoded',
        headers: const {'User-Agent': _tvLoginUa, 'Content-Type': 'application/x-www-form-urlencoded'},
        timeout: const Duration(seconds: 20),
      ),
    );
    if (!response.isOk) {
      throw VodTvLoginFailure('HTTP ${response.statusCode}');
    }
    final decoded = jsonDecode(response.text);
    if (decoded is! Map<String, Object?>) {
      throw const VodTvLoginFailure('登录响应格式异常');
    }
    final code = (decoded['code'] as num?)?.toInt() ?? -1;
    if (validateCode && code != 0) {
      throw VodTvLoginFailure('${decoded['message'] ?? '登录失败（$code）'}');
    }
    final data = decoded['data'];
    if (data is! Map<String, Object?>) {
      if (!validateCode) return <String, Object?>{'code': code, 'message': decoded['message']};
      throw const VodTvLoginFailure('登录响应为空');
    }
    return data;
  }

  /// The failure's words, for the dialog.
  String failureText(Object error) => error is VodTvLoginFailure ? error.message : '$error';
}

/// The TV sign-in could not answer.
final class VodTvLoginFailure implements Exception {
  /// Creates the failure.
  // ignore: unnecessary_type_name_in_constructor
  const VodTvLoginFailure(this.message);

  /// One line on what went wrong.
  final String message;

  @override
  String toString() => message;
}
