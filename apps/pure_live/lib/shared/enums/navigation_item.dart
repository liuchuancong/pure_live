import 'package:desen_ui/desen_ui.dart';

import 'package:pure_live/l10n/translations.dart' show Translations;

/// The shell's navigation destinations. A module's menu is several blocks
/// with a divider between them (the live module reads the reference's rail
/// block for block: Search Live / Watch history, Link Parser / Multi-view, Favorites / Popular / Areas,
/// Recording centre), and settings is pinned to the sidebar's foot.
enum NavigationItem {
  /// The live branch.
  live(DsIcons.tv),

  /// The channels branch.
  channels(DsIcons.layoutGrid),

  /// The discover branch.
  discover(DsIcons.compass),

  /// The history branch.
  history(DsIcons.history),

  /// The multi-view branch.
  multiview(DsIcons.columns2),

  /// The favorites branch.
  favorites(DsIcons.heart),

  /// The hot branch.
  hot(DsIcons.flame),

  /// The zones branch.
  zones(DsIcons.squareStack),

  /// The search branch.
  search(DsIcons.search),

  /// The link-parser branch. The network probe and image-cache clear that
  /// used to share this entry are settings utilities now.
  toolbox(DsIcons.wrench),

  /// The log console branch: the running app's records, the level, the file
  /// and the export.
  logs(DsIcons.terminal),

  /// The recording branch.
  record(DsIcons.disc3),

  /// The settings branch.
  settings(DsIcons.settings),

  /// The appearance branch.
  appearance(DsIcons.palette),

  /// The network proxy branch.
  proxy(DsIcons.globe),

  /// The user branch.
  user(DsIcons.circleUser),

  /// The VOD module's own entry: the station's home (推荐/热门/动态).
  vod(DsIcons.film),

  /// The video station's cinema, the reference's 影视 rail entry.
  vodPgc(DsIcons.clapperboard),

  /// The video station's region browse, the reference's 分区 rail entry.
  vodRegions(DsIcons.layoutList),

  /// The video station's search, the reference's 搜索 rail entry.
  vodSearch(DsIcons.search),

  /// The video station's personal page, the reference's 个人 rail entry:
  /// 稍后再看, 历史, 收藏 and 追番 behind its tabs.
  vodPersonal(DsIcons.circleUser),

  /// The video station's live page, the reference's 直播 rail entry: the
  /// followed rooms, the site's areas and its recommended live feed.
  vodLive(DsIcons.tvMinimal),

  /// The IPTV module's playlists and guide sources.
  iptvSources(DsIcons.radioTower),

  /// The IPTV module's programme guide, the reference's 节目单 surface.
  iptvGuide(DsIcons.calendarClock),

  /// The IPTV module's favourite channels, the reference's 收藏.
  iptvFavorites(DsIcons.heart),

  /// The IPTV module's watch history, the reference's 最近观看.
  iptvRecent(DsIcons.history),

  /// The music module's own entry, the reference's 搜索 rail entry.
  music(DsIcons.search),

  /// The music module's song lists, the reference's 歌单.
  musicSonglist(DsIcons.listMusic),

  /// The music module's charts, the reference's 排行榜.
  musicToplist(DsIcons.chartColumn),

  /// The music module's own lists, the reference's 我的列表.
  musicLibrary(DsIcons.heart),

  /// The device's own music files, the reference's 本地音乐.
  musicLocal(DsIcons.folderOpen),

  /// The music module's download queue, the reference's 下载管理.
  musicDownloads(DsIcons.download),

  /// The hongguo station's home feed (首页).
  hongguoHome(DsIcons.home),

  /// The hongguo station's find-drama shelves (找剧).
  hongguoFind(DsIcons.clapperboard),

  /// The hongguo station's rank boards (排行榜).
  hongguoRank(DsIcons.trophy),

  /// The hongguo station's favorites (收藏).
  hongguoFavorites(DsIcons.heart),

  /// The hongguo station's watch history (观看历史).
  hongguoHistory(DsIcons.history),

  /// The hongguo station's account reservations (账户预约).
  hongguoReservations(DsIcons.calendarClock),

  /// The hongguo station's account (登录/账户管理).
  hongguoAccount(DsIcons.circleUser),

  /// The hongguo station's search.
  hongguoSearch(DsIcons.search);

  NavigationItem(this.icon);

  /// The destination's icon.
  final DsIconData icon;

  /// The localized label.
  String label(Translations t) => switch (this) {
    NavigationItem.live => t.navigation.live,
    NavigationItem.channels => t.iptv.live,
    NavigationItem.discover => t.navigation.discover,
    NavigationItem.history => t.navigation.history,
    NavigationItem.multiview => t.navigation.multiview,
    NavigationItem.favorites => t.navigation.favorites,
    NavigationItem.hot => t.navigation.hot,
    NavigationItem.zones => t.navigation.zones,
    NavigationItem.search => t.navigation.search,
    NavigationItem.toolbox => t.navigation.toolbox,
    NavigationItem.logs => t.toolbox.toolLogsTitle,
    NavigationItem.record => t.navigation.record,
    NavigationItem.settings => t.navigation.settings,
    NavigationItem.appearance => t.navigation.appearance,
    NavigationItem.proxy => t.navigation.proxy,
    NavigationItem.user => t.navigation.user,
    NavigationItem.vod => t.vod.home,
    NavigationItem.vodPgc => t.vod.pgcTitle,
    NavigationItem.vodRegions => t.vod.regions,
    NavigationItem.vodSearch => t.vod.search,
    NavigationItem.vodPersonal => t.vod.personal,
    NavigationItem.vodLive => t.vod.live,
    NavigationItem.iptvSources => t.navigation.iptvSources,
    NavigationItem.iptvGuide => t.navigation.iptvGuide,
    NavigationItem.iptvFavorites => t.iptv.favouritesTitle,
    NavigationItem.iptvRecent => t.iptv.recentTitle,
    NavigationItem.music => t.music.search,
    NavigationItem.musicSonglist => t.navigation.musicSonglist,
    NavigationItem.musicToplist => t.navigation.musicToplist,
    NavigationItem.musicLibrary => t.navigation.musicLibrary,
    NavigationItem.musicLocal => t.navigation.musicLocal,
    NavigationItem.musicDownloads => t.navigation.musicDownloads,
    NavigationItem.hongguoHome => t.hongguo.navHome,
    NavigationItem.hongguoFind => t.hongguo.navFind,
    NavigationItem.hongguoRank => t.hongguo.navRank,
    NavigationItem.hongguoFavorites => t.hongguo.navFavorites,
    NavigationItem.hongguoHistory => t.hongguo.navHistory,
    NavigationItem.hongguoReservations => t.hongguo.navReservations,
    NavigationItem.hongguoAccount => t.hongguo.navAccount,
    NavigationItem.hongguoSearch => t.hongguo.navSearch,
  };
}
