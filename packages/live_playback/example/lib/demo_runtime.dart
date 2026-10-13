import 'package:flutter/foundation.dart';

import 'package:live_playback/live_playback.dart';
import 'package:media_core/media_core.dart';
import 'package:media_core/testing/library.dart';

/// A presentation adapter the demo's buttons can poke.
///
/// It is the host's seam: `apply` returns immediately because the demo's stage
/// *is* the "platform" — the picture is a box in the widget tree, so entering
/// fullscreen or a small window is a rebuild. The two capabilities start where
/// a desktop app without platform drivers would be: the in-app small window is
/// pure widget work (`floating: true`), system PiP needs an OS window that
/// `media_core_pip` would provide (`pip: false`).
///
/// [setCapabilities] is what a host does when its platform layer learns
/// something — a permission was granted, a driver attached — and it is the
/// switch that makes the background policy visibly change its answer.
final class DemoPresentationAdapter extends PresentationAdapterBase {
  /// Creates the adapter.
  new({super.initialCapabilities = const PresentationCapabilities(floating: true)});

  @override
  Future<void> apply(PresentationRequest request) async {
    // The demo's platform is the widget tree; nothing to do.
  }

  @override
  Future<void> refreshCapabilities() async {
    // The demo's capabilities only change through [setCapabilities].
  }

  /// Reports new platform abilities, keeping the ones not named.
  void setCapabilities({bool? pip, bool? floating}) {
    updateCapabilities(
      PresentationCapabilities(pip: pip ?? capabilities.canPip, floating: floating ?? capabilities.canFloating),
    );
  }
}

/// Everything the demo runs on: kernel, service, settings and the log.
///
/// The kernel is the real thing with the *fake* backend registered, so every
/// scenario runs end to end — sessions open, recovery ladders arm, the audio
/// policy mutes windows — without a stream URL, a codec or a platform window
/// system. On a real app the same call site registers `media_core_media_kit`
/// or `media_core_better_player` instead.
final class DemoRuntime {
  /// Creates the runtime.
  new() {
    kernel = PlayerKernel()
      ..registerBackend(
        PlayerAdapterRegistration(
          // The id must be one the factory can create: `fakeAdapterFactory`
          // registers the `testing` adapter under `fake`. A real app pairs its
          // own id with its own adapter factory here.
          id: 'fake',
          capabilities: const PlayerAdapterCapabilities(),
          factory: TestPlayerFactory.fakeAdapterFactory(),
        ),
      );

    service = PlaybackService(kernel: kernel, presentationAdapter: adapter, settings: settings);

    service.stateStream.listen(_onState);
    _log('ready: 假后端已注册，平台能力 PiP=${adapter.capabilities.canPip} 小窗=${adapter.capabilities.canFloating}');
  }

  /// The kernel with the fake backend.
  late final PlayerKernel kernel;

  /// The presentation adapter the demo's platform switches drive.
  final DemoPresentationAdapter adapter = DemoPresentationAdapter();

  /// The viewer's settings, live-editable from the demo's panel.
  final PlaybackSettings settings = PlaybackSettings();

  /// The service under test.
  late final PlaybackService service;

  /// The log the UI shows, oldest first.
  final ValueNotifier<List<String>> log = ValueNotifier<List<String>>(<String>[]);

  PlaybackSystemState _last = PlaybackSystemState.idle;

  /// A live-room source.
  PlayerSource liveSource(String id) => PlayerSource(
    id: SourceId('https://example.com/$id.m3u8'),
    uri: Uri.parse('https://example.com/$id.m3u8'),
    type: SourceType.live,
    title: '直播间 $id',
  );

  /// A recorded-video source.
  PlayerSource recordedSource(String id) => PlayerSource(
    id: SourceId('https://example.com/$id.mp4'),
    uri: Uri.parse('https://example.com/$id.mp4'),
    title: '录播 $id',
  );

  /// The video geometry the stage pretends to have.
  ///
  /// A live room is vertical and a recorded video is wide, which is what makes
  /// the small window's shape and its remembered rect differ between them.
  VideoGeometry geometryOf({required bool portrait}) {
    final size = portrait ? const VideoSize(width: 720, height: 1280) : const VideoSize(width: 1920, height: 1080);
    return VideoGeometry.derived(
      videoSize: size,
      displaySize: DisplaySize(width: size.width.toDouble(), height: size.height.toDouble()),
      rotation: const VideoRotationInfo.none(),
      pixelRatio: const PixelRatioValue.one(),
    );
  }

  /// Appends a line to the log.
  void note(String line) => _log(line);

  void _log(String line) {
    log.value = <String>[...log.value, line];
  }

  /// Logs the interesting differences between two snapshots.
  ///
  /// The full snapshot ticks with every position update; the demo cares about
  /// the transitions a viewer would notice — which window is audible, where the
  /// picture is, whether the app is in the background, and the two global
  /// switches.
  void _onState(PlaybackSystemState state) {
    if (state.presentationMode != _last.presentationMode) {
      _log('presentation -> ${state.presentationMode.name}');
    }
    if (state.primarySessionId != _last.primarySessionId) {
      _log('audio owner -> ${state.primarySessionId ?? "无"}');
    }
    if (state.overlaySessionId != _last.overlaySessionId) {
      _log('overlay -> ${state.overlaySessionId ?? "无"}');
    }
    if (state.isBackgrounded != _last.isBackgrounded) {
      _log('app -> ${state.isBackgrounded ? "后台" : "前台"}');
    }
    if (state.sessions.length != _last.sessions.length) {
      _log('sessions -> ${state.sessions.keys.join(", ")}');
    }
    if (state.allMuted != _last.allMuted && state.sessions.isNotEmpty) {
      _log('all muted -> ${state.allMuted}');
    }
    if (state.allDanmakuDisabled != _last.allDanmakuDisabled) {
      _log('chat off -> ${state.allDanmakuDisabled}');
    }

    _last = state;
  }

  /// Releases the kernel.
  Future<void> dispose() async {
    await service.dispose();
    await kernel.dispose();
  }
}
