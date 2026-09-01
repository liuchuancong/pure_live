import 'package:flutter/material.dart';
import 'package:pure_live/player/models/player_engine.dart';

class PlayerConsts {
  static const String defaultKey = 'mpv';

  static const Map<String, PlayerEngine> engines = {
    'mpv': PlayerEngine.mediaKit,
    'ijk': PlayerEngine.fijk,
    'exo': PlayerEngine.exo,
  };

  static const Map<String, String> names = {'mpv': 'player_mpv', 'ijk': 'player_ijk', 'exo': 'player_exo'};

  static String getKeyByI18nKey(String i18nKey) {
    return names.entries.firstWhere((e) => e.value == i18nKey, orElse: () => names.entries.first).key;
  }

  static const List<String> resolutions = ['原画', '蓝光8M', '蓝光4M', '超清', '流畅'];
  static Map<String, Color> themeColors = {
    "Crimson": const Color.fromARGB(255, 220, 20, 60),
    "Orange": Colors.orange,
    "Chrome": const Color.fromARGB(255, 230, 184, 0),
    "Grass": Colors.lightGreen,
    "Teal": Colors.teal,
    "SeaFoam": const Color.fromARGB(255, 112, 193, 207),
    "Ice": const Color.fromARGB(255, 115, 155, 208),
    "Blue": Colors.blue,
    "Indigo": Colors.indigo,
    "Violet": Colors.deepPurple,
    "Primary": const Color(0xFF6200EE),
    "Orchid": const Color.fromARGB(255, 218, 112, 214),
    "Variant": const Color(0xFF3700B3),
    "Secondary": const Color(0xFF03DAC6),
  };

  /// 可选硬件解码器
  static const List<Map<String, String>> hardwareDecodersList = [
    {'key': 'auto', 'nameEn': 'Any Available Decoder', 'nameZh': '启用任意可用解码器'},
    {'key': 'auto-safe', 'nameEn': 'Best Decoder', 'nameZh': '启用最佳解码器'},
    {'key': 'auto-copy', 'nameEn': 'Best Decoder with Copy-Back', 'nameZh': '启用带拷贝功能的最佳解码器'},
    {'key': 'd3d11va', 'nameEn': 'DirectX 11 (Windows 8+)', 'nameZh': 'DirectX 11（Windows 8 及以上）'},
    {'key': 'd3d11va-copy', 'nameEn': 'DirectX 11 (Copy-Back)', 'nameZh': 'DirectX 11（非直通）'},
    {'key': 'videotoolbox', 'nameEn': 'VideoToolbox (macOS / iOS)', 'nameZh': 'VideoToolbox（macOS / iOS）'},
    {'key': 'videotoolbox-copy', 'nameEn': 'VideoToolbox (Copy-Back)', 'nameZh': 'VideoToolbox（非直通）'},
    {'key': 'vaapi', 'nameEn': 'VAAPI (Linux)', 'nameZh': 'VAAPI（Linux）'},
    {'key': 'vaapi-copy', 'nameEn': 'VAAPI (Copy-Back)', 'nameZh': 'VAAPI（非直通）'},
    {'key': 'nvdec', 'nameEn': 'NVDEC (NVIDIA Only)', 'nameZh': 'NVDEC（仅 NVIDIA）'},
    {'key': 'nvdec-copy', 'nameEn': 'NVDEC (NVIDIA Only, Copy-Back)', 'nameZh': 'NVDEC（仅 NVIDIA，非直通）'},
    {'key': 'drm', 'nameEn': 'DRM (Linux)', 'nameZh': 'DRM（Linux）'},
    {'key': 'drm-copy', 'nameEn': 'DRM (Copy-Back)', 'nameZh': 'DRM（非直通）'},
    {'key': 'vulkan', 'nameEn': 'Vulkan (Experimental)', 'nameZh': 'Vulkan（全平台，实验性）'},
    {'key': 'vulkan-copy', 'nameEn': 'Vulkan (Experimental, Copy-Back)', 'nameZh': 'Vulkan（全平台，实验性，非直通）'},
    {'key': 'dxva2', 'nameEn': 'DXVA2 (Windows 7+)', 'nameZh': 'DXVA2（Windows 7 及以上）'},
    {'key': 'dxva2-copy', 'nameEn': 'DXVA2 (Copy-Back)', 'nameZh': 'DXVA2（非直通）'},
    {'key': 'vdpau', 'nameEn': 'VDPAU (Linux)', 'nameZh': 'VDPAU（Linux）'},
    {'key': 'vdpau-copy', 'nameEn': 'VDPAU (Copy-Back)', 'nameZh': 'VDPAU（非直通）'},
    {'key': 'mediacodec', 'nameEn': 'MediaCodec (Android)', 'nameZh': 'MediaCodec（Android）'},
    {'key': 'mediacodec-copy', 'nameEn': 'MediaCodec (Copy-Back)', 'nameZh': 'MediaCodec（Android，非直通）'},
    {'key': 'cuda', 'nameEn': 'CUDA (NVIDIA Only, Deprecated)', 'nameZh': 'CUDA（仅 NVIDIA，已过时）'},
    {'key': 'cuda-copy', 'nameEn': 'CUDA (NVIDIA Only, Deprecated, Copy-Back)', 'nameZh': 'CUDA（仅 NVIDIA，已过时，非直通）'},
    {'key': 'crystalhd', 'nameEn': 'CrystalHD (Deprecated)', 'nameZh': 'CrystalHD（全平台，已过时）'},
    {'key': 'rkmpp', 'nameEn': 'Rockchip MPP (Selected Rockchip SoCs)', 'nameZh': 'Rockchip MPP（仅部分 Rockchip 芯片）'},
  ];

  /// 可选音频输出驱动
  static const List<Map<String, String>> audioOutputDriversList = [
    {'key': 'auto', 'nameEn': 'Auto', 'nameZh': '自动选择'},
    {'key': 'null', 'nameEn': 'Null (No Audio Output)', 'nameZh': 'Null（不输出音频）'},
    {'key': 'pulse', 'nameEn': 'PulseAudio (Linux)', 'nameZh': 'PulseAudio（Linux）'},
    {'key': 'pipewire', 'nameEn': 'PipeWire (Linux)', 'nameZh': 'PipeWire（Linux）'},
    {'key': 'alsa', 'nameEn': 'ALSA (Linux Only)', 'nameZh': 'ALSA（仅 Linux）'},
    {'key': 'oss', 'nameEn': 'OSS (Linux Only)', 'nameZh': 'OSS（仅 Linux）'},
    {'key': 'jack', 'nameEn': 'JACK (Linux / macOS, Low Latency)', 'nameZh': 'JACK（Linux / macOS，低延迟音频）'},
    {'key': 'directsound', 'nameEn': 'DirectSound (Windows Only)', 'nameZh': 'DirectSound（仅 Windows）'},
    {'key': 'wasapi', 'nameEn': 'WASAPI (Windows Only)', 'nameZh': 'WASAPI（仅 Windows）'},
    {'key': 'winmm', 'nameEn': 'WinMM (Windows Only, Legacy)', 'nameZh': 'WinMM（仅 Windows，旧版 API）'},
    {'key': 'audiounit', 'nameEn': 'AudioUnit (iOS Only)', 'nameZh': 'AudioUnit（仅 iOS）'},
    {'key': 'coreaudio', 'nameEn': 'CoreAudio (macOS Only)', 'nameZh': 'CoreAudio（仅 macOS）'},
    {'key': 'opensles', 'nameEn': 'OpenSL ES (Android Only)', 'nameZh': 'OpenSL ES（仅 Android）'},
    {'key': 'audiotrack', 'nameEn': 'AudioTrack (Android Only)', 'nameZh': 'AudioTrack（仅 Android）'},
    {'key': 'aaudio', 'nameEn': 'AAudio (Android Only)', 'nameZh': 'AAudio（仅 Android）'},
    {'key': 'pcm', 'nameEn': 'PCM (Cross-Platform)', 'nameZh': 'PCM（跨平台）'},
    {'key': 'sdl', 'nameEn': 'SDL (Cross-Platform)', 'nameZh': 'SDL（跨平台）'},
    {'key': 'openal', 'nameEn': 'OpenAL (Cross-Platform)', 'nameZh': 'OpenAL（跨平台）'},
    {'key': 'libao', 'nameEn': 'libao (Cross-Platform)', 'nameZh': 'libao（跨平台）'},
  ];

  /// 可选视频渲染器
  static const List<Map<String, String>> videoRenderersList = [
    {'key': 'auto', 'nameEn': 'Auto', 'nameZh': '自动选择'},
    {'key': 'gpu', 'nameEn': 'GPU', 'nameZh': 'GPU'},
    {'key': 'gpu-next', 'nameEn': 'GPU Next', 'nameZh': 'GPU Next'},
    {'key': 'sdl', 'nameEn': 'SDL', 'nameZh': 'SDL'},
    {'key': 'null', 'nameEn': 'Null (No Video Output)', 'nameZh': 'Null（不输出视频）'},
    {'key': 'mediacodec_embed', 'nameEn': 'MediaCodec Embed (Android Only)', 'nameZh': 'MediaCodec Embed（仅 Android）'},
    {'key': 'direct3d', 'nameEn': 'Direct3D (Windows Only)', 'nameZh': 'Direct3D（仅 Windows）'},
    {'key': 'vaapi', 'nameEn': 'VA-API (Linux Only)', 'nameZh': 'VA-API（仅 Linux）'},
    {'key': 'vdpau', 'nameEn': 'VDPAU (Linux Only)', 'nameZh': 'VDPAU（仅 Linux）'},
    {'key': 'drm', 'nameEn': 'DRM (Linux Only)', 'nameZh': 'DRM（仅 Linux）'},
    {'key': 'wlshm', 'nameEn': 'Wayland SHM (Linux Only)', 'nameZh': 'Wayland SHM（仅 Linux）'},
    {'key': 'dmabuf-wayland', 'nameEn': 'DMABUF Wayland (Linux Only)', 'nameZh': 'DMABUF Wayland（仅 Linux）'},
    {'key': 'x11', 'nameEn': 'X11 (Linux Only)', 'nameZh': 'X11（仅 Linux）'},
    {'key': 'xv', 'nameEn': 'XVideo (Linux Only)', 'nameZh': 'XVideo（仅 Linux）'},
    {'key': 'caca', 'nameEn': 'CACA (macOS / Linux)', 'nameZh': 'CACA（macOS / Linux）'},
    {'key': 'avfoundation', 'nameEn': 'AVFoundation (macOS / iOS)', 'nameZh': 'AVFoundation（macOS / iOS）'},
  ];

  /// 超分辨率滤镜
  static const List<Map<String, String>> mpvAnime4KShaders = [
    {'key': 'Anime4K_Clamp_Highlights.glsl', 'nameEn': 'Clamp Highlights', 'nameZh': '高光限制'},
    {'key': 'Anime4K_Restore_CNN_VL.glsl', 'nameEn': 'CNN Restoration (VL)', 'nameZh': 'CNN 图像恢复（高质量）'},
    {'key': 'Anime4K_Upscale_CNN_x2_VL.glsl', 'nameEn': 'CNN 2× Upscaling (VL)', 'nameZh': 'CNN 2 倍放大（高质量）'},
    {'key': 'Anime4K_AutoDownscalePre_x2.glsl', 'nameEn': 'Auto Downscale Preprocess 2×', 'nameZh': '2 倍自动预降采样'},
    {'key': 'Anime4K_AutoDownscalePre_x4.glsl', 'nameEn': 'Auto Downscale Preprocess 4×', 'nameZh': '4 倍自动预降采样'},
    {'key': 'Anime4K_Upscale_CNN_x2_M.glsl', 'nameEn': 'CNN 2× Upscaling (Medium)', 'nameZh': 'CNN 2 倍放大（中等）'},
  ];

  /// 超分辨率滤镜（轻量）
  static const List<Map<String, String>> mpvAnime4KShadersLite = [
    {'key': 'Anime4K_Clamp_Highlights.glsl', 'nameEn': 'Clamp Highlights', 'nameZh': '高光限制'},
    {'key': 'Anime4K_Restore_CNN_M.glsl', 'nameEn': 'CNN Restoration (Medium)', 'nameZh': 'CNN 图像恢复（中等）'},
    {'key': 'Anime4K_Restore_CNN_S.glsl', 'nameEn': 'CNN Restoration (Light)', 'nameZh': 'CNN 图像恢复（轻量）'},
    {'key': 'Anime4K_Upscale_CNN_x2_M.glsl', 'nameEn': 'CNN 2× Upscaling (Medium)', 'nameZh': 'CNN 2 倍放大（中等）'},
    {'key': 'Anime4K_AutoDownscalePre_x2.glsl', 'nameEn': 'Auto Downscale Preprocess 2×', 'nameZh': '2 倍自动预降采样'},
    {'key': 'Anime4K_AutoDownscalePre_x4.glsl', 'nameEn': 'Auto Downscale Preprocess 4×', 'nameZh': '4 倍自动预降采样'},
    {'key': 'Anime4K_Upscale_CNN_x2_S.glsl', 'nameEn': 'CNN 2× Upscaling (Light)', 'nameZh': 'CNN 2 倍放大（轻量）'},
  ];

  static List<String> get mpvAnime4KShadersLiteKeys =>
      mpvAnime4KShadersLite.map((e) => e['key']!).toList(growable: false);

  static List<String> get mpvAnime4KShaderKeys => mpvAnime4KShaders.map((e) => e['key']!).toList(growable: false);
}
