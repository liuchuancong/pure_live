import 'dart:async';

import 'package:pure_live/common/index.dart';
import 'package:pure_live/modules/account/bilibili/bilibili_login_qr_code.dart';
import 'package:pure_live/modules/account/bilibili/qr_login_controller.dart';
import 'package:remixicon/remixicon.dart';

class BiliBiliQRLoginPage extends GetView<BiliBiliQRLoginController> {
  const BiliBiliQRLoginPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(i18n('bilibili_login'))),
      body: ListView(
        key: const ValueKey('bilibili-qr-scroll-view'),
        physics: const PureLiveScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        children: [
          _buildTipBanner(theme),
          const SizedBox(height: 28),
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Obx(() => _buildQrState(theme)),
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildQrState(ThemeData theme) {
    switch (controller.qrStatus.value) {
      case QRStatus.loading:
        return _buildProgressState(i18n('qr_loading'));
      case QRStatus.verifying:
        return _buildProgressState(i18n('account_verifying'));
      case QRStatus.verified:
        return _buildStatusMessage(
          theme,
          icon: Remix.checkbox_circle_line,
          message: i18n('bilibili_login_verified'),
          highlighted: true,
        );
      case QRStatus.failed:
        final messageKey = controller.errorMessageKey.value.isEmpty
            ? 'qr_load_failed'
            : controller.errorMessageKey.value;
        return _buildErrorState(
          theme,
          message: i18n(messageKey),
          buttonText: i18n('retry'),
          onPressed: controller.loadQRCode,
        );
      case QRStatus.expired:
        return _buildErrorState(
          theme,
          message: i18n('qr_expired'),
          buttonText: i18n('refresh_qr'),
          onPressed: controller.loadQRCode,
        );
      case QRStatus.unscanned:
      case QRStatus.scanned:
        return _buildActiveQr(theme);
    }
  }

  Widget _buildActiveQr(ThemeData theme) {
    final scanned = controller.qrStatus.value == QRStatus.scanned;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final size = (constraints.maxWidth - 64).clamp(140.0, 180.0).toDouble();
            return context.buildModernCard([
              Padding(
                padding: const EdgeInsets.all(16),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: BilibiliLoginQrCode(data: controller.qrcodeUrl.value, size: size),
                ),
              ),
            ]);
          },
        ),
        const SizedBox(height: 20),
        _buildStatusMessage(
          theme,
          icon: scanned ? Remix.checkbox_circle_line : Remix.qr_code_line,
          message: i18n(scanned ? 'qr_scanned_confirm' : 'qr_waiting_scan'),
          highlighted: scanned,
        ),
      ],
    );
  }

  Widget _buildProgressState(String message) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 56),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox.square(dimension: 28, child: CircularProgressIndicator(strokeWidth: 3)),
          const SizedBox(height: 20),
          Text(message, textAlign: TextAlign.center, style: AppTextStyles.t14),
        ],
      ),
    );
  }

  Widget _buildStatusMessage(
    ThemeData theme, {
    required IconData icon,
    required String message,
    bool highlighted = false,
  }) {
    final color = highlighted ? theme.colorScheme.primary : theme.hintColor;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: highlighted ? theme.colorScheme.primary.withValues(alpha: 0.1) : Colors.transparent,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(icon, size: 18, color: color),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              textAlign: TextAlign.start,
              style: AppTextStyles.t13.copyWith(
                color: color,
                fontWeight: highlighted ? FontWeight.w600 : FontWeight.normal,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTipBanner(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(Remix.information_line, size: 18, color: theme.colorScheme.primary.withValues(alpha: 0.8)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              i18n('qr_login_tip'),
              style: AppTextStyles.t13.copyWith(
                color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.8),
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(
    ThemeData theme, {
    required String message,
    required String buttonText,
    required Future<bool> Function() onPressed,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Remix.error_warning_line, size: 40, color: theme.hintColor.withValues(alpha: 0.4)),
          const SizedBox(height: 12),
          Text(
            message,
            textAlign: TextAlign.center,
            style: AppTextStyles.t14.copyWith(color: theme.hintColor),
          ),
          const SizedBox(height: 16),
          TextButton.icon(
            onPressed: () => unawaited(onPressed()),
            icon: const Icon(Remix.refresh_line, size: 18),
            label: Text(buttonText, textAlign: TextAlign.center),
            style: TextButton.styleFrom(
              foregroundColor: theme.colorScheme.primary,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              textStyle: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
