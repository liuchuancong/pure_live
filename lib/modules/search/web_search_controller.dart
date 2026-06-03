import 'dart:developer' as developer;
import 'package:pure_live/common/index.dart';
import 'package:pure_live/plugins/utils.dart';
import 'package:pure_live/routes/app_navigation.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

class WebSearchController extends GetxController {
  InAppWebViewController? webViewController;
  final CookieManager cookieManager = CookieManager.instance();

  late String url;
  late String platform;
  var loading = true.obs;
  var roomId = ''.obs;
  bool _isShowingDialog = false;

  @override
  void onInit() {
    super.onInit();
    final Map args = Get.arguments;
    url = args['url'];
    platform = args['platform'];
  }

  String getDynamicUserAgent() {
    return "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/123.0.0.0 Safari/537.36";
  }

  void onWebViewCreated(InAppWebViewController controller) {
    webViewController = controller;
    webViewController!.loadUrl(urlRequest: URLRequest(url: WebUri(url)));
  }

  void onLoadStart(InAppWebViewController controller, WebUri? uri) {
    loading.value = true;
    if (uri != null) {
      developer.log("🚀 页面开始加载/跳转: ${uri.toString()}");
      _parseRoomId(uri.toString());
    }
  }

  void onUpdateVisitedHistory(InAppWebViewController controller, WebUri? uri, bool? isReload) {
    if (uri != null) {
      developer.log("📜 历史记录变更（SPA跳转）: ${uri.toString()}");
      _parseRoomId(uri.toString());
    }
  }

  Future<void> onLoadStop(InAppWebViewController controller, WebUri? uri) async {
    try {
      final cookieManager = CookieManager.instance();
      await cookieManager.flush(); // 🚀 强行落盘持久化
      developer.log("🍪 网页登录状态和本地 Cookies 已成功强行保存到磁盘。");
    } catch (e) {
      developer.log("⚠️ 强行保存凭证时遇到小警告: $e");
    }
    loading.value = false;
    if (uri != null) {
      _parseRoomId(uri.toString());
    }
  }

  Future<NavigationActionPolicy> shouldOverrideUrlLoading(
    InAppWebViewController controller,
    NavigationAction action,
  ) async {
    final uri = action.request.url;
    if (uri != null) {
      final link = uri.toString();
      developer.log("点击链接: $link");
      _parseRoomId(link);
    }
    return NavigationActionPolicy.ALLOW;
  }

  void _parseRoomId(String url) async {
    if (url.isEmpty) return;

    final cleanUrl = url.trim().replaceAll(RegExp(r'[\r\n\t]'), '');
    if (cleanUrl.startsWith('about:blank') || !cleanUrl.toLowerCase().contains('http')) {
      return;
    }
    String? result;

    try {
      final uri = Uri.parse(cleanUrl);
      final host = uri.host.toLowerCase();

      if (host.endsWith('huya.com')) {
        if (cleanUrl.contains('/search')) {
          developer.log("⚠️ 虎牙非直播页面，跳过");
          return;
        }
        final match = RegExp(r'^\/(\d+)').firstMatch(uri.path);
        result = match?.group(1);
      } else if (host == 'live.douyin.com') {
        final match = RegExp(r'^\/(\d+)').firstMatch(uri.path);
        result = match?.group(1);
      } else if (host.endsWith('douyu.com')) {
        final match = RegExp(r'^\/(\d+)').firstMatch(uri.path);
        result = match?.group(1);
      } else if (host == 'live.kuaishou.com') {
        final match = RegExp(r'\/u\/([^/?#]+)').firstMatch(uri.path);
        result = match?.group(1);
      } else if (host == 'cc.163.com') {
        final match = RegExp(r'^\/(\d+)').firstMatch(uri.path);
        result = match?.group(1);
      } else if (host == 'live.bilibili.com') {
        final match = RegExp(r'^\/(\d+)').firstMatch(uri.path);
        result = match?.group(1);
      } else {
        developer.log("⚠️ 非支持平台，跳过");
        return;
      }

      if (result != null && result.isNotEmpty) {
        final blackList = ['search', 'category', 'game', 'video', 'user', 'index', 'topic'];
        if (blackList.contains(result.toLowerCase())) {
          result = null;
        }
      }

      if (result != null && result.isNotEmpty) {
        if (_isShowingDialog) {
          developer.log("⏳ 弹窗处理中，拦截重复调用");
          return;
        }
        _isShowingDialog = true;

        roomId.value = result;
        developer.log("🎯 捕获到 roomId: $result");

        bool? confirm = await Utils.showAlertDialog(
          i18n("detected_room_id_open"),
          title: i18n("tip"),
          confirm: i18n("confirm"),
          cancel: i18n("cancel"),
        );

        if (confirm == true) {
          webViewController?.stopLoading();
          AppNavigator.offAndToRoomDetail(
            liveRoom: LiveRoom(roomId: roomId.value, platform: platform),
          );
        } else {
          _isShowingDialog = false;
        }
      }
    } catch (e) {
      developer.log("🔥 解析异常: $e");
      _isShowingDialog = false;
    }
  }

  void goBack() async {
    if (await webViewController?.canGoBack() ?? false) {
      webViewController?.goBack();
    } else {
      Navigator.pop(Get.context!);
    }
  }

  void closePage() {
    webViewController?.stopLoading();
    Navigator.pop(Get.context!);
  }

  @override
  void onClose() {
    webViewController?.stopLoading();
    webViewController = null;
    super.onClose();
  }
}
