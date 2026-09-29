import 'package:flutter/foundation.dart';
import 'package:pure_live/player/utils/mpv_platform_profile.dart';

enum MpvOptionKind { videoOutput, audioOutput, hardwareDecoder }

typedef MpvOption = ({String key, String label});

// Readable names adapted from liuchuancong/pure_live. Only keys the platform
// profile accepts are ever offered; an unnamed key shows the profile's label.
const Map<String, (String, String)> _videoOutputLabels = {
  'gpu': ('GPU', 'GPU'),
  'gpu-next': ('GPU Next', 'GPU Next'),
  'libmpv': ('libmpv（Flutter 纹理）', 'libmpv (Flutter texture)'),
  'direct3d': ('Direct3D（仅 Windows）', 'Direct3D (Windows only)'),
  'sdl': ('SDL', 'SDL'),
  'mediacodec_embed': ('MediaCodec Embed（仅 Android）', 'MediaCodec Embed (Android only)'),
  'vaapi': ('VA-API（仅 Linux）', 'VA-API (Linux only)'),
  'vdpau': ('VDPAU（仅 Linux）', 'VDPAU (Linux only)'),
  'dmabuf-wayland': ('DMABUF Wayland（仅 Linux）', 'DMABUF Wayland (Linux only)'),
  'x11': ('X11（仅 Linux）', 'X11 (Linux only)'),
  'xv': ('XVideo（仅 Linux）', 'XVideo (Linux only)'),
  'null': ('Null（不输出视频）', 'Null (no video output)'),
};

const Map<String, (String, String)> _audioOutputLabels = {
  'auto': ('自动选择', 'Auto'),
  'wasapi': ('WASAPI（仅 Windows）', 'WASAPI (Windows only)'),
  'directsound': ('DirectSound（仅 Windows）', 'DirectSound (Windows only)'),
  'winmm': ('WinMM（仅 Windows，旧版 API）', 'WinMM (Windows only, legacy)'),
  'audiotrack': ('AudioTrack（仅 Android）', 'AudioTrack (Android only)'),
  'aaudio': ('AAudio（仅 Android 8.0+）', 'AAudio (Android 8.0+)'),
  'opensles': ('OpenSL ES（仅 Android）', 'OpenSL ES (Android only)'),
  'audiounit': ('AudioUnit（仅 iOS）', 'AudioUnit (iOS only)'),
  'coreaudio': ('CoreAudio（仅 macOS）', 'CoreAudio (macOS only)'),
  'pulse': ('PulseAudio（Linux）', 'PulseAudio (Linux)'),
  'pipewire': ('PipeWire（Linux）', 'PipeWire (Linux)'),
  'alsa': ('ALSA（仅 Linux）', 'ALSA (Linux only)'),
  'oss': ('OSS（仅 Linux）', 'OSS (Linux only)'),
  'jack': ('JACK（Linux / macOS，低延迟）', 'JACK (Linux / macOS, low latency)'),
  'pcm': ('PCM（跨平台）', 'PCM (cross-platform)'),
  'sdl': ('SDL（跨平台）', 'SDL (cross-platform)'),
  'openal': ('OpenAL（跨平台）', 'OpenAL (cross-platform)'),
  'libao': ('libao（跨平台）', 'libao (cross-platform)'),
  'null': ('Null（不输出音频）', 'Null (no audio output)'),
};

const Map<String, (String, String)> _hardwareDecoderLabels = {
  'auto': ('启用任意可用解码器', 'Any available decoder'),
  'auto-safe': ('启用最佳解码器', 'Best decoder'),
  'auto-copy': ('启用带拷贝功能的最佳解码器', 'Best decoder with copy-back'),
  'yes': ('强制硬件解码', 'Force hardware decoding'),
  'no': ('关闭（软件解码）', 'Off (software decoding)'),
  'd3d11va': ('DirectX 11（Windows 8 及以上）', 'DirectX 11 (Windows 8+)'),
  'd3d11va-copy': ('DirectX 11（非直通）', 'DirectX 11 (copy-back)'),
  'dxva2': ('DXVA2（Windows 7 及以上）', 'DXVA2 (Windows 7+)'),
  'dxva2-copy': ('DXVA2（非直通）', 'DXVA2 (copy-back)'),
  'nvdec': ('NVDEC（仅 NVIDIA）', 'NVDEC (NVIDIA only)'),
  'nvdec-copy': ('NVDEC（仅 NVIDIA，非直通）', 'NVDEC (NVIDIA only, copy-back)'),
  'cuda': ('CUDA（仅 NVIDIA，已过时）', 'CUDA (NVIDIA only, deprecated)'),
  'cuda-copy': ('CUDA（仅 NVIDIA，已过时，非直通）', 'CUDA (NVIDIA only, deprecated, copy-back)'),
  'mediacodec': ('MediaCodec（Android）', 'MediaCodec (Android)'),
  'mediacodec-copy': ('MediaCodec（Android，非直通）', 'MediaCodec (Android, copy-back)'),
  'videotoolbox': ('VideoToolbox（macOS / iOS）', 'VideoToolbox (macOS / iOS)'),
  'videotoolbox-copy': ('VideoToolbox（非直通）', 'VideoToolbox (copy-back)'),
  'vaapi': ('VAAPI（Linux）', 'VAAPI (Linux)'),
  'vaapi-copy': ('VAAPI（非直通）', 'VAAPI (copy-back)'),
  'vdpau': ('VDPAU（Linux）', 'VDPAU (Linux)'),
  'vdpau-copy': ('VDPAU（非直通）', 'VDPAU (copy-back)'),
  'drm': ('DRM（Linux）', 'DRM (Linux)'),
  'drm-copy': ('DRM（非直通）', 'DRM (copy-back)'),
  'vulkan': ('Vulkan（实验性）', 'Vulkan (experimental)'),
  'vulkan-copy': ('Vulkan（实验性，非直通）', 'Vulkan (experimental, copy-back)'),
  'crystalhd': ('CrystalHD（已过时）', 'CrystalHD (deprecated)'),
  'rkmpp': ('Rockchip MPP（仅部分 Rockchip 芯片）', 'Rockchip MPP (selected Rockchip SoCs)'),
};

Map<String, String> _allowed(MpvOptionKind kind, TargetPlatform platform) => switch (kind) {
  MpvOptionKind.videoOutput => mpvVideoOutputDriversForPlatform(platform),
  MpvOptionKind.audioOutput => mpvAudioOutputDriversForPlatform(platform),
  MpvOptionKind.hardwareDecoder => mpvHardwareDecodersForPlatform(platform),
};

Map<String, (String, String)> _labels(MpvOptionKind kind) => switch (kind) {
  MpvOptionKind.videoOutput => _videoOutputLabels,
  MpvOptionKind.audioOutput => _audioOutputLabels,
  MpvOptionKind.hardwareDecoder => _hardwareDecoderLabels,
};

/// The stored value as the player will use it on [platform].
String normalizedMpvOption(MpvOptionKind kind, String value, TargetPlatform platform) => switch (kind) {
  MpvOptionKind.videoOutput => normalizeMpvVideoOutputDriverForPlatform(value, platform),
  MpvOptionKind.audioOutput => normalizeMpvAudioOutputDriverForPlatform(value, platform),
  MpvOptionKind.hardwareDecoder => normalizeMpvHardwareDecoderForPlatform(value, platform),
};

String mpvOptionLabel(MpvOptionKind kind, String key, TargetPlatform platform, {required bool zh}) {
  final named = _labels(kind)[key];
  if (named != null) return zh ? named.$1 : named.$2;
  return _allowed(kind, platform)[key] ?? key;
}

/// Options the settings page may offer on [platform], in the profile's order.
List<MpvOption> mpvOptionsForPlatform(MpvOptionKind kind, TargetPlatform platform, {required bool zh}) => [
  for (final key in _allowed(kind, platform).keys) (key: key, label: mpvOptionLabel(kind, key, platform, zh: zh)),
];
