import 'dart:io';

import 'package:media_core/media_core.dart';
import 'package:media_core_media_kit/media_core_media_kit.dart';
import 'package:pure_live/player/kernel/player_preset.dart';
import 'package:media_kit_video/media_kit_video.dart' as mkv;
import 'package:pure_live/common/index.dart';

/// mpv properties for live rooms, owned by the app.
///
/// The adapter applies exactly what the host declares and nothing else, so the
/// live-stream tuning that used to live inside the package lives here:
/// demuxer budget, network timeout, decoder fallback and the per-platform
/// quirks of the rooms this app plays.
abstract final class MediaKitLiveProperties {
  static const int forwardBytes = 96 * 1024 * 1024;
  static const int backBytes = 8 * 1024 * 1024;
  static const int lowEndForwardBytes = 40 * 1024 * 1024;
  static const int lowEndBackBytes = 5 * 1024 * 1024;
  static const int readaheadSeconds = 8;
  static const int cacheSeconds = 30;
  static const int cachePauseWaitSeconds = 4;

  static bool get _lowEnd => _cpuCores <= 4;

  static int get _cpuCores {
    try {
      return Platform.numberOfProcessors;
    } catch (_) {
      return 4;
    }
  }

  /// The full property map handed to the adapter's `extraProperties`.
  static Map<String, String> build() {
    final properties = <String, String>{
      'protocol_whitelist': 'httpproxy,udp,rtp,tcp,tls,data,file,http,https,crypto,rtmp,rtmps,rtsp,srt',
      'demuxer-lavf-probesize': '2097152',
      'demuxer-lavf-analyzeduration': '2',
      'network-timeout': '15',
      // Drop a failing hw decoder after one bad frame.
      'hwdec-software-fallback': '1',
      // Network cache-secs takes precedence over the smaller base readahead.
      'force-seekable': 'yes',
      'cache': 'yes',
      'cache-on-disk': 'no',
      'cache-secs': cacheSeconds.toString(),
      'demuxer-max-bytes': (_lowEnd ? lowEndForwardBytes : forwardBytes).toString(),
      'demuxer-max-back-bytes': (_lowEnd ? lowEndBackBytes : backBytes).toString(),
      // Past media must not borrow the unused forward reserve.
      'demuxer-donate-buffer': 'no',
      'demuxer-readahead-secs': readaheadSeconds.toString(),
      // Refill-then-resume: wait for a healthy buffer after a stall.
      'cache-pause': 'yes',
      'cache-pause-wait': cachePauseWaitSeconds.toString(),
      'demuxer-thread': 'yes',
      // Drop late frames instead of stacking lag.
      'framedrop': 'decoder+vo',
    };

    if (_lowEnd) {
      properties['audio-buffer'] = '0.4';
      properties['stream-lavf-o'] = 'reconnect=1,reconnect_streamed=1,reconnect_on_network_error=1,reconnect_delay_max=2';
    }

    if (Platform.isAndroid) {
      properties['mediacodec-surface-iostream'] = 'yes';
      properties['mediacodec-embed-surface-landscape'] = 'yes';
    }

    if (Platform.isMacOS) {
      // The bundled libmpv's VideoToolbox path is unstable with the Flutter
      // texture surface on this app's macOS builds.
      properties['hwdec'] = 'no';
    }

    // Decode-cost policy: a software decoder's thread pool is what actually
    // costs CPU on a weak box, so cap it there and let lowres absorb the rest.
    if (_lowEnd) {
      properties['vd-lavc-threads'] = '2';
      properties['vd-lavc-o'] = 'lowres=1';
      properties['vd-lavc-skiploopfilter'] = 'nonref';
    } else {
      properties['vd-lavc-o'] = 'lowres=0';
      properties['vd-lavc-skiploopfilter'] = 'default';
    }

    return properties;
  }

  /// The effective output segment for the current engine and platform.
  static PlayerEngineOutput get _output {
    final settings = SettingsService.to.player;
    final segment = PlayerEngineOutput(
      presetId: settings.currentPreset,
      enableCodec: settings.enableCodec.v,
      customPlayerOutput: settings.customPlayerOutput.v,
      videoOutputDriver: settings.videoOutputDriver.v,
      videoHardwareDecoder: settings.videoHardwareDecoder.v,
      audioOutputDriver: settings.audioOutputDriver.v,
    );
    final detail = segment.presetId.outputOverride;

    return segment.copyWith(
      enableCodec: detail.enableCodec ?? segment.enableCodec,
      customPlayerOutput: detail.vo != null ? true : segment.customPlayerOutput,
      videoOutputDriver: detail.vo ?? segment.videoOutputDriver,
      videoHardwareDecoder: detail.hwdec ?? segment.videoHardwareDecoder,
    );
  }

  /// The native controller configuration the segment spells out.
  ///
  /// vo/hwdec are engine names passed verbatim; every tuning property
  /// travels through [engineOptions] instead.
  static mkv.VideoControllerConfiguration buildVideoControllerConfiguration() {
    final segment = _output;

    return mkv.VideoControllerConfiguration(
      vo: segment.customPlayerOutput ? _normalize(segment.videoOutputDriver) : null,
      hwdec: segment.customPlayerOutput ? _normalize(segment.videoHardwareDecoder) : null,
      enableHardwareAcceleration: segment.enableCodec,
    );
  }

  /// Normalises a pick; empty/auto leaves the engine default.
  static String? _normalize(String pick) {
    final value = pick.trim();
    return value.isEmpty || value == 'auto' ? null : value;
  }

  /// The full runtime option list handed to the adapter.
  ///
  /// The live tuning table first, then the preset's own properties, then
  /// the segment's audio pick — a later option for the same property wins.
  static List<EngineOption> engineOptions() {
    final segment = _output;
    final properties = <String, String>{...build(), ...segment.presetId.extraProperties};

    final options = <EngineOption>[
      for (final entry in properties.entries) EngineOption(entry.key, entry.value),
    ];

    final audio = segment.audioOutputDriver;
    if (audio.trim().isNotEmpty && audio.trim() != 'auto') {
      options.add(EngineOption('ao', audio));
    }

    return options;
  }

  /// Applies the app's current settings to a freshly created adapter.
  ///
  /// Called from the factory's `configure` hook: the adapter stashes the
  /// options until its engine exists, so nothing is lost when the kernel
  /// initializes later.
  static void applyTo(MediaKitPlayerAdapter adapter) {
    adapter.applyEngineOptions(engineOptions());
  }
}
