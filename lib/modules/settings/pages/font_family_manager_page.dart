import 'dart:io';
import 'package:remixicon/remixicon.dart';
import 'package:pure_live/common/index.dart';
import 'package:pure_live/plugins/file_utils.dart';
import 'package:pure_live/common/models/font_model.dart';
import 'package:pure_live/common/global/platform_utils.dart';
import 'package:pure_live/plugins/font_download_manager.dart';
import 'package:pure_live/common/global/app_path_manager.dart';

class FontFamilyManagerPage extends GetView<SettingsService> {
  const FontFamilyManagerPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    controller.refreshFontDiskSizes();

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        title: Text(
          i18n("font_family_settings"),
          style: const TextStyle(fontWeight: FontWeight.w700, letterSpacing: 0.3),
        ),
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: Obx(() {
        final fontModels = controller.fontList;

        return ListView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: [
            context.buildGroupTitle(i18n("factory_default_group")),
            _buildPresetEnvironmentCard(theme),
            const SizedBox(height: 28),
            context.buildGroupTitle(i18n("cloud_font_group")),
            if (fontModels.isEmpty)
              SizedBox(
                height: 200,
                child: AppStatusView(type: AppStatusType.loading, title: "", subtitle: ""),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: fontModels.length,
                itemBuilder: (context, index) {
                  final fontModel = fontModels[index];
                  return Obx(() {
                    final bool isCurrentActive = controller.fontFamilyName.value == fontModel.id;
                    final bool isSelectedModel = controller.curFontModel.value == fontModel;
                    final String? diskSize = controller.fontFolderSizes[fontModel.id];
                    final bool localExists = diskSize != null;

                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.fastOutSlowIn,
                      margin: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: isCurrentActive
                            ? theme.colorScheme.primary.withValues(alpha: 0.03)
                            : theme.colorScheme.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: isCurrentActive
                                ? theme.colorScheme.primary.withValues(alpha: 0.06)
                                : theme.shadowColor.withValues(alpha: 0.02),
                            blurRadius: isCurrentActive ? 24 : 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                        border: Border.all(
                          color: isCurrentActive
                              ? theme.colorScheme.primary
                              : (isSelectedModel
                                    ? theme.colorScheme.primary.withValues(alpha: 0.3)
                                    : theme.dividerColor.withValues(alpha: 0.05)),
                          width: isCurrentActive ? 1.8 : 1.2,
                        ),
                      ),
                      child: GestureDetector(
                        onTap: () async {
                          if (localExists) {
                            final path = await AppPathManager().getFontFamilyFolderPath(fontModel.id);
                            FileUtils.openFileOrUrl(path);
                          }
                        },
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(24),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      theme.colorScheme.primary.withValues(alpha: 0.06),
                                      theme.colorScheme.primary.withValues(alpha: 0.0),
                                    ],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                ),
                                padding: const EdgeInsets.fromLTRB(20, 16, 20, 2),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          fontModel.name,
                                          style: TextStyle(
                                            fontSize: AppTextStyles.t16.fontSize,
                                            fontWeight: FontWeight.w800,
                                            letterSpacing: 0.1,
                                          ),
                                        ),
                                        _buildLicenseBadge(theme, fontModel, diskSize),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      fontModel.desc,
                                      style: theme.textTheme.bodyMedium?.copyWith(
                                        color: theme.hintColor.withValues(alpha: 0.8),
                                        height: 1.4,
                                        letterSpacing: 0.2,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          "${fontModel.files.length} ${i18n("font_units_suffix")}",
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: theme.hintColor.withValues(alpha: 0.6),
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                        _buildActionButtonRow(
                                          context,
                                          fontModel,
                                          isCurrentActive,
                                          isSelectedModel,
                                          localExists,
                                        ),
                                      ],
                                    ),

                                    const SizedBox(height: 8),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  });
                },
              ),
          ],
        );
      }),
    );
  }

  Widget _buildPresetEnvironmentCard(ThemeData theme) {
    final bool isDefaultActive = controller.fontFamilyName.value == 'Default';

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDefaultActive ? theme.colorScheme.primary : theme.dividerColor.withValues(alpha: 0.05),
          width: isDefaultActive ? 1.5 : 1.0,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: ListTile(
          tileColor: isDefaultActive
              ? theme.colorScheme.primary.withValues(alpha: 0.03)
              : theme.colorScheme.surfaceContainerLow,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isDefaultActive
                  ? theme.colorScheme.primary.withValues(alpha: 0.1)
                  : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.settings_suggest_outlined,
              color: isDefaultActive ? theme.colorScheme.primary : theme.hintColor,
              size: 18,
            ),
          ),
          title: Text(
            PlatformUtils.isWindows ? "PingFang" : "System Default",
            style: TextStyle(
              fontSize: 14,
              fontWeight: isDefaultActive ? FontWeight.w700 : FontWeight.w600,
              color: isDefaultActive ? theme.colorScheme.primary : null,
            ),
          ),
          subtitle: Text(
            i18n("factory_default_desc"),
            style: TextStyle(fontSize: 11, color: theme.hintColor.withValues(alpha: 0.7)),
          ),
          trailing: isDefaultActive ? Icon(Icons.check_circle, color: theme.colorScheme.primary, size: 18) : null,
          onTap: () {
            controller.fontFamilyName.value = 'Default';
          },
        ),
      ),
    );
  }

  Widget _buildActionButtonRow(
    BuildContext context,
    FontModel fontModel,
    bool isCurrentActive,
    bool isSelectedModel,
    bool localExists,
  ) {
    final theme = Theme.of(context);

    if (isCurrentActive) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: theme.colorScheme.primary.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(30),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              i18n("font_currently_active"),
              style: TextStyle(fontSize: 12, color: theme.colorScheme.primary, fontWeight: FontWeight.w700),
            ),
            const SizedBox(width: 6),
            Icon(Icons.check_circle, color: theme.colorScheme.primary, size: 16),
            const SizedBox(width: 6),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                elevation: 0,
                backgroundColor: theme.colorScheme.primary,
                foregroundColor: theme.colorScheme.onPrimary,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
              ),
              onPressed: () {
                if (fontModel.files.length <= 1) {
                  controller.activateFontFamily(fontModel);
                } else {
                  _showFontWeightSelector(context, fontModel);
                }
              },
              child: Text(i18n("apply"), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      );
    }

    if (isSelectedModel && controller.fontState.value == DownloadState.downloading) {
      return AppStatusView(type: AppStatusType.loading, title: "", subtitle: "", isMini: true);
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (localExists) ...[
          IconButton(
            icon: Icon(Remix.delete_bin_6_line, size: 18, color: theme.colorScheme.error.withValues(alpha: 0.8)),
            tooltip: i18n("delete"),
            style: IconButton.styleFrom(
              padding: const EdgeInsets.all(10),
              backgroundColor: theme.colorScheme.error.withValues(alpha: 0.05),
            ),
            onPressed: () => controller.uninstallFontFamily(fontModel),
          ),
          const SizedBox(width: 10),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              elevation: 0,
              backgroundColor: theme.colorScheme.primary,
              foregroundColor: theme.colorScheme.onPrimary,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
            ),
            onPressed: () {
              if (fontModel.files.length <= 1) {
                controller.activateFontFamily(fontModel);
              } else {
                _showFontWeightSelector(context, fontModel);
              }
            },
            child: Text(i18n("apply"), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
          ),
        ] else
          ElevatedButton.icon(
            icon: const Icon(Remix.download_cloud_2_line, size: 15),
            label: Text(i18n("download"), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
            style: ElevatedButton.styleFrom(
              elevation: 0,
              backgroundColor: theme.colorScheme.primaryContainer,
              foregroundColor: theme.colorScheme.onPrimaryContainer,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
            ),
            onPressed: () async {
              controller.curFontModel.value = fontModel;
              final success = await FontDownloadManager.instance.downloadFontFamily(
                fontModel: fontModel,
                onStateChanged: (state) => controller.fontState.value = state,
              );
              if (success) {
                await controller.refreshFontDiskSizes();
                await controller.activateFontFamily(fontModel);
              } else {
                ToastUtil.show(i18n("font_load_failed"));
              }
            },
          ),
      ],
    );
  }

  void _showFontWeightSelector(BuildContext context, FontModel fontModel) async {
    final path = await AppPathManager().getFontFamilyFolderPath(fontModel.id);
    final fontDir = Directory(path);

    final List<File> downloadedFiles = [];
    if (await fontDir.exists()) {
      await for (final entity in fontDir.list()) {
        if (entity is File && (entity.path.endsWith('.ttf') || entity.path.endsWith('.otf'))) {
          final length = await entity.length();
          if (length > 0) {
            downloadedFiles.add(entity);
          }
        }
      }
    }

    if (downloadedFiles.isEmpty) {
      ToastUtil.show(i18n('font_not_downloaded_or_corrupted'));
      return;
    }

    Get.dialog(
      Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: Theme.of(Get.context!).colorScheme.surfaceContainerHigh,
        child: Container(
          padding: const EdgeInsets.all(24),
          constraints: const BoxConstraints(maxWidth: 400),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                i18n('font_selector_title', args: {"name": fontModel.name}),
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                i18n('font_selector_subtitle'),
                style: TextStyle(fontSize: 13, color: Theme.of(Get.context!).colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: 16),
              ConstrainedBox(
                constraints: BoxConstraints(maxHeight: MediaQuery.of(Get.context!).size.height * 0.45),
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                      leading: const Icon(Icons.auto_awesome),
                      title: Text(i18n('font_auto_weight')),
                      subtitle: Text(i18n('font_auto_weight_desc')),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      onTap: () {
                        Navigator.of(context).pop();
                        controller.activateFontFamily(fontModel);
                      },
                    ),
                    const Divider(height: 16),
                    ...downloadedFiles.map((file) {
                      final fileName = file.path.split(Platform.pathSeparator).last.split('.').first;
                      final fileNameWithExt = file.path.split(Platform.pathSeparator).last;
                      final label = fileName.split('-').last;

                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                        leading: const Icon(Icons.font_download_outlined),
                        title: Text(i18n('font_lock_weight', args: {"label": label})),
                        subtitle: Text(i18n('font_lock_weight_desc')),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        onTap: () async {
                          Navigator.of(context).pop();
                          final modifiedModel = FontModel(
                            id: fontModel.id,
                            name: "${fontModel.name} ($label)",
                            files: ["${fontModel.id}/$fileNameWithExt"],
                            desc: fontModel.desc,
                            official: fontModel.official,
                            license: fontModel.license,
                          );

                          controller.activateFontFamily(modifiedModel, targetFileName: fileNameWithExt);
                        },
                      );
                    }),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(i18n('cancel')))],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLicenseBadge(ThemeData theme, FontModel fontModel, String? diskSize) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (diskSize != null)
          Container(
            margin: const EdgeInsets.only(right: 6),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              diskSize,
              style: TextStyle(
                fontSize: 10,
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.2,
              ),
            ),
          ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            fontModel.license['name'] ?? "OFL",
            style: TextStyle(fontSize: 10, color: theme.colorScheme.onSurfaceVariant, fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );
  }
}
