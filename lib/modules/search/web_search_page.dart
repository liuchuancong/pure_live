import 'web_search_controller.dart';
import 'package:pure_live/common/index.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

class WebSearchPage extends GetView<WebSearchController> {
  const WebSearchPage({super.key});

  @override
  Widget build(BuildContext context) {
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
          Obx(() {
            if (controller.loading.value) {
              return const SizedBox();
            }
            return Padding(
              padding: const EdgeInsets.all(8.0),
              child: IconButton(
                icon: const Icon(Icons.bug_report),
                onPressed: () async {
                  await controller.webViewController!.openDevTools();
                },
              ),
            );
          }),
        ],
      ),
      body: Obx(() {
        return Stack(
          children: [
            Positioned.fill(
              child: InAppWebView(
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
                onReceivedServerTrustAuthRequest: (controller, challenge) async {
                  debugPrint(challenge.protectionSpace.host);
                  return ServerTrustAuthResponse(action: ServerTrustAuthResponseAction.PROCEED);
                },
                shouldOverrideUrlLoading: controller.shouldOverrideUrlLoading,
              ),
            ),

            if (controller.loading.value) AppStatusView(type: AppStatusType.loading, title: "", subtitle: ""),
          ],
        );
      }),
    );
  }
}
