import 'dart:async';

import 'package:live_playback/live_playback.dart' show EngineReady, EngineStopped, PlaybackEngine, PlaybackEngineEvent;
import 'package:live_sites/live_sites.dart' show LivePlayLine, LiveStreamFormat;
import 'package:media_core/media_core.dart'
    show PlayerHandle, PlayerId, PlayerKernel, PlayerSource, SourceHeaders, SourceId, SourceProtocol, SourceType;
import 'package:media_core_media_kit/media_core_media_kit.dart'
    show MediaKitPlayerAdapter, NativePlayer, registerMediaKitRegistry;
import 'package:media_core_presentation/media_core_presentation.dart' show MediaCorePresentation;

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
///
/// `mpvOptions` is the tuning channel — the reference's mpv option page
/// written onto this build's engine: read fresh before every open and pushed
/// into the native player as mpv properties, so vo/ao/hwdec changes take
/// effect on the next stream without rebuilding the app.
final class MediaCorePlaybackEngine implements PlaybackEngine {
  /// Creates the engine with its own kernel and a fresh media_kit backend.
  new({Map<String, String> Function()? mpvOptions}) {
    registerMediaKitRegistry(
      _kernel.registry,
      // The hook is asked per open, not at registration: the settings can
      // change between two streams in the same process.
      beforeOpen: mpvOptions == null
          ? null
          : (player, source) async {
              final platform = player.platform;
              if (platform is! NativePlayer) {
                return;
              }
              for (final entry in mpvOptions().entries) {
                // Best effort: an mpv build without the option answers false
                // or throws in the channel — the untuned default still plays.
                try {
                  await platform.setProperty(entry.key, entry.value);
                } on Object {
                  continue;
                }
              }
            },
    );
  }

  final PlayerKernel _kernel = PlayerKernel();
  final StreamController<PlaybackEngineEvent> _events = StreamController<PlaybackEngineEvent>.broadcast();
  PlayerHandle? _handle;

  // Window-level presentation (picture-in-picture and the always-on-top mini
  // window) is media_core's, not hand-rolled window calls: one
  // [MediaCorePresentation] driver attached to the kernel turns the OS window
  // into a small floating surface on Windows/macOS/Linux. It is attached
  // lazily, on the first request, so a room that never asks for PiP never
  // touches the window plugin. The app's own fullscreen path is untouched —
  // this driver owns only the pip/floating modes, entered one at a time.
  final MediaCorePresentation _presentation = MediaCorePresentation();
  bool _presentationAttached = false;

  /// The adapter the current handle drives — the video surface renders
  /// this. Null until [open] first succeeds.
  MediaKitPlayerAdapter? get surfaceAdapter {
    final adapter = _handle?.adapter;
    return adapter is MediaKitPlayerAdapter ? adapter : null;
  }

  /// The kernel, for hosts that attach their own drivers (multiview, the
  /// media session). The room page does not need it; it uses the [enterPip]
  /// family below.
  PlayerKernel get kernel => _kernel;

  /// The live player's id, or null before the first open and after a stop.
  PlayerId? get playerId => _handle?.id;

  /// Whether this platform can shrink its window into a floating surface
  /// (Windows/macOS/Linux; mobile system-PiP is a separate path the app does
  /// not wire). False means the PiP and mini-window controls stay hidden.
  bool get supportsWindowPresentation => _presentation.supportsPresentationWindow;

  /// Whether the window is currently a PiP or floating surface.
  bool get isWindowed => _presentationWindow != null;

  _WindowPresentation? _presentationWindow;

  /// Shrinks the window into an aspect-locked, always-on-top PiP surface.
  /// Returns false when this platform has no window presentation.
  Future<bool> enterPip() => _applyWindow(_WindowPresentation.pip);

  /// Shrinks the window into a free-floating always-on-top mini window.
  Future<bool> enterMiniWindow() => _applyWindow(_WindowPresentation.mini);

  /// Restores the window from a PiP/mini surface to its normal size.
  Future<void> restoreWindow() async {
    final id = _handle?.id;
    if (_presentationWindow == null || id == null || !_presentationAttached) {
      _presentationWindow = null;
      return;
    }
    await _kernel.exitPip(id).catchError((_) {});
    _presentationWindow = null;
  }

  Future<bool> _applyWindow(_WindowPresentation kind) async {
    final id = _handle?.id;
    if (id == null || !_presentation.supportsPresentationWindow) {
      return false;
    }
    await _attachPresentation();
    // One window surface at a time: switching PiP ⇄ mini restores first.
    if (_presentationWindow != null && _presentationWindow != kind) {
      await restoreWindow();
    }
    _presentationWindow = kind;
    try {
      await switch (kind) {
        _WindowPresentation.pip => _kernel.enterPip(id),
        _WindowPresentation.mini => _kernel.enterFloating(id),
      };
      return true;
    } on Object {
      // No video size reported yet, or the window refused — leave the state
      // honest rather than claiming a surface that did not appear.
      _presentationWindow = null;
      return false;
    }
  }

  Future<void> _attachPresentation() async {
    if (_presentationAttached) {
      return;
    }
    await _presentation.initialize();
    _kernel.presentationDriver = _presentation;
    _presentation.observeKernel(_kernel);
    _presentationAttached = true;
  }

  @override
  Stream<PlaybackEngineEvent> get events => _events.stream;

  @override
  Future<void> open(LivePlayLine line) async {
    try {
      final previous = _handle;
      _handle = null;
      // A new source is a new player id; whatever window surface the last one
      // owned is the page's to restore, not this handle's.
      _presentationWindow = null;
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
    if (_presentationWindow != null && handle != null) {
      // Leaving the room must not strand the window as a corner tile: the
      // surface goes back to the normal shape before the player is gone.
      await _kernel.exitPip(handle.id).catchError((_) {});
      _presentationWindow = null;
    }
    await handle?.dispose();
    await _presentation.dispose();
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

/// The window surfaces media_core's presentation driver can shrink the room's
/// window into: an aspect-locked picture-in-picture tile, or a free-aspect
/// floating mini window. The engine keeps one at a time — the window can only
/// be one shape — and restores to the normal window on leaving either.
enum _WindowPresentation {
  /// Aspect-locked, always-on-top — the classic PiP tile.
  pip,

  /// Always-on-top without the aspect lock; a resizable mini player.
  mini,
}
