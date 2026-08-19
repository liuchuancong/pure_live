/// This file is a part of media_kit (https://github.com/media-kit/media-kit).
///
/// Copyright © 2021 & onwards, Hitesh Kumar Saini <saini123hitesh@gmail.com>.
/// All rights reserved.
/// Use of this source code is governed by MIT license that can be found in the LICENSE file.
import 'dart:io';
import 'dart:async';
import 'dart:collection';

import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:synchronized/synchronized.dart';

import 'package:media_kit/media_kit.dart';

import 'package:media_kit_video/src/utils/query_decoders.dart';
import 'package:media_kit_video/src/video_controller/platform_video_controller.dart';
import 'package:media_kit_video/src/video_controller/video_output_policy.dart';

/// {@template android_video_controller}
///
/// AndroidVideoController
/// ----------------------
///
/// The [PlatformVideoController] implementation based on native JNI & C/C++ used on Android.
///
/// {@endtemplate}
class AndroidVideoController extends PlatformVideoController {
  /// Whether [AndroidVideoController] is supported on the current platform or not.
  static bool get supported => Platform.isAndroid;

  /// Pointer address to the global object reference of `android.view.Surface` i.e. `(intptr_t)(*android.view.Surface)`.
  final ValueNotifier<int?> wid = ValueNotifier<int?>(null);

  /// [Lock] used to synchronize [onLoadHooks], [onUnloadHooks] & [subscription].
  final lock = Lock();

  /// Requested application state. Surface lifecycle and track selection must
  /// share this single owner; otherwise rotation/PiP can overwrite `vid=no`
  /// with `vid=auto` while another asynchronous mpv command is still pending.
  bool _videoOutputEnabled = true;

  NativePlayer get platform => player.platform as NativePlayer;

  Future<void> setProperty(String key, String value) async {
    await platform.setProperty(key, value, waitForInitialization: false);
  }

  Future<void> setProperties(Map<String, String> properties) async {
    for (final entry in properties.entries) {
      await setProperty(entry.key, entry.value);
    }
  }

  /// Listener for updating the --wid property.
  Future<void> widListener() async {
    late final Duration currentPosition;
    await lock.synchronized(() async {
      final width = rect.value?.width.toInt() ?? 1;
      final height = rect.value?.height.toInt() ?? 1;
      final properties = resolveAndroidSurfaceProperties(
        width: width,
        height: height,
        wid: wid.value,
        configuredVo: configuration.vo!,
        videoOutputEnabled: _videoOutputEnabled,
      );
      // It is important to re-initialize --vo after --android-surface-size.
      await setProperty('vo', 'null');
      // ORDER IS IMPORTANT. Surface attachment is the authoritative point at
      // which video can be restored, and [properties] always includes `vid` for
      // both gpu and mediacodec_embed output.
      await setProperties(properties);
      // Instead of seeking to the start (Duration.zero), seek to the current playback position
      // without jumping the user to the start of the media.
      currentPosition = player.state.position;
    });

    // Re-seeking the current position is only a render refresh after the
    // Surface has changed. Native command replies can be delayed by a live
    // demuxer, so keeping this await inside [lock] would also block an unrelated
    // headphone-mode request. The ordered Surface/track properties above are
    // already committed before this best-effort refresh is issued.
    unawaited(
      player.seek(currentPosition).catchError((
        Object error,
        StackTrace stackTrace,
      ) {
        debugPrint('media_kit: Surface refresh seek failed: $error');
        debugPrintStack(stackTrace: stackTrace);
      }),
    );
  }

  @override
  Future<void> setVideoOutputEnabled(bool enabled) {
    // Record intent before waiting for an in-flight Surface update. Even if a
    // WID callback captured the previous value, this queued reconciliation is
    // guaranteed to write the latest value last.
    _videoOutputEnabled = enabled;
    return lock.synchronized(() async {
      final value = resolveVideoTrackForSurface(
        videoOutputEnabled: _videoOutputEnabled,
        surfaceAttached: (wid.value ?? 0) != 0,
      );

      // Do not use NativePlayer.setProperty here. Its synchronous FFI call can
      // block Flutter's isolate while a live demuxer is busy; the timeout and
      // audio-only presentation then cannot even paint, which looks like an
      // endless spinner. media_kit's asynchronous property request keeps the
      // isolate responsive. This controller lock remains the single ordering
      // owner relative to WID/Surface updates, and the adapter's latest-value
      // queue reconciles a superseded request after the async reply arrives.
      final track = value == 'no' ? VideoTrack.no() : VideoTrack.auto();
      await platform.setVideoTrack(track, synchronized: false);
    });
  }

  /// [StreamSubscription] for listening to video [Rect].
  StreamSubscription<VideoParams>? videoParamsSubscription;

  /// {@macro android_video_controller}
  AndroidVideoController._(super.player, super.configuration) {
    wid.addListener(widListener);
    videoParamsSubscription = player.stream.videoParams.listen(
      (event) => unawaited(_handleVideoParams(event)),
    );
  }

  Future<void> _handleVideoParams(VideoParams event) async {
    try {
      final int width;
      final int height;
      if (event.rotate == 0 || event.rotate == 180) {
        width = event.dw ?? 0;
        height = event.dh ?? 0;
      } else {
        // width & height are swapped for 90 or 270 degrees rotation.
        width = event.dh ?? 0;
        height = event.dw ?? 0;
      }

      final isZero = width == 0 || height == 0;
      final isSame = width == rect.value?.width.toInt() &&
          height == rect.value?.height.toInt();
      if (isZero || isSame) return;

      // Surface-size IPC is independent from mpv's WID/vo/vid transaction.
      // Keeping this vendor MethodChannel await inside [lock] meant one delayed
      // Android reply could prevent the headphone action from ever acquiring
      // the video-output lock. Only WID and track selection share [lock].
      final handle = await player.handle;
      await _channel.invokeMethod('VideoOutputManager.SetSurfaceSize', {
        'handle': handle.toString(),
        'width': width.toString(),
        'height': height.toString(),
      });

      rect.value = Rect.fromLTWH(
        0.0,
        0.0,
        width.toDouble(),
        height.toDouble(),
      );

      if (!waitUntilFirstFrameRenderedCompleter.isCompleted) {
        waitUntilFirstFrameRenderedCompleter.complete();
      }
    } catch (error, stackTrace) {
      debugPrint('media_kit: Surface-size update failed: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  /// {@macro android_video_controller}
  static Future<PlatformVideoController> create(
    Player player,
    VideoControllerConfiguration configuration,
  ) async {
    Future<String> getDefaultHwdec() async {
      // Enforce software rendering in emulators.
      bool hw = configuration.enableHardwareAcceleration;
      final bool isEmulator = await _channel.invokeMethod('Utils.IsEmulator');
      if (isEmulator) {
        hw = false;
        debugPrint('media_kit: Emulator detected.');
        debugPrint('media_kit: Enforcing S/W rendering.');
      }
      return hw ? 'auto-safe' : 'no';
    }

    // Update [configuration] to have default values.
    configuration = configuration.copyWith(
      vo: configuration.vo ?? 'gpu',
      hwdec: configuration.hwdec ?? await getDefaultHwdec(),
    );

    // Retrieve the native handle of the [Player].
    final handle = await player.handle;
    // Return the existing [VideoController] if it's already created.
    if (_controllers.containsKey(handle)) {
      return _controllers[handle]!;
    }

    // In case no video-decoders are found, this means media_kit_libs_***_audio is being used.
    // Thus, --vid=no is required to prevent libmpv from trying to decode video (otherwise bad things may happen).
    //
    // Search for common H264 decoder to check if video support is available.
    final decoders = await queryDecoders(handle);
    if (!decoders.contains('h264')) {
      throw UnsupportedError(
        '[VideoController] is not available.'
        ' '
        'Please use media_kit_libs_***_video instead of media_kit_libs_***_audio.',
      );
    }

    // Creation:
    final controller = AndroidVideoController._(player, configuration);

    // Register [_dispose] for execution upon [Player.dispose].
    player.platform?.release.add(controller._dispose);

    // Store the [VideoController] in the [_controllers].
    _controllers[handle] = controller;

    await _channel.invokeMethod('VideoOutputManager.Create', {
      'handle': handle.toString(),
      'enableSurfaceProducer': configuration.enableAndroidSurfaceProducer,
    });

    await controller.setProperties({
      // It is necessary to set vo=null here to avoid SIGSEGV, --wid must be assigned before vo=gpu is set.
      'vo': 'null',
      'hwdec': configuration.hwdec!,
      'vid': 'auto',
      'force-window': 'yes',
      'gpu-api': configuration.vo == 'gpu-next' ? 'vulkan,opengl' : 'auto',
      'sub-use-margins': 'no',
      'sub-font-provider': 'none',
      'sub-scale-with-window': 'yes',
      'hwdec-codecs': 'h264,hevc,mpeg4,mpeg2video,vp8,vp9,av1',
    });

    // Return the [PlatformVideoController].
    return controller;
  }

  /// Sets the required size of the video output.
  /// This may yield substantial performance improvements if a small [width] & [height] is specified.
  ///
  /// Remember:
  /// * “Premature optimization is the root of all evil”
  /// * “With great power comes great responsibility”
  @override
  Future<void> setSize({int? width, int? height}) {
    throw UnsupportedError(
      '[AndroidVideoController.setSize] is not available on Android',
    );
  }

  /// Disposes the instance. Releases allocated resources back to the system.
  Future<void> _dispose() async {
    super.dispose();
    wid.dispose();
    wid.removeListener(widListener);
    await videoParamsSubscription?.cancel();
    final handle = await player.handle;
    _controllers.remove(handle);
    await _channel.invokeMethod('VideoOutputManager.Dispose', {
      'handle': handle.toString(),
    });
  }

  /// Currently created [AndroidVideoController]s.
  static final _controllers = HashMap<int, AndroidVideoController>();

  /// [MethodChannel] for invoking platform specific native implementation.
  static final _channel = const MethodChannel(
    'com.alexmercerind/media_kit_video',
  )..setMethodCallHandler((MethodCall call) async {
      try {
        debugPrint(call.method.toString());
        debugPrint(call.arguments.toString());
        switch (call.method) {
          case 'VideoOutput.Resize':
            {
              // Notify about updated texture ID & [Rect].
              final int handle = call.arguments['handle'];
              final Rect rect = Rect.fromLTWH(
                call.arguments['rect']['left'] * 1.0,
                call.arguments['rect']['top'] * 1.0,
                call.arguments['rect']['width'] * 1.0,
                call.arguments['rect']['height'] * 1.0,
              );
              final int id = call.arguments['id'];
              final int wid = call.arguments['wid'];
              _controllers[handle]?.rect.value = rect;
              _controllers[handle]?.id.value = id;
              _controllers[handle]?.wid.value = wid;
              break;
            }
          case 'VideoOutput.WaitUntilFirstFrameRenderedNotify':
            {
              // Notify about updated texture ID & [Rect].
              final int handle = call.arguments['handle'];
              debugPrint(handle.toString());
              // Notify about the first frame being rendered.
              final completer =
                  _controllers[handle]?.waitUntilFirstFrameRenderedCompleter;
              if (!(completer?.isCompleted ?? true)) {
                completer?.complete();
              }
              break;
            }
          default:
            {
              break;
            }
        }
      } catch (exception, stacktrace) {
        debugPrint(exception.toString());
        debugPrint(stacktrace.toString());
      }
    });
}
