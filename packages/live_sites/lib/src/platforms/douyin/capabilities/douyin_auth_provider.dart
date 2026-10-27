import 'package:live_sites/src/capabilities/live_auth_capability.dart';
import 'package:live_sites/src/core/live_site_error.dart';
import 'package:live_sites/src/internal/cookie_fields.dart';
import 'package:live_sites/src/platforms/douyin/douyin_manifest.dart';
import 'package:live_sites/src/platforms/douyin/douyin_site.dart';
import 'package:live_sites/src/platforms/douyin/parsers/douyin_failure.dart';

// Platform-internal code: constructor-name and doc verbosity rules that
// govern the public surface are relaxed here, and a paste the platform
// rejects is thrown as the app-facing `LiveSiteError` value (the type the
// application can read a message off).
// ignore_for_file: unnecessary_type_name_in_constructor, only_throw_errors

/// Douyin's sign-in: the web gives an outside client no login QR — the viewer
/// pastes the `live.douyin.com` cookie, the paste is judged by the platform
/// itself through `webcast/user/me/` (whose 20003 answer says the cookie
/// names no login), and the credential is applied to the site in memory only
/// — storing it is the application's business (its secret store).
final class DouyinAuthProvider implements LiveAuthCapability {
  /// Serves [site].
  DouyinAuthProvider({required this.site});

  /// The site this capability serves.
  final DouyinSite site;

  static const String _siteId = douyinSiteId;

  @override
  bool get supportsCookiePaste => true;

  @override
  bool get supportsQrLogin => false;

  @override
  bool get canVerifyOnline => true;

  @override
  LiveAuthSession startQrLogin() =>
      throw UnsupportedError('douyin signs in with a pasted live.douyin.com cookie, not a QR code');

  @override
  Future<LiveCredential> exchange(LiveAuthSession session) =>
      throw UnsupportedError('douyin has no QR session to exchange — applyPastedCookie is the sign-in');

  /// Who the applied login is, from `webcast/user/me/`. A cookie the platform
  /// no longer accepts answers as its authentication failure, which is how a
  /// login that expired since it was saved is found out; a transport
  /// breakdown keeps its own kind so the account surface can tell the two
  /// apart.
  @override
  Future<LiveCredential> fetchAccount() async {
    final cookie = site.login();
    if (cookie.isEmpty) {
      throw const LiveSiteError.authentication(siteId: _siteId, message: 'no douyin login is applied');
    }
    return await _credential(cookie, cookies: parseCookieFields(cookie));
  }

  /// Verifies the pasted browser cookie [rawCookieHeader] online and wraps it
  /// as the credential; a paste the platform rejects is never a credential.
  @override
  Future<LiveCredential> applyPastedCookie(String rawCookieHeader) async {
    final cookies = parseCookieFields(rawCookieHeader);
    if (cookies.isEmpty) {
      throw const LiveSiteError.authentication(siteId: _siteId, message: 'the pasted cookie is empty');
    }
    return await _credential(cookieHeaderOf(cookies), cookies: cookies);
  }

  @override
  Future<void> applyCredential(LiveCredential credential) async {
    if (credential.siteId != _siteId) {
      throw ArgumentError.value(credential.siteId, 'credential.siteId', 'the credential is not a douyin credential');
    }
    if (credential.cookies.isEmpty) {
      throw ArgumentError.value(credential, 'credential', 'the credential has no cookies');
    }
    site.applyLoginCredential(cookieHeaderOf(credential.cookies));
  }

  @override
  Future<void> clearCredential() async => site.clearLoginCredential();

  /// [cookies] as the credential the platform's answer names for [cookie].
  Future<LiveCredential> _credential(String cookie, {required Map<String, String> cookies}) async {
    final nickname = await _ask(cookie);
    return LiveCredential(siteId: _siteId, cookies: cookies, nickname: nickname);
  }

  /// The platform's own answer about [cookie], its failure mapped to the
  /// app-facing error kind (`needsLogin` is what "登录已失效" reads).
  Future<String> _ask(String cookie) async {
    try {
      return await site.accountNickname(cookie: cookie);
    } on DouyinFailure catch (failure) {
      throw failure.toLiveSiteError(_siteId);
    }
  }
}
