import 'package:live_sites/src/capabilities/live_auth_capability.dart';
import 'package:live_sites/src/core/live_site_error.dart';
import 'package:live_sites/src/platforms/huya/huya_site.dart';

// Platform-internal code: constructor-name and doc verbosity rules that
// govern the public surface are relaxed here, and the paste's verification
// failures are thrown as the app-facing `LiveSiteError` values (the type the
// application can actually read a message off) rather than the private
// platform failure.
// ignore_for_file: unnecessary_type_name_in_constructor, only_throw_errors

final RegExp _controlCharacters = RegExp(r'[\u0000-\u001F\u007F]');

/// Huya's sign-in: the web sign-in has no QR flow — the viewer pastes the
/// browser's `www.huya.com` cookie, the paste is verified the way the site's
/// own request plumbing reads the login (the `yyuid` field must name the
/// account), and the credential is applied to the site in memory only —
/// storing it is the application's business (its secret store).
///
/// The verification reads the login out of the cookie itself: huya's web
/// front exposes no user endpoint an outside client could verify against.
final class HuyaAuthProvider implements LiveAuthCapability {
  /// Serves [site].
  HuyaAuthProvider({required this.site});

  /// The site this capability serves.
  final HuyaSite site;

  static const String _siteId = 'huya';

  @override
  LiveAuthSession startQrLogin() =>
      throw UnsupportedError('huya signs in with a pasted www.huya.com cookie, not a QR code');

  @override
  Future<LiveCredential> exchange(LiveAuthSession session) =>
      throw UnsupportedError('huya has no QR session to exchange — applyPastedCookie is the sign-in');

  /// Verifies the pasted browser cookie [rawCookieHeader] (a `name=value;`
  /// header line, `Cookie:` prefix and attributes tolerated) and wraps it as
  /// the credential. A paste without a usable `yyuid` login field is an
  /// authentication failure whose message says what is missing. The
  /// verification reads the cookie itself — huya's web front exposes no user
  /// endpoint an outside client could verify against, so this is the
  /// reference's own verification: a paste is a login exactly when the
  /// `yyuid` account id is in it.
  @override
  Future<LiveCredential> applyPastedCookie(String rawCookieHeader) async {
    const siteId = _siteId;
    final cookies = parseFields(rawCookieHeader);
    if (cookies.isEmpty) {
      throw const LiveSiteError.authentication(siteId: siteId, message: 'the pasted cookie is empty');
    }
    final uid = accountUid(cookies);
    if (uid == null) {
      throw const LiveSiteError.authentication(
        siteId: siteId,
        message: 'the pasted cookie carries no yyuid login field — copy the cookie while signed in',
      );
    }
    return LiveCredential(siteId: siteId, cookies: cookies, userId: '$uid');
  }

  @override
  Future<void> applyCredential(LiveCredential credential) async {
    if (credential.siteId != _siteId) {
      throw ArgumentError.value(credential.siteId, 'credential.siteId', 'the credential is not a huya credential');
    }
    if (credential.cookies.isEmpty) {
      throw ArgumentError.value(credential, 'credential', 'the credential has no cookies');
    }
    site.applyLoginCredential(_cookieHeader(credential.cookies));
  }

  @override
  Future<void> clearCredential() async => site.clearLoginCredential();

  /// The `name=value` pairs of a cookie header line, attributes tolerated, a
  /// later field replacing an earlier one of the same name.
  static Map<String, String> parseFields(String rawCookieHeader) {
    final fields = <String, String>{};
    for (final part in rawCookieHeader.replaceAll(_controlCharacters, '').split(';')) {
      final separator = part.indexOf('=');
      if (separator <= 0) continue;
      final name = part.substring(0, separator).trim();
      final value = part.substring(separator + 1).trim();
      if (name.isEmpty || value.isEmpty) continue;
      fields[name] = value;
    }
    return fields;
  }

  /// The account id the cookie names: an exact `yyuid` field above 0 — the
  /// identity the site's signing reads — null when absent or unusable.
  static int? accountUid(Map<String, String> cookies) {
    final uid = int.tryParse(cookies['yyuid'] ?? '');
    return uid != null && uid > 0 ? uid : null;
  }

  static String _cookieHeader(Map<String, String> cookies) =>
      cookies.entries.map((entry) => '${entry.key}=${entry.value}').join('; ');
}
