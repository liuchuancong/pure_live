import 'web_search_controller.dart';

import 'package:pure_live/common/index.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

class WebSearchPage extends GetView<WebSearchController> {
  const WebSearchPage({super.key});

  @override
  Widget build(BuildContext context) {
    if (controller.usesExternalBrowser) {
      return Scaffold(
        appBar: AppBar(title: Text(i18n("web_search"))),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.open_in_browser_rounded, size: 48),
                const SizedBox(height: 16),
                Text(i18n('linux_web_search_external_tip'), textAlign: TextAlign.center),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: controller.openExternalBrowser,
                  icon: const Icon(Icons.open_in_new_rounded),
                  label: Text(i18n('open_in_system_browser')),
                ),
              ],
            ),
          ),
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: Text(i18n("web_search")),
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: controller.goBack),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: IconButton(
              icon: const Icon(Icons.close),
              tooltip: i18n('close'),
              onPressed: () => controller.closePage(),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: IconButton(
              icon: const Icon(Icons.bug_report),
              onPressed: () async {
                await controller.webViewController?.openDevTools();
              },
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: Obx(() {
              if (!controller.showWebView.value) {
                return const SizedBox.shrink();
              }

              return InAppWebView(
                onWebViewCreated: controller.onWebViewCreated,
                onLoadStart: controller.onLoadStart,
                onLoadStop: controller.onLoadStop,
                onUpdateVisitedHistory: controller.onUpdateVisitedHistory,
                initialSettings: InAppWebViewSettings(
                  userAgent: controller.getDynamicUserAgent(),
                  javaScriptEnabled: true,
                  useWideViewPort: true,
                  loadWithOverviewMode: true,
                  supportZoom: true,
                  builtInZoomControls: true,
                  displayZoomControls: false,
                  useShouldOverrideUrlLoading: true,
                  domStorageEnabled: true,
                  databaseEnabled: true,
                  thirdPartyCookiesEnabled: true,
                  cacheEnabled: true,
                  isInspectable: true,
                ),
                onReceivedServerTrustAuthRequest: controller.onReceivedServerTrustAuthRequest,
                shouldOverrideUrlLoading: controller.shouldOverrideUrlLoading,
                onConsoleMessage: controller.onConsoleMessage,
              );
            }),
          ),
        ],
      ),
    );
  }
}
