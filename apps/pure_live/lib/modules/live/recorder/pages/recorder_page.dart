import 'dart:async' show TimeoutException, unawaited;
import 'dart:io' show File;

import 'package:desen_ui/desen_ui.dart';
import 'package:file_picker/file_picker.dart' show FilePicker, FileType;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart' show GoRouterHelper;
import 'package:live_sites/live_sites.dart' show LiveAudienceMetricType, LiveDanmakuProvider, LiveRoom;
import 'package:path/path.dart' as p;
import 'package:pure_live/app/app.dart';
import 'package:pure_live/features/media_preview/media_preview_item.dart';
import 'package:pure_live/features/media_preview/media_preview_page.dart';
import 'package:pure_live/features/settings/pages/wallpaper_download_manager.dart' show openDownloadedPath;
import 'package:pure_live/features/settings/settings.dart';
import 'package:pure_live/l10n/translations.dart';
import 'package:pure_live/modules/live/favorites/favorites.dart';
import 'package:pure_live/modules/live/history/history.dart';
import 'package:pure_live/modules/live/recorder/data/recorder_search_handoff.dart';
import 'package:pure_live/modules/live/recorder/data/recording_library.dart';
import 'package:pure_live/modules/live/recorder/data/recording_preview.dart';
import 'package:pure_live/modules/live/recorder/data/recording_repository.dart';
import 'package:pure_live/modules/live/recorder/data/recording_settings.dart';
import 'package:pure_live/modules/live/recorder/data/recording_task.dart';
import 'package:pure_live/modules/live/recorder/engine/recorder_engine.dart' show recorderEngineProvider;
import 'package:pure_live/modules/live/recorder/engine/stream_resolver.dart'
    show NoRecordableStream, resolveRecordableStream;
import 'package:pure_live/modules/live/recorder/pages/recorder_library_pane.dart';
import 'package:pure_live/modules/live/search/room_search_picker.dart' show showRoomSearchPicker;
import 'package:pure_live/shared/shared.dart';

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
/// The task filter. It stops at 失败 on purpose: a saved recording is no
/// longer a row in a task list but a file in the library below, where every
/// take of a room shows rather than only the last one the store kept a row for.
enum _RecorderFilter {
  all,
  recording,
  waiting,
  failed;

  /// Whether [task] belongs under this filter.
  bool matches(RecordingTask task) => switch (this) {
    all => true,
    recording => task.state == RecordingTaskState.recording || task.postProcessing,
    waiting => task.state == RecordingTaskState.waiting,
    failed => task.state == RecordingTaskState.failed,
  };

  /// The section's icon.
  DsIconData get icon => switch (this) {
    all || recording => DsIcons.disc3,
    waiting => DsIcons.clock,
    failed => DsIcons.circleAlert,
  };
}

final class _RecorderPageState extends ConsumerState<RecorderPage> {
  _RecorderFilter _filter = _RecorderFilter.all;

  @override
  void initState() {
    super.initState();
    // The toolbar's word opens the room search picker over this page: a
    // room found there becomes a task. The listener catches a word handed
    // while the page is showing; the post-frame take catches one handed as
    // the page arrives.
    ref.listenManual(recorderSearchHandoffProvider, (_, _) => _takeHandoff());
    WidgetsBinding.instance.addPostFrameCallback((_) => _takeHandoff());
  }

  void _takeHandoff() {
    final word = ref.read(recorderSearchHandoffProvider.notifier).take();
    if (word == null || word.isEmpty || !mounted) return;
    unawaited(showRoomSearchPicker(context, query: word, title: context.t.recorder.searchHint, onPick: _addFromSearch));
  }

  /// Adds the picked room as a task: a live room starts recording now, an
  /// offline one joins the waiting list and starts when the live check
  /// sees it on air — each after the viewer confirms what will happen.
  Future<void> _addFromSearch(LiveRoom room) async {
    final t = context.t;
    final live = room.broadcast.isLiveNow;
    final title = room.content.title.trim().isEmpty ? room.anchor?.name ?? room.ref.roomId : room.content.title;
    final confirmed = await showDsConfirm(
      context: context,
      title: t.recorder.addTitle,
      description: live ? t.recorder.addBodyLive(title: title) : t.recorder.addBodyOffline(title: title),
      confirmLabel: live ? t.recorder.addStartNow : t.recorder.addArm,
      cancelLabel: t.common.cancel,
      icon: const DsIcon(DsIcons.disc3),
    );
    if (!confirmed || !mounted) return;
    final id = '${room.ref.platform}:${room.ref.roomId}';
    if (ref.read(recorderEngineProvider).isRecording(id)) {
      showDsToast(context: context, title: t.recorder.addAlreadyRecording, status: DsStatus.info);
      return;
    }
    final settings = ref.read(recordingSettingsProvider);
    final existing = ref.read(recordingTasksProvider).tasks.where((task) => task.id == id).firstOrNull;
    final now = DateTime.now().toUtc();
    if (live) {
      final task =
          existing?.copyWith(
            roomTitle: room.content.title,
            quality: settings.defaultQuality,
            state: RecordingTaskState.stopped,
            startedAt: now,
          ) ??
          RecordingTask(
            id: id,
            platform: room.ref.platform,
            roomId: room.ref.roomId,
            roomTitle: room.content.title,
            quality: settings.defaultQuality,
            state: RecordingTaskState.stopped,
            startedAt: now,
          );
      await _startNow(task);
      return;
    }
    // Nothing begins a take on its own with the live check off.
    if (!settings.schedule.pollingEnabled) {
      ref.read(recordingSettingsProvider.notifier).pollingEnabled = true;
    }
    final waiting =
        existing?.copyWith(
          roomTitle: room.content.title,
          quality: settings.defaultQuality,
          state: RecordingTaskState.waiting,
          startedAt: now,
        ) ??
        RecordingTask(
          id: id,
          platform: room.ref.platform,
          roomId: room.ref.roomId,
          roomTitle: room.content.title,
          quality: settings.defaultQuality,
          state: RecordingTaskState.waiting,
          startedAt: now,
        );
    await ref.read(recordingTasksProvider.notifier).add(waiting);
    if (!mounted) return;
    showDsToast(
      context: context,
      title: t.recorder.addArmed(seconds: ref.read(recordingSettingsProvider).schedule.liveCheckSeconds),
      status: DsStatus.success,
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final theme = DsTheme.of(context);
    final colors = DsTheme.colorsOf(context);
    final store = ref.watch(recordingTasksProvider);
    final polling = ref.watch(recordingSettingsProvider).schedule.pollingEnabled;
    // The tasks store their room's identity only; the room itself (cover,
    // streamer, audience) is the snapshot the follows and history stores
    // keep under the same key (`platform:roomId`), so the card shows real
    // room facts without the recording model growing copies of them.
    final follows = ref.watch(followsProvider);
    final history = ref.watch(historyProvider);
    String keyOf(LiveRoom room) => '${room.ref.platform}:${room.ref.roomId}';
    final rooms = <String, LiveRoom>{
      for (final (room, _) in history.records) keyOf(room): room,
      for (final room in follows.rooms) keyOf(room): room,
    };
    // Live's own rows. The IPTV module records through the same engine and the
    // same store — one tree, one task list — and it shows its recordings on its
    // own page, so nothing here may pick a channel up: 停止全部 would stop
    // channels, a chip's count would include rows no card shows, and 进入直播间
    // has no channel behind an IPTV take.
    final liveTasks = [
      for (final task in store.tasks)
        if (task.platform != kIptvRecordingPlatform) task,
    ];
    // A chip's count is a count of the rows that chip can show — the tasks the
    // page still owns. Counting every stored row instead would print a number
    // the list under it never reaches, because a saved take lives in the library.
    final listed = liveTasks.where(_isTaskRow).toList();
    final counts = <_RecorderFilter, int>{
      for (final filter in _RecorderFilter.values) filter: listed.where(filter.matches).length,
    };
    // The two groups the whole-list actions work on: what the engine is
    // writing now, and the rows a session already settled — a take still being
    // joined and a room still being watched belong to neither.
    final recording = [
      for (final task in liveTasks)
        if (task.state == RecordingTaskState.recording) task,
    ];
    final settled = [
      for (final task in liveTasks)
        if (!task.postProcessing &&
            task.state != RecordingTaskState.recording &&
            task.state != RecordingTaskState.waiting)
          task,
    ];
    // What the page still owns as a task: a capture running, a room waiting to
    // go live, a session that failed, a join still going — and a saved row whose
    // file is gone, which the library cannot show and is the only way back to
    // 重新合并 or to dropping the record. The toolbar's word narrows these
    // rows in place, the search field above.
    final inset = LiveWindow.pageInset(MediaQuery.sizeOf(context).width);
    final narrow = LiveWindow.stacksToolbar(MediaQuery.sizeOf(context).width);
    final wide = MediaQuery.sizeOf(context).width >= 720;
    final attention = [
      for (final task in listed)
        if (_filter.matches(task)) task,
    ];
    final statusFilter = DsTabs<String>(
      value: _filter.name,
      semanticLabel: t.recorder.filterLabel,
      onChanged: (value) => setState(() => _filter = _RecorderFilter.values.byName(value)),
      tabs: [
        DsTab(value: 'all', label: Text(t.recorder.filterAll), count: counts[_RecorderFilter.all] ?? 0),
        DsTab(
          value: 'recording',
          label: Text(t.recorder.filterRecording),
          count: counts[_RecorderFilter.recording] ?? 0,
        ),
        DsTab(value: 'waiting', label: Text(t.recorder.filterWaiting), count: counts[_RecorderFilter.waiting] ?? 0),
        DsTab(value: 'failed', label: Text(t.recorder.filterFailed), count: counts[_RecorderFilter.failed] ?? 0),
      ],
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(inset, DsSpace.s16, inset, DsSpace.s12),
          child: Row(
            spacing: DsSpace.s12,
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  color: colors.accentTint,
                  borderRadius: BorderRadius.circular(theme.radii.card),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(DsSpace.s12),
                  child: DsIcon(DsIcons.video, size: 28, color: colors.accentText),
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: 2,
                  children: [
                    Text(t.navigation.record, style: theme.typography.title.copyWith(color: colors.text)),
                    Text(
                      t.recorder.centerSubtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.typography.caption.copyWith(color: colors.textMuted),
                    ),
                  ],
                ),
              ),
              DsButton(
                variant: DsButtonVariant.secondary,
                size: DsSize.sm,
                leading: const DsIcon(DsIcons.settings, size: 16),
                onPressed: _openSettings,
                child: Text(t.recorder.settingsOpen),
              ),
            ],
          ),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(inset, 0, inset, DsSpace.s12),
          child: Align(
            alignment: AlignmentDirectional.centerStart,
            child: DsSegmentedControl<RecorderCenterTab>(
              value: ref.watch(recorderCenterTabProvider),
              onChanged: (value) => ref.read(recorderCenterTabProvider.notifier).set(value),
              segments: [
                DsSegment(value: RecorderCenterTab.tasks, label: Text(t.recorder.tabTasks)),
                DsSegment(value: RecorderCenterTab.files, label: Text(t.recorder.tabFiles)),
              ],
            ),
          ),
        ),
        if (ref.watch(recorderCenterTabProvider) == RecorderCenterTab.tasks)
          Expanded(
            child: _tasksBody(
              inset: inset,
              narrow: narrow,
              wide: wide,
              statusFilter: statusFilter,
              attention: attention,
              onStopAll: recording.isEmpty ? null : () => unawaited(_stopAll(recording)),
              onClearFinished: settled.isEmpty ? null : () => unawaited(_clearFinished(settled)),
              polling: polling,
              pollingBannerTasks: store.tasks.any((task) => task.needsLiveCheck),
              rooms: rooms,
            ),
          )
        else ...[
          Expanded(
            child: RecorderLibraryPane(
              showHeading: false,
              // Channels are the IPTV module's own list.
              excludedPlatforms: const {kIptvRecordingPlatform},
              onPlay: (around, take) => unawaited(_playLibraryTake(around, take)),
              onOpenRoom: (take) => unawaited(_openRoomOf(take)),
              platformName: _platformName,
            ),
          ),
        ],
      ],
    );
  }

  /// The tasks page's own body: the four figures, the toolbar, the banner
  /// and the task rows — the operation centre, not a file list.
  Widget _tasksBody({
    required double inset,
    required bool narrow,
    required bool wide,
    required Widget statusFilter,
    required List<RecordingTask> attention,
    required VoidCallback? onStopAll,
    required VoidCallback? onClearFinished,

    required bool polling,
    required bool pollingBannerTasks,
    required Map<String, LiveRoom> rooms,
  }) {
    final t = context.t;
    // The tasks page reads as a worklist, not a band across the window: one
    // centred measure holds the toolbar and the rows together.
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 860),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(inset, 0, inset, DsSpace.s8),
              // The states with their counts lead, the whole-list actions end.
              // Adding a task is the shell's own search above — it opens the
              // room picker — so the toolbar carries no second field.
              child: Row(
                spacing: DsSpace.s8,
                children: [
                  Expanded(child: statusFilter),
                  _BatchMenu(onStopAll: onStopAll, onClearFinished: onClearFinished),
                ],
              ),
            ),
            // With the live check off nothing begins a take on its own, so the
            // banner covers the scheduled rows too: a stopped task whose window
            // is meant to re-arm it is just as stranded as a room waiting to go
            // live.
            if (!polling && pollingBannerTasks)
              Padding(
                padding: EdgeInsets.fromLTRB(inset, 0, inset, DsSpace.s8),
                child: DsAlert(
                  title: Text(t.recorder.pollingOff),
                  status: DsStatus.warning,
                  action: DsButton(
                    variant: DsButtonVariant.secondary,
                    size: DsSize.sm,
                    onPressed: () {
                      ref.read(recordingSettingsProvider.notifier).pollingEnabled = true;
                      showDsToast(
                        context: context,
                        title: t.recorder.pollingEnabledToast(
                          seconds: ref.read(recordingSettingsProvider).schedule.liveCheckSeconds,
                        ),
                        status: DsStatus.success,
                      );
                    },
                    child: Text(t.recorder.pollingEnable),
                  ),
                ),
              ),
            // The rows this page still owns, as the file manager's table on a
            // wide window and the cards on a narrow one. This is the whole
            // tasks page now — the library below became its own page.
            Expanded(
              child: attention.isEmpty
                  ? DsEmptyState(icon: const DsIcon(DsIcons.video), title: Text(t.recorder.emptyTitle))
                  : Padding(
                      padding: EdgeInsets.fromLTRB(inset, 0, inset, DsSpace.s8),
                      child: wide
                          ? DsTable<RecordingTask>(
                              semanticLabel: t.recorder.runningTitle,
                              style: const DsTableStyle(rowHeight: 56),
                              columns: _taskColumns(context, rooms),
                              rows: attention,
                              rowKey: (task) => task.id,
                              emptyView: const SizedBox.shrink(),
                            )
                          : SingleChildScrollView(
                              padding: const EdgeInsets.only(bottom: DsSpace.s8),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                spacing: DsSpace.s8,
                                children: [for (final task in attention) ..._taskCards(context, task, rooms)],
                              ),
                            ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  /// The task table's columns: the take (its cover, its name and its
  /// state), what it has written, when it began, and the phase's own
  /// action beside the menu — the file manager's columns.
  List<DsTableColumn<RecordingTask>> _taskColumns(BuildContext context, Map<String, LiveRoom> rooms) {
    final t = context.t;
    return [
      DsTableColumn<RecordingTask>(
        id: 'task',
        label: t.recorder.columnTask,
        value: (task) => task.roomTitle.trim().isNotEmpty ? task.roomTitle.trim() : task.roomId,
        cell: (context, task) => _taskNameCell(context, task, rooms),
        width: const DsTableColumnWidth.flex(3, 200),
      ),
      DsTableColumn<RecordingTask>(
        id: 'size',
        label: t.recorder.columnSize,
        value: (task) => task.bytes,
        text: (task) => task.bytes > 0 ? formatRecordingBytes(task.bytes) : '—',
        numeric: true,
        width: const DsTableColumnWidth.intrinsic(min: 88),
      ),
      DsTableColumn<RecordingTask>(
        id: 'time',
        label: t.recorder.columnStarted,
        value: (task) => task.startedAt.millisecondsSinceEpoch,
        text: (task) => formatRecordingMoment(task.startedAt),
        width: const DsTableColumnWidth.intrinsic(min: 92),
      ),
      DsTableColumn<RecordingTask>(
        id: 'actions',
        label: t.recorder.columnActions,
        alignment: DsTableCellAlignment.end,
        cell: (context, task) => _taskActionsCell(context, task, rooms),
        width: const DsTableColumnWidth.fixed(150),
      ),
    ];
  }

  /// The take's row head: its cover (the platform's letter when the room
  /// snapshot has none), the streamer over the title, the facts line, and
  /// the state's badge beside the name.
  Widget _taskNameCell(BuildContext context, RecordingTask task, Map<String, LiveRoom> rooms) {
    final t = context.t;
    final theme = DsTheme.of(context);
    final colors = DsTheme.colorsOf(context);
    final room = rooms[task.id] ?? rooms['${task.platform.toLowerCase()}:${task.roomId.trim()}'];
    final streamer = room?.anchor?.name.trim() ?? '';
    final storedTitle = task.roomTitle.trim();
    final roomTitle = room?.content.title.trim() ?? '';
    final title = storedTitle.isNotEmpty ? storedTitle : (roomTitle.isNotEmpty ? roomTitle : task.roomId);
    final cover = room?.content.coverUrl.trim() ?? '';
    final fileDeleted = task.state == RecordingTaskState.stopped && task.warning == 'file-deleted';
    return Row(
      spacing: DsSpace.s8,
      children: [
        DsImage(
          image: cover.isEmpty ? null : cachedImage(cover),
          width: 48,
          height: 32,
          fallback: _CoverFallback(letter: _TaskCard.platformLetter(task.platform)),
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 2,
            children: [
              Row(
                spacing: DsSpace.s8,
                children: [
                  Expanded(
                    child: Text(
                      streamer.isEmpty ? title : streamer,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.typography.body.copyWith(fontWeight: FontWeight.w600, color: colors.text),
                    ),
                  ),
                  DsBadge(
                    label: Text(
                      task.postProcessing
                          ? t.recorder.stateProcessing
                          : fileDeleted
                          ? t.recorder.stateFileDeleted
                          : _TaskCard.stateLabel(t, task.state),
                    ),
                    status: task.postProcessing
                        ? DsStatus.info
                        : fileDeleted
                        ? DsStatus.neutral
                        : _TaskCard.stateStatus(task.state),
                  ),
                ],
              ),
              Text(
                [
                  _platformName(task.platform),
                  if (task.quality.isNotEmpty) task.quality else t.recorder.qualityBest,
                  if (task.scheduleEnabled) _scheduleSummary(t, task),
                  t.recorder.startedAt(time: formatRecordingMoment(task.startedAt)),
                ].join(' · '),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.typography.caption.copyWith(color: colors.textMuted),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// The row's one action: the verb this phase asks for — stop a capture,
  /// cancel a join, start a waiting or failed one now — beside the row's
  /// menu. A capture another window holds answers nothing here, so its row
  /// carries the menu alone.
  Widget _taskActionsCell(BuildContext context, RecordingTask task, Map<String, LiveRoom> rooms) {
    final t = context.t;
    final engine = ref.read(recorderEngineProvider);
    final callbacks = _taskCallbacks(task, rooms);
    final runningHere = engine.isRecording(task.id);
    Widget? primary;
    if (task.postProcessing) {
      primary = DsButton(
        variant: DsButtonVariant.secondary,
        size: DsSize.sm,
        leading: const DsIcon(DsIcons.x, size: 14),
        onPressed: callbacks.onCancelProcessing,
        child: Text(t.recorder.cancelProcessing),
      );
    } else if (runningHere) {
      primary = DsButton(
        variant: DsButtonVariant.secondary,
        size: DsSize.sm,
        leading: const DsIcon(DsIcons.squareStop, size: 14),
        onPressed: callbacks.onStop,
        child: Text(t.recorder.stop),
      );
    } else if (callbacks.onStartNow != null) {
      primary = DsButton(
        variant: DsButtonVariant.primary,
        size: DsSize.sm,
        leading: const DsIcon(DsIcons.play, size: 14),
        onPressed: callbacks.onStartNow,
        child: Text(t.recorder.startNow),
      );
    }
    return Row(
      spacing: DsSpace.s4,
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        ?primary,
        _TaskMenu(
          task: task,
          hasFile: (task.filePath ?? '').trim().isNotEmpty,
          onOpen: callbacks.onOpen,
          onStop: callbacks.onStop,
          onCancelWaiting: callbacks.onCancelWaiting,
          onDelete: callbacks.onDelete,
          onSchedule: callbacks.onSchedule,
          onCancelProcessing: callbacks.onCancelProcessing,
          onStartNow: callbacks.onStartNow,
          onRetryJoin: callbacks.onRetryJoin,
          onPreview: callbacks.onPreview,
          onPlayExternal: callbacks.onPlayExternal,
        ),
      ],
    );
  }

  /// The callbacks one task's row needs, shared by the card list and the
  /// table — the store's answers decide which are present.
  _TaskCallbacks _taskCallbacks(RecordingTask task, Map<String, LiveRoom> rooms) {
    final engine = ref.read(recorderEngineProvider);
    return (
      onOpen: playableFileAt(task.filePath) == null
          ? () => unawaited(openRoom(context, platform: task.platform, roomId: task.roomId))
          : () => unawaited(_openPreview(task)),
      onStop: engine.isRecording(task.id) ? () => unawaited(_stop(task.id)) : null,
      onCancelWaiting: task.state == RecordingTaskState.waiting
          ? () => unawaited(ref.read(recordingTasksProvider.notifier).remove(task.id))
          : null,
      onDelete: () => unawaited(ref.read(recordingTasksProvider.notifier).remove(task.id)),
      onSchedule: () => unawaited(_editSchedule(task)),
      onStartNow: !task.postProcessing && task.state != RecordingTaskState.recording
          ? () => unawaited(_startNow(task))
          : null,
      onCancelProcessing: task.postProcessing ? () => unawaited(_cancelProcessing(task.id)) : null,
      onRetryJoin:
          !task.postProcessing && task.state != RecordingTaskState.recording && (task.filePath ?? '').isNotEmpty
          ? () => unawaited(_retryJoin(task))
          : null,
      onPreview: _canPreview(task) ? () => unawaited(_openPreview(task)) : null,
      onPlayExternal: _canPreview(task) ? () => unawaited(_playExternal(task)) : null,
    );
  }

  /// The rows the task strip still lists. A saved take with a file on disk
  /// belongs to the library, which shows every take rather than the store's one
  /// row per room; a saved row whose file is gone stays here because the library
  /// has nothing to show and the row is the way to rejoin or to drop it.
  /// No disk probe here: the page rebuilds on every progress tick of a running
  /// capture, so this reads only what the row already says — its state, whether
  /// a join is still going, and the warning a deleted file left behind.
  bool _isTaskRow(RecordingTask task) =>
      task.state != RecordingTaskState.stopped ||
      task.postProcessing ||
      task.warning == kRecordingFileDeletedWarning ||
      (task.filePath ?? '').trim().isEmpty;

  /// One task as its card, with the actions that depend on the store's answer.
  List<Widget> _taskCards(BuildContext context, RecordingTask task, Map<String, LiveRoom> rooms) {
    final engine = ref.read(recorderEngineProvider);
    return [
      _TaskCard(
        task: task,
        room: rooms[task.id] ?? rooms['${task.platform.toLowerCase()}:${task.roomId.trim()}'],
        platformName: _platformName(task.platform),
        // The card's press opens the recording, the same door the library's row
        // uses; the room is a menu step away, as it is there.
        onOpen: playableFileAt(task.filePath) == null
            ? () => unawaited(openRoom(context, platform: task.platform, roomId: task.roomId))
            : () => unawaited(_openPreview(task)),
        onStop: engine.isRecording(task.id) ? () => unawaited(_stop(task.id)) : null,
        onCancelWaiting: task.state == RecordingTaskState.waiting
            ? () => unawaited(ref.read(recordingTasksProvider.notifier).remove(task.id))
            : null,
        onDelete: () => unawaited(ref.read(recordingTasksProvider.notifier).remove(task.id)),
        onSchedule: () => unawaited(_editSchedule(task)),
        onStartNow: !task.postProcessing && task.state != RecordingTaskState.recording
            ? () => unawaited(_startNow(task))
            : null,
        onCancelProcessing: task.postProcessing ? () => unawaited(_cancelProcessing(task.id)) : null,
        // A take the app never finished still holds its segments: offer the
        // finish again whenever the task names a file and nothing runs.
        onRetryJoin:
            !task.postProcessing && task.state != RecordingTaskState.recording && (task.filePath ?? '').isNotEmpty
            ? () => unawaited(_retryJoin(task))
            : null,
        onPreview: _canPreview(task) ? () => unawaited(_openPreview(task)) : null,
        onPlayExternal: _canPreview(task) ? () => unawaited(_playExternal(task)) : null,
      ),
    ];
  }

  /// Plays a library take through the entry every recording centre shares.
  Future<void> _playLibraryTake(List<RecordingTake> around, RecordingTake take) =>
      playRecordingTake(context, ref, around: around, take: take, platformName: _platformName);

  /// The room a take was made in, from the library's row menu. A hand-dropped
  /// file the store never made a row for has no room to open.
  Future<void> _openRoomOf(RecordingTake take) async {
    final row = take.task;
    if (row == null) return;
    await openRoom(context, platform: row.platform, roomId: row.roomId);
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

  /// The recorder's settings live on the settings surface: the header action
  /// opens that page with the recording category chosen, the same page the
  /// sidebar reaches, instead of a dialog over this one.
  void _openSettings() {
    openSettingsSection(ref, SettingsSection.recording);
    unawaited(context.push(SettingsSectionRoute(section: SettingsSection.recording.name).location));
  }

  /// Cancels the take's running join/transcode; the files it already has stay.
  Future<void> _cancelProcessing(String taskId) async {
    final cancelled = await ref.read(recorderEngineProvider).cancelFinalize(taskId);
    if (!cancelled || !mounted) return;
    showDsToast(context: context, title: context.t.recorder.cancelProcessingRequested, status: DsStatus.info);
  }

  /// Runs the post-recording steps again on a take the app never finished.
  ///
  /// The engine reads the folder back — its manifest and journals say which
  /// segments are closed — and joins, transcodes and renames it exactly as a
  /// normal stop would, so the card shows the work with its own progress and
  /// the cancel item. Only a refusal needs saying here, and the engine names
  /// the reason.
  Future<void> _retryJoin(RecordingTask task) async {
    final t = context.t;
    final failure = await ref.read(recorderEngineProvider).retryFinalize(task);
    if (!mounted) return;
    if (failure == null) {
      showDsToast(context: context, title: t.recorder.retryJoinStarted, status: DsStatus.info);
      return;
    }
    final message = switch (failure) {
      'busy' => t.recorder.retryJoinBusy,
      'gone' => t.recorder.retryJoinGone,
      'nothing' => t.recorder.retryJoinNothing,
      _ => t.recorder.retryJoinFailed(error: failure),
    };
    showDsToast(context: context, title: message, status: DsStatus.warning);
  }

  /// Whether the card's take can open in either player: a settled task whose
  /// take still exists. A running capture is a folder of open segments, not
  /// something to watch.
  bool _canPreview(RecordingTask task) {
    if (task.postProcessing || task.state == RecordingTaskState.recording) return false;
    // A folder that only holds the archive (its video deleted from the
    // preview) has nothing to play, however much it still exists.
    return playableFileAt(task.filePath) != null;
  }

  /// Opens the built-in preview on [task]'s take, with the centre's other
  /// takes listed beside it — the finished picture first, the folder's
  /// segments when the join never ran.
  Future<void> _openPreview(RecordingTask task) async {
    final t = context.t;
    final items = _previewItems();
    final index = items.indexWhere((item) => item.id == task.id);
    // A take whose files disappeared between the card's build and the tap is
    // said so, not silently replaced by a neighbour in the list.
    if (index < 0) {
      showDsToast(context: context, title: t.recorder.previewUnavailable, status: DsStatus.warning);
      return;
    }
    await openMediaPreview(
      context,
      title: t.recorder.previewTitle,
      items: items,
      initialIndex: index,
      // A take whose file the viewer deleted from the preview is no longer
      // a saved recording: the row says so instead of still reading 已保存
      // over a file that is gone. The entry stays — the take's folder may
      // still hold the chat sidecars and the archived segments.
      onDeleted: (item) async {
        final row = ref.read(recordingTasksProvider).tasks.where((task) => task.id == item.id).firstOrNull;
        if (row == null) return;
        // The row keeps naming the take's folder, so 打开文件夹 still works
        // on what is left in it.
        await ref
            .read(recordingTasksProvider.notifier)
            .setStopped(item.id, filePath: row.takeDirectory, bytes: 0, warning: kRecordingFileDeletedWarning);
      },
    );
  }

  /// Hands the tapped take to the system's own player, files it cannot name
  /// included (the built-in preview is the other door).
  Future<void> _playExternal(RecordingTask task) async {
    final file = playableFileAt(task.filePath);
    if (file == null) {
      showDsToast(context: context, title: context.t.recorder.previewUnavailable, status: DsStatus.warning);
      return;
    }
    await openDownloadedPath(context, file);
  }

  /// Every settled take that holds a file a player can open, in the store's
  /// order — the same construction the IPTV page runs over its own filter of
  /// the shared task library, so the two doors cannot drift.
  List<MediaPreviewItem> _previewItems() => recordingPreviewItems(
    // The same cut as the page's: live's door walks live's takes.
    [
      for (final task in ref.read(recordingTasksProvider).tasks)
        if (task.platform != kIptvRecordingPlatform) task,
    ],
    platformName: (task) => _platformName(task.platform),
  );

  /// Stops every capture the engine is writing.
  ///
  /// Each take ends as a user stop, so its segments stay and its join runs the
  /// way the card's own stop would. A row the engine does not hold is skipped
  /// rather than faked: another window owns that session and its files.
  Future<void> _stopAll(List<RecordingTask> recording) async {
    final t = context.t;
    final confirmed = await showDsConfirm(
      context: context,
      title: t.recorder.stopAllTitle,
      description: t.recorder.stopAllBody(count: recording.length),
      confirmLabel: t.recorder.stopAll,
      cancelLabel: t.common.cancel,
      destructive: true,
      icon: const DsIcon(DsIcons.squareStop),
    );
    if (!confirmed || !mounted) return;
    final engine = ref.read(recorderEngineProvider);
    var stopped = 0;
    String? failure;
    for (final task in recording) {
      if (!engine.isRecording(task.id)) continue;
      try {
        final error = await engine.stop(task.id);
        if (error == null) {
          stopped++;
        } else {
          failure = error;
        }
      } on Object catch (error) {
        failure = error.toString();
      }
    }
    if (!mounted) return;
    showDsToast(
      context: context,
      title: failure == null
          ? t.recorder.stopAllDone(count: stopped)
          : t.recorder.stopAllPartial(count: stopped, error: failure),
      status: failure == null ? DsStatus.success : DsStatus.warning,
    );
  }

  /// Drops the rows a session already settled, leaving every file where it is.
  ///
  /// The list of a recorder that ran for a month is mostly history; the take is
  /// the thing worth keeping, the card is not. A take still being joined and a
  /// room still being watched are never in this group (the caller filters them),
  /// and removing a row touches no media.
  Future<void> _clearFinished(List<RecordingTask> settled) async {
    final t = context.t;
    final confirmed = await showDsConfirm(
      context: context,
      title: t.recorder.clearSettledTitle,
      description: t.recorder.clearSettledBody(count: settled.length),
      confirmLabel: t.recorder.clearSettled,
      cancelLabel: t.common.cancel,
      destructive: true,
      icon: const DsIcon(DsIcons.trash2),
    );
    if (!confirmed || !mounted) return;
    final notifier = ref.read(recordingTasksProvider.notifier);
    var removed = 0;
    for (final task in settled) {
      await notifier.remove(task.id);
      removed++;
    }
    if (!mounted) return;
    showDsToast(
      context: context,
      title: t.recorder.clearSettledDone(count: removed),
      status: DsStatus.success,
    );
  }

  /// Starts a waiting/stopped task now, ignoring its schedule window.
  ///
  /// This is the manual override a viewer uses when they know the room is live:
  /// it resolves the current line exactly as the monitor does and hands it to
  /// the engine.
  Future<void> _startNow(RecordingTask task) async {
    final t = context.t;
    final site = ref.read(sitesProvider).getById(task.platform);
    if (site == null) {
      showDsToast(
        context: context,
        title: t.recorder.startNowFailed(error: task.platform),
        status: DsStatus.danger,
      );
      return;
    }
    try {
      final stream = await resolveRecordableStream(
        site: site,
        platform: task.platform,
        roomId: task.roomId,
        qualityLabel: task.quality,
      ).timeout(const Duration(seconds: 20));
      if (!mounted) return;
      final failure = await ref
          .read(recorderEngineProvider)
          .start(task, stream.line, room: stream.room, danmaku: site.capability<LiveDanmakuProvider>());
      if (!mounted) return;
      showDsToast(
        context: context,
        title: failure == null
            ? t.recorder.startNowStarted
            : failure == 'custom-ca'
            ? t.recorder.startNowCaFailed
            : failure == 'recording-busy'
            ? t.recorder.startNowBusyOther
            : t.recorder.startNowFailed(error: failure),
        status: failure == null ? DsStatus.success : DsStatus.danger,
      );
    } on NoRecordableStream catch (error) {
      if (!mounted) return;
      showDsToast(
        context: context,
        title: error.reason == 'offline' ? t.recorder.startNowOffline : t.recorder.startNowNoStream,
        status: DsStatus.warning,
      );
    } on TimeoutException {
      if (mounted) showDsToast(context: context, title: t.recorder.startNowTimeout, status: DsStatus.warning);
    } on Object catch (error) {
      if (mounted) {
        showDsToast(
          context: context,
          title: t.recorder.startNowFailed(error: error.toString()),
          status: DsStatus.danger,
        );
      }
    }
  }

  /// Opens the take's schedule editor and saves the window it returns.
  Future<void> _editSchedule(RecordingTask task) async {
    final draft = await showDsDialog<_ScheduleDraft>(
      context: context,
      builder: (context) => _ScheduleDialog(task: task),
    );
    if (draft == null || !mounted) return;
    final days = draft.days.toList()..sort();
    await ref
        .read(recordingTasksProvider.notifier)
        .add(
          task.copyWith(
            scheduleEnabled: draft.enabled,
            scheduleDays: days.isEmpty ? const [1, 2, 3, 4, 5, 6, 7] : days,
            scheduleStartMinutes: draft.start,
            scheduleEndMinutes: draft.end,
            stopAtWindowEnd: draft.stopAtEnd,
          ),
        );
    if (!mounted) return;
    showDsToast(context: context, title: context.t.recorder.scheduleSaved, status: DsStatus.success);
  }

  /// A platform id's display name, or the id itself when the registry
  /// does not know it (a task from a site since removed).
  String _platformName(String id) {
    final site = ref.read(sitesProvider).getById(id);
    return site == null ? id : localizedSiteName(site);
  }
}

/// The callbacks one task row carries, named for the helpers that pass
/// them between the card list and the table.
typedef _TaskCallbacks = ({
  VoidCallback onOpen,
  VoidCallback? onStop,
  VoidCallback? onCancelWaiting,
  VoidCallback onDelete,
  VoidCallback onSchedule,
  VoidCallback? onStartNow,
  VoidCallback? onCancelProcessing,
  VoidCallback? onRetryJoin,
  VoidCallback? onPreview,
  VoidCallback? onPlayExternal,
});

/// A filter's word, without its count.

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
    required this.onSchedule,
    this.onStop,
    this.onCancelWaiting,
    this.onCancelProcessing,
    this.onStartNow,
    this.onRetryJoin,
    this.onPreview,
    this.onPlayExternal,
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

  /// Opens the take's schedule editor.
  final VoidCallback onSchedule;

  /// Stops a running capture, null when the task is not being recorded.
  final VoidCallback? onStop;

  /// Takes a waiting task out of the live check, null for other states.
  final VoidCallback? onCancelWaiting;

  /// Cancels a running join/transcode, null when there is none.
  final VoidCallback? onCancelProcessing;

  /// Starts a waiting/stopped task now, null while it is already running.
  final VoidCallback? onStartNow;

  /// Re-runs the post-recording steps on a take the app never finished, null
  /// while the task is being captured or finished.
  final VoidCallback? onRetryJoin;

  /// Opens the built-in preview over the centre's finished takes, null when
  /// this card's take is not one of them.
  final VoidCallback? onPreview;

  /// Hands this take to the system's own player, null under the same rule.
  final VoidCallback? onPlayExternal;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final theme = DsTheme.of(context);
    final colors = DsTheme.colorsOf(context);
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
      if (task.scheduleEnabled) _scheduleSummary(t, task),
      t.recorder.startedAt(time: formatRecordingMoment(task.startedAt)),
    ].join(' · ');
    // Media time is what the take actually captured; a running session that
    // has not reported yet falls back to the wall clock since it started.
    final recorded = Duration(milliseconds: task.durationMs);
    final elapsed = task.isRunning && recorded == Duration.zero ? DateTime.now().difference(task.startedAt) : recorded;
    final speed = task.isRunning && elapsed.inSeconds > 0 && task.bytes > 0 ? task.bytes / elapsed.inSeconds : 0.0;
    final progress = [
      if (elapsed > Duration.zero) formatRecordingDuration(elapsed),
      if (speed > 0) '${formatRecordingBytes(speed.round())}/s',
    ].join(' · ');
    return DsCard(
      onPressed: onOpen,
      semanticLabel: title,
      style: DsCardStyle(
        padding: const EdgeInsets.all(DsSpace.s12),
        borderRadius: BorderRadius.circular(theme.radii.card),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          // The badge, the size figure and the menu — with the gaps, some
          // 110–130 px — are fixed, so the cover follows the card's own
          // width (the sidebar beside the list shrinks it too) and steps
          // down before the title starves; at the window's floor it stands
          // down entirely.
          final width = constraints.maxWidth;
          final (coverWidth, coverHeight) = width >= 560
              ? (128.0, 72.0)
              : width >= 420
              ? (96.0, 54.0)
              : width >= 340
              ? (72.0, 40.0)
              : (0.0, 0.0);
          return Row(
            spacing: DsSpace.s12,
            children: [
              if (coverWidth > 0)
                DsImage(
                  image: cover.isEmpty ? null : cachedImage(cover),
                  width: coverWidth,
                  height: coverHeight,
                  semanticLabel: title,
                  fallback: _CoverFallback(letter: platformLetter(task.platform)),
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
                    // A row that says recording while this window holds no
                    // session tells the truth about the store, not about here:
                    // another window may be writing it, or the last process
                    // died mid-take. The line says which readings to expect
                    // rather than leaving a card that looks live and answers
                    // nothing.
                    if (task.state == RecordingTaskState.recording && onStop == null)
                      Text(
                        t.recorder.stateRecordingElsewhere,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.typography.caption.copyWith(color: colors.warning.text),
                      ),
                    if (task.state == RecordingTaskState.failed && task.errorText.trim().isNotEmpty)
                      Text(
                        task.errorText.trim(),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.typography.caption.copyWith(color: colors.danger.text),
                      ),
                    if (!task.postProcessing && task.warning.isNotEmpty)
                      Text(
                        _warningLabel(t, task.warning),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.typography.caption.copyWith(color: colors.warning.text),
                      ),
                    if (task.postProcessing)
                      Padding(
                        padding: const EdgeInsets.only(top: DsSpace.s4),
                        child: Align(
                          alignment: AlignmentDirectional.centerStart,
                          child: DsProgressBar(
                            value: task.postProcessingProgress >= 0
                                ? task.postProcessingProgress.clamp(0.0, 1.0)
                                : null,
                            semanticLabel: t.recorder.stateProcessing,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                spacing: DsSpace.s3,
                children: [
                  DsBadge(
                    label: Text(
                      task.postProcessing
                          ? t.recorder.stateProcessing
                          : _fileDeleted
                          ? t.recorder.stateFileDeleted
                          : stateLabel(t, task.state),
                    ),
                    status: task.postProcessing
                        ? DsStatus.info
                        : _fileDeleted
                        ? DsStatus.neutral
                        : stateStatus(task.state),
                  ),
                  Text(
                    task.bytes > 0 ? formatRecordingBytes(task.bytes) : '—',
                    style: theme.typography.caption.copyWith(color: colors.textSubtle),
                  ),
                  if (progress.isNotEmpty)
                    Text(
                      progress,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.typography.caption.copyWith(color: colors.textSubtle),
                    ),
                ],
              ),
              _TaskMenu(
                task: task,
                hasFile: (task.filePath ?? '').trim().isNotEmpty,
                onOpen: onOpen,
                onStop: onStop,
                onCancelWaiting: onCancelWaiting,
                onDelete: onDelete,
                onSchedule: onSchedule,
                onCancelProcessing: onCancelProcessing,
                onStartNow: onStartNow,
                onRetryJoin: onRetryJoin,
                onPreview: onPreview,
                onPlayExternal: onPlayExternal,
              ),
            ],
          );
        },
      ),
    );
  }

  /// Whether the take's file was deleted from the preview: a settled row
  /// whose recording is gone reads as that, not as saved.
  bool get _fileDeleted => task.state == RecordingTaskState.stopped && task.warning == 'file-deleted';

  /// The state's badge label.
  static String stateLabel(Translations t, RecordingTaskState state) => switch (state) {
    RecordingTaskState.recording => t.recorder.stateRecording,
    RecordingTaskState.waiting => t.recorder.stateWaiting,
    RecordingTaskState.stopped => t.recorder.stateSaved,
    RecordingTaskState.failed => t.recorder.stateFailed,
  };

  /// The state's badge tone: capturing is live information, waiting is a
  /// pending state, a saved session is a success, a failed one is danger.
  static DsStatus stateStatus(RecordingTaskState state) => switch (state) {
    RecordingTaskState.recording => DsStatus.info,
    RecordingTaskState.waiting => DsStatus.warning,
    RecordingTaskState.stopped => DsStatus.success,
    RecordingTaskState.failed => DsStatus.danger,
  };

  /// The tile's letter: the platform id's first rune, uppercased.
  static String platformLetter(String platform) {
    if (platform.isEmpty) return '?';
    return platform[0].toUpperCase();
  }
}

/// The whole-list actions, beside the page title.
///
/// An item appears only when there is something for it to act on — a row that
/// would do nothing is a dead control, and the card menu already follows the
/// same rule. Bulk *starting* is deliberately absent: a waiting room is begun
/// by the live check when it goes on air, and forcing one that is offline is
/// what each card's 「立即开录」 exists for.
final class _BatchMenu extends StatelessWidget {
  const _BatchMenu({this.onStopAll, this.onClearFinished});

  /// Stops the captures now running; null when none are.
  final VoidCallback? onStopAll;

  /// Drops the rows a session already settled; null when there are none.
  final VoidCallback? onClearFinished;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final theme = DsTheme.of(context);
    final colors = DsTheme.colorsOf(context);
    if (onStopAll == null && onClearFinished == null) return const SizedBox.shrink();
    return DsMenuAnchor(
      semanticLabel: t.recorder.batchMenu,
      align: DsAlign.end,
      builder: (context, controller, child) => DsPressable(
        semanticLabel: t.recorder.batchMenu,
        onPressed: controller.toggle,
        builder: (context, states, _) {
          final hovered = states.contains(WidgetState.hovered);
          return Padding(
            padding: const EdgeInsets.all(DsSpace.s4),
            child: DsIcon(
              DsIcons.listChecks,
              size: theme.sizes.iconSm,
              color: hovered ? colors.text : colors.textSubtle,
            ),
          );
        },
      ),
      items: [
        if (onStopAll case final stop?)
          DsMenuItem(
            leading: const DsIcon(DsIcons.squareStop),
            label: Text(t.recorder.stopAll),
            destructive: true,
            onPressed: stop,
          ),
        if (onClearFinished case final clear?)
          DsMenuItem(
            leading: const DsIcon(DsIcons.trash2),
            label: Text(t.recorder.clearSettled),
            destructive: true,
            onPressed: clear,
          ),
      ],
    );
  }
}

/// The card's "⋮" menu: the room, the saved file's folder (when the task
/// has one), taking a waiting task out of the live check, and the confirmed
/// delete.
final class _TaskMenu extends StatelessWidget {
  const _TaskMenu({
    required this.task,
    required this.hasFile,
    required this.onOpen,
    required this.onDelete,
    required this.onSchedule,
    this.onStop,
    this.onCancelWaiting,
    this.onCancelProcessing,
    this.onStartNow,
    this.onRetryJoin,
    this.onPreview,
    this.onPlayExternal,
  });

  final RecordingTask task;

  /// Whether the task has a saved file (so a folder to open).
  final bool hasFile;

  final VoidCallback onOpen;
  final VoidCallback onDelete;
  final VoidCallback onSchedule;

  /// Stops a running capture, null when the task is not being recorded.
  final VoidCallback? onStop;

  /// Takes a waiting task out of the live check, null for other states.
  final VoidCallback? onCancelWaiting;

  /// Cancels a running join/transcode, null when there is none.
  final VoidCallback? onCancelProcessing;

  /// Starts a waiting/stopped task now, null while it is already running.
  final VoidCallback? onStartNow;

  /// Re-runs the post-recording steps on a take the app never finished, null
  /// while the task is being captured or finished.
  final VoidCallback? onRetryJoin;

  /// Opens the built-in preview over the centre's finished takes, null when
  /// this card's take is not one of them.
  final VoidCallback? onPreview;

  /// Hands this take to the system's own player, null under the same rule.
  final VoidCallback? onPlayExternal;

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
        DsMenuItem(
          leading: const DsIcon(DsIcons.calendarClock),
          label: Text(t.recorder.scheduleMenu),
          onPressed: onSchedule,
        ),
        if (onStartNow case final start?)
          DsMenuItem(leading: const DsIcon(DsIcons.play), label: Text(t.recorder.startNow), onPressed: start),
        if (hasFile)
          DsMenuItem(
            leading: const DsIcon(DsIcons.folderOpen),
            label: Text(t.recorder.openFolder),
            onPressed: () => unawaited(_openFolder(context)),
          ),
        if (onPreview case final preview?)
          DsMenuItem(
            leading: const DsIcon(DsIcons.playCircle),
            label: Text(t.recorder.previewRecording),
            onPressed: preview,
          ),
        if (onPlayExternal case final play?)
          DsMenuItem(leading: const DsIcon(DsIcons.play), label: Text(t.recorder.playRecording), onPressed: play),
        if (onStop case final stop?)
          DsMenuItem(
            leading: const DsIcon(DsIcons.squareStop),
            label: Text(t.recorder.stop),
            destructive: true,
            onPressed: stop,
          ),
        if (onCancelProcessing case final cancel?)
          DsMenuItem(leading: const DsIcon(DsIcons.x), label: Text(t.recorder.cancelProcessing), onPressed: cancel),
        if (onRetryJoin case final retry?)
          DsMenuItem(leading: const DsIcon(DsIcons.merge), label: Text(t.recorder.retryJoin), onPressed: retry),
        if (onCancelWaiting case final cancel?)
          DsMenuItem(leading: const DsIcon(DsIcons.clock), label: Text(t.room.autoRecordOff), onPressed: cancel),
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
    await openDownloadedPath(context, p.dirname(file), failedTitle: context.t.recorder.openFolderFailed);
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
    // The tap can land after the dialog's host is gone (the list rebuilt
    // under it); a dead context must not reach the page's store callback.
    if (!confirmed || !context.mounted) return;
    onDelete();
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

/// A recording cap in the unit the settings use: whole megabytes below a
/// gigabyte, one decimal above.
String _formatMb(int megabytes) => megabytes >= 1024 ? '${(megabytes / 1024).toStringAsFixed(1)} GB' : '$megabytes MB';

/// A bitrate as the settings show it: whole megabits when the figure divides
/// evenly, one decimal otherwise.
String _formatBitrate(int kbps) =>
    kbps % 1000 == 0 ? '${kbps ~/ 1000} Mbps' : '${(kbps / 1000).toStringAsFixed(1)} Mbps';

/// The bitrate choices, plus the stored value when it came from an older
/// build, so the dropdown never opens on a value it does not list.
List<int> _transcodeBitrateChoices(int current) => ({1500, 2500, 4000, 6000, 8000, current}.toList()..sort());

/// One of the stable post-processing warning codes as the viewer's sentence.
String _warningLabel(Translations t, String warning) => switch (warning) {
  'join-failed' => t.recorder.warningJoinFailed,
  'transcode-failed' => t.recorder.warningTranscodeFailed,
  'stale' => t.recorder.warningStaleProcessing,
  'disk-low' => t.recorder.warningDiskLow,
  'canceled' => t.recorder.warningCanceled,
  'file-deleted' => t.recorder.warningFileDeleted,
  _ => t.recorder.warningFinalizeFailed,
};

/// A clock minute in the 24-hour form the app's Chinese UI uses; 1440 is the
/// end of the day, shown as 24:00.
String _formatClock(int minutes) {
  final value = minutes.clamp(0, 1440);
  final hour = value ~/ 60;
  final minute = value % 60;
  return '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
}

String _scheduleDayLabel(Translations t, int day) => switch (day) {
  1 => t.recorder.scheduleDayMon,
  2 => t.recorder.scheduleDayTue,
  3 => t.recorder.scheduleDayWed,
  4 => t.recorder.scheduleDayThu,
  5 => t.recorder.scheduleDayFri,
  6 => t.recorder.scheduleDaySat,
  _ => t.recorder.scheduleDaySun,
};

/// The weekdays a schedule covers, in the shortest form that stays truthful.
String _scheduleDaysLabel(Translations t, List<int> days) {
  final selected = days.isEmpty ? const {1, 2, 3, 4, 5, 6, 7} : days.toSet();
  if (selected.length == 7) return t.recorder.scheduleEveryDay;
  if (selected.length == 5 && selected.containsAll(const [1, 2, 3, 4, 5])) {
    return t.recorder.scheduleWorkdays;
  }
  if (selected.length == 2 && selected.containsAll(const [6, 7])) return t.recorder.scheduleWeekend;
  return [
    for (var day = 1; day <= 7; day++)
      if (selected.contains(day)) _scheduleDayLabel(t, day),
  ].join(t.recorder.scheduleDaySeparator);
}

String _scheduleSummary(Translations t, RecordingTask task) => t.recorder.scheduleSummary(
  days: _scheduleDaysLabel(t, task.scheduleDays),
  range: '${_formatClock(task.scheduleStartMinutes)}–${_formatClock(task.scheduleEndMinutes)}',
);

/// A capture length as a player shows it: minutes and seconds, hours only

/// A local moment for a task list row: the clock on today's entries, a

/// One labelled slider of the recorder settings: the row every settings
/// bar uses — the knob and its description on the left, the current value
/// and the bar at the row's end (the bar drops under the row when the pane
/// is too narrow to carry it).
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
  Widget build(BuildContext context) => SettingsConfigRow(
    leading: DsIcon(icon),
    title: title,
    description: description,
    detail: Text(detail),
    controlWidth: 220,
    control: DsSlider(
      value: value.clamp(min, max),
      min: min,
      max: max,
      divisions: divisions,
      onChanged: onChanged,
      semanticLabel: semanticLabel,
      semanticFormatter: (value) => detail,
    ),
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

  /// Null keeps the switch visible but disabled, so a dependent setting
  /// never reads as a missing one.
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) => SettingsConfigRow(
    leading: DsIcon(icon),
    title: title,
    description: description,
    control: DsSwitch(value: value, onChanged: onChanged, semanticLabel: title),
  );
}

/// The recording settings' categories: where a file lands and how it names
/// itself, how a capture is segmented and recovered, the background and
/// capacity limits, and the live check that starts captures on its own.
enum RecordingTab {
  /// Where files land, what they are called and the file's own shape.
  files,

  /// Segmentation, timeouts and the retry walk.
  capture,

  /// Background behaviour, concurrency and the managed cache.
  runtime,

  /// Watching followed rooms for a live start.
  polling,
}

/// The recorder's settings pane: one page with its categories on a segmented
/// control, the way the danmaku settings lay their own out — a short tab
/// instead of one long scroll, and one headed card per topic.
final class RecordingSettingsPane extends ConsumerStatefulWidget {
  /// The recorder settings pane.
  const RecordingSettingsPane({super.key});

  @override
  ConsumerState<RecordingSettingsPane> createState() => _RecordingSettingsPaneState();
}

final class _RecordingSettingsPaneState extends ConsumerState<RecordingSettingsPane> {
  RecordingTab _tab = RecordingTab.files;

  /// The pushed page's header end, when this pane is shown as its own page;
  /// null when it sits in a desktop window's settings pane, which has no
  /// header of its own.
  ValueNotifier<Widget?>? _slot;

  /// Whether the reset action was handed to that header.
  bool _published = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _slot = SettingsPageActionScope.maybeOf(context);
    final slot = _slot;
    if (slot == null || _published) return;
    _published = true;
    // A header sits above this body: notifying it mid-build would rebuild an
    // ancestor while the tree is still being laid out.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) slot.value = _resetAction();
    });
  }

  @override
  void dispose() {
    // A header left holding a dead action would press nothing.
    final slot = _slot;
    if (slot != null && _published) slot.value = null;
    super.dispose();
  }

  /// The reset as the page header's end control: an icon the viewer can find
  /// beside the title, not a row the body has to make room for.
  Widget _resetAction() => DsButton.icon(
    variant: DsButtonVariant.ghost,
    semanticLabel: context.t.recorder.resetAll,
    onPressed: () => unawaited(_resetAll()),
    icon: const DsIcon(DsIcons.rotateCw, size: 18),
  );

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: DsSpace.s16,
      children: [
        // On its own page the reset lives in the header's end; an in-place
        // desktop pane has no header, so it draws the same action here.
        if (_slot == null)
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: DsButton(
              variant: DsButtonVariant.secondary,
              size: DsSize.sm,
              leading: const DsIcon(DsIcons.rotateCw, size: 16),
              onPressed: () => unawaited(_resetAll()),
              child: Text(t.recorder.resetAll),
            ),
          ),
        // Four names do not always fit a narrow pane — the recording centre
        // opens this same pane in a dialog: the control scrolls sideways
        // instead of squeezing its own segments.
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DsSegmentedControl<RecordingTab>(
              value: _tab,
              semanticLabel: t.recorder.settingsTitle,
              segments: [
                DsSegment(
                  value: RecordingTab.files,
                  label: Text(t.recorder.settingsTabFiles),
                  icon: const DsIcon(DsIcons.folderVideo, size: 16),
                ),
                DsSegment(
                  value: RecordingTab.capture,
                  label: Text(t.recorder.settingsTabCapture),
                  icon: const DsIcon(DsIcons.refreshCw, size: 16),
                ),
                DsSegment(
                  value: RecordingTab.runtime,
                  label: Text(t.recorder.settingsTabRuntime),
                  icon: const DsIcon(DsIcons.activity, size: 16),
                ),
                DsSegment(
                  value: RecordingTab.polling,
                  label: Text(t.recorder.settingsTabPolling),
                  icon: const DsIcon(DsIcons.clock, size: 16),
                ),
              ],
              onChanged: (value) => setState(() => _tab = value),
            ),
          ),
        ),
        switch (_tab) {
          RecordingTab.files => _files(context),
          RecordingTab.capture => _capture(context),
          RecordingTab.runtime => _runtime(context),
          RecordingTab.polling => _polling(context),
        },
      ],
    );
  }

  /// Where a file lands, what it is called, how big it may grow, which
  /// container it uses and whether the chat is written beside it.
  Widget _files(BuildContext context) {
    final t = context.t;
    final settings = ref.watch(recordingSettingsProvider);
    final controller = ref.read(recordingSettingsProvider.notifier);
    final directory = ref.watch(appPathsProvider).recordings;
    final custom = ref.watch(storageFolderOverridesProvider).containsKey(StorageFolder.recordings);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: DsSpace.s16,
      children: [
        DsListSection(
          header: Text(t.recorder.settingsFiles),
          children: [
            SettingsChoiceRow<String>(
              leading: const DsIcon(DsIcons.slidersHorizontal),
              title: t.recorder.defaultQualityTitle,
              description: t.recorder.defaultQualityDesc,
              value: settings.defaultQuality,
              options: [
                for (final quality in kPreferredResolutionChoices) DsSelectOption(value: quality, label: quality),
              ],
              onChanged: (value) => controller.defaultQuality = value,
            ),
            // The folder is chosen right here now, not only on the storage
            // page: this is where a viewer looks when a recording lands
            // somewhere unexpected.
            DsListRow(
              leading: const DsIcon(DsIcons.folder),
              title: Text(t.recorder.saveDirTitle),
              description: DsTooltip(
                message: directory.path,
                child: Text(directory.path, maxLines: 1, overflow: TextOverflow.ellipsis),
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
                    semanticLabel: t.recorder.openFolder,
                    onPressed: () => unawaited(_openFolder(context, directory.path)),
                    icon: const DsIcon(DsIcons.folderOpen, size: 16),
                  ),
                ],
              ),
            ),
            // Always there, so a custom folder never hides the way back; it says
            // so rather than disappearing when the default already applies.
            DsListRow(
              leading: const DsIcon(DsIcons.rotateCcw),
              title: Text(t.recorder.saveDirResetTitle),
              description: Text(custom ? t.recorder.saveDirResetDesc : t.recorder.saveDirDefaultInUse),
              onPressed: custom ? () => unawaited(_resetFolder()) : null,
            ),
            DsListRow(
              leading: const DsIcon(DsIcons.fileText),
              title: Text(t.recorder.namingTitle),
              description: Text(t.recorder.namingDescription),
              detail: Text(settings.namingTemplate),
              onPressed: () => unawaited(_editNaming(context, ref)),
              showChevron: true,
            ),
            // A cap the viewer can lift: off means the take runs until the
            // stream ends or the duration split cuts it.
            _RecordSwitch(
              icon: DsIcons.hardDrive,
              title: t.recorder.maxSizeLimitTitle,
              description: t.recorder.maxSizeLimitDesc,
              value: settings.maxSizeMb > 0,
              onChanged: (value) => controller.maxSizeMb = value ? RecordingSettings.defaults.maxSizeMb : 0,
            ),
            // The bar belongs to the cap above it: with the cap off there is
            // no number to set.
            if (settings.maxSizeMb > 0)
              _RecordSlider(
                icon: DsIcons.hardDrive,
                title: t.recorder.maxSizeTitle,
                description: t.recorder.maxSizeDescription,
                detail: _formatMb(settings.maxSizeMb),
                value: settings.maxSizeMb.toDouble(),
                min: 100,
                max: 20480,
                divisions: 203,
                // The slider's 100.4 MB steps land on 401, 502 …; whole
                // hundreds read cleanly in the detail, capped at the max.
                onChanged: (value) => controller.maxSizeMb = ((value / 100).round() * 100).clamp(100, 20480),
                semanticLabel: t.recorder.maxSizeTitle,
              ),
            // A dropdown, not a two-way segmented strip: the container is a
            // choice among formats like every other format row, and a
            // third would not fit the segment.
            SettingsChoiceRow<RecordingFileContainer>(
              leading: const DsIcon(DsIcons.fileVideo),
              title: t.recorder.containerTitle,
              description: t.recorder.containerDescription,
              value: settings.container,
              options: [
                DsSelectOption(value: RecordingFileContainer.mpegTs, label: t.recorder.containerTs),
                DsSelectOption(value: RecordingFileContainer.mp4, label: t.recorder.containerMp4),
              ],
              onChanged: (value) => controller.container = value,
            ),
            // The post-recording step the reference runs by default: segments
            // are the crash-safe capture, one MP4 is the file a viewer opens.
            _RecordSwitch(
              icon: DsIcons.film,
              title: t.recorder.combineTitle,
              description: t.recorder.combineDesc,
              value: settings.combineAfterStop,
              onChanged: (value) => controller.combineAfterStop = value,
            ),
            if (settings.combineAfterStop)
              _RecordSwitch(
                icon: DsIcons.trash2,
                title: t.recorder.combineDeleteOriginals,
                description: t.recorder.combineDeleteOriginalsDesc,
                value: settings.deleteOriginalsAfterCombine,
                onChanged: (value) => controller.deleteOriginalsAfterCombine = value,
              ),
            if (settings.combineAfterStop)
              _RecordSwitch(
                icon: DsIcons.cpu,
                title: t.recorder.transcodeTitle,
                description: t.recorder.transcodeDesc,
                value: settings.transcodeAfterCombine,
                onChanged: (value) => controller.transcodeAfterCombine = value,
              ),
            if (settings.combineAfterStop && settings.transcodeAfterCombine)
              SettingsChoiceRow<int>(
                leading: const DsIcon(DsIcons.gauge),
                title: t.recorder.transcodeBitrateTitle,
                description: t.recorder.transcodeBitrateDesc,
                value: settings.transcodeBitrateKbps,
                options: [
                  for (final bitrate in _transcodeBitrateChoices(settings.transcodeBitrateKbps))
                    DsSelectOption(value: bitrate, label: _formatBitrate(bitrate)),
                ],
                onChanged: (value) => controller.transcodeBitrateKbps = value,
              ),
            _RecordSwitch(
              icon: DsIcons.messageCircle,
              title: t.recorder.recordChatTitle,
              description: t.recorder.recordChatDescription,
              value: settings.recordDanmaku,
              onChanged: (value) => controller.recordDanmaku = value,
            ),
            // A sub-option of the switch above it: with the chat off there is no
            // danmaku file for a gift to join.
            if (settings.recordDanmaku)
              _RecordSwitch(
                icon: DsIcons.gift,
                title: t.recorder.recordChatGiftsTitle,
                description: t.recorder.recordChatGiftsDesc,
                value: settings.recordDanmakuGifts,
                onChanged: (value) => controller.recordDanmakuGifts = value,
              ),
          ],
        ),
        // The formats only matter while the chat is recorded; the switch
        // above is the only way in, so they follow it.
        if (settings.recordDanmaku) const DanmakuSaveFormatsSection(),
      ],
    );
  }

  /// How a capture is cut, how long it waits and how it walks its retries.
  Widget _capture(BuildContext context) {
    final t = context.t;
    final settings = ref.watch(recordingSettingsProvider);
    final controller = ref.read(recordingSettingsProvider.notifier);
    // The row says what is in force, which means it has to say so when the
    // picked bundle is no longer where the row found it.
    final customCa = settings.network.customCaPath.trim();
    final customCaName = customCa.isEmpty ? '' : p.basename(customCa);
    final missing = customCa.isNotEmpty && !File(customCa).existsSync();
    return DsListSection(
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
          detail: t.recorder.seconds(count: settings.network.readTimeoutSeconds),
          value: settings.network.readTimeoutSeconds.toDouble(),
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
          min: 5,
          max: 120,
          divisions: 23,
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
          icon: DsIcons.filter,
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
        _RecordSwitch(
          icon: DsIcons.lockCheck,
          title: t.recorder.tlsVerifyTitle,
          description: t.recorder.tlsVerifyDesc,
          value: settings.network.tlsVerify,
          onChanged: (value) => controller.tlsVerify = value,
        ),
        // Trusting one's own root is the honest alternative to switching
        // verification off, so it sits beside that switch rather than hidden
        // three rows away.
        DsListRow(
          leading: const DsIcon(DsIcons.badgeCheck),
          title: Text(t.recorder.caCustomTitle),
          description: Text(
            customCa.isEmpty
                ? t.recorder.caCustomDesc
                : missing
                ? t.recorder.caCustomMissing(name: customCaName)
                : t.recorder.caCustomPicked(name: customCaName),
          ),
          onPressed: () => unawaited(_pickCaFile()),
          showChevron: true,
          trailing: customCa.isEmpty
              ? null
              : DsButton(
                  variant: DsButtonVariant.ghost,
                  size: DsSize.sm,
                  onPressed: () => unawaited(_clearCaFile()),
                  child: Text(t.recorder.caCustomClear),
                ),
        ),
      ],
    );
  }

  /// What the app does while capturing in the background, how many takes run
  /// at once, and the managed folder's own cap.
  Widget _runtime(BuildContext context) {
    final t = context.t;
    final settings = ref.watch(recordingSettingsProvider);
    final controller = ref.read(recordingSettingsProvider.notifier);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: DsSpace.s16,
      children: [
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
            SettingsChoiceRow<int>(
              leading: const DsIcon(DsIcons.listOrdered),
              title: t.recorder.queueTitle,
              description: t.recorder.queueDescription,
              value: _queueChoice(settings.queueSize),
              options: [
                for (final size in const [1024, 2048, 4096, 8192]) DsSelectOption(value: size, label: '$size'),
              ],
              onChanged: (value) => controller.queueSize = value,
            ),
            // Both caps can be lifted: off means the queue's waiting takes
            // start as they come, and takes are not stopped for low free
            // space.
            _RecordSwitch(
              icon: DsIcons.layers,
              title: t.recorder.maxTasksLimitTitle,
              description: t.recorder.maxTasksLimitDesc,
              value: settings.maxTasks > 0,
              onChanged: (value) => controller.maxTasks = value ? RecordingSettings.defaults.maxTasks : 0,
            ),
            if (settings.maxTasks > 0)
              _RecordSlider(
                icon: DsIcons.layers,
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
            _RecordSwitch(
              icon: DsIcons.hardDrive,
              title: t.recorder.diskWatermarkLimitTitle,
              description: t.recorder.diskWatermarkLimitDesc,
              value: settings.diskWatermarkMb > 0,
              onChanged: (value) => controller.diskWatermarkMb = value ? RecordingSettings.defaults.diskWatermarkMb : 0,
            ),
            if (settings.diskWatermarkMb > 0)
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
        const _RecordingCacheSection(),
      ],
    );
  }

  /// Watching followed rooms for a live start, and picking a capture back up
  /// after a restart.
  Widget _polling(BuildContext context) {
    final t = context.t;
    final settings = ref.watch(recordingSettingsProvider);
    final controller = ref.read(recordingSettingsProvider.notifier);
    return DsListSection(
      header: Text(t.recorder.liveCheckGroup),
      children: [
        _RecordSwitch(
          icon: DsIcons.clock,
          title: t.recorder.enablePolling,
          description: t.recorder.enablePollingDesc,
          value: settings.schedule.pollingEnabled,
          onChanged: (value) => controller.pollingEnabled = value,
        ),
        // The schedule belongs to the switch above it: with polling off
        // there is no interval to set, so these follow it in and out.
        if (settings.schedule.pollingEnabled) ...[
          _RecordSlider(
            icon: DsIcons.timer,
            title: t.recorder.liveCheckSecondsTitle,
            description: t.recorder.liveCheckSecondsDesc,
            detail: t.recorder.seconds(count: settings.schedule.liveCheckSeconds),
            value: settings.schedule.liveCheckSeconds.toDouble(),
            min: 10,
            max: 300,
            divisions: 29,
            onChanged: (value) => controller.liveCheckSeconds = value.round(),
            semanticLabel: t.recorder.liveCheckSecondsTitle,
          ),
          _RecordSwitch(
            icon: DsIcons.activity,
            title: t.recorder.checkBackoff,
            description: t.recorder.checkBackoffDesc,
            value: settings.schedule.checkBackoffEnabled,
            onChanged: (value) => controller.checkBackoffEnabled = value,
          ),
          if (settings.schedule.checkBackoffEnabled)
            _RecordSlider(
              icon: DsIcons.hourglass,
              title: t.recorder.maxCheckSecondsTitle,
              description: t.recorder.maxCheckSecondsDesc,
              detail: t.recorder.seconds(count: settings.schedule.maxCheckSeconds),
              value: settings.schedule.maxCheckSeconds.toDouble(),
              min: 60,
              max: 3600,
              divisions: 59,
              onChanged: (value) => controller.maxCheckSeconds = (value / 60).round() * 60,
              semanticLabel: t.recorder.maxCheckSecondsTitle,
            ),
        ],
        _RecordSwitch(
          icon: DsIcons.power,
          title: t.recorder.autoStartOnBoot,
          description: t.recorder.autoStartOnBootDesc,
          value: settings.schedule.autoStartOnBoot,
          onChanged: (value) => controller.autoStartOnBoot = value,
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

  /// Lets the viewer move the recordings somewhere writable, with the same
  /// probe and toasts the storage page uses.
  Future<void> _pickFolder() async {
    final t = context.t;
    try {
      final selected = await FilePicker.getDirectoryPath(dialogTitle: t.settings.storageFolderPick);
      if (selected == null || selected.trim().isEmpty) return;
      if (!mounted) return;
      final active = ref.read(recorderEngineProvider).activeRecordingCount;
      if (active > 0) {
        final confirmed = await showDsConfirm(
          context: context,
          title: t.recorder.folderInUseTitle,
          description: t.recorder.folderInUseBody(count: active),
          confirmLabel: t.recorder.folderInUseConfirm,
          cancelLabel: t.common.cancel,
          icon: const DsIcon(DsIcons.folderVideo),
        );
        if (!confirmed || !mounted) return;
      }
      final saved = await ref.read(storageFolderOverridesProvider.notifier).set(StorageFolder.recordings, selected);
      if (!mounted) return;
      if (!saved) {
        showDsToast(context: context, title: t.settings.storageFolderPermissionHint, status: DsStatus.danger);
        return;
      }
      showDsToast(
        context: context,
        title: active > 0
            ? t.recorder.folderChangedActive
            : StorageFolder.recordings.needsRestart
            ? '${t.settings.storageFoldersUpdated} · ${t.settings.storageFolderRestart}'
            : t.settings.storageFoldersUpdated,
      );
    } on Object {
      if (mounted) {
        showDsToast(context: context, title: t.settings.storageFolderPickFailed, status: DsStatus.danger);
      }
    }
  }

  /// Lets the viewer point the recorder at a CA bundle of their own — the way
  /// to trust a corporate or self-signed chain without turning verification
  /// off. The engine stages the bytes itself; this proves the pick.
  Future<void> _pickCaFile() async {
    final t = context.t;
    try {
      final picked = await FilePicker.pickFiles(
        dialogTitle: t.recorder.caCustomTitle,
        type: FileType.custom,
        allowedExtensions: const ['pem', 'crt', 'cer', 'ca-bundle'],
      );
      // An empty list is the cancel; a picked file without a path is a content
      // URI this platform will not hand a native reader, so it is treated the
      // same way.
      final path = picked.isEmpty ? '' : picked.first.path ?? '';
      if (path.isEmpty) return;
      final file = File(path);
      if (!file.existsSync() || !file.readAsStringSync().contains('-----BEGIN CERTIFICATE-----')) {
        if (!mounted) return;
        showDsToast(context: context, title: t.recorder.caCustomNotPem, status: DsStatus.danger);
        return;
      }
      ref.read(recordingSettingsProvider.notifier).customCaPath = path;
      if (!mounted) return;
      showDsToast(
        context: context,
        title: t.recorder.caCustomPicked(name: p.basename(path)),
      );
    } on Object {
      if (mounted) {
        showDsToast(context: context, title: t.recorder.caCustomPickFailed, status: DsStatus.danger);
      }
    }
  }

  /// Puts the recorder back on the bundled Mozilla store.
  Future<void> _clearCaFile() async {
    ref.read(recordingSettingsProvider.notifier).customCaPath = '';
    if (!mounted) return;
    showDsToast(context: context, title: context.t.recorder.caCustomCleared);
  }

  /// Puts the recordings back under the download folder; existing files
  /// stay where they are.
  Future<void> _resetFolder() async {
    await ref.read(storageFolderOverridesProvider.notifier).reset(StorageFolder.recordings);
    if (!mounted) return;
    showDsToast(context: context, title: context.t.settings.storageFoldersUpdated);
  }

  /// Puts every recording tunable back to its designed defaults, behind a
  /// confirmation. The save folder and the danmaku save formats are not
  /// recorder tunables and stay exactly as they are.
  Future<void> _resetAll() async {
    final t = context.t;
    final confirmed = await showDsConfirm(
      context: context,
      title: t.recorder.resetAllConfirmTitle,
      description: t.recorder.resetAllConfirmDesc,
      confirmLabel: t.recorder.resetAll,
      cancelLabel: t.common.cancel,
      destructive: true,
      icon: const DsIcon(DsIcons.rotateCw),
    );
    if (!confirmed || !mounted) return;
    await ref.read(recordingSettingsProvider.notifier).reset();
    if (!mounted) return;
    showDsToast(context: context, title: t.recorder.resetAllDone);
  }

  /// Opens the recordings folder in the system's own file manager.
  Future<void> _openFolder(BuildContext context, String path) async {
    await openDownloadedPath(context, path, failedTitle: context.t.recorder.openFolderFailed);
  }

  Future<void> _editNaming(BuildContext context, WidgetRef ref) {
    final t = context.t;
    return _editText(
      context,
      title: t.recorder.namingTitle,
      hint: t.recorder.namingDialogHint,
      initial: ref.read(recordingSettingsProvider).namingTemplate,
      // The engine fills these in; the dialog says which ones exist and
      // inserts a tapped one, so the template is not guessed from memory.
      fields: [
        (token: '{date}', label: t.recorder.namingFieldDate),
        (token: '{time}', label: t.recorder.namingFieldTime),
        (token: '{platform}', label: t.recorder.namingFieldPlatform),
        (token: '{roomId}', label: t.recorder.namingFieldRoomId),
        (token: '{title}', label: t.recorder.namingFieldTitle),
      ],
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
    List<({String token, String label})>? fields,
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
              // Enter commits, as the app's other dialogs do; a plain pop
              // would silently drop what was typed.
              onSubmitted: (next) {
                value = next;
                Navigator.of(context).pop();
                onCommit(value);
              },
              semanticLabel: title,
            ),
            if (fields case final fields?) ...[
              const SizedBox(height: DsSpace.s4),
              Text(t.recorder.namingFieldsCaption),
              Wrap(
                spacing: DsSpace.s8,
                runSpacing: DsSpace.s8,
                children: [
                  for (final entry in fields)
                    DsButton(
                      variant: DsButtonVariant.secondary,
                      size: DsSize.sm,
                      onPressed: () {
                        value = '$value${entry.token}';
                        field
                          ..text = value
                          ..selection = TextSelection.collapsed(offset: value.length);
                      },
                      child: Text('${entry.token} · ${entry.label}'),
                    ),
                ],
              ),
            ],
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

/// The recorder's cache section: the managed folder's size, the automatic
/// trim switch and cap, and the confirmed clear that skips active takes.
final class _RecordingCacheSection extends ConsumerStatefulWidget {
  const _RecordingCacheSection();

  @override
  ConsumerState<_RecordingCacheSection> createState() => _RecordingCacheSectionState();
}

final class _RecordingCacheSectionState extends ConsumerState<_RecordingCacheSection> {
  int? _bytes;
  bool _busy = false;
  ({int done, int total, String name})? _merging;
  bool _mergeCancelRequested = false;

  @override
  void initState() {
    super.initState();
    unawaited(_measure());
  }

  @override
  void dispose() {
    // The run owns real file moves; dropping this card does not undo them, but
    // it must stop the loop from writing into a widget that is gone.
    _mergeCancelRequested = true;
    super.dispose();
  }

  Future<void> _measure() async {
    try {
      final bytes = await ref.read(recorderEngineProvider).cacheBytes();
      if (mounted) setState(() => _bytes = bytes);
    } on Object {
      if (mounted) setState(() => _bytes = 0);
    }
  }

  Future<void> _enforce() async {
    try {
      final bytes = await ref.read(recorderEngineProvider).enforceCacheLimit();
      if (mounted) setState(() => _bytes = bytes);
    } on Object {
      if (mounted) {
        showDsToast(context: context, title: context.t.recorder.cacheFailed, status: DsStatus.danger);
      }
    }
  }

  Future<void> _editLimit() async {
    final value = await showDsDialog<int>(
      context: context,
      builder: (_) => _CacheLimitDialog(initialMb: ref.read(recordingSettingsProvider).cacheLimitMb),
    );
    if (value == null || !mounted) return;
    ref.read(recordingSettingsProvider.notifier).cacheLimitMb = value;
    await _enforce();
  }

  Future<void> _clear() async {
    final t = context.t;
    final confirmed = await showDsConfirm(
      context: context,
      title: t.recorder.cacheClearConfirm,
      description: t.recorder.cacheClearConfirmDesc,
      confirmLabel: t.recorder.cacheClear,
      cancelLabel: t.common.cancel,
      destructive: true,
      icon: const DsIcon(DsIcons.trash2),
    );
    if (!confirmed || !mounted) return;
    setState(() => _busy = true);
    try {
      final bytes = await ref.read(recorderEngineProvider).clearCache();
      if (!mounted) return;
      setState(() => _bytes = bytes);
      showDsToast(context: context, title: t.recorder.cacheCleared);
    } on Object {
      if (mounted) {
        showDsToast(context: context, title: t.recorder.cacheFailed, status: DsStatus.danger);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Brings the takes from other folders into the current one.
  ///
  /// The engine renames on the same volume and copies, measures and only then
  /// deletes across volumes, so a take is never left with one home missing;
  /// this only says how many landed and which did not.
  Future<void> _mergeStranded(List<RecordingTask> stranded) async {
    final t = context.t;
    final confirmed = await showDsConfirm(
      context: context,
      title: t.recorder.mergeTitle,
      description: t.recorder.mergeBody(count: stranded.length),
      confirmLabel: t.recorder.merge,
      cancelLabel: t.common.cancel,
      destructive: true,
      icon: const DsIcon(DsIcons.folderVideo),
    );
    if (!confirmed || !mounted) return;
    setState(() {
      _merging = (done: 0, total: stranded.length, name: '');
      _mergeCancelRequested = false;
    });
    final result = await ref
        .read(recorderEngineProvider)
        .moveStrandedTakes(
          onProgress: (done, total, name) {
            if (mounted) setState(() => _merging = (done: done, total: total, name: name));
          },
          cancelled: () => _mergeCancelRequested,
        )
        .whenComplete(() {
          if (mounted) setState(() => _merging = null);
        });
    if (!mounted) return;
    await _measure();
    if (!mounted) return;
    showDsToast(
      context: context,
      title: result.failed == 0
          ? t.recorder.mergeDone(count: result.moved)
          : t.recorder.mergePartial(moved: result.moved, failed: result.failed),
      status: result.failed == 0 ? DsStatus.success : DsStatus.warning,
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final settings = ref.watch(recordingSettingsProvider);
    final controller = ref.read(recordingSettingsProvider.notifier);
    final tasks = ref.watch(recordingTasksProvider).tasks;
    final recording = tasks.any((task) => task.state == RecordingTaskState.recording);
    final processing = tasks.any((task) => task.postProcessing);
    final directory = ref.watch(appPathsProvider).recordings;
    final outside = ref.read(recorderEngineProvider).hasActiveOutside(directory);
    // Settled takes the current folder does not hold, read from the task list
    // this build already watches — the engine owns the moving, the page only
    // counts and names.
    final stranded = strandedTasksOf(tasks, directory.path);
    final running = _merging;
    final blocked = recording || processing || outside;
    return DsListSection(
      header: Text(t.recorder.cacheTitle),
      children: [
        _RecordSwitch(
          icon: DsIcons.database,
          title: t.recorder.cacheLimitEnabled,
          description: t.recorder.cacheLimitEnabledDesc,
          value: settings.cacheLimitEnabled,
          onChanged: (value) {
            controller.cacheLimitEnabled = value;
            if (value) unawaited(_enforce());
          },
        ),
        if (settings.cacheLimitEnabled)
          DsListRow(
            leading: const DsIcon(DsIcons.hardDrive),
            title: Text(t.recorder.cacheLimit),
            description: Text(t.recorder.cacheLimitDesc),
            detail: Text(_formatMb(settings.cacheLimitMb)),
            onPressed: () => unawaited(_editLimit()),
            showChevron: true,
          ),
        DsListRow(
          leading: const DsIcon(DsIcons.archive),
          title: Text(t.recorder.cacheSize),
          description: Text(
            outside
                ? t.recorder.cacheOtherRoot
                : (recording || processing)
                ? t.recorder.cacheBusy
                : t.recorder.cacheSizeDesc,
          ),
          detail: Text(_bytes == null ? '…' : _formatMb((_bytes! / (1024 * 1024)).round())),
          trailing: DsButton(
            variant: DsButtonVariant.ghost,
            size: DsSize.sm,
            leading: const DsIcon(DsIcons.refreshCw, size: 16),
            onPressed: _busy ? null : () => unawaited(_measure()),
            child: Text(t.recorder.cacheRefresh),
          ),
        ),
        // Takes left behind by a folder move are the one thing the figures
        // above cannot reach, so the row that names them also brings them home.
        if (stranded.isNotEmpty || running != null)
          DsListRow(
            leading: const DsIcon(DsIcons.folderVideo),
            title: Text(t.recorder.merge),
            description: Text(
              running == null
                  ? t.recorder.mergeDesc(count: stranded.length)
                  : t.recorder.mergeRunning(done: running.done + 1, total: running.total, name: running.name),
            ),
            trailing: DsButton(
              variant: DsButtonVariant.secondary,
              size: DsSize.sm,
              onPressed: running == null
                  ? () => unawaited(_mergeStranded(stranded))
                  : () => setState(() => _mergeCancelRequested = true),
              child: Text(running == null ? t.recorder.merge : t.common.cancel),
            ),
          ),
        DsListRow(
          leading: const DsIcon(DsIcons.trash2),
          title: Text(t.recorder.cacheClear),
          description: Text(t.recorder.cacheClearDesc),
          destructive: true,
          trailing: DsButton(
            variant: DsButtonVariant.secondary,
            size: DsSize.sm,
            onPressed: _busy || blocked ? null : () => unawaited(_clear()),
            child: Text(t.recorder.cacheClear),
          ),
        ),
      ],
    );
  }
}

/// The window a schedule editor returns; applied to the task on Confirm.
typedef _ScheduleDraft = ({bool enabled, Set<int> days, int start, int end, bool stopAtEnd});

/// The take's schedule editor: a switch, weekday chips, two time pickers and
/// the window-end policy. A dialog because it is a short form, not a page.
final class _ScheduleDialog extends StatefulWidget {
  const _ScheduleDialog({required this.task});

  final RecordingTask task;

  @override
  State<_ScheduleDialog> createState() => _ScheduleDialogState();
}

final class _ScheduleDialogState extends State<_ScheduleDialog> {
  late bool _enabled = widget.task.scheduleEnabled;
  late Set<int> _days = widget.task.scheduleDays.toSet();
  late int _start = widget.task.scheduleStartMinutes;
  late int _end = widget.task.scheduleEndMinutes;
  late bool _stopAtEnd = widget.task.stopAtWindowEnd;

  static DsTime _timeOf(int minutes) {
    final value = minutes.clamp(0, 1439);
    return DsTime(value ~/ 60, value % 60);
  }

  void _toggleDay(int day, bool selected) {
    final next = {..._days};
    if (selected) {
      next.add(day);
    } else {
      next.remove(day);
    }
    setState(() => _days = next.isEmpty ? {1, 2, 3, 4, 5, 6, 7} : next);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final theme = DsTheme.of(context);
    final colors = DsTheme.colorsOf(context);
    return DsDialog(
      title: Text(t.recorder.scheduleTitle),
      icon: const DsIcon(DsIcons.calendarClock),
      style: const DsDialogStyle(width: 460),
      description: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: DsSpace.s16,
        children: [
          SettingsConfigRow(
            leading: const DsIcon(DsIcons.clock),
            title: t.recorder.scheduleEnableTitle,
            description: t.recorder.scheduleEnableDesc,
            control: DsSwitch(
              value: _enabled,
              onChanged: (value) => setState(() => _enabled = value),
              semanticLabel: t.recorder.scheduleEnableTitle,
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: DsSpace.s8,
            children: [
              Text(t.recorder.scheduleDaysTitle, style: theme.typography.caption.copyWith(color: colors.textMuted)),
              Wrap(
                spacing: DsSpace.s8,
                runSpacing: DsSpace.s8,
                children: [
                  for (var day = 1; day <= 7; day++)
                    DsChip(
                      label: Text(_scheduleDayLabel(t, day)),
                      selected: _days.contains(day),
                      onChanged: _enabled ? (selected) => _toggleDay(day, selected) : null,
                      semanticLabel: _scheduleDayLabel(t, day),
                    ),
                ],
              ),
              Wrap(
                spacing: DsSpace.s8,
                runSpacing: DsSpace.s8,
                children: [
                  DsButton(
                    variant: DsButtonVariant.secondary,
                    size: DsSize.sm,
                    onPressed: _enabled ? () => setState(() => _days = {1, 2, 3, 4, 5, 6, 7}) : null,
                    child: Text(t.recorder.scheduleEveryDay),
                  ),
                  DsButton(
                    variant: DsButtonVariant.secondary,
                    size: DsSize.sm,
                    onPressed: _enabled ? () => setState(() => _days = {1, 2, 3, 4, 5}) : null,
                    child: Text(t.recorder.scheduleWorkdays),
                  ),
                  DsButton(
                    variant: DsButtonVariant.secondary,
                    size: DsSize.sm,
                    onPressed: _enabled ? () => setState(() => _days = {6, 7}) : null,
                    child: Text(t.recorder.scheduleWeekend),
                  ),
                ],
              ),
            ],
          ),
          Row(
            spacing: DsSpace.s12,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: DsSpace.s4,
                  children: [
                    Text(
                      t.recorder.scheduleStartTitle,
                      style: theme.typography.caption.copyWith(color: colors.textMuted),
                    ),
                    DsTimePicker(
                      value: _timeOf(_start),
                      onChanged: _enabled ? (time) => setState(() => _start = time?.inMinutes ?? _start) : null,
                      placeholder: 'HH:mm',
                      semanticLabel: t.recorder.scheduleStartTitle,
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: DsSpace.s4,
                  children: [
                    Text(
                      t.recorder.scheduleEndTitle,
                      style: theme.typography.caption.copyWith(color: colors.textMuted),
                    ),
                    DsTimePicker(
                      value: _timeOf(_end),
                      onChanged: _enabled
                          ? (time) {
                              if (time == null) return;
                              setState(() => _end = time.inMinutes == 0 ? 1440 : time.inMinutes);
                            }
                          : null,
                      placeholder: 'HH:mm',
                      semanticLabel: t.recorder.scheduleEndTitle,
                    ),
                  ],
                ),
              ),
            ],
          ),
          Text(t.recorder.scheduleOvernightHint, style: theme.typography.caption.copyWith(color: colors.textMuted)),
          SettingsConfigRow(
            leading: const DsIcon(DsIcons.squareStop),
            title: t.recorder.scheduleStopAtEnd,
            description: t.recorder.scheduleStopAtEndDesc,
            control: DsSwitch(
              value: _stopAtEnd,
              onChanged: _enabled ? (value) => setState(() => _stopAtEnd = value) : null,
              semanticLabel: t.recorder.scheduleStopAtEnd,
            ),
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
          onPressed: () =>
              Navigator.of(context)
                  .pop((enabled: _enabled, days: _days, start: _start, end: _end, stopAtEnd: _stopAtEnd)),
          child: Text(t.common.confirm),
        ),
      ],
    );
  }
}

/// The cap editor: typed freely, committed on Confirm so a half-typed
/// "2048" never trims the folder at "2" MB.
final class _CacheLimitDialog extends StatefulWidget {
  const _CacheLimitDialog({required this.initialMb});

  final int initialMb;

  @override
  State<_CacheLimitDialog> createState() => _CacheLimitDialogState();
}

final class _CacheLimitDialogState extends State<_CacheLimitDialog> {
  late num? _draft = widget.initialMb;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    return DsDialog(
      title: Text(t.recorder.cacheLimit),
      icon: const DsIcon(DsIcons.database),
      description: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: DsSpace.s12,
        children: [
          Text(t.recorder.cacheLimitDesc),
          DsNumberField(
            value: _draft,
            min: kRecordingCacheLimitMinMb,
            max: kRecordingCacheLimitMaxMb,
            unit: 'MB',
            autofocus: true,
            semanticLabel: t.recorder.cacheLimit,
            onChanged: (value) => setState(() => _draft = value),
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
          onPressed: _draft == null ? null : () => Navigator.of(context).pop(_draft!.round()),
          child: Text(t.common.confirm),
        ),
      ],
    );
  }
}
