import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:pure_live/core/index.dart';
import 'package:pure_live/domains/account/presentation/account/bilibili/web_login_controller.dart';
import 'package:remixicon/remixicon.dart';

class BiliBiliWebLoginPage extends GetView<BiliBiliWebLoginController> {
  const BiliBiliWebLoginPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final compactAction = MediaQuery.sizeOf(context).width < 520 || MediaQuery.textScalerOf(context).scale(14) > 20;

    return Scaffold(
      appBar: AppBar(
        title: Text(i18n('bilibili_login')),
        actions: [
          Obx(() {
            final busy = controller.isVerifying.value || controller.isSwitchingToQr.value;
            if (compactAction) {
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: IconButton(
                  key: const ValueKey('bilibili-web-login-qr-action'),
                  onPressed: busy ? null : controller.toQRLogin,
                  tooltip: i18n('qr_login'),
                  icon: const Icon(Remix.qr_code_line),
                ),
              );
            }
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: TextButton.icon(
                key: const ValueKey('bilibili-web-login-qr-action'),
                onPressed: busy ? null : controller.toQRLogin,
                style: TextButton.styleFrom(
                  foregroundColor: theme.colorScheme.primary,
                  textStyle: const TextStyle(fontWeight: FontWeight.w600),
                ),
                icon: const Icon(Remix.qr_code_line, size: 16),
                label: Text(i18n('qr_login')),
              ),
            );
          }),
        ],
      ),
      body: Obx(() {
        if (controller.isSwitchingToQr.value) {
          return _buildProgressState(
            key: const ValueKey('bilibili-web-login-switching'),
            message: i18n('bilibili_opening_qr_login'),
          );
        }

        return Stack(
          fit: StackFit.expand,
          children: [
            if (controller.showWebView.value)
              InAppWebView(
                initialUrlRequest: URLRequest(url: WebUri(bilibiliWebLoginUrl)),
                onWebViewCreated: controller.onWebViewCreated,
                onLoadStop: controller.onLoadStop,
                initialSettings: InAppWebViewSettings(
                  userAgent:
                      'Mozilla/5.0 (iPhone; CPU iPhone OS 13_2_3 like Mac OS X) '
                      'AppleWebKit/605.1.15 (KHTML, like Gecko) Version/13.0.3 '
                      'Mobile/15E148 Safari/604.1 Edg/118.0.0.0',
                  useShouldOverrideUrlLoading: true,
                ),
                shouldOverrideUrlLoading: (_, navigationAction) async {
                  return controller.navigationPolicyFor(navigationAction.request.url);
                },
              )
            else
              const ColoredBox(color: Colors.transparent),
            if (controller.isVerifying.value)
              _buildProgressState(
                key: const ValueKey('bilibili-web-login-verifying'),
                message: i18n('account_verifying'),
                backgroundColor: theme.colorScheme.surface.withValues(alpha: 0.94),
              ),
            if (!controller.isVerifying.value && controller.errorMessageKey.value.isNotEmpty)
              _buildErrorBanner(theme, i18n(controller.errorMessageKey.value)),
          ],
        );
      }),
    );
  }

  Widget _buildProgressState({required Key key, required String message, Color? backgroundColor}) {
    return ColoredBox(
      key: key,
      color: backgroundColor ?? Colors.transparent,
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox.square(dimension: 28, child: CircularProgressIndicator(strokeWidth: 3)),
              const SizedBox(height: 20),
              Text(message, textAlign: TextAlign.center, style: AppTextStyles.t14),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildErrorBanner(ThemeData theme, String message) {
    return Align(
      alignment: Alignment.bottomCenter,
      child: SafeArea(
        minimum: const EdgeInsets.all(12),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Material(
            key: const ValueKey('bilibili-web-login-error'),
            color: theme.colorScheme.errorContainer,
            borderRadius: BorderRadius.circular(16),
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Icon(Remix.error_warning_line, color: theme.colorScheme.onErrorContainer, size: 20),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      message,
                      style: AppTextStyles.t13.copyWith(color: theme.colorScheme.onErrorContainer, height: 1.35),
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
}
