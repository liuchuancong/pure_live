import 'package:live_sites/src/capabilities/live_auth_capability.dart';
import 'package:live_sites/src/core/live_site_error.dart';
import 'package:live_sites/src/internal/cookie_fields.dart';
import 'package:live_sites/src/platforms/bilibili/api/bilibili_endpoints.dart';
import 'package:live_sites/src/platforms/bilibili/bilibili_manifest.dart';
import 'package:live_sites/src/platforms/bilibili/bilibili_site.dart';
import 'package:live_sites/src/platforms/bilibili/capabilities/bilibili_qr_login_session.dart';
import 'package:live_sites/src/platforms/bilibili/parsers/bilibili_auth_parser.dart';
import 'package:live_sites/src/platforms/bilibili/parsers/bilibili_failure.dart';

// Platform-internal code: constructor-name and doc verbosity rules that
// govern the public surface are relaxed here, and a paste the site rejects is
// thrown as the app-facing `LiveSiteError` value (the type the application can
// read a message off).
// ignore_for_file: unnecessary_type_name_in_constructor, only_throw_errors

/// Bilibili's QR login: `passport.bilibili.com` issues and judges the code,
/// `x/member/web/account` verifies the granted cookie, and the credential is
/// applied to the site in memory only — storing it is the application's
/// business (its secret store).
final class BilibiliAuthProvider implements LiveAuthCapability {
  /// Serves [site].
  BilibiliAuthProvider({required this.site});

  /// The site this capability serves.
  final BilibiliSite site;

  static const String _siteId = bilibiliSiteId;

  @override
  bool get supportsCookiePaste => true;

  @override
  bool get supportsQrLogin => true;

  @override
  bool get canVerifyOnline => true;

  /// Who the applied login is, from `x/member/web/account`. A stored cookie
  /// the site no longer accepts answers as its authentication failure, which
  /// is how a login that expired since it was saved is found out.
  @override
  Future<LiveCredential> fetchAccount() async {
    final cookie = site.login();
    if (cookie.isEmpty) {
      throw const LiveSiteError.authentication(siteId: _siteId, message: 'no bilibili login is applied');
    }
    final account = await site.accountOf(cookie: cookie);
    return LiveCredential(
      siteId: _siteId,
      cookies: parseCookieFields(cookie),
      userId: '${account.uid}',
      nickname: account.name,
      avatar: account.face.isEmpty ? null : account.face,
    );
  }

  @override
  LiveAuthSession startQrLogin() => BilibiliQrLoginSession(provider: this);

  /// Signs in with a browser cookie the viewer pasted (the QR page's "填写
  /// Cookie" way, for a login the QR cannot reach): the paste must carry
  /// `SESSDATA`, and it is verified against `x/member/web/account` before it
  /// counts — a paste the site rejects throws what the account call answered.
  @override
  Future<LiveCredential> applyPastedCookie(String rawCookieHeader) async {
    final cookies = parseCookieFields(rawCookieHeader);
    if (cookies.isEmpty) {
      throw const LiveSiteError.authentication(siteId: _siteId, message: 'the pasted cookie is empty');
    }
    if ((cookies['SESSDATA'] ?? '').isEmpty) {
      throw const LiveSiteError.authentication(
        siteId: _siteId,
        message: 'the pasted cookie carries no SESSDATA — copy it while signed in',
      );
    }
    final account = await site.accountOf(cookie: cookieHeaderOf(cookies));
    return LiveCredential(
      siteId: _siteId,
      cookies: cookies,
      userId: '${account.uid}',
      nickname: account.name,
      avatar: account.face.isEmpty ? null : account.face,
    );
  }

  @override
  Future<LiveCredential> exchange(LiveAuthSession session) async {
    if (session is! BilibiliQrLoginSession) {
      throw const BilibiliFailure(BilibiliFailureKind.invalidArgument, 'exchange: not a bilibili QR session');
    }
    final granted = await session.granted();
    final account = await site.accountOf(cookie: _cookieHeader(granted.cookies));
    return LiveCredential(
      siteId: _siteId,
      cookies: granted.cookies,
      userId: '${account.uid}',
      nickname: account.name,
      avatar: account.face.isEmpty ? null : account.face,
      expiry: granted.expiry,
    );
  }

  @override
  Future<void> applyCredential(LiveCredential credential) async {
    if (credential.siteId != _siteId) {
      throw BilibiliFailure(
        BilibiliFailureKind.invalidArgument,
        'applyCredential: the credential is for ${credential.siteId}',
      );
    }
    if (credential.cookies.isEmpty) {
      throw const BilibiliFailure(
        BilibiliFailureKind.invalidArgument,
        'applyCredential: the credential has no cookies',
      );
    }
    site.applyLoginCredential(
      cookie: _cookieHeader(credential.cookies),
      uid: credential.userId == null ? null : int.tryParse(credential.userId!),
    );
  }

  @override
  Future<void> clearCredential() async => site.clearLoginCredential();

  /// Issues one QR (`qrcode/generate`), as a guest.
  Future<({String key, String url})> issueQrCode() async {
    final response = await site.httpGet(BilibiliEndpoints.qrGenerate(), headers: site.apiHeaders(''));
    return BilibiliAuthParser.qrGenerate(response.text, status: response.status);
  }

  /// One poll of [key] (`qrcode/poll`); the granted cookies are read from the
  /// answer's `Set-Cookie` lines, not from the body.
  Future<({int code, Map<String, String> cookies, DateTime? expiry})> pollQrCode(String key) async {
    final response = await site.http.getRaw(BilibiliEndpoints.qrPoll(key), headers: site.apiHeaders(''));
    final granted = BilibiliAuthParser.grantedCookies(response.setCookies);
    return (
      code: BilibiliAuthParser.qrPollState(response.text, status: response.statusCode),
      cookies: granted.cookies,
      expiry: granted.expiry,
    );
  }

  static String _cookieHeader(Map<String, String> cookies) =>
      cookies.entries.map((entry) => '${entry.key}=${entry.value}').join('; ');
}
