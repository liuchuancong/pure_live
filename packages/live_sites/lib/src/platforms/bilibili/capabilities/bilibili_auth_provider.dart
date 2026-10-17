import 'package:live_sites/src/capabilities/live_auth_capability.dart';
import 'package:live_sites/src/platforms/bilibili/api/bilibili_endpoints.dart';
import 'package:live_sites/src/platforms/bilibili/bilibili_site.dart';
import 'package:live_sites/src/platforms/bilibili/capabilities/bilibili_qr_login_session.dart';
import 'package:live_sites/src/platforms/bilibili/parsers/bilibili_auth_parser.dart';
import 'package:live_sites/src/platforms/bilibili/parsers/bilibili_failure.dart';

// Platform-internal code: constructor-name and doc verbosity rules that
// govern the public surface are relaxed here.
// ignore_for_file: unnecessary_type_name_in_constructor

/// Bilibili's QR login: `passport.bilibili.com` issues and judges the code,
/// `x/member/web/account` verifies the granted cookie, and the credential is
/// applied to the site in memory only — storing it is the application's
/// business (its secret store).
final class BilibiliAuthProvider implements LiveAuthCapability {
  /// Serves [site].
  BilibiliAuthProvider({required this.site});

  /// The site this capability serves.
  final BilibiliSite site;

  static const String _siteId = 'bilibili';

  @override
  LiveAuthSession startQrLogin() => BilibiliQrLoginSession(provider: this);

  @override
  Future<LiveCredential> applyPastedCookie(String rawCookieHeader) =>
      throw UnsupportedError('bilibili signs in with its QR code, not a pasted cookie');

  @override
  Future<LiveCredential> exchange(LiveAuthSession session) async {
    if (session is! BilibiliQrLoginSession) {
      throw const BilibiliFailure(
        BilibiliFailureKind.invalidArgument,
        'exchange: not a bilibili QR session',
      );
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
