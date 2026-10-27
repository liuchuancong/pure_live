import 'package:live_sites/src/capabilities/live_auth_capability.dart';
import 'package:live_sites/src/core/live_site_error.dart';
import 'package:live_sites/src/internal/cookie_fields.dart';
import 'package:live_sites/src/platforms/kuaishou/kuaishou_manifest.dart';
import 'package:live_sites/src/platforms/kuaishou/kuaishou_site.dart';

// Platform-internal code: constructor-name and doc verbosity rules that
// govern the public surface are relaxed here, and an empty paste is thrown as
// the app-facing `LiveSiteError` value (the type the application can read a
// message off).
// ignore_for_file: unnecessary_type_name_in_constructor, only_throw_errors

/// Kuaishou's sign-in: the viewer pastes the `live.kuaishou.com` cookie and it
/// is kept as given — the platform gives an outside client no endpoint to
/// verify a login against and no account name to show, so the account surface
/// says "已保存" and the cookie's own worth is judged by the requests that
/// carry it (the reference's `check: none`).
final class KuaishouAuthProvider implements LiveAuthCapability {
  /// Serves [site].
  KuaishouAuthProvider({required this.site});

  /// The site this capability serves.
  final KuaishouSite site;

  static const String _siteId = kuaishouSiteId;

  @override
  bool get supportsCookiePaste => true;

  @override
  bool get supportsQrLogin => false;

  @override
  bool get canVerifyOnline => false;

  @override
  LiveAuthSession startQrLogin() =>
      throw UnsupportedError('kuaishou signs in with a pasted live.kuaishou.com cookie, not a QR code');

  @override
  Future<LiveCredential> exchange(LiveAuthSession session) =>
      throw UnsupportedError('kuaishou has no QR session to exchange — applyPastedCookie is the sign-in');

  @override
  Future<LiveCredential> fetchAccount() =>
      throw UnsupportedError('kuaishou has no account endpoint — its pasted cookie is kept as given');

  /// Wraps the pasted browser cookie [rawCookieHeader] as the credential.
  /// Nothing is verified: an empty paste is the only answer this platform can
  /// give without asking it, and asking it is what it has no endpoint for.
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
      throw ArgumentError.value(
        credential.siteId,
        'credential.siteId',
        'the credential is not a kuaishou credential',
      );
    }
    if (credential.cookies.isEmpty) {
      throw ArgumentError.value(credential, 'credential', 'the credential has no cookies');
    }
    site.applyLoginCredential(cookieHeaderOf(credential.cookies));
  }

  @override
  Future<void> clearCredential() async => site.clearLoginCredential();
}
