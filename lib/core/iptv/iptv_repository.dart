import 'dart:developer';

import 'package:pure_live/get/get.dart' hide Value;
import 'package:pure_live/core/plugins/db_service.dart';
import 'package:pure_live/core/iptv/models/channel.dart' as models;
import 'package:pure_live/core/iptv/local/database.dart' as database;
import 'package:pure_live/core/common/http_header_policy.dart';

class IptvRepository extends GetxService {
  Future<IptvRepository> init() async {
    return this;
  }

  Future<List<models.Channel>> getChannels(String providerId) async {
    try {
      final db = Get.find<DbService>().db;
      final List<database.Channel> dbChannels = await db.getChannelsForProvider(providerId);
      return dbChannels.map((e) {
        return models.Channel(
          id: e.id,
          providerId: e.providerId,
          name: e.name,
          streamUrl: e.streamUrl,
          groupTitle: e.groupTitle,
          tvgId: e.tvgId,
          tvgName: e.tvgName,
          tvgLogo: e.tvgLogo,
          catchupMode: e.catchupMode,
          catchupSource: e.catchupSource,
          catchupDays: e.catchupDays,
          catchupCorrectionHours: e.catchupCorrectionHours,
          httpHeaders: HttpHeaderPolicy.decode(e.httpHeadersJson),
        );
      }).toList();
    } catch (e) {
      log("Repository getChannels Execution Error: $e");
      return [];
    }
  }
}
