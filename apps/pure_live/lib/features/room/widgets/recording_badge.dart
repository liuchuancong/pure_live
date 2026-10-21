import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_record_core/live_record_core.dart' show RecordStatus, RecordTask;
import 'package:pure_live/features/recorder/recorder_engine.dart' show RecorderRuntime;
import 'package:pure_live/features/recorder/recorder_providers.dart' show recorderRuntimeProvider;
import 'package:pure_live/features/room/room_providers.dart' show RoomIdentity;
import 'package:pure_live/l10n/generated/strings.g.dart';
import 'package:pure_uikit/pure_uikit.dart';

/// The mark of a room whose recording is busy: 录制中 with a running clock, or
/// 重连中/合成中 on a dark pill while the task is not capturing — the
/// reference's `RoomRecordingBadge`, in the picture's corner.
///
/// Nothing shows while the task is queued or resolving (the reference hides
/// those too): a badge that appears before anything is written would be a
/// promise the recorder has not made yet.
final class RoomRecordingBadge extends ConsumerStatefulWidget {
  /// The badge for [identity]'s room.
  const new({required this.identity, super.key});

  /// The room to look up in the recorder's tasks.
  final RoomIdentity identity;

  @override
  ConsumerState<RoomRecordingBadge> createState() => _RoomRecordingBadgeState();
}

final class _RoomRecordingBadgeState extends ConsumerState<RoomRecordingBadge> {
  RecordTask? _task;
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _wire();
  }

  @override
  void didUpdateWidget(covariant RoomRecordingBadge oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.identity != widget.identity) {
      _wire();
    }
  }

  @override
  void dispose() {
    _ticker?.cancel();
    unawaited(_changed?.cancel());
    super.dispose();
  }

  StreamSubscription<RecordTask>? _changed;

  void _wire() {
    final runtime = ref.read(recorderRuntimeProvider).value;
    _task = _mine(runtime);
    unawaited(_changed?.cancel());
    _changed = runtime?.onChanged.listen((task) {
      if (!mounted || !_isMine(task)) {
        return;
      }
      setState(() => _task = task);
      _armTicker();
    });
    _armTicker();
  }

  bool _isMine(RecordTask task) =>
      task.target.platform == widget.identity.siteId && task.target.roomId == widget.identity.roomId;

  RecordTask? _mine(RecorderRuntime? runtime) {
    if (runtime == null) {
      return null;
    }
    for (final task in runtime.tasks) {
      if (_isMine(task)) {
        return task;
      }
    }
    return null;
  }

  /// The clock ticks only while something has a running figure to show.
  void _armTicker() {
    _ticker?.cancel();
    final status = _task?.status;
    if (status == RecordStatus.recording || status == RecordStatus.retrying) {
      _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) {
          setState(() {});
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final task = _task;
    if (task == null) {
      return const SizedBox.shrink();
    }
    final t = context.t;
    final theme = PureTheme.of(context);
    final clock = _clock(task);
    final (label, color) = switch (task.status) {
      RecordStatus.recording => (t.room.recBadgeRecording(time: clock), theme.colors.error),
      RecordStatus.retrying => (t.room.recBadgeRetrying(time: clock), const Color(0xCC222222)),
      RecordStatus.merging => (t.room.recBadgeMerging, const Color(0xCC222222)),
      _ => ('', Colors.transparent),
    };
    if (label.isEmpty) {
      return const SizedBox.shrink();
    }
    return DecoratedBox(
      key: const ValueKey('room-recording-badge'),
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(999)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (task.status == RecordStatus.recording) ...[
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
              ),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: theme.text.caption.copyWith(color: Colors.white, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }

  /// Elapsed since the task started capturing, as mm:ss (h:mm:ss past an
  /// hour).
  String _clock(RecordTask task) {
    final startedAt = task.startedAt;
    if (startedAt == null) {
      return '00:00';
    }
    final elapsed = DateTime.now().difference(startedAt);
    final hours = elapsed.inHours;
    final minutes = elapsed.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = elapsed.inSeconds.remainder(60).toString().padLeft(2, '0');
    return hours > 0 ? '$hours:$minutes:$seconds' : '$minutes:$seconds';
  }
}
