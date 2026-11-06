import 'dart:async' show TimeoutException, Timer, unawaited;
import 'dart:io' show File;
import 'dart:math' as math;

import 'package:desen_ui/desen_ui.dart';
import 'package:file_picker/file_picker.dart' show FilePicker, FileType;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart' show GoRouterHelper;
import 'package:live_cache/live_cache.dart' show ImageCachePolicies;
import 'package:live_sites/live_sites.dart' show LiveAudienceMetricType, LiveDanmakuProvider, LiveRoom;
import 'package:path/path.dart' as p;
import 'package:pure_live/app/app.dart';
import 'package:pure_live/features/media_preview/media_preview_item.dart';
import 'package:pure_live/features/media_preview/media_preview_page.dart';
import 'package:pure_live/features/settings/pages/wallpaper_download_manager.dart' show openDownloadedPath;
import 'package:pure_live/features/settings/settings.dart';
import 'package:pure_live/l10n/translations.dart';
import 'package:pure_live/layouts/page_head_actions.dart';
import 'package:pure_live/layouts/page_layout_scope.dart';
import 'package:pure_live/modules/live/favorites/favorites.dart';
import 'package:pure_live/modules/live/history/history.dart';
import 'package:pure_live/modules/live/recorder/data/recorder_library_filter.dart' show scopeLibraryTakes;
import 'package:pure_live/modules/live/recorder/data/recorder_platform_filter.dart';
import 'package:pure_live/modules/live/recorder/data/recorder_search_handoff.dart';
import 'package:pure_live/modules/live/recorder/data/recording_library.dart';
import 'package:pure_live/modules/live/recorder/data/recording_preview.dart';
import 'package:pure_live/modules/live/recorder/data/recording_repository.dart';
import 'package:pure_live/modules/live/recorder/data/recording_settings.dart';
import 'package:pure_live/modules/live/recorder/data/recording_task.dart';
import 'package:pure_live/modules/live/recorder/engine/recorder_engine.dart' show recorderEngineProvider;
import 'package:pure_live/modules/live/recorder/engine/stream_resolver.dart'
    show NoRecordableStream, resolveRecordableStream;
import 'package:pure_live/modules/live/recorder/pages/recorder_card_parts.dart';
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
  paused,
  failed;

  /// Whether [task] belongs under this filter.
  ///
  /// The list is subscriptions: a room stays under 等待 even after its last
  /// take was saved, because the live check keeps watching it. 已暂停 is the
  /// room whose switch is off, and 失败 is a watched room whose last take
  /// could not be made.
  bool matches(RecordingTask task) => switch (this) {
    all => true,
    recording => task.state == RecordingTaskState.recording || task.postProcessing,
    waiting =>
      task.enabled &&
          !task.postProcessing &&
          task.state != RecordingTaskState.recording &&
          task.state != RecordingTaskState.failed,
    paused => !task.enabled,
    failed => task.enabled && task.state == RecordingTaskState.failed,
  };

  /// The section's icon.
  DsIconData get icon => switch (this) {
    all || recording => DsIcons.disc3,
    waiting => DsIcons.clock,
    paused => DsIcons.pause,
    failed => DsIcons.circleAlert,
  };
}

final class _RecorderPageState extends ConsumerState<RecorderPage> {
  _RecorderFilter _filter = _RecorderFilter.all;

  /// How many rows one task page holds.
  static const int _taskPageSize = 20;

  /// The task list's shown page; a filter change starts it again.
  int _taskPage = 1;

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
    // The card keeps naming the streamer and pictures the room even after the
    // room leaves both stores: the snapshot rides on the subscription.
    final anchorName = (room.anchor?.name ?? '').trim();
    final avatarUrl = (room.anchor?.avatarUrl ?? '').trim();
    final coverUrl = room.content.coverUrl.trim();
    if (live) {
      final task =
          existing?.copyWith(
            roomTitle: room.content.title,
            quality: settings.defaultQuality,
            anchorName: anchorName,
            anchorAvatarUrl: avatarUrl,
            coverUrl: coverUrl,
            checkSeconds: settings.schedule.liveCheckSeconds,
            checkBackoff: settings.schedule.checkBackoffEnabled,
            maxCheckSeconds: settings.schedule.maxCheckSeconds,
            state: RecordingTaskState.stopped,
            startedAt: now,
          ) ??
          RecordingTask(
            id: id,
            platform: room.ref.platform,
            roomId: room.ref.roomId,
            roomTitle: room.content.title,
            quality: settings.defaultQuality,
            anchorName: anchorName,
            anchorAvatarUrl: avatarUrl,
            coverUrl: coverUrl,
            checkSeconds: settings.schedule.liveCheckSeconds,
            checkBackoff: settings.schedule.checkBackoffEnabled,
            maxCheckSeconds: settings.schedule.maxCheckSeconds,
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
          anchorName: anchorName,
          anchorAvatarUrl: avatarUrl,
          coverUrl: coverUrl,
          checkSeconds: settings.schedule.liveCheckSeconds,
          checkBackoff: settings.schedule.checkBackoffEnabled,
          maxCheckSeconds: settings.schedule.maxCheckSeconds,
          state: RecordingTaskState.waiting,
          startedAt: now,
        ) ??
        RecordingTask(
          id: id,
          platform: room.ref.platform,
          roomId: room.ref.roomId,
          roomTitle: room.content.title,
          quality: settings.defaultQuality,
          anchorName: anchorName,
          anchorAvatarUrl: avatarUrl,
          coverUrl: coverUrl,
          checkSeconds: settings.schedule.liveCheckSeconds,
          checkBackoff: settings.schedule.checkBackoffEnabled,
          maxCheckSeconds: settings.schedule.maxCheckSeconds,
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
    // One platform cuts both lists — the subscriptions here and the files
    // pane below — through the centre's own filter.
    final platformFilter = ref.watch(recorderPlatformFilterProvider);
    final listed = platformFilter == kAllPlatforms
        ? liveTasks
        : [
            for (final task in liveTasks)
              if (task.platform == platformFilter) task,
          ];
    final taskPlatforms = recorderPlatformsOf(liveTasks.map((task) => task.platform), _platformName);
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
    // What the page still owns as a task: a capture running, a room waiting to
    // go live, a session that failed, a join still going — and a saved row whose
    // file is gone, which the library cannot show and is the only way back to
    // 重新合并 or to dropping the record. The toolbar's word narrows these
    // rows in place, the search field above.
    final inset = LiveWindow.pageInset(MediaQuery.sizeOf(context).width);
    // The shell decides how the page's width reads (see PageLayoutScope).
    final narrow = PageLayoutScope.isNarrow(context);
    final attention = [
      for (final task in listed)
        if (_filter.matches(task)) task,
    ]..sort(_subscriptionOrder);
    final statusFilter = DsTabs<_RecorderFilter>(
      value: _filter,
      semanticLabel: t.recorder.filterLabel,
      // The first tab lines up with the rows under it, and the bar's hairline
      // stops with the tabs instead of running to the window's right edge.
      style: const DsTabsStyle(padding: EdgeInsets.zero, dividerColor: Color(0x00000000)),
      onChanged: (value) => setState(() {
        _filter = value;
        _taskPage = 1;
      }),
      tabs: [
        for (final filter in _RecorderFilter.values)
          DsTab(value: filter, label: Text(_filterLabel(t, filter)), count: counts[filter] ?? 0),
      ],
    );
    // The files page's toolbar answers for this module's half of the shared
    // tree, so the takes it counts and filters are the same cut the pane under
    // it lists.
    final scopedLibraryTakes = scopeLibraryTakes(
      ref.watch(recordingLibraryProvider).value ?? const <RecordingTake>[],
      excluded: const {kIptvRecordingPlatform},
    );
    final libraryTakes = platformFilter == kAllPlatforms
        ? scopedLibraryTakes
        : [
            for (final take in scopedLibraryTakes)
              if (take.platformId == platformFilter) take,
          ];
    final filePlatforms = recorderPlatformsOf(scopedLibraryTakes.map((take) => take.platformId), _platformName);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(inset, DsSpace.s16, inset, DsSpace.s12),
          // The centre's two pages on the left, the files page's own verbs on
          // the same line: the filter and the refresh narrow what is under
          // them, so they belong to the page switch rather than to a second
          // band below it.
          child: () {
            final files = ref.watch(recorderCenterTabProvider) == RecorderCenterTab.files;
            final switchRow = DsSegmentedControl<RecorderCenterTab>(
              value: ref.watch(recorderCenterTabProvider),
              onChanged: (value) => ref.read(recorderCenterTabProvider.notifier).set(value),
              segments: [
                DsSegment(value: RecorderCenterTab.tasks, label: Text(t.recorder.tabTasks)),
                DsSegment(value: RecorderCenterTab.files, label: Text(t.recorder.tabFiles)),
              ],
            );
            final toolbar = RecorderLibraryToolbar(platforms: filePlatforms, nameOf: _platformName);
            final settingsButton = DsButton(
              variant: DsButtonVariant.secondary,
              size: DsSize.sm,
              leading: const DsIcon(DsIcons.settings, size: 16),
              onPressed: _openSettings,
              child: Text(t.recorder.settingsOpen),
            );
            // A stacked toolbar hands the settings and the files verbs to the
            // shell's head line; this row keeps the page switch alone.
            if (narrow) {
              publishPageHeadActions(context, ref, NavigationItem.record, [
                DsButton.icon(
                  variant: DsButtonVariant.secondary,
                  size: DsSize.sm,
                  semanticLabel: t.recorder.settingsOpen,
                  onPressed: _openSettings,
                  icon: const DsIcon(DsIcons.settings, size: 16),
                ),
                if (files) RecorderLibraryToolbarMore(platforms: filePlatforms, nameOf: _platformName),
              ]);
              return Row(spacing: DsSpace.s8, children: [switchRow]);
            }
            return Row(spacing: DsSpace.s8, children: [switchRow, const Spacer(), if (files) toolbar, settingsButton]);
          }(),
        ),
        if (ref.watch(recorderCenterTabProvider) == RecorderCenterTab.tasks)
          Expanded(
            child: _tasksBody(
              inset: inset,
              narrow: narrow,
              statusFilter: statusFilter,
              platforms: taskPlatforms,
              nameOf: _platformName,
              attention: attention,
              total: listed.length,
              onStopAll: recording.isEmpty ? null : () => unawaited(_stopAll(recording)),
              rooms: rooms,
            ),
          )
        else ...[
          // The files page opens with its own total: the day groups below
          // say per-day counts, and the page should say what the tree holds.
          if (libraryTakes.isNotEmpty)
            Padding(
              padding: EdgeInsets.fromLTRB(inset, 0, inset, DsSpace.s8),
              child: Text(
                t.recorder.librarySummary(
                  count: libraryTakes.length,
                  size: formatRecordingBytes(libraryTakes.fold<int>(0, (sum, take) => sum + take.bytes)),
                ),
                style: theme.typography.caption.copyWith(color: colors.textMuted),
              ),
            ),
          Expanded(
            child: RecorderLibraryPane(
              showHeading: false,
              // Its verbs ride the page switch's own line, above.
              showToolbar: false,
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

  Widget _tasksBody({
    required double inset,
    required bool narrow,
    required Widget statusFilter,
    required List<String> platforms,
    required String Function(String id) nameOf,
    required List<RecordingTask> attention,
    required int total,
    required VoidCallback? onStopAll,

    required Map<String, LiveRoom> rooms,
  }) {
    final t = context.t;
    final pageCount = math.max(1, (attention.length / _taskPageSize).ceil());
    final page = _taskPage.clamp(1, pageCount);
    final shown = attention.skip((page - 1) * _taskPageSize).take(_taskPageSize).toList();
    // The rows take the page's whole width: the table spreads its columns
    // across it, and the cards read as rows of one worklist instead of a
    // column stranded in the window's left half.
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: ConstrainedBox(
        constraints: const BoxConstraints(),
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
                  RecorderPlatformFilterButton(platforms: platforms, nameOf: nameOf, compact: narrow),
                  _BatchMenu(onStopAll: onStopAll),
                ],
              ),
            ),
            // The rows this page still owns, as the file manager's table on a
            // wide window and the cards on a narrow one. This is the whole
            // tasks page now — the library below became its own page.
            Expanded(
              child: attention.isEmpty
                  ? Center(
                      child: DsEmptyState(
                        icon: const DsIcon(DsIcons.video),
                        title: Text(
                          total == 0
                              ? t.recorder.emptyTitle
                              : t.recorder.emptyFilterTitle(status: _filterLabel(t, _filter)),
                        ),
                        description: total == 0 ? Text(t.recorder.emptyDescription) : null,
                        actions: [
                          if (total == 0)
                            DsButton(
                              variant: DsButtonVariant.primary,
                              leading: const DsIcon(DsIcons.plus, size: 16),
                              onPressed: () => unawaited(
                                showRoomSearchPicker(
                                  context,
                                  query: '',
                                  title: t.recorder.addTitle,
                                  onPick: _addFromSearch,
                                ),
                              ),
                              child: Text(t.recorder.addTitle),
                            ),
                        ],
                      ),
                    )
                  : Padding(
                      padding: EdgeInsets.fromLTRB(inset, 0, inset, DsSpace.s8),
                      child: _LiveClock(
                        active: attention.any((task) => task.isRunning),
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.only(bottom: DsSpace.s8),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            spacing: DsSpace.s8,
                            children: [for (final task in shown) ..._taskCards(context, task, rooms)],
                          ),
                        ),
                      ),
                    ),
            ),
            if (attention.isNotEmpty)
              Padding(
                padding: EdgeInsets.fromLTRB(inset, DsSpace.s12, inset, DsSpace.s12),
                child: Center(
                  child: DsPagination(
                    page: page,
                    pageCount: pageCount,
                    onChanged: (next) => setState(() => _taskPage = next),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

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
        // The menu's room entry always opens the room, never the take.
        onOpenRoom: () => unawaited(openRoom(context, platform: task.platform, roomId: task.roomId)),
        onStop: engine.isRecording(task.id) ? () => unawaited(_stop(task.id)) : null,
        onToggleWatch: () => unawaited(_setWatched(task, watched: !task.enabled)),
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

  /// Turns a room's watch switch on or off. A take already running is left to
  /// its own stop: pausing decides whether the next live check begins one.
  Future<void> _setWatched(RecordingTask task, {required bool watched}) =>
      ref.read(recordingTasksProvider.notifier).setEnabled(task.id, enabled: watched);

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
    final draft = await showDsPanel<_ScheduleDraft>(
      context: context,
      builder: (context) => _RoomSettingsPanel(task: task),
    );
    if (draft == null || !mounted) return;
    final days = draft.days.toList()..sort();
    await ref
        .read(recordingTasksProvider.notifier)
        .add(
          task.copyWith(
            enabled: draft.check,
            scheduleEnabled: draft.enabled,
            scheduleDays: days.isEmpty ? const [1, 2, 3, 4, 5, 6, 7] : days,
            scheduleStartMinutes: draft.start,
            scheduleEndMinutes: draft.end,
            stopAtWindowEnd: draft.stopAtEnd,
            checkSeconds: draft.checkSeconds,
            checkBackoff: draft.checkBackoff,
            maxCheckSeconds: draft.maxCheckSeconds,
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

/// Rebuilds its child every second while a take is being written: the clock
/// and the rate move with the wall, not with the ten-second status write.
final class _LiveClock extends StatefulWidget {
  const _LiveClock({required this.active, required this.child});

  final bool active;
  final Widget child;

  @override
  State<_LiveClock> createState() => _LiveClockState();
}

final class _LiveClockState extends State<_LiveClock> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _sync();
  }

  @override
  void didUpdateWidget(_LiveClock oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.active != widget.active) _sync();
  }

  void _sync() {
    _timer?.cancel();
    _timer = widget.active
        ? Timer.periodic(const Duration(seconds: 1), (_) {
            if (mounted) setState(() {});
          })
        : null;
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// The resolution a quality name carries ("1080P", "原画 1080p"), or null when
/// the name says nothing a viewer can measure.
String? resolutionOf(String quality) {
  final match = RegExp(r'(\d{3,4})\s*[pP]').firstMatch(quality);
  return match == null ? null : '${match.group(1)}P';
}

/// Everything the card no longer draws: the take's figures, where its file is
/// and the room's check cadence. A panel on a window, a sheet on a phone.
final class _TaskDetailsPanel extends ConsumerWidget {
  const _TaskDetailsPanel({required this.task, required this.room, required this.platformName});

  final RecordingTask task;
  final LiveRoom? room;
  final String platformName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    // The switch lives here too, so the panel follows the store instead of
    // the snapshot it opened with: turning the check on outside this panel
    // must not leave this copy reading the old value.
    final task = ref.watch(
      recordingTasksProvider.select(
        (state) => state.tasks.where((item) => item.id == this.task.id).firstOrNull ?? this.task,
      ),
    );
    final liveElapsed = task.isRunning
        ? DateTime.now().difference(task.startedAt)
        : (task.durationMs > 0 ? Duration(milliseconds: task.durationMs) : Duration.zero);
    final size = task.bytes > 0 ? formatRecordingBytes(task.bytes) : t.recorder.statSavedEmpty;
    final bitrate = task.bytes > 0 && liveElapsed.inSeconds > 0 ? formatRecordingBitrate(task.bytes, liveElapsed) : '—';
    final fps = task.frameRate > 0 ? task.frameRate : task.liveFps;
    // One line: the pixel size, then the rate. "1920 × 1080" beside
    // "1080P 60 FPS" repeated the height and wrapped in the middle of a
    // number.
    final spec = task.videoWidth > 0 && task.videoHeight > 0
        ? '${task.videoWidth}×${task.videoHeight}${fps > 0 ? ' · ${fps.round()} FPS' : ''}'
        : (resolutionOf(task.quality) ?? (task.quality.isNotEmpty ? task.quality : t.recorder.qualityBest));
    final codec = [
      if (task.videoCodec.isNotEmpty) task.videoCodec.toUpperCase(),
      if (task.audioCodec.isNotEmpty) task.audioCodec.toUpperCase(),
    ].join(' · ');
    final saved = (task.filePath ?? '').trim();
    final section = recorderPanelSectionStyle(context);
    return DsPanel(
      title: Text(t.recorder.detailsTitle),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: DsSpace.s16,
        children: [
          DsListSection(
            style: section,
            header: Text(t.recorder.detailsMetrics),
            children: [
              DsListRow(
                title: Text(t.recorder.columnDuration),
                detail: Text(liveElapsed > Duration.zero ? formatRecordingDuration(liveElapsed) : '—'),
              ),
              DsListRow(title: Text(t.recorder.columnBitrate), detail: Text(bitrate)),
              DsListRow(title: Text(t.recorder.statProfile), detail: Text(spec)),
              if (codec.isNotEmpty) DsListRow(title: Text(t.recorder.statCodec), detail: Text(codec)),
              DsListRow(
                title: Text(t.recorder.statSaved),
                detail: Text(savingNote(task: task, size: size, empty: t.recorder.statSavedEmpty)),
              ),
              if (task.droppedFrames > 0)
                DsListRow(
                  title: Text(t.recorder.stateRecording),
                  detail: Text(t.recorder.droppedFramesNote(count: task.droppedFrames)),
                ),
            ],
          ),
          DsListSection(
            style: section,
            header: Text(t.recorder.detailsLocation),
            children: [
              DsListRow(
                title: Text(t.recorder.saveLocation),
                detail: Text(saved.isEmpty ? t.recorder.saveDirTitle : saved),
                trailing: saved.isEmpty
                    ? null
                    : DsButton.icon(
                        variant: DsButtonVariant.ghost,
                        size: DsSize.sm,
                        onPressed: () => unawaited(
                          openDownloadedPath(context, p.dirname(saved), failedTitle: t.recorder.openFolderFailed),
                        ),
                        icon: const DsIcon(DsIcons.folderOpen, size: 16),
                        semanticLabel: t.recorder.openFolder,
                      ),
              ),
              if (task.endedAt != null || task.bytes > 0)
                DsListRow(
                  title: Text(t.recorder.statLatest),
                  detail: Text(t.recorder.lastRecordingAt(time: formatRecordingMoment(task.endedAt ?? task.startedAt))),
                ),
            ],
          ),
          DsListSection(
            style: section,
            header: Text(t.recorder.liveCheckGroup),
            children: [
              DsListRow(
                title: Text(t.recorder.roomCheckTitle),
                trailing: DsSwitch(
                  value: task.enabled,
                  onChanged: (value) =>
                      unawaited(ref.read(recordingTasksProvider.notifier).setEnabled(task.id, enabled: value)),
                  semanticLabel: t.recorder.roomCheckTitle,
                ),
              ),
              DsListRow(
                title: Text(t.recorder.liveCheckSecondsTitle),
                detail: Text(t.recorder.checkEvery(seconds: task.checkSeconds)),
              ),
              DsListRow(
                title: Text(t.recorder.statProfile),
                detail: Text(task.quality.isNotEmpty ? task.quality : t.recorder.qualityBest),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// How the saved file reads in the panel: its size, then the container and the
/// segment count while the take is still being written.
String savingNote({required RecordingTask task, required String size, required String empty}) {
  final container = task.container.toUpperCase();
  if (task.bytes <= 0) return empty;
  if (task.isRunning && task.segments > 0) return '$size · $container · ${task.segments}';
  return container.isEmpty ? size : '$size · $container';
}

/// The length a row can speak for: media time once the engine reports it,
/// and the wall clock since the start while the take is still writing — a
/// running session's size and rate have to read before the first report.
Duration recordingElapsed(RecordingTask task) {
  final recorded = Duration(milliseconds: task.durationMs);
  if (!task.isRunning || recorded > Duration.zero) return recorded;
  return DateTime.now().difference(task.startedAt);
}

/// The list's order: a room being recorded first, then a room being finished,
/// then the ones waiting for their next live stream, then a failed last take,
/// and the paused rooms last. Ties keep the newest session on top.
int _subscriptionOrder(RecordingTask a, RecordingTask b) {
  int rank(RecordingTask task) {
    if (task.postProcessing || task.state == RecordingTaskState.recording) return 0;
    if (!task.enabled) return 3;
    if (task.state == RecordingTaskState.failed) return 2;
    return 1;
  }

  final byRank = rank(a).compareTo(rank(b));
  return byRank != 0 ? byRank : b.startedAt.compareTo(a.startedAt);
}

/// A filter's word, without its count.
String _filterLabel(Translations t, _RecorderFilter filter) => switch (filter) {
  _RecorderFilter.all => t.recorder.filterAll,
  _RecorderFilter.recording => t.recorder.filterRecording,
  _RecorderFilter.waiting => t.recorder.filterWaiting,
  _RecorderFilter.paused => t.recorder.filterPaused,
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
final class _TaskCard extends ConsumerWidget {
  const _TaskCard({
    required this.task,
    required this.room,
    required this.platformName,
    required this.onOpen,
    required this.onOpenRoom,
    required this.onDelete,
    required this.onSchedule,
    required this.onToggleWatch,
    this.onStop,
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

  /// The card's own press: plays the take, or opens the room when there is
  /// nothing playable to open.
  final VoidCallback onOpen;

  /// Opens the room the task records, whatever the take's state.
  final VoidCallback onOpenRoom;

  /// Drops the task (the menu has confirmed it).
  final VoidCallback onDelete;

  /// Opens the take's schedule editor.
  final VoidCallback onSchedule;

  /// Stops a running capture, null when the task is not being recorded.
  final VoidCallback? onStop;

  /// Pauses or resumes the room's watch switch.
  final VoidCallback onToggleWatch;

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
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    final theme = DsTheme.of(context);
    final colors = DsTheme.colorsOf(context);
    final platformIcon = localizedSiteIcon(ref.watch(sitesProvider).getById(task.platform), size: 14);
    // The live stores win; the snapshot stored with the subscription answers
    // when the room is in neither of them, so the card always names the
    // streamer and pictures the room.
    final liveAnchor = (room?.anchor?.name ?? '').trim();
    final storedTitle = task.roomTitle.trim();
    final liveTitle = (room?.content.title ?? '').trim();
    final title = storedTitle.isNotEmpty ? storedTitle : (liveTitle.isNotEmpty ? liveTitle : task.roomId);
    final anchor = liveAnchor.isNotEmpty ? liveAnchor : task.anchorName.trim();
    final liveAvatar = (room?.anchor?.avatarUrl ?? '').trim();
    final avatarUrl = liveAvatar.isNotEmpty ? liveAvatar : task.anchorAvatarUrl.trim();
    final liveCover = (room?.content.coverUrl ?? '').trim();
    final cover = liveCover.isNotEmpty ? liveCover : task.coverUrl.trim();
    // Media time is what the take captured; a session that has not reported
    // yet falls back to the wall clock, so the length, the size and the rate
    // read while it is still writing.
    final recorded = Duration(milliseconds: task.durationMs);
    final elapsed = task.isRunning && recorded == Duration.zero ? DateTime.now().difference(task.startedAt) : recorded;
    // A room that has already recorded keeps its last take's moment on the
    // card; a fresh subscription has none to name.
    final lastRun = task.isRunning || (task.endedAt == null && task.bytes == 0)
        ? ''
        : t.recorder.lastRecordingAt(time: formatRecordingMoment(task.endedAt ?? task.startedAt));
    final processing = task.postProcessing;
    final fileDeleted = _fileDeleted;
    final recording = task.isRunning && !processing;
    final failed = task.enabled && task.state == RecordingTaskState.failed && !processing;
    final paused = !task.enabled && !processing;
    final area = (room?.area?.areaName ?? '').trim();
    // A title that opens with a bracket starts half an em in; the caption
    // under it starts at the box's edge, so it takes the same blank to read
    // as one left edge with the title.
    final category = [area, anchor].where((part) => part.isNotEmpty).join(' · ');
    final categoryHang = recorderPunctuationHang(title, theme.typography.heading.fontSize ?? 14);
    final liveElapsed = task.isRunning ? DateTime.now().difference(task.startedAt) : elapsed;
    final segmentSeconds = ref.watch(recordingSettingsProvider).segmentSeconds;
    final segmentMinutes = segmentSeconds <= 0 ? 0 : (segmentSeconds / 60).ceil();
    final segment = liveElapsed <= Duration.zero || segmentMinutes <= 0
        ? ''
        : t.recorder.segmentProgress(count: liveElapsed.inSeconds ~/ segmentSeconds + 1, minutes: segmentMinutes);
    final statusText = processing
        ? t.recorder.stateProcessing
        : recording
        ? t.recorder.stateRecording
        : failed
        ? t.recorder.stateFailed
        : paused
        ? t.recorder.statePaused
        : fileDeleted
        ? t.recorder.stateFileDeleted
        : t.recorder.stateWaiting;
    final statusTone = processing
        ? DsStatus.info
        : recording || failed
        ? DsStatus.danger
        : paused || fileDeleted
        ? DsStatus.neutral
        : DsStatus.warning;
    final statusNote = recording
        ? segment
        : (lastRun.isNotEmpty ? lastRun : (fileDeleted ? t.recorder.warningFileDeleted : ''));
    final audience = _audienceOf(room);
    final tags = [
      if (task.quality.isNotEmpty) task.quality else t.recorder.qualityBest,
      if (audience.isNotEmpty) audience,
      if (task.videoCodec.isNotEmpty) task.videoCodec.toUpperCase(),
      '${t.recorder.roomArea} ${task.roomId}',
    ];
    final Widget action = processing
        ? DsButton(
            variant: DsButtonVariant.secondary,
            size: DsSize.sm,
            leading: const DsIcon(DsIcons.x, size: 14),
            onPressed: onCancelProcessing,
            child: Text(t.recorder.cancelProcessing),
          )
        : recording
        ? DsButton(
            variant: DsButtonVariant.secondary,
            size: DsSize.sm,
            leading: const DsIcon(DsIcons.squareStop, size: 14),
            onPressed: onStop,
            child: Text(t.recorder.stop),
          )
        : failed
        ? DsButton(
            variant: DsButtonVariant.primary,
            size: DsSize.sm,
            leading: const DsIcon(DsIcons.refreshCw, size: 14),
            onPressed: onStartNow,
            child: Text(t.common.retry),
          )
        : DsButton(
            variant: DsButtonVariant.primary,
            size: DsSize.sm,
            leading: const DsIcon(DsIcons.play, size: 14),
            onPressed: onStartNow,
            child: Text(t.recorder.startRecording),
          );
    final saved = (task.filePath ?? '').trim();
    return DsCard(
      onPressed: onOpen,
      semanticLabel: title,
      style: DsCardStyle(
        padding: const EdgeInsets.all(DsSpace.s16),
        borderRadius: BorderRadius.circular(theme.radii.card),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final (coverWidth, coverHeight) = width >= 560 ? (132.0, 74.0) : (96.0, 54.0);
          Widget watch() => Row(
            mainAxisSize: MainAxisSize.min,
            spacing: DsSpace.s8,
            children: [
              Text(t.recorder.roomCheckTitle, style: theme.typography.caption.copyWith(color: colors.textMuted)),
              DsSwitch(
                value: task.enabled,
                onChanged: (value) => onToggleWatch(),
                semanticLabel: t.recorder.roomCheckTitle,
              ),
            ],
          );
          Widget details() => DsButton(
            variant: DsButtonVariant.secondary,
            size: DsSize.sm,
            leading: const DsIcon(DsIcons.info, size: 14),
            onPressed: () => unawaited(
              showDsPanel<void>(
                context: context,
                builder: (context) => _TaskDetailsPanel(task: task, room: room, platformName: platformName),
              ),
            ),
            child: Text(t.recorder.details),
          );
          Widget play() => DsButton(
            variant: DsButtonVariant.secondary,
            size: DsSize.sm,
            leading: const DsIcon(DsIcons.playCircle, size: 14),
            onPressed: onPreview ?? onPlayExternal,
            child: Text(t.recorder.playRecording),
          );
          Widget menu() => _TaskMenu(
            task: task,
            hasFile: saved.isNotEmpty,
            onOpenRoom: onOpenRoom,
            onStop: onStop,
            onDelete: onDelete,
            onSchedule: onSchedule,
            onCancelProcessing: onCancelProcessing,
            onRetryJoin: onRetryJoin,
          );
          final badge = DsBadge(label: Text(statusText), status: statusTone);
          final note = statusNote.isEmpty
              ? null
              : Text(
                  statusNote,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.typography.caption.copyWith(color: colors.textSubtle),
                );
          // Three verbs and the menu in two rows of two, the phase's own
          // verb first: what the row does leads, what it shows follows.
          Widget cell(Widget child) => SizedBox(width: 112, child: child);
          // The rows shrink to their cells so the block can be held to the
          // card's right edge on a narrow window; a max-width row would fill
          // the row and pack the cells at its start instead.
          final controls = Column(
            mainAxisSize: MainAxisSize.min,
            spacing: DsSpace.s8,
            children: [
              Row(mainAxisSize: MainAxisSize.min, spacing: DsSpace.s8, children: [cell(action), cell(details())]),
              Row(mainAxisSize: MainAxisSize.min, spacing: DsSpace.s8, children: [cell(play()), cell(menu())]),
            ],
          );
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: DsSpace.s12,
            children: [
              Row(
                spacing: DsSpace.s16,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: DsImage(
                      image: cover.isEmpty ? null : cachedImage(cover, policy: ImageCachePolicies.videoCover),
                      width: coverWidth,
                      height: coverHeight,
                      semanticLabel: title,
                      fallback: _CoverFallback(letter: platformLetter(task.platform)),
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      spacing: DsSpace.s4,
                      children: [
                        // The avatar, the title and the room's own category on
                        // one line; the tags that describe the room follow
                        // underneath it.
                        Row(
                          spacing: DsSpace.s8,
                          children: [
                            DsAvatar(
                              initials: avatarInitials(anchor.isEmpty ? title : anchor),
                              image: avatarUrl.isEmpty
                                  ? null
                                  : cachedImage(avatarUrl, policy: ImageCachePolicies.avatar),
                              size: DsSize.sm,
                              semanticLabel: anchor.isEmpty ? title : anchor,
                            ),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                spacing: 1,
                                children: [
                                  Text(
                                    title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: theme.typography.heading.copyWith(color: colors.text),
                                  ),
                                  if (category.isNotEmpty)
                                    Padding(
                                      padding: EdgeInsetsDirectional.only(start: categoryHang),
                                      child: Text(
                                        category,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: theme.typography.caption.copyWith(color: colors.textMuted),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        Wrap(
                          spacing: DsSpace.s6,
                          runSpacing: DsSpace.s4,
                          children: [
                            RecorderTagChip(text: platformName, icon: platformIcon),
                            for (final tag in tags) RecorderTagChip(text: tag),
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (width >= 620) ...[const SizedBox(width: DsSpace.s16), controls],
                ],
              ),
              // The state, the note and the watch switch share one line, so
              // the switch sits level with the badge and the last-take note.
              Row(
                spacing: DsSpace.s8,
                children: [
                  badge,
                  if (note != null) Expanded(child: note) else const Spacer(),
                  watch(),
                ],
              ),
              // A narrow card puts the verbs under the state line, held to the
              // card's right edge instead of stretching across it.
              if (width < 620) Row(mainAxisAlignment: MainAxisAlignment.end, children: [controls]),
              if (task.state == RecordingTaskState.recording && onStop == null)
                Text(
                  t.recorder.stateRecordingElsewhere,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.typography.caption.copyWith(color: colors.warning.text),
                )
              else if (task.state == RecordingTaskState.failed && task.errorText.trim().isNotEmpty)
                Text(
                  task.errorText.trim(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.typography.caption.copyWith(color: colors.danger.text),
                )
              else if (!processing && task.warning.isNotEmpty)
                Text(
                  _warningLabel(t, task.warning),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.typography.caption.copyWith(color: colors.warning.text),
                ),
              if (processing) ...[
                DsProgressBar(
                  value: task.postProcessingProgress >= 0 ? task.postProcessingProgress.clamp(0.0, 1.0) : null,
                  semanticLabel: t.recorder.stateProcessing,
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  /// Whether the take's file was deleted from the preview: a settled row
  /// whose recording is gone reads as that, not as saved.
  bool get _fileDeleted => task.state == RecordingTaskState.stopped && task.warning == 'file-deleted';

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
  const _BatchMenu({this.onStopAll});

  /// Stops the captures now running; null when none are.
  final VoidCallback? onStopAll;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final theme = DsTheme.of(context);
    final colors = DsTheme.colorsOf(context);
    if (onStopAll == null) return const SizedBox.shrink();
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
      ],
    );
  }
}

/// The card's "⋮" menu: the room, the saved file's folder (when the task
/// has one), the room's settings and the confirmed delete, with the running
/// session's own verbs in between.
final class _TaskMenu extends StatelessWidget {
  const _TaskMenu({
    required this.task,
    required this.hasFile,
    required this.onOpenRoom,
    required this.onDelete,
    required this.onSchedule,
    this.onStop,
    this.onCancelProcessing,
    this.onRetryJoin,
  });

  final RecordingTask task;

  /// Whether the task has a saved file (so a folder to open).
  final bool hasFile;

  /// Opens the room the task records.
  final VoidCallback onOpenRoom;

  final VoidCallback onDelete;
  final VoidCallback onSchedule;

  /// Stops a running capture, null when the task is not being recorded.
  final VoidCallback? onStop;

  /// Cancels a running join/transcode, null when there is none.
  final VoidCallback? onCancelProcessing;

  /// Re-runs the post-recording steps on a take the app never finished, null
  /// while the task is being captured or finished.
  final VoidCallback? onRetryJoin;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    return DsMenuAnchor(
      semanticLabel: t.recorder.menuMore,
      align: DsAlign.end,
      builder: (context, controller, child) => DsButton(
        variant: DsButtonVariant.secondary,
        size: DsSize.sm,
        semanticLabel: t.recorder.menuMore,
        leading: const DsIcon(DsIcons.chevronDown, size: 14),
        onPressed: controller.toggle,
        child: Text(t.common.more),
      ),
      items: [
        DsMenuItem(
          leading: const DsIcon(DsIcons.externalLink),
          label: Text(t.recorder.openRoom),
          onPressed: onOpenRoom,
        ),
        if (hasFile)
          DsMenuItem(
            leading: const DsIcon(DsIcons.folderOpen),
            label: Text(t.recorder.openFolder),
            onPressed: () => unawaited(_openFolder(context)),
          ),
        DsMenuItem(leading: const DsIcon(DsIcons.settings), label: Text(t.navigation.settings), onPressed: onSchedule),
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

String _scheduleDayLabel(Translations t, int day) => switch (day) {
  1 => t.recorder.scheduleDayMon,
  2 => t.recorder.scheduleDayTue,
  3 => t.recorder.scheduleDayWed,
  4 => t.recorder.scheduleDayThu,
  5 => t.recorder.scheduleDayFri,
  6 => t.recorder.scheduleDaySat,
  _ => t.recorder.scheduleDaySun,
};

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
/// itself, how a capture is segmented and recovered, and the background and
/// capacity limits. The live check belongs to each room now.
enum RecordingTab {
  /// Where files land, what they are called and the file's own shape.
  files,

  /// Segmentation, timeouts and the retry walk.
  capture,

  /// Background behaviour, concurrency and the managed cache.
  runtime,
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
          child: DsTabs<RecordingTab>(
            value: _tab,
            semanticLabel: t.recorder.settingsTitle,
            style: const DsTabsStyle(padding: EdgeInsets.zero),
            onChanged: (value) => setState(() => _tab = value),
            tabs: [
              DsTab(value: RecordingTab.files, label: Text(t.recorder.settingsTabFiles)),
              DsTab(value: RecordingTab.capture, label: Text(t.recorder.settingsTabCapture)),
              DsTab(value: RecordingTab.runtime, label: Text(t.recorder.settingsTabRuntime)),
            ],
          ),
        ),
        switch (_tab) {
          RecordingTab.files => _files(context),
          RecordingTab.capture => _capture(context),
          RecordingTab.runtime => _runtime(context),
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
typedef _ScheduleDraft = ({
  bool check,
  bool enabled,
  Set<int> days,
  int start,
  int end,
  bool stopAtEnd,
  int checkSeconds,
  bool checkBackoff,
  int maxCheckSeconds,
});

/// The take's schedule editor: a switch, weekday chips, two time pickers and
/// the window-end policy. A dialog because it is a short form, not a page.
final class _RoomSettingsPanel extends StatefulWidget {
  const _RoomSettingsPanel({required this.task});

  final RecordingTask task;

  @override
  State<_RoomSettingsPanel> createState() => _RoomSettingsPanelState();
}

final class _RoomSettingsPanelState extends State<_RoomSettingsPanel> {
  late bool _enabled = widget.task.scheduleEnabled;
  late Set<int> _days = widget.task.scheduleDays.toSet();
  late int _start = widget.task.scheduleStartMinutes;
  late int _end = widget.task.scheduleEndMinutes;
  late bool _stopAtEnd = widget.task.stopAtWindowEnd;
  late bool _check = widget.task.enabled;
  late int _checkSeconds = widget.task.checkSeconds;
  late bool _checkBackoff = widget.task.checkBackoff;
  late int _maxCheckSeconds = widget.task.maxCheckSeconds;

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
    return DsPanel(
      title: Text(t.recorder.roomSettings),
      footer: Row(
        spacing: DsSpace.s8,
        children: [
          Expanded(
            child: DsButton(
              variant: DsButtonVariant.secondary,
              onPressed: () => Navigator.of(context).pop(),
              child: Text(t.common.cancel),
            ),
          ),
          Expanded(
            child: DsButton(
              onPressed: () => Navigator.of(context).pop((
                check: _check,
                enabled: _enabled,
                days: _days,
                start: _start,
                end: _end,
                stopAtEnd: _stopAtEnd,
                checkSeconds: _checkSeconds,
                checkBackoff: _checkBackoff,
                maxCheckSeconds: _maxCheckSeconds,
              )),
              child: Text(t.common.confirm),
            ),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: DsSpace.s16,
        children: [
          SettingsConfigRow(
            leading: const DsIcon(DsIcons.radar),
            title: t.recorder.roomCheckTitle,
            description: t.recorder.roomCheckDesc,
            control: DsSwitch(
              value: _check,
              onChanged: (value) => setState(() => _check = value),
              semanticLabel: t.recorder.roomCheckTitle,
            ),
          ),
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
          // The room's own live-check cadence: one weekly show and one
          // all-day room should not share an interval.
          _RecordSlider(
            icon: DsIcons.timer,
            title: t.recorder.liveCheckSecondsTitle,
            description: t.recorder.liveCheckSecondsDesc,
            detail: t.recorder.seconds(count: _checkSeconds),
            value: _checkSeconds.toDouble(),
            min: 10,
            max: 300,
            divisions: 29,
            onChanged: (value) => setState(() => _checkSeconds = value.round()),
            semanticLabel: t.recorder.liveCheckSecondsTitle,
          ),
          SettingsConfigRow(
            leading: const DsIcon(DsIcons.activity),
            title: t.recorder.checkBackoff,
            description: t.recorder.checkBackoffDesc,
            control: DsSwitch(
              value: _checkBackoff,
              onChanged: (value) => setState(() => _checkBackoff = value),
              semanticLabel: t.recorder.checkBackoff,
            ),
          ),
          if (_checkBackoff)
            _RecordSlider(
              icon: DsIcons.hourglass,
              title: t.recorder.maxCheckSecondsTitle,
              description: t.recorder.maxCheckSecondsDesc,
              detail: t.recorder.seconds(count: _maxCheckSeconds),
              value: _maxCheckSeconds.toDouble(),
              min: 60,
              max: 3600,
              divisions: 59,
              onChanged: (value) => setState(() => _maxCheckSeconds = (value / 60).round() * 60),
              semanticLabel: t.recorder.maxCheckSecondsTitle,
            ),
        ],
      ),
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
