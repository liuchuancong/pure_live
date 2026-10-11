/// Live playback orchestration for Pure Live.
///
/// A `PlaybackSession` takes a room, asks its `LiveSite` for qualities
/// and lines, drives a `PlaybackEngine` (the seam the app binds to
/// media_core), schedules lease renewals, classifies failures and walks
/// the recovery ladder (same line → next line → next quality → refresh →
/// give up). `PlaybackCoordinator` keeps several sessions (windows) in
/// order and decides who owns the audio. The package never implements a
/// player engine, an adapter or any rendering.
library;

export 'src/coordinator/playback_coordinator.dart';
export 'src/engine/playback_engine.dart';
export 'src/model/playback_event.dart';
export 'src/model/playback_failure.dart';
export 'src/model/playback_state.dart';
export 'src/session/playback_session.dart';
export 'src/session/quality_selector.dart';
