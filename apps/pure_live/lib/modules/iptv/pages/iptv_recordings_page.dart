import 'dart:async' show unawaited;

import 'package:desen_ui/desen_ui.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart' show GoRouterHelper;
import 'package:pure_live/app/app.dart' show RouteNames, SettingsSectionRoute;
import 'package:pure_live/features/settings/settings.dart';
import 'package:pure_live/l10n/translations.dart';
import 'package:pure_live/modules/live/recorder/recorder.dart';
import 'package:pure_live/shared/shared.dart' show LiveWindow;

/// The IPTV module's own recording centre: the channels this module recorded,
/// and nothing else.
///
/// The recorder is one machine — the same engine, the same task store, the same
/// folder tree (`<root>/<day>/iptv/<channel>/<take>/`) — but the two modules
/// never show each other's takes. A channel recording has no live room behind it
/// to open, and a live room is not what a viewer expects to find under IPTV, so
/// the cut is made here by platform id rather than by copying the library.
final class IptvRecordingsPage extends ConsumerWidget {
  /// The module's recording page.
  const IptvRecordingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    final theme = DsTheme.of(context);
    final colors = theme.colors;
    final store = ref.watch(recordingTasksProvider);
    final engine = ref.read(recorderEngineProvider);
    final moduleName = t.common.moduleIptv;
    // Only the rows the module's own page can act on. A channel take with a file
    // on disk belongs to the library below, which lists every take rather than
    // the store's one row per channel.
    final attention = [
      for (final task in store.tasks)
        if (task.platform == kIptvRecordingPlatform && _needsRow(task)) task,
    ];
    final inset = LiveWindow.pageInset(MediaQuery.sizeOf(context).width);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(inset, DsSpace.s12, inset, 0),
          child: Row(
            spacing: DsSpace.s12,
            children: [
              Expanded(
                child: Text(t.navigation.record, style: theme.typography.title.copyWith(color: colors.text)),
              ),
              // The recorder's limits, naming template and folder are one set of
              // rules for both modules, so this opens the page the live centre
              // opens rather than a second copy of the same choices.
              DsButton(
                variant: DsButtonVariant.ghost,
                size: DsSize.sm,
                leading: const DsIcon(DsIcons.settings, size: 16),
                onPressed: () => _openSettings(context, ref),
                child: Text(t.recorder.settingsOpen),
              ),
            ],
          ),
        ),
        if (attention.isNotEmpty)
          Padding(
            padding: EdgeInsets.fromLTRB(inset, DsSpace.s8, inset, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: DsSpace.s4,
              children: [
                Text(t.recorder.runningTitle, style: theme.typography.labelStrong.copyWith(color: colors.textMuted)),
                for (final task in attention)
                  DsListRow(
                    leading: const DsIcon(DsIcons.disc3),
                    title: Text(task.roomTitle.isEmpty ? task.roomId : task.roomTitle),
                    description: Text(_stateLabel(t, task)),
                    trailing: engine.isRecording(task.id)
                        ? DsButton(
                            variant: DsButtonVariant.secondary,
                            size: DsSize.sm,
                            onPressed: () => unawaited(_stop(context, ref, task.id)),
                            child: Text(t.recorder.stopRecording),
                          )
                        : DsButton.icon(
                            variant: DsButtonVariant.ghost,
                            size: DsSize.sm,
                            onPressed: () => unawaited(ref.read(recordingTasksProvider.notifier).remove(task.id)),
                            icon: const DsIcon(DsIcons.trash2, size: 16),
                            semanticLabel: t.recorder.delete,
                          ),
                  ),
              ],
            ),
          ),
        Expanded(
          child: RecorderLibraryPane(
            showHeading: false,
            // The module's half of the shared tree.
            platforms: const {kIptvRecordingPlatform},
            platformName: (_) => moduleName,
            // An IPTV row leads back to a channel, never to a live room.
            openRoomLabel: t.iptv.openChannel,
            onPlay: (around, take) =>
                unawaited(playRecordingTake(context, ref, around: around, take: take, platformName: (_) => moduleName)),
            onOpenRoom: (take) => unawaited(_openChannel(context, take)),
          ),
        ),
      ],
    );
  }

  /// Whether a task still needs its row: a capture running, a join still going,
  /// and a saved row the library cannot show — a channel whose files were
  /// deleted keeps its row here so it can still be dropped.
  bool _needsRow(RecordingTask task) =>
      task.state != RecordingTaskState.stopped ||
      task.postProcessing ||
      task.warning == kRecordingFileDeletedWarning ||
      (task.filePath ?? '').trim().isEmpty;

  String _stateLabel(Translations t, RecordingTask task) => switch (task.state) {
    RecordingTaskState.recording => t.recorder.stateRecording,
    RecordingTaskState.waiting => t.recorder.filterWaiting,
    RecordingTaskState.failed => t.recorder.filterFailed,
    RecordingTaskState.stopped =>
      task.warning == kRecordingFileDeletedWarning ? t.recorder.stateFileDeleted : t.recorder.stateSaved,
  };

  Future<void> _stop(BuildContext context, WidgetRef ref, String taskId) async {
    final t = context.t;
    final failure = await ref.read(recorderEngineProvider).stop(taskId);
    if (!context.mounted) return;
    showDsToast(
      context: context,
      title: failure ?? t.recorder.stateSaved,
      status: failure == null ? DsStatus.success : DsStatus.danger,
    );
  }

  /// Back to the channel the take was made from. The recorder files a channel
  /// under its own id, so the row names the destination directly.
  Future<void> _openChannel(BuildContext context, RecordingTake take) async {
    final channel = take.roomId.trim();
    if (channel.isEmpty) return;
    await context.push(RouteNames.iptvPlay.replaceFirst(':channelId', channel));
  }

  void _openSettings(BuildContext context, WidgetRef ref) {
    openSettingsSection(ref, SettingsSection.recording);
    unawaited(context.push(SettingsSectionRoute(section: SettingsSection.recording.name).location));
  }
}
