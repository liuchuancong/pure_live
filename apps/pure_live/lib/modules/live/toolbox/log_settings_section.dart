import 'dart:async' show unawaited;

import 'package:desen_ui/desen_ui.dart';
import 'package:file_picker/file_picker.dart' show FilePicker;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_log/live_log.dart' show LogLevel;
import 'package:pure_live/app/app.dart';
import 'package:pure_live/features/settings/pages/wallpaper_download_manager.dart' show openDownloadedPath;
import 'package:pure_live/features/settings/surface/settings_widgets.dart' show SettingsChoiceRow, SettingsConfigRow;
import 'package:pure_live/l10n/translations.dart';
import 'package:pure_live/shared/widgets/app_dialog.dart';
import 'package:pure_live/shared/widgets/choice_dialog.dart' show AdaptiveChoiceField;

/// The 日志 settings page: what the tree records, whether a rotating file is
/// written and how it is kept, and where the files land.
///
/// The console's own strip borrows [LogQuickSettings] from this file; the
/// rest of the card — the rotation limits and the folder picker — lives here,
/// reachable from the console's gear.
final class LogSettingsSection extends ConsumerStatefulWidget {
  /// The configuration card.
  const LogSettingsSection({super.key});

  @override
  ConsumerState<LogSettingsSection> createState() => _LogSettingsSectionState();
}

final class _LogSettingsSectionState extends ConsumerState<LogSettingsSection> {
  /// The file-size stops, in megabytes; a stored value outside them is added
  /// to the list so it still reads as chosen.
  static const List<int> _kFileSizeMb = [1, 2, 4, 8, 16];

  /// How many rotating files the viewer may keep; zero keeps every file.
  static const List<int> _kFilesKept = [0, 2, 5, 10];

  Future<void> _pickFolder() async {
    final t = context.t;
    try {
      final selected = await FilePicker.getDirectoryPath(dialogTitle: t.settings.storageFolderPick);
      if (selected == null || selected.trim().isEmpty) return;
      final saved = await ref.read(storageFolderOverridesProvider.notifier).set(StorageFolder.logs, selected);
      if (!mounted) return;
      if (!saved) {
        showDsToast(context: context, title: t.settings.storageFolderPermissionHint, status: DsStatus.danger);
        return;
      }
      showDsToast(context: context, title: t.settings.storageFoldersUpdated);
    } on Object {
      if (mounted) {
        showDsToast(context: context, title: t.settings.storageFolderPickFailed, status: DsStatus.danger);
      }
    }
  }

  Future<void> _resetFolder() async {
    await ref.read(storageFolderOverridesProvider.notifier).reset(StorageFolder.logs);
    if (!mounted) return;
    showDsToast(context: context, title: context.t.settings.storageFoldersUpdated);
  }

  /// The file's base name, edited in place: the rotating files take it on
  /// the next line written.
  Future<void> _editFileName() async {
    final t = context.t;
    final controller = TextEditingController(text: ref.read(logSettingsProvider).fileName);
    var value = controller.text;
    await showAppDialog<void>(
      context: context,
      builder: (context) => AppDialog(
        title: Text(t.settings.logFileName),
        description: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: DsSpace.s8,
          children: [
            Text(t.settings.logFileNameDesc),
            DsTextField(
              controller: controller,
              autofocus: true,
              clearable: true,
              placeholder: t.settings.logFileNameHint,
              onChanged: (next) => value = next,
              onSubmitted: (next) {
                value = next;
                Navigator.of(context).pop();
                unawaited(ref.read(logSettingsProvider.notifier).setFileName(value));
              },
              semanticLabel: t.settings.logFileName,
            ),
          ],
        ),
        actions: [
          DsButton(
            variant: DsButtonVariant.secondary,
            onPressed: () => Navigator.of(context).pop(),
            child: Text(t.common.cancel),
          ),
          DsButton(
            onPressed: () {
              Navigator.of(context).pop();
              unawaited(ref.read(logSettingsProvider.notifier).setFileName(value));
            },
            child: Text(t.common.confirm),
          ),
        ],
      ),
    );
    controller.dispose();
  }

  Future<void> _openFolder(String path) async {
    await openDownloadedPath(context, path, failedTitle: context.t.settings.logOpenFailed);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final theme = DsTheme.of(context);
    final colors = DsTheme.colorsOf(context);
    final settings = ref.watch(logSettingsProvider);
    final controller = ref.read(logSettingsProvider.notifier);
    final custom = ref.watch(storageFolderOverridesProvider).containsKey(StorageFolder.logs);
    // A cap imported from outside the stops still shows as chosen.
    List<int> stops(List<int> base, int current) => ([...base, if (!base.contains(current)) current]..sort());
    final fileMaxMb = (settings.fileMaxBytes / (1024 * 1024)).round();
    final filesKept = _kFilesKept.contains(settings.filesKept) ? settings.filesKept : 0;
    return DsListSection(
      // The recorded level reads at the header's end: the one fact to know
      // before reading the console.
      header: Row(
        spacing: DsSpace.s8,
        children: [
          Expanded(child: Text(t.toolbox.logsSection)),
          Text(t.toolbox.logsLevelLabel, style: theme.typography.caption.copyWith(color: colors.textMuted)),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: DsSpace.s6, vertical: 2),
            decoration: DsBoxDecoration(color: colors.accentTint, borderRadius: BorderRadius.circular(6)),
            child: Text(
              settings.level.label,
              style: theme.typography.numeric(
                theme.typography.caption.copyWith(color: colors.accentText, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
      children: [
        SettingsChoiceRow<LogLevel>(
          leading: const DsIcon(DsIcons.gauge),
          title: t.settings.logLevel,
          description: t.settings.logLevelDesc,
          value: settings.level,
          options: [
            for (final level in const [
              LogLevel.trace,
              LogLevel.debug,
              LogLevel.info,
              LogLevel.warning,
              LogLevel.error,
              LogLevel.fatal,
            ])
              DsSelectOption(value: level, label: level.label),
          ],
          placeholder: t.settings.logLevel,
          onChanged: (value) => unawaited(controller.setLevel(value)),
        ),
        SettingsConfigRow(
          leading: const DsIcon(DsIcons.hardDrive),
          title: t.settings.logFile,
          description: t.settings.logFileDesc,
          // The file's name reads beside the switch; the folder below is
          // where it lives.
          detail: Text('${settings.fileName}.log'),
          control: DsSwitch(
            value: settings.fileEnabled,
            semanticLabel: t.settings.logFile,
            onChanged: (value) => unawaited(controller.setFileEnabled(enabled: value)),
          ),
        ),
        // The rotation rules only matter while a file is written; they follow
        // the switch in and out.
        if (settings.fileEnabled) ...[
          DsListRow(
            leading: const DsIcon(DsIcons.fileText),
            title: Text(t.settings.logFileName),
            description: Text(t.settings.logFileNameDesc),
            detail: Text('${settings.fileName}.log'),
            showChevron: true,
            onPressed: () => unawaited(_editFileName()),
          ),
          SettingsChoiceRow<int>(
            leading: const DsIcon(DsIcons.ruler),
            title: t.settings.logFileMaxBytes,
            description: t.settings.logFileMaxBytesDesc,
            value: fileMaxMb,
            options: [for (final mb in stops(_kFileSizeMb, fileMaxMb)) DsSelectOption(value: mb, label: '$mb MB')],
            placeholder: t.settings.logFileMaxBytes,
            onChanged: (value) => unawaited(controller.setFileMaxBytes(value * 1024 * 1024)),
          ),
          SettingsChoiceRow<int>(
            leading: const DsIcon(DsIcons.archive),
            title: t.settings.logFilesKept,
            description: t.settings.logFilesKeptDesc,
            value: filesKept,
            options: [
              DsSelectOption(value: 0, label: t.settings.logFilesKeptUnlimited),
              for (final kept in _kFilesKept.where((kept) => kept > 0)) DsSelectOption(value: kept, label: '$kept'),
            ],
            placeholder: t.settings.logFilesKept,
            onChanged: (value) => unawaited(controller.setFilesKept(value)),
          ),
        ],
        // How 保存到本地 encodes the ring: it works with the file switch
        // off too, so it is not a child of that switch.
        SettingsChoiceRow<LogExportFormat>(
          leading: const DsIcon(DsIcons.fileText),
          title: t.settings.logExportFormat,
          description: t.settings.logExportFormatDesc,
          value: settings.exportFormat,
          options: [
            DsSelectOption(value: LogExportFormat.txt, label: t.settings.logExportFormatText),
            DsSelectOption(value: LogExportFormat.log, label: t.settings.logExportFormatLog),
            DsSelectOption(value: LogExportFormat.jsonLines, label: t.settings.logExportFormatJsonl),
          ],
          placeholder: t.settings.logExportFormat,
          onChanged: (value) => unawaited(controller.setExportFormat(value)),
        ),
        // The folder is chosen right here: the console's saved copy and the
        // rotating files both land in it.
        DsListRow(
          leading: const DsIcon(DsIcons.folder),
          title: Text(t.settings.logDirectory),
          description: DsTooltip(
            message: settings.directory,
            child: Text(settings.directory, maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
          detail: Text(custom ? t.settings.storageFolderCustomLabel : t.settings.storageFolderDefaultLabel),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              DsButton(
                variant: DsButtonVariant.ghost,
                size: DsSize.sm,
                onPressed: () => unawaited(_pickFolder()),
                child: Text(t.settings.storageFolderPick),
              ),
              DsButton.icon(
                variant: DsButtonVariant.ghost,
                size: DsSize.sm,
                semanticLabel: t.toolbox.logsOpenFolder,
                onPressed: settings.directory.isEmpty ? null : () => unawaited(_openFolder(settings.directory)),
                icon: const DsIcon(DsIcons.folderOpen, size: 16),
              ),
            ],
          ),
        ),
        DsListRow(
          leading: const DsIcon(DsIcons.rotateCcw),
          title: Text(t.settings.logDirectoryResetTitle),
          description: Text(custom ? t.settings.logDirectoryResetDesc : t.settings.logDirectoryDefaultInUse),
          onPressed: custom ? () => unawaited(_resetFolder()) : null,
        ),
      ],
    );
  }
}

/// The two controls the log page's accordion shows: what the tree records at
/// and whether a file is written. Everything else — the rotation limits, the
/// folder picker — belongs to the settings page, which the page's gear opens,
/// so the console keeps the height.
final class LogQuickSettings extends ConsumerWidget {
  /// The page's quick controls.
  const LogQuickSettings({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    final settings = ref.watch(logSettingsProvider);
    final controller = ref.read(logSettingsProvider.notifier);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DsListRow(
          leading: const DsIcon(DsIcons.gauge),
          title: Text(t.settings.logLevel),
          description: Text(t.settings.logLevelDesc),
          trailing: SizedBox(
            width: 160,
            child: AdaptiveChoiceField<LogLevel>(
              value: settings.level,
              title: t.settings.logLevel,
              semanticLabel: t.settings.logLevel,
              onChanged: (level) => unawaited(controller.setLevel(level)),
              options: [
                for (final level in const [
                  LogLevel.trace,
                  LogLevel.debug,
                  LogLevel.info,
                  LogLevel.warning,
                  LogLevel.error,
                  LogLevel.fatal,
                ])
                  DsSelectOption(value: level, label: level.label),
              ],
            ),
          ),
        ),
        DsListRow(
          leading: const DsIcon(DsIcons.hardDrive),
          title: Text(t.settings.logFile),
          description: Text(t.settings.logFileDesc),
          trailing: DsSwitch(
            value: settings.fileEnabled,
            semanticLabel: t.settings.logFile,
            onChanged: (value) => unawaited(controller.setFileEnabled(enabled: value)),
          ),
        ),
      ],
    );
  }
}
