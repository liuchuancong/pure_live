import 'dart:io';

/// One-click tuning presets for a player engine.
///
/// A preset is a complete, explainable recipe — output picks plus the mpv
/// properties behind it — instead of a dozen scattered switches. Applied
/// per engine and per platform group, so Android and Windows can carry
/// different recipes at the same time.
enum PlayerPresetId {
  /// Engine defaults; the app only adds its live-stream tuning table.
  balanced,

  /// Android compatibility: `mediacodec_embed` surface + `mediacodec`
  /// decode, for devices where the default surface path glitches.
  compat,

  /// NVIDIA RTX Video Super Resolution on Windows (d3d11va + d3d11vpp).
  rtxVsr,

  /// Weak hardware: software decode with capped threads, lowres and a
  /// small buffer, so a weak box stays smooth instead of stuttering.
  lowEnd,

  /// Unstable networks: a large demuxer budget and aggressive reconnect,
  /// trading memory for fewer stalls.
  stableNetwork,

  /// Lowest latency: small buffers and forward frame dropping, for
  /// watching over a fast link where delay matters more than hiccups.
  lowLatency,
}

/// Per-engine, per-platform-group output settings.
///
/// One segment holds everything an engine needs to build its output:
/// hardware acceleration, manual vo/hwdec picks and the audio output.
/// Segments are stored separately for each engine and each platform
/// group, so an Android pick never leaks onto Windows.
class PlayerEngineOutput {
  const PlayerEngineOutput({
    this.presetId = PlayerPresetId.balanced,
    this.enableCodec = true,
    this.customPlayerOutput = false,
    this.videoOutputDriver = 'auto',
    this.videoHardwareDecoder = 'auto-safe',
    this.audioOutputDriver = 'auto',
    this.videoSync = 'audio',
    this.interpolation = 'no',
    this.scale = 'lanczos',
    this.deinterlace = 'auto',
    this.hwdecCodecs = 'all',
    this.audioExclusive = 'no',
  });

  /// The tuning recipe this segment follows.
  final PlayerPresetId presetId;

  /// Whether hardware decoding is allowed at all.
  final bool enableCodec;

  /// Whether the manual vo/hwdec picks below are applied.
  final bool customPlayerOutput;

  /// Manual video output driver (mpv `vo`), engine-spelled.
  final String videoOutputDriver;

  /// Manual hardware decoder (mpv `hwdec`), engine-spelled.
  final String videoHardwareDecoder;

  /// Manual audio output driver (mpv `ao`), engine-spelled.
  final String audioOutputDriver;

  /// mpv `video-sync` mode.
  final String videoSync;

  /// mpv `interpolation`.
  final String interpolation;

  /// mpv `scale` (upscale kernel).
  final String scale;

  /// mpv `deinterlace`.
  final String deinterlace;

  /// mpv `hwdec-codecs`.
  final String hwdecCodecs;

  /// mpv `audio-exclusive` (Windows).
  final String audioExclusive;

  PlayerEngineOutput copyWith({
    PlayerPresetId? presetId,
    bool? enableCodec,
    bool? customPlayerOutput,
    String? videoOutputDriver,
    String? videoHardwareDecoder,
    String? audioOutputDriver,
  }) {
    return PlayerEngineOutput(
      presetId: presetId ?? this.presetId,
      enableCodec: enableCodec ?? this.enableCodec,
      customPlayerOutput: customPlayerOutput ?? this.customPlayerOutput,
      videoOutputDriver: videoOutputDriver ?? this.videoOutputDriver,
      videoHardwareDecoder: videoHardwareDecoder ?? this.videoHardwareDecoder,
      audioOutputDriver: audioOutputDriver ?? this.audioOutputDriver,
    );
  }

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'preset': presetId.name,
      'enableCodec': enableCodec,
      'customPlayerOutput': customPlayerOutput,
      'videoOutputDriver': videoOutputDriver,
      'videoHardwareDecoder': videoHardwareDecoder,
      'audioOutputDriver': audioOutputDriver,
      'videoSync': videoSync,
      'interpolation': interpolation,
      'scale': scale,
      'deinterlace': deinterlace,
      'hwdecCodecs': hwdecCodecs,
      'audioExclusive': audioExclusive,
    };
  }

  static PlayerEngineOutput fromJson(Object? json) {
    if (json is! Map) return const PlayerEngineOutput();

    return PlayerEngineOutput(
      presetId: PlayerPresetId.values.firstWhere(
        (id) => id.name == json['preset'],
        orElse: () => PlayerPresetId.balanced,
      ),
      enableCodec: json['enableCodec'] is bool ? json['enableCodec'] as bool : true,
      customPlayerOutput: json['customPlayerOutput'] is bool ? json['customPlayerOutput'] as bool : false,
      videoOutputDriver: json['videoOutputDriver'] is String ? json['videoOutputDriver'] as String : 'auto',
      videoHardwareDecoder: json['videoHardwareDecoder'] is String ? json['videoHardwareDecoder'] as String : 'auto-safe',
      audioOutputDriver: json['audioOutputDriver'] is String ? json['audioOutputDriver'] as String : 'auto',
      videoSync: json['videoSync'] is String ? json['videoSync'] as String : 'audio',
      interpolation: json['interpolation'] is String ? json['interpolation'] as String : 'no',
      scale: json['scale'] is String ? json['scale'] as String : 'lanczos',
      deinterlace: json['deinterlace'] is String ? json['deinterlace'] as String : 'auto',
      hwdecCodecs: json['hwdecCodecs'] is String ? json['hwdecCodecs'] as String : 'all',
      audioExclusive: json['audioExclusive'] is String ? json['audioExclusive'] as String : 'no',
    );
  }
}

/// Everything a preset spells out, as data.
extension PlayerPresetDetail on PlayerPresetId {
  /// Translation key of the preset's display name.
  ///
  /// The name lives in the locale files like every other user-visible string:
  /// a table here would be one more place that shows Chinese in an English
  /// interface.
  String get nameKey => 'player_preset_$name';

  /// Translation key of the one-paragraph explanation on the guide page.
  String get descriptionKey => 'player_preset_${name}_desc';

  /// Whether this preset applies on the current platform at all.
  bool get availableOnCurrentPlatform => switch (this) {
    PlayerPresetId.compat => Platform.isAndroid,
    PlayerPresetId.rtxVsr => Platform.isWindows,
    _ => true,
  };

  /// Manual output picks the preset implies (null = leave the segment's
  /// own value / engine default).
  ({String? vo, String? hwdec, bool? enableCodec}) get outputOverride => switch (this) {
    PlayerPresetId.compat => (vo: 'mediacodec_embed', hwdec: 'mediacodec', enableCodec: true),
    PlayerPresetId.rtxVsr => (vo: null, hwdec: 'd3d11va', enableCodec: true),
    PlayerPresetId.lowEnd => (vo: null, hwdec: null, enableCodec: false),
    _ => (vo: null, hwdec: null, enableCodec: null),
  };

  /// Output picks this preset takes over, so the settings page can mark
  /// the matching tiles as locked instead of pretending they are free.
  Set<String> get lockedOutputKeys => switch (this) {
        PlayerPresetId.compat => const {'vo', 'hwdec'},
        PlayerPresetId.rtxVsr => const {'hwdec'},
        _ => const {},
      };

  /// mpv properties layered on top of the app's live tuning table when
  /// this preset is active. Empty for the balanced baseline.
  Map<String, String> get extraProperties => switch (this) {
    PlayerPresetId.rtxVsr => const <String, String>{'vf': 'd3d11vpp=scale=2:scaling-mode=nvidia'},
    PlayerPresetId.lowEnd => const <String, String>{
      'vd-lavc-threads': '2',
      'vd-lavc-o': 'lowres=1',
      'vd-lavc-skiploopfilter': 'nonref',
      'audio-buffer': '0.4',
      'demuxer-max-bytes': '41943040',
      'demuxer-readahead-secs': '4',
    },
    PlayerPresetId.stableNetwork => const <String, String>{
      'cache-secs': '120',
      'demuxer-readahead-secs': '30',
      'stream-lavf-o': 'reconnect=1,reconnect_streamed=1,reconnect_on_network_error=1,reconnect_delay_max=7',
    },
    PlayerPresetId.lowLatency => const <String, String>{
      'cache': 'no',
      'demuxer-readahead-secs': '1',
      'cache-pause': 'no',
      'framedrop': 'decoder+vo',
      'network-timeout': '8',
    },
    _ => const <String, String>{},
  };
}

/// Platform groups a settings segment can be stored under.
String platformGroupName() {
  if (Platform.isAndroid) return 'android';
  if (Platform.isIOS) return 'ios';
  if (Platform.isMacOS) return 'macos';
  if (Platform.isWindows) return 'windows';
  if (Platform.isLinux) return 'linux';
  return 'other';
}
