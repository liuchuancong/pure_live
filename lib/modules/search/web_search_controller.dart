import 'package:get/get.dart';
import 'dart:developer' as developer;
import 'package:flutter/foundation.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

class WebSearchController extends GetxController {
  InAppWebViewController? webViewController;
  final CookieManager cookieManager = CookieManager.instance();

  late String url;
  var loading = true.obs;

  var roomId = ''.obs;

  @override
  void onInit() {
    super.onInit();
    url = Get.arguments ?? "";
    developer.log("init url: $url");
  }

  String getDynamicUserAgent() {
    if (kIsWeb) {
      return "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 Chrome/120 Safari/537.36";
    }

    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
      case TargetPlatform.iOS:
        return "Mozilla/5.0 (iPhone; CPU iPhone OS 15_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/15.0 Mobile/15E148 Safari/604.1";

      case TargetPlatform.windows:
      case TargetPlatform.macOS:
      case TargetPlatform.linux:
      default:
        return "Mozilla/5.0 (iPhone; CPU iPhone OS 15_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/15.0 Mobile/15E148 Safari/604.1";
    }
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

  void onLoadStop(InAppWebViewController controller, WebUri? uri) {
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

  void _parseRoomId(String url) {
    try {
      if (url.isEmpty) return;

      // 1. 强力清洗 Windows 底层可能附带的各种乱码、换行符和前后空格
      final cleanUrl = url.trim().replaceAll(RegExp(r'[\r\n\t]'), '');

      // 2. 必须是 http 网页访问才处理，防止误拦截 App 协议
      if (!cleanUrl.toLowerCase().contains('http')) return;

      developer.log("开始处理底层传递的干净 URL: $cleanUrl");

      // 🔥 核心逻辑：先检查整个 URL 是否包含已知的视频或功能保留词，如果是则直接拒绝，防止把视频ID当成房间号
      final lowerUrl = cleanUrl.toLowerCase();
      final systemKeywords = ['/video/', '/g/', '/u/', '/member', '/search', '/category', '/topic'];
      for (var keyword in systemKeywords) {
        if (lowerUrl.contains(keyword)) {
          developer.log("⚠️ 检测到系统非直播页面 ($keyword)，跳过解析");
          return;
        }
      }

      String? id;

      // ========================================================
      // 🎯 万能降维算法：直接用正则强行抓取【整条 URL 里最后的一串连续数字】
      // 无论是 m.huya.com/196645 还是 douyu.com...
      // 它们的核心直播间房间号永远是 URL 路由部分最后的纯数字段
      // ========================================================

      // 先把 URL 按照问号 ? 和井号 # 切开，只在前半段路径里找数字，完美规避后面参数里的数字干扰
      final pathOnly = cleanUrl.split('?').first.split('#').first;

      final Iterable<Match> matches = RegExp(r'\d+').allMatches(pathOnly);
      if (matches.isNotEmpty) {
        id = matches.last.group(0); // 拿到最后出现的数字，即房间号
      }

      // ========================================================
      // 🛑 全局洗净与数据状态提交
      // ========================================================
      if (id != null) {
        id = id.trim();

        // 保守兜底黑名单
        final blackList = ['search', 'category', 'game', 'video', 'user', 'index', 'topic', 'member'];
        if (blackList.contains(id.toLowerCase())) return;

        // 成功提取并确保与旧值不同，更新 observable 状态
        if (id.isNotEmpty && roomId.value != id) {
          roomId.value = id;
          developer.log("🎯 【万能数字榨取算法】绝对成功! 捕获到 roomId: $id");
        }
      }
    } catch (e, stack) {
      developer.log("🔥 核心底层解析发生未知异常: $e", stackTrace: stack);
    }
  }

  // ==============================
  void goBack() async {
    if (await webViewController?.canGoBack() ?? false) {
      webViewController?.goBack();
    } else {
      Get.back();
    }
  }

  // ==============================
  // 🧹 生命周期
  // ==============================
  @override
  void onClose() {
    webViewController?.stopLoading();
    webViewController = null;
    super.onClose();
  }
}
