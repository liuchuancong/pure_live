import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:pure_live/core/index.dart';
import 'package:pure_live/domains/live/presentation/search/web_search_controller.dart';

class WebSearchPage extends StatefulWidget {
  const WebSearchPage({super.key, this.showDeveloperTools});

  final bool? showDeveloperTools;

  @override
  State<WebSearchPage> createState() => _WebSearchPageState();
}

class _WebSearchPageState extends State<WebSearchPage> {
  WebSearchController get controller => Get.find<WebSearchController>();

  bool _allowPop = false;
  bool _popScheduled = false;

  bool get _showDeveloperTools => widget.showDeveloperTools ?? kDebugMode;

  @override
  Widget build(BuildContext context) {
    return PopScope<Object?>(
      canPop: _allowPop,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) unawaited(_handleBack());
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(i18n('web_search')),
          leading: BackButton(onPressed: () => unawaited(_handleBack())),
          actions: [
            IconButton(
              icon: const Icon(Icons.close),
              tooltip: i18n('close'),
              onPressed: () => unawaited(_handleClose()),
            ),
            if (_showDeveloperTools && !controller.usesExternalBrowser)
              IconButton(
                icon: const Icon(Icons.bug_report),
                tooltip: i18n('web_search_devtools'),
                onPressed: () => unawaited(controller.openDevTools()),
              ),
          ],
        ),
        body: _buildBody(context),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (!controller.hasValidLaunchRequest) {
      return _buildFailure(context, retryable: false);
    }
    if (controller.usesExternalBrowser) return _buildExternalBrowser(context);
    return Stack(
      children: [
        Positioned.fill(
          child: Obx(
            () => controller.showWebView.value
                ? InAppWebView(
                    onWebViewCreated: controller.onWebViewCreated,
                    onLoadStart: controller.onLoadStart,
                    onLoadStop: controller.onLoadStop,
                    onProgressChanged: controller.onProgressChanged,
                    onUpdateVisitedHistory: controller.onUpdateVisitedHistory,
                    onReceivedHttpError: controller.onReceivedHttpError,
                    onReceivedError: controller.onReceivedError,
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
                      isInspectable: _showDeveloperTools,
                    ),
                    onReceivedServerTrustAuthRequest: controller.onReceivedServerTrustAuthRequest,
                    shouldOverrideUrlLoading: controller.shouldOverrideUrlLoading,
                    onConsoleMessage: controller.onConsoleMessage,
                  )
                : const SizedBox.shrink(),
          ),
        ),
        Obx(() {
          if (controller.viewStatus.value != WebSearchViewStatus.loading) return const SizedBox.shrink();
          final progress = controller.loadProgress.value;
          return Align(
            alignment: Alignment.topCenter,
            child: Semantics(
              label: i18n('web_search_loading'),
              child: LinearProgressIndicator(value: progress > 0 && progress < 100 ? progress / 100 : null),
            ),
          );
        }),
        Obx(() {
          if (controller.viewStatus.value != WebSearchViewStatus.failed) return const SizedBox.shrink();
          return Positioned.fill(
            child: ColoredBox(
              color: Theme.of(context).colorScheme.surface,
              child: _buildFailure(context, retryable: true),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildExternalBrowser(BuildContext context) {
    final theme = Theme.of(context);
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        physics: const PureLiveScrollPhysics(),
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: (constraints.maxHeight - 48).clamp(0, double.infinity)),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.open_in_browser_rounded, size: 48, color: theme.colorScheme.primary),
                  const SizedBox(height: 16),
                  Text(i18n('linux_web_search_external_tip'), textAlign: TextAlign.center),
                  const SizedBox(height: 20),
                  Obx(
                    () => FilledButton.icon(
                      key: const ValueKey('web-search-open-external'),
                      onPressed: controller.isOpeningExternal.value
                          ? null
                          : () => unawaited(controller.openExternalBrowser()),
                      icon: controller.isOpeningExternal.value
                          ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.open_in_new_rounded),
                      label: Text(i18n('open_in_system_browser'), textAlign: TextAlign.center),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFailure(BuildContext context, {required bool retryable}) {
    final key = controller.errorMessageKey.value;
    return SingleChildScrollView(
      physics: const PureLiveScrollPhysics(),
      padding: const EdgeInsets.all(24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Column(
            key: const ValueKey('web-search-failure'),
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.wifi_off_rounded, size: 48, color: Theme.of(context).colorScheme.error),
              const SizedBox(height: 20),
              Text(
                i18n('web_search_error_title'),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Text(
                i18n(key.isEmpty ? 'web_search_load_failed' : key),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium
                    ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant, height: 1.4),
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: retryable ? () => unawaited(controller.retry()) : () => unawaited(_handleClose()),
                icon: Icon(retryable ? Icons.refresh_rounded : Icons.close_rounded),
                label: Text(i18n(retryable ? 'retry' : 'close'), textAlign: TextAlign.center),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _handleBack() async {
    final disposition = await controller.requestBack();
    if (disposition == WebSearchBackDisposition.closePage) _schedulePop();
  }

  Future<void> _handleClose() async {
    await controller.closeWebSearch();
    _schedulePop();
  }

  void _schedulePop() {
    if (!mounted || _popScheduled) return;
    _popScheduled = true;
    setState(() => _allowPop = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Navigator.of(context).maybePop();
    });
  }
}
