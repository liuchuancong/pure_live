import 'dart:async';

import 'package:live_playback/live_playback.dart' show EngineReady, EngineStopped, PlaybackEngine, PlaybackEngineEvent;
import 'package:live_sites/live_sites.dart' show LivePlayLine, LiveStreamFormat;
import 'package:media_core/media_core.dart'
    show PlayerHandle, PlayerKernel, PlayerSource, SourceHeaders, SourceId, SourceProtocol, SourceType;
import 'package:media_core_media_kit/media_core_media_kit.dart' show MediaKitPlayerAdapter, registerMediaKitRegistry;

/// Loads the media_kit native libraries; a desktop-startup step.
///
/// On a platform without the media_kit libs bundled this initialises into a
/// backend that cannot play — the room page surfaces that as a stopped
/// engine instead of crashing here.
void ensureMediaEngineInitialized() => MediaKitPlayerAdapter.ensureInitialized();

/// The app's playback engine: media_core's [PlayerKernel] with the
/// media_kit (libmpv) backend registered, opened line by line.
///
/// Each [open] replaces the current handle — re-resolving a lease, switching
/// quality or switching line is one call. Failures never throw: they arrive
/// as [EngineStopped] and the room page decides between retry and giving up.
final class MediaCorePlaybackEngine implements PlaybackEngine {
  /// Creates the engine with its own kernel and a fresh media_kit backend.
  new() {
    registerMediaKitRegistry(_kernel.registry);
  }

  final PlayerKernel _kernel = PlayerKernel();
  final StreamController<PlaybackEngineEvent> _events = StreamController<PlaybackEngineEvent>.broadcast();
  PlayerHandle? _handle;

  /// The adapter the current handle drives — the video surface renders
  /// this. Null until [open] first succeeds.
  MediaKitPlayerAdapter? get surfaceAdapter {
    final adapter = _handle?.adapter;
    return adapter is MediaKitPlayerAdapter ? adapter : null;
  }

  @override
  Stream<PlaybackEngineEvent> get events => _events.stream;

  @override
  Future<void> open(LivePlayLine line) async {
    try {
      final previous = _handle;
      _handle = null;
      await previous?.dispose();
      final handle = await _kernel.create(source: _sourceFor(line));
      _handle = handle;
      await handle.playbackController.play();
      _events.add(const EngineReady());
    } on Object catch (error) {
      _events.add(EngineStopped(error: error));
    }
  }

  @override
  Future<void> pause() => _handle?.playbackController.pause() ?? Future<void>.value();

  @override
  Future<void> resume() => _handle?.playbackController.play() ?? Future<void>.value();

  @override
  Future<void> stop() => _handle?.playbackController.stop() ?? Future<void>.value();

  @override
  Future<void> dispose() async {
    final handle = _handle;
    _handle = null;
    await handle?.dispose();
    await _events.close();
  }

  PlayerSource _sourceFor(LivePlayLine line) => PlayerSource(
    id: SourceId.generate(),
    uri: Uri.parse(line.url),
    type: SourceType.live,
    protocol: switch (line.format) {
      LiveStreamFormat.hls => SourceProtocol.hls,
      LiveStreamFormat.dash => SourceProtocol.dash,
      LiveStreamFormat.rtmp => SourceProtocol.rtmp,
      LiveStreamFormat.rtsp => SourceProtocol.rtsp,
      LiveStreamFormat.udp => SourceProtocol.udp,
      LiveStreamFormat.rtp => SourceProtocol.udp,
      LiveStreamFormat.mpegts => SourceProtocol.udp,
      LiveStreamFormat.flv => SourceProtocol.http,
      _ => SourceProtocol.https,
    },
    headers: line.headers.isEmpty ? null : SourceHeaders(line.headers),
  );
}
