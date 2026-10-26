import 'dart:io' show Directory, File;

import 'package:flutter/foundation.dart' show TargetPlatform, defaultTargetPlatform, kIsWeb;
import 'package:flutter/services.dart' show AssetManifest, rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_storage/live_storage.dart' show StoragePrefs;
import 'package:media_core/media_core.dart' show EngineOption, PlayerHandle, PlayerHandleEngineOptions;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart' show getApplicationSupportDirectory;

/// Anime4K super-resolution, borrowed from the old client's player.
///
/// mpv mounts GLSL shaders through the list-valued `glsl-shaders` option;
/// the files must exist on disk, so the bundled assets are unpacked to the
/// app support directory once and reused from there.
///
/// Live sources are where this pays off: a 480p room upscaled to a 1440p or
/// 4K screen without an upscaler reads soft. Desktop GPUs only — a phone GPU
/// cannot hold the CNN chain in realtime.
enum SuperResolutionMode {
  /// No shaders mounted.
  off,

  /// Efficiency chain: lighter CNN models, for GPUs that cannot hold the
  /// quality chain at realtime.
  efficiency,

  /// Quality chain: the heaviest models, sharpest result.
  quality;

  static SuperResolutionMode fromName(String? name) =>
      SuperResolutionMode.values.firstWhere((mode) => mode.name == name, orElse: () => SuperResolutionMode.off);
}

/// Whether this platform can run the shader chain. Windows desktop is the
/// tested path; a phone cannot hold it in realtime.
bool get superResolutionAvailable => !kIsWeb && defaultTargetPlatform == TargetPlatform.windows;

/// The shader files of each chain, in mount order.
const List<String> _qualityShaders = [
  'Anime4K_Clamp_Highlights.glsl',
  'Anime4K_Restore_CNN_VL.glsl',
  'Anime4K_Upscale_CNN_x2_VL.glsl',
  'Anime4K_AutoDownscalePre_x2.glsl',
  'Anime4K_AutoDownscalePre_x4.glsl',
  'Anime4K_Upscale_CNN_x2_M.glsl',
];

const List<String> _efficiencyShaders = [
  'Anime4K_Clamp_Highlights.glsl',
  'Anime4K_Restore_CNN_M.glsl',
  'Anime4K_Restore_CNN_S.glsl',
  'Anime4K_Upscale_CNN_x2_M.glsl',
  'Anime4K_AutoDownscalePre_x2.glsl',
  'Anime4K_AutoDownscalePre_x4.glsl',
  'Anime4K_Upscale_CNN_x2_S.glsl',
];

/// The absolute paths of [mode]'s chain, or null when it mounts nothing or
/// the chain is incomplete.
List<String>? _chainOf(SuperResolutionMode mode, Directory directory) {
  final names = switch (mode) {
    SuperResolutionMode.off => null,
    SuperResolutionMode.quality => _qualityShaders,
    SuperResolutionMode.efficiency => _efficiencyShaders,
  };
  if (names == null) return null;
  final files = [for (final name in names) p.join(directory.path, name)];
  return files.every((file) => File(file).existsSync()) ? files : null;
}

/// The option that mounts [mode]'s shader chain, or null when nothing is
/// mounted or the bundled files cannot be completed.
///
/// Unpacking is incremental: existing files are left alone, so the cost is
/// paid once per install. A `List` value travels as mpv's own
/// `change-list` commands (clear, then append each path), which is the only
/// form the engine accepts for a list option.
Future<EngineOption?> superResolutionOption(SuperResolutionMode mode) async {
  if (!superResolutionAvailable || mode == SuperResolutionMode.off) return null;
  try {
    final support = await getApplicationSupportDirectory();
    final directory = Directory(p.join(support.path, 'anime_shaders'));
    if (!directory.existsSync()) directory.createSync(recursive: true);
    final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
    for (final asset in manifest.listAssets().where(
      (asset) => asset.startsWith('assets/shaders/') && asset.endsWith('.glsl'),
    )) {
      final target = File(p.join(directory.path, p.basename(asset)));
      if (target.existsSync()) continue;
      final data = await rootBundle.load(asset);
      target.writeAsBytesSync(data.buffer.asUint8List(), flush: true);
    }
    final files = _chainOf(mode, directory);
    return files == null ? null : EngineOption('glsl-shaders', files);
  } on Object {
    return null;
  }
}

/// [options] plus [mode]'s shader chain for a fresh handle; unchanged when
/// nothing is mounted.
Future<List<EngineOption>> withSuperResolution(List<EngineOption> options, SuperResolutionMode mode) async {
  final shader = await superResolutionOption(mode);
  return shader == null ? options : <EngineOption>[...options, shader];
}

/// Applies [mode] to a running engine: mounts its chain, or clears the
/// previously mounted one. A refused property is not a playback failure.
Future<void> applySuperResolution(PlayerHandle handle, SuperResolutionMode mode) async {
  try {
    final option = await superResolutionOption(mode);
    await handle.applyEngineOptions(<EngineOption>[
      option ?? const EngineOption('glsl-shaders', <String>[]),
    ]);
  } on Object {
    // A picture that keeps playing beats a playback error over a decoration.
  }
}

/// The viewer's super-resolution choice, persisted under
/// `player.superResolution`. Off on every platform without the shader path.
final class SuperResolutionModeController extends Notifier<SuperResolutionMode> {
  static const String _key = 'player.superResolution';

  @override
  SuperResolutionMode build() {
    if (!superResolutionAvailable) return SuperResolutionMode.off;
    try {
      return SuperResolutionMode.fromName(StoragePrefs.getString(_key));
    } on Object {
      return SuperResolutionMode.off;
    }
  }

  /// Stores and applies a new choice; the room controller applies it to the
  /// running handle as well as every later one.
  Future<void> select(SuperResolutionMode mode) async {
    if (mode == state) return;
    state = mode;
    try {
      await StoragePrefs.setString(_key, mode.name);
    } on Object {
      // A preference; a closed store loses it.
    }
  }
}

/// The chosen super-resolution mode.
final superResolutionModeProvider = NotifierProvider<SuperResolutionModeController, SuperResolutionMode>(
  SuperResolutionModeController.new,
);
