import 'dart:developer';
import 'dart:io' hide HttpClient;
import 'package:flutter/services.dart';
import 'package:pure_live/plugins/race_http.dart';
import 'package:pure_live/core/common/http_client.dart';
import 'package:pure_live/common/models/font_model.dart';
import 'package:pure_live/common/utils/githup_mirror.dart';
import 'package:pure_live/common/global/app_path_manager.dart';

enum DownloadState { notDownloaded, downloading, downloaded }

class FontDownloadManager {
  FontDownloadManager._();
  static final FontDownloadManager instance = FontDownloadManager._();

  Future<String> get _fontRootPath async {
    final directory = await AppPathManager().getDir(AppPathManager.dirDownload);
    final fontRoot = Directory("${directory.path}/fonts");
    if (!await fontRoot.exists()) {
      await fontRoot.create(recursive: true);
    }
    return fontRoot.path;
  }

  Future<bool> checkFontDownloaded(String fontId) async {
    final root = await _fontRootPath;
    final fontDir = Directory("$root/$fontId");
    if (!await fontDir.exists()) return false;

    int validFileCount = 0;
    await for (final entity in fontDir.list()) {
      if (entity is File && (entity.path.endsWith('.ttf') || entity.path.endsWith('.otf'))) {
        validFileCount++;
      }
    }
    return validFileCount >= 1;
  }

  Future<void> loadFont(String fontId) async {
    try {
      final root = await _fontRootPath;
      final fontDir = Directory("$root/$fontId");
      if (!await fontDir.exists()) return;

      final loader = FontLoader(fontId);
      bool containsValidFonts = false;

      await for (final entity in fontDir.list()) {
        if (entity is File && (entity.path.endsWith('.ttf') || entity.path.endsWith('.otf'))) {
          loader.addFont(entity.readAsBytes().then(ByteData.sublistView));
          containsValidFonts = true;
        }
      }

      if (containsValidFonts) {
        await loader.load();
        log('FontLoader registered family: $fontId');
      }
    } catch (e) {
      log("Font registration sequence failed: $e");
    }
  }

  Future<bool> downloadFontFamily({
    required FontModel fontModel,
    required Function(DownloadState) onStateChanged,
  }) async {
    final root = await _fontRootPath;
    final fontId = fontModel.id;
    final fontDir = Directory("$root/$fontId");

    if (!await fontDir.exists()) {
      await fontDir.create(recursive: true);
    }

    onStateChanged(DownloadState.downloading);
    log("Starting block download pipeline for font family: $fontId");

    try {
      final mirror = GitHubMirror(owner: 'liuchuancong', repo: 'fonts', branch: 'master');

      for (final filePath in fontModel.files) {
        final fileName = filePath.split('/').last;
        final file = File("${fontDir.path}/$fileName");

        if (await file.exists()) {
          final length = await file.length();
          if (length == 0) {
            await file.delete();
          } else {
            continue;
          }
        }

        final urls = mirror.mirrors(filePath);
        final fastestUrl = await RaceHttp.findFastestUrl(urls);
        log(fastestUrl.toString(), name: "Fastest URL for $fileName");
        int retryCount = 0;
        const maxRetries = 3;

        while (retryCount < maxRetries) {
          try {
            await HttpClient().download(
              fastestUrl!,
              file.path,
              header: {
                'User-Agent':
                    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
              },
            );

            if (await file.exists() && await file.length() > 0) {
              break;
            }
            throw Exception("File is empty or corrupted");
          } catch (e) {
            retryCount++;
            if (file.existsSync()) {
              try {
                file.deleteSync();
              } catch (_) {}
            }
            if (retryCount >= maxRetries) {
              throw Exception("Failed to sync file slice: $fileName");
            }
            await Future.delayed(const Duration(seconds: 1));
          }
        }
      }

      onStateChanged(DownloadState.downloaded);
      await loadFont(fontId);
      return true;
    } catch (e, s) {
      log("Font bundle sync sequence aborted: $e, retry count exceeded $s");
      onStateChanged(DownloadState.notDownloaded);

      if (await fontDir.exists()) {
        try {
          await fontDir.delete(recursive: true);
        } catch (_) {}
      }
      return false;
    }
  }

  Future<void> deleteFontFamily(FontModel fontModel, Function(DownloadState) onStateChanged) async {
    try {
      final root = await _fontRootPath;
      final fontDir = Directory("$root/${fontModel.id}");
      if (await fontDir.exists()) {
        await fontDir.delete(recursive: true);
      }
      onStateChanged(DownloadState.notDownloaded);
    } catch (e) {
      log("Failed to delete font family: $e");
    }
  }
}
