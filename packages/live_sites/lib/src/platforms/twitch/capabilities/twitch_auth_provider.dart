import 'package:live_sites/src/capabilities/live_auth_capability.dart';
import 'package:live_sites/src/core/live_site_error.dart';
import 'package:live_sites/src/internal/cookie_fields.dart';
import 'package:live_sites/src/platforms/twitch/api/twitch_endpoints.dart';
import 'package:live_sites/src/platforms/twitch/twitch_manifest.dart';
import 'package:live_sites/src/platforms/twitch/twitch_site.dart';

// Platform-internal code: constructor-name and doc verbosity rules that
// govern the public surface are relaxed here, and a paste that names no
// account is thrown as the app-facing `LiveSiteError` value (the type the
// application can read a message off).
// ignore_for_file: unnecessary_type_name_in_constructor, only_throw_errors

/// Twitch's sign-in: the viewer pastes the `www.twitch.tv` cookie; the login is
/// the pair the chat itself reads out of it (`auth-token` and `login`), so the
/// paste is verified the way the platform's own request plumbing verifies it
/// and no account endpoint is asked. The credential is applied to the site in
/// memory only — storing it is the application's business (its secret store).
final class TwitchAuthProvider implements LiveAuthCapability {
  /// Serves [site].
  TwitchAuthProvider({required this.site});

  /// The site this capability serves.
  final TwitchSite site;

  static const String _siteId = twitchSiteId;

  @override
  bool get supportsCookiePaste => true;

  @override
  bool get supportsQrLogin => false;

  @override
  bool get canVerifyOnline => false;

  @override
  LiveAuthSession startQrLogin() =>
      throw UnsupportedError('twitch signs in with a pasted www.twitch.tv cookie, not a QR code');

  @override
  Future<LiveCredential> exchange(LiveAuthSession session) =>
      throw UnsupportedError('twitch has no QR session to exchange — applyPastedCookie is the sign-in');

  /// The account the applied cookie names, read from its own fields (what
  /// [TwitchSite.chat] answers); Twitch's OAuth identity is not an endpoint an
  /// outside client verifies a browser cookie against.
  @override
  Future<LiveCredential> fetchAccount() async {
    final cookie = site.login();
    final chat = twitchChatLogin(cookie);
    if (chat == null) {
      throw const LiveSiteError.authentication(
        siteId: _siteId,
        message: 'the stored cookie carries no chat identity (auth-token)',
      );
    }
    return LiveCredential(
      siteId: _siteId,
      cookies: parseCookieFields(cookie),
      userId: chat.login,
      nickname: chat.login,
    );
  }

  /// Verifies the pasted browser cookie [rawCookieHeader] the way the chat
  /// connection does: it is a login exactly when it names both a token and a
  /// nickname. A paste missing either is an authentication failure whose
  /// message says what is missing.
  @override
  Future<LiveCredential> applyPastedCookie(String rawCookieHeader) async {
    final cookies = parseCookieFields(rawCookieHeader);
    if (cookies.isEmpty) {
      throw const LiveSiteError.authentication(siteId: _siteId, message: 'the pasted cookie is empty');
    }
    final header = cookieHeaderOf(cookies);
    final chat = twitchChatLogin(header);
    if (chat == null) {
      throw const LiveSiteError.authentication(
        siteId: _siteId,
        message: 'the pasted cookie carries no auth-token and login pair — copy it while signed in',
      );
    }
    return LiveCredential(siteId: _siteId, cookies: cookies, userId: chat.login, nickname: chat.login);
  }

  @override
  Future<void> applyCredential(LiveCredential credential) async {
    if (credential.siteId != _siteId) {
      throw ArgumentError.value(credential.siteId, 'credential.siteId', 'the credential is not a twitch credential');
    }
    if (credential.cookies.isEmpty) {
      throw ArgumentError.value(credential, 'credential', 'the credential has no cookies');
    }
    site.applyLoginCredential(cookieHeaderOf(credential.cookies));
  }

  @override
  Future<void> clearCredential() async => site.clearLoginCredential();
}
