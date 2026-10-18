import 'dart:async';
import 'dart:io' show Directory;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:open_file/open_file.dart';
import 'package:pure_live/features/recorder/recorder_preferences.dart';
import 'package:pure_live/features/recorder/recorder_providers.dart';
import 'package:pure_live/features/settings/widgets/settings_chooser.dart';
import 'package:pure_live/l10n/generated/strings.g.dart';
import 'package:pure_settings_ui/pure_settings_ui.dart';
import 'package:pure_uikit/pure_uikit.dart';

/// The recording settings page (the reference's `SettingsSection.recording`,
/// `record_settings_page.dart`, trimmed to the backed knobs): where recordings
/// are written and how long the segments are.
///
/// The reference's quality/naming/FFmpeg/reconnect groups have no backing in
/// this build's recorder engine and stay out. Changing the directory re-opens
/// the recorder runtime — the same path the recorder page's own row drives.
final class RecordSettingsPage extends ConsumerWidget {
  /// The recording settings page.
  const new({super.key});

  static const List<int> _segmentChoices = [1, 2, 5, 10, 15, 30, 60];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    final preferences = ref.watch(recorderPreferencesProvider).value ?? const RecorderPreferences();
    final root = ref.watch(recorderRootProvider).value ?? preferences.outputDirectory;
    return PureScaffold(
      appBar: PureAppBar(title: t.settings.recordingTitle),
      body: SettingsList(
        sections: [
          SettingsSection(
            title: Text(t.settings.recordingTitle),
            tiles: [
              SettingsTile.navigation(
                leading: const Icon(Icons.folder_outlined),
                title: Text(t.recorder.outputDirectory),
                description: Text(root.isEmpty ? t.recorder.outputDirectoryDefault : root),
                onPressed: (_) => unawaited(_chooseDirectory(context, ref, preferences)),
              ),
              SettingsTile.navigation(
                leading: const Icon(Icons.video_settings_outlined),
                title: Text(t.recorder.segmentLength),
                value: Text(t.recorder.minutesValue(minutes: preferences.segmentMinutes)),
                onPressed: (_) => unawaited(_chooseSegment(context, ref, preferences)),
              ),
              SettingsTile.navigation(
                leading: const Icon(Icons.folder_open_outlined),
                title: Text(t.recorder.openFolder),
                onPressed: (_) => unawaited(_openFolder(context, root)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _chooseDirectory(BuildContext context, WidgetRef ref, RecorderPreferences preferences) async {
    final t = context.t;
    final current = preferences.outputDirectory;
    final selected = await FilePickerPlatform.instance.getDirectoryPath(
      dialogTitle: t.recorder.chooseDirectory,
      initialDirectory: current.isEmpty ? null : current,
    );
    if (selected == null || selected == current || !context.mounted) {
      return;
    }
    await updateRecorderPreferences(
      () => ref.read(recorderPreferencesStoreProvider.future),
      (value) => value.copyWith(outputDirectory: selected),
    );
  }

  Future<void> _chooseSegment(BuildContext context, WidgetRef ref, RecorderPreferences preferences) async {
    final t = context.t;
    final picked = await showSettingsChooser<int>(
      context,
      title: t.recorder.segmentLength,
      current: preferences.segmentMinutes,
      options: [for (final minutes in _segmentChoices) (minutes, t.recorder.minutesValue(minutes: minutes))],
    );
    if (picked == null || !context.mounted) {
      return;
    }
    await updateRecorderPreferences(
      () => ref.read(recorderPreferencesStoreProvider.future),
      (value) => value.copyWith(segmentMinutes: picked),
    );
  }

  Future<void> _openFolder(BuildContext context, String root) async {
    final t = context.t;
    try {
      final result = await OpenFile.open(root.isEmpty ? Directory.systemTemp.path : root);
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
