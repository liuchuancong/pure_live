import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:pure_live/core/common/log.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/services.dart' show AssetManifest, rootBundle;

class ShaderAssetService {
  ShaderAssetService._();

  static final ShaderAssetService instance = ShaderAssetService._();

  Directory? _shadersDirectory;

  Directory? get shadersDirectory => _shadersDirectory;

  String? get shadersDirectoryPath => _shadersDirectory?.path;

  bool get isInitialized => _shadersDirectory != null;

  Future<Directory> initialize() async {
    if (_shadersDirectory != null && await _shadersDirectory!.exists()) {
      Log.i(
        'ShaderManager: Already initialized: '
        '${_shadersDirectory!.path}',
      );

      return _shadersDirectory!;
    }

    try {
      final assetManifest = await AssetManifest.loadFromAssetBundle(rootBundle);

      final assets = assetManifest.listAssets();

      final applicationSupportDirectory = await getApplicationSupportDirectory();

      final shadersDirectory = Directory(
        path.join(applicationSupportDirectory.path, 'anime_shaders'),
      );

      if (!await shadersDirectory.exists()) {
        await shadersDirectory.create(recursive: true);

        Log.i(
          'ShaderManager: Create GLSL Shader directory: '
          '${shadersDirectory.path}',
        );
      }

      final shaderFiles = assets.where(
        (asset) => asset.startsWith('assets/shaders/') && asset.endsWith('.glsl'),
      );

      int copiedFilesCount = 0;
      int skippedFilesCount = 0;

      for (final assetPath in shaderFiles) {
        final fileName = path.basename(assetPath);

        final targetFile = File(path.join(shadersDirectory.path, fileName));

        if (await targetFile.exists()) {
          skippedFilesCount++;

          Log.i(
            'ShaderManager: GLSL Shader exists, skip: '
            '${targetFile.path}',
          );

          continue;
        }

        try {
          final data = await rootBundle.load(assetPath);

          final bytes = data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);

          await targetFile.writeAsBytes(bytes, flush: true);

          copiedFilesCount++;

          Log.i(
            'ShaderManager: Copy GLSL Shader: '
            '${targetFile.path}',
          );
        } catch (e, s) {
          Log.e(
            'ShaderManager: Failed to copy GLSL Shader: '
            '$assetPath',
            s,
          );
        }
      }

      _shadersDirectory = shadersDirectory;

      Log.i(
        'ShaderManager: Initialize completed. '
        'copied=$copiedFilesCount, '
        'skipped=$skippedFilesCount, '
        'directory=${shadersDirectory.path}',
      );

      return shadersDirectory;
    } catch (e, s) {
      Log.e('ShaderManager: Initialize failed', s);

      rethrow;
    }
  }

  Future<File?> getShaderFile(String fileName) async {
    final directory = _shadersDirectory;

    if (directory == null) {
      await initialize();
    }

    final currentDirectory = _shadersDirectory;

    if (currentDirectory == null) {
      return null;
    }

    final file = File(path.join(currentDirectory.path, fileName));

    if (!await file.exists()) {
      Log.w('ShaderManager: Shader not found: ${file.path}');

      return null;
    }

    return file;
  }

  Future<String?> getShaderPath(String fileName) async {
    final file = await getShaderFile(fileName);
    return file?.path;
  }

  Future<Directory> refresh() async {
    _shadersDirectory = null;
    return initialize();
  }
}
