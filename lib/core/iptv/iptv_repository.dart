import 'package:drift/drift.dart';
import 'package:pure_live/get/get.dart' hide Value;
import 'package:pure_live/plugins/db_service.dart';
import 'package:pure_live/core/iptv/models/channel.dart' as models;
import 'package:pure_live/core/iptv/local/database.dart' as database;
import 'package:pure_live/core/iptv/loader/playlist_loader.dart' as loader;

class IptvRepository extends GetxService {
  late final database.AppDatabase db;

  Future<IptvRepository> init() async {
    db = Get.find<DbService>().db;
    loadHot();
    return this;
  }

  Future<List<models.Channel>> loadProvider({required String providerId, String? url, String? filePath}) async {
    final channels = await loader.PlaylistLoader.load(providerId: providerId, url: url, filePath: filePath);
    if (channels.isNotEmpty) {
      await _saveToDb(providerId, channels);
    }
    return channels;
  }

  Future<void> _saveToDb(String providerId, List<models.Channel> channels) async {
    if (channels.isEmpty) return;
    await db.deleteProvider(providerId);
    await db.upsertChannels(
      channels.map((e) {
        return database.ChannelsCompanion.insert(
          id: e.id,
          providerId: providerId,
          name: e.name,
          streamUrl: e.streamUrl,
          groupTitle: Value(e.groupTitle),
          tvgId: Value(e.tvgId),
          tvgName: Value(e.tvgName),
          tvgLogo: Value(e.tvgLogo),
        );
      }).toList(),
    );
  }

  Future<List<models.Channel>> getChannels(String providerId) async {
    final rows = await db.getChannelsForProvider(providerId);

    return rows.map((e) {
      return models.Channel(
        id: e.id,
        name: e.name,
        streamUrl: e.streamUrl,
        groupTitle: e.groupTitle,
        tvgId: e.tvgId,
        tvgName: e.tvgName,
        tvgLogo: e.tvgLogo,
        providerId: providerId,
      );
    }).toList();
  }

  Future<List<models.Channel>> loadHot() {
    return loadProvider(providerId: 'hot');
  }
}
