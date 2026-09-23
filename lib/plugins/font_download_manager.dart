import 'dart:developer';
import 'dart:io' hide HttpClient;

import 'package:flutter/services.dart';
import 'package:pure_live/plugins/race_http.dart';
import 'package:pure_live/core/common/http_client.dart';
import 'package:pure_live/common/models/font_model.dart';
import 'package:pure_live/common/utils/githup_mirror.dart';
import 'package:pure_live/common/global/app_path_manager.dart';
import 'package:pure_live/common/services/settings/cache_controller.dart';
import 'package:pure_live/common/services/medels/download_status.dart';

class FontDownloadManager {
  FontDownloadManager._();
  static final FontDownloadManager instance = FontDownloadManager._();

  Future<String> get _fontRootPath async {
    // Fonts share the same user-selectable download directory as app updates
    // so both live under one folder and follow the Cache & Data setting.
    final directory = await CacheController.ensureDownloadDirectory();
    final fontRoot = Directory("${directory.path}${Platform.pathSeparator}${AppPathManager.fontDirectoryName}");
    if (!await fontRoot.exists()) {
      await fontRoot.create(recursive: true);
    }
    return fontRoot.path;
  }

  bool _isSafeFontId(String fontId) =>
      fontId.isNotEmpty && fontId != '.' && fontId != '..' && RegExp(r'^[a-zA-Z0-9._-]+$').hasMatch(fontId);

  void _notifyState(Function(DownloadState) callback, DownloadState state) {
    try {
      callback(state);
    } catch (error) {
      log('Font download state callback failed: $error');
    }
  }

  Future<Directory?> _resolveFontDirectory(String rawFontId) async {
    final fontId = rawFontId.trim();
    if (!_isSafeFontId(fontId)) return null;
    final root = await _fontRootPath;
    final fontDir = Directory("$root/$fontId");
    final previousDir = Directory("$root/.$fontId.previous");
    if (await previousDir.exists()) {
      if (await fontDir.exists()) {
        try {
          await previousDir.delete(recursive: true);
        } catch (error) {
          log('Failed to remove stale font rollback directory: $error');
        }
      } else {
        await previousDir.rename(fontDir.path);
      }
    }
    return fontDir;
  }

  Future<bool> checkFontDownloaded(String fontId) async {
    try {
      final fontDir = await _resolveFontDirectory(fontId);
      if (fontDir == null || !await fontDir.exists()) return false;

      int validFileCount = 0;
      await for (final entity in fontDir.list()) {
        final lowerPath = entity.path.toLowerCase();
        if (entity is File &&
            (lowerPath.endsWith('.ttf') || lowerPath.endsWith('.otf')) &&
            await _isValidFontFile(entity)) {
          validFileCount++;
        }
      }
      return validFileCount >= 1;
    } catch (_) {
      return false;
    }
  }

  Future<bool> loadFont(String fontId, {String fileName = ''}) async {
    try {
      final fontDir = await _resolveFontDirectory(fontId);
      if (fontDir == null || !await fontDir.exists()) return false;

      final loader = FontLoader(fontId);
      bool containsValidFonts = false;
      final files = <File>[];
      await for (final entity in fontDir.list()) {
        if (entity is File) {
          final lowerPath = entity.path.toLowerCase();
          if ((lowerPath.endsWith('.ttf') || lowerPath.endsWith('.otf')) && await _isValidFontFile(entity)) {
            files.add(entity);
          }
        }
      }
      files.sort((left, right) => left.path.compareTo(right.path));
      for (final entity in files) {
        if (fileName.isNotEmpty) {
          final currentName = entity.path.split(Platform.pathSeparator).last;
          if (currentName == fileName) {
            loader.addFont(entity.readAsBytes().then(ByteData.sublistView));
            containsValidFonts = true;
            break;
          }
        } else {
          loader.addFont(entity.readAsBytes().then(ByteData.sublistView));
          containsValidFonts = true;
        }
      }

      if (containsValidFonts) {
        await loader.load();
        log('FontLoader registered family: $fontId');
        return true;
      }
      return false;
    } catch (e) {
      log("Font registration sequence failed: $e");
      return false;
    }
  }

  Future<bool> downloadFontFamily({
    required FontModel fontModel,
    required Function(DownloadState) onStateChanged,
  }) async {
    final root = await _fontRootPath;
    final fontId = fontModel.id.trim();
    final fontDir = Directory("$root/$fontId");
    final stagedDir = Directory("$root/.$fontId.pending");
    final previousDir = Directory("$root/.$fontId.previous");

    _notifyState(onStateChanged, DownloadState.downloading);
    log("Starting block download pipeline for font family: $fontId");

    try {
      if (!_isSafeFontId(fontId) || fontModel.files.isEmpty) {
        throw const FormatException('Invalid font family manifest');
      }

      // Finish or discard an interrupted commit before staging new files.
      if (await previousDir.exists()) {
        if (await fontDir.exists()) {
          await previousDir.delete(recursive: true);
        } else {
          await previousDir.rename(fontDir.path);
        }
      }
      if (await stagedDir.exists()) await stagedDir.delete(recursive: true);
      await stagedDir.create(recursive: true);

      final mirror = GitHubMirror(owner: 'liuchuancong', repo: 'fonts', branch: 'master');
      final fileNames = <String>{};

      for (final filePath in fontModel.files) {
        final pathParts = filePath.split('/');
        final fileName = filePath.split('/').last;
        final lowerName = fileName.toLowerCase();
        if (filePath.contains('\\') ||
            pathParts.any((part) => part.isEmpty || part == '.' || part == '..') ||
            fileName.isEmpty ||
            fileName == '.' ||
            fileName == '..' ||
            RegExp(r'[<>:"/\\|?*\x00-\x1F]').hasMatch(fileName) ||
            (!lowerName.endsWith('.ttf') && !lowerName.endsWith('.otf')) ||
            !fileNames.add(fileName)) {
          throw FormatException('Invalid font file manifest: $filePath');
        }
        final existing = File("${fontDir.path}/$fileName");
        final staged = File("${stagedDir.path}/$fileName");

        if (await existing.exists() && await _isValidFontFile(existing)) {
          await existing.copy(staged.path);
          continue;
        }

        final urls = mirror.mirrors(filePath);
        final remainingUrls = List<String>.of(urls);
        int retryCount = 0;
        const maxRetries = 3;

        while (retryCount < maxRetries && remainingUrls.isNotEmpty) {
          final downloadUrl = await RaceHttp.findFastestUrl(remainingUrls);
          if (downloadUrl == null) {
            throw Exception("No reachable font source for: $fileName");
          }
          try {
            await HttpClient.instance.download(
              downloadUrl,
              staged.path,
              header: {
                'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
              },
            );

            if (await staged.exists() && await _isValidFontFile(staged)) {
              break;
            }
            throw Exception("File is empty or corrupted");
          } catch (e) {
            retryCount++;
            remainingUrls.remove(downloadUrl);
            if (staged.existsSync()) {
              try {
                staged.deleteSync();
              } catch (_) {}
            }
            if (retryCount >= maxRetries || remainingUrls.isEmpty) {
              throw Exception("Failed to sync file slice: $fileName");
            }
            await Future.delayed(const Duration(seconds: 1));
          }
        }
      }

      final hadPrevious = await fontDir.exists();
      if (hadPrevious) await fontDir.rename(previousDir.path);
      try {
        await stagedDir.rename(fontDir.path);
      } catch (_) {
        if (hadPrevious && await previousDir.exists() && !await fontDir.exists()) {
          await previousDir.rename(fontDir.path);
        }
        rethrow;
      }
      if (await previousDir.exists()) {
        try {
          await previousDir.delete(recursive: true);
        } catch (_) {
          // The new family is complete. A later update can remove this stale
          // rollback directory before staging another bundle.
        }
      }
      _notifyState(onStateChanged, DownloadState.downloaded);
      return true;
    } catch (e, s) {
      log("Font bundle sync sequence aborted: $e, retry count exceeded $s");
      if (await stagedDir.exists()) {
        try {
          await stagedDir.delete(recursive: true);
        } catch (_) {}
      }
      final retainedState = await checkFontDownloaded(fontId) ? DownloadState.downloaded : DownloadState.notDownloaded;
      _notifyState(onStateChanged, retainedState);
      return false;
    }
  }

  Future<bool> _isValidFontFile(File file) async {
    RandomAccessFile? handle;
    try {
      if (!await file.exists() || await file.length() < 12) return false;
      handle = await file.open();
      final signature = await handle.read(4);
      if (signature.length != 4) return false;
      final tag = String.fromCharCodes(signature);
      return (signature[0] == 0 && signature[1] == 1 && signature[2] == 0 && signature[3] == 0) ||
          tag == 'OTTO' ||
          tag == 'true' ||
          tag == 'typ1' ||
          tag == 'ttcf';
    } catch (_) {
      return false;
    } finally {
      await handle?.close();
    }
  }

  Future<bool> deleteFontFamily(FontModel fontModel, Function(DownloadState) onStateChanged) async {
    try {
      final fontId = fontModel.id.trim();
      if (!_isSafeFontId(fontId)) return false;
      final root = await _fontRootPath;
      for (final fontDir in [
        Directory("$root/$fontId"),
        Directory("$root/.$fontId.pending"),
        Directory("$root/.$fontId.previous"),
      ]) {
        if (await fontDir.exists()) {
          await fontDir.delete(recursive: true);
        }
      }
      _notifyState(onStateChanged, DownloadState.notDownloaded);
      return true;
    } catch (e) {
      log("Failed to delete font family: $e");
      return false;
    }
  }
}
