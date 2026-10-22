import 'package:live_sites/src/capabilities/live_auth_capability.dart';
import 'package:live_sites/src/core/live_site_error.dart';
import 'package:live_sites/src/platforms/douyu/douyu_manifest.dart';
import 'package:live_sites/src/platforms/douyu/douyu_site.dart';
import 'package:live_sites/src/platforms/douyu/parsers/douyu_account.dart';
import 'package:live_sites/src/platforms/douyu/parsers/douyu_json.dart';

// Platform-internal code: constructor-name and doc verbosity rules that
// govern the public surface are relaxed here, and the paste's verification
// failures are thrown as the app-facing `LiveSiteError` values (the type the
// application can actually read a message off) rather than the private
// platform failure.
// ignore_for_file: unnecessary_type_name_in_constructor, only_throw_errors

/// Douyu's sign-in: the web sign-in has no QR flow — the viewer pastes the
/// browser's `www.douyu.com` cookie, the paste is verified the way the
/// reference's cookie editor verifies it (a session token must be present; a
/// passport-only paste is refused, for the play edge answers a bare 403 to
/// it), and the credential is applied to the site in memory only — storing
/// it is the application's business (its secret store).
///
/// The verification reads the login out of the cookie itself (`dy_auth`,
/// `acf_auth` or `acf_jwt_token`, the identity `acf_uid` names): douyu's web
/// front exposes no user endpoint an outside client could verify against.
final class DouyuAuthProvider implements LiveAuthCapability {
  /// Serves [site].
  DouyuAuthProvider({required this.site});

  /// The site this capability serves.
  final DouyuSite site;

  static const String _siteId = douyuSiteId;

  @override
  LiveAuthSession startQrLogin() =>
      throw UnsupportedError('douyu signs in with a pasted www.douyu.com cookie, not a QR code');

  @override
  Future<LiveCredential> exchange(LiveAuthSession session) =>
      throw UnsupportedError('douyu has no QR session to exchange — applyPastedCookie is the sign-in');

  /// Verifies the pasted browser cookie [rawCookieHeader] (a `name=value;`
  /// header line, `Cookie:` prefix tolerated) and wraps it as the credential.
  /// A paste without a session token, or the passport request's cookie (the
  /// renewal fields without a login), is an authentication failure whose
  /// message says what is missing. The verification reads the cookie itself —
  /// douyu's web front exposes no user endpoint an outside client could
  /// verify against, so this is the reference's own verification: a paste is
  /// a login exactly when the web session's token is in it.
  @override
  Future<LiveCredential> applyPastedCookie(String rawCookieHeader) async {
    final cookie = DouyuAccount.normalizeCookie(rawCookieHeader);
    if (cookie.isEmpty) {
      throw const LiveSiteError.authentication(siteId: _siteId, message: 'the pasted cookie is empty');
    }
    if (DouyuAccount.isPassportCookie(cookie)) {
      throw const LiveSiteError.authentication(
        siteId: _siteId,
        message:
            "the paste is the passport request's cookie, which carries no login — "
            'copy the www.douyu.com page cookie instead',
      );
    }
    if (DouyuAccount.sessionToken(cookie) == null) {
      throw const LiveSiteError.authentication(
        siteId: _siteId,
        message: 'the pasted cookie carries no session token (dy_auth, acf_auth or acf_jwt_token)',
      );
    }
    return LiveCredential(
      siteId: _siteId,
      cookies: DouyuAccount.cookieFields(cookie),
      userId: _uidOf(cookie),
      expiry: DouyuAccount.sessionExpiry(cookie),
    );
  }

  @override
  Future<void> applyCredential(LiveCredential credential) async {
    if (credential.siteId != _siteId) {
      throw ArgumentError.value(credential.siteId, 'credential.siteId', 'the credential is not a douyu credential');
    }
    if (credential.cookies.isEmpty) {
      throw ArgumentError.value(credential, 'credential', 'the credential has no cookies');
    }
    site.applyLoginCredential(_cookieHeader(credential.cookies));
  }

  @override
  Future<void> clearCredential() async => site.clearLoginCredential();

  /// The account id the cookie itself names: the `acf_uid` field, else the
  /// H5 token payload's uid — null when the cookie names none.
  static String? _uidOf(String cookie) {
    final field = DouyuAccount.cookieField(cookie, 'acf_uid');
    if (field != null && field.isNotEmpty) return field;
    final payload = DouyuAccount.jwtPayload(DouyuAccount.sessionToken(cookie) ?? '');
    for (final key in const ['uid', 'user_id', 'userid']) {
      final id = jsonInt(payload?[key]);
      if (id != null && id > 0) return '$id';
    }
    return null;
  }

  static String _cookieHeader(Map<String, String> cookies) =>
      cookies.entries.map((entry) => '${entry.key}=${entry.value}').join('; ');
}
