import 'dart:io';

import 'package:flutter/services.dart' show rootBundle, AssetManifest;
import 'package:path/path.dart' as path;
import 'package:media_core/media_core.dart';

/// Anime4K super-resolution, borrowed from Kazumi's player.
///
/// mpv mounts GLSL shaders through the `glsl-shaders` property; the files
/// must exist on disk, so the bundled assets are unpacked to the app
/// support directory once and reused from there.
///
/// Live sources are exactly where this pays off: a 480p room upscaled to
/// a 1440p/4K screen without the upscaler reads soft, and Anime4K's CNN
/// chain restores edges live. Desktop GPUs only — a phone GPU cannot run
/// the CNN chain in realtime.
enum SuperResolutionMode {
  /// No shaders mounted.
  off('关闭', '默认渲染, 不挂载任何超分滤镜'),

  /// Efficiency chain: lighter CNN models, for GPUs that cannot hold the
  /// quality chain at realtime.
  efficiency('效率档', '轻量 Anime4K 卷积链, GPU 负担小, 适合核显或高刷屏'),

  /// Quality chain: the heaviest models, sharpest result.
  quality('质量档', '完整 Anime4K 卷积链, 效果最好, 需要独立显卡');

  const SuperResolutionMode(this.label, this.descriptionZh);

  final String label;
  final String descriptionZh;

  static SuperResolutionMode fromName(String? name) {
    return SuperResolutionMode.values.firstWhere((mode) => mode.name == name, orElse: () => SuperResolutionMode.off);
  }
}

/// Quality-chain shader set, in mount order (Kazumi's `mpvAnime4KShaders`).
const List<String> _qualityShaders = [
  'Anime4K_Clamp_Highlights.glsl',
  'Anime4K_Restore_CNN_VL.glsl',
  'Anime4K_Upscale_CNN_x2_VL.glsl',
  'Anime4K_AutoDownscalePre_x2.glsl',
  'Anime4K_AutoDownscalePre_x4.glsl',
  'Anime4K_Upscale_CNN_x2_M.glsl',
];

/// Efficiency-chain shader set (Kazumi's `mpvAnime4KShadersLite`).
const List<String> _efficiencyShaders = [
  'Anime4K_Clamp_Highlights.glsl',
  'Anime4K_Restore_CNN_M.glsl',
  'Anime4K_Restore_CNN_S.glsl',
  'Anime4K_Upscale_CNN_x2_M.glsl',
  'Anime4K_AutoDownscalePre_x2.glsl',
  'Anime4K_AutoDownscalePre_x4.glsl',
  'Anime4K_Upscale_CNN_x2_S.glsl',
];

/// Unpacks the bundled shaders to disk and returns the mount property for
/// [mode], or null when [mode] mounts nothing.
///
/// Unpacking is incremental: existing files are left alone, so the cost is
/// paid once per app install.
Future<EngineOption?> superResolutionOption(
  SuperResolutionMode mode,
  Directory supportDirectory,
) async {
  if (mode == SuperResolutionMode.off) {
    return null;
  }

  final directory = Directory(path.join(supportDirectory.path, 'anime_shaders'));

  if (!directory.existsSync()) {
    directory.createSync(recursive: true);
  }

  final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
  final bundled = manifest
      .listAssets()
      .where((asset) => asset.startsWith('assets/shaders/') && asset.endsWith('.glsl'));

  for (final asset in bundled) {
    final target = File(path.join(directory.path, path.basename(asset)));

    if (target.existsSync()) {
      continue;
    }

    final data = await rootBundle.load(asset);
    target.writeAsBytesSync(data.buffer.asUint8List(), flush: true);
  }

  final files = (mode == SuperResolutionMode.quality ? _qualityShaders : _efficiencyShaders)
      .map((name) => path.join(directory.path, name))
      .toList();

  // mpv's glsl-shaders is a path list; comma is the separator mpv accepts
  // for a string write of a list property.
  return EngineOption('glsl-shaders', files.join(','));
}
