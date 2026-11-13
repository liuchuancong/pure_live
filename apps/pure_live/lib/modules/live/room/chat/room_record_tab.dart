import 'dart:async' show Timer, unawaited;

import 'package:desen_ui/desen_ui.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:live_sites/live_sites.dart' show LiveRoom;
import 'package:pure_live/app/routing/navigation/route_names.dart' show RouteNames;
import 'package:pure_live/l10n/translations.dart';
import 'package:pure_live/modules/live/recorder/recorder.dart';
import 'package:pure_live/modules/live/room/controller/room_controller.dart' show roomProvider;
import 'package:pure_live/modules/live/room/page/player_surface.dart' show toggleRoomRecording;
import 'package:pure_live/shared/player/recording_indicator.dart' show RecordingIndicator;

/// The room's own recording panel: what this room's capture has written, and
/// the verbs on it — start and stop right here, so managing this room's take
/// never means leaving the room.
///
/// The verbs are the player bar's own ([toggleRoomRecording]), called with
/// this panel's ref: one switch, one truth, two doors. The recording centre
/// stays a quiet line at the foot — the queue, the schedule and the finished
/// files live there, and this panel says so without sending the viewer off
/// for a button press.
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
              _centreButton(t),
            ],
          ),
        ],
      );
    }

    final settings = ref.watch(recordingSettingsProvider);
    final elapsed = DateTime.now().difference(task.startedAt);
    // The take's own average rather than the stream's instantaneous rate: the
    // store keeps bytes and media time and no live bitrate, which is all a
    // recording can honestly answer with.
    final bitrate = formatRecordingBitrate(task.bytes, recording ? elapsed : Duration(milliseconds: task.durationMs));
    final chatCount = recording ? ref.read(recorderEngineProvider).chatEntries(task.id) : null;
    final (word, tone) = switch (task.state) {
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
              onPressed: _toggle,
              child: Text(recording ? t.room.stopRecording : t.room.recordStarted),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(top: DsSpace.s8),
          child: Align(alignment: AlignmentDirectional.centerStart, child: _centreButton(t)),
        ),
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
