import 'dart:async' show unawaited;

import 'package:desen_ui/desen_ui.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:pure_live/app/providers/sites_providers.dart' show sitesProvider;
import 'package:pure_live/features/recorder/recording_repository.dart';
import 'package:pure_live/features/recorder/recording_settings.dart';
import 'package:pure_live/features/recorder/recording_task.dart';
import 'package:pure_live/l10n/translations.dart';
import 'package:pure_live/shared/grids/card_grid.dart';

/// The recording centre (the reference's recorder page): the tasks in two
/// status tabs — 进行中 / 已完成, the reference's filters narrowed to what
/// the store can honestly tell today — each a full-width task list with a
/// per-row remove, and an empty state that says the recording itself
/// arrives with the player stack.
///
/// The tasks' engine is not wired yet: the store and its transitions stand
/// ready for the player stack (`media_core_recording_ffmpeg`), so the page
/// shows whatever tasks exist (an empty list until then) and never
/// pretends a capture is running.
final class RecorderPage extends ConsumerStatefulWidget {
  /// The recording centre page.
  const RecorderPage({super.key});

  @override
  ConsumerState<RecorderPage> createState() => _RecorderPageState();
}

/// The status the tabs filter by.
enum _RecorderTab { running, finished }

final class _RecorderPageState extends ConsumerState<RecorderPage> {
  _RecorderTab _tab = _RecorderTab.running;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final store = ref.watch(recordingTasksProvider);
    if (!store.ready) {
      return const CardList<RecordingTask>(items: [], isLoading: true);
    }
    // A running task is capturing; every ended one (saved or failed) is
    // finished — the two tabs between them cover the whole store.
    final visible = [
      for (final task in store.tasks)
        if (task.isRunning == (_tab == _RecorderTab.running)) task,
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(DsSpace.s20, DsSpace.s12, DsSpace.s20, DsSpace.s8),
          child: Row(
            spacing: DsSpace.s16,
            children: [
              DsSegmentedControl<_RecorderTab>(
                segments: [
                  DsSegment(value: _RecorderTab.running, label: Text(t.recorder.tabRunning)),
                  DsSegment(value: _RecorderTab.finished, label: Text(t.recorder.tabFinished)),
                ],
                value: _tab,
                onChanged: (value) => setState(() => _tab = value),
              ),
              if (_tab == _RecorderTab.finished && visible.isNotEmpty)
                Expanded(
                  child: Align(
                    alignment: AlignmentDirectional.centerEnd,
                    child: DsButton(
                      onPressed: () => unawaited(ref.read(recordingTasksProvider.notifier).clear()),
                      child: Text(t.recorder.clearFinished),
                    ),
                  ),
                ),
            ],
          ),
        ),
        Expanded(
          child: visible.isEmpty
              ? Center(
                  child: DsEmptyState(
                    icon: DsIcon(_tab == _RecorderTab.running ? DsIcons.disc3 : DsIcons.fileMp4),
                    title: Text(_tab == _RecorderTab.running ? t.recorder.emptyTitle : t.recorder.emptyFinishedTitle),
                    description: Text(t.recorder.emptyDescription),
                  ),
                )
              : CardList<RecordingTask>(
                  items: visible,
                  itemBuilder: (context, task) => _TaskCard(
                    task: task,
                    platformName: _platformName(task.platform),
                    onRemove: () => unawaited(ref.read(recordingTasksProvider.notifier).remove(task.id)),
                  ),
                ),
        ),
      ],
    );
  }

  /// A platform id's display name, or the id itself when the registry
  /// does not know it (a task from a site since removed).
  String _platformName(String id) {
    final site = ref.read(sitesProvider).getById(id);
    return site?.manifest.name['zh-CN'] ?? id;
  }
}

/// One recording task as a list card: the platform's letter tile, the
/// room title, its meta line, the state's badge with the session's size,
/// and the remove button.
final class _TaskCard extends StatelessWidget {
  const _TaskCard({required this.task, required this.platformName, required this.onRemove});

  final RecordingTask task;

  /// The task's platform's display name (the page resolves it).
  final String platformName;

  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final colors = DsTheme.colorsOf(context);
    final theme = DsTheme.of(context);
    final meta = [
      platformName,
      if (task.quality.isNotEmpty) task.quality else t.recorder.qualityBest,
      t.recorder.startedAt(time: _formatMoment(task.startedAt)),
    ].join(' · ');
    return DsPressable(
      onPressed: null,
      builder: (context, states, _) {
        final hovered = states.contains(WidgetState.hovered);
        return Container(
          padding: const EdgeInsets.all(DsSpace.s12),
          decoration: DsBoxDecoration(
            color: hovered ? colors.hover : null,
            borderRadius: BorderRadius.circular(theme.radii.card),
            shadows: hovered
                ? [DsShadow(color: colors.overlay, blur: 24, offset: const Offset(0, 8))]
                : const <DsShadow>[],
          ),
          child: Row(
            spacing: DsSpace.s12,
            children: [
              // The platform's letter tile: the card's identity mark until
              // platform logos arrive.
              Container(
                width: theme.sizes.lg,
                height: theme.sizes.lg,
                alignment: AlignmentDirectional.center,
                decoration: DsBoxDecoration(
                  color: colors.accentTint,
                  borderRadius: BorderRadius.circular(theme.radii.nested(theme.radii.card, DsSpace.s12)),
                ),
                child: Text(
                  _platformLetter(task.platform),
                  style: theme.typography.body.copyWith(fontWeight: FontWeight.w700, color: colors.accentText),
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: DsSpace.s3,
                  children: [
                    Text(
                      task.roomTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.typography.body.copyWith(fontWeight: FontWeight.w600, color: colors.text),
                    ),
                    Text(
                      meta,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.typography.caption.copyWith(color: colors.textMuted),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                spacing: DsSpace.s3,
                children: [
                  DsBadge(label: Text(_stateLabel(t, task.state)), status: _stateStatus(task.state)),
                  Text(
                    task.bytes > 0 ? _formatBytes(task.bytes) : '—',
                    style: theme.typography.caption.copyWith(color: colors.textSubtle),
                  ),
                ],
              ),
              DsPressable(
                semanticLabel: t.recorder.removeTask,
                onPressed: onRemove,
                builder: (context, states, _) {
                  final hovered = states.contains(WidgetState.hovered);
                  return DsIcon(
                    DsIcons.x,
                    size: theme.sizes.iconSm,
                    color: hovered ? colors.danger.fill : colors.textSubtle,
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  /// The state's badge label.
  static String _stateLabel(Translations t, RecordingTaskState state) => switch (state) {
    RecordingTaskState.recording => t.recorder.stateRecording,
    RecordingTaskState.stopped => t.recorder.stateStopped,
    RecordingTaskState.failed => t.recorder.stateFailed,
  };

  /// The state's badge tone: capturing is live information, a saved
  /// session is a success, a failed one is in danger.
  static DsStatus _stateStatus(RecordingTaskState state) => switch (state) {
    RecordingTaskState.recording => DsStatus.info,
    RecordingTaskState.stopped => DsStatus.success,
    RecordingTaskState.failed => DsStatus.danger,
  };

  /// The tile's letter: the platform id's first rune, uppercased.
  static String _platformLetter(String platform) {
    if (platform.isEmpty) return '?';
    return platform[0].toUpperCase();
  }
}

/// Renders a bytes figure the way a file manager would: the largest unit
/// that stays above one, one decimal from KB on.
String _formatBytes(int bytes) {
  const units = ['B', 'KB', 'MB', 'GB', 'TB'];
  var value = bytes.toDouble();
  var unit = 0;
  while (value >= 1024 && unit < units.length - 1) {
    value /= 1024;
    unit++;
  }
  return unit == 0 ? '${value.round()} B' : '${value.toStringAsFixed(1)} ${units[unit]}';
}

/// A gigabyte figure without the trailing `.0` a plain double would show.
String _formatGb(double gigabytes) =>
    gigabytes == gigabytes.roundToDouble() ? '${gigabytes.round()} GB' : '${gigabytes.toStringAsFixed(1)} GB';

/// A local moment for a task list row: the clock on today's entries, a
/// short date with the clock otherwise.
String _formatMoment(DateTime utc) {
  String two(int value) => value.toString().padLeft(2, '0');
  final local = utc.toLocal();
  final now = DateTime.now();
  final sameDay = local.year == now.year && local.month == now.month && local.day == now.day;
  final clock = '${two(local.hour)}:${two(local.minute)}';
  return sameDay ? clock : '${two(local.month)}-${two(local.day)} $clock';
}

/// The recorder's settings pane: where recordings land, how their files
/// name themselves, and how large one file may grow — the reference's key
/// recording settings, writing through as they change.
///
/// Public for the settings surface to embed once its sections are wired;
/// the folder picker itself arrives with the player stack, so the
/// directory row edits the path by hand for now and says so.
final class RecordingSettingsPane extends ConsumerWidget {
  /// The recorder settings pane.
  const RecordingSettingsPane({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    final settings = ref.watch(recordingSettingsProvider);
    return DsListSection(
      header: Text(t.recorder.settingsTitle),
      children: [
        DsListRow(
          leading: const DsIcon(DsIcons.folder),
          title: Text(t.recorder.saveDirTitle),
          description: Text(settings.saveDir.isEmpty ? t.recorder.saveDirDefault : settings.saveDir),
          onPressed: () => unawaited(_editSaveDir(context, ref)),
          showChevron: true,
        ),
        DsListRow(
          leading: const DsIcon(DsIcons.fileText),
          title: Text(t.recorder.namingTitle),
          description: Text(t.recorder.namingDescription),
          detail: Text(settings.namingTemplate),
          onPressed: () => unawaited(_editNaming(context, ref)),
          showChevron: true,
        ),
        DsListRow(
          leading: const DsIcon(DsIcons.hardDrive),
          title: Text(t.recorder.maxSizeTitle),
          description: Text(t.recorder.maxSizeDescription),
          detail: Text(_formatGb(settings.maxSizeGb)),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(DsSpace.s20, 0, DsSpace.s20, DsSpace.s8),
          child: DsSlider(
            value: settings.maxSizeGb,
            min: 1,
            max: 20,
            divisions: 19,
            onChanged: (value) => ref.read(recordingSettingsProvider.notifier).maxSizeGb = value,
            semanticLabel: t.recorder.maxSizeTitle,
          ),
        ),
      ],
    );
  }

  Future<void> _editSaveDir(BuildContext context, WidgetRef ref) {
    final t = context.t;
    return _editText(
      context,
      title: t.recorder.saveDirTitle,
      hint: t.recorder.saveDirDialogHint,
      initial: ref.read(recordingSettingsProvider).saveDir,
      onCommit: (value) => ref.read(recordingSettingsProvider.notifier).saveDir = value,
    );
  }

  Future<void> _editNaming(BuildContext context, WidgetRef ref) {
    final t = context.t;
    return _editText(
      context,
      title: t.recorder.namingTitle,
      hint: t.recorder.namingDialogHint,
      initial: ref.read(recordingSettingsProvider).namingTemplate,
      onCommit: (value) => ref.read(recordingSettingsProvider.notifier).namingTemplate = value,
    );
  }

  /// The one text edit the pane offers: a dialog with a single field,
  /// committed on confirm (the reference's directory dialog, without the
  /// picker).
  Future<void> _editText(
    BuildContext context, {
    required String title,
    required String hint,
    required String initial,
    required ValueChanged<String> onCommit,
  }) async {
    final t = context.t;
    final field = TextEditingController(text: initial);
    var value = initial;
    await showDsDialog<void>(
      context: context,
      builder: (context) => DsDialog(
        title: Text(title),
        description: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: DsSpace.s8,
          children: [
            Text(hint),
            DsTextField(
              controller: field,
              autofocus: true,
              clearable: true,
              placeholder: hint,
              onChanged: (next) => value = next,
              onSubmitted: (next) {
                value = next;
                Navigator.of(context).pop();
              },
              semanticLabel: title,
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
              onCommit(value);
            },
            child: Text(t.common.confirm),
          ),
        ],
      ),
    );
    field.dispose();
  }
}
