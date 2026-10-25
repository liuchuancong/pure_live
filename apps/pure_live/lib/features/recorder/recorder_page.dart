import 'dart:async' show unawaited;

import 'package:desen_ui/desen_ui.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart' show GoRouterHelper;
import 'package:live_sites/live_sites.dart' show LiveAudienceMetricType, LiveRoom;
import 'package:open_file/open_file.dart' show OpenFile, ResultType;
import 'package:path/path.dart' as p;

import 'package:pure_live/app/providers/sites_providers.dart' show sitesProvider;
import 'package:pure_live/app/routing/app_router.dart' show RoomRoute;
import 'package:pure_live/features/favorites/follow_repository.dart' show followsProvider;
import 'package:pure_live/features/history/history_repository.dart' show historyProvider;
import 'package:pure_live/features/recorder/recorder_engine.dart' show recorderEngineProvider;
import 'package:pure_live/features/recorder/recording_repository.dart';
import 'package:pure_live/features/recorder/recording_settings.dart';
import 'package:pure_live/features/recorder/recording_task.dart';
import 'package:pure_live/l10n/translations.dart';
import 'package:pure_live/shared/grids/card_grid.dart';
import 'package:pure_live/shared/images/app_image_cache.dart' show cachedImage;
import 'package:pure_live/shared/platforms/platform_display.dart' show localizedSiteName;
import 'package:pure_live/shared/utils/audience_format.dart' show AudienceFormat;

/// The recording centre (the reference's recorder page): five status
/// filters with their counts — All / Recording / Waiting / Saved / Failed — each a
/// full-width task list with a per-row menu, and a filter-specific empty
/// state.
///
/// The tasks come from the FFmpeg engine the room page starts
/// (`media_core_recording_ffmpeg`), through the store's own transitions:
/// a running capture updates its bytes and ends into saved or failed, and
/// the menu stops a session without deleting its files.
final class RecorderPage extends ConsumerStatefulWidget {
  /// The recording centre page.
  const RecorderPage({super.key});

  @override
  ConsumerState<RecorderPage> createState() => _RecorderPageState();
}

/// The status a task is filtered by; `saved` is the model's `stopped`
/// state (its file was kept), under the word the page uses.
enum _RecorderFilter {
  all,
  recording,
  waiting,
  saved,
  failed;

  /// Whether [task] belongs under this filter.
  bool matches(RecordingTask task) => switch (this) {
    all => true,
    recording => task.state == RecordingTaskState.recording,
    waiting => task.state == RecordingTaskState.waiting,
    saved => task.state == RecordingTaskState.stopped,
    failed => task.state == RecordingTaskState.failed,
  };

  /// The empty state's icon for this filter.
  DsIconData get icon => switch (this) {
    all || recording => DsIcons.disc3,
    waiting => DsIcons.clock,
    saved => DsIcons.fileMp4,
    failed => DsIcons.circleAlert,
  };
}

final class _RecorderPageState extends ConsumerState<RecorderPage> {
  _RecorderFilter _filter = _RecorderFilter.all;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final theme = DsTheme.of(context);
    final colors = DsTheme.colorsOf(context);
    final store = ref.watch(recordingTasksProvider);
    // The tasks store their room's identity only; the room itself (cover,
    // streamer, audience) is the snapshot the follows and history boxes
    // keep under the same key (`platform:roomId`), so the card shows real
    // room facts without the recording model growing copies of them.
    final follows = ref.watch(followsProvider);
    final history = ref.watch(historyProvider);
    String keyOf(LiveRoom room) => '${room.ref.platform}:${room.ref.roomId}';
    final rooms = <String, LiveRoom>{
      for (final (room, _) in history.records) keyOf(room): room,
      for (final room in follows.rooms) keyOf(room): room,
    };
    final counts = <_RecorderFilter, int>{
      for (final filter in _RecorderFilter.values) filter: store.tasks.where(filter.matches).length,
    };
    final visible = [
      for (final task in store.tasks)
        if (_filter.matches(task)) task,
    ];
    final noneAtAll = store.tasks.isEmpty;

    final Widget content;
    if (!store.ready) {
      content = const CardList<RecordingTask>(items: [], isLoading: true);
    } else if (visible.isEmpty) {
      content = Center(
        child: DsEmptyState(
          icon: DsIcon(_filter.icon),
          title: Text(
            noneAtAll ? t.recorder.emptyTitle : t.recorder.emptyFilterTitle(status: _filterLabel(t, _filter)),
          ),
          description: noneAtAll ? Text(t.recorder.emptyDescription) : null,
        ),
      );
    } else {
      content = CardList<RecordingTask>(
        items: visible,
        itemBuilder: (context, task) => _TaskCard(
          task: task,
          room: rooms[task.id] ?? rooms['${task.platform.toLowerCase()}:${task.roomId.trim()}'],
          platformName: _platformName(task.platform),
          onOpen: () => unawaited(context.push(RoomRoute(platform: task.platform, roomId: task.roomId).location)),
          onStop: ref.read(recorderEngineProvider).isRecording(task.id) ? () => unawaited(_stop(task.id)) : null,
          onDelete: () => unawaited(ref.read(recordingTasksProvider.notifier).remove(task.id)),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(DsSpace.s20, DsSpace.s12, DsSpace.s20, 0),
          child: Row(
            spacing: DsSpace.s12,
            children: [
              Expanded(
                child: Text(t.navigation.record, style: theme.typography.title.copyWith(color: colors.text)),
              ),
              DsButton(
                variant: DsButtonVariant.ghost,
                size: DsSize.sm,
                leading: const DsIcon(DsIcons.settings, size: 16),
                onPressed: () => unawaited(_openSettings()),
                child: Text(t.recorder.settingsOpen),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(DsSpace.s20, DsSpace.s8, DsSpace.s20, DsSpace.s8),
          child: DsChoiceChips<_RecorderFilter>(
            value: _filter,
            onChanged: (value) => setState(() => _filter = value),
            semanticLabel: t.recorder.filterLabel,
            options: [
              for (final filter in _RecorderFilter.values)
                DsChipOption(value: filter, label: Text('${_filterLabel(t, filter)}  ${counts[filter] ?? 0}')),
            ],
          ),
        ),
        Expanded(child: content),
      ],
    );
  }

  /// Ends a running capture; its finished segments stay, and the task's
  /// saved state arrives through the store the page already watches.
  Future<void> _stop(String taskId) async {
    final failure = await ref.read(recorderEngineProvider).stop(taskId);
    if (!mounted) return;
    showDsToast(
      context: context,
      title: failure ?? context.t.recorder.stateSaved,
      status: failure == null ? DsStatus.success : DsStatus.danger,
    );
  }

  /// The recorder settings, as the pane the settings surface will embed
  /// beside this page too; until its section exists, the header action
  /// opens it in a panel over the page.
  Future<void> _openSettings() => showDsDialog<void>(
    context: context,
    builder: (dialogContext) => DsDialog(
      title: Text(dialogContext.t.recorder.settingsOpen),
      icon: const DsIcon(DsIcons.settings),
      description: const RecordingSettingsPane(),
      actions: [
        DsButton(
          variant: DsButtonVariant.secondary,
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: Text(dialogContext.t.common.close),
        ),
      ],
      style: const DsDialogStyle(width: 460),
    ),
  );

  /// A platform id's display name, or the id itself when the registry
  /// does not know it (a task from a site since removed).
  String _platformName(String id) {
    final site = ref.read(sitesProvider).getById(id);
    return site == null ? id : localizedSiteName(site);
  }
}

/// A filter's word, without its count.
String _filterLabel(Translations t, _RecorderFilter filter) => switch (filter) {
  _RecorderFilter.all => t.recorder.filterAll,
  _RecorderFilter.recording => t.recorder.filterRecording,
  _RecorderFilter.waiting => t.recorder.filterWaiting,
  _RecorderFilter.saved => t.recorder.filterSaved,
  _RecorderFilter.failed => t.recorder.filterFailed,
};

/// One recording task as a list card: the room's cover (the platform's
/// letter when it has none), the streamer and room title, the platform and
/// audience line, the state's badge with the session's size, and the "⋮"
/// menu.
///
/// The card's room facts come from the follows/history snapshots; a task
/// whose room is stored in neither keeps its title and platform and shows
/// the letter tile.
final class _TaskCard extends StatelessWidget {
  const _TaskCard({
    required this.task,
    required this.room,
    required this.platformName,
    required this.onOpen,
    required this.onDelete,
    this.onStop,
  });

  final RecordingTask task;

  /// The room's stored snapshot, when follows or history has one.
  final LiveRoom? room;

  /// The task's platform's display name (the page resolves it).
  final String platformName;

  /// Opens the room.
  final VoidCallback onOpen;

  /// Drops the task (the menu has confirmed it).
  final VoidCallback onDelete;

  /// Stops a running capture, null when the task is not being recorded.
  final VoidCallback? onStop;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final theme = DsTheme.of(context);
    final colors = DsTheme.colorsOf(context);
    final wide = MediaQuery.sizeOf(context).width >= 840;
    final (coverWidth, coverHeight) = wide ? (128.0, 72.0) : (96.0, 54.0);
    final streamer = room?.anchor?.name.trim() ?? '';
    final storedTitle = task.roomTitle.trim();
    final roomTitle = room?.content.title.trim() ?? '';
    final title = storedTitle.isNotEmpty ? storedTitle : (roomTitle.isNotEmpty ? roomTitle : task.roomId);
    final audience = _audienceOf(room);
    final cover = room?.content.coverUrl.trim() ?? '';
    final meta = [
      platformName,
      if (audience.isNotEmpty) audience,
      if (task.quality.isNotEmpty) task.quality else t.recorder.qualityBest,
      t.recorder.startedAt(time: _formatMoment(task.startedAt)),
    ].join(' · ');
    return DsCard(
      onPressed: onOpen,
      semanticLabel: title,
      style: DsCardStyle(
        padding: const EdgeInsets.all(DsSpace.s12),
        borderRadius: BorderRadius.circular(theme.radii.card),
      ),
      child: Row(
        spacing: DsSpace.s12,
        children: [
          DsImage(
            image: cover.isEmpty ? null : cachedImage(cover),
            width: coverWidth,
            height: coverHeight,
            semanticLabel: title,
            fallback: _CoverFallback(letter: _platformLetter(task.platform)),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: DsSpace.s3,
              children: [
                Text(
                  streamer.isEmpty ? title : streamer,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.typography.body.copyWith(fontWeight: FontWeight.w600, color: colors.text),
                ),
                if (streamer.isNotEmpty)
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.typography.caption.copyWith(color: colors.textMuted),
                  ),
                Text(
                  meta,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.typography.caption.copyWith(color: colors.textMuted),
                ),
                if (task.state == RecordingTaskState.failed && task.errorText.trim().isNotEmpty)
                  Text(
                    task.errorText.trim(),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.typography.caption.copyWith(color: colors.danger.text),
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
          _TaskMenu(
            task: task,
            hasFile: (task.filePath ?? '').trim().isNotEmpty,
            onOpen: onOpen,
            onStop: onStop,
            onDelete: onDelete,
          ),
        ],
      ),
    );
  }

  /// The state's badge label.
  static String _stateLabel(Translations t, RecordingTaskState state) => switch (state) {
    RecordingTaskState.recording => t.recorder.stateRecording,
    RecordingTaskState.waiting => t.recorder.stateWaiting,
    RecordingTaskState.stopped => t.recorder.stateSaved,
    RecordingTaskState.failed => t.recorder.stateFailed,
  };

  /// The state's badge tone: capturing is live information, waiting is a
  /// pending state, a saved session is a success, a failed one is danger.
  static DsStatus _stateStatus(RecordingTaskState state) => switch (state) {
    RecordingTaskState.recording => DsStatus.info,
    RecordingTaskState.waiting => DsStatus.warning,
    RecordingTaskState.stopped => DsStatus.success,
    RecordingTaskState.failed => DsStatus.danger,
  };

  /// The tile's letter: the platform id's first rune, uppercased.
  static String _platformLetter(String platform) {
    if (platform.isEmpty) return '?';
    return platform[0].toUpperCase();
  }
}

/// The card's "⋮" menu: the room, the saved file's folder (when the task
/// has one), and the confirmed delete. The reference's "auto-record when live" switch
/// has no field behind it yet and is left out rather than faked.
final class _TaskMenu extends StatelessWidget {
  const _TaskMenu({
    required this.task,
    required this.hasFile,
    required this.onOpen,
    required this.onDelete,
    this.onStop,
  });

  final RecordingTask task;

  /// Whether the task has a saved file (so a folder to open).
  final bool hasFile;

  final VoidCallback onOpen;
  final VoidCallback onDelete;

  /// Stops a running capture, null when the task is not being recorded.
  final VoidCallback? onStop;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final theme = DsTheme.of(context);
    final colors = DsTheme.colorsOf(context);
    return DsMenuAnchor(
      semanticLabel: t.recorder.menuMore,
      align: DsAlign.end,
      builder: (context, controller, child) => DsPressable(
        semanticLabel: t.recorder.menuMore,
        onPressed: controller.toggle,
        builder: (context, states, _) {
          final hovered = states.contains(WidgetState.hovered);
          return Padding(
            padding: const EdgeInsets.all(DsSpace.s4),
            child: DsIcon(
              DsIcons.ellipsisVertical,
              size: theme.sizes.iconSm,
              color: hovered ? colors.text : colors.textSubtle,
            ),
          );
        },
      ),
      items: [
        DsMenuItem(leading: const DsIcon(DsIcons.externalLink), label: Text(t.recorder.openRoom), onPressed: onOpen),
        if (hasFile)
          DsMenuItem(
            leading: const DsIcon(DsIcons.folderOpen),
            label: Text(t.recorder.openFolder),
            onPressed: () => unawaited(_openFolder(context)),
          ),
        if (onStop case final stop?)
          DsMenuItem(
            leading: const DsIcon(DsIcons.square),
            label: Text(t.recorder.stop),
            destructive: true,
            onPressed: stop,
          ),
        const DsMenuDivider(),
        DsMenuItem(
          leading: const DsIcon(DsIcons.trash2),
          label: Text(t.recorder.delete),
          destructive: true,
          onPressed: () => unawaited(_confirmDelete(context)),
        ),
      ],
    );
  }

  /// Opens the folder the last session's file landed in, through the
  /// system's own file manager.
  Future<void> _openFolder(BuildContext context) async {
    final file = (task.filePath ?? '').trim();
    if (file.isEmpty) return;
    final opened = await OpenFile.open(p.dirname(file));
    if (opened.type == ResultType.done || !context.mounted) return;
    showDsToast(context: context, title: context.t.recorder.openFolderFailed, status: DsStatus.danger);
  }

  /// Asks before dropping the task: the entry goes, the files stay.
  Future<void> _confirmDelete(BuildContext context) async {
    final t = context.t;
    final name = task.roomTitle.trim().isNotEmpty ? task.roomTitle.trim() : task.roomId;
    final confirmed = await showDsConfirm(
      context: context,
      title: t.recorder.deleteTitle(name: name),
      description: t.recorder.deleteBody,
      confirmLabel: t.recorder.delete,
      cancelLabel: t.common.cancel,
      destructive: true,
      icon: const DsIcon(DsIcons.trash2),
    );
    if (confirmed) onDelete();
  }
}

/// The card's cover stand-in: the platform's letter on the accent tint, so
/// a room whose snapshot has no picture keeps the head's shape.
final class _CoverFallback extends StatelessWidget {
  const _CoverFallback({required this.letter});

  final String letter;

  @override
  Widget build(BuildContext context) {
    final colors = DsTheme.colorsOf(context);
    final theme = DsTheme.of(context);
    return ColoredBox(
      color: colors.accentTint,
      child: Center(
        child: Text(
          letter,
          style: theme.typography.body.copyWith(fontWeight: FontWeight.w700, color: colors.accentText),
        ),
      ),
    );
  }
}

/// A room's leading audience figure, in the page's number words.
String _audienceOf(LiveRoom? room) {
  final audience = room?.audience;
  if (audience == null) return '';
  final figure = switch (audience.primaryMetric) {
    LiveAudienceMetricType.onlineViewers => audience.onlineViewers ?? audience.popularity,
    LiveAudienceMetricType.totalViewers => audience.totalViewers ?? audience.popularity,
    _ => audience.popularity,
  };
  return AudienceFormat.format(figure);
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

/// A recording cap in the unit the settings use: whole megabytes below a
/// gigabyte, one decimal above.
String _formatMb(int megabytes) => megabytes >= 1024
    ? '${(megabytes / 1024).toStringAsFixed(1)} GB'
    : '$megabytes MB';

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

/// One labelled slider of the recorder settings: the row names the knob
/// and its current value, the slider below it sets it.
final class _RecordSlider extends StatelessWidget {
  const _RecordSlider({
    required this.icon,
    required this.title,
    required this.description,
    required this.detail,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
    required this.semanticLabel,
    this.divisions,
  });

  final DsIconData icon;
  final String title;
  final String description;
  final String detail;
  final double value;
  final double min;
  final double max;
  final int? divisions;
  final ValueChanged<double> onChanged;
  final String semanticLabel;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      DsListRow(
        leading: DsIcon(icon),
        title: Text(title),
        description: Text(description),
        detail: Text(detail),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(DsSpace.s20, 0, DsSpace.s20, DsSpace.s8),
        child: DsSlider(
          value: value,
          min: min,
          max: max,
          divisions: divisions,
          onChanged: onChanged,
          semanticLabel: semanticLabel,
        ),
      ),
    ],
  );
}

/// One switch of the recorder settings.
final class _RecordSwitch extends StatelessWidget {
  const _RecordSwitch({
    required this.icon,
    required this.title,
    required this.description,
    required this.value,
    required this.onChanged,
  });

  final DsIconData icon;
  final String title;
  final String description;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) => DsListRow(
    leading: DsIcon(icon),
    title: Text(title),
    description: Text(description),
    trailing: DsSwitch(value: value, onChanged: onChanged),
  );
}

/// A choice with its explanation above a full-width control (the container
/// picker): the segmented control needs the row's width, not the trailing
/// column.
final class _RecordChoice extends StatelessWidget {
  const _RecordChoice({
    required this.icon,
    required this.title,
    required this.description,
    required this.child,
  });

  final DsIconData icon;
  final String title;
  final String description;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = DsTheme.colorsOf(context);
    final theme = DsTheme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(DsSpace.s16, DsSpace.s8, DsSpace.s16, DsSpace.s12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: DsSpace.s8,
        children: [
          Row(
            spacing: DsSpace.s8,
            children: [
              DsIcon(icon, size: theme.sizes.iconSm, color: colors.textMuted),
              Expanded(
                child: Text(title, style: theme.typography.body.copyWith(color: colors.text)),
              ),
            ],
          ),
          Text(description, style: theme.typography.caption.copyWith(color: colors.textMuted)),
          child,
        ],
      ),
    );
  }
}

/// The recorder's settings pane: where files land and how they name
/// themselves, how a capture is segmented and recovered, and the background
/// and concurrency limits — every row reaches the FFmpeg session through
/// `RecordingSettings`.
final class RecordingSettingsPane extends ConsumerWidget {
  /// The recorder settings pane.
  const RecordingSettingsPane({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    final settings = ref.watch(recordingSettingsProvider);
    final controller = ref.read(recordingSettingsProvider.notifier);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: DsSpace.s16,
      children: [
        DsListSection(
          header: Text(t.recorder.settingsFiles),
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
              detail: Text(_formatMb(settings.maxSizeMb)),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(DsSpace.s20, 0, DsSpace.s20, DsSpace.s8),
              child: DsSlider(
                value: settings.maxSizeMb.toDouble(),
                min: 100,
                max: 20480,
                divisions: 203,
                onChanged: (value) => controller.maxSizeMb = value.round(),
                semanticLabel: t.recorder.maxSizeTitle,
              ),
            ),
            _RecordChoice(
              icon: DsIcons.fileVideo,
              title: t.recorder.containerTitle,
              description: t.recorder.containerDescription,
              child: DsSegmentedControl<RecordingFileContainer>(
                value: settings.container,
                onChanged: (value) => controller.container = value,
                segments: [
                  DsSegment(value: RecordingFileContainer.mpegTs, label: Text(t.recorder.containerTs)),
                  DsSegment(value: RecordingFileContainer.mp4, label: Text(t.recorder.containerMp4)),
                ],
              ),
            ),
          ],
        ),
        DsListSection(
          header: Text(t.recorder.settingsRecovery),
          children: [
            _RecordSlider(
              icon: DsIcons.timer,
              title: t.recorder.segmentTitle,
              description: t.recorder.segmentDescription,
              detail: t.recorder.segmentMinutes(count: settings.segmentSeconds ~/ 60),
              value: (settings.segmentSeconds / 60).clamp(1, 60),
              min: 1,
              max: 60,
              divisions: 59,
              onChanged: (value) => controller.segmentSeconds = value.round() * 60,
              semanticLabel: t.recorder.segmentTitle,
            ),
            _RecordSlider(
              icon: DsIcons.clock,
              title: t.recorder.readTimeoutTitle,
              description: t.recorder.readTimeoutDescription,
              detail: t.recorder.seconds(count: settings.readTimeoutSeconds),
              value: settings.readTimeoutSeconds.toDouble(),
              min: 5,
              max: 120,
              divisions: 23,
              onChanged: (value) => controller.readTimeoutSeconds = value.round(),
              semanticLabel: t.recorder.readTimeoutTitle,
            ),
            _RecordSlider(
              icon: DsIcons.refreshCw,
              title: t.recorder.restartTitle,
              description: t.recorder.restartDescription,
              detail: t.recorder.restartCount(count: settings.restartLimit),
              value: settings.restartLimit.toDouble(),
              min: 0,
              max: 20,
              divisions: 20,
              onChanged: (value) => controller.restartLimit = value.round(),
              semanticLabel: t.recorder.restartTitle,
            ),
            _RecordSlider(
              icon: DsIcons.timerReset,
              title: t.recorder.backoffTitle,
              description: t.recorder.backoffDescription,
              detail: t.recorder.seconds(count: settings.restartBackoffSeconds),
              value: settings.restartBackoffSeconds.toDouble(),
              min: 1,
              max: 60,
              divisions: 59,
              onChanged: (value) => controller.restartBackoffSeconds = value.round(),
              semanticLabel: t.recorder.backoffTitle,
            ),
            _RecordSlider(
              icon: DsIcons.activity,
              title: t.recorder.stallTitle,
              description: t.recorder.stallDescription,
              detail: t.recorder.seconds(count: settings.stallTimeoutSeconds),
              value: settings.stallTimeoutSeconds.toDouble(),
              min: 10,
              max: 300,
              divisions: 29,
              onChanged: (value) => controller.stallTimeoutSeconds = value.round(),
              semanticLabel: t.recorder.stallTitle,
            ),
            _RecordSwitch(
              icon: DsIcons.layers,
              title: t.recorder.preferBestTitle,
              description: t.recorder.preferBestDescription,
              value: settings.preferBestStream,
              onChanged: (value) => controller.preferBestStream = value,
            ),
            _RecordSwitch(
              icon: DsIcons.circleCheck,
              title: t.recorder.verifyTitle,
              description: t.recorder.verifyDescription,
              value: settings.verifyOutput,
              onChanged: (value) => controller.verifyOutput = value,
            ),
          ],
        ),
        DsListSection(
          header: Text(t.recorder.settingsRuntime),
          children: [
            _RecordSwitch(
              icon: DsIcons.moon,
              title: t.recorder.keepAliveTitle,
              description: t.recorder.keepAliveDescription,
              value: settings.keepAlive,
              onChanged: (value) => controller.keepAlive = value,
            ),
            DsListRow(
              leading: const DsIcon(DsIcons.listOrdered),
              title: Text(t.recorder.queueTitle),
              description: Text(t.recorder.queueDescription),
              trailing: DsSelect<int>(
                value: _queueChoice(settings.queueSize),
                onChanged: (value) {
                  if (value != null) controller.queueSize = value;
                },
                options: [
                  for (final size in const [1024, 2048, 4096, 8192])
                    DsSelectOption(value: size, label: '$size'),
                ],
                semanticLabel: t.recorder.queueTitle,
              ),
            ),
            _RecordSlider(
              icon: DsIcons.copy,
              title: t.recorder.maxTasksTitle,
              description: t.recorder.maxTasksDescription,
              detail: t.recorder.maxTasksCount(count: settings.maxTasks),
              value: settings.maxTasks.toDouble(),
              min: 1,
              max: 10,
              divisions: 9,
              onChanged: (value) => controller.maxTasks = value.round(),
              semanticLabel: t.recorder.maxTasksTitle,
            ),
            _RecordSlider(
              icon: DsIcons.hardDrive,
              title: t.recorder.watermarkTitle,
              description: t.recorder.watermarkDescription,
              detail: _formatMb(settings.diskWatermarkMb),
              value: settings.diskWatermarkMb.toDouble(),
              min: 50,
              max: 2048,
              divisions: 39,
              onChanged: (value) => controller.diskWatermarkMb = (value / 50).round() * 50,
              semanticLabel: t.recorder.watermarkTitle,
            ),
          ],
        ),
      ],
    );
  }

  /// The stored queue size as one of the four choices; a value from an
  /// older build shows as the nearest choice rather than an empty field.
  static int _queueChoice(int size) {
    const choices = [1024, 2048, 4096, 8192];
    var best = choices.first;
    for (final choice in choices) {
      if ((choice - size).abs() < (best - size).abs()) best = choice;
    }
    return best;
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
