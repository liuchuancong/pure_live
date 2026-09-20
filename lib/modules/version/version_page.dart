import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:remixicon/remixicon.dart';
import 'package:pure_live/common/index.dart';
import 'package:pure_live/plugins/update.dart';
import 'package:markdown_widget/widget/all.dart';
import 'package:markdown_widget/config/configs.dart';
import 'package:pure_live/common/global/platform_utils.dart';
import 'package:pure_live/modules/version/version_controller.dart';

typedef VersionDownloadHandler = Future<void> Function(String url, {String? fileName});

Uri? versionDownloadUri(String rawUrl) => updateDownloadUri(rawUrl);

class VersionPage extends GetView<VersionController> {
  const VersionPage({super.key, this.downloadRelease});

  final VersionDownloadHandler? downloadRelease;

  @override
  Widget build(BuildContext context) {
    final textScale = MediaQuery.textScalerOf(context).scale(1);
    final toolbarHeight = textScale <= 1.5 ? kToolbarHeight : math.min(152.0, 44 + 36 * textScale);
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: toolbarHeight,
        title: Text(i18n('version_update'), maxLines: 2, overflow: TextOverflow.ellipsis),
      ),
      body: Obx(() {
        if (controller.loading.value) {
          return const AppStatusView(type: AppStatusType.loading, title: '', subtitle: '');
        }
        if (controller.error.value) {
          return _buildErrorState(context);
        }

        return ListView(
          key: const ValueKey('version-update-scroll'),
          physics: const PureLiveScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          children: [
            if (PlatformUtils.isAndroid) ...[
              _buildPlatformCard(
                context,
                title: "Android",
                subtitle: i18n("android_desc"),
                icon: Remix.android_line,
                children: [
                  _buildDownloadSection(context, title: i18n("arch_arm64"), urls: controller.androidArm64Url.value),
                  const SizedBox(height: 16),
                  _buildDownloadSection(
                    context,
                    title: i18n("arch_arm32"),
                    urls: controller.androidArmeabiV7aUrl.value,
                  ),
                  const SizedBox(height: 16),
                  _buildDownloadSection(context, title: i18n("arch_x86_64"), urls: controller.androidX8664Url.value),
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
                  _buildDownloadSection(context, title: i18n("exe_installer"), urls: controller.windowsSetupUrl.value),
                  const SizedBox(height: 16),
                  if (controller.windowsMsixUrl.value.isNotEmpty) ...[
                    _buildDownloadSection(
                      context,
                      title: i18n("msix_installer"),
                      urls: controller.windowsMsixUrl.value,
                    ),
                    const SizedBox(height: 16),
                  ],
                  _buildDownloadSection(
                    context,
                    title: i18n("portable_package"),
                    urls: controller.windowsPortableUrl.value,
                  ),
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
                children: [
                  _buildDownloadSection(context, title: i18n("macos_package"), urls: controller.macosUrl.value),
                ],
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
                              data: controller.updateLog.value,
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

  Widget _buildErrorState(BuildContext context) {
    final theme = Theme.of(context);
    return CustomScrollView(
      key: const ValueKey('version-update-error'),
      physics: const PureLiveScrollPhysics(),
      slivers: [
        SliverFillRemaining(
          hasScrollBody: false,
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.cloud_off_rounded, size: 48, color: theme.colorScheme.primary),
                  const SizedBox(height: 20),
                  Text(
                    i18n('version_update_failed_title'),
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    i18n('version_update_failed_subtitle'),
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: 20),
                  FilledButton.icon(
                    key: const ValueKey('version-update-retry'),
                    onPressed: controller.checkNewVersion,
                    icon: const Icon(Remix.refresh_line),
                    label: Text(i18n('retry')),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
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
    final githubOriginOnly = SettingsService.to.app.useGitHubOriginForUpdates.v;
    final mirrorUrls = getMirrorUrls(
      urls,
      githubOriginOnly: githubOriginOnly,
    ).where((url) => versionDownloadUri(url) != null).toList(growable: false);

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
            final textScale = MediaQuery.textScalerOf(context).scale(1);
            int maxColumns = 1;
            if (textScale <= 1.5 && maxWidth >= 360) {
              maxColumns = 2;
            }
            if (PlatformUtils.isDesktop && textScale <= 1.5) {
              maxColumns = maxWidth > 800 ? 4 : (maxWidth > 500 ? 3 : 2);
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
                    child: Tooltip(
                      message: mirrorUrls[i],
                      waitDuration: const Duration(milliseconds: 300),
                      child: OutlinedButton.icon(
                        key: ValueKey('version-source-$title-$i'),
                        style:
                            OutlinedButton.styleFrom(
                              backgroundColor: theme.colorScheme.surfaceContainerLow,
                              foregroundColor: theme.colorScheme.onSurfaceVariant,
                              minimumSize: const Size(0, kMinInteractiveDimension),
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
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
                          githubOriginOnly
                              ? i18n('github_origin_source')
                              : i18n("download_source", args: {"num": "${i + 1}"}),
                          style: AppTextStyles.t12.copyWith(fontWeight: FontWeight.w600),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
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

  Future<void> _showActionDialog(
    BuildContext pageContext,
    String platformName,
    String targetUrl,
    int sourceIndex,
  ) async {
    final theme = Theme.of(pageContext);
    await showDialog<void>(
      context: pageContext,
      builder: (dialogContext) {
        return AlertDialog(
          scrollable: true,
          insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
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
            crossAxisAlignment: CrossAxisAlignment.stretch,
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
                child: SelectableText(
                  targetUrl,
                  style: AppTextStyles.t11.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
              ),
              const SizedBox(height: 8),
              FilledButton.icon(
                key: const ValueKey('version-source-download'),
                onPressed: () {
                  Navigator.of(dialogContext).pop();
                  _startDownload(pageContext, targetUrl);
                },
                icon: const Icon(Remix.download_2_line, size: 20),
                label: Text(i18n('download'), textAlign: TextAlign.center),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                key: const ValueKey('version-source-copy'),
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: targetUrl));
                  if (!dialogContext.mounted) return;
                  Navigator.of(dialogContext).pop();
                  if (pageContext.mounted) _showMessage(pageContext, 'copied_to_clipboard');
                },
                icon: const Icon(Remix.clipboard_line, size: 20),
                label: Text(i18n('copy_link'), textAlign: TextAlign.center),
              ),
            ],
          ),
          actions: [
            TextButton(
              key: const ValueKey('version-source-cancel'),
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(i18n('cancel')),
            ),
          ],
        );
      },
    );
  }

  Future<void> _startDownload(BuildContext context, String targetUrl) async {
    if (versionDownloadUri(targetUrl) == null) return;
    try {
      final handler = downloadRelease;
      if (handler != null) {
        await handler(targetUrl);
      } else {
        await downloadAndInstallApk(targetUrl);
      }
    } catch (_) {
      if (context.mounted) _showMessage(context, 'version_update_download_failed');
    }
  }

  void _showMessage(BuildContext context, String key) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(i18n(key))));
  }
}
