import 'dart:io';
import 'dart:developer' as developer;

import 'package:media_core/media_core.dart';
import 'package:media_core_ingest/media_core_ingest.dart' show isHlsManifestUri;
import 'package:media_core_media_kit/media_core_media_kit.dart';
import 'package:pure_live/core/player/kernel/player_preset.dart';
import 'package:pure_live/core/player/core/playback_proxy_policy.dart';
import 'package:pure_live/core/player/core/playback_source_hints.dart';
import 'package:pure_live/core/player/super_resolution.dart';
import 'package:media_core_media_kit/media_core_media_kit.dart' as mkv;
import 'package:pure_live/core/index.dart';

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
  ///
  /// Only properties that are the same for every source belong here. Anything
  /// that depends on the source being opened — the proxy, the container, the
  /// live-playlist cache policy — is written by [applyToSource] instead, because
  /// two writers for one property do not have a deterministic order: the
  /// factory's `configure` hook takes a `void` callback, so the future returned
  /// here is dropped and these writes can land *after* a source has opened.
  /// A Twitch reproduction showed exactly that, with the per-source
  /// `force-seekable=no` overwritten by this table's `yes` a few lines later.
  static Map<String, String> build() {
    final properties = <String, String>{
      'protocol_whitelist': 'httpproxy,udp,rtp,tcp,tls,data,file,http,https,crypto,rtmp,rtmps,rtsp,srt',
      'demuxer-lavf-probesize': '2097152',
      'demuxer-lavf-analyzeduration': '2',
      'network-timeout': '15',
      // Drop a failing hw decoder after one bad frame.
      'hwdec-software-fallback': '1',
      // Network cache-secs takes precedence over the smaller base readahead.
      'cache': 'yes',
      'cache-on-disk': 'no',
      'cache-secs': cacheSeconds.toString(),
      'demuxer-max-bytes': (_lowEnd ? lowEndForwardBytes : forwardBytes).toString(),
      'demuxer-max-back-bytes': (_lowEnd ? lowEndBackBytes : backBytes).toString(),
      // Past media must not borrow the unused forward reserve.
      'demuxer-donate-buffer': 'no',
      'demuxer-readahead-secs': readaheadSeconds.toString(),
      // Refill-then-resume: wait for a healthy buffer after a stall. Whether it
      // is enabled at all is a per-source decision (see [sourceProperties]).
      'cache-pause-wait': cachePauseWaitSeconds.toString(),
      'demuxer-thread': 'yes',
      // Drop late frames instead of stacking lag.
      'framedrop': 'decoder+vo',
    };

    if (_lowEnd) {
      properties['audio-buffer'] = '0.4';
      properties['stream-lavf-o'] =
          'reconnect=1,reconnect_streamed=1,reconnect_on_network_error=1,reconnect_delay_max=2';
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

    // With the embedded render context only libmpv draws into the Flutter
    // texture. 'auto' (engine default) maps to no explicit vo; anything else
    // a stale segment may still carry ('null', windowed drivers) is dropped —
    // those produce sound-without-picture or a rogue mpv window.
    final vo = segment.customPlayerOutput && segment.videoOutputDriver.trim() == 'libmpv' ? 'libmpv' : null;

    return mkv.VideoControllerConfiguration(
      vo: vo,
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
  static Future<List<EngineOption>> engineOptions() async {
    final segment = _output;
    final properties = <String, String>{...build(), ...segment.presetId.extraProperties};

    final options = <EngineOption>[for (final entry in properties.entries) EngineOption(entry.key, entry.value)];

    if (superResolutionAvailable) {
      final shader = await superResolutionOption(_superResolution, await getApplicationSupportDirectory());

      if (shader != null) {
        options.add(shader);
      }
    }

    options.addAll(<EngineOption>[
      if (segment.videoSync != 'auto') EngineOption('video-sync', segment.videoSync),
      if (segment.interpolation != 'no') EngineOption('interpolation', 'yes'),
      if (segment.scale != 'lanczos') EngineOption('scale', segment.scale),
      if (segment.deinterlace != 'auto') EngineOption('deinterlace', segment.deinterlace),
      if (segment.hwdecCodecs != 'all') EngineOption('hwdec-codecs', segment.hwdecCodecs),
      if (segment.audioExclusive != 'no') EngineOption('audio-exclusive', 'yes'),
    ]);

    // The manual ao pick rides the same custom-output gate as vo/hwdec:
    // with the switch off, the engine default applies and the settings UI
    // does not show the pick at all.
    final audio = segment.audioOutputDriver;
    if (segment.customPlayerOutput && audio.trim().isNotEmpty && audio.trim() != 'auto') {
      options.add(EngineOption('ao', audio));
    }

    return options;
  }

  /// Applies the app's current settings to a freshly created adapter.
  ///
  /// Called from the factory's `configure` hook: the adapter stashes the
  /// options until its engine exists, so nothing is lost when the kernel
  /// initializes later.
  static Future<void> applyTo(MediaKitPlayerAdapter adapter) async {
    adapter.applyEngineOptions(await engineOptions());
  }

  /// The native player configuration; only the log level differs from media_kit's
  /// defaults, since passing this object at all means restating them.
  static mkv.PlayerConfiguration playerConfiguration() => mkv.PlayerConfiguration(
    logLevel: const bool.fromEnvironment('dart.vm.product') ? mkv.MPVLogLevel.warn : mkv.MPVLogLevel.v,
  );

  static Map<String, String> sourceProperties({
    required Uri uri,
    required String? declaredFormat,
    required String proxy,
  }) {
    final bool privateInput = isPrivatePlaybackInput(uri);
    final bool playlist = (declaredFormat ?? (isHlsManifestUri(uri) ? 'hls' : null)) == 'hls';
    return <String, String>{
      'http-proxy': privateInput || playsDirectBehindProxy(uri) ? '' : proxy,
      'demuxer-lavf-format': playlist && !privateInput ? 'hls' : '',
      'force-seekable': playlist ? 'no' : 'yes',
      'cache-pause': playlist ? 'no' : 'yes',
    };
  }

  static Future<void> applyToSource(Player player, PlayerSource source) async {
    final platform = player.platform;
    if (platform is! NativePlayer) return;
    final properties = sourceProperties(
      uri: source.uri,
      declaredFormat: declaredStreamFormatOf(source),
      proxy: PlaybackProxyPolicy.currentNativeUrl(privateInput: false),
    );
    developer.log('${source.uri.host} -> $properties', name: 'PlaybackProxy');
    for (final entry in properties.entries) {
      await platform.setProperty(entry.key, entry.value);
    }
  }

  /// Whether the super-resolution shaders should mount on this machine.
  static bool get superResolutionAvailable => Platform.isWindows;

  static SuperResolutionMode get _superResolution =>
      SuperResolutionMode.fromName(SettingsService.to.player.superResolutionMode.v);
}
