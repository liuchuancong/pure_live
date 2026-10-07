import 'dart:async';

import 'package:pure_live/core/index.dart';
import 'package:pure_live/core/network/cookie_sanitizer.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:pure_live/domains/account/data/bilibili_account_service.dart';

const String bilibiliWebLoginUrl = 'https://passport.bilibili.com/login';

typedef BilibiliWebCookieLoader = Future<String> Function(WebUri uri);
typedef BilibiliWebCookieVerifier = Future<bool> Function(String cookie);
typedef BilibiliWebLoginCompletion = void Function();
typedef BilibiliQrLoginNavigator = Future<void> Function();

class BiliBiliWebLoginController extends GetxController {
  BiliBiliWebLoginController({
    BilibiliWebCookieLoader? cookieLoader,
    BilibiliWebCookieVerifier? cookieVerifier,
    BilibiliWebLoginCompletion? completeLogin,
    BilibiliQrLoginNavigator? openQrLogin,
    this.transitionDelay = const Duration(milliseconds: 300),
  }) : _cookieLoader = cookieLoader ?? _loadBrowserCookie,
       _cookieVerifier = cookieVerifier ?? _verifyCookie,
       _completeLogin = completeLogin ?? _finishLogin,
       _openQrLogin = openQrLogin ?? _navigateToQrLogin;

  final BilibiliWebCookieLoader _cookieLoader;
  final BilibiliWebCookieVerifier _cookieVerifier;
  final BilibiliWebLoginCompletion _completeLogin;
  final BilibiliQrLoginNavigator _openQrLogin;
  final Duration transitionDelay;

  InAppWebViewController? webViewController;
  final showWebView = true.obs;
  final isVerifying = false.obs;
  final isSwitchingToQr = false.obs;
  final errorMessageKey = ''.obs;

  Future<void>? _activeLogin;
  Future<void>? _activeQrSwitch;
  int _loginRevision = 0;
  int _switchRevision = 0;
  bool _completed = false;
  bool _closed = false;

  void onWebViewCreated(InAppWebViewController controller) {
    if (_closed) return;
    webViewController = controller;
  }

  bool shouldCompleteLogin(WebUri? uri) {
    if (uri == null) return false;
    final host = uri.host.toLowerCase();
    return uri.scheme == 'https' && (host == 'm.bilibili.com' || host == 'www.bilibili.com');
  }

  NavigationActionPolicy navigationPolicyFor(WebUri? uri) {
    if (!shouldCompleteLogin(uri)) return NavigationActionPolicy.ALLOW;
    unawaited(handleLoginRedirect(uri!));
    return NavigationActionPolicy.CANCEL;
  }

  void onLoadStop(InAppWebViewController _, WebUri? uri) {
    if (shouldCompleteLogin(uri)) unawaited(handleLoginRedirect(uri!));
  }

  Future<void> handleLoginRedirect(WebUri uri) {
    if (_closed || _completed || isSwitchingToQr.value || !shouldCompleteLogin(uri)) {
      return Future.value();
    }
    final activeLogin = _activeLogin;
    if (activeLogin != null) return activeLogin;

    final revision = ++_loginRevision;
    isVerifying.value = true;
    errorMessageKey.value = '';
    late final Future<void> task;
    task = _loadAndVerifyCookie(uri, revision).whenComplete(() {
      if (identical(_activeLogin, task)) _activeLogin = null;
    });
    _activeLogin = task;
    return task;
  }

  Future<void> _loadAndVerifyCookie(WebUri uri, int revision) async {
    String cookie;
    try {
      cookie = normalizeAccountCookie(await _cookieLoader(uri));
    } catch (_) {
      if (_isLoginCurrent(revision)) _showLoginError('bilibili_web_cookie_failed');
      return;
    }
    if (!_isLoginCurrent(revision)) return;
    if (cookie.isEmpty) {
      _showLoginError('bilibili_web_cookie_missing');
      return;
    }

    bool loggedIn;
    try {
      loggedIn = await _cookieVerifier(cookie);
    } catch (_) {
      loggedIn = false;
    }
    if (!_isLoginCurrent(revision)) return;
    if (!loggedIn) {
      _showLoginError('bilibili_login_verification_failed');
      return;
    }

    _completed = true;
    showWebView.value = false;
    await Future<void>.delayed(transitionDelay);
    if (!_isLoginCurrent(revision)) return;
    isVerifying.value = false;
    _completeLogin();
  }

  Future<void> toQRLogin() {
    if (_closed) return Future.value();
    final activeSwitch = _activeQrSwitch;
    if (activeSwitch != null) return activeSwitch;

    _loginRevision++;
    isVerifying.value = false;
    errorMessageKey.value = '';
    showWebView.value = false;
    isSwitchingToQr.value = true;
    final revision = ++_switchRevision;

    late final Future<void> task;
    task = _switchToQrLogin(revision).whenComplete(() {
      if (identical(_activeQrSwitch, task)) _activeQrSwitch = null;
    });
    _activeQrSwitch = task;
    return task;
  }

  Future<void> _switchToQrLogin(int revision) async {
    try {
      await Future<void>.delayed(transitionDelay);
      if (!_isSwitchCurrent(revision)) return;
      await _openQrLogin();
    } catch (_) {
      if (_isSwitchCurrent(revision)) errorMessageKey.value = 'bilibili_qr_open_failed';
    } finally {
      if (_isSwitchCurrent(revision)) {
        isSwitchingToQr.value = false;
        showWebView.value = true;
      }
    }
  }

  void _showLoginError(String messageKey) {
    isVerifying.value = false;
    showWebView.value = true;
    errorMessageKey.value = messageKey;
  }

  bool _isLoginCurrent(int revision) {
    return !_closed && !isSwitchingToQr.value && revision == _loginRevision;
  }

  bool _isSwitchCurrent(int revision) => !_closed && revision == _switchRevision;

  @override
  void onClose() {
    _closed = true;
    _loginRevision++;
    _switchRevision++;
    webViewController = null;
    super.onClose();
  }

  static Future<String> _loadBrowserCookie(WebUri uri) async {
    final cookies = await CookieManager.instance().getCookies(url: uri);
    return cookies
        .map((cookie) => normalizeAccountCookie('${cookie.name}=${cookie.value}'))
        .where((cookie) => cookie.isNotEmpty)
        .join(';');
  }

  static Future<bool> _verifyCookie(String cookie) {
    final service = BiliBiliAccountService.instance;
    service.setCookie(cookie);
    return service.loadUserInfo();
  }

  static void _finishLogin() {
    Navigator.of(Get.context!).pop(true);
  }

  static Future<void> _navigateToQrLogin() async {
    await Get.offAndToNamed(RoutePath.kBiliBiliQRLogin);
  }
}
