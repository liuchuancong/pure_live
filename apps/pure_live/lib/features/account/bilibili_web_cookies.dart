import 'dart:developer' as developer show log;

import 'package:webview_flutter/webview_flutter.dart';

/// The built-in browser's side of bilibili's web login: which hosts carry the
/// login, whether this device has a browser at all, and how its cookies become
/// the cookie header a sign-in is stored from. The page that shows the browser
/// lives beside this file (`bilibili_web_login_page.dart`).

/// Whether this device has a built-in browser the web login can use.
///
/// `webview_flutter` ships no Windows or Linux implementation, so there the
/// platform instance is never registered and stays null — the same answer the
/// in-app search page gives when it offers the system browser instead of an
/// empty frame. A sign-in entry that could do nothing is not shown at all, so
/// this is what the QR page's web login option is gated on.
bool get bilibiliWebLoginAvailable => WebViewPlatform.instance != null;

/// The bilibili addresses whose built-in browser cookies make up a login.
final List<Uri> bilibiliWebCookieDomains = [
  Uri.https('www.bilibili.com'),
  Uri.https('passport.bilibili.com'),
  Uri.https('m.bilibili.com'),
];

/// Where the web login starts: bilibili's sign-in page (SMS, password).
final Uri bilibiliPassportLogin = Uri.https('passport.bilibili.com', '/login');

/// Whether [uri] is the main site — where a signed-in visitor lands, and what
/// the web login page says it is doing when it gets there (the reference's
/// 3.x rule).
bool isBilibiliHome(Uri uri) {
  final host = uri.host.toLowerCase();
  return host == 'www.bilibili.com' || host == 'm.bilibili.com' || host == 'bilibili.com';
}

/// Removes bilibili's cookies from the built-in browser, so the web login
/// never picks up the account that was signed in last time.
///
/// The platform's cookie store has no per-domain delete: every cookie read
/// off the three bilibili hosts is rewritten with an empty value instead,
/// which is the same end for the login ([hasBilibiliSessionCookie] wants a
/// value) and leaves the rest of the jar alone. Nothing happens without a
/// built-in browser, and one host's failure never stops the others.
Future<void> clearBilibiliWebCookies() async {
  if (!bilibiliWebLoginAvailable) return;
  final manager = WebViewCookieManager();
  for (final url in bilibiliWebCookieDomains) {
    try {
      for (final cookie in await manager.getCookies(domain: url)) {
        await manager.setCookie(WebViewCookie(name: cookie.name, value: '', domain: cookie.domain, path: cookie.path));
      }
    } on Object catch (error, stack) {
      developer.log(
        'Clearing the bilibili web cookies of ${url.host} failed',
        name: 'AccountPage',
        error: error,
        stackTrace: stack,
      );
    }
  }
}

/// The cookies the built-in browser holds for bilibili, as the `name=value; …`
/// header line a sign-in is stored from: the first value of each name, over
/// every one of [bilibiliWebCookieDomains]. A host that cannot be read is
/// skipped — the others still make the login.
Future<String> readBilibiliWebCookieHeader() async {
  if (!bilibiliWebLoginAvailable) return '';
  final manager = WebViewCookieManager();
  final seen = <String>{};
  final fields = <String>[];
  for (final url in bilibiliWebCookieDomains) {
    try {
      for (final cookie in await manager.getCookies(domain: url)) {
        final name = cookie.name.trim();
        if (name.isEmpty || !seen.add(name)) continue;
        fields.add('$name=${cookie.value}');
      }
    } on Object catch (error, stack) {
      developer.log(
        'Reading the bilibili web cookies of ${url.host} failed',
        name: 'AccountPage',
        error: error,
        stackTrace: stack,
      );
    }
  }
  return fields.join('; ');
}

/// Whether [header] carries a session cookie: bilibili signs a visitor in with
/// `SESSDATA`, and a login without one (or with the empty one the browser was
/// cleared to) is not a login yet.
bool hasBilibiliSessionCookie(String header) => RegExp(r'(?:^|;\s*)SESSDATA=[^;\s]+').hasMatch(header);
