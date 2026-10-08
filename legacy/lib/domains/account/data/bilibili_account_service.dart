import 'dart:async';

import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:pure_live/core/index.dart';
import 'package:pure_live/core/models/bilibili_user_info_page.dart';
import 'package:pure_live/core/network/cookie_sanitizer.dart';
import 'package:pure_live/core/network/http_client.dart';
import 'package:pure_live/core/config/cookie_settings_controller.dart';

typedef BilibiliAccountLoader = Future<Map<String, dynamic>?> Function(String cookie);
typedef BrowserCookieClearer = Future<void> Function();
typedef AccountNotice = void Function(String localizationKey);

class BiliBiliAccountService extends GetxController {
  BiliBiliAccountService({
    BilibiliAccountLoader? accountLoader,
    BrowserCookieClearer? browserCookieClearer,
    AccountNotice? notice,
    this.initialLoadDelay = const Duration(seconds: 1),
  }) : _accountLoader = accountLoader ?? _loadAccount,
       _browserCookieClearer = browserCookieClearer ?? _clearBrowserCookies,
       _notice = notice ?? _showNotice;

  static BiliBiliAccountService get instance => Get.find<BiliBiliAccountService>();

  final BilibiliAccountLoader _accountLoader;
  final BrowserCookieClearer _browserCookieClearer;
  final AccountNotice _notice;
  final Duration initialLoadDelay;

  final RxBool logined = false.obs;
  final RxString name = ''.obs;

  Timer? _initialLoadTimer;
  Worker? _cookieWorker;
  Future<bool>? _activeLoad;
  String? _activeLoadCookie;
  Future<void>? _logoutTask;
  int _loadRevision = 0;
  bool _closed = false;

  String get currentCookie => normalizeAccountCookie(CookieSettingsController.to.bilibiliCookie.v);

  @override
  void onInit() {
    super.onInit();
    _closed = false;
    final cookie = currentCookie;
    logined.value = cookie.isNotEmpty;
    if (cookie.isEmpty) _clearLocalAccountState();
    _cookieWorker = ever<String>(CookieSettingsController.to.bilibiliCookie, _handleCookieChanged);
    if (cookie.isNotEmpty) {
      _initialLoadTimer = Timer(initialLoadDelay, () => unawaited(loadUserInfo()));
    }
  }

  void _handleCookieChanged(String value) {
    _initialLoadTimer?.cancel();
    _initialLoadTimer = null;
    final normalized = normalizeAccountCookie(value);
    if (normalized != value) {
      CookieSettingsController.to.bilibiliCookie.v = normalized;
      return;
    }
    final hasCurrentLoad = normalized.isNotEmpty && _activeLoadCookie == normalized && _activeLoad != null;
    if (!hasCurrentLoad) _loadRevision++;
    logined.value = normalized.isNotEmpty;
    _clearLocalAccountState();
    if (normalized.isNotEmpty && !_closed && !hasCurrentLoad) unawaited(loadUserInfo());
  }

  Future<bool> loadUserInfo() {
    final cookie = currentCookie;
    if (cookie.isEmpty || _closed) {
      _loadRevision++;
      if (!_closed) {
        logined.value = false;
        _clearLocalAccountState();
      }
      return Future.value(false);
    }
    final activeLoad = _activeLoad;
    if (_activeLoadCookie == cookie && activeLoad != null) return activeLoad;

    final revision = ++_loadRevision;
    late final Future<bool> task;
    task = _loadAndCommit(cookie, revision).whenComplete(() {
      if (identical(_activeLoad, task)) {
        _activeLoad = null;
        _activeLoadCookie = null;
      }
    });
    _activeLoadCookie = cookie;
    _activeLoad = task;
    return task;
  }

  Future<bool> _loadAndCommit(String cookie, int revision) async {
    try {
      final result = await _accountLoader(cookie);
      if (!_isCurrent(cookie, revision)) return false;
      if (result == null) {
        _notice('bilibili_user_info_failed');
        return false;
      }
      if (result['code'] != 0) {
        _notice('bilibili_login_expired');
        await logout();
        return false;
      }
      final rawData = result['data'];
      if (rawData is! Map) {
        _notice('bilibili_user_info_failed');
        return false;
      }
      final info = BiliBiliUserInfoModel.fromJson(Map<String, dynamic>.from(rawData));
      if (!_isCurrent(cookie, revision)) return false;
      final accountName = info.uname?.trim() ?? '';
      if (accountName.isEmpty) {
        _notice('bilibili_user_info_failed');
        return false;
      }
      name.value = accountName;
      CookieSettingsController.to.bilibiliUid.value = info.mid ?? 0;
      logined.value = true;
      return true;
    } catch (_) {
      if (_isCurrent(cookie, revision)) _notice('bilibili_user_info_failed');
      return false;
    }
  }

  bool _isCurrent(String cookie, int revision) {
    return !_closed && revision == _loadRevision && currentCookie == cookie;
  }

  void setCookie(String cookie) {
    final normalized = normalizeAccountCookie(cookie);
    final storedCookie = CookieSettingsController.to.bilibiliCookie;
    if (storedCookie.v == normalized) {
      logined.value = normalized.isNotEmpty;
      if (normalized.isEmpty) {
        _loadRevision++;
        _clearLocalAccountState();
      } else if (!_closed) {
        unawaited(loadUserInfo());
      }
      return;
    }
    storedCookie.v = normalized;
  }

  Future<void> logout() {
    final activeLogout = _logoutTask;
    if (activeLogout != null) return activeLogout;
    late final Future<void> task;
    task = _performLogout().whenComplete(() {
      if (identical(_logoutTask, task)) _logoutTask = null;
    });
    _logoutTask = task;
    return task;
  }

  Future<void> _performLogout() async {
    _initialLoadTimer?.cancel();
    _initialLoadTimer = null;
    _loadRevision++;
    CookieSettingsController.to.bilibiliCookie.v = '';
    logined.value = false;
    _clearLocalAccountState();
    try {
      await _browserCookieClearer();
    } catch (_) {
      if (!_closed) _notice('bilibili_logout_cleanup_failed');
    }
  }

  void _clearLocalAccountState() {
    name.value = '';
    CookieSettingsController.to.bilibiliUid.value = 0;
  }

  @override
  void onClose() {
    _closed = true;
    _loadRevision++;
    _initialLoadTimer?.cancel();
    _cookieWorker?.dispose();
    super.onClose();
  }

  static Future<Map<String, dynamic>?> _loadAccount(String cookie) async {
    final result = await HttpClient.instance.getJson(
      'https://api.bilibili.com/x/member/web/account',
      header: {'Cookie': cookie},
    );
    if (result is! Map) return null;
    return Map<String, dynamic>.from(result);
  }

  static Future<void> _clearBrowserCookies() => CookieManager.instance().deleteAllCookies();

  static void _showNotice(String localizationKey) {
    ToastUtil.show(i18n(localizationKey));
  }
}
