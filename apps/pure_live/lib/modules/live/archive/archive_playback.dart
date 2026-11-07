import 'package:flutter/foundation.dart';
import 'package:live_sites/live_sites.dart' show LiveMessage, LiveRetraction;
import 'package:live_vod/live_vod.dart' show ArchiveQuality, ArchiveVideo;
import 'package:media_core/media_core.dart' show PlayerHandle, PlayerHandlePlayback;

/// The common control surface of official replay players. Platform resolution
/// and progress stores remain independent; live playback is never reused as
/// VOD. The session is the module player kernel's handle: a page attaches one
/// handle and hands it here, so a replay and a live room never decode twice.
abstract class ArchivePlaybackController extends ChangeNotifier {
  double _rate = 1;

  /// Selected speed; restricted to the native player's supported range.
  double get rate => _rate;

  /// Applies a preset or a 0.05 increment without reopening/starting
  /// playback. The bool reports whether the engine took the value; the
  /// kernel's handle answers void, so only an engine failure says no.
  Future<bool> setRate(double value) async {
    if (!value.isFinite || value < 0.25 || value > 4 || (value * 20 - (value * 20).round()).abs() > 0.000001) {
      return false;
    }
    try {
      await session.setRate(value);
      _rate = value;
      notifyListeners();
      return true;
    } on Object {
      return false;
    }
  }

  /// Restores the selected rate after a quality/part change.
  Future<void> restoreRate() async {
    await session.setRate(_rate);
  }

  /// Completes after asynchronous native disposal, so another decoder can
  /// resume.
  Future<void> get retirement;

  /// The page's native player handle from the kernel.
  PlayerHandle get session;

  /// Current metadata without media credentials.
  ArchiveVideo? get video;

  /// Current input position, including a pending seek.
  Duration get position;

  /// Public recording clock, which may span a segment-anchored native input.
  Duration get duration => session.duration > Duration.zero ? session.duration : video?.duration ?? Duration.zero;

  /// Server-offered renditions.
  List<ArchiveQuality> get qualities;

  /// Selected rendition id.
  String? get qualityId;

  /// Related segments, when the platform provides them.
  List<ArchiveVideo> get segments => const [];

  /// Resolution or quality change in progress.
  bool get busy;

  /// Failure translated by the shared player.
  Object? get error;

  /// Whether this source exposes a verified comment timeline.
  bool get supportsDanmaku => false;

  /// A single external player URL would omit the separate DASH audio.
  bool get requiresExternalAudio => false;

  /// Current comment visibility.
  bool get danmakuVisible => false;

  /// Timeline messages, not live-room comments from a different broadcast.
  Stream<LiveMessage> get messages => const Stream.empty();

  /// Timeline clears after seeking.
  Stream<LiveRetraction> get retractions => const Stream.empty();

  /// Opens an official video id and optional position.
  Future<void> open(String id, {Duration? start});

  /// Selects a permitted quality without losing position.
  Future<void> selectQuality(String id);

  /// Seeks within the current recording.
  Future<void> seek(Duration position);

  /// Saves metadata and position only.
  Future<void> record();

  /// Plays or pauses, whichever the transport is not doing.
  Future<void> togglePlayPause() async {
    if (session.playbackStream.value.command.isPlaying) {
      await session.pause();
    } else {
      await session.play();
    }
  }

  /// Toggles a supported comment timeline.
  void toggleDanmaku() {}
}
