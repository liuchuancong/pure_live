import 'dart:async';
import 'dart:developer' as developer;
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:pure_live/common/index.dart';
import 'package:pure_live/common/services/settings/log_controller.dart';
import 'package:pure_live/core/common/log.dart';
import 'package:pure_live/modules/search/web_search_room_parser.dart';
import 'package:pure_live/plugins/utils.dart';
import 'package:pure_live/routes/app_navigation.dart';
import 'package:url_launcher/url_launcher.dart';

enum WebSearchViewStatus { loading, ready, failed }

enum WebSearchBackDisposition { stayOnPage, closePage }

class WebSearchLaunchRequest {
  const WebSearchLaunchRequest({required this.uri, required this.platform});

  final Uri uri;
  final String platform;
}

WebSearchLaunchRequest? parseWebSearchLaunchRequest(Object? arguments) {
  if (arguments is! Map) return null;
  final rawUrl = arguments['url'];
  final rawPlatform = arguments['platform'];
  if (rawUrl is! String || rawPlatform is! String) return null;
  final uri = Uri.tryParse(rawUrl.trim());
  final platform = rawPlatform.trim().toLowerCase();
  if (uri == null ||
      (uri.scheme != 'http' && uri.scheme != 'https') ||
      uri.host.trim().isEmpty ||
      uri.userInfo.isNotEmpty ||
      platform.isEmpty) {
    return null;
  }
  return WebSearchLaunchRequest(uri: uri, platform: platform);
}

abstract interface class WebSearchBrowser {
  Future<void> load(Uri uri);

  Future<void> reload();

  Future<bool> canGoBack();

  Future<void> goBack();

  Future<void> stopLoading();

  Future<void> openDevTools();

  void dispose();
}

class _InAppWebSearchBrowser implements WebSearchBrowser {
  const _InAppWebSearchBrowser(this.controller);

  final InAppWebViewController controller;

  @override
  Future<void> load(Uri uri) => controller.loadUrl(urlRequest: URLRequest(url: WebUri(uri.toString())));

  @override
  Future<void> reload() => controller.reload();

  @override
  Future<bool> canGoBack() => controller.canGoBack();

  @override
  Future<void> goBack() => controller.goBack();

  @override
  Future<void> stopLoading() => controller.stopLoading();

  @override
  Future<void> openDevTools() => controller.openDevTools();

  @override
  void dispose() => controller.dispose();
}

typedef WebSearchExternalLauncher = Future<bool> Function(Uri uri);
typedef WebSearchRoomConfirmation = Future<bool?> Function(WebSearchRoomTarget target);
typedef WebSearchRoomOpener = Future<void> Function(LiveRoom room);
typedef WebSearchCookieFlusher = Future<void> Function();
typedef WebSearchNotice = void Function(String localizationKey);

class WebSearchController extends GetxController {
  WebSearchController({
    this.initialArguments,
    this.useExternalBrowser,
    WebSearchExternalLauncher? launchExternal,
    WebSearchRoomConfirmation? confirmRoom,
    WebSearchRoomOpener? openRoom,
    WebSearchCookieFlusher? flushCookies,
    WebSearchNotice? notice,
  }) : _launchExternal = launchExternal ?? _defaultLaunchExternal,
       _confirmRoom = confirmRoom ?? _defaultConfirmRoom,
       _openRoom = openRoom ?? _defaultOpenRoom,
       _flushCookies = flushCookies ?? _defaultFlushCookies,
       _notice = notice ?? _defaultNotice;

  final Object? initialArguments;
  final bool? useExternalBrowser;
  final WebSearchExternalLauncher _launchExternal;
  final WebSearchRoomConfirmation _confirmRoom;
  final WebSearchRoomOpener _openRoom;
  final WebSearchCookieFlusher _flushCookies;
  final WebSearchNotice _notice;

  WebSearchLaunchRequest? launchRequest;
  final roomId = ''.obs;
  final showWebView = true.obs;
  final viewStatus = WebSearchViewStatus.loading.obs;
  final errorMessageKey = ''.obs;
  final loadProgress = 0.obs;
  final isOpeningExternal = false.obs;

  WebSearchBrowser? _browser;
  InAppWebViewController? _nativeController;
  WebSearchRoomTarget? _pendingTarget;
  String? _observedTargetKey;
  String? _dismissedTarget;
  Future<void>? _promptOperation;
  Future<void>? _externalOpenOperation;
  Future<WebSearchBackDisposition>? _backOperation;
  Future<void>? _closeOperation;
  int _generation = 0;
  bool _closed = false;

  bool get usesExternalBrowser => useExternalBrowser ?? Platform.isLinux;

  bool get hasValidLaunchRequest => launchRequest != null;

  Uri? get initialUri => launchRequest?.uri;

  String getDynamicUserAgent() {
    return 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) '
        'AppleWebKit/537.36 (KHTML, like Gecko) Chrome/123.0.0.0 Safari/537.36';
  }

  @override
  void onInit() {
    super.onInit();
    _closed = false;
    final arguments = initialArguments ?? Get.arguments;
    launchRequest = parseWebSearchLaunchRequest(arguments);
    final request = launchRequest;
    if (request == null) {
      showWebView.value = false;
      _setFailure('web_search_invalid_address');
      _logWarning('[WebSearch] Rejected invalid launch arguments.');
      return;
    }
    _logInfo('[WebSearch] Initialized for ${request.uri.scheme}://${request.uri.host} (${request.platform}).');
  }

  Future<void> openExternalBrowser() {
    final existing = _externalOpenOperation;
    if (existing != null) return existing;
    final request = launchRequest;
    if (_closed || request == null) {
      if (!_closed) _notice('web_search_invalid_address');
      return Future.value();
    }

    final generation = _generation;
    isOpeningExternal.value = true;
    late final Future<void> task;
    task = _openExternal(request.uri, generation).whenComplete(() {
      if (identical(_externalOpenOperation, task)) {
        _externalOpenOperation = null;
        if (_isCurrent(generation)) isOpeningExternal.value = false;
      }
    });
    _externalOpenOperation = task;
    return task;
  }

  Future<void> _openExternal(Uri uri, int generation) async {
    var opened = false;
    try {
      opened = await _launchExternal(uri);
    } catch (error) {
      debugPrint('[WebSearch] External browser launch failed: $error');
    }
    if (_isCurrent(generation) && !opened) _notice('external_browser_not_opened');
  }

  void onWebViewCreated(InAppWebViewController controller) {
    _nativeController = controller;
    unawaited(attachBrowser(_InAppWebSearchBrowser(controller), nativeController: controller));
  }

  @visibleForTesting
  Future<void> attachBrowser(WebSearchBrowser browser, {InAppWebViewController? nativeController}) async {
    final request = launchRequest;
    if (_closed || request == null || usesExternalBrowser) {
      await _disposeSpecificBrowser(browser);
      return;
    }

    final previous = _browser;
    _browser = browser;
    _nativeController = nativeController;
    if (previous != null && !identical(previous, browser)) {
      await _disposeSpecificBrowser(previous);
    }
    if (_closed || !identical(_browser, browser)) return;

    _beginMainFrameLoad();
    try {
      await browser.load(request.uri);
    } catch (error) {
      if (!_closed && identical(_browser, browser)) {
        debugPrint('[WebSearch] Initial page load failed: $error');
        _setFailure('web_search_load_failed');
      }
    }
  }

  void onLoadStart(InAppWebViewController controller, WebUri? uri) {
    if (!_acceptNativeController(controller)) return;
    final documentUri = _parseHttpUri(uri?.toString());
    if (documentUri == null) return;
    _beginMainFrameLoad();
    unawaited(observeUrl(documentUri.toString()));
  }

  void onUpdateVisitedHistory(InAppWebViewController controller, WebUri? uri, bool? isReload) {
    if (!_acceptNativeController(controller) || uri == null) return;
    unawaited(observeUrl(uri.toString()));
  }

  Future<void> onLoadStop(InAppWebViewController controller, WebUri? uri) async {
    if (!_acceptNativeController(controller)) return;
    final documentUri = _parseHttpUri(uri?.toString());
    if (documentUri == null) return;
    if (errorMessageKey.value.isEmpty) {
      viewStatus.value = WebSearchViewStatus.ready;
      loadProgress.value = 100;
    }
    unawaited(observeUrl(documentUri.toString()));

    final generation = _generation;
    try {
      await _flushCookies();
      if (_isCurrent(generation)) _logInfo('[WebSearch] Persisted browser cookies.');
    } catch (error) {
      debugPrint('[WebSearch] Cookie flush failed: $error');
    }
  }

  void onProgressChanged(InAppWebViewController controller, int progress) {
    if (!_acceptNativeController(controller) || viewStatus.value == WebSearchViewStatus.failed) return;
    loadProgress.value = progress.clamp(0, 100);
  }

  void onReceivedHttpError(
    InAppWebViewController controller,
    WebResourceRequest request,
    WebResourceResponse response,
  ) {
    if (!_acceptNativeController(controller) || request.isForMainFrame != true) return;
    final uri = _parseHttpUri(request.url.toString());
    _logWarning('[WebSearch] Main document HTTP status ${response.statusCode} from ${uri?.host ?? 'unknown host'}.');
    _setFailure('web_search_load_failed');
  }

  void onReceivedError(InAppWebViewController controller, WebResourceRequest request, WebResourceError error) {
    if (!_acceptNativeController(controller) || request.isForMainFrame != true) return;
    final uri = _parseHttpUri(request.url.toString());
    _logWarning('[WebSearch] Main document load error on ${uri?.host ?? 'unknown host'} (${error.type}).');
    _setFailure('web_search_load_failed');
  }

  Future<ServerTrustAuthResponse?> onReceivedServerTrustAuthRequest(
    InAppWebViewController controller,
    URLAuthenticationChallenge challenge,
  ) async {
    if (_acceptNativeController(controller)) {
      _logWarning('[WebSearch] Rejected an untrusted certificate for ${challenge.protectionSpace.host}.');
    }
    return ServerTrustAuthResponse(action: ServerTrustAuthResponseAction.CANCEL);
  }

  void onConsoleMessage(InAppWebViewController controller, ConsoleMessage consoleMessage) {
    if (kDebugMode && _acceptNativeController(controller) && consoleMessage.messageLevel == ConsoleMessageLevel.ERROR) {
      debugPrint('[WebSearch] Browser console reported an error.');
    }
  }

  Future<NavigationActionPolicy> shouldOverrideUrlLoading(
    InAppWebViewController controller,
    NavigationAction action,
  ) async {
    if (!_acceptNativeController(controller)) return NavigationActionPolicy.CANCEL;
    final uri = action.request.url;
    final documentUri = _parseHttpUri(uri?.toString());
    if (documentUri == null) {
      _logWarning('[WebSearch] Blocked a non-HTTP(S) navigation request.');
      return NavigationActionPolicy.CANCEL;
    }
    unawaited(observeUrl(documentUri.toString()));
    return NavigationActionPolicy.ALLOW;
  }

  Future<void> observeUrl(String rawUrl) {
    if (_closed) return Future.value();
    final uri = _parseHttpUri(rawUrl.trim().replaceAll(RegExp(r'[\r\n\t]'), ''));
    if (uri == null) return Future.value();
    final target = WebSearchRoomParser.parse(uri.toString());
    if (target == null) {
      _observedTargetKey = null;
      _pendingTarget = null;
      _dismissedTarget = null;
      return Future.value();
    }
    _observedTargetKey = target.key;
    if (_dismissedTarget == target.key) return Future.value();

    _pendingTarget = target;
    final existing = _promptOperation;
    if (existing != null) return existing;
    final generation = _generation;
    late final Future<void> task;
    task = _drainPromptQueue(generation).whenComplete(() {
      if (identical(_promptOperation, task)) _promptOperation = null;
    });
    _promptOperation = task;
    return task;
  }

  Future<void> _drainPromptQueue(int generation) async {
    while (_isCurrent(generation)) {
      final target = _pendingTarget;
      _pendingTarget = null;
      if (target == null) return;
      if (_dismissedTarget == target.key) continue;

      roomId.value = target.roomId;
      developer.log('[WebSearch] Detected a supported ${target.platform} room link.');
      bool? confirmed;
      try {
        confirmed = await _confirmRoom(target);
      } catch (error) {
        debugPrint('[WebSearch] Room confirmation failed: $error');
      }
      if (!_isCurrent(generation)) return;
      // A dialog can outlive the document that discovered it. A later room
      // will be drained next; a non-room navigation clears the pending target.
      if (_observedTargetKey != target.key) continue;
      if (confirmed != true) {
        _dismissedTarget = target.key;
        continue;
      }

      _pendingTarget = null;
      showWebView.value = false;
      await _disposeBrowser();
      if (!_isCurrent(generation)) return;
      try {
        await _openRoom(LiveRoom(roomId: target.roomId, platform: target.platform));
      } catch (error) {
        if (!_isCurrent(generation)) return;
        debugPrint('[WebSearch] Opening the detected room failed: $error');
        _setFailure('get_room_info_failed_retry');
        showWebView.value = true;
        _notice('get_room_info_failed_retry');
      }
      return;
    }
  }

  Future<void> retry() async {
    final request = launchRequest;
    if (_closed || request == null) return;
    errorMessageKey.value = '';
    viewStatus.value = WebSearchViewStatus.loading;
    loadProgress.value = 0;
    showWebView.value = true;
    final browser = _browser;
    if (browser == null) return;
    try {
      await browser.reload();
    } catch (error) {
      if (!_closed && identical(_browser, browser)) {
        debugPrint('[WebSearch] Page reload failed: $error');
        _setFailure('web_search_load_failed');
      }
    }
  }

  Future<void> openDevTools() async {
    if (!kDebugMode || _closed) return;
    try {
      await _browser?.openDevTools();
    } catch (error) {
      debugPrint('[WebSearch] Developer tools failed to open: $error');
    }
  }

  Future<WebSearchBackDisposition> requestBack() {
    final existing = _backOperation;
    if (existing != null) return existing;
    late final Future<WebSearchBackDisposition> task;
    task = _performBack().whenComplete(() {
      if (identical(_backOperation, task)) _backOperation = null;
    });
    _backOperation = task;
    return task;
  }

  Future<WebSearchBackDisposition> _performBack() async {
    if (_closed) return WebSearchBackDisposition.closePage;
    final browser = _browser;
    if (browser != null) {
      try {
        if (await browser.canGoBack()) {
          if (_closed || !identical(_browser, browser)) return WebSearchBackDisposition.closePage;
          await browser.goBack();
          return WebSearchBackDisposition.stayOnPage;
        }
      } catch (error) {
        debugPrint('[WebSearch] Browser history navigation failed: $error');
      }
    }
    await closeWebSearch();
    return WebSearchBackDisposition.closePage;
  }

  Future<void> closeWebSearch() {
    final existing = _closeOperation;
    if (existing != null) return existing;
    _closed = true;
    _generation++;
    _pendingTarget = null;
    _observedTargetKey = null;
    showWebView.value = false;
    isOpeningExternal.value = false;
    late final Future<void> task;
    task = _disposeBrowser().whenComplete(() {
      if (identical(_closeOperation, task)) _closeOperation = null;
    });
    _closeOperation = task;
    return task;
  }

  void _beginMainFrameLoad() {
    errorMessageKey.value = '';
    viewStatus.value = WebSearchViewStatus.loading;
    loadProgress.value = 0;
  }

  void _setFailure(String localizationKey) {
    errorMessageKey.value = localizationKey;
    viewStatus.value = WebSearchViewStatus.failed;
  }

  bool _acceptNativeController(InAppWebViewController controller) {
    return !_closed && identical(_nativeController, controller);
  }

  bool _isCurrent(int generation) => !_closed && generation == _generation;

  Uri? _parseHttpUri(String? raw) {
    if (raw == null) return null;
    final uri = Uri.tryParse(raw);
    if (uri == null || (uri.scheme != 'http' && uri.scheme != 'https') || uri.host.isEmpty) return null;
    return uri;
  }

  Future<void> _disposeBrowser() async {
    final browser = _browser;
    _browser = null;
    _nativeController = null;
    if (browser != null) await _disposeSpecificBrowser(browser);
  }

  Future<void> _disposeSpecificBrowser(WebSearchBrowser browser) async {
    try {
      await browser.stopLoading();
    } catch (error) {
      debugPrint('[WebSearch] Stopping the browser failed: $error');
    }
    try {
      browser.dispose();
    } catch (error) {
      debugPrint('[WebSearch] Disposing the browser failed: $error');
    }
  }

  @override
  void onClose() {
    if (!_closed) {
      _closed = true;
      _generation++;
      _pendingTarget = null;
      _observedTargetKey = null;
      showWebView.value = false;
    }
    unawaited(_disposeBrowser());
    super.onClose();
  }

  static Future<bool> _defaultLaunchExternal(Uri uri) {
    return launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  static Future<bool?> _defaultConfirmRoom(WebSearchRoomTarget target) {
    return Utils.showAlertDialog(
      i18n('detected_room_id_open'),
      title: i18n('tip'),
      confirm: i18n('confirm'),
      cancel: i18n('cancel'),
    );
  }

  static Future<void> _defaultOpenRoom(LiveRoom room) {
    return AppNavigator.offAndToRoomDetail(liveRoom: room);
  }

  static Future<void> _defaultFlushCookies() {
    return CookieManager.instance().flush();
  }

  static void _defaultNotice(String localizationKey) {
    ToastUtil.show(i18n(localizationKey));
  }

  static void _logInfo(String message) {
    if (Get.isRegistered<LogController>()) {
      Log.i(message);
    } else {
      debugPrint(message);
    }
  }

  static void _logWarning(String message) {
    if (Get.isRegistered<LogController>()) {
      Log.w(message);
    } else {
      debugPrint(message);
    }
  }
}
