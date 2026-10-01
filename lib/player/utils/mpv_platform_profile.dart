import 'package:flutter/foundation.dart';
import 'package:pure_live/player/utils/player_consts.dart';

const Map<String, String> _iosVideoOutputDrivers = <String, String>{'libmpv': 'libmpv'};
const Map<String, String> _iosAudioOutputDrivers = <String, String>{
  'auto': 'auto',
  'audiounit': 'audiounit (iOS only)',
  'null': 'null (No audio output)',
};
const Map<String, String> _androidAudioOutputDrivers = <String, String>{
  'auto': 'auto (Automatic fallback)',
  'audiotrack': 'audiotrack (Android AudioTrack)',
  'aaudio': 'aaudio (Android 8.0+)',
  'opensles': 'opensles (Legacy fallback)',
  'null': 'null (No audio output)',
};
const Map<String, String> _iosHardwareDecoders = <String, String>{
  'auto': 'auto',
  'auto-safe': 'auto-safe',
  'auto-copy': 'auto-copy',
  'no': 'no',
  'videotoolbox': 'videotoolbox',
  'videotoolbox-copy': 'videotoolbox-copy',
};

/// Returns only native MPV outputs that the current settings UI may persist.
///
/// media_kit owns the iOS Flutter texture through `vo=libmpv`. Android exposes
/// only drivers compiled into the bundled libmpv instead of mixing Windows and
/// Linux choices into the phone settings menu.
/// Desktop libmpv is the ONLY vo that renders into the Flutter texture;
/// windowed drivers (gpu/gpu-next/direct3d/...) make mpv open its own
/// native window on top of the app — the "mpv window pops up over the
/// live room" report. The richer table stays available to standalone
/// mpv consumers, not to the embedded player settings.
// Per the mpv manual. The embedded player renders through libmpv's render
// API (the Flutter texture); windowed drivers draw into mpv's own window and
// are offered with an explicit warning label for users who want them anyway
// (D3D11 interop performance, standalone-style rendering). Each entry's
// second value is the severity marker consumed by the settings UI.
const Map<String, String> _windowsVideoOutputDrivers = <String, String>{
  'libmpv': 'ok',
  'gpu': 'window',
  'gpu-next': 'window',
  'direct3d': 'window',
  'null': 'novideo',
};

const Map<String, String> _desktopVideoOutputDrivers = <String, String>{
  'libmpv': 'libmpv',
};

Map<String, String> mpvVideoOutputDriversForPlatform(TargetPlatform platform) {
  if (platform == TargetPlatform.iOS) return _iosVideoOutputDrivers;
  if (platform == TargetPlatform.android) return PlayerConsts.videoOutputDrivers;
  if (platform == TargetPlatform.windows) return _windowsVideoOutputDrivers;
  return _desktopVideoOutputDrivers;
}

// mpv manual, audio output drivers on Windows: wasapi (default since
// mpv 0.30), win32 (waveOut, legacy), sdl2, pcm (dump), null.
const Map<String, String> _windowsAudioOutputDrivers = <String, String>{
  'auto': 'auto（引擎默认）',
  'wasapi': 'wasapi（Windows 默认，推荐）',
  'win32': 'win32（waveOut 旧通道）',
  'sdl2': 'sdl2',
  'pcm': 'pcm（转储到文件）',
  'null': 'null（无声音）',
};

const Map<String, String> _linuxAudioOutputDrivers = <String, String>{
  'auto': 'auto',
  'alsa': 'alsa',
  'pipewire': 'pipewire',
  'sdl': 'sdl',
  'null': 'null (不输出音频)',
};

const Map<String, String> _macosAudioOutputDrivers = <String, String>{
  'auto': 'auto',
  'audiounit': 'audiounit',
  'sdl': 'sdl',
  'null': 'null (不输出音频)',
};

// mpv manual, hardware decoding on Windows (d3d11 / nvdec family).
// copy variants decode into system memory: slower, but required by filters
// that cannot read GPU textures directly (some vf chains, screenshots on
// some paths).
const Map<String, String> _windowsHardwareDecoders = <String, String>{
  'no': 'no（软解）',
  'auto': 'auto（全部尝试）',
  'auto-safe': 'auto-safe（白名单，推荐）',
  'auto-copy': 'auto-copy',
  'd3d11va': 'd3d11va（Direct3D 11）',
  'd3d11va-copy': 'd3d11va-copy',
  'nvdec': 'nvdec（NVIDIA）',
  'nvdec-copy': 'nvdec-copy（NVIDIA）',
};

const Map<String, String> _linuxHardwareDecoders = <String, String>{
  'auto': 'auto',
  'auto-safe': 'auto-safe',
  'auto-copy': 'auto-copy',
  'vaapi': 'vaapi',
  'vaapi-copy': 'vaapi-copy',
  'vdpau': 'vdpau',
  'nvdec': 'nvdec',
  'nvdec-copy': 'nvdec-copy',
};

Map<String, String> mpvAudioOutputDriversForPlatform(TargetPlatform platform) => switch (platform) {
  TargetPlatform.android => _androidAudioOutputDrivers,
  TargetPlatform.iOS => _iosAudioOutputDrivers,
  TargetPlatform.windows => _windowsAudioOutputDrivers,
  TargetPlatform.macOS => _macosAudioOutputDrivers,
  TargetPlatform.linux => _linuxAudioOutputDrivers,
  _ => PlayerConsts.audioOutputDrivers,
};

Map<String, String> mpvHardwareDecodersForPlatform(TargetPlatform platform) => switch (platform) {
  TargetPlatform.android => PlayerConsts.hardwareDecoder,
  TargetPlatform.iOS || TargetPlatform.macOS => _iosHardwareDecoders,
  TargetPlatform.windows => _windowsHardwareDecoders,
  TargetPlatform.linux => _linuxHardwareDecoders,
  _ => PlayerConsts.hardwareDecoder,
};

String defaultMpvVideoOutputDriverForPlatform(TargetPlatform platform) => 'auto';

String normalizeMpvVideoOutputDriverForPlatform(String value, TargetPlatform platform) => _normalizeMpvOption(
  value,
  mpvVideoOutputDriversForPlatform(platform),
  defaultMpvVideoOutputDriverForPlatform(platform),
);

String normalizeMpvAudioOutputDriverForPlatform(String value, TargetPlatform platform) =>
    _normalizeMpvOption(value, mpvAudioOutputDriversForPlatform(platform), 'auto');

/// Native audio preference applied when expert output overrides are disabled.
///
/// The bundled Android libmpv contains all three drivers. Prefer AudioTrack's
/// platform mixer path, retain AAudio and OpenSL ES as ordered fallbacks, then
/// let mpv probe any remaining compiled driver. Linux retains the existing
/// explicit ALSA default; other platforms keep media_kit's native default.
String? defaultMpvAudioOutputDriverForPlatform(TargetPlatform platform) => switch (platform) {
  TargetPlatform.android => 'audiotrack,aaudio,opensles,',
  TargetPlatform.linux => 'alsa',
  _ => null,
};

/// Resolves the value sent to libmpv after applying the platform contract.
///
/// Android's bundled libmpv exposes several concrete backends. Treat the
/// user-facing `auto` choice as the same ordered chain used by the safe
/// default instead of passing a pseudo-driver which has produced video with no
/// audio device on real Android builds.
String? effectiveMpvAudioOutputDriverForPlatform({
  required bool customOutput,
  required String configuredDriver,
  required TargetPlatform platform,
}) {
  if (!customOutput) return defaultMpvAudioOutputDriverForPlatform(platform);
  final normalized = normalizeMpvAudioOutputDriverForPlatform(configuredDriver, platform);
  if (platform == TargetPlatform.android && normalized == 'auto') {
    return defaultMpvAudioOutputDriverForPlatform(platform);
  }
  return normalized;
}

bool isMpvAudioOutputDisabledForPlatform({
  required bool customOutput,
  required String configuredDriver,
  required TargetPlatform platform,
}) => customOutput && normalizeMpvAudioOutputDriverForPlatform(configuredDriver, platform) == 'null';

String normalizeMpvHardwareDecoderForPlatform(String value, TargetPlatform platform) =>
    _normalizeMpvOption(value, mpvHardwareDecodersForPlatform(platform), 'auto');

String _normalizeMpvOption(String value, Map<String, String> available, String fallback) =>
    available.containsKey(value) ? value : fallback;
