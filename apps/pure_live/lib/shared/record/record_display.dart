import 'package:desen_ui/desen_ui.dart';
import 'package:flutter/widgets.dart';
import 'package:pure_live/l10n/translations.dart';
import 'package:pure_live/modules/live/recorder/data/recording_task.dart';

/// What a recording task looks like to the viewer, derived once for every
/// surface: the bar's pill and word, the centre's status row, its tone and
/// its sort order. The engine's own states plus the one fact only the
/// surfaces know — whether the take's file is gone — fold into one mapping
/// here, so two pages cannot drift into calling the same task different
/// things.
enum RecordingDisplayState {
  /// The engine is writing the room's stream.
  recording,

  /// The take's segments are being joined into its file.
  joining,

  /// The last session ended in an error; nothing usable was kept.
  failed,

  /// The take was saved once, and its file is gone — deleted from the
  /// player or the library.
  fileDeleted,

  /// The subscription is disarmed; the task is kept.
  paused,

  /// The subscription is armed: the live check starts a take when the room
  /// goes live, and a finished session waits for the next one.
  waiting;

  /// Derives the state from the task's own facts.
  static RecordingDisplayState of(RecordingTask task) {
    if (task.postProcessing) return RecordingDisplayState.joining;
    if (task.state == RecordingTaskState.recording) return RecordingDisplayState.recording;
    if (task.state == RecordingTaskState.failed) return RecordingDisplayState.failed;
    if (task.warning == kRecordingFileDeletedWarning) return RecordingDisplayState.fileDeleted;
    if (!task.enabled) return RecordingDisplayState.paused;
    return RecordingDisplayState.waiting;
  }

  /// Whether the bar's strip carries a word for the state: a paused
  /// subscription and a deleted take stay silent there — the plain disc
  /// reads as "not writing", and a word for every idle task would crowd
  /// the strip.
  bool get showsOnBar => switch (this) {
    joining || waiting || failed => true,
    _ => false,
  };

  /// The strip's and the row's colour word for the state.
  DsStatus get tone => switch (this) {
    RecordingDisplayState.joining => DsStatus.info,
    RecordingDisplayState.recording || RecordingDisplayState.failed => DsStatus.danger,
    RecordingDisplayState.paused || RecordingDisplayState.fileDeleted => DsStatus.neutral,
    RecordingDisplayState.waiting => DsStatus.warning,
  };

  /// Which tasks sort first in the centre's subscription list: what is
  /// writing (or finishing) leads, then what is armed, then the failures,
  /// and the disarmed rooms last.
  int get sortRank => switch (this) {
    RecordingDisplayState.recording || RecordingDisplayState.joining => 0,
    RecordingDisplayState.fileDeleted || RecordingDisplayState.waiting => 1,
    RecordingDisplayState.failed => 2,
    RecordingDisplayState.paused => 3,
  };

  /// The state in the viewer's words; [joinPercent] (0–100) tells how far
  /// a joining take got, the way the reference's badge does.
  String word(BuildContext context, {int? joinPercent}) => switch (this) {
    RecordingDisplayState.joining =>
      joinPercent == null
          ? context.t.recorder.stateProcessing
          : '${context.t.recorder.stateProcessing} ${joinPercent.clamp(0, 100)}%',
    RecordingDisplayState.recording => context.t.recorder.stateRecording,
    RecordingDisplayState.failed => context.t.recorder.stateFailed,
    RecordingDisplayState.fileDeleted => context.t.recorder.stateFileDeleted,
    RecordingDisplayState.paused => context.t.recorder.statePaused,
    RecordingDisplayState.waiting => context.t.recorder.stateWaiting,
  };
}
