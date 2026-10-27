import 'package:live_sites/src/capabilities/live_auth_capability.dart';
import 'package:live_sites/src/core/live_site_error.dart';
import 'package:live_sites/src/internal/cookie_fields.dart';
import 'package:live_sites/src/platforms/cc/cc_manifest.dart';
import 'package:live_sites/src/platforms/cc/cc_site.dart';

// Platform-internal code: constructor-name and doc verbosity rules that
// govern the public surface are relaxed here, and an empty paste is thrown as
// the app-facing `LiveSiteError` value (the type the application can read a
// message off).
// ignore_for_file: unnecessary_type_name_in_constructor, only_throw_errors

/// NetEase CC's sign-in: the viewer pastes the `cc.163.com` cookie, and it is
/// stored and nothing more.
///
/// CC gives an outside client no account endpoint to ask who a cookie belongs
/// to, so [fetchAccount] answers `UnsupportedError` like kuaishou's. The
/// difference is what the stored cookie does: no request of [CcSite] reads it,
/// because every answer the adapter builds (lists, search, rooms, qualities) is
/// the website's anonymous one and CC has no chat join to make as the viewer.
/// That is the reference's `usedByRequests = false`, whose account surface
/// shows "已保存，暂未用于请求" instead of claiming a sign-in — this provider keeps
/// the promise honest by keeping the cookie on [CcSite.appliedLogin], where the
/// day an account-identified danmaku lands is the one place it will be read
/// from.
final class CcAuthProvider implements LiveAuthCapability {
  /// Serves [site].
  CcAuthProvider({required this.site});

  /// The site this capability serves.
  final CcSite site;

  static const String _siteId = ccSiteId;

  @override
  bool get supportsCookiePaste => true;

  @override
  bool get supportsQrLogin => false;

  @override
  bool get canVerifyOnline => false;

  @override
  LiveAuthSession startQrLogin() =>
      throw UnsupportedError('cc signs in with a pasted cc.163.com cookie, not a QR code');

  @override
  Future<LiveCredential> exchange(LiveAuthSession session) =>
      throw UnsupportedError('cc has no QR session to exchange — applyPastedCookie is the sign-in');

  @override
  Future<LiveCredential> fetchAccount() =>
      throw UnsupportedError('cc has no account endpoint — its pasted cookie is kept as given');

  /// Wraps the pasted browser cookie [rawCookieHeader] as the credential;
  /// verified by nothing but being a cookie, since CC has no endpoint that
  /// answers who one belongs to.
  @override
  Future<LiveCredential> applyPastedCookie(String rawCookieHeader) async {
    final cookies = parseCookieFields(rawCookieHeader);
    if (cookies.isEmpty) {
      throw const LiveSiteError.authentication(siteId: _siteId, message: 'the pasted cookie is empty');
    }
    return LiveCredential(siteId: _siteId, cookies: cookies);
  }

  /// Remembers [credential]'s cookies on the site. Stored, not attached: no CC
  /// request carries them (see [CcSite.appliedLogin]).
  @override
  Future<void> applyCredential(LiveCredential credential) async {
    if (credential.siteId != _siteId) {
      throw ArgumentError.value(credential.siteId, 'credential.siteId', 'the credential is not a cc credential');
    }
    if (credential.cookies.isEmpty) {
      throw ArgumentError.value(credential, 'credential', 'the credential has no cookies');
    }
    site.applyLoginCredential(cookieHeaderOf(credential.cookies));
  }

  @override
  Future<void> clearCredential() async => site.clearLoginCredential();
}
