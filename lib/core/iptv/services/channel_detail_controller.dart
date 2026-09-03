import 'dart:collection';
import 'dart:developer';

import '../models/channel.dart';
import '../models/epg.dart' as epg;

import 'package:pure_live/common/index.dart';
import 'package:pure_live/plugins/db_service.dart';
import 'package:pure_live/core/iptv/core/fuzzy_match.dart';
import 'package:pure_live/core/iptv/local/database.dart' as database;

class EpgChannelMatchCache {
  EpgChannelMatchCache({this.maxEntries = 1024}) : assert(maxEntries > 0);

  final int maxEntries;
  final LinkedHashMap<String, String> _entries = LinkedHashMap<String, String>();

  String _key(String sourceId, String channelName) => '$sourceId\u0000$channelName';

  String? get(String sourceId, String channelName) => _entries[_key(sourceId, channelName)];

  void put(String sourceId, String channelName, String epgChannelId) {
    final key = _key(sourceId, channelName);
    _entries.remove(key);
    _entries[key] = epgChannelId;
    while (_entries.length > maxEntries) {
      _entries.remove(_entries.keys.first);
    }
  }

  void remove(String sourceId, String channelName) => _entries.remove(_key(sourceId, channelName));

  int get length => _entries.length;
}

class ChannelDetailController extends GetxController {
  static final EpgChannelMatchCache _channelNameCache = EpgChannelMatchCache();

  final Rxn<epg.EpgChannel> currentEpgChannel = Rxn<epg.EpgChannel>();
  final Rxn<epg.EpgProgramme> nowPlayingProg = Rxn<epg.EpgProgramme>();
  final RxList<epg.EpgProgramme> upcomingProgs = <epg.EpgProgramme>[].obs;
  final RxBool isLoadingEpg = false.obs;

  Future<void> loadChannelEpg(Channel channel, String currentEpgSourceId) async {
    isLoadingEpg.value = true;
    _clearCurrentEpg();
    try {
      final String queryName = channel.displayName;
      final db = Get.find<DbService>().db;
      final List<database.EpgChannel> dbChannels = await db.getEpgChannelsForSource(
        currentEpgSourceId,
      );
      if (dbChannels.isEmpty) return;

      String? matchedEpgChannelId = _channelNameCache.get(currentEpgSourceId, queryName);
      if (matchedEpgChannelId != null &&
          !dbChannels.any((channel) => channel.id == matchedEpgChannelId)) {
        // The selected EPG source was refreshed and the old id disappeared.
        _channelNameCache.remove(currentEpgSourceId, queryName);
        matchedEpgChannelId = null;
      }

      if (matchedEpgChannelId == null) {
        final matchedDbChannels = dbChannels.where((dbCh) {
          return fuzzyMatchPasses(queryName, [dbCh.displayName]);
        }).toList();

        if (matchedDbChannels.isNotEmpty) {
          matchedDbChannels.sort(
            (a, b) => fuzzyMatch(queryName, [
              b.displayName,
            ]).compareTo(fuzzyMatch(queryName, [a.displayName])),
          );
          final bestMatch = matchedDbChannels.first;
          matchedEpgChannelId = bestMatch.id;
          _channelNameCache.put(currentEpgSourceId, queryName, matchedEpgChannelId);
        }
      }
      if (matchedEpgChannelId != null) {
        final matchedDbCh = dbChannels.firstWhereOrNull((e) => e.id == matchedEpgChannelId);

        if (matchedDbCh != null) {
          currentEpgChannel.value = epg.EpgChannel(
            id: matchedDbCh.id,
            sourceId: matchedDbCh.sourceId,
            displayNames: [matchedDbCh.displayName],
            iconUrl: matchedDbCh.iconUrl,
          );
        }
        await _loadProgrammes(matchedEpgChannelId);
      }
    } catch (e) {
      log('根据频道名和 EPG 频道名进行模糊匹配时发生异常: $e');
    } finally {
      isLoadingEpg.value = false;
    }
  }

  Future<void> _loadProgrammes(String epgChannelId) async {
    final now = DateTime.now();
    final startTime = now.subtract(const Duration(minutes: 5));
    final endTime = now.add(const Duration(days: 1));

    final db = Get.find<DbService>().db;

    // 直接调用你现有的 getProgrammes
    List<database.EpgProgramme> dbProgrammes = await db.getProgrammes(
      epgChannelId: epgChannelId,
      start: startTime,
      end: endTime,
    );

    if (dbProgrammes.isEmpty) return;

    List<epg.EpgProgramme> allProgrammes = dbProgrammes.map((p) {
      return epg.EpgProgramme(
        title: p.title,
        start: p.start,
        stop: p.stop,
        channelId: p.epgChannelId,
        sourceId: p.sourceId,
      );
    }).toList();

    final validProgs = allProgrammes.where((p) => p.stop.isAfter(now)).toList();
    upcomingProgs.value = validProgs;

    try {
      nowPlayingProg.value = validProgs.firstWhere(
        (p) => p.start.isBefore(now) && p.stop.isAfter(now),
      );
    } catch (_) {
      nowPlayingProg.value = null;
    }
  }

  void _clearCurrentEpg() {
    currentEpgChannel.value = null;
    nowPlayingProg.value = null;
    upcomingProgs.clear();
  }
}
