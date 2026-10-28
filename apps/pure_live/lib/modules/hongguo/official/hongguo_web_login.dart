// Dart port of hongguoTV's WebLogin (kotlin-tv/core); GPL-3.0-only.
// One official-website login session: the QR code the phone app scans, the
// poll that waits for the confirmation, and the redirect chain that settles
// the session cookie — its CSRF cookies surviving across the three steps.
// A dedicated dart:io client: redirects are followed by hand so every
// Set-Cookie on the chain is kept.
import 'dart:convert' show base64Decode, jsonDecode, utf8;
import 'dart:io' show HttpClient, HttpClientResponse, HttpHeaders;
import 'dart:typed_data' show Uint8List;

const String _kBase = 'https://hongguoduanju.com';
const String _kLoginUa =
    'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/141.0.0.0 Safari/537.36';

final class _LoginCookie {
  const _LoginCookie(this.name, this.value, this.expiresAt);

  final String name;
  final String value;
  final int expiresAt;

  bool get alive => expiresAt <= 0 || expiresAt * 1000 > DateTime.now().millisecondsSinceEpoch;
}

/// The QR code to show, and how long it stays valid.
final class HongguoQrCode {
  /// Creates the code.
  const HongguoQrCode({required this.image, required this.expiresIn});

  /// The code's PNG bytes.
  final Uint8List image;

  /// Seconds until the code expires.
  final int expiresIn;
}

/// One website login session; one instance per QR code shown.
final class HongguoWebLogin {
  /// Creates the session; the [proxy] field (`host:port`) routes the
  /// browser-flow requests through the app's proxy when one is in force.
  HongguoWebLogin({this.proxy});

  /// The proxy endpoint in force, or null for direct.
  final String? proxy;
  final List<_LoginCookie> _cookies = [];
  String _token = '';
  HttpClient? _io;
  String _mobile = '';
  bool _codeSent = false;

  /// Releases the session's transport.
  void dispose() {
    _io?.close(force: true);
    _io = null;
  }

  HttpClient _client() => _io ??= _newClient();

  HttpClient _newClient() {
    final client = HttpClient();
    final proxy = this.proxy;
    if (proxy != null && proxy.contains(':')) {
      client.findProxy = (uri) => 'PROXY $proxy';
    }
    return client;
  }

  Future<HttpClientResponse> _send(Uri url, {Map<String, String>? form}) async {
    {
      final request = await _client().openUrl(form == null ? 'GET' : 'POST', url);
      request
        ..followRedirects = false
        ..persistentConnection = false
        ..headers.set('User-Agent', _kLoginUa)
        ..headers.set('Referer', '$_kBase/')
        ..headers.set('Origin', _kBase)
        ..headers.set('Accept', 'application/json, text/javascript');
      final csrf = _cookie('passport_csrf_token');
      if (csrf != null) {
        request.headers.set('x-tt-passport-csrf-token', csrf.value);
      }
      final jar = _cookies.where((cookie) => cookie.alive).map((cookie) => '${cookie.name}=${cookie.value}').join('; ');
      if (jar.isNotEmpty) {
        request.headers.set('Cookie', jar);
      }
      if (form != null) {
        final body = form.entries.map((entry) => '${entry.key}=${Uri.encodeQueryComponent(entry.value)}').join('&');
        final bytes = utf8.encode(body);
        request.headers.set('Content-Type', 'application/x-www-form-urlencoded');
        request.headers.contentLength = bytes.length;
        request.add(bytes);
      }
      final response = await request.close();
      _absorb(
        response.cookies.map(
          (cookie) => _LoginCookie(
            cookie.name,
            cookie.value,
            (cookie.expires?.millisecondsSinceEpoch ?? 0) ~/ 1000,
          ),
        ),
      );
      return response;
    }
  }

  void _absorb(Iterable<_LoginCookie> fresh) {
    for (final cookie in fresh) {
      _cookies.removeWhere((kept) => kept.name == cookie.name);
      if (cookie.value.isNotEmpty) _cookies.add(cookie);
    }
  }

  _LoginCookie? _cookie(String name) {
    for (final cookie in _cookies) {
      if (cookie.name == name && cookie.alive) return cookie;
    }
    return null;
  }

  Future<Map<String, Object?>> _call(
    String path, {
    Map<String, String>? data,
    Map<String, String> params = const {},
  }) async {
    final query = {
      'aid': '513755',
      'passport_jssdk_version': '3.4.10',
      'passport_jssdk_type': 'normal',
      'account_sdk_source': 'web',
      'is_from_ttaccountsdk': '1',
      'language': 'zh',
      ...params,
    };
    final uri = Uri.https('hongguoduanju.com', path, query);
    final response = await _send(uri, form: data);
    final text = await response.transform(utf8.decoder).join();
    Object? decoded;
    try {
      decoded = jsonDecode(text);
    } on Object {
      throw const HongguoLoginFailure('官网登录返回格式异常');
    }
    if (decoded is! Map<String, Object?>) {
      throw const HongguoLoginFailure('官网登录返回格式异常');
    }
    return decoded;
  }

  Map<String, Object?> _checked(Map<String, Object?> reply) {
    final data = reply['data'];
    if (data is! Map<String, Object?>) {
      throw const HongguoLoginFailure('官网登录返回格式异常');
    }
    if (reply['message'] != 'success') {
      final code = data['error_code'] is num ? (data['error_code']! as num).toInt() : -1;
      final described = data['description'];
      final message = described is String && described.isNotEmpty
          ? described
          : '官网登录失败';
      throw HongguoLoginFailure('$message（错误码 $code）');
    }
    return data;
  }

  /// Fetches a fresh QR code to show.
  Future<HongguoQrCode> qr() async {
    final data = _checked(await _call('/passport/web/get_qrcode/', params: {'next': '$_kBase/'}));
    final token = data['token'];
    final encoded = data['qrcode'];
    if (token is! String || token.isEmpty || encoded is! String || !encoded.contains('base64,')) {
      throw const HongguoLoginFailure('二维码数据异常');
    }
    _token = token;
    final raw = encoded.substring(encoded.indexOf('base64,') + 7);
    final expiry = data['expire_time'] is num ? (data['expire_time']! as num).toInt() : 180;
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final seconds = expiry > 1000000000 ? (expiry - now).clamp(0, 600) : expiry.clamp(0, 600);
    return HongguoQrCode(image: base64Decode(raw), expiresIn: seconds);
  }

  /// Whether the visitor confirmed the code yet; false while waiting.
  Future<bool> poll() async {
    if (_token.isEmpty) {
      throw const HongguoLoginFailure('请先获取二维码');
    }
    final data = _checked(
      await _call('/passport/web/check_qrconnect/', params: {'next': '$_kBase/', 'token': _token}),
    );
    final status = data['status'];
    if (status == '5' || status == 'expired') {
      throw const HongguoLoginFailure('二维码已过期，请重新获取');
    }
    if (status == '3' || status == 'confirmed') {
      final redirect = data['redirect_url'];
      if (redirect is String && redirect.isNotEmpty) {
        await _finishRedirect(redirect);
      }
    }
    return hasSession;
  }

  /// Follows only the official site's confirmation redirect, so every
  /// domain cookie on the chain lands.
  Future<void> _finishRedirect(String value) async {
    var url = Uri.parse('$_kBase/').resolve(value);
    for (var hop = 0; hop < 5; hop++) {
      if (!url.isScheme('https') || url.host != 'hongguoduanju.com') {
        throw const HongguoLoginFailure('登录确认跳转到不支持的站点');
      }
      final response = await _send(url);
      if (response.statusCode >= 300 && response.statusCode < 400) {
        final location = response.headers.value(HttpHeaders.locationHeader);
        await response.drain<void>();
        if (location == null) {
          throw const HongguoLoginFailure('登录确认地址无效');
        }
        url = url.resolve(location);
        continue;
      }
      await response.drain<void>();
      if (response.statusCode ~/ 100 != 2) {
        throw HongguoLoginFailure('登录确认失败（HTTP ${response.statusCode}）');
      }
      return;
    }
    throw const HongguoLoginFailure('登录确认跳转次数过多');
  }

  /// Mixes a field the way the web passport expects: each UTF-8 byte
  /// xored with 5, written as two hex digits.
  static String _mix(String value) => utf8
      .encode(value)
      .map((byte) => ((byte & 0xFF) ^ 0x05).toRadixString(16))
      .join();

  /// Sends the login code to [number] (`138…` mainland, `+区号 号码`
  /// elsewhere). The QR fetch warms the CSRF cookie when the session has
  /// none yet.
  Future<({String maskedMobile, int retrySeconds})> sendCode(String number) async {
    if (_cookie('passport_csrf_token') == null) {
      await qr();
    }
    _mobile = number.startsWith('+') ? number : '+86 $number';
    final data = _checked(
      await _call('/passport/web/send_code/', data: {
        'mobile': _mix(_mobile),
        'type': _mix('24'),
        'mix_mode': '1',
        'fixed_mix_mode': '1',
      }),
    );
    _codeSent = true;
    final masked = data['mobile'] is String && (data['mobile']! as String).isNotEmpty
        ? data['mobile']! as String
        : '你的手机';
    final retry = data['retry_time'] is num ? (data['retry_time']! as num).toInt() : 60;
    return (maskedMobile: masked, retrySeconds: retry);
  }

  /// Verifies [code]; answers whether the session cookie landed.
  Future<bool> verifyCode(String code) async {
    if (!_codeSent) {
      throw const HongguoLoginFailure('请先发送验证码');
    }
    _checked(
      await _call('/passport/web/sms_login/', data: {
        'mobile': _mix(_mobile),
        'code': _mix(code),
        'login_only': 'true',
        'mix_mode': '1',
        'fixed_mix_mode': '1',
      }),
    );
    return hasSession;
  }

  bool get hasSession => _cookie('sessionid') != null || _cookie('sessionid_ss') != null;

  /// The confirmed login's cookies, as the account endpoints' `Cookie`
  /// header. Call after [poll] answered true.
  Future<String> credentials() async {
    if (!hasSession) {
      throw const HongguoLoginFailure('官网尚未下发登录态，请先在手机确认登录');
    }
    _checked(await _call('/passport/account/info/v2/'));
    return _cookies
        .where((cookie) => cookie.alive)
        .map((cookie) => '${cookie.name}=${cookie.value}')
        .join('; ');
  }
}

/// A login step the platform refused, safe to show as sent.
final class HongguoLoginFailure implements Exception {
  /// Creates the failure.
  const HongguoLoginFailure(this.message);

  /// One line on what went wrong.
  final String message;

  @override
  String toString() => message;
}
