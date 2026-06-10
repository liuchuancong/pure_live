import 'package:flutter/services.dart';
import 'package:remixicon/remixicon.dart';
import 'package:pure_live/common/index.dart';
import 'package:pure_live/plugins/update.dart';
import 'package:markdown_widget/widget/all.dart';
import 'package:markdown_widget/config/configs.dart';
import 'package:pure_live/common/global/platform_utils.dart';
import 'package:pure_live/modules/version/version_controller.dart';

class VersionPage extends GetView<VersionController> {
  const VersionPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(i18n("version_update"))),
      body: Obx(() {
        if (controller.loading.value) {
          return AppStatusView(type: AppStatusType.loading, title: "", subtitle: "");
        }

        return ListView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          children: [
            if (PlatformUtils.isAndroid) ...[
              _buildPlatformCard(
                context,
                title: "Android",
                subtitle: i18n("android_desc"),
                icon: Remix.android_line,
                children: [
                  _buildDownloadSection(context, title: i18n("arch_arm64"), urls: controller.apkUrl2.value),
                  const SizedBox(height: 16),
                  _buildDownloadSection(context, title: i18n("arch_arm32"), urls: controller.apkUrl.value),
                  const SizedBox(height: 16),
                  _buildDownloadSection(context, title: i18n("arch_x86_64"), urls: controller.apkUrl3.value),
                ],
              ),
              const SizedBox(height: 24),
            ],
            if (PlatformUtils.isWindows) ...[
              _buildPlatformCard(
                context,
                title: "Windows",
                subtitle: i18n("windows_desc"),
                icon: Remix.windows_line,
                children: [
                  _buildDownloadSection(context, title: i18n("exe_installer"), urls: controller.windowsUrl.value),
                  const SizedBox(height: 16),
                  _buildDownloadSection(context, title: i18n("msix_installer"), urls: controller.windowsUrl2.value),
                ],
              ),
              const SizedBox(height: 24),
            ],
            if (PlatformUtils.isMacOS) ...[
              _buildPlatformCard(
                context,
                title: "macOS",
                subtitle: i18n("macos_desc"),
                icon: Remix.macbook_line,
                children: [_buildDownloadSection(context, title: i18n("macos_dmg"), urls: controller.macosUrl.value)],
              ),
              const SizedBox(height: 20),
            ],

            context.buildGroupTitle(i18n("update_log")),
            const SizedBox(height: 8),
            context.buildModernCard([
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: SizedBox(
                  width: double.infinity,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Align(
                        alignment: Alignment.topLeft,
                        child: Builder(
                          builder: (context) {
                            final theme = Theme.of(context);
                            final textTheme = theme.textTheme;
                            final isDark = theme.brightness == Brightness.dark;

                            final baseConfig = isDark ? MarkdownConfig.darkConfig : MarkdownConfig.defaultConfig;

                            return MarkdownBlock(
                              data: VersionUtil.latestUpdateLog,
                              config: baseConfig.copy(
                                configs: [
                                  PConfig(textStyle: textTheme.bodyMedium ?? const TextStyle()),

                                  H1Config(
                                    style: (textTheme.titleLarge ?? const TextStyle()).copyWith(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  H2Config(
                                    style: (textTheme.titleMedium ?? const TextStyle()).copyWith(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  H3Config(
                                    style: (textTheme.titleSmall ?? const TextStyle()).copyWith(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  //
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ]),
          ],
        );
      }),
    );
  }

  Widget _buildPlatformCard(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required List<Widget> children,
  }) {
    final theme = Theme.of(context);
    return context.buildModernCard([
      Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: theme.colorScheme.primary, size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: AppTextStyles.t16.copyWith(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 2),
                      Text(subtitle, style: AppTextStyles.t12.copyWith(color: theme.hintColor.withValues(alpha: 0.8))),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            ...children,
          ],
        ),
      ),
    ]);
  }

  Widget _buildDownloadSection(BuildContext context, {required String title, required String urls}) {
    final List<String> mirrorUrls = getMirrorUrls(urls);

    if (mirrorUrls.isEmpty) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: AppTextStyles.t13.copyWith(
            fontWeight: FontWeight.w600,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
          ),
        ),
        const SizedBox(height: 10),
        LayoutBuilder(
          builder: (context, constraints) {
            final double maxWidth = constraints.maxWidth;

            int maxColumns = 2;
            if (PlatformUtils.isDesktop) {
              maxColumns = maxWidth > 800 ? 4 : (maxWidth > 500 ? 3 : 2);
            } else {
              maxColumns = maxWidth > 340 ? 2 : 1;
            }

            const double spacing = 8.0;
            final double buttonWidth = (maxWidth - spacing * (maxColumns - 1)) / maxColumns;

            return Wrap(
              spacing: spacing,
              runSpacing: spacing,
              children: [
                for (int i = 0; i < mirrorUrls.length; i++)
                  SizedBox(
                    width: buttonWidth,
                    height: 38,
                    child: Tooltip(
                      message: mirrorUrls[i],
                      waitDuration: const Duration(milliseconds: 300),
                      child: OutlinedButton.icon(
                        style:
                            OutlinedButton.styleFrom(
                              backgroundColor: theme.colorScheme.surfaceContainerLow,
                              foregroundColor: theme.colorScheme.onSurfaceVariant,
                              padding: const EdgeInsets.symmetric(horizontal: 8),
                              // Subtle border matching your design specs
                              side: BorderSide(color: theme.dividerColor.withValues(alpha: 0.08), width: 1),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ).copyWith(
                              backgroundColor: WidgetStateProperty.resolveWith<Color?>((states) {
                                if (states.contains(WidgetState.pressed)) {
                                  return theme.colorScheme.primary.withValues(alpha: 0.15);
                                }
                                if (states.contains(WidgetState.hovered)) {
                                  return theme.colorScheme.primary.withValues(alpha: 0.08);
                                }
                                return theme.colorScheme.surfaceContainerLow;
                              }),
                              foregroundColor: WidgetStateProperty.resolveWith<Color?>((states) {
                                if (states.contains(WidgetState.hovered) || states.contains(WidgetState.pressed)) {
                                  return theme.colorScheme.primary;
                                }
                                return theme.colorScheme.onSurfaceVariant;
                              }),
                              side: WidgetStateProperty.resolveWith<BorderSide?>((states) {
                                if (states.contains(WidgetState.hovered) || states.contains(WidgetState.pressed)) {
                                  return BorderSide(color: theme.colorScheme.primary.withValues(alpha: 0.3), width: 1);
                                }
                                return BorderSide(color: theme.dividerColor.withValues(alpha: 0.08), width: 1);
                              }),
                            ),
                        onPressed: () => _showActionDialog(context, title, mirrorUrls[i], i + 1),
                        icon: const Icon(Remix.link_m, size: 14),
                        label: Text(
                          i18n("download_source", args: {"num": "${i + 1}"}),
                          style: AppTextStyles.t12.copyWith(fontWeight: FontWeight.w600),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }

  void _showActionDialog(BuildContext context, String platformName, String targetUrl, int sourceIndex) {
    final theme = Theme.of(context);
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: theme.colorScheme.surfaceContainerHigh,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          titlePadding: const EdgeInsets.only(left: 20, right: 20, top: 20, bottom: 12),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12),
          actionsPadding: const EdgeInsets.only(left: 16, right: 16, bottom: 16, top: 8),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(Remix.download_cloud_2_line, color: theme.colorScheme.primary, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(platformName, style: AppTextStyles.t15.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 2),
                    Text(
                      i18n("download_source", args: {"num": "$sourceIndex"}),
                      style: AppTextStyles.t11.copyWith(color: theme.hintColor),
                    ),
                  ],
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: theme.dividerColor.withValues(alpha: 0.05)),
                ),
                child: Text(
                  targetUrl,
                  style: AppTextStyles.t11.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(height: 8),
              ListTile(
                leading: Icon(Remix.download_2_line, color: theme.colorScheme.primary, size: 20),
                title: Text(i18n("download"), style: AppTextStyles.t13.copyWith(fontWeight: FontWeight.w600)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                onTap: () {
                  Navigator.of(context).pop();
                  downloadAndInstallApk(targetUrl);
                },
              ),
              ListTile(
                leading: Icon(Remix.clipboard_line, color: theme.colorScheme.secondary, size: 20),
                title: Text(i18n("copy_link"), style: AppTextStyles.t13.copyWith(fontWeight: FontWeight.w600)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                onTap: () {
                  Navigator.of(context).pop();
                  Clipboard.setData(ClipboardData(text: targetUrl));
                  Get.snackbar(
                    i18n("done"),
                    i18n("copied_to_clipboard"),
                    snackPosition: SnackPosition.bottom,
                    margin: const EdgeInsets.all(16),
                  );
                },
              ),
            ],
          ),
          actions: [TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(i18n("cancel")))],
        );
      },
    );
  }
}
