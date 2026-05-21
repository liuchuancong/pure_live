import 'package:pure_live/common/index.dart';
import 'package:pure_live/plugins/db_service.dart';
import 'package:pure_live/model/live_category.dart';
import 'package:pure_live/model/live_play_quality.dart';
import 'package:pure_live/core/iptv/local/database.dart';
import 'package:pure_live/model/live_search_result.dart';
import 'package:pure_live/core/interface/live_site.dart';
import 'package:pure_live/core/iptv/iptv_repository.dart';
import 'package:pure_live/model/live_category_result.dart';
import 'package:pure_live/core/danmaku/empty_danmaku.dart';
import 'package:pure_live/core/interface/live_danmaku.dart';

class IptvSite implements LiveSite {
  final db = Get.find<DbService>().db;

  @override
  String id = 'iptv';

  @override
  String name = '网络';

  @override
  Future<List<LiveCategory>> getCategores(int page, int pageSize) async {
    final providers = await db.getAllProviders();

    final categoryTypes = <LiveCategory>[];

    for (final provider in providers) {
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
    return categoryTypes;
  }

  // =========================================================
  // 分类下频道
  // =========================================================

  @override
  Future<LiveCategoryResult> getCategoryRooms(LiveArea category, {int page = 1}) async {
    final items = <LiveRoom>[];

    final ch = await db.getChannelById(category.areaId!);
    if (ch == null) return LiveCategoryResult(hasMore: false, items: []);

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
        avatar:
            'https://img95.699pic.com/xsj/0q/x6/7p.jpg%21/fw/700/watermark/url/L3hzai93YXRlcl9kZXRhaWwyLnBuZw/align/southeast',
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

    return LiveCategoryResult(hasMore: false, items: items);
  }

  // =========================================================
  // 房间详情
  // =========================================================

  @override
  Future<LiveRoom> getRoomDetail({required String platform, required String roomId}) async {
    final channel = await db.getChannelById(roomId);
    if (channel == null) throw Exception('Channel not found');
    final mapping = await db.getMappingByChannelId(channel.id);
    EpgProgramme? nowProg;
    if (mapping?.epgChannelId != null) {
      final nowList = await db.getNowPlaying([mapping!.epgChannelId]);
      if (nowList.isNotEmpty) nowProg = nowList.first;
    }
    debugPrint('channel.streamUrl ${channel.streamUrl}');
    return LiveRoom(
      roomId: channel.id,
      title: channel.name,
      nick: channel.groupTitle ?? '',
      cover: channel.tvgLogo ?? '',
      area: channel.groupTitle ?? '',
      watching: '',
      avatar:
          'https://img95.699pic.com/xsj/0q/x6/7p.jpg%21/fw/700/watermark/url/L3hzai93YXRlcl9kZXRhaWwyLnBuZw/align/southeast',
      status: true,
      liveStatus: LiveStatus.live,
      platform: Sites.iptvSite,
      link: channel.streamUrl,
      data: channel.streamUrl,
      epgId: mapping?.epgChannelId,
      currentProgramme: nowProg?.title,
      currentProgrammeDescription: nowProg?.description,
    );
  }

  // =========================================================
  // 推荐（热门）
  // =========================================================

  @override
  Future<LiveCategoryResult> getRecommendRooms({int page = 1, required String nick}) async {
    final repo = Get.find<IptvRepository>();
    final channels = await repo.getChannels('hot');
    final items = <LiveRoom>[];
    for (final ch in channels) {
      items.add(
        LiveRoom(
          roomId: ch.id,
          title: ch.name,
          nick: nick,
          cover: ch.tvgLogo ?? '',
          area: ch.groupTitle ?? '',
          watching: '',
          avatar:
              'https://img95.699pic.com/xsj/0q/x6/7p.jpg%21/fw/700/watermark/url/L3hzai93YXRlcl9kZXRhaWwyLnBuZw/align/southeast',
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

    return LiveCategoryResult(hasMore: false, items: items);
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
  Future<LiveSearchAnchorResult> searchAnchors(String keyword, {int page = 1}) async {
    return LiveSearchAnchorResult(hasMore: false, items: []);
  }

  // =========================================================
  // 搜索频道
  // =========================================================

  @override
  Future<LiveSearchRoomResult> searchRooms(String keyword, {int page = 1}) async {
    if (keyword.trim().isEmpty) return LiveSearchRoomResult(hasMore: false, items: []);
    final matched = await db.searchChannelsByName(keyword);
    final items = matched.map((ch) {
      return LiveRoom(
        roomId: ch.id,
        title: ch.name,
        nick: ch.groupTitle ?? '',
        cover: ch.tvgLogo ?? '',
        area: ch.groupTitle ?? '',
        watching: '',
        avatar:
            'https://img95.699pic.com/xsj/0q/x6/7p.jpg%21/fw/700/watermark/url/L3hzai93YXRlcl9kZXRhaWwyLnBuZw/align/southeast',
        status: true,
        liveStatus: LiveStatus.live,
        platform: Sites.iptvSite,
        link: ch.streamUrl,
        data: ch.streamUrl,
      );
    }).toList();
    return LiveSearchRoomResult(hasMore: false, items: items);
  }
}
