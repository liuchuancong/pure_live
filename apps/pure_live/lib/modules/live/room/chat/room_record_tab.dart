import 'dart:async' show Timer;

import 'package:desen_ui/desen_ui.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pure_live/app/routing/navigation/route_names.dart' show RouteNames;
import 'package:pure_live/l10n/translations.dart';
import 'package:pure_live/modules/live/recorder/recorder.dart';
import 'package:pure_live/modules/live/room/controller/room_controller.dart' show roomProvider;
import 'package:pure_live/shared/player/recording_indicator.dart' show RecordingIndicator;

/// The room's own recording panel: what this room's capture has written, in the
/// words the recording centre already uses.
///
/// Read-only on purpose. Every verb that changes the take — start, stop, the
/// quality it records at — is already on the player's bar and in the recording
/// centre, and a second copy here would be a second place for the same switch to
/// disagree with the first.
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
    _syncTicker(running: recording);

    if (task == null) {
      return Center(
        child: DsEmptyState(
          icon: const DsIcon(DsIcons.disc),
          title: Text(t.room.recordIdle),
          actions: [_centerButton(t)],
        ),
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
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: DsBadge(dot: false, label: Text(word), status: tone),
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
        Padding(
          padding: const EdgeInsets.only(top: DsSpace.s16),
          child: Align(alignment: AlignmentDirectional.centerStart, child: _centerButton(t)),
        ),
      ],
    );
  }

  /// The one way out of a read-only panel: the centre that owns the take.
  Widget _centerButton(Translations t) => DsButton(
    variant: DsButtonVariant.secondary,
    size: DsSize.sm,
    onPressed: () => context.go(RouteNames.recorder),
    child: Text(t.navigation.record),
  );
}
