import 'package:live_sites/src/capabilities/live_auth_capability.dart';
import 'package:live_sites/src/core/live_site_error.dart';
import 'package:live_sites/src/internal/cookie_fields.dart';
import 'package:live_sites/src/platforms/yy/yy_manifest.dart';
import 'package:live_sites/src/platforms/yy/yy_site.dart';

// Platform-internal code: constructor-name and doc verbosity rules that
// govern the public surface are relaxed here, and an empty paste is thrown as
// the app-facing `LiveSiteError` value (the type the application can read a
// message off).
// ignore_for_file: unnecessary_type_name_in_constructor, only_throw_errors

/// YY's sign-in: the viewer pastes the `www.yy.com` cookie and it is kept as
/// given — the platform gives an outside client no account endpoint, so the
/// account surface says "已保存" while the quality tiers the cookie unlocks are
/// what its requests answer (the reference's `check: none`).
final class YyAuthProvider implements LiveAuthCapability {
  /// Serves [site].
  YyAuthProvider({required this.site});

  /// The site this capability serves.
  final YySite site;

  static const String _siteId = yySiteId;

  @override
  bool get supportsCookiePaste => true;

  @override
  bool get supportsQrLogin => false;

  @override
  bool get canVerifyOnline => false;

  @override
  LiveAuthSession startQrLogin() =>
      throw UnsupportedError('yy signs in with a pasted www.yy.com cookie, not a QR code');

  @override
  Future<LiveCredential> exchange(LiveAuthSession session) =>
      throw UnsupportedError('yy has no QR session to exchange — applyPastedCookie is the sign-in');

  @override
  Future<LiveCredential> fetchAccount() =>
      throw UnsupportedError('yy has no account endpoint — its pasted cookie is kept as given');

  /// Wraps the pasted browser cookie [rawCookieHeader] as the credential,
  /// verified by nothing but being a cookie: YY names no account endpoint an
  /// outside client could ask.
  @override
  Future<LiveCredential> applyPastedCookie(String rawCookieHeader) async {
    final cookies = parseCookieFields(rawCookieHeader);
    if (cookies.isEmpty) {
      throw const LiveSiteError.authentication(siteId: _siteId, message: 'the pasted cookie is empty');
    }
    return LiveCredential(siteId: _siteId, cookies: cookies);
  }

  @override
  Future<void> applyCredential(LiveCredential credential) async {
    if (credential.siteId != _siteId) {
      throw ArgumentError.value(credential.siteId, 'credential.siteId', 'the credential is not a yy credential');
    }
    if (credential.cookies.isEmpty) {
      throw ArgumentError.value(credential, 'credential', 'the credential has no cookies');
    }
    site.applyLoginCredential(cookieHeaderOf(credential.cookies));
  }

  @override
  Future<void> clearCredential() async => site.clearLoginCredential();
}
