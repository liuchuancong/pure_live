import 'dart:developer';
import 'package:pure_live/common/index.dart';
import 'package:pure_live/plugins/db_service.dart';
import 'package:pure_live/plugins/file_utils.dart';
import 'package:pure_live/model/live_category.dart';
import 'package:pure_live/model/live_anchor_item.dart';
import 'package:pure_live/model/live_play_quality.dart';
import 'package:pure_live/core/iptv/local/database.dart';
import 'package:pure_live/core/interface/live_site.dart';
import 'package:pure_live/core/iptv/iptv_repository.dart';
import 'package:pure_live/core/iptv/core/fuzzy_match.dart';
import 'package:pure_live/core/danmaku/empty_danmaku.dart';
import 'package:pure_live/core/interface/live_danmaku.dart';
import 'package:pure_live/core/iptv/services/auto_sync_scheduler.dart';

class IptvSite implements LiveSite {
  final db = Get.find<DbService>().db;

  @override
  String id = 'iptv';

  @override
  String name = '网络';

  String defaultAvatar =
      "https://img95.699pic.com/xsj/0q/x6/7p.jpg%21/fw/700/watermark/url/L3hzai93YXRlcl9kZXRhaWwyLnBuZw/align/southeast";

  @override
  Future<List<LiveCategory>> getCategores(int page, int pageSize) async {
    final providers = await db.getAllProviders();

    final categoryTypes = <LiveCategory>[];

    for (final provider in providers) {
      if (provider.id == FileUtils.systemHotProviderId || provider.name == 'hot') {
        continue;
      } else {
        final channels = await db.getChannelsForProvider(provider.id);

        final subs = <LiveArea>[];
        for (final ch in channels) {
          subs.add(
            LiveArea(
              areaId: ch.id,
              areaName: ch.name,
              areaPic: ch.tvgLogo ?? '',
              typeName: provider.name,
              areaType: provider.id,
              platform: Sites.iptvSite,
            ),
          );
        }

        categoryTypes.add(LiveCategory(id: provider.id, name: provider.name, children: subs));
      }
    }
    return categoryTypes;
  }

  // =========================================================
  // 分类下频道
  // =========================================================

  @override
  Future<List<LiveRoom>> getCategoryRooms(LiveArea category, {int page = 1, int pageSize = 30}) async {
    final items = <LiveRoom>[];

    final ch = await db.getChannelById(category.areaId!);
    if (ch == null) return [];

    final mapping = await db.getMappingByChannelId(ch.id);
    EpgProgramme? nowProg;
    if (mapping?.epgChannelId != null) {
      final nowList = await db.getNowPlaying([mapping!.epgChannelId]);
      if (nowList.isNotEmpty) nowProg = nowList.first;
    }

    items.add(
      LiveRoom(
        roomId: ch.id,
        title: ch.name,
        nick: ch.groupTitle ?? '',
        cover: ch.tvgLogo ?? '',
        area: ch.groupTitle ?? '',
        watching: '',
        avatar: defaultAvatar,
        status: true,
        liveStatus: LiveStatus.live,
        platform: Sites.iptvSite,
        link: ch.streamUrl,
        data: ch.streamUrl,
        epgId: mapping?.epgChannelId,
        currentProgramme: nowProg?.title,
        currentProgrammeDescription: nowProg?.description,
      ),
    );

    return items;
  }

  // =========================================================
  // 房间详情
  // =========================================================

  @override
  Future<LiveRoom> getRoomDetail({required String platform, required String roomId}) async {
    final channel = await db.getChannelById(roomId);
    if (channel == null) {
      if (channel == null) {
        return LiveRoom(
          cover: '',
          watching: '',
          roomId: roomId,
          area: '',
          title: '',
          nick: '',
          avatar: defaultAvatar,
          introduction: '',
          notice: '',
          status: true,
          liveStatus: LiveStatus.live,
          platform: Sites.iptvSite,
          link: roomId,
          data: roomId,
        );
      }
    }
    String? finalEpgChannelId;
    final String currentEpgSourceId = SettingsService.to.iptv.selectedSourceId.v;

    if (currentEpgSourceId.isEmpty) {
      return _buildLiveRoom(channel, null);
    }

    EpgMapping? existingMapping = await db.getMappingByChannelId(roomId);
    if (existingMapping == null && channel.tvgId != null && channel.tvgId!.isNotEmpty) {
      existingMapping = await db.getMappingByTvid(channel.tvgId!);
    }
    if (existingMapping != null && existingMapping.epgSourceId == currentEpgSourceId) {
      finalEpgChannelId = existingMapping.epgChannelId;
    } else {
      final dbChannels = await db.getEpgChannelsForSource(currentEpgSourceId);

      log(dbChannels.length.toString());
      if (dbChannels.isNotEmpty) {
        final cleanTvgId = channel.tvgId?.trim().toLowerCase();
        if (cleanTvgId != null && cleanTvgId.isNotEmpty) {
          final matchedTvg = dbChannels.firstWhereOrNull((dbCh) {
            return dbCh.channelId.trim().toLowerCase() == cleanTvgId;
          });
          if (matchedTvg != null) {
            finalEpgChannelId = matchedTvg.id;
          }
        }
        if (finalEpgChannelId == null) {
          final cleanRegex = RegExp(r'[^a-zA-Z0-9\u4e00-\u9fa5]');
          final suffixRegex = RegExp(r'(综合|高清|超清|中央|电视台|频道|hd)', caseSensitive: false);

          String targetClean = channel.name.trim().split(' ').first;
          targetClean = targetClean.toLowerCase().replaceAll(cleanRegex, '');
          targetClean = targetClean.replaceAll(suffixRegex, '').trim();

          var matchedList = dbChannels.where((dbCh) {
            String dbClean = dbCh.displayName.trim().split(' ').first;
            dbClean = dbClean.toLowerCase().replaceAll(cleanRegex, '');
            dbClean = dbClean.replaceAll(suffixRegex, '').trim();

            return targetClean.contains(dbClean) || dbClean.contains(targetClean);
          }).toList();

          if (matchedList.isNotEmpty) {
            matchedList.sort((a, b) {
              String aClean = a.displayName
                  .trim()
                  .split(' ')
                  .first
                  .toLowerCase()
                  .replaceAll(cleanRegex, '')
                  .replaceAll(suffixRegex, '')
                  .trim();
              String bClean = b.displayName
                  .trim()
                  .split(' ')
                  .first
                  .toLowerCase()
                  .replaceAll(cleanRegex, '')
                  .replaceAll(suffixRegex, '')
                  .trim();

              final aPerfect = aClean == targetClean;
              final bPerfect = bClean == targetClean;

              if (aPerfect && !bPerfect) return -1;
              if (bPerfect && !aPerfect) return 1;
              if (aPerfect && bPerfect) return 0;

              final scoreA = fuzzyMatch(channel.name, [a.displayName]);
              final scoreB = fuzzyMatch(channel.name, [b.displayName]);
              return scoreB.compareTo(scoreA);
            });

            finalEpgChannelId = matchedList.first.id;
          }
        }
      }
    }

    EpgProgramme? nowProg;
    if (finalEpgChannelId != null) {
      final list = await db.getNowPlaying([finalEpgChannelId]);
      if (list.isNotEmpty) nowProg = list.first;
    }

    return _buildLiveRoom(channel, nowProg, epgId: finalEpgChannelId);
  }

  LiveRoom _buildLiveRoom(Channel channel, EpgProgramme? prog, {String? epgId}) {
    return LiveRoom(
      roomId: channel.id,
      title: channel.name,
      nick: channel.tvgName ?? channel.name,
      cover: channel.tvgLogo ?? '',
      area: channel.groupTitle ?? '',
      watching: '',
      avatar: defaultAvatar,
      status: true,
      liveStatus: LiveStatus.live,
      platform: Sites.iptvSite,
      link: channel.streamUrl,
      data: channel.streamUrl,
      epgId: epgId,
      currentProgramme: prog?.title,
      currentProgrammeDescription: prog?.description,
    );
  }

  // =========================================================
  // 推荐（热门）
  // =========================================================

  @override
  Future<List<LiveRoom>> getRecommendRooms({int page = 1, int pageSize = 30}) async {
    var channels = await IptvRepository().getChannels(FileUtils.systemHotProviderId);
    if (channels.isEmpty) {
      await AutoSyncScheduler.instance.loadHotResources();
    }
    channels = await IptvRepository().getChannels(FileUtils.systemHotProviderId);
    final items = <LiveRoom>[];
    for (final ch in channels) {
      items.add(
        LiveRoom(
          roomId: ch.id,
          title: ch.name,
          nick: '',
          cover: ch.tvgLogo ?? '',
          area: ch.groupTitle ?? '',
          watching: '',
          avatar: defaultAvatar,
          introduction: ch.name,
          notice: '',
          status: true,
          liveStatus: LiveStatus.live,
          platform: Sites.iptvSite,
          link: ch.streamUrl,
          data: ch.streamUrl,
        ),
      );
    }

    return items;
  }

  // =========================================================
  // 播放质量
  // =========================================================

  @override
  Future<List<LivePlayQuality>> getPlayQualites({required LiveRoom detail}) async {
    return [
      LivePlayQuality(quality: '默认', sort: 1, data: <String>[detail.data]),
    ];
  }

  // =========================================================
  // 播放地址
  // =========================================================

  @override
  Future<List<String>> getPlayUrls({required LiveRoom detail, required LivePlayQuality quality}) async {
    return quality.data as List<String>;
  }

  // =========================================================
  // 弹幕
  // =========================================================

  @override
  LiveDanmaku getDanmaku() => EmptyDanmaku();

  // =========================================================
  // 直播状态
  // =========================================================

  @override
  Future<bool> getLiveStatus({required String platform, required String roomId}) async {
    return true;
  }

  // =========================================================
  // 超级留言
  // =========================================================

  @override
  Future<List<LiveSuperChatMessage>> getSuperChatMessage({required String roomId}) async {
    return [];
  }

  // =========================================================
  // 搜索主播
  // =========================================================

  @override
  Future<List<LiveAnchorItem>> searchAnchors(String keyword, {int page = 1, int pageSize = 30}) async {
    return [];
  }

  // =========================================================
  // 搜索频道
  // =========================================================

  @override
  Future<List<LiveRoom>> searchRooms(String keyword, {int page = 1, int pageSize = 30}) async {
    if (keyword.trim().isEmpty) return [];
    final matched = await db.searchChannelsByName(keyword);
    final items = matched.map((ch) {
      return LiveRoom(
        roomId: ch.id,
        title: ch.name,
        nick: ch.groupTitle ?? '',
        cover: ch.tvgLogo ?? '',
        area: ch.groupTitle ?? '',
        watching: '',
        avatar: defaultAvatar,
        status: true,
        liveStatus: LiveStatus.live,
        platform: Sites.iptvSite,
        link: ch.streamUrl,
        data: ch.streamUrl,
      );
    }).toList();
    return items;
  }
}
