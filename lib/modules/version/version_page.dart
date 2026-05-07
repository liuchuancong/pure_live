import 'package:get/get.dart';
import 'package:flutter/material.dart';
import 'package:pure_live/plugins/update.dart';
import 'package:markdown_widget/config/configs.dart';
import 'package:pure_live/common/utils/version_util.dart';
import 'package:markdown_widget/widget/markdown_block.dart';
import 'package:pure_live/common/global/platform_utils.dart';
import 'package:pure_live/modules/version/version_controller.dart';

class VersionPage extends GetView<VersionController> {
  const VersionPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('版本更新')),
      body: Obx(() {
        if (controller.loading.value) {
          return const Center(child: CircularProgressIndicator.adaptive());
        }

        return Padding(
          padding: const EdgeInsets.all(16),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // =====================================================
                // Android
                // =====================================================
                if (PlatformUtils.isAndroid) ...[
                  _buildPlatformCard(
                    context,
                    title: 'Android MediaKit版',
                    subtitle: '使用 MediaKit 播放器内核',
                    icon: Icons.android,
                    children: [
                      _buildDownloadSection(title: 'ARM64 (arm64-v8a)', urls: controller.apkUrl2.value),

                      const SizedBox(height: 16),

                      _buildDownloadSection(title: 'ARM32 (armeabi-v7a)', urls: controller.apkUrl.value),
                    ],
                  ),

                  const SizedBox(height: 20),

                  _buildPlatformCard(
                    context,
                    title: 'Android FVP版',
                    subtitle: '使用 FVP 播放器内核',
                    icon: Icons.live_tv,
                    children: [
                      _buildDownloadSection(title: 'ARM64 FVP', urls: controller.apkFvpUrl2.value),

                      const SizedBox(height: 16),

                      _buildDownloadSection(title: 'ARM32 FVP', urls: controller.apkFvpUrl.value),
                    ],
                  ),

                  const SizedBox(height: 24),
                ],

                if (PlatformUtils.isWindows) ...[
                  _buildPlatformCard(
                    context,
                    title: 'Windows MediaKit版',
                    subtitle: '使用 MediaKit 播放器内核',
                    icon: Icons.desktop_windows,
                    children: [
                      _buildDownloadSection(title: 'EXE 安装包', urls: controller.windowsUrl.value),

                      const SizedBox(height: 16),

                      _buildDownloadSection(title: 'MSIX 安装包', urls: controller.windowsUrl2.value),
                    ],
                  ),

                  const SizedBox(height: 20),

                  _buildPlatformCard(
                    context,
                    title: 'Windows FVP版',
                    subtitle: '使用 FVP 播放器内核',
                    icon: Icons.live_tv,
                    children: [
                      _buildDownloadSection(title: 'FVP EXE', urls: controller.windowsFvpUrl.value),

                      const SizedBox(height: 16),

                      _buildDownloadSection(title: 'FVP MSIX', urls: controller.windowsFvpUrl2.value),
                    ],
                  ),

                  const SizedBox(height: 24),
                ],

                if (PlatformUtils.isMacOS) ...[
                  _buildPlatformCard(
                    context,
                    title: 'macOS MediaKit版',
                    subtitle: '使用 MediaKit 播放器内核',
                    icon: Icons.laptop_mac,
                    children: [_buildDownloadSection(title: 'macOS DMG', urls: controller.macosUrl.value)],
                  ),

                  const SizedBox(height: 20),

                  _buildPlatformCard(
                    context,
                    title: 'macOS FVP版',
                    subtitle: '使用 FVP 播放器内核',
                    icon: Icons.live_tv,
                    children: [_buildDownloadSection(title: 'macOS FVP DMG', urls: controller.macosFvpUrl.value)],
                  ),

                  const SizedBox(height: 24),
                ],

                // =====================================================
                // 更新日志
                // =====================================================
                Text('更新日志', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),

                const SizedBox(height: 12),

                Card(
                  elevation: 0,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: MarkdownBlock(
                      data: VersionUtil.latestUpdateLog,
                      config: Get.isDarkMode ? MarkdownConfig.darkConfig : MarkdownConfig.defaultConfig,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      }),
    );
  }

  // =========================================================
  // 平台卡片
  // =========================================================

  Widget _buildPlatformCard(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Card(
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon),

                const SizedBox(width: 12),

                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                      ),

                      const SizedBox(height: 2),

                      Text(subtitle, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey)),
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
    );
  }

  // =========================================================
  // 下载区
  // =========================================================

  Widget _buildDownloadSection({required String title, required String urls}) {
    final List<String> mirrorUrls = getMirrorUrls(urls);

    if (mirrorUrls.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(Get.context!).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),

        const SizedBox(height: 10),

        LayoutBuilder(
          builder: (context, constraints) {
            final double maxWidth = constraints.maxWidth;

            final int maxColumns = PlatformUtils.isDesktop ? 4 : 2;

            const double spacing = 10.0;

            final double buttonWidth = (maxWidth - spacing * (maxColumns - 1)) / maxColumns;

            return Wrap(
              spacing: spacing,
              runSpacing: spacing,
              children: [
                for (int i = 0; i < mirrorUrls.length; i++)
                  SizedBox(
                    width: buttonWidth,
                    height: 42,
                    child: Tooltip(
                      message: mirrorUrls[i],
                      waitDuration: const Duration(milliseconds: 300),
                      child: ElevatedButton.icon(
                        onPressed: () {
                          downloadAndInstallApk(mirrorUrls[i]);
                        },
                        icon: const Icon(Icons.download_rounded, size: 18),
                        label: Text('下载源 ${i + 1}', maxLines: 1, overflow: TextOverflow.ellipsis),
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
}
