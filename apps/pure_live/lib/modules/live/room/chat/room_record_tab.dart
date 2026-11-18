import 'dart:async' show Timer, unawaited;
import 'dart:math' as math;

import 'package:desen_ui/desen_ui.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:live_sites/live_sites.dart' show LiveRoom;
import 'package:pure_live/app/app.dart' show SettingsSectionRoute, sitesProvider;
import 'package:pure_live/features/settings/pages/wallpaper_download_manager.dart' show openDownloadedPath;
import 'package:pure_live/features/settings/settings.dart' show SettingsSection, openSettingsSection;
import 'package:pure_live/l10n/translations.dart';
import 'package:pure_live/modules/live/recorder/recorder.dart';
import 'package:pure_live/modules/live/room/controller/room_controller.dart' show roomProvider;
import 'package:pure_live/modules/live/room/page/player_surface.dart' show toggleRoomRecording;
import 'package:pure_live/shared/player/recording_indicator.dart' show RecordingIndicator;
import 'package:pure_live/shared/shared.dart' show AppPanel, localizedSiteName, showAppPanel;
import 'package:pure_live/shared/widgets/app_dialog.dart' show showAppConfirm;

/// The room's own recording panel: what this room's capture is doing and
/// what it has already written, with the verbs on both — start and stop and
/// play right here, so managing this room's takes never means leaving the
/// room.
///
/// The panel splits into two panes under one segmented switch: 录制 drives
/// the capture (the transport card and the record-when-live card), 录制文件
/// shelves the finished takes as thumbnail rows with their own verbs —
/// play, the take's folder, delete — on each row. The settings page sits in
/// the top row where any amount of content cannot push it away.
///
/// The figures come from the task store, which the engine writes once a second
/// while bytes move. The clock is the exception and ticks on its own: a number
/// that only changes when the file grows reads as frozen on a stream that is
/// merely buffering, and a viewer who thinks a capture stopped will stop it.
final class RoomRecordTab extends ConsumerStatefulWidget {
  /// The panel.
  const RoomRecordTab({super.key});

  @override
  ConsumerState<RoomRecordTab> createState() => _RoomRecordTabState();
}

/// The panel's two panes: the capture the room is driving, and the files it
/// has already written — separate views, because a shelf of takes reads as
/// inventory and a running capture reads as control, and one long scroll
/// made the second wait behind the first.
enum _RoomPane { live, files }

final class _RoomRecordTabState extends ConsumerState<RoomRecordTab> with SingleTickerProviderStateMixin {
  Timer? _tick;
  bool _ticking = false;
  _RoomPane _pane = _RoomPane.live;
  // The live dot breathes: a fixed red circle reads as a label, a breathing
  // one reads as on air — every recorder's REC dot does this, and the eye
  // has learned to look for the pulse.
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
    lowerBound: 0.35,
  )..repeat(reverse: true);

  @override
  void dispose() {
    _tick?.cancel();
    _pulse.dispose();
    super.dispose();
  }

  /// Runs the one-second repaint only while a take is being captured; a waiting
  /// or finished room has nothing to count and buys no timer.
  void _syncTicker({required bool running}) {
    if (running == _ticking) return;
    _ticking = running;
    _tick?.cancel();
    _tick = null;
    if (!running) return;
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  /// Starts or stops this room's capture — the player bar's own verb.
  void _toggle() => unawaited(toggleRoomRecording(context, ref));

  @override
  Widget build(BuildContext context) {
    final room = ref.watch(roomProvider.select((state) => state.room));
    final task = room == null
        ? null
        : ref
              .watch(recordingTasksProvider)
              .tasks
              .where((candidate) => candidate.id == '${room.ref.platform}:${room.ref.roomId}')
              .firstOrNull;
    final recording = task != null && task.state == RecordingTaskState.recording;
    final waiting = task?.state == RecordingTaskState.waiting;
    _syncTicker(running: recording);

    return Column(
      children: [
        // The switch and the settings share the top row: both verbs stay
        // reachable no matter how long either pane's content runs — a
        // hundred files never push them below the fold again.
        Padding(
          padding: const EdgeInsets.fromLTRB(DsSpace.s16, DsSpace.s12, DsSpace.s16, 0),
          child: Row(
            spacing: DsSpace.s8,
            children: [
              Expanded(
                child: DsSegmentedControl<_RoomPane>(
                  value: _pane,
                  onChanged: (pane) => setState(() => _pane = pane),
                  segments: [
                    DsSegment(value: _RoomPane.live, label: Text(context.t.room.tabRecording)),
                    DsSegment(value: _RoomPane.files, label: Text(context.t.room.recordFilesPane)),
                  ],
                ),
              ),
              _settingsButton(),
            ],
          ),
        ),
        Expanded(
          child: _pane == _RoomPane.live
              ? ListView(
                  padding: const EdgeInsets.all(DsSpace.s16),
                  children: [
                    _statusCard(task: task),
                    const SizedBox(height: DsSpace.s12),
                    _autoRecordCard(room: room, task: task, waiting: waiting, recording: recording),
                  ],
                )
              : _filesPane(room: room),
        ),
      ],
    );
  }

  /// The recorder's settings page — quality, segments, schedule shape — as a
  /// top-bar verb: the section's own page, not a walk through the library.
  Widget _settingsButton() {
    final t = context.t;
    return DsButton(
      variant: DsButtonVariant.ghost,
      size: DsSize.sm,
      onPressed: () {
        openSettingsSection(ref, SettingsSection.recording);
        unawaited(context.push(SettingsSectionRoute(section: SettingsSection.recording.name).location));
      },
      leading: const DsIcon(DsIcons.settings, size: 15),
      child: Text(t.recorder.settingsOpen),
    );
  }

  /// The capture's own card, built like a recorder's transport: the state
  /// line on top (a breathing dot when on air), the elapsed clock as the
  /// hero figure with its size·rate line under it, the session's facts as
  /// label:value tiles, and the start/stop verb as one full-width block at
  /// the bottom — the recorder-page pattern (OBS's own Start Recording
  /// block): the verb is a destination, not a chip at the end of a row.
  Widget _statusCard({required RecordingTask? task}) {
    final t = context.t;
    final theme = DsTheme.of(context);
    final colors = DsTheme.colorsOf(context);
    final recording = task != null && task.state == RecordingTaskState.recording;
    // The take's segments are being joined into its file: neither recording
    // nor stopped, and the state words say so where the raw state cannot.
    final joining = task?.postProcessing ?? false;
    final (word, tone) = task == null
        ? (t.recorder.stateIdle, DsStatus.neutral)
        : joining
        ? (t.recorder.stateProcessing, DsStatus.info)
        : switch (task.state) {
            RecordingTaskState.recording => (t.recorder.stateRecording, DsStatus.danger),
            RecordingTaskState.waiting => (t.recorder.stateWaiting, DsStatus.neutral),
            RecordingTaskState.stopped => (t.recorder.stateStopped, DsStatus.success),
            RecordingTaskState.failed => (t.recorder.stateFailed, DsStatus.warning),
          };
    final elapsed = recording ? DateTime.now().difference(task.startedAt) : null;
    // The take's own average rather than the stream's instantaneous rate: the
    // store keeps bytes and media time and no live bitrate, which is all a
    // recording can honestly answer with. Media time over the wall clock: a
    // stalled stream writes fewer bytes than the clock says, and the average
    // should say what landed. Zero bytes answers nothing, on a waiting room
    // as on a just-started take.
    final mediaTime = Duration(milliseconds: task?.durationMs ?? 0);
    final bitrate = task == null
        ? ''
        : formatRecordingBitrate(
            task.bytes,
            mediaTime > Duration.zero ? mediaTime : DateTime.now().difference(task.startedAt),
          );
    // What the clock's line already says is not repeated in the tiles: size
    // and rate ride under the hero figure, the tiles hold the per-take facts
    // a viewer checks once — quality, danmaku, resolution, segments. A live
    // danmaku count only while the capture runs; a take recorded without a
    // chat file says nothing about one — "0 条" would read as a capture that
    // lost every line.
    final tiles = <(String, String)>[
      if (task != null) (t.room.recordLabelQuality, task.quality.isEmpty ? t.recorder.qualityBest : task.quality),
      if (recording) (t.room.recordLabelDanmaku, '${ref.read(recorderEngineProvider).chatEntries(task.id)}'),
      if (task != null && task.videoWidth > 0 && task.videoHeight > 0)
        (t.room.recordLabelResolution, '${task.videoWidth}×${task.videoHeight}'),
      if (recording) (t.room.recordLabelSegment, t.room.recordSegmentN(index: task.segments < 1 ? 1 : task.segments)),
      if (!recording && task != null && task.bytes > 0) (t.room.recordLabelSize, formatRecordingBytes(task.bytes)),
    ];

    return DsListSection(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: DsSpace.s12, vertical: DsSpace.s12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: DsSpace.s8,
            children: [
              // The state line: dot and word, the word in the status's own
              // color while on air — red is not decoration here, it is the
              // recorder's oldest signal.
              Row(
                spacing: DsSpace.s8,
                children: [
                  _statusDot(tone: tone, recording: recording, colors: colors),
                  Text(
                    word,
                    style: theme.typography.heading.copyWith(color: recording ? colors.status(tone).text : colors.text),
                  ),
                ],
              ),
              if (elapsed != null) ...[
                Text(
                  RecordingIndicator.formatElapsed(elapsed),
                  style: theme.typography.numeric(
                    theme.typography.display.copyWith(color: colors.text, fontWeight: FontWeight.w600, height: 1.1),
                  ),
                ),
                // The clock's companion line: what the take has landed so
                // far, said in the same breath as the time it took.
                if (recording && (task.bytes > 0 || bitrate.isNotEmpty))
                  Text(
                    [
                      if (recording && task.bytes > 0) formatRecordingBytes(task.bytes),
                      if (bitrate.isNotEmpty) bitrate,
                    ].join('  ·  '),
                    style: theme.typography.small.copyWith(color: colors.textMuted),
                  ),
              ],
              if (task?.state == RecordingTaskState.waiting)
                Text(
                  t.room.recordCheckEvery(seconds: ref.read(recordingSettingsProvider).schedule.liveCheckSeconds),
                  style: theme.typography.small.copyWith(color: colors.textMuted),
                ),
              if (tiles.isNotEmpty)
                for (final row in _chunk(tiles)) ...[
                  Row(
                    spacing: DsSpace.s8,
                    children: [
                      Expanded(child: _factTile(row.first, theme, colors)),
                      if (row.length > 1) Expanded(child: _factTile(row.last, theme, colors)),
                      // A trailing lone tile keeps its half width, so the
                      // grid reads as a grid rather than stretching to fill.
                      if (row.length == 1) const Expanded(child: SizedBox()),
                    ],
                  ),
                ],
              const SizedBox(height: DsSpace.s4),
              SizedBox(
                width: double.infinity,
                child: DsButton(
                  variant: recording ? DsButtonVariant.danger : DsButtonVariant.primary,
                  size: DsSize.lg,
                  leading: DsIcon(recording ? DsIcons.squareStop : DsIcons.disc, size: 16),
                  onPressed: joining ? null : _toggle,
                  child: Text(recording ? t.room.stopRecording : t.room.recordStarted),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// The state dot: the status's own signal color, breathing while the
  /// capture runs — on air is something the eye should catch peripherally.
  Widget _statusDot({required DsStatus tone, required bool recording, required DsColors colors}) {
    final color = colors.status(tone).signal;
    if (!recording) {
      return Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(4)),
      );
    }
    return AnimatedBuilder(
      animation: _pulse,
      builder: (context, _) => Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(
          color: color.withValues(alpha: _pulse.value),
          borderRadius: BorderRadius.circular(4),
          boxShadow: [BoxShadow(color: color.withValues(alpha: _pulse.value * 0.45), blurRadius: 8, spreadRadius: 1)],
        ),
      ),
    );
  }

  /// One fact tile: the label muted and small above the value plain and
  /// strong — a place to look up, not a sentence to read.
  Widget _factTile((String, String) fact, DsThemeData theme, DsColors colors) {
    final (label, value) = fact;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: DsSpace.s12, vertical: DsSpace.s8),
      decoration: DsBoxDecoration(
        color: colors.control,
        borderRadius: BorderRadius.circular(theme.radii.nested(theme.radii.card, DsSpace.s5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 2,
        children: [
          Text(label, style: theme.typography.caption.copyWith(color: colors.textSubtle)),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.typography.labelStrong.copyWith(color: colors.text),
          ),
        ],
      ),
    );
  }

  /// Splits the facts into rows of two, order kept.
  Iterable<List<(String, String)>> _chunk(List<(String, String)> facts) sync* {
    for (var i = 0; i < facts.length; i += 2) {
      yield facts.sublist(i, math.min(i + 2, facts.length));
    }
  }

  /// The schedule card: record when live, with the cadence it will run at —
  /// armed or not, the description names what the switch does, so an off
  /// switch still advertises its own meaning.
  Widget _autoRecordCard({
    required LiveRoom? room,
    required RecordingTask? task,
    required bool waiting,
    required bool recording,
  }) {
    if (room == null) return const SizedBox.shrink();
    final t = context.t;
    final seconds = ref.watch(recordingSettingsProvider).schedule.liveCheckSeconds;
    return DsListSection(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: DsSpace.s12, vertical: DsSpace.s8),
          child: DsSwitch(
            value: waiting,
            onChanged: recording ? null : (_) => unawaited(toggleRoomAutoRecord(context, ref, room, task)),
            label: Text(t.room.autoRecordOn),
            description: Text(waiting ? t.room.autoRecordArmed(seconds: seconds) : t.room.autoRecordHint),
          ),
        ),
      ],
    );
  }

  /// The files pane: this room's finished takes, newest first, each a
  /// thumbnail row with its own verbs — play, the take's folder, delete —
  /// so a file is managed where it is listed, not after a trip elsewhere.
  Widget _filesPane({required LiveRoom? room}) {
    final t = context.t;
    final theme = DsTheme.of(context);
    final colors = DsTheme.colorsOf(context);
    final platform = room?.ref.platform;
    final roomId = room?.ref.roomId;
    final takesAsync = ref.watch(recordingLibraryProvider);
    final takes = [
      for (final take in takesAsync.value ?? const <RecordingTake>[])
        if (take.playable && platform != null && take.platformId == platform && take.roomId == roomId) take,
    ];
    return ListView(
      padding: const EdgeInsets.all(DsSpace.s16),
      children: [
        if (takes.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: DsSpace.s8),
            child: Text(
              t.room.roomRecordTakes(count: takes.length),
              style: theme.typography.overline.copyWith(color: colors.textSubtle),
            ),
          ),
        if (takes.isEmpty)
          DsEmptyState(icon: const DsIcon(DsIcons.video), title: Text(t.room.roomRecordTakesEmpty))
        else
          DsListSection(
            style: recorderPanelSectionStyle(context),
            children: [for (final take in takes) _takeRow(take, takes)],
          ),
      ],
    );
  }

  /// One finished take: the frame the backend cut from the file, the take's
  /// title and the day it was taken beside it, its weight at the end — the
  /// whole row opens the preview, and the row's end carries the file verbs:
  /// the take's folder, and delete with its confirmation.
  Widget _takeRow(RecordingTake take, List<RecordingTake> around) {
    final t = context.t;
    final theme = DsTheme.of(context);
    final colors = DsTheme.colorsOf(context);
    final bytes = take.bytes > 0 ? formatRecordingBytes(take.bytes) : null;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => unawaited(playRecordingTake(context, ref, around: around, take: take, platformName: _platformName)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: DsSpace.s12, vertical: DsSpace.s8),
        child: Row(
          spacing: DsSpace.s8,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: RecorderTakeCover(take: take, width: 96, height: 54),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: 2,
                children: [
                  Text(
                    take.roomTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.typography.labelStrong.copyWith(color: colors.text),
                  ),
                  Text(
                    formatRecordingMoment(take.takenAt),
                    style: theme.typography.caption.copyWith(color: colors.textMuted),
                  ),
                ],
              ),
            ),
            if (bytes != null) Text(bytes, style: theme.typography.caption.copyWith(color: colors.textSubtle)),
            _rowAction(
              icon: DsIcons.folder,
              tooltip: t.recorder.openFolder,
              onTap: () => unawaited(openDownloadedPath(context, take.folder)),
            ),
            _rowAction(
              icon: DsIcons.trash2,
              tooltip: t.recorder.delete,
              color: colors.danger.text,
              onTap: () => unawaited(_deleteTake(take)),
            ),
          ],
        ),
      ),
    );
  }

  /// One row verb: a quiet glyph that stays out of the thumbnail's way.
  Widget _rowAction({required DsIconData icon, required String tooltip, required VoidCallback onTap, Color? color}) {
    final colors = DsTheme.colorsOf(context);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(DsSpace.s4),
        child: DsIcon(icon, size: 15, color: color ?? colors.textSubtle),
      ),
    );
  }

  /// Deletes one take where it is listed: the confirmation the centre uses,
  /// then the same walk — the folder goes, and the task's row says its file
  /// is gone instead of pointing into nothing. A take the engine is still
  /// writing or joining is refused, and the toast says so.
  Future<void> _deleteTake(RecordingTake take) async {
    final t = context.t;
    final ok = await showAppConfirm(
      context: context,
      title: t.recorder.deleteTakeTitle(name: take.name),
      description: t.recorder.deleteTakeBody(count: 1),
      confirmLabel: t.recorder.delete,
      destructive: true,
    );
    if (!ok || !mounted) return;
    final removed = await ref.read(recordingLibraryProvider.notifier).deleteTake(take);
    if (!mounted) return;
    showDsToast(context: context, title: removed ? t.recorder.deletedToast(count: 1) : t.recorder.deleteBlocked);
    if (!removed) return;
    final row = take.task;
    if (row != null) {
      final store = ref.read(recordingTasksProvider.notifier);
      if (row.state == RecordingTaskState.stopped) {
        await store.setStopped(row.id, filePath: row.takeDirectory, bytes: 0, warning: kRecordingFileDeletedWarning);
      } else {
        await store.add(row.copyWith(filePath: row.takeDirectory, bytes: 0));
      }
    }
  }

  /// A platform id's display name, or the id itself when the registry does
  /// not know it — the preview player's group labels speak the site's name.
  String _platformName(String id) {
    final site = ref.read(sitesProvider).getById(id);
    return site == null ? id : localizedSiteName(site);
  }
}

/// Adds the room to the live check, or takes it out.
///
/// A waiting task is what the monitor polls; turning the check on here matches
/// the reference, where "Record when live" opens the live check as it adds the
/// room.
Future<void> toggleRoomAutoRecord(BuildContext context, WidgetRef ref, LiveRoom detail, RecordingTask? task) async {
  final t = context.t;
  final tasks = ref.read(recordingTasksProvider.notifier);
  if (task?.state == RecordingTaskState.recording) return;
  if (task?.state == RecordingTaskState.waiting) {
    await tasks.remove(task!.id);
    if (!context.mounted) return;
    showDsToast(context: context, title: t.room.autoRecordRemoved, status: DsStatus.success);
    return;
  }
  if (!ref.read(recordingTasksProvider).ready) {
    showDsToast(context: context, title: t.room.autoRecordFailed, status: DsStatus.danger);
    return;
  }
  final settings = ref.read(recordingSettingsProvider);
  if (!settings.schedule.pollingEnabled) {
    ref.read(recordingSettingsProvider.notifier).pollingEnabled = true;
  }
  final now = DateTime.now().toUtc();
  final waiting = task == null
      ? RecordingTask(
          id: '${detail.ref.platform}:${detail.ref.roomId}',
          platform: detail.ref.platform,
          roomId: detail.ref.roomId,
          roomTitle: detail.content.title,
          quality: settings.defaultQuality,
          state: RecordingTaskState.waiting,
          startedAt: now,
        )
      : task.copyWith(
          roomTitle: detail.content.title,
          quality: settings.defaultQuality,
          state: RecordingTaskState.waiting,
          startedAt: now,
        );
  await tasks.add(waiting);
  // The task write arms the monitor, but the arm's first probe owes the poll
  // interval: ask for the check now, so a room already on air starts
  // recording while the toast is still on screen.
  unawaited(ref.read(recordingLiveMonitorProvider).checkNow());
  if (!context.mounted) return;
  showDsToast(
    context: context,
    title: t.room.autoRecordArmed(seconds: settings.schedule.liveCheckSeconds),
    status: DsStatus.success,
  );
}

/// Opens the room's recording management as its own panel: the same surface
/// the chat side's 录制 tab carries — this room's capture, its facts and its
/// finished takes — reached straight from the more menu, no chat drawer in
/// between. The content keeps its tab body's height so its list scrolls in
/// place; the sheet's own width rule stands.
Future<void> showRoomRecordManager(BuildContext context) => showAppPanel<void>(
  context: context,
  builder: (sheetContext) => AppPanel(
    title: Text(sheetContext.t.room.tabRecording),
    minChildHeight: 0,
    child: const SizedBox(height: 480, child: RoomRecordTab()),
  ),
);
