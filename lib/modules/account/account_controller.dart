import 'dart:async';

import 'package:pure_live/common/index.dart';
import 'package:pure_live/common/services/settings/bilibili_account_service.dart';
import 'package:pure_live/common/services/settings/cookie_value.dart';
import 'package:pure_live/core/common/log.dart';
import 'package:pure_live/core/site/douyin/douyin_site.dart';
import 'package:pure_live/plugins/utils.dart';
import 'package:pure_live/routes/app_navigation.dart';

typedef DouyinAccountLoader = Future<Map<String, dynamic>> Function(String cookie);

class AccountController extends GetxController {
  AccountController({
    DouyinAccountLoader? douyinAccountLoader,
    this.initialLoadDelay = const Duration(milliseconds: 300),
  }) : _douyinAccountLoader = douyinAccountLoader ?? _loadDouyinAccount;

  final DouyinAccountLoader _douyinAccountLoader;
  final Duration initialLoadDelay;
  final cookie = SettingsService.to.cookieManager;
  final douyinNickName = ''.obs;

  Timer? _initialLoadTimer;
  Worker? _cookieWorker;
  Future<void>? _activeLoad;
  String? _activeLoadCookie;
  Future<void>? _logoutTransaction;
  int _loadRevision = 0;
  bool _closed = false;

  @override
  void onInit() {
    super.onInit();
    _closed = false;
    _cookieWorker = ever<String>(cookie.douyinCookie, _handleDouyinCookieChanged);
    _initialLoadTimer = Timer(initialLoadDelay, () => unawaited(loadDouyinAccount()));
  }

  void _handleDouyinCookieChanged(String _) {
    _initialLoadTimer?.cancel();
    _initialLoadTimer = null;
    final currentCookie = normalizeAccountCookie(cookie.douyinCookie.v);
    final hasCurrentLoad = currentCookie.isNotEmpty && _activeLoadCookie == currentCookie && _activeLoad != null;
    if (!hasCurrentLoad) _loadRevision++;
    douyinNickName.value = '';
    if (currentCookie.isNotEmpty && !_closed && !hasCurrentLoad) {
      unawaited(loadDouyinAccount());
    }
  }

  Future<void> bilibiliTap() async {
    if (BiliBiliAccountService.instance.logined.value) {
      final result = await Utils.showAlertDialog(i18n('logout_bilibili_confirm'), title: i18n('logout'));
      if (result) await BiliBiliAccountService.instance.logout();
    } else {
      AppNavigator.toBiliBiliLogin();
    }
  }

  Future<void> runLogoutTransaction(Future<void> Function() transaction) {
    if (_closed) return Future.value();
    final activeTransaction = _logoutTransaction;
    if (activeTransaction != null) return activeTransaction;

    late final Future<void> task;
    task = Future<void>.sync(transaction).whenComplete(() {
      if (identical(_logoutTransaction, task)) _logoutTransaction = null;
    });
    _logoutTransaction = task;
    return task;
  }

  Future<void> loadDouyinAccount() {
    final requestCookie = normalizeAccountCookie(cookie.douyinCookie.v);
    if (requestCookie.isEmpty || _closed) {
      _loadRevision++;
      if (!_closed) douyinNickName.value = '';
      return Future.value();
    }
    final activeLoad = _activeLoad;
    if (_activeLoadCookie == requestCookie && activeLoad != null) return activeLoad;

    final revision = ++_loadRevision;
    late final Future<void> task;
    task = _loadAndCommitDouyinAccount(requestCookie, revision).whenComplete(() {
      if (identical(_activeLoad, task)) {
        _activeLoad = null;
        _activeLoadCookie = null;
      }
    });
    _activeLoadCookie = requestCookie;
    _activeLoad = task;
    return task;
  }

  Future<void> _loadAndCommitDouyinAccount(String requestCookie, int revision) async {
    try {
      final result = await _douyinAccountLoader(requestCookie);
      if (!_isCurrentDouyinRequest(requestCookie, revision)) return;
      final rawNickname = result['nickname'];
      douyinNickName.value = rawNickname is String ? rawNickname.trim() : '';
    } catch (error, stack) {
      if (_isCurrentDouyinRequest(requestCookie, revision)) {
        Log.e('Load Douyin account failed: $error', stack);
      }
    }
  }

  bool _isCurrentDouyinRequest(String requestCookie, int revision) {
    return !_closed && revision == _loadRevision && normalizeAccountCookie(cookie.douyinCookie.v) == requestCookie;
  }

  @override
  void onClose() {
    _closed = true;
    _loadRevision++;
    _initialLoadTimer?.cancel();
    _cookieWorker?.dispose();
    super.onClose();
  }

  static Future<Map<String, dynamic>> _loadDouyinAccount(String cookie) {
    return DouyinSite().getUserInfoByCookie(cookie);
  }
}
