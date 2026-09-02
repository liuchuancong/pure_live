import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:pure_live/common/index.dart';
import 'package:pure_live/core/common/cookie_string.dart';
import 'package:pure_live/modules/account/cookie_validator.dart';

/// 平台抓取配置：登录页地址与 Cookie 归属域名。
class CookieCaptureTarget {
  const CookieCaptureTarget({required this.platform, required this.loginUrl, required this.domains});

  /// 平台标识（与账户模块一致），用于抓取后经平台接口校验登录态。
  final String platform;

  /// 打开的登录页/站点地址。
  final String loginUrl;

  /// Cookie 归属域名（后缀匹配，如 'twitch.tv' 匹配 '.twitch.tv'）。
  final List<String> domains;
}

/// 各平台抓取配置（key 与账户模块的平台标识一致）。
const Map<String, CookieCaptureTarget> kCookieCaptureTargets = {
  'douyin': CookieCaptureTarget(platform: 'douyin', loginUrl: 'https://www.douyin.com/', domains: ['douyin.com']),
  'huya': CookieCaptureTarget(platform: 'huya', loginUrl: 'https://www.huya.com/', domains: ['huya.com']),
  'kuaishou': CookieCaptureTarget(
    platform: 'kuaishou',
    loginUrl: 'https://www.kuaishou.com/',
    domains: ['kuaishou.com'],
  ),
  'soop': CookieCaptureTarget(platform: 'soop', loginUrl: 'https://www.sooplive.co.kr/', domains: ['sooplive.co.kr']),
  'twitch': CookieCaptureTarget(platform: 'twitch', loginUrl: 'https://www.twitch.tv/login', domains: ['twitch.tv']),
};

/// 按 [domains] 过滤并组装 `name=value; ...`；同名 Cookie 后值覆盖前值。
String? assembleCookieString(List<Cookie> cookies, List<String> domains) {
  final byName = <String, String>{};
  for (final cookie in cookies) {
    if (cookie.name.isEmpty) continue;
    if (!cookieDomainMatches(cookie.domain ?? '', domains)) continue;
    byName[cookie.name] = cookie.value?.toString() ?? '';
  }
  if (byName.isEmpty) return null;
  return byName.entries.map((e) => '${e.key}=${e.value}').join('; ');
}

/// 内置浏览器（InAppWebView）Cookie 抓取。
///
/// 打开全屏网页加载平台登录页，用户在页面内完成登录后点击
/// 「我已登录完成」，经 [CookieManager] 按域名过滤组装
/// `name=value; ...`，再经平台接口校验登录态后返回。
class WebCookieCapturePage extends StatefulWidget {
  const WebCookieCapturePage({super.key, required this.target});

  final CookieCaptureTarget target;

  /// 打开内置浏览器抓取页并等待用户完成登录；
  /// 捕获成功返回 Cookie 字符串，返回/取消返回 null。
  static Future<String?> capture(CookieCaptureTarget target) async {
    return Get.to<String>(() => WebCookieCapturePage(target: target));
  }

  @override
  State<WebCookieCapturePage> createState() => _WebCookieCapturePageState();
}

class _WebCookieCapturePageState extends State<WebCookieCapturePage> {
  bool _busy = false;
  bool _showWebView = true;

  /// 当前页面的 WebView 控制器。Windows 上 CookieManager 未绑定控制器时
  /// 会创建并销毁一个临时 WebView2，该路径在 ICoreWebView2 内部有已知
  /// 崩溃；所有 Cookie 读写必须绑定此控制器走当前 WebView。
  InAppWebViewController? _webViewController;

  CookieCaptureTarget get target => widget.target;

  Future<void> _completeLogin() async {
    final controller = _webViewController;
    if (_busy || controller == null) return;
    setState(() => _busy = true);
    try {
      final cookies = await CookieManager.instance().getCookies(
        url: WebUri(target.loginUrl),
        webViewController: controller,
      );
      final cookie = assembleCookieString(cookies, target.domains);
      if (!mounted) return;
      if (cookie == null || cookie.isEmpty) {
        ToastUtil.show(i18n('cookie_capture_empty_hint'));
        return;
      }
      final validation = await CookieValidator.validate(target.platform, cookie);
      if (!mounted) return;
      switch (validation) {
        case CookieValidationStatus.valid || CookieValidationStatus.unverified:
          // 返回前先把 WebView 从控件树移除并等待若干帧。若带着平台视图
          // 直接 pop，视图会在路由转场动画帧中被引擎合成器销毁，
          // Windows 上触发 flutter_windows.dll 内的访问违规崩溃
          // （与网络搜索页关闭前的处理一致）。
          controller.stopLoading();
          controller.dispose();
          setState(() => _showWebView = false);
          await Future.delayed(const Duration(milliseconds: 500));
          if (!mounted) return;
          Navigator.of(context).pop(cookie);
        case CookieValidationStatus.invalid:
          ToastUtil.show(i18n('cookie_invalid_retry'));
        case CookieValidationStatus.error:
          ToastUtil.show(i18n('cookie_check_failed'));
      }
    } catch (_) {
      if (mounted) ToastUtil.show(i18n('cookie_check_failed'));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(i18n('cookie_capture_title')),
        actions: [
          TextButton(
            onPressed: _busy || _webViewController == null ? null : _completeLogin,
            child: Text(i18n('cookie_capture_done_button')),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            color: theme.colorScheme.primary.withValues(alpha: 0.06),
            child: Text(
              '${i18n('cookie_capture_waiting')}\n${i18n('cookie_capture_waiting_hint')}',
              style: AppTextStyles.t12.copyWith(color: theme.colorScheme.onSurfaceVariant, height: 1.5),
            ),
          ),
          Expanded(
            child: _showWebView
                ? InAppWebView(
                    initialUrlRequest: URLRequest(url: WebUri(target.loginUrl)),
                    onWebViewCreated: (controller) => setState(() => _webViewController = controller),
                    initialSettings: InAppWebViewSettings(
                      userAgent: "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/123.0.0.0 Safari/537.36",
                      javaScriptEnabled: true,
                      useWideViewPort: true,
                      loadWithOverviewMode: true,
                      supportZoom: true,
                      builtInZoomControls: true,
                      displayZoomControls: false,
                      domStorageEnabled: true,
                      databaseEnabled: true,
                      thirdPartyCookiesEnabled: true,
                      cacheEnabled: true,
                    ),
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}
