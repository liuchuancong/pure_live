import 'package:xml/xml.dart';
import 'package:dio/dio.dart' as dio;
import 'package:drift/drift.dart' as drift;
import 'package:pure_live/common/index.dart';
import 'package:pure_live/plugins/db_service.dart';
import 'package:pure_live/plugins/file_recover_utils.dart';
import 'package:pure_live/core/iptv/local/database.dart' as database;

class EpgSyncManager {
  Future<bool> updateEpgCache({
    required String sourceName,
    required String downloadUrl,
    bool forceUpdate = false,
  }) async {
    try {
      final db = Get.find<DbService>().db;
      final cleanName = sourceName.trim().toLowerCase();
      String finalSourceId = FileRecoverUtils.getUUid();

      final existing = await db.getAllEpgSources();
      final matchedList = existing.where((e) => (e.name).trim().toLowerCase() == cleanName).toList();

      if (matchedList.isNotEmpty) {
        if (!forceUpdate) {
          Get.dialog(
            AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Text(i18n("provider_name_exists_tip")),
              content: Text('${i18n("active_epg_source")} "$sourceName" ${i18n("delete_confirm_message")}'),
              actions: [
                TextButton(onPressed: () => Navigator.of(Get.context!).pop(), child: Text(i18n("cancel"))),
                TextButton(
                  onPressed: () async {
                    Navigator.of(Get.context!).pop();
                    await updateEpgCache(sourceName: sourceName, downloadUrl: downloadUrl, forceUpdate: true);
                  },
                  child: Text(i18n("confirm")),
                ),
              ],
            ),
          );
          return false;
        }

        finalSourceId = matchedList.first.id;

        if (matchedList.length > 1) {
          for (int i = 1; i < matchedList.length; i++) {
            final duplicateItem = matchedList[i];
            await (db.delete(db.epgProgrammes)..where((t) => t.sourceId.equals(duplicateItem.id))).go();
            await (db.delete(db.epgChannels)..where((t) => t.sourceId.equals(duplicateItem.id))).go();
            await (db.delete(db.epgSources)..where((t) => t.id.equals(duplicateItem.id))).go();
          }
        }
      }

      final dioInstance = dio.Dio(
        dio.BaseOptions(
          connectTimeout: const Duration(seconds: 15),
          receiveTimeout: const Duration(seconds: 15),
          validateStatus: (status) => status != null && status >= 200 && status < 500,
        ),
      );

      dio.Response? response;
      int retryCount = 0;
      int delaySeconds = 2;

      while (retryCount < 3) {
        response = await dioInstance.get(downloadUrl, options: dio.Options(responseType: dio.ResponseType.plain));
        if (response.statusCode == 429) {
          retryCount++;
          if (retryCount >= 3) break;
          await Future.delayed(Duration(seconds: delaySeconds));
          delaySeconds *= 2;
          continue;
        }
        break;
      }

      if (response == null || response.statusCode != 200) {
        throw Exception("Network Error with status: ${response?.statusCode}");
      }

      await db.upsertEpgSource(
        database.EpgSourcesCompanion.insert(
          id: finalSourceId,
          name: sourceName,
          url: downloadUrl,
          lastRefresh: drift.Value(DateTime.now()),
        ),
      );

      final document = XmlDocument.parse(response.data as String);
      final xmlProgrammes = document.findAllElements('programme');
      List<database.EpgProgrammesCompanion> parseBatch = [];

      await (db.delete(db.epgProgrammes)..where((t) => t.sourceId.equals(finalSourceId))).go();

      for (var element in xmlProgrammes) {
        final channelId = element.getAttribute('channel') ?? '';
        final startStr = element.getAttribute('start') ?? '';
        final stopStr = element.getAttribute('stop') ?? '';
        final title = element.findElements('title').firstOrNull?.innerText ?? 'No Title';
        final desc = element.findElements('desc').firstOrNull?.innerText;
        if (channelId.isEmpty || startStr.isEmpty) continue;

        final DateTime parsedStart = _parseXmltvDateTime(startStr);
        final DateTime parsedStop = _parseXmltvDateTime(stopStr);

        parseBatch.add(
          database.EpgProgrammesCompanion(
            epgChannelId: drift.Value(channelId),
            sourceId: drift.Value(finalSourceId),
            title: drift.Value(title),
            description: drift.Value(desc),
            start: drift.Value(parsedStart),
            stop: drift.Value(parsedStop),
          ),
        );

        if (parseBatch.length >= 500) {
          await db.insertProgrammes(parseBatch);
          parseBatch.clear();
        }
      }

      if (parseBatch.isNotEmpty) {
        await db.insertProgrammes(parseBatch);
      }

      await db.updateEpgSourceRefreshTime(finalSourceId);
      await db.pruneOldProgrammes(maxAge: const Duration(days: 2));

      ToastUtil.show(i18n("epg_source_updated"));
      return true;
    } catch (e) {
      debugPrint("$e");
      ToastUtil.show(i18n("epg_import_failed"));
      return false;
    }
  }

  DateTime _parseXmltvDateTime(String xmltvDate) {
    final rawDigits = xmltvDate.split(' ').first;
    if (rawDigits.length >= 14) {
      final year = int.parse(rawDigits.substring(0, 4));
      final month = int.parse(rawDigits.substring(4, 6));
      final day = int.parse(rawDigits.substring(6, 8));
      final hour = int.parse(rawDigits.substring(8, 10));
      final minute = int.parse(rawDigits.substring(10, 12));
      final second = int.parse(rawDigits.substring(12, 14));
      return DateTime(year, month, day, hour, minute, second);
    }
    return DateTime.now();
  }
}
