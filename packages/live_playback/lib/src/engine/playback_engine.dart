import 'package:live_sites/live_sites.dart';

/// What an engine reports back to the session.
///
/// Engines translate their native errors through `PlaybackEngineEvent`s;
/// the session classifies them (`PlaybackFailure`) and decides on
/// recovery.
sealed class PlaybackEngineEvent {
  const new();
}

/// The engine opened the source and produced its first frame.
final class EngineReady extends PlaybackEngineEvent {
  /// The engine is ready.
  const new();
}

/// The engine stopped playing before being asked to (an error, an ended
/// stream).
final class EngineStopped extends PlaybackEngineEvent {
  /// The engine stopped with an optional [error].
  const new({this.error});

  /// The native error, when the engine surfaced one.
  final Object? error;
}

/// The engine reported progress (position and buffer health).
final class EngineProgress extends PlaybackEngineEvent {
  /// A progress report.
  const new({required this.position, this.bufferAhead});

  /// Current position.
  final Duration position;

  /// Buffered time ahead of the position, when the engine reports it.
  final Duration? bufferAhead;
}

/// The seam between playback orchestration and a player engine.
///
/// The app implements it over media_core (PlayerKernel handles): this
/// package stays engine-agnostic and pure Dart, exactly like the site
/// layer stays transport-agnostic. Implementations must never throw from
/// `open`; failures arrive as [EngineStopped].
abstract interface class PlaybackEngine {
  /// A stream of engine events for the current source.
  Stream<PlaybackEngineEvent> get events;

  /// Opens [line] and starts playing.
  Future<void> open(LivePlayLine line);

  /// Pauses playback.
  Future<void> pause();

  /// Resumes playback.
  Future<void> resume();

  /// Stops playback and releases the current source.
  Future<void> stop();

  /// Releases the engine. The instance is unusable afterwards.
  Future<void> dispose();
}

/// A factory the session uses to create one engine per session.
typedef PlaybackEngineFactory = PlaybackEngine Function();
