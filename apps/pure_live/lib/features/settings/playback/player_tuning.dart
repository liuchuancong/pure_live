import 'dart:convert' show jsonDecode, jsonEncode;

import 'package:flutter/foundation.dart' show TargetPlatform, defaultTargetPlatform, kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_storage/live_storage.dart' show StoragePrefs;
import 'package:media_core/media_core.dart' show EngineOption;

import 'package:pure_live/app/providers/network/network_providers.dart' show appProxyEndpoint, proxySettingsProvider;
import 'package:pure_live/app/providers/network/system_proxy_provider.dart' show systemProxyProvider;
import 'package:pure_live/features/settings/playback/playback_settings_providers.dart' show playbackSettingsProvider;

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

  /// Output picks this recipe owns, so the advanced page can mark the
  /// matching rows as preset-locked instead of pretending they are free.
  Set<String> get lockedOutputKeys => switch (this) {
    PlayerPresetId.compat => const {'vo', 'hwdec'},
    PlayerPresetId.rtxVsr => const {'hwdec'},
    _ => const {},
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

/// How the player's own streams reach the network.
///
/// mpv opens those streams itself — the app's transport never carries them —
/// so the choice stays the player's. [followApp] is what makes one proxy
/// enough for both: the endpoint is taken from the app proxy, already resolved
/// from its own mode and the system reading.
enum PlayerProxyMode {
  /// Direct, no proxy.
  off,

  /// Whatever the app proxy resolves to, host and port included.
  followApp,

  /// The host and port typed on the player's own proxy page.
  manual,
}

/// The player's proxy: the mode in force and, for [PlayerProxyMode.manual],
/// the endpoint mpv is given.
typedef PlayerProxySettings = ({PlayerProxyMode mode, String host, int port});

/// The reference's default player proxy port (`defaultProxyPort`).
const int kDefaultPlayerProxyPort = 7897;

/// A fresh store follows the app proxy: one switch then covers the player too,
/// and while the app proxy is off the route resolves to a direct one, which is
/// exactly what the old default meant. An existing store keeps its own answer.
const PlayerProxySettings kDefaultPlayerProxy = (
  mode: PlayerProxyMode.followApp,
  host: '',
  port: kDefaultPlayerProxyPort,
);

/// Repairs a typed or restored proxy host the way the reference's
/// `normalizeProxyHost` does: a Chinese keyboard's full-width dot, colon and
/// brackets would otherwise resolve as one DNS name, and whitespace inside
/// the endpoint is never meaningful.
String normalizePlayerProxyHost(String value) => value
    .trim()
    .replaceAll('。', '.')
    .replaceAll('．', '.')
    .replaceAll('：', ':')
    .replaceAll('［', '[')
    .replaceAll('］', ']')
    .replaceAll(RegExp(r'\s+'), '');

/// Repairs a persisted or imported port; an invalid value falls back to the
/// reference's 7897 instead of leaving playback without a proxy.
int normalizePlayerProxyPort(int? port) => port != null && port >= 1 && port <= 65535 ? port : kDefaultPlayerProxyPort;

/// The stored endpoint with its host and port repaired.
PlayerProxySettings normalizePlayerProxy(PlayerProxySettings value) =>
    (mode: value.mode, host: normalizePlayerProxyHost(value.host), port: normalizePlayerProxyPort(value.port));

/// The engine option for [proxy].
///
/// The key is always sent, with an empty value when the proxy is off (the
/// reference passes it the same way): an empty mpv `http-proxy` means direct
/// and clears a route left by an earlier value. IPv6 literals are bracketed so
/// the URL stays parseable.
EngineOption playerProxyEngineOption(PlayerProxySettings proxy) {
  final normalized = normalizePlayerProxy(proxy);
  if (normalized.mode == PlayerProxyMode.off || normalized.host.isEmpty) {
    return const EngineOption('http-proxy', '');
  }
  final host = normalized.host;
  final endpointHost = host.contains(':') && !host.startsWith('[') && !host.endsWith(']') ? '[$host]' : host;
  return EngineOption('http-proxy', 'http://$endpointHost:${normalized.port}');
}

/// The engines' driver/decoder catalogues, per platform. Values are mpv's
/// own keys; the labels the UI shows are the keys unless a friendlier word
/// exists in the locale bundle.
List<String> playerVideoOutputOptions(TargetPlatform platform) => switch (platform) {
  TargetPlatform.windows => const ['auto', 'libmpv', 'gpu', 'gpu-next', 'direct3d', 'null'],
  TargetPlatform.android => const ['auto', 'gpu', 'gpu-next', 'libmpv', 'mediacodec_embed', 'null'],
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

/// The hwdec values each platform's mpv build accepts, in display order
/// (auto first, concrete backends next, software decoding last). The
/// reference keeps `no` out of the picker because its hardware-decoding
/// switch covers it; our custom-output mode disables that switch, so `no`
/// stays here as the explicit software route.
List<String> playerHardwareDecoderOptions(TargetPlatform platform) => switch (platform) {
  TargetPlatform.windows => const [
    'auto',
    'auto-safe',
    'auto-copy',
    'd3d11va',
    'd3d11va-copy',
    'nvdec',
    'nvdec-copy',
    'no',
  ],
  TargetPlatform.android => const [
    'auto',
    'auto-safe',
    'auto-unsafe',
    'yes',
    'auto-copy',
    'mediacodec',
    'mediacodec-copy',
    'no',
  ],
  TargetPlatform.iOS ||
  TargetPlatform.macOS => const ['auto', 'auto-safe', 'auto-copy', 'videotoolbox', 'videotoolbox-copy', 'no'],
  TargetPlatform.linux => const [
    'auto',
    'auto-safe',
    'auto-copy',
    'vaapi',
    'vaapi-copy',
    'vdpau',
    'nvdec',
    'nvdec-copy',
    'no',
  ],
  _ => const ['auto', 'auto-safe', 'auto-copy', 'no'],
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

/// The video-sync mode in use. The reference migrates the legacy `auto`
/// spelling to `audio` on startup; any other value this build does not offer
/// falls back to that same engine default instead of being sent verbatim.
String normalizePlayerVideoSync(String value) => playerVideoSyncOptions.contains(value) ? value : 'audio';

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

/// The deinterlace mode in use. The reference keeps only these three values;
/// anything else is sent to mpv verbatim, which can be rejected, so unknown
/// values fall back to the engine default instead.
String normalizePlayerDeinterlace(String value) => playerDeinterlaceOptions.contains(value) ? value : 'auto';

List<String> playerHwdecCodecOptions(TargetPlatform platform) => switch (platform) {
  TargetPlatform.android => const ['h264,hevc', 'h264,hevc,vp9', 'all'],
  _ => const ['all', 'h264,hevc', 'h264,hevc,vp9', 'h264,hevc,vp9,av1'],
};

List<String> playerAudioExclusiveOptions(TargetPlatform platform) =>
    platform == TargetPlatform.windows ? const ['no', 'yes'] : const [];

/// The output driver in use on [platform]. A pick written on another
/// platform (a preset, or a restored backup) may name a driver this engine
/// does not compile; the automatic value is used instead of sending it.
String effectivePlayerVideoOutput(String value, TargetPlatform platform) {
  final options = playerVideoOutputOptions(platform);
  return options.contains(value) ? value : 'auto';
}

/// The audio driver in use on [platform], repaired the same way.
String effectivePlayerAudioOutput(String value, TargetPlatform platform) {
  final options = playerAudioOutputOptions(platform);
  return options.contains(value) ? value : 'auto';
}

/// The hardware decoder in use on [platform]; an unknown pick falls back to
/// the reference's `auto-safe` instead of silently decoding in software.
String effectivePlayerHardwareDecoder(String value, TargetPlatform platform) {
  final options = playerHardwareDecoderOptions(platform);
  return options.contains(value) ? value : 'auto-safe';
}

/// Whether hardware decoding is actually in force. With custom output on,
/// its decoder pick replaces the hardware-decoding switch, so `no` means
/// software decoding even while the switch still reads on; with it off, the
/// switch alone decides.
bool playerHardwareDecodingActive({required bool hardwareDecoding, required PlayerTuning tuning}) =>
    tuning.customOutput ? tuning.hwdec != 'no' : hardwareDecoding;

/// The `hwdec` write every playback surface sends.
///
/// The reference's custom-output switch arms the three expert picks and
/// replaces the hardware-decoding switch while it is on (3.x
/// `media_kit_live_properties.dart` `_output`, v5
/// `MpvEngineConfig.preferredHardwareDecoder`); with the switch off, the
/// decoder pick is inert and the hardware-decoding preference alone decides
/// between `auto-safe` and `no`.
EngineOption playerHardwareDecodingOption({
  required bool hardwareDecoding,
  required PlayerTuning tuning,
  TargetPlatform? platform,
}) {
  final target = platform ?? defaultTargetPlatform;
  if (tuning.customOutput) {
    return EngineOption('hwdec', effectivePlayerHardwareDecoder(tuning.hwdec, target));
  }
  return EngineOption('hwdec', hardwareDecoding ? 'auto-safe' : 'no');
}

/// The `vo` / `ao` writes: only the custom-output switch arms them, and only
/// a concrete driver is sent — `auto` leaves the engine's own default alone,
/// the same way 3.x passes nothing for it.
List<EngineOption> playerOutputEngineOptions({
  required bool hardwareDecoding,
  required PlayerTuning tuning,
  TargetPlatform? platform,
}) {
  final target = platform ?? defaultTargetPlatform;
  return [
    playerHardwareDecodingOption(hardwareDecoding: hardwareDecoding, tuning: tuning, platform: target),
    if (tuning.customOutput) ...[
      if (effectivePlayerVideoOutput(tuning.vo, target) case final vo when vo != 'auto') EngineOption('vo', vo),
      if (effectivePlayerAudioOutput(tuning.ao, target) case final ao when ao != 'auto') EngineOption('ao', ao),
    ],
  ];
}

/// Whether an output driver changed; the render context is bound to it, so a
/// running engine must be rebuilt rather than just reconfigured.
bool playerOutputChanged(PlayerTuning previous, PlayerTuning next) =>
    previous.customOutput != next.customOutput || previous.vo != next.vo || previous.ao != next.ao;

/// The options a playback surface stores for its next open: the output
/// drivers (with the custom-output gate and the hardware-decoding switch),
/// the codec mask, interpolation, the scale kernel, the Windows exclusive-audio
/// switch, the active preset's engine properties and the player proxy. The
/// live room layers its full [playerTuningOptions] over them when the tuning
/// changes.
List<EngineOption> playerStoredEngineOptions({
  required bool hardwareDecoding,
  required PlayerTuning tuning,
  required PlayerProxySettings proxy,
}) => [
  ...playerOutputEngineOptions(hardwareDecoding: hardwareDecoding, tuning: tuning),
  // The reference narrows the engine's codec list only when the pick differs
  // from `all`; the default leaves the engine's own list alone. Stored with
  // the outputs so a new line, engine or app start keeps a narrowed mask.
  if (playerHardwareDecodingActive(hardwareDecoding: hardwareDecoding, tuning: tuning) && tuning.hwdecCodecs != 'all')
    EngineOption('hwdec-codecs', tuning.hwdecCodecs),
  // Stored with the outputs: a new line, engine or app start must keep the
  // viewer's interpolation choice, not only a live tuning change.
  EngineOption('interpolation', tuning.interpolation ? 'yes' : 'no'),
  // The reference sends the scale kernel as an engine property on every
  // open, so a restart must not fall back to the engine default.
  EngineOption('scale', tuning.scale),
  // The Windows WASAPI switch belongs to every adapter's option list too:
  // IPTV, VOD and multiview only apply the stored set, so a new channel,
  // line or engine must not silently fall back to shared mode.
  if (playerAudioExclusiveOptions(defaultTargetPlatform).isNotEmpty)
    EngineOption('audio-exclusive', tuning.audioExclusive ? 'yes' : 'no'),
  // Every preset spells out its own demuxer/cache/filter recipe; a new room,
  // channel, line or recovery has to be born with it, not wait for a live
  // tuning change that may never come.
  for (final entry in tuning.preset.extraProperties.entries) EngineOption(entry.key, entry.value),
  playerProxyEngineOption(proxy),
];

/// Values that undo a preset's engine properties when another recipe takes
/// over. A handle remembers every option it has been given and replays them
/// after a rebuild, so switching has to overwrite the keys the previous
/// recipe owned. Values follow the reference's live tuning baseline or mpv's
/// own default rather than inventing a new setting.
const Map<String, String> _presetNeutralProperties = {
  'vf': '',
  'vd-lavc-threads': '0',
  'vd-lavc-o': 'lowres=0',
  'vd-lavc-skiploopfilter': 'default',
  'audio-buffer': '0.2',
  'demuxer-max-bytes': '100663296',
  'demuxer-readahead-secs': '8',
  'cache-secs': '30',
  'cache': 'yes',
  'cache-pause': 'yes',
  'framedrop': 'decoder+vo',
  'network-timeout': '15',
  'stream-lavf-o': '',
};

/// The options that clear what [previous] installed and [next] does not set
/// again. Applying the next recipe's own properties on top leaves a new
/// preset's values in force; the keys it does not mention return to the
/// engine baseline instead of keeping the old recipe's buffer or filter.
List<EngineOption> playerPresetTransitionOptions(PlayerTuning previous, PlayerTuning next) {
  if (previous.preset == next.preset) return const [];
  final nextKeys = next.preset.extraProperties.keys.toSet();
  return [
    for (final key in previous.preset.extraProperties.keys)
      if (!nextKeys.contains(key))
        if (_presetNeutralProperties[key] case final value?) EngineOption(key, value),
  ];
}

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
    ...playerOutputEngineOptions(hardwareDecoding: hardwareDecoding, tuning: tuning, platform: platform),
    EngineOption('video-sync', tuning.videoSync),
    EngineOption('interpolation', tuning.interpolation ? 'yes' : 'no'),
    EngineOption('scale', tuning.scale),
    EngineOption('deinterlace', tuning.deinterlace),
    // Same gate as the stored set: custom output may decode in software, and
    // `all` is the engine's own list rather than a mask to write.
    if (playerHardwareDecodingActive(hardwareDecoding: hardwareDecoding, tuning: tuning) && tuning.hwdecCodecs != 'all')
      EngineOption('hwdec-codecs', tuning.hwdecCodecs),
    if (playerAudioExclusiveOptions(platform).isNotEmpty)
      EngineOption('audio-exclusive', tuning.audioExclusive ? 'yes' : 'no'),
    for (final entry in tuning.preset.extraProperties.entries) EngineOption(entry.key, entry.value),
    playerProxyEngineOption(proxy),
  ];
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
    // Reference segments are stored per engine and platform, so a preset
    // never crosses devices. One shared segment can (a backup or a synced
    // prefs store). An Android-only or Windows-only recipe must not send its
    // filter/decoder keys to an engine that cannot take them, and the default
    // output take-over belongs to that platform only.
    final storedPreset = PlayerPresetId.fromName(decoded['preset']);
    final presetHere = storedPreset.availableHere;
    return (
      customOutput: presetHere && read('customOutput', kDefaultPlayerTuning.customOutput)!,
      vo: presetHere
          ? effectivePlayerVideoOutput(read('vo', kDefaultPlayerTuning.vo)!, defaultTargetPlatform)
          : kDefaultPlayerTuning.vo,
      ao: effectivePlayerAudioOutput(read('ao', kDefaultPlayerTuning.ao)!, defaultTargetPlatform),
      hwdec: presetHere
          ? effectivePlayerHardwareDecoder(read('hwdec', kDefaultPlayerTuning.hwdec)!, defaultTargetPlatform)
          : kDefaultPlayerTuning.hwdec,
      videoSync: normalizePlayerVideoSync(read('videoSync', kDefaultPlayerTuning.videoSync)!),
      interpolation: read('interpolation', kDefaultPlayerTuning.interpolation)!,
      scale: read('scale', kDefaultPlayerTuning.scale)!,
      deinterlace: normalizePlayerDeinterlace(read('deinterlace', kDefaultPlayerTuning.deinterlace)!),
      hwdecCodecs: read('hwdecCodecs', kDefaultPlayerTuning.hwdecCodecs)!,
      audioExclusive: read('audioExclusive', kDefaultPlayerTuning.audioExclusive)!,
      forceDestroy: read('forceDestroy', kDefaultPlayerTuning.forceDestroy)!,
      preset: presetHere ? storedPreset : PlayerPresetId.balanced,
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
    if (!preset.availableHere) return;
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

  /// Restores the kernel page's own fields, matching the reference's
  /// `kernelSettings` reset: hardware decoding, presets, custom output and the
  /// three drivers. Advanced mpv options (sync, scaling, deinterlacing,
  /// codec mask, exclusive audio) and the preferred qualities stay as set.
  Future<void> resetKernelDefaults() => _write((
    customOutput: kDefaultPlayerTuning.customOutput,
    vo: kDefaultPlayerTuning.vo,
    ao: kDefaultPlayerTuning.ao,
    hwdec: kDefaultPlayerTuning.hwdec,
    videoSync: state.videoSync,
    interpolation: state.interpolation,
    scale: state.scale,
    deinterlace: state.deinterlace,
    hwdecCodecs: state.hwdecCodecs,
    audioExclusive: state.audioExclusive,
    forceDestroy: kDefaultPlayerTuning.forceDestroy,
    preset: kDefaultPlayerTuning.preset,
  ));
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
      return normalizePlayerProxy((
        mode: switch (decoded['mode']) {
          'followApp' => PlayerProxyMode.followApp,
          'manual' => PlayerProxyMode.manual,
          'off' => PlayerProxyMode.off,
          // The builds before the modes stored one boolean, whose "on" could
          // only ever have meant the typed endpoint beside it.
          _ => decoded['enabled'] == true ? PlayerProxyMode.manual : PlayerProxyMode.off,
        },
        host: decoded['host'] is String ? decoded['host'] as String : '',
        port: decoded['port'] is int ? decoded['port'] as int : kDefaultPlayerProxyPort,
      ));
    } on Object {
      return kDefaultPlayerProxy;
    }
  }

  Future<void> save(PlayerProxySettings value) async {
    final normalized = normalizePlayerProxy(value);
    state = normalized;
    try {
      await StoragePrefs.setString(
        _key,
        jsonEncode({'mode': normalized.mode.name, 'host': normalized.host, 'port': normalized.port}),
      );
    } on Object {
      // A preference; a closed store loses it.
    }
  }
}

final playerProxyProvider = NotifierProvider<PlayerProxyController, PlayerProxySettings>(PlayerProxyController.new);

/// The proxy the player actually runs with: [playerProxyProvider] with a
/// follow-the-app choice answered by the app's own resolved endpoint.
///
/// Every playback surface reads and listens to this rather than the stored
/// choice, so typing an address on the network page — or a system proxy
/// appearing after start-up — reaches a player that is already open.
final effectivePlayerProxyProvider = Provider<PlayerProxySettings>((ref) {
  final proxy = ref.watch(playerProxyProvider);
  if (proxy.mode != PlayerProxyMode.followApp) return proxy;
  final endpoint = appProxyEndpoint(ref.watch(proxySettingsProvider), ref.watch(systemProxyProvider));
  if (endpoint == null) return kDefaultPlayerProxy;
  return (mode: PlayerProxyMode.manual, host: endpoint.host, port: endpoint.port);
});
