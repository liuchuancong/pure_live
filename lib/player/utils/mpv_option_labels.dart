import 'package:flutter/foundation.dart';
import 'package:pure_live/player/utils/mpv_platform_profile.dart';

enum MpvOptionKind {
  videoOutput,
  audioOutput,
  hardwareDecoder,
  videoSync,
  interpolation,
  scale,
  deinterlace,
  hwdecCodecs,
  audioExclusive,
}

typedef MpvOption = ({String key, String label});

// Readable names adapted from liuchuancong/pure_live. Only keys the platform
// profile accepts are ever offered; an unnamed key shows the profile's label.
const Map<String, (String, String)> _videoOutputLabels = {
  'auto': ('auto（跟随 mpv 默认，推荐）', 'Auto (follow mpv default, recommended)'),
  'libmpv': ('libmpv（内嵌 Flutter 纹理，默认）', 'libmpv (embedded Flutter texture, default)'),
  'gpu': ('gpu（⚠ 独立 mpv 窗口，完整着色含 RTX 滤镜）', 'gpu (⚠ standalone mpv window, full shading incl. RTX)'),
  'gpu-next': ('gpu-next（⚠ 独立窗口，libplacebo 新管线，支持 HDR）', 'gpu-next (⚠ standalone, libplacebo pipeline, HDR)'),
  'direct3d': ('direct3d（⚠ 独立窗口，旧 D3D9 兼容）', 'direct3d (⚠ standalone, legacy D3D9)'),
  'null': ('null（⚠ 不渲染画面，只有声音）', 'null (⚠ no video, audio only)'),
  'sdl': ('SDL（⚠ 独立窗口）', 'SDL (⚠ standalone window)'),
  'mediacodec_embed': ('MediaCodec Embed（仅 Android）', 'MediaCodec Embed (Android only)'),
  'vaapi': ('VA-API（仅 Linux）', 'VA-API (Linux only)'),
  'vdpau': ('VDPAU（仅 Linux）', 'VDPAU (Linux only)'),
  'dmabuf-wayland': ('DMABUF Wayland（仅 Linux）', 'DMABUF Wayland (Linux only)'),
  'x11': ('X11（仅 Linux）', 'X11 (Linux only)'),
  'xv': ('XVideo（仅 Linux）', 'XVideo (Linux only)'),
};

const Map<String, (String, String)> _audioOutputLabels = {
  'auto': ('自动（引擎按平台挑选，推荐）', 'Auto (engine picks per platform, recommended)'),
  'wasapi': ('WASAPI（Windows 默认通道，推荐）', 'WASAPI (Windows default, recommended)'),
  'directsound': ('DirectSound（Windows 旧通道）', 'DirectSound (Windows legacy)'),
  'winmm': ('WinMM / waveOut（Windows 旧 API，兼容用）', 'WinMM / waveOut (Windows legacy)'),
  'audiotrack': ('AudioTrack（Android 系统混音器，推荐）', 'AudioTrack (Android mixer, recommended)'),
  'aaudio': ('AAudio（Android 8.0+，低延迟）', 'AAudio (Android 8.0+, low latency)'),
  'opensles': ('OpenSL ES（Android 旧通道，兼容用）', 'OpenSL ES (Android legacy)'),
  'audiounit': ('AudioUnit（iOS）', 'AudioUnit (iOS)'),
  'coreaudio': ('CoreAudio（macOS）', 'CoreAudio (macOS)'),
  'pulse': ('PulseAudio（Linux 桌面常用）', 'PulseAudio (Linux desktop)'),
  'pipewire': ('PipeWire（Linux 新声音栈）', 'PipeWire (Linux new stack)'),
  'alsa': ('ALSA（Linux 直通，独占声卡）', 'ALSA (Linux, may claim the card)'),
  'oss': ('OSS（Linux 旧接口）', 'OSS (Linux legacy)'),
  'jack': ('JACK（专业音频，低延迟）', 'JACK (pro audio, low latency)'),
  'pcm': ('PCM（原始数据转储到文件，调试用）', 'PCM (dump to file, debugging)'),
  'sdl': ('SDL（跨平台兜底）', 'SDL (cross-platform fallback)'),
  'null': ('null（不输出声音，静音调试）', 'null (no audio, silent debugging)'),
};

const Map<String, (String, String)> _hardwareDecoderLabels = {
  'no': ('no（软件解码，兼容性最好）', 'no (software decode, most compatible)'),
  'auto': ('auto（任意硬解路径，兼容性有风险）', 'auto (any hw path, may glitch)'),
  'auto-safe': ('auto-safe（白名单内安全硬解，推荐）', 'auto-safe (whitelisted, recommended)'),
  'auto-copy': ('auto-copy（安全硬解+拷回内存，滤镜/截图可用）', 'auto-copy (safe + copy-back)'),
  'yes': ('yes（强制硬解，失败即报错）', 'yes (force hw, fails loudly)'),
  'd3d11va': ('d3d11va（Direct3D 11 直通，Windows 8+）', 'd3d11va (Direct3D 11, Windows 8+)'),
  'd3d11va-copy': ('d3d11va-copy（D3D11 + 拷回内存）', 'd3d11va-copy (D3D11 + copy-back)'),
  'dxva2': ('dxva2（DirectX 9，Windows 7 老机）', 'dxva2 (DXVA2, Windows 7 era)'),
  'dxva2-copy': ('dxva2-copy（DXVA2 + 拷回内存）', 'dxva2-copy (DXVA2 + copy-back)'),
  'nvdec': ('nvdec（NVIDIA 直通，低开销）', 'nvdec (NVIDIA, zero-copy)'),
  'nvdec-copy': ('nvdec-copy（NVIDIA + 拷回内存）', 'nvdec-copy (NVIDIA + copy-back)'),
  'vaapi': ('vaapi（Intel/AMD Linux 直通）', 'vaapi (Intel/AMD Linux, zero-copy)'),
  'vaapi-copy': ('vaapi-copy（vaapi + 拷回内存）', 'vaapi-copy (vaapi + copy-back)'),
  'vdpau': ('vdpau（NVIDIA Linux 旧接口）', 'vdpau (NVIDIA Linux legacy)'),
  'videotoolbox': ('videotoolbox（Apple 直通，推荐）', 'videotoolbox (Apple, recommended)'),
  'videotoolbox-copy': ('videotoolbox-copy（Apple + 拷回内存）', 'videotoolbox-copy (Apple + copy-back)'),
  'mediacodec': ('mediacodec（Android 直通，推荐）', 'mediacodec (Android, recommended)'),
  'mediacodec-copy': ('mediacodec-copy（Android + 拷回内存）', 'mediacodec-copy (Android + copy-back)'),
  'crystalhd': ('crystalhd（Broadcom 老硬件）', 'crystalhd (Broadcom legacy)'),
  'rkmpp': ('rkmpp（Rockchip 盒子/开发板）', 'rkmpp (Rockchip boards)'),
};

Map<String, String> _allowed(MpvOptionKind kind, TargetPlatform platform) {
  final android = platform == TargetPlatform.android;
  final desktop = !android && platform != TargetPlatform.iOS;
  final windows = platform == TargetPlatform.windows;

  return switch (kind) {
    MpvOptionKind.videoOutput => mpvVideoOutputDriversForPlatform(platform),
    MpvOptionKind.audioOutput => mpvAudioOutputDriversForPlatform(platform),
    MpvOptionKind.hardwareDecoder => mpvHardwareDecodersForPlatform(platform),
    MpvOptionKind.videoSync => const {
      'audio': 'audio（默认，音频为时钟）',
      'display-resample': 'display-resample（最平滑，吃 GPU）',
      'display-resample-vdrop': 'display-resample-vdrop',
      'display-resample-drop': 'display-resample-drop',
      'display-adrop': 'display-adrop',
      'display-vdrop': 'display-vdrop',
      'display-desync': 'display-desync',
      'desync': 'desync（完全不解音画同步）',
    },
    MpvOptionKind.interpolation => const {'no': 'no', 'yes': 'yes'},
    MpvOptionKind.scale => desktop
        ? const {
            'lanczos': 'lanczos（均衡推荐）',
            'ewa_lanczossharp': 'ewa_lanczossharp（锐利，吃 GPU）',
            'ewa_lanczos4sharpest': 'ewa_lanczos4sharpest（配合插帧）',
            'ewa_lanczos': 'ewa_lanczos',
            'spline36': 'spline36',
            'spline16': 'spline16（快）',
            'catmull_rom': 'catmull_rom',
            'mitchell': 'mitchell',
            'hermite': 'hermite（柔和）',
            'bicubic_fast': 'bicubic_fast（快）',
            'bilinear': 'bilinear（最快，最糊）',
            'nearest': 'nearest（最近邻）',
          }
        : const {'lanczos': 'lanczos', 'bilinear': 'bilinear'},
    MpvOptionKind.deinterlace => const {'auto': 'auto', 'no': 'no', 'yes': 'yes'},
    MpvOptionKind.hwdecCodecs => android
        ? const {
            'h264,hevc': 'h264,hevc',
            'h264,hevc,vp9': 'h264,hevc,vp9',
            'all': 'all',
          }
        : const {'all': 'all', 'h264,hevc': 'h264,hevc', 'h264,hevc,vp9,av1': 'h264,hevc,vp9,av1'},
    MpvOptionKind.audioExclusive => windows ? const {'no': 'no', 'yes': 'yes'} : const {},
  };
}

Map<String, (String, String)> _labels(MpvOptionKind kind) => switch (kind) {
  MpvOptionKind.videoOutput => _videoOutputLabels,
  MpvOptionKind.audioOutput => _audioOutputLabels,
  MpvOptionKind.hardwareDecoder => _hardwareDecoderLabels,
  MpvOptionKind.videoSync => {
    'audio': ('音频时钟（mpv 默认）', 'Audio clock (mpv default)'),
    'display-resample': ('显示重采样（最平滑，吃 GPU）', 'Display resample (smoothest, GPU heavy)'),
    'display-resample-vdrop': ('显示重采样+视频丢帧', 'Display resample + vdrop'),
    'display-resample-drop': ('显示重采样+整帧丢弃', 'Display resample + drop'),
    'display-adrop': ('显示时钟+音频丢样', 'Display clock + adrop'),
    'display-vdrop': ('显示时钟+视频丢帧', 'Display clock + vdrop'),
    'display-desync': ('显示时钟+不同步', 'Display clock + desync'),
    'desync': ('完全不同步（调试）', 'Desync (debug)'),
  },
  MpvOptionKind.interpolation => {
    'no': ('关闭', 'Off'),
    'yes': ('开启（配合显示重采样）', 'On (with display-resample)'),
  },
  MpvOptionKind.scale => {
    'lanczos': ('Lanczos（均衡推荐）', 'Lanczos (balanced)'),
    'ewa_lanczossharp': ('EWA Lanczos Sharp（锐利，吃 GPU）', 'EWA Lanczos Sharp (sharpest, heavy)'),
    'ewa_lanczos4sharpest': ('EWA Lanczos 4 Sharpest（配合插帧）', 'EWA Lanczos 4 Sharpest (with interpolation)'),
    'ewa_lanczos': ('EWA Lanczos', 'EWA Lanczos'),
    'spline36': ('Spline36', 'Spline36'),
    'spline16': ('Spline16（快）', 'Spline16 (fast)'),
    'catmull_rom': ('Catmull-Rom', 'Catmull-Rom'),
    'mitchell': ('Mitchell', 'Mitchell'),
    'hermite': ('Hermite（柔和）', 'Hermite (soft)'),
    'bicubic_fast': ('Bicubic Fast（快）', 'Bicubic Fast (fast)'),
    'bilinear': ('双线性（最快，最糊）', 'Bilinear (fastest, soft)'),
    'nearest': ('最近邻（块状）', 'Nearest (blocky)'),
  },
  MpvOptionKind.deinterlace => {
    'auto': ('自动', 'Auto'),
    'no': ('关闭', 'Off'),
    'yes': ('开启（隔行源才需要）', 'On (interlaced sources only)'),
  },
  MpvOptionKind.hwdecCodecs => {
    'all': ('全部编码格式', 'All codecs'),
    'h264,hevc': ('H264 + HEVC', 'H264 + HEVC'),
    'h264,hevc,vp9': ('H264 + HEVC + VP9', 'H264 + HEVC + VP9'),
    'h264,hevc,vp9,av1': ('H264 + HEVC + VP9 + AV1', 'H264 + HEVC + VP9 + AV1'),
  },
  MpvOptionKind.audioExclusive => {
    'no': ('共享模式', 'Shared mode'),
    'yes': ('独占模式（可能有更好的音质，其他应用无法出声）', 'Exclusive (other apps go silent)'),
  },
};

/// The stored value as the player will use it on [platform].
String normalizedMpvOption(MpvOptionKind kind, String value, TargetPlatform platform) => switch (kind) {
  MpvOptionKind.videoOutput => normalizeMpvVideoOutputDriverForPlatform(value, platform),
  MpvOptionKind.audioOutput => normalizeMpvAudioOutputDriverForPlatform(value, platform),
  MpvOptionKind.hardwareDecoder => normalizeMpvHardwareDecoderForPlatform(value, platform),
  MpvOptionKind.videoSync => value,
  MpvOptionKind.interpolation => value,
  MpvOptionKind.scale => value,
  MpvOptionKind.deinterlace => value,
  MpvOptionKind.hwdecCodecs => value,
  MpvOptionKind.audioExclusive => value,
};

String mpvOptionLabel(MpvOptionKind kind, String key, TargetPlatform platform, {required bool zh}) {
  final named = _labels(kind)[key];
  if (named != null) return zh ? named.$1 : named.$2;
  return _allowed(kind, platform)[key] ?? key;
}

/// Options the settings page may offer on [platform].
///
/// Ordering contract: `auto` first, the disable entry (`no`/`null`) second,
/// then everything else. The hardware-decoder list omits `no` entirely —
/// disabling hardware acceleration is the hardware-acceleration switch's
/// job, not a decoder choice, so the two never duplicate.
List<MpvOption> mpvOptionsForPlatform(MpvOptionKind kind, TargetPlatform platform, {required bool zh}) {
  final all = <MpvOption>[
    for (final key in _allowed(kind, platform).keys) (key: key, label: mpvOptionLabel(kind, key, platform, zh: zh)),
  ];

  final head = <MpvOption>[];
  for (final key in ['auto', 'no', 'null']) {
    final matches = all.where((entry) => entry.key == key).toList();
    if (matches.isNotEmpty) {
      head.add(matches.first);
      all.remove(matches.first);
    }
  }

  if (kind == MpvOptionKind.hardwareDecoder) {
    all.removeWhere((entry) => entry.key == 'no');
  }

  return [...head, ...all];
}
