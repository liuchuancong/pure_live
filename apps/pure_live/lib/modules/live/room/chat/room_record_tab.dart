import 'dart:async' show Timer, unawaited;

import 'package:desen_ui/desen_ui.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:live_sites/live_sites.dart' show LiveRoom;
import 'package:pure_live/app/app.dart' show RouteNames, SettingsSectionRoute, sitesProvider;
import 'package:pure_live/features/settings/settings.dart' show SettingsSection, openSettingsSection;
import 'package:pure_live/l10n/translations.dart';
import 'package:pure_live/modules/live/recorder/recorder.dart';
import 'package:pure_live/modules/live/room/controller/room_controller.dart' show roomProvider;
import 'package:pure_live/modules/live/room/page/player_surface.dart' show toggleRoomRecording;
import 'package:pure_live/shared/player/recording_indicator.dart' show RecordingIndicator;
import 'package:pure_live/shared/shared.dart' show AppPanel, localizedSiteName, showAppPanel;

/// The room's own recording panel: what this room's capture has written and
/// what it has already written, with the verbs on both — start and stop and
/// play right here, so managing this room's takes never means leaving the
/// room.
///
/// The verbs are the player bar's own ([toggleRoomRecording]), called with
/// this panel's ref: one switch, one truth, two doors. The foot carries the
/// two doors the panel itself does not replace: the recorder's settings page
/// (the quality, the segments, the schedule's shape) and the recording centre
/// (the queue and every room's files together). Settings goes to the settings
/// page, not to the centre — a change of quality is not a walk through the
/// library.
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

final class _RoomRecordTabState extends ConsumerState<RoomRecordTab> {
  Timer? _tick;
  bool _ticking = false;

  @override
  void dispose() {
    _tick?.cancel();
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
    final t = context.t;
    final theme = DsTheme.of(context);
    final colors = DsTheme.colorsOf(context);
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
    // The take's segments are being joined into its file: neither recording
    // nor stopped, and the state words say so where the raw state cannot.
    final joining = task?.postProcessing ?? false;
    _syncTicker(running: recording);

    if (task == null) {
      return ListView(
        padding: const EdgeInsets.all(DsSpace.s16),
        children: [
          _autoRecordSwitch(room: room, task: task, waiting: waiting),
          const SizedBox(height: DsSpace.s32),
          DsEmptyState(
            icon: const DsIcon(DsIcons.disc),
            title: Text(t.room.recordIdle),
            actions: [
              DsButton(
                variant: DsButtonVariant.primary,
                size: DsSize.sm,
                leading: const DsIcon(DsIcons.disc, size: 15),
                onPressed: _toggle,
                child: Text(t.room.recordStarted),
              ),
            ],
          ),
          const SizedBox(height: DsSpace.s24),
          _takesSection(room: room),
          const SizedBox(height: DsSpace.s16),
          _footer(),
        ],
      );
    }

    final settings = ref.watch(recordingSettingsProvider);
    final elapsed = DateTime.now().difference(task.startedAt);
    // The take's own average rather than the stream's instantaneous rate: the
    // store keeps bytes and media time and no live bitrate, which is all a
    // recording can honestly answer with.
    // Media time over the wall clock: a stalled stream writes fewer bytes
    // than the clock says, and the average should say what landed. The
    // clock keeps its own line below.
    final mediaTime = Duration(milliseconds: task.durationMs);
    final bitrate = formatRecordingBitrate(task.bytes, mediaTime > Duration.zero ? mediaTime : elapsed);
    final chatCount = recording ? ref.read(recorderEngineProvider).chatEntries(task.id) : null;
    final (word, tone) = joining
        ? (t.recorder.stateProcessing, DsStatus.info)
        : switch (task.state) {
            RecordingTaskState.recording => (t.recorder.stateRecording, DsStatus.danger),
            RecordingTaskState.waiting => (t.recorder.stateWaiting, DsStatus.neutral),
            RecordingTaskState.stopped => (t.recorder.stateStopped, DsStatus.success),
            RecordingTaskState.failed => (t.recorder.stateFailed, DsStatus.warning),
          };
    return ListView(
      padding: const EdgeInsets.all(DsSpace.s16),
      children: [
        _autoRecordSwitch(room: room, task: task, waiting: waiting),
        const SizedBox(height: DsSpace.s16),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: DsBadge(dot: recording, label: Text(word), status: tone),
        ),
        if (recording)
          Padding(
            padding: const EdgeInsets.only(top: DsSpace.s12, bottom: DsSpace.s4),
            child: Text(
              RecordingIndicator.formatElapsed(elapsed),
              style: theme.typography.numeric(
                theme.typography.title.copyWith(color: colors.text, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        if (recording)
          Text(
            t.room.recordSegment(
              index: task.segments < 1 ? 1 : task.segments,
              minutes: (settings.segmentSeconds / 60).round(),
            ),
            style: theme.typography.caption.copyWith(color: colors.textMuted),
          ),
        Padding(
          padding: const EdgeInsets.only(top: DsSpace.s12),
          child: Wrap(
            spacing: DsSpace.s8,
            runSpacing: DsSpace.s6,
            children: [
              if (task.bytes > 0)
                DsBadge(dot: false, label: Text(t.room.recordSize(size: formatRecordingBytes(task.bytes)))),
              if (bitrate.isNotEmpty) DsBadge(dot: false, label: Text(bitrate)),
              DsBadge(dot: false, label: Text(task.quality.isEmpty ? t.recorder.qualityBest : task.quality)),
              // A take recorded without a chat file says nothing about one:
              // "0 条" would read as a capture that lost every line.
              if (chatCount case final count? when count > 0)
                DsBadge(dot: false, label: Text(t.room.recordDanmakuCount(count: count))),
            ],
          ),
        ),
        // The verb on the take, where the facts about it are: a press here
        // starts or stops this room's capture, and the room never moves.
        Padding(
          padding: const EdgeInsets.only(top: DsSpace.s16),
          child: SizedBox(
            width: double.infinity,
            child: DsButton(
              variant: recording ? DsButtonVariant.danger : DsButtonVariant.primary,
              size: DsSize.sm,
              leading: DsIcon(recording ? DsIcons.squareStop : DsIcons.disc, size: 15),
              onPressed: joining ? null : _toggle,
              child: Text(recording ? t.room.stopRecording : t.room.recordStarted),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(top: DsSpace.s24, bottom: DsSpace.s16),
          child: _takesSection(room: room),
        ),
        _footer(),
      ],
    );
  }

  /// The takes the capture has already filed for this room, newest first —
  /// the room's own shelf, so a finished take plays without a trip to the
  /// centre. The walk runs once per settled session; while it first runs the
  /// section keeps quiet rather than promising rows it cannot name yet.
  Widget _takesSection({required LiveRoom? room}) {
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
    if (takes.isEmpty) {
      // A walk still in flight says nothing: "no recordings" before the
      // first answer lands is a lie the next frame corrects.
      if (takesAsync.isLoading && takesAsync.value == null) return const SizedBox.shrink();
      return Text(t.room.roomRecordTakesEmpty, style: theme.typography.caption.copyWith(color: colors.textMuted));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: DsSpace.s4,
      children: [
        Text(
          t.room.roomRecordTakes(count: takes.length),
          style: theme.typography.overline.copyWith(color: colors.textSubtle),
        ),
        for (final take in takes) _takeRow(take, takes),
      ],
    );
  }

  /// One finished take: when it was taken, how long and how heavy it is —
  /// the whole line is the way in, the same preview player the centre opens.
  Widget _takeRow(RecordingTake take, List<RecordingTake> around) {
    final theme = DsTheme.of(context);
    final colors = DsTheme.colorsOf(context);
    final facts = [
      formatRecordingMoment(take.takenAt),
      if (take.duration case final duration?) formatRecordingDuration(duration),
      if (take.bytes > 0) formatRecordingBytes(take.bytes),
    ].join(' · ');
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => unawaited(playRecordingTake(context, ref, around: around, take: take, platformName: _platformName)),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: DsSpace.s6),
        child: Row(
          spacing: DsSpace.s8,
          children: [
            DsIcon(DsIcons.play, size: 16, color: colors.textMuted),
            Expanded(
              child: Text(
                facts,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.typography.caption.copyWith(color: colors.text),
              ),
            ),
            DsIcon(DsIcons.chevronRight, size: 14, color: colors.textSubtle),
          ],
        ),
      ),
    );
  }

  /// A platform id's display name, or the id itself when the registry does
  /// not know it — the preview player's group labels speak the site's name.
  String _platformName(String id) {
    final site = ref.read(sitesProvider).getById(id);
    return site == null ? id : localizedSiteName(site);
  }

  /// The quiet foot: the recorder's settings page and the centre. Settings
  /// is the section's own page — quality, segments, schedule shape — not a
  /// walk through the library; the centre keeps the queue and every room's
  /// files together. A push, not a `go`: the room stays under them.
  Widget _footer() {
    final t = context.t;
    return Wrap(
      spacing: DsSpace.s8,
      runSpacing: DsSpace.s6,
      children: [
        DsButton(
          variant: DsButtonVariant.ghost,
          size: DsSize.sm,
          onPressed: () {
            openSettingsSection(ref, SettingsSection.recording);
            unawaited(context.push(SettingsSectionRoute(section: SettingsSection.recording.name).location));
          },
          leading: const DsIcon(DsIcons.settings, size: 15),
          child: Text(t.recorder.settingsOpen),
        ),
        _centreButton(t),
      ],
    );
  }

  /// The centre still exists for what a single room's panel cannot show — the
  /// queue, the schedule, the finished files — said as one quiet line, not as
  /// the panel's only door. A push, not a `go`: the room stays under it, and
  /// the way back is the panel's own.
  Widget _centreButton(Translations t) => DsButton(
    variant: DsButtonVariant.ghost,
    size: DsSize.sm,
    onPressed: () => unawaited(context.push(RouteNames.recorder)),
    child: Text(t.navigation.record),
  );

  /// The room's schedule verb, where the room's takes are managed: arming the
  /// live check for this room is a recording errand, not a room-menu row.
  Widget _autoRecordSwitch({required LiveRoom? room, required RecordingTask? task, required bool waiting}) {
    if (room == null) return const SizedBox.shrink();
    final t = context.t;
    final recording = task?.state == RecordingTaskState.recording;
    final seconds = ref.watch(recordingSettingsProvider).schedule.liveCheckSeconds;
    return DsSwitch(
      value: waiting,
      onChanged: recording ? null : (_) => unawaited(toggleRoomAutoRecord(context, ref, room, task)),
      label: Text(t.room.autoRecordOn),
      description: waiting ? Text(t.room.autoRecordArmed(seconds: seconds)) : null,
    );
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
