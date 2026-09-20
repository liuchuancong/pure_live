import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:remixicon/remixicon.dart';
import 'package:pure_live/common/index.dart';
import 'package:pure_live/plugins/file_utils.dart';
import 'package:pure_live/common/models/font_model.dart';
import 'package:pure_live/common/global/platform_utils.dart';
import 'package:pure_live/plugins/font_download_manager.dart';
import 'package:pure_live/common/global/app_path_manager.dart';
import 'package:pure_live/common/services/medels/download_status.dart';

class FontFamilyManagerPage extends GetView<SettingsService> {
  final bool isDanmakuSettings;

  const FontFamilyManagerPage({super.key, this.isDanmakuSettings = false});

  Rx<String> get currentFontRx {
    return isDanmakuSettings
        ? SettingsService.to.danmaku.danmakuFontFamilyName as Rx<String>
        : SettingsService.to.font.fontFamilyName as Rx<String>;
  }

  Future<void> _activateFont(FontModel model, {String? targetFileName}) async {
    if (isDanmakuSettings) {
      await SettingsService.to.font.activateDanmakuFontFamily(model, targetFileName: targetFileName);
      Get.updateLocale(Get.locale ?? const Locale('zh', 'CN'));
    } else {
      await SettingsService.to.font.activateFontFamily(model, targetFileName: targetFileName);
    }
  }

  Future<void> _setDefaultFont() async {
    if (isDanmakuSettings) {
      await SettingsService.to.font.resetDanmakuFontFamily();
      ToastUtil.show(i18n('font_reset_default'));
      return;
    }
    await SettingsService.to.font.resetAppFontFamily();
    ToastUtil.show(i18n('font_reset_default'));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mediaQuery = MediaQuery.of(context);
    final title = isDanmakuSettings ? i18n("change_danmaku_font_family") : i18n("font_family_settings");
    final openFolderLabel = i18n("recorder_open_folder");
    final useCompactFolderAction = mediaQuery.size.width < 520 || mediaQuery.textScaler.scale(14) > 18;

    Future<void> openFontFolder() async {
      final downloadDir = await AppPathManager().downloadDir;
      await FileUtils.openFileOrUrl(p.join(downloadDir.path, AppPathManager.fontDirectoryName));
    }

    SettingsService.to.font.refreshFontDiskSizes();

    return Scaffold(
      appBar: AppBar(
        title: Tooltip(
          message: title,
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w700, letterSpacing: 0.3),
          ),
        ),
        actions: [
          if (useCompactFolderAction)
            IconButton(
              key: const ValueKey('font-open-folder-action'),
              tooltip: openFolderLabel,
              onPressed: openFontFolder,
              icon: const Icon(Remix.folder_open_line, size: 20),
            )
          else
            TextButton.icon(
              key: const ValueKey('font-open-folder-action'),
              onPressed: openFontFolder,
              icon: const Icon(Remix.folder_open_line, size: 18),
              label: Text(openFolderLabel, maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: Obx(() {
        final fontModels = SettingsService.to.font.fontList;

        return CustomScrollView(
          physics: const PureLiveScrollPhysics(),
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  context.buildGroupTitle(i18n("factory_default_group")),
                  _buildPresetEnvironmentCard(theme),
                  const SizedBox(height: 28),
                  context.buildGroupTitle(i18n("cloud_font_group")),
                ]),
              ),
            ),
            if (fontModels.isEmpty)
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                sliver: SliverToBoxAdapter(
                  child: SizedBox(
                    height: 200,
                    child: AppStatusView(type: AppStatusType.loading, title: "", subtitle: ""),
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) => _buildFontCard(context, theme, fontModels[index]),
                    childCount: fontModels.length,
                  ),
                ),
              ),
            const SliverToBoxAdapter(child: SizedBox(height: 32)),
          ],
        );
      }),
    );
  }

  Widget _buildFontCard(BuildContext context, ThemeData theme, FontModel fontModel) {
    return Obx(() {
      final currentValue = currentFontRx.value;
      final isCurrentActive = currentValue == fontModel.id;
      final isSelectedModel = SettingsService.to.font.curFontModel.value == fontModel;
      final diskSize = SettingsService.to.font.fontFolderSizes[fontModel.id];
      final localExists = diskSize != null;

      return AnimatedContainer(
        key: ValueKey('font-family-${fontModel.id}'),
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
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: localExists
              ? () async {
                  final path = await AppPathManager().getFontFamilyFolderPath(fontModel.id);
                  await FileUtils.openFileOrUrl(path);
                }
              : null,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: Container(
              width: double.infinity,
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
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 10),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final stackMetadata = constraints.maxWidth < 440 || MediaQuery.textScalerOf(context).scale(1) > 1.5;
                  final name = Tooltip(
                    message: fontModel.name,
                    child: Text(
                      fontModel.name,
                      key: ValueKey('font-family-name-${fontModel.id}'),
                      maxLines: stackMetadata ? null : 2,
                      overflow: stackMetadata ? TextOverflow.visible : TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: AppTextStyles.t16.fontSize,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.1,
                      ),
                    ),
                  );
                  final badges = _buildLicenseBadge(theme, fontModel, diskSize);
                  final units = Text(
                    "${fontModel.files.length} ${i18n("font_units_suffix")}",
                    key: ValueKey('font-family-units-${fontModel.id}'),
                    style: AppTextStyles.t12Medium.copyWith(color: theme.hintColor.withValues(alpha: 0.6)),
                  );
                  final actions = _buildActionButtonRow(
                    context,
                    fontModel,
                    isCurrentActive,
                    isSelectedModel,
                    localExists,
                  );

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (stackMetadata) ...[
                        name,
                        const SizedBox(height: 8),
                        badges,
                      ] else
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(child: name),
                            const SizedBox(width: 12),
                            Flexible(child: badges),
                          ],
                        ),
                      const SizedBox(height: 8),
                      Text(
                        fontModel.desc,
                        key: ValueKey('font-family-description-${fontModel.id}'),
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.hintColor.withValues(alpha: 0.8),
                          height: 1.4,
                          letterSpacing: 0.2,
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (stackMetadata) ...[
                        units,
                        const SizedBox(height: 12),
                        Align(alignment: Alignment.centerRight, child: actions),
                      ] else
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Expanded(child: units),
                            const SizedBox(width: 12),
                            actions,
                          ],
                        ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      );
    });
  }

  Widget _buildPresetEnvironmentCard(ThemeData theme) {
    final bool isDefaultActive = currentFontRx.value == 'Default';

    return AnimatedContainer(
      key: const ValueKey('font-family-default'),
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
            PlatformUtils.isWindows ? "Microsoft YaHei" : i18n("font_system_default"),
            style: isDefaultActive
                ? AppTextStyles.t14Bold.copyWith(color: theme.colorScheme.primary)
                : AppTextStyles.t14SemiBold,
          ),
          subtitle: Text(
            i18n("factory_default_desc"),
            style: AppTextStyles.t11.copyWith(color: theme.hintColor.withValues(alpha: 0.7)),
          ),
          trailing: isDefaultActive ? Icon(Icons.check_circle, color: theme.colorScheme.primary, size: 18) : null,
          onTap: _setDefaultFont,
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
    final mediaQuery = MediaQuery.of(context);
    final useCompactActions = mediaQuery.size.width < 360 || mediaQuery.textScaler.scale(13) > 18;

    Widget applyButton() => useCompactActions
        ? IconButton.filledTonal(
            key: ValueKey('font-apply-${fontModel.id}'),
            tooltip: i18n("apply"),
            onPressed: () async {
              if (fontModel.files.length <= 1) {
                await _activateFont(fontModel);
              } else {
                await _showFontWeightSelector(context, fontModel);
              }
            },
            icon: const Icon(Icons.check_rounded),
          )
        : ElevatedButton(
            key: ValueKey('font-apply-${fontModel.id}'),
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.colorScheme.primaryContainer,
              foregroundColor: theme.colorScheme.onPrimaryContainer,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
            ),
            onPressed: () async {
              if (fontModel.files.length <= 1) {
                await _activateFont(fontModel);
              } else {
                await _showFontWeightSelector(context, fontModel);
              }
            },
            child: Text(
              i18n("apply"),
              style: AppTextStyles.t13Bold.copyWith(color: theme.colorScheme.onPrimaryContainer),
            ),
          );

    if (isCurrentActive) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: theme.colorScheme.primary.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(30),
        ),
        child: Wrap(
          alignment: WrapAlignment.end,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 6,
          runSpacing: 8,
          children: [
            Text(
              i18n("font_currently_active"),
              style: AppTextStyles.t12Bold.copyWith(color: theme.colorScheme.primary),
            ),
            Icon(Icons.check_circle, color: theme.colorScheme.primary, size: 16),
            applyButton(),
          ],
        ),
      );
    }

    if (isSelectedModel && SettingsService.to.font.fontState.value == DownloadState.downloading) {
      return AppStatusView(type: AppStatusType.loading, title: "", subtitle: "", isMini: true);
    }

    return Wrap(
      alignment: WrapAlignment.end,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 10,
      runSpacing: 8,
      children: [
        if (localExists) ...[
          IconButton(
            icon: Icon(Remix.delete_bin_6_line, size: 18, color: theme.colorScheme.error.withValues(alpha: 0.8)),
            tooltip: i18n("delete"),
            style: IconButton.styleFrom(
              padding: const EdgeInsets.all(10),
              backgroundColor: theme.colorScheme.error.withValues(alpha: 0.05),
            ),
            onPressed: () => SettingsService.to.font.uninstallFontFamily(fontModel),
          ),
          applyButton(),
        ] else if (useCompactActions)
          IconButton.filledTonal(
            key: ValueKey('font-download-${fontModel.id}'),
            tooltip: i18n("download"),
            onPressed: () => _downloadAndActivateFont(context, fontModel),
            icon: const Icon(Remix.download_cloud_2_line),
          )
        else
          ElevatedButton.icon(
            key: ValueKey('font-download-${fontModel.id}'),
            icon: const Icon(Remix.download_cloud_2_line, size: 15),
            label: Text(i18n("download"), style: AppTextStyles.t13Bold),
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.colorScheme.primaryContainer,
              foregroundColor: theme.colorScheme.onPrimaryContainer,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
            ),
            onPressed: () => _downloadAndActivateFont(context, fontModel),
          ),
      ],
    );
  }

  Future<void> _downloadAndActivateFont(BuildContext context, FontModel fontModel) async {
    SettingsService.to.font.curFontModel.value = fontModel;
    final success = await FontDownloadManager.instance.downloadFontFamily(
      fontModel: fontModel,
      onStateChanged: (state) => SettingsService.to.font.fontState.value = state,
    );
    if (success) {
      await SettingsService.to.font.refreshFontDiskSizes(force: true);
      if (fontModel.files.length <= 1) {
        await _activateFont(fontModel);
      } else if (context.mounted) {
        await _showFontWeightSelector(context, fontModel);
      }
    } else {
      ToastUtil.show(i18n("font_load_failed"));
    }
  }

  Future<void> _showFontWeightSelector(BuildContext context, FontModel fontModel) async {
    final path = await AppPathManager().getFontFamilyFolderPath(fontModel.id);
    final fontDir = Directory(path);
    final downloadedFiles = <File>[];

    if (await fontDir.exists()) {
      await for (final entity in fontDir.list()) {
        if (entity is File && FontFamilyFilePolicy.isSupportedPath(entity.path)) {
          if (await entity.length() > 0) downloadedFiles.add(entity);
        }
      }
    }
    downloadedFiles.sort((left, right) => left.path.compareTo(right.path));

    if (downloadedFiles.isEmpty) {
      ToastUtil.show(i18n('font_not_downloaded_or_corrupted'));
      return;
    }

    Get.dialog(
      FontWeightSelectorDialog(
        fontName: fontModel.name,
        downloadedFiles: downloadedFiles,
        onAutoSelected: () => _activateFont(fontModel),
        onFileSelected: (file) async {
          final fileNameWithExt = p.basename(file.path);
          final label = p.basenameWithoutExtension(file.path).split('-').last;
          final modifiedModel = FontModel(
            id: fontModel.id,
            name: "${fontModel.name} ($label)",
            files: ["${fontModel.id}/$fileNameWithExt"],
            desc: fontModel.desc,
            official: fontModel.official,
            license: fontModel.license,
          );
          await _activateFont(modifiedModel, targetFileName: fileNameWithExt);
        },
      ),
    );
  }

  Widget _buildLicenseBadge(ThemeData theme, FontModel fontModel, String? diskSize) {
    final licenseName = '${fontModel.license['name'] ?? "OFL"}';
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxBadgeWidth = constraints.maxWidth.isFinite ? constraints.maxWidth : 240.0;
        return Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            if (diskSize != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  diskSize,
                  style: AppTextStyles.t11Bold.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.2,
                  ),
                ),
              ),
            Tooltip(
              message: licenseName,
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: maxBadgeWidth),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    licenseName,
                    key: ValueKey('font-family-license-${fontModel.id}'),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.t11Bold.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

abstract final class FontFamilyFilePolicy {
  static bool isSupportedPath(String path) {
    final lowerPath = path.toLowerCase();
    return lowerPath.endsWith('.ttf') || lowerPath.endsWith('.otf');
  }
}

class FontWeightSelectorDialog extends StatelessWidget {
  const FontWeightSelectorDialog({
    super.key,
    required this.fontName,
    required this.downloadedFiles,
    required this.onAutoSelected,
    required this.onFileSelected,
  });

  final String fontName;
  final List<File> downloadedFiles;
  final Future<void> Function() onAutoSelected;
  final Future<void> Function(File file) onFileSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mediaQuery = MediaQuery.of(context);
    final compact = mediaQuery.size.width < 420 || mediaQuery.textScaler.scale(13) > 18;

    return Dialog(
      insetPadding: EdgeInsets.symmetric(horizontal: compact ? 12 : 40, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: theme.colorScheme.surfaceContainerHigh,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 400, maxHeight: mediaQuery.size.height - 48),
        child: SingleChildScrollView(
          key: const ValueKey('font-weight-selector-scroll'),
          padding: EdgeInsets.all(compact ? 16 : 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                i18n('font_selector_title', args: {"name": fontName}),
                key: const ValueKey('font-weight-selector-title'),
                style: AppTextStyles.t18Bold,
              ),
              const SizedBox(height: 8),
              Text(
                i18n('font_selector_subtitle'),
                style: AppTextStyles.t13.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: 16),
              _buildOption(
                context,
                key: const ValueKey('font-weight-auto'),
                icon: Icons.auto_awesome,
                title: i18n('font_auto_weight'),
                subtitle: i18n('font_auto_weight_desc'),
                onTap: () async {
                  Navigator.of(context).pop();
                  await onAutoSelected();
                },
              ),
              const Divider(height: 16),
              ...downloadedFiles.map((file) {
                final fileNameWithExt = p.basename(file.path);
                final label = p.basenameWithoutExtension(file.path).split('-').last;
                return _buildOption(
                  context,
                  key: ValueKey('font-weight-$fileNameWithExt'),
                  icon: Icons.font_download_outlined,
                  title: i18n('font_lock_weight', args: {"label": label}),
                  subtitle: i18n('font_lock_weight_desc'),
                  onTap: () async {
                    Navigator.of(context).pop();
                    await onFileSelected(file);
                  },
                );
              }),
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(i18n('cancel'))),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOption(
    BuildContext context, {
    required Key key,
    required IconData icon,
    required String title,
    required String subtitle,
    required Future<void> Function() onTap,
  }) {
    return InkWell(
      key: key,
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(padding: const EdgeInsets.only(top: 2), child: Icon(icon)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Tooltip(
                    message: title,
                    child: Text(
                      title,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Tooltip(
                    message: subtitle,
                    child: Text(
                      subtitle,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
