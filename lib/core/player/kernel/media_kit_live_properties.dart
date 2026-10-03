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

    // 播放器代理必须落到引擎上：直连播放时只有引擎自己会去连上游，而中继路径
    // 早就通过 PlaybackProxyPolicy 拿到了代理，唯独直连这条没有——必须代理才
    // 可达的 CDN（Twitch 的 playlist.ttvnw.net 直连握手要 9 秒以上）会在
    // "8 秒卡在 0ms" 的看门狗之前连不上，报 NO_PLAYABLE_STREAM。
    // 空串即"不用代理"，与 owned_input_opener 对私有输入清除代理的语义一致。
    final String proxy = PlaybackProxyPolicy.currentNativeUrl(privateInput: false);
    properties['http-proxy'] = proxy;
    // 应用代理与播放器代理是两套开关，界面之外看不出播放器这一套到底生没生效，
    // 而"能列出房间却播不动"正是它没生效的样子，所以每次装配都记一行。
    developer.log(proxy.isEmpty ? 'direct (no player or system proxy)' : proxy, name: 'PlaybackProxy');

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

  /// 按源决定的 mpv 属性。
  ///
  /// 装配期那张表整个引擎生命周期只有一份，而这两项每条源都不一样：本机输入不能
  /// 走代理，容器格式只有解析播放地址的平台知道。[proxy] 由调用方从
  /// `PlaybackProxyPolicy` 取好再传进来，判定本身就是纯函数。
  static Map<String, String> sourceProperties({
    required Uri uri,
    required String? declaredFormat,
    required String proxy,
  }) {
    final bool privateInput = isPrivatePlaybackInput(uri);
    // 声明优先，其次 URL 形状（Twitch 那种把签名塞进路径的 `/v1/playlist/….m3u8`
    // 也认得出）。本机输入两者都不看：探测本机几乎不要钱，而 Dart 重写的 HEVC FLV
    // 中继输出的根本不是 HLS，指死解复用器只会把它打死。
    final String? format = privateInput ? null : declaredFormat ?? (isHlsManifestUri(uri) ? 'hls' : null);
    return <String, String>{
      'http-proxy': privateInput ? '' : proxy,
      // 指死解复用器就跳过了 mpv 的格式探测：2MB 的 probesize 在高延迟线路上正好
      // 吃掉"8 秒卡在 0ms 判死"的那份起播预算。空串是清除——引擎是跨源复用的，
      // 上一条源强制的 hls 不能漏到这一条 FLV 上。
      'demuxer-lavf-format': format == 'hls' ? 'hls' : '',
    };
  }

  /// 把 [sourceProperties] 写到即将打开这条源的引擎上。
  ///
  /// 挂在 media_kit 适配器的 `beforeOpen`：引擎已经存在、还没拿到 URL，属性正好
  /// 落在这次打开上，而且在打开窗口之外，引擎事件不会被误判成打开失败。
  static Future<void> applyToSource(Player player, PlayerSource source) async {
    final platform = player.platform;
    if (platform is! NativePlayer) return;
    final properties = sourceProperties(
      uri: source.uri,
      declaredFormat: declaredStreamFormatOf(source),
      proxy: PlaybackProxyPolicy.currentNativeUrl(privateInput: false),
    );
    for (final entry in properties.entries) {
      await platform.setProperty(entry.key, entry.value);
    }
  }

  /// Whether the super-resolution shaders should mount on this machine.
  static bool get superResolutionAvailable => Platform.isWindows;

  static SuperResolutionMode get _superResolution =>
      SuperResolutionMode.fromName(SettingsService.to.player.superResolutionMode.v);
}
