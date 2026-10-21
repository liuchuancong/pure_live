import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_log/live_log.dart' show LogLevel;
import 'package:open_file/open_file.dart';
import 'package:pure_live/app/app_providers.dart';
import 'package:pure_live/features/settings/widgets/settings_chrome.dart';
import 'package:pure_live/l10n/generated/strings.g.dart';
import 'package:pure_live/system/configuration/app_preferences_providers.dart';
import 'package:pure_live/system/environment/app_directory.dart';
import 'package:pure_live/system/logging/app_log.dart';
import 'package:pure_settings_ui/pure_settings_ui.dart';
import 'package:pure_uikit/pure_uikit.dart';

/// The log page (the reference's `SettingsSection.log`, `log_page.dart`):
/// the tree's minimum level and a way to get the recent records out.
///
/// The level is stored and applied live — `LiveLog.setMinLevel` re-tunes the
/// running tree, and start-up replays the stored choice. Empty selection
/// means "follow the build default" (trace in debug, info in release).
/// Export copies the in-memory ring (the last 500 records) as JSON Lines to
/// the clipboard; the rotating files stay under the data area's logs tree.
final class LogsSettingsPage extends ConsumerWidget {
  /// The log settings page.
  const new({super.key});

  /// The selectable thresholds: the build default plus the levels that mean
  /// something as a minimum (a fatal-only tree is what `off` is for).
  static const List<String> _choices = ['', 'trace', 'debug', 'info', 'warning', 'error', 'off'];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    final preferences = ref.watch(appPreferencesProvider);
    return SettingsChrome(
      title: t.logs.title,
      body: SettingsList(
        sections: [
          SettingsSection(
            title: Text(t.logs.title),
            tiles: [
              SettingsTile.navigation(
                leading: const Icon(Icons.tune_outlined),
                title: Text(t.logs.level),
                description: Text(t.logs.levelHint),
                value: Text(_levelLabel(t, preferences.logLevelId)),
                onPressed: (_) => unawaited(_chooseLevel(context, ref, preferences.logLevelId)),
              ),
              SettingsTile.navigation(
                leading: const Icon(Icons.share_outlined),
                title: Text(t.logs.export),
                onPressed: (_) => unawaited(_export(context, ref)),
              ),
              SettingsTile.navigation(
                leading: const Icon(Icons.folder_open_outlined),
                title: Text(t.logs.openFolder),
                onPressed: (_) => unawaited(_openFolder(context, ref)),
              ),
            ],
          ),
          SettingsSection(
            tiles: [
              CustomSettingsTile(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: PureSpacing.lg),
                  child: Text(
                    t.logs.note,
                    style: PureTheme.of(context).text.caption.copyWith(color: PureTheme.of(context).colors.textSecondary),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static String _levelLabel(Translations t, String levelId) => switch (levelId) {
    '' => t.logs.levelDefault,
    'trace' => t.logs.levelTrace,
    'debug' => t.logs.levelDebug,
    'info' => t.logs.levelInfo,
    'warning' => t.logs.levelWarning,
    'error' => t.logs.levelError,
    'off' => t.logs.levelOff,
    _ => t.logs.levelDefault,
  };

  /// Maps a stored id to the tree threshold to apply — the shared helper in
  /// `app_log.dart`; kept here as the page's own words for the empty id.
  static LogLevel? levelFor(String levelId) => logLevelForStoredId(levelId);

  Future<void> _chooseLevel(BuildContext context, WidgetRef ref, String current) async {
    final t = context.t;
    final picked = await showPureDialog<String>(
      context: context,
      title: t.logs.level,
      child: Builder(
        builder: (dialogContext) => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final id in _choices)
              PureListRow(
                title: _levelLabel(t, id),
                leading: Icon(
                  id == current ? Icons.check_circle : Icons.radio_button_unchecked,
                  color: id == current ? PureTheme.of(dialogContext).colors.primary : null,
                ),
                selected: id == current,
                onTap: () => Navigator.of(dialogContext).pop(id),
              ),
          ],
        ),
      ),
    );
    if (picked == null || !context.mounted) {
      return;
    }
    await ref.read(appPreferencesProvider.notifier).update((p) => p.copyWith(logLevelId: picked));
    // The stored empty id keeps the build default; make that literal by
    // re-applying info so a switch back from e.g. trace is felt immediately.
    applyStoredLogLevel(ref.read(appLogProvider), picked.isEmpty ? 'info' : picked);
  }

  Future<void> _export(BuildContext context, WidgetRef ref) async {
    final t = context.t;
    final lines = ref.read(appLogProvider).ring.exportJsonLines();
    final count = lines.isEmpty ? 0 : lines.split('\n').length;
    if (count == 0) {
      PureToast.show(context, t.logs.exportEmpty);
      return;
    }
    await Clipboard.setData(ClipboardData(text: lines));
    if (context.mounted) {
      PureToast.show(context, t.logs.exportDone(count: count), type: PureToastType.success);
    }
  }

  Future<void> _openFolder(BuildContext context, WidgetRef ref) async {
    final t = context.t;
    try {
      final directory = await ref.read(pathsProvider).directory(AppDirectory.logs);
      final result = await OpenFile.open(directory.path);
      if (result.type != ResultType.done && context.mounted) {
        PureToast.show(context, t.recorder.folderNotOpened, type: PureToastType.error);
      }
    } on Object {
      if (context.mounted) {
        PureToast.show(context, t.recorder.folderNotOpened, type: PureToastType.error);
      }
    }
  }
}
