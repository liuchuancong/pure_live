import 'dart:convert' show jsonDecode, jsonEncode;

import 'package:flutter/foundation.dart' show TargetPlatform, defaultTargetPlatform, kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_storage/live_storage.dart' show StoragePrefs;
import 'package:media_core/media_core.dart' show EngineOption;

import 'package:pure_live/features/settings/playback_settings_providers.dart' show playbackSettingsProvider;

/// One-click tuning recipes, the old client's six presets.
enum PlayerPresetId {
  balanced,
  compat,
  rtxVsr,
  lowEnd,
  stableNetwork,
  lowLatency;

  /// Whether the recipe applies on this platform.
  bool get availableHere => switch (this) {
    PlayerPresetId.compat => !kIsWeb && defaultTargetPlatform == TargetPlatform.android,
    PlayerPresetId.rtxVsr => !kIsWeb && defaultTargetPlatform == TargetPlatform.windows,
    _ => true,
  };

  /// The output picks this recipe takes over (null leaves the current
  /// value / engine default).
  ({String? vo, String? hwdec, bool? hardwareDecoding}) get outputOverride => switch (this) {
    PlayerPresetId.compat => (vo: 'mediacodec_embed', hwdec: 'mediacodec', hardwareDecoding: true),
    PlayerPresetId.rtxVsr => (vo: null, hwdec: 'd3d11va', hardwareDecoding: true),
    PlayerPresetId.lowEnd => (vo: null, hwdec: null, hardwareDecoding: false),
    _ => (vo: null, hwdec: null, hardwareDecoding: null),
  };

  /// mpv properties layered over the base tuning for this recipe.
  Map<String, String> get extraProperties => switch (this) {
    PlayerPresetId.rtxVsr => const {'vf': 'd3d11vpp=scale=2:scaling-mode=nvidia'},
    PlayerPresetId.lowEnd => const {
      'vd-lavc-threads': '2',
      'vd-lavc-o': 'lowres=1',
      'vd-lavc-skiploopfilter': 'nonref',
      'audio-buffer': '0.4',
      'demuxer-max-bytes': '41943040',
      'demuxer-readahead-secs': '4',
    },
    PlayerPresetId.stableNetwork => const {
      'cache-secs': '120',
      'demuxer-readahead-secs': '30',
      'stream-lavf-o': 'reconnect=1,reconnect_streamed=1,reconnect_on_network_error=1,reconnect_delay_max=7',
    },
    PlayerPresetId.lowLatency => const {
      'cache': 'no',
      'demuxer-readahead-secs': '1',
      'cache-pause': 'no',
      'framedrop': 'decoder+vo',
      'network-timeout': '8',
    },
    _ => const {},
  };

  static PlayerPresetId fromName(Object? name) =>
      PlayerPresetId.values.firstWhere((preset) => preset.name == name, orElse: () => PlayerPresetId.balanced);
}

/// The mpv tuning the kernel page edits. Hardware decoding itself stays in
/// [playbackSettingsProvider] (it is a playback preference too), so this
/// holds only the engine's output/decoder options.
typedef PlayerTuning = ({
  bool customOutput,
  String vo,
  String ao,
  String hwdec,
  String videoSync,
  bool interpolation,
  String scale,
  String deinterlace,
  String hwdecCodecs,
  bool audioExclusive,
  bool forceDestroy,
  PlayerPresetId preset,
});

const PlayerTuning kDefaultPlayerTuning = (
  customOutput: false,
  vo: 'auto',
  ao: 'auto',
  hwdec: 'auto-safe',
  videoSync: 'audio',
  interpolation: false,
  scale: 'lanczos',
  deinterlace: 'auto',
  hwdecCodecs: 'all',
  audioExclusive: false,
  forceDestroy: false,
  preset: PlayerPresetId.balanced,
);

/// The player's own HTTP proxy. It is separate from the app proxy: mpv
/// opens its own streams, and the two must not silently share a host.
typedef PlayerProxySettings = ({bool enabled, String host, int port});

const PlayerProxySettings kDefaultPlayerProxy = (enabled: false, host: '', port: 0);

/// The engines' driver/decoder catalogues, per platform. Values are mpv's
/// own keys; the labels the UI shows are the keys unless a friendlier word
/// exists in the locale bundle.
List<String> playerVideoOutputOptions(TargetPlatform platform) => switch (platform) {
  TargetPlatform.windows => const ['auto', 'libmpv', 'gpu', 'gpu-next', 'direct3d', 'null'],
  TargetPlatform.android => const ['auto', 'mediacodec_embed'],
  TargetPlatform.iOS => const ['auto', 'libmpv'],
  _ => const ['auto', 'libmpv'],
};

List<String> playerAudioOutputOptions(TargetPlatform platform) => switch (platform) {
  TargetPlatform.android => const ['auto', 'audiotrack', 'aaudio', 'opensles', 'null'],
  TargetPlatform.iOS => const ['auto', 'audiounit', 'null'],
  TargetPlatform.windows => const ['auto', 'wasapi', 'win32', 'sdl', 'pcm', 'null'],
  TargetPlatform.macOS => const ['auto', 'audiounit', 'sdl', 'null'],
  TargetPlatform.linux => const ['auto', 'alsa', 'pipewire', 'sdl', 'null'],
  _ => const ['auto', 'null'],
};

List<String> playerHardwareDecoderOptions(TargetPlatform platform) => switch (platform) {
  TargetPlatform.windows => const [
    'auto-safe',
    'auto',
    'auto-copy',
    'd3d11va',
    'd3d11va-copy',
    'nvdec',
    'nvdec-copy',
    'no',
  ],
  TargetPlatform.android => const ['auto-safe', 'auto', 'auto-copy', 'mediacodec', 'mediacodec-copy', 'no'],
  TargetPlatform.iOS ||
  TargetPlatform.macOS => const ['auto-safe', 'auto', 'auto-copy', 'videotoolbox', 'videotoolbox-copy', 'no'],
  TargetPlatform.linux => const [
    'auto-safe',
    'auto',
    'auto-copy',
    'vaapi',
    'vaapi-copy',
    'vdpau',
    'nvdec',
    'nvdec-copy',
    'no',
  ],
  _ => const ['auto-safe', 'auto', 'auto-copy', 'no'],
};

const List<String> playerVideoSyncOptions = [
  'audio',
  'display-resample',
  'display-resample-vdrop',
  'display-resample-drop',
  'display-adrop',
  'display-vdrop',
  'display-desync',
  'desync',
];

List<String> playerScaleOptions(TargetPlatform platform) => switch (platform) {
  TargetPlatform.android || TargetPlatform.iOS => const ['lanczos', 'bilinear'],
  _ => const [
    'lanczos',
    'ewa_lanczossharp',
    'ewa_lanczos4sharpest',
    'ewa_lanczos',
    'spline36',
    'spline16',
    'catmull_rom',
    'mitchell',
    'hermite',
    'bicubic_fast',
    'bilinear',
    'nearest',
  ],
};

const List<String> playerDeinterlaceOptions = ['auto', 'no', 'yes'];

List<String> playerHwdecCodecOptions(TargetPlatform platform) => switch (platform) {
  TargetPlatform.android => const ['h264,hevc', 'h264,hevc,vp9', 'all'],
  _ => const ['all', 'h264,hevc', 'h264,hevc,vp9', 'h264,hevc,vp9,av1'],
};

List<String> playerAudioExclusiveOptions(TargetPlatform platform) =>
    platform == TargetPlatform.windows ? const ['no', 'yes'] : const [];

/// The options a media_kit handle receives for the current tuning. The
/// caller adds the super-resolution shader option; an unsupported option is
/// the engine's answer to accept, never a crash.
List<EngineOption> playerTuningOptions({
  required PlayerTuning tuning,
  required bool hardwareDecoding,
  required PlayerProxySettings proxy,
}) {
  final platform = defaultTargetPlatform;
  final options = <EngineOption>[
    EngineOption('hwdec', hardwareDecoding ? tuning.hwdec : 'no'),
    if (tuning.customOutput) EngineOption('vo', tuning.vo),
    if (tuning.customOutput) EngineOption('ao', tuning.ao),
    EngineOption('video-sync', tuning.videoSync),
    EngineOption('interpolation', tuning.interpolation ? 'yes' : 'no'),
    EngineOption('scale', tuning.scale),
    EngineOption('deinterlace', tuning.deinterlace),
    if (hardwareDecoding) EngineOption('hwdec-codecs', tuning.hwdecCodecs),
    if (platform == TargetPlatform.windows) EngineOption('audio-exclusive', tuning.audioExclusive ? 'yes' : 'no'),
    for (final entry in tuning.preset.extraProperties.entries) EngineOption(entry.key, entry.value),
  ];
  if (proxy.enabled && proxy.host.trim().isNotEmpty && proxy.port > 0) {
    options.add(EngineOption('http-proxy', 'http://${proxy.host.trim()}:${proxy.port}'));
  }
  return options;
}

String _encodeTuning(PlayerTuning tuning) => jsonEncode({
  'customOutput': tuning.customOutput,
  'vo': tuning.vo,
  'ao': tuning.ao,
  'hwdec': tuning.hwdec,
  'videoSync': tuning.videoSync,
  'interpolation': tuning.interpolation,
  'scale': tuning.scale,
  'deinterlace': tuning.deinterlace,
  'hwdecCodecs': tuning.hwdecCodecs,
  'audioExclusive': tuning.audioExclusive,
  'forceDestroy': tuning.forceDestroy,
  'preset': tuning.preset.name,
});

PlayerTuning _decodeTuning(String? raw) {
  if (raw == null || raw.isEmpty) return kDefaultPlayerTuning;
  try {
    final decoded = jsonDecode(raw);
    if (decoded is! Map) return kDefaultPlayerTuning;
    T? read<T>(String key, T? fallback) => decoded[key] is T ? decoded[key] as T : fallback;
    return (
      customOutput: read('customOutput', kDefaultPlayerTuning.customOutput)!,
      vo: read('vo', kDefaultPlayerTuning.vo)!,
      ao: read('ao', kDefaultPlayerTuning.ao)!,
      hwdec: read('hwdec', kDefaultPlayerTuning.hwdec)!,
      videoSync: read('videoSync', kDefaultPlayerTuning.videoSync)!,
      interpolation: read('interpolation', kDefaultPlayerTuning.interpolation)!,
      scale: read('scale', kDefaultPlayerTuning.scale)!,
      deinterlace: read('deinterlace', kDefaultPlayerTuning.deinterlace)!,
      hwdecCodecs: read('hwdecCodecs', kDefaultPlayerTuning.hwdecCodecs)!,
      audioExclusive: read('audioExclusive', kDefaultPlayerTuning.audioExclusive)!,
      forceDestroy: read('forceDestroy', kDefaultPlayerTuning.forceDestroy)!,
      preset: PlayerPresetId.fromName(decoded['preset']),
    );
  } on Object {
    return kDefaultPlayerTuning;
  }
}

/// The viewer's mpv tuning, persisted under `player.tuning`.
final class PlayerTuningController extends Notifier<PlayerTuning> {
  static const String _key = 'player.tuning';

  @override
  PlayerTuning build() {
    try {
      return _decodeTuning(StoragePrefs.getString(_key));
    } on Object {
      return kDefaultPlayerTuning;
    }
  }

  Future<void> _write(PlayerTuning next) async {
    state = next;
    try {
      await StoragePrefs.setString(_key, _encodeTuning(next));
    } on Object {
      // A preference; a closed store loses it.
    }
  }

  Future<void> setCustomOutput({required bool value}) => _write((
    customOutput: value,
    vo: state.vo,
    ao: state.ao,
    hwdec: state.hwdec,
    videoSync: state.videoSync,
    interpolation: state.interpolation,
    scale: state.scale,
    deinterlace: state.deinterlace,
    hwdecCodecs: state.hwdecCodecs,
    audioExclusive: state.audioExclusive,
    forceDestroy: state.forceDestroy,
    preset: state.preset,
  ));

  Future<void> setVo(String value) => _write((
    customOutput: state.customOutput,
    vo: value,
    ao: state.ao,
    hwdec: state.hwdec,
    videoSync: state.videoSync,
    interpolation: state.interpolation,
    scale: state.scale,
    deinterlace: state.deinterlace,
    hwdecCodecs: state.hwdecCodecs,
    audioExclusive: state.audioExclusive,
    forceDestroy: state.forceDestroy,
    preset: state.preset,
  ));

  Future<void> setAo(String value) => _write((
    customOutput: state.customOutput,
    vo: state.vo,
    ao: value,
    hwdec: state.hwdec,
    videoSync: state.videoSync,
    interpolation: state.interpolation,
    scale: state.scale,
    deinterlace: state.deinterlace,
    hwdecCodecs: state.hwdecCodecs,
    audioExclusive: state.audioExclusive,
    forceDestroy: state.forceDestroy,
    preset: state.preset,
  ));

  Future<void> setHwdec(String value) => _write((
    customOutput: state.customOutput,
    vo: state.vo,
    ao: state.ao,
    hwdec: value,
    videoSync: state.videoSync,
    interpolation: state.interpolation,
    scale: state.scale,
    deinterlace: state.deinterlace,
    hwdecCodecs: state.hwdecCodecs,
    audioExclusive: state.audioExclusive,
    forceDestroy: state.forceDestroy,
    preset: state.preset,
  ));

  Future<void> setVideoSync(String value) => _write((
    customOutput: state.customOutput,
    vo: state.vo,
    ao: state.ao,
    hwdec: state.hwdec,
    videoSync: value,
    interpolation: state.interpolation,
    scale: state.scale,
    deinterlace: state.deinterlace,
    hwdecCodecs: state.hwdecCodecs,
    audioExclusive: state.audioExclusive,
    forceDestroy: state.forceDestroy,
    preset: state.preset,
  ));

  Future<void> setInterpolation({required bool value}) => _write((
    customOutput: state.customOutput,
    vo: state.vo,
    ao: state.ao,
    hwdec: state.hwdec,
    videoSync: state.videoSync,
    interpolation: value,
    scale: state.scale,
    deinterlace: state.deinterlace,
    hwdecCodecs: state.hwdecCodecs,
    audioExclusive: state.audioExclusive,
    forceDestroy: state.forceDestroy,
    preset: state.preset,
  ));

  Future<void> setScale(String value) => _write((
    customOutput: state.customOutput,
    vo: state.vo,
    ao: state.ao,
    hwdec: state.hwdec,
    videoSync: state.videoSync,
    interpolation: state.interpolation,
    scale: value,
    deinterlace: state.deinterlace,
    hwdecCodecs: state.hwdecCodecs,
    audioExclusive: state.audioExclusive,
    forceDestroy: state.forceDestroy,
    preset: state.preset,
  ));

  Future<void> setDeinterlace(String value) => _write((
    customOutput: state.customOutput,
    vo: state.vo,
    ao: state.ao,
    hwdec: state.hwdec,
    videoSync: state.videoSync,
    interpolation: state.interpolation,
    scale: state.scale,
    deinterlace: value,
    hwdecCodecs: state.hwdecCodecs,
    audioExclusive: state.audioExclusive,
    forceDestroy: state.forceDestroy,
    preset: state.preset,
  ));

  Future<void> setHwdecCodecs(String value) => _write((
    customOutput: state.customOutput,
    vo: state.vo,
    ao: state.ao,
    hwdec: state.hwdec,
    videoSync: state.videoSync,
    interpolation: state.interpolation,
    scale: state.scale,
    deinterlace: state.deinterlace,
    hwdecCodecs: value,
    audioExclusive: state.audioExclusive,
    forceDestroy: state.forceDestroy,
    preset: state.preset,
  ));

  Future<void> setAudioExclusive({required bool value}) => _write((
    customOutput: state.customOutput,
    vo: state.vo,
    ao: state.ao,
    hwdec: state.hwdec,
    videoSync: state.videoSync,
    interpolation: state.interpolation,
    scale: state.scale,
    deinterlace: state.deinterlace,
    hwdecCodecs: state.hwdecCodecs,
    audioExclusive: value,
    forceDestroy: state.forceDestroy,
    preset: state.preset,
  ));

  Future<void> setForceDestroy({required bool value}) => _write((
    customOutput: state.customOutput,
    vo: state.vo,
    ao: state.ao,
    hwdec: state.hwdec,
    videoSync: state.videoSync,
    interpolation: state.interpolation,
    scale: state.scale,
    deinterlace: state.deinterlace,
    hwdecCodecs: state.hwdecCodecs,
    audioExclusive: state.audioExclusive,
    forceDestroy: value,
    preset: state.preset,
  ));

  /// Applies one recipe: its output picks, its hardware-decoding state and
  /// its extra mpv properties (read from [PlayerPresetId.extraProperties] by
  /// the engine-option builder).
  Future<void> applyPreset(PlayerPresetId preset) async {
    final override = preset.outputOverride;
    if (override.hardwareDecoding case final decoding?) {
      await ref.read(playbackSettingsProvider.notifier).setHardwareDecoding(value: decoding);
    }
    await _write((
      customOutput: override.vo != null || override.hwdec != null,
      vo: override.vo ?? 'auto',
      ao: state.ao,
      hwdec: override.hwdec ?? 'auto-safe',
      videoSync: state.videoSync,
      interpolation: state.interpolation,
      scale: state.scale,
      deinterlace: state.deinterlace,
      hwdecCodecs: state.hwdecCodecs,
      audioExclusive: state.audioExclusive,
      forceDestroy: state.forceDestroy,
      preset: preset,
    ));
  }

  /// Returns the tuning to its defaults; the hardware-decoding preference is
  /// the playback pane's and is reset there by the caller.
  Future<void> reset() => _write(kDefaultPlayerTuning);
}

final playerTuningProvider = NotifierProvider<PlayerTuningController, PlayerTuning>(PlayerTuningController.new);

/// The player's own proxy, persisted under `player.proxy`.
final class PlayerProxyController extends Notifier<PlayerProxySettings> {
  static const String _key = 'player.proxy';

  @override
  PlayerProxySettings build() {
    try {
      final raw = StoragePrefs.getString(_key);
      if (raw == null || raw.isEmpty) return kDefaultPlayerProxy;
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return kDefaultPlayerProxy;
      return (
        enabled: decoded['enabled'] == true,
        host: decoded['host'] is String ? decoded['host'] as String : '',
        port: decoded['port'] is int ? decoded['port'] as int : 0,
      );
    } on Object {
      return kDefaultPlayerProxy;
    }
  }

  Future<void> save(PlayerProxySettings value) async {
    state = value;
    try {
      await StoragePrefs.setString(
        _key,
        jsonEncode({'enabled': value.enabled, 'host': value.host, 'port': value.port}),
      );
    } on Object {
      // A preference; a closed store loses it.
    }
  }
}

final playerProxyProvider = NotifierProvider<PlayerProxyController, PlayerProxySettings>(PlayerProxyController.new);
