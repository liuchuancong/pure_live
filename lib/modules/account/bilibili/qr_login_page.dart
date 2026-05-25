import 'package:remixicon/remixicon.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:pure_live/common/index.dart';
import 'package:pure_live/modules/account/bilibili/qr_login_controller.dart';

class BiliBiliQRLoginPage extends GetView<BiliBiliQRLoginController> {
  const BiliBiliQRLoginPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(i18n("bilibili_login"))),
      body: ListView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        children: [
          _buildTipBanner(theme),
          const SizedBox(height: 40),
          Center(
            child: Obx(() {
              if (controller.qrStatus.value == QRStatus.loading) {
                return SizedBox(
                  height: 200,
                  child: AppStatusView(type: AppStatusType.loading, title: "", subtitle: ""),
                );
              }

              if (controller.qrStatus.value == QRStatus.failed) {
                return _buildErrorState(
                  theme,
                  message: i18n("qr_load_failed"),
                  buttonText: i18n("retry"),
                  onPressed: controller.loadQRCode,
                );
              }

              if (controller.qrStatus.value == QRStatus.expired) {
                return _buildErrorState(
                  theme,
                  message: i18n("qr_expired"),
                  buttonText: i18n("refresh_qr"),
                  onPressed: controller.loadQRCode,
                );
              }

              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  context.buildModernCard([
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: QrImageView(
                          data: controller.qrcodeUrl.value,
                          version: QrVersions.auto,
                          backgroundColor: Colors.white,
                          size: 180.0,
                          padding: const EdgeInsets.all(12),
                        ),
                      ),
                    ),
                  ]),
                  const SizedBox(height: 20),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: controller.qrStatus.value == QRStatus.scanned
                        ? Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Remix.checkbox_circle_line, size: 16, color: theme.colorScheme.primary),
                                const SizedBox(width: 6),
                                Text(
                                  i18n("qr_scanned_confirm"),
                                  style: AppTextStyles.t13.copyWith(
                                    color: theme.colorScheme.primary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : Text(i18n("qr_waiting_scan"), style: AppTextStyles.t13.copyWith(color: theme.hintColor)),
                  ),
                ],
              );
            }),
          ),
          const SizedBox(height: 32),
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
          Icon(Remix.information_line, size: 18, color: theme.colorScheme.primary.withValues(alpha: 0.8)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              i18n("qr_login_tip"),
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
    required VoidCallback onPressed,
  }) {
    return SizedBox(
      height: 220,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Remix.error_warning_line, size: 40, color: theme.hintColor.withValues(alpha: 0.4)),
          const SizedBox(height: 12),
          Text(message, style: AppTextStyles.t14.copyWith(color: theme.hintColor)),
          const SizedBox(height: 16),
          TextButton.icon(
            onPressed: onPressed,
            icon: const Icon(Remix.refresh_line, size: 16),
            label: Text(buttonText),
            style: TextButton.styleFrom(
              foregroundColor: theme.colorScheme.primary,
              textStyle: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
