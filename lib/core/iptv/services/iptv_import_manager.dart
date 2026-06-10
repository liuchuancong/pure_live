import 'dart:io';
import 'dart:async';
import 'dart:convert';
import 'package:path/path.dart' as p;
import 'package:drift/drift.dart' as drift;
import 'package:pure_live/common/index.dart';
import 'package:file_picker/file_picker.dart';
import 'package:pure_live/core/common/log.dart';
import 'package:synchronized/synchronized.dart';
import 'package:pure_live/plugins/file_utils.dart';
import 'package:pure_live/plugins/db_service.dart';
import 'package:pure_live/core/common/http_client.dart';
import 'package:charset_converter/charset_converter.dart';
import 'package:pure_live/core/iptv/parsers/m3u_parser.dart';
import 'package:pure_live/core/iptv/parsers/txt_parser.dart';
import 'package:pure_live/common/global/app_path_manager.dart';
import 'package:pure_live/core/iptv/local/database.dart' as database;

class IptvImportManager {
  static final _mappingLock = Lock();

  /// 1. 本地文件浏览器选择导入
  Future<bool> importFromLocalPicker() async {
    FilePickerResult? result = await FilePicker.pickFiles(
      dialogTitle: i18n("select_recover_file"),
      type: FileType.custom,
      allowedExtensions: ['m3u', 'txt'],
    );

    if (result == null || result.files.single.path == null) return false;

    final file = File(result.files.single.path!);
    final name = FileUtils.getBaseName(file.path);
    return await importIptvFile(file: file, providerName: name);
  }

  Future<bool> importFromNetworkUrl(
    String url,
    String fileName, {
    bool forceUpdate = false,
    bool showTips = true,
    bool isHot = false,
  }) async {
    File? tempFile;
    try {
      final dir = await AppPathManager().getDir(AppPathManager.dirIptvCache);
      final lowercaseUrl = url.toLowerCase().trim();
      String detectedExtension = '.m3u';
      if (lowercaseUrl.endsWith('.txt')) {
        detectedExtension = '.txt';
      }

      final initialFilePath = p.join(dir.path, 'download_iptv_${FileUtils.generateUuid()}$detectedExtension');
      tempFile = File(initialFilePath);
      await HttpClient.instance.download(url, tempFile.path);
      Log.d('Downloaded file: ${tempFile.path}');
      if (!await tempFile.exists() || await tempFile.length() == 0) {
        if (showTips) ToastUtil.show(i18n("unsupported_file_format"));
        if (await tempFile.exists()) await tempFile.delete();
        return false;
      }
      final lines = await tempFile
          .openRead()
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .take(50) // Read up to 50 lines to inspect structure
          .toList();

      final headerSample = lines.join('\n').trim();
      if (headerSample.isEmpty) {
        if (showTips) ToastUtil.show(i18n("unsupported_file_format"));
        if (await tempFile.exists()) await tempFile.delete();
        return false;
      }

      // 4. Strict format detection check based on downloaded file content
      String finalExtension = '.m3u';
      if (headerSample.startsWith('#EXTM3U')) {
        finalExtension = '.m3u';
      } else if (headerSample.contains(',#genre#')) {
        finalExtension = '.txt';
      } else if (lowercaseUrl.endsWith('.txt')) {
        finalExtension = '.txt';
      } else if (lowercaseUrl.endsWith('.m3u') || lowercaseUrl.endsWith('.m3u8')) {
        finalExtension = '.m3u';
      } else {
        if (showTips) ToastUtil.show(i18n("unsupported_file_format"));
        if (await tempFile.exists()) await tempFile.delete();
        return false;
      }
      if (detectedExtension != finalExtension) {
        final correctedPath = p.setExtension(tempFile.path, finalExtension);
        tempFile = await tempFile.rename(correctedPath);
      }

      // 6. Clean up the filename
      String cleanName = p.basename(fileName);
      while (p.extension(cleanName).isNotEmpty) {
        cleanName = p.basenameWithoutExtension(cleanName);
      }
      fileName = cleanName;
      final success = await importIptvFile(
        file: tempFile,
        providerName: fileName,
        url: url,
        forceUpdate: forceUpdate,
        showTips: showTips,
        isHot: isHot,
      );
      if (await tempFile.exists()) await tempFile.delete();
      return success;
    } catch (e) {
      debugPrint("Network IPTV Download Failure: $e");
      if (tempFile != null && await tempFile.exists()) {
        try {
          await tempFile.delete();
        } catch (_) {}
      }
      if (showTips) {
        ToastUtil.show(i18n('download_failed'));
      }
      return false;
    }
  }

  Future<bool> importFromWebString(
    String fileString,
    String fileName, {
    bool forceUpdate = false,
    bool showTips = true,
  }) async {
    try {
      String extension = '.m3u';
      final lowerName = fileName.toLowerCase();
      final trimmedContent = fileString.trim();

      if (trimmedContent.startsWith('#EXTM3U')) {
        extension = '.m3u';
      } else if (trimmedContent.startsWith('{') || trimmedContent.startsWith('[')) {
        extension = '.json';
      } else if (lowerName.contains('.txt') || trimmedContent.contains(',#genre#')) {
        extension = '.txt';
      } else {
        final lastDotIndex = lowerName.lastIndexOf('.');
        if (lastDotIndex != -1) {
          final rawExt = lowerName.substring(lastDotIndex);
          if (rawExt == '.m3u' || rawExt == '.m3u8' || rawExt == '.txt' || rawExt == '.json') {
            extension = rawExt;
          }
        }
      }

      final dir = await AppPathManager().getDir(AppPathManager.dirIptvCache);
      final file = File(p.join(dir.path, 'web_iptv_${FileUtils.generateUuid()}$extension'));
      await file.writeAsString(fileString);

      String cleanName = p.basename(fileName);
      while (p.extension(cleanName).isNotEmpty) {
        cleanName = p.basenameWithoutExtension(cleanName);
      }
      fileName = cleanName;

      final success = await importIptvFile(
        file: file,
        providerName: fileName,
        forceUpdate: forceUpdate,
        showTips: showTips,
      );
      if (await file.exists()) await file.delete();
      return success;
    } catch (e) {
      if (showTips) {
        ToastUtil.show(i18n('subscription_download_or_parse_failed'));
      }
      return false;
    }
  }

  Future<bool> importFromSharedMedia(dynamic media, {bool forceUpdate = false, bool showTips = true}) async {
    try {
      if (media.content == null || media.content!.isEmpty) {
        if (showTips) {
          ToastUtil.show(i18n("local_import_failed"));
        }
        return false;
      }

      File file = await FileUtils.convertPhysicalFile(media.content!);
      final ext = p.extension(file.path).toLowerCase();
      if (ext != '.m3u' && ext != '.txt') {
        if (showTips) {
          ToastUtil.show(i18n("unsupported_file_format"));
        }
        return false;
      }

      final success = await importIptvFile(
        file: file,
        providerName: FileUtils.getBaseName(file.path),
        forceUpdate: forceUpdate,
        showTips: showTips,
      );
      return success;
    } catch (e) {
      debugPrint("Shared IPTV Import Process Crash: $e");
      if (showTips) {
        ToastUtil.show(i18n("local_import_failed"));
      }
      return false;
    }
  }

  Future<bool> importIptvFile({
    required File file,
    required String providerName,
    bool isHot = false,
    String url = '',
    bool forceUpdate = false,
    bool showTips = true,
  }) async {
    try {
      final cleanName = providerName.trim().toLowerCase();
      final ext = p.extension(file.path).toLowerCase();
      final typeName = ext == '.txt' ? 'TXT' : 'M3U';

      String content;
      try {
        final bytes = await file.readAsBytes();
        if (bytes.length >= 3 && bytes[0] == 0xEF && bytes[1] == 0xBB && bytes[2] == 0xBF) {
          content = utf8.decode(bytes.sublist(3));
        } else {
          content = utf8.decode(bytes);
        }
      } catch (_) {
        final bytes = await file.readAsBytes();
        content = await CharsetConverter.decode("gbk", bytes);
      }

      String finalProviderId = isHot || providerName == 'hot'
          ? FileUtils.systemHotProviderId
          : FileUtils.generateUuid();
      final parsedResult = ext == '.txt'
          ? TxtParser().parse(content, providerId: finalProviderId)
          : M3uParser().parse(content, providerId: finalProviderId);

      if (parsedResult.channels.isEmpty) {
        if (showTips) {
          ToastUtil.show(i18n("unsupported_file_format"));
        }
        return false;
      }
      final db = Get.find<DbService>().db;
      if (!isHot && !forceUpdate) {
        final existing = await db.getAllProviders();
        final matchedList = existing.where((p) => p.name.trim().toLowerCase() == cleanName).toList();
        if (matchedList.isNotEmpty) {
          final completer = Completer<bool>();
          Get.dialog(
            AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Text(i18n("provider_name_exists_tip")),
              content: Text('"$providerName"\n\n${i18n("replace_confirm_message").replaceAll("{}", typeName)}'),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(Get.context!).pop();
                    completer.complete(false);
                  },
                  child: Text(i18n("cancel")),
                ),
                TextButton(
                  onPressed: () async {
                    Navigator.of(Get.context!).pop();
                    final targetId = matchedList.first.id;
                    if (matchedList.length > 1) {
                      for (int i = 1; i < matchedList.length; i++) {
                        final duplicateItem = matchedList[i];
                        await db.deleteProviderAndChannels(duplicateItem.id);
                        await db.deleteMappingsByProviderId(duplicateItem.id);
                      }
                    }
                    final success = await _saveToDatabase(
                      file: file,
                      ext: ext,
                      providerId: targetId,
                      providerName: providerName,
                      isHot: isHot,
                      url: url,
                      channels: parsedResult.channels,
                    );
                    completer.complete(success);
                  },
                  child: Text(i18n("confirm")),
                ),
              ],
            ),
            barrierDismissible: false,
          );
          return await completer.future;
        }
      }

      final success = await _saveToDatabase(
        file: file,
        ext: ext,
        providerId: finalProviderId,
        providerName: providerName,
        isHot: isHot,
        url: url,
        channels: parsedResult.channels,
      );

      if (success) {
        if (showTips) ToastUtil.show(i18n("sync_success"));
      } else {
        if (showTips) ToastUtil.show(i18n("sync_failed"));
      }
      return success;
    } catch (e) {
      debugPrint("IPTV Import Error: $e");
      if (showTips) {
        ToastUtil.show('${i18n("sync_failed")}: ${e.toString()}');
      }
      return false;
    }
  }

  Future<bool> _saveToDatabase({
    required File file,
    required String ext,
    required String providerId,
    required String providerName,
    required bool isHot,
    required String url,
    required List<dynamic> channels,
  }) async {
    try {
      final dir = await AppPathManager().getDir(AppPathManager.dirIptvCache);
      final savedFile = File(p.join(dir.path, '$providerId$ext'));
      final db = Get.find<DbService>().db;

      if (isHot && await savedFile.exists()) await savedFile.delete();
      await file.copy(savedFile.path);
      await db.deleteProviderAndChannels(providerId);
      await db.upsertProvider(
        database.ProvidersCompanion.insert(
          id: providerId,
          name: providerName.trim(),
          type: ext.replaceAll('.', ''),
          isAutoUpdate: drift.Value(url.isNotEmpty ? SettingsService.to.iptv.isAutoSyncEnabled.v : false),
          url: drift.Value<String?>(url.isNotEmpty ? url : savedFile.path),
        ),
      );

      await db.upsertChannels(
        channels.map((e) {
          return database.ChannelsCompanion.insert(
            id: e.id,
            providerId: providerId,
            name: e.name,
            streamUrl: e.streamUrl,
            groupTitle: drift.Value(e.groupTitle),
            tvgId: drift.Value(e.tvgId),
            tvgName: drift.Value(e.tvgName),
            tvgLogo: drift.Value(e.tvgLogo),
          );
        }).toList(),
      );
      await runAutoEpgMapping(providerId: providerId);
      return true;
    } catch (e) {
      debugPrint("Database Write Error: $e");
      return false;
    }
  }

  Future<void> runAutoEpgMapping({required String providerId}) async {
    await _mappingLock.synchronized(() async {
      try {
        final db = Get.find<DbService>().db;
        final String currentEpgSourceId = SettingsService.to.iptv.selectedSourceId.v;
        if (currentEpgSourceId.isEmpty) return;
        final channels = await db.getChannelsForProvider(providerId);
        final epgChannels = await db.getEpgChannelsForSource(currentEpgSourceId);
        await db.transaction(() async {
          final clearQuery = db.delete(db.epgMappings);
          clearQuery.where((t) => t.providerId.equals(providerId));
          await clearQuery.go();
        });

        if (channels.isEmpty || epgChannels.isEmpty) return;

        final cleanRegex = RegExp(r'[^a-zA-Z0-9\u4e00-\u9fa5]');
        List<database.EpgMappingsCompanion> mappingBatch = [];

        for (var ch in channels) {
          String? matchedEpgChannelId;
          final cleanTvgId = ch.tvgId?.trim().toLowerCase();
          final cleanChId = ch.id.trim().toLowerCase();

          final idMatch = epgChannels.firstWhereOrNull((dbCh) {
            final targetEpgId = dbCh.channelId.trim().toLowerCase();
            return (cleanTvgId != null && targetEpgId == cleanTvgId) || (targetEpgId == cleanChId);
          });

          if (idMatch != null) {
            matchedEpgChannelId = idMatch.id;
          } else {
            final targetClean = ch.name.toLowerCase().replaceAll(cleanRegex, '');
            final nameMatch = epgChannels.firstWhereOrNull((dbCh) {
              final dbChClean = dbCh.displayName.toLowerCase().replaceAll(cleanRegex, '');
              return targetClean.contains(dbChClean) || dbChClean.contains(targetClean);
            });

            if (nameMatch != null) {
              matchedEpgChannelId = nameMatch.id;
            }
          }

          if (matchedEpgChannelId != null) {
            mappingBatch.add(
              database.EpgMappingsCompanion.insert(
                channelId: ch.id,
                providerId: providerId,
                epgChannelId: matchedEpgChannelId,
                epgSourceId: currentEpgSourceId,
                source: const drift.Value('auto'),
              ),
            );
          }
        }
        if (mappingBatch.isNotEmpty) {
          await db.transaction(() async {
            await db.upsertMappings(mappingBatch);
          });
          debugPrint("📊 [Auto Mapping] 成功在后台为该直播源生成了 ${mappingBatch.length} 条 EPG 映射记录！");
        }
      } catch (e) {
        debugPrint("Auto Mapping runner process crashed: $e");
      }
    });
  }
}
