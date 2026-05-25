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
            padding: const EdgeInsets.all(8.0),
            child: IconButton(
              icon: const Icon(Icons.close),
              tooltip: i18n('close'),
              onPressed: () => controller.closePage(), // 调用刚刚添加的关闭方法
            ),
          ),
        ],
      ),
      body: Obx(() {
        return Stack(
          children: [
            InAppWebView(
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
              ),
              shouldOverrideUrlLoading: controller.shouldOverrideUrlLoading,
            ),

            if (controller.loading.value) AppStatusView(type: AppStatusType.loading, title: "", subtitle: ""),
          ],
        );
      }),
    );
  }
}
