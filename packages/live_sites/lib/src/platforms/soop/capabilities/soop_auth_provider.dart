import 'package:live_sites/src/capabilities/live_auth_capability.dart';
import 'package:live_sites/src/core/live_site_error.dart';
import 'package:live_sites/src/internal/cookie_fields.dart';
import 'package:live_sites/src/platforms/soop/soop_manifest.dart';
import 'package:live_sites/src/platforms/soop/soop_site.dart';

// Platform-internal code: constructor-name and doc verbosity rules that
// govern the public surface are relaxed here, and an empty paste is thrown as
// the app-facing `LiveSiteError` value (the type the application can read a
// message off).
// ignore_for_file: unnecessary_type_name_in_constructor, only_throw_errors

/// SOOP's sign-in: the viewer pastes the `www.sooplive.co.kr` cookie and it is
/// kept as given — the platform answers no account endpoint an outside client
/// could ask, so the account surface says "已保存" and the cookie's worth is
/// what its requests answer: the player API reads the viewer out of it, which
/// unlocks the age-restricted broadcasts and the qualities above the guest
/// ones (the reference's `check: none`). The chat socket never carries it.
final class SoopAuthProvider implements LiveAuthCapability {
  /// Serves [site].
  SoopAuthProvider({required this.site});

  /// The site this capability serves.
  final SoopSite site;

  static const String _siteId = soopSiteId;

  @override
  bool get supportsCookiePaste => true;

  @override
  bool get supportsQrLogin => false;

  @override
  bool get canVerifyOnline => false;

  @override
  LiveAuthSession startQrLogin() =>
      throw UnsupportedError('soop signs in with a pasted www.sooplive.co.kr cookie, not a QR code');

  @override
  Future<LiveCredential> exchange(LiveAuthSession session) =>
      throw UnsupportedError('soop has no QR session to exchange — applyPastedCookie is the sign-in');

  @override
  Future<LiveCredential> fetchAccount() =>
      throw UnsupportedError('soop has no account endpoint — its pasted cookie is kept as given');

  /// Wraps the pasted browser cookie [rawCookieHeader] as the credential.
  /// Nothing is verified: SOOP has no endpoint that answers who a cookie
  /// belongs to, and a cookie that is not a login simply leaves the player API
  /// answering as it does for a guest.
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
      throw ArgumentError.value(credential.siteId, 'credential.siteId', 'the credential is not a soop credential');
    }
    if (credential.cookies.isEmpty) {
      throw ArgumentError.value(credential, 'credential', 'the credential has no cookies');
    }
    site.applyLoginCredential(cookieHeaderOf(credential.cookies));
  }

  @override
  Future<void> clearCredential() async => site.clearLoginCredential();
}
