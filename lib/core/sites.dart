import 'site/niconico/niconico_site.dart';
import 'site/chzzk/chzzk_site.dart';
import 'site/kick/kick_site.dart';
import 'site/liveme/liveme_site.dart';
import 'site/tiktok/tiktok_site.dart';
import 'site/youtube/youtube_site.dart';
import 'site/bigo/bigo_site.dart';
import 'site/pandalive/pandalive_site.dart';
import 'site/fc2live/fc2_site.dart';
import 'site/steambroadcast/steam_broadcast_site.dart';
import 'site/jdlive/jd_live_site.dart';
import 'site/kugoulive/kugou_live_site.dart';
import 'site/baidulive/baidu_live_site.dart';
import 'site/sixroom/sixroom_site.dart';
import 'site/looklive/look_live_site.dart';
import 'site/seventeenlive/seventeenlive_site.dart';
import 'site/showroom/showroom_site.dart';
import 'site/weibo/weibo_site.dart';
import 'site/xiaohongshu/xiaohongshu_site.dart';
import 'site/picarto/picarto_site.dart';
import 'site/missevan/missevan_site.dart';
import 'site/inke/inke_site.dart';
import 'site/kilakila/kilakila_site.dart';
import 'site/twitcasting/twitcasting_site.dart';
import 'site/yy/yy_site.dart';
import 'site/acfun/acfun_site.dart';
import 'site/soop/soop_site.dart';
import 'site/huya/huya_site.dart';
import 'interface/live_site.dart';
import 'site/douyu/douyu_site.dart';
import 'site/douyin/douyin_site.dart';

import 'package:pure_live/common/index.dart';
import 'package:pure_live/core/site/cc/cc_site.dart';
import 'package:pure_live/core/site/iptv/iptv_site.dart';
import 'package:pure_live/core/site/twitch/twitch_site.dart';
import 'package:pure_live/core/site/kuaishou/kuaishou_site.dart';
import 'package:pure_live/core/site/bilibili/bilibili_site.dart';

class Sites {
  static const String weiboSite = 'weibo';
  static const String niconicoSite = 'niconico';
  static const String allSite = "all";
  static const String bilibiliSite = "bilibili";
  static const String douyuSite = "douyu";
  static const String huyaSite = "huya";
  static const String douyinSite = "douyin";
  static const String kuaishouSite = "kuaishou";
  static const String ccSite = "cc";
  static const String iptvSite = "iptv";
  static const String twitchSite = "twitch";
  static const String soopSite = 'soop';
  static const String yySite = 'yy';
  static const String acfunSite = 'acfun';
  static const String picartoSite = 'picarto';
  static const String twitcastingSite = 'twitcasting';
  static const String missevanSite = 'missevan';
  static const String inkeSite = 'inke';
  static const String kilakilaSite = 'kilakila';
  static const String xiaohongshuSite = 'xiaohongshu';
  static const String showroomSite = 'showroom';
  static const String chzzkSite = 'chzzk';
  static const String kickSite = 'kick';
  static const String liveMeSite = 'liveme';
  static const String tiktokSite = 'tiktok';
  static const String youtubeSite = 'youtube';
  static const String bigoSite = 'bigo';
  static const String pandaLiveSite = 'pandalive';
  static const String fc2LiveSite = 'fc2live';
  static const String steamBroadcastSite = 'steambroadcast';
  static const String jdLiveSite = 'jdlive';
  static const String kugouLiveSite = 'kugoulive';
  static const String baiduLiveSite = 'baidulive';
  static const String sixRoomSite = 'sixroom';
  static const String lookLiveSite = 'looklive';
  static const String seventeenLiveSite = '17live';

  static const Set<String> supportedSiteIds = {
    weiboSite,
    niconicoSite,
    bilibiliSite,
    douyuSite,
    huyaSite,
    douyinSite,
    kuaishouSite,
    ccSite,
    twitchSite,
    soopSite,
    yySite,
    acfunSite,
    picartoSite,
    twitcastingSite,
    missevanSite,
    inkeSite,
    kilakilaSite,
    xiaohongshuSite,
    showroomSite,
    chzzkSite,
    kickSite,
    liveMeSite,
    tiktokSite,
    youtubeSite,
    bigoSite,
    pandaLiveSite,
    fc2LiveSite,
    steamBroadcastSite,
    jdLiveSite,
    kugouLiveSite,
    baiduLiveSite,
    sixRoomSite,
    lookLiveSite,
    seventeenLiveSite,
    iptvSite,
  };

  static bool isSupported(String id) => supportedSiteIds.contains(id.trim().toLowerCase());

  /// Platforms removed in 3.2.8 (hard to maintain, niche or no longer usable).
  /// Saved follows, history and links for them stay readable and are shown as
  /// retired instead of failing as unknown.
  static const Set<String> retiredSiteIds = {
    'huajiao',
    'openrec',
    'ttinglive',
    'popkontv',
    'shopeelive',
    'vkvideolive',
    'nimotv',
    'dailymotion',
    'rumble',
    'goodgame',
    'taobaolive',
  };

  static bool isRetired(String id) => retiredSiteIds.contains(id.trim().toLowerCase());

  /// Read-only artwork lookup for frequently rebuilt room and multiview UI.
  /// A badge must not allocate a platform adapter just to obtain its asset.
  static String logoForId(String id) {
    final normalizedId = id.trim().toLowerCase();
    // Retired platforms keep a neutral badge so saved follows still render.
    if (retiredSiteIds.contains(normalizedId)) return 'assets/images/logo.png';
    if (!supportedSiteIds.contains(normalizedId)) throw StateError('Unsupported live site: $normalizedId');
    return switch (normalizedId) {
      bilibiliSite => 'assets/images/bilibili_2.png',
      douyuSite => 'assets/images/douyu.png',
      huyaSite => 'assets/images/huya.png',
      douyinSite => 'assets/images/douyin.png',
      kuaishouSite => 'assets/images/kuaishou.png',
      ccSite => 'assets/images/cc.png',
      twitchSite => 'assets/images/twitch.png',
      soopSite => 'assets/images/soop.png',
      yySite => 'assets/images/yy.png',
      _ => 'assets/images/logo.png',
    };
  }

  static List<Site> get supportSites => [
    Site(id: bilibiliSite, name: i18n("site_bilibili"), logo: "assets/images/bilibili_2.png", liveSite: BiliBiliSite()),
    Site(id: douyuSite, name: i18n("site_douyu"), logo: "assets/images/douyu.png", liveSite: DouyuSite()),
    Site(id: huyaSite, name: i18n("site_huya"), logo: "assets/images/huya.png", liveSite: HuyaSite()),
    Site(id: douyinSite, name: i18n("site_douyin"), logo: "assets/images/douyin.png", liveSite: DouyinSite()),
    Site(id: kuaishouSite, name: i18n("site_kuaishou"), logo: "assets/images/kuaishou.png", liveSite: KuaishowSite()),
    Site(id: ccSite, name: i18n("site_cc"), logo: "assets/images/cc.png", liveSite: CCSite()),
    Site(id: twitchSite, name: i18n("site_twitch"), logo: "assets/images/twitch.png", liveSite: TwitchSite()),
    Site(id: soopSite, name: i18n("site_soop"), logo: "assets/images/soop.png", liveSite: SoopSite()),
    Site(id: yySite, name: i18n("site_yy"), logo: "assets/images/yy.png", liveSite: YYSite()),
    Site(id: acfunSite, name: i18n('site_acfun'), logo: 'assets/images/logo.png', liveSite: AcfunSite()),
    Site(id: picartoSite, name: 'Picarto', logo: 'assets/images/logo.png', liveSite: PicartoSite()),
    Site(id: twitcastingSite, name: 'TwitCasting', logo: 'assets/images/logo.png', liveSite: TwitcastingSite()),
    Site(id: missevanSite, name: i18n('site_missevan'), logo: 'assets/images/logo.png', liveSite: MissevanSite()),
    Site(id: inkeSite, name: i18n('site_inke'), logo: 'assets/images/logo.png', liveSite: InkeSite()),
    Site(id: kilakilaSite, name: i18n('site_kilakila'), logo: 'assets/images/logo.png', liveSite: KilakilaSite()),
    Site(
      id: xiaohongshuSite,
      name: i18n('site_xiaohongshu'),
      logo: 'assets/images/logo.png',
      liveSite: XiaohongshuSite(),
    ),
    Site(id: niconicoSite, name: 'niconico', logo: 'assets/images/logo.png', liveSite: NiconicoSite()),
    Site(id: weiboSite, name: i18n('site_weibo'), logo: 'assets/images/logo.png', liveSite: WeiboSite()),
    Site(id: showroomSite, name: i18n('site_showroom'), logo: 'assets/images/logo.png', liveSite: ShowroomSite()),
    Site(id: chzzkSite, name: i18n('site_chzzk'), logo: 'assets/images/logo.png', liveSite: ChzzkSite()),
    Site(id: kickSite, name: i18n('site_kick'), logo: 'assets/images/logo.png', liveSite: KickSite()),
    Site(id: liveMeSite, name: i18n('site_liveme'), logo: 'assets/images/logo.png', liveSite: LiveMeSite()),
    Site(id: tiktokSite, name: i18n('site_tiktok'), logo: 'assets/images/logo.png', liveSite: TikTokSite()),
    Site(id: youtubeSite, name: i18n('site_youtube'), logo: 'assets/images/logo.png', liveSite: YouTubeSite()),
    Site(id: bigoSite, name: i18n('site_bigo'), logo: 'assets/images/logo.png', liveSite: BigoSite()),
    Site(id: pandaLiveSite, name: i18n('site_pandalive'), logo: 'assets/images/logo.png', liveSite: PandaLiveSite()),
    Site(id: fc2LiveSite, name: i18n('site_fc2live'), logo: 'assets/images/logo.png', liveSite: Fc2Site()),
    Site(
      id: steamBroadcastSite,
      name: i18n('site_steambroadcast'),
      logo: 'assets/images/logo.png',
      liveSite: SteamBroadcastSite(),
    ),
    Site(id: jdLiveSite, name: i18n('site_jdlive'), logo: 'assets/images/logo.png', liveSite: JdLiveSite()),
    Site(id: kugouLiveSite, name: i18n('site_kugoulive'), logo: 'assets/images/logo.png', liveSite: KugouLiveSite()),
    Site(id: baiduLiveSite, name: i18n('site_baidulive'), logo: 'assets/images/logo.png', liveSite: BaiduLiveSite()),
    Site(id: sixRoomSite, name: i18n('site_sixroom'), logo: 'assets/images/logo.png', liveSite: SixRoomSite()),
    Site(id: lookLiveSite, name: i18n('site_looklive'), logo: 'assets/images/logo.png', liveSite: LookLiveSite()),
    Site(
      id: seventeenLiveSite,
      name: i18n('site_17live'),
      logo: 'assets/images/logo.png',
      liveSite: SeventeenLiveSite(),
    ),
    Site(id: iptvSite, name: i18n("site_iptv"), logo: "assets/images/logo.png", liveSite: IptvSite()),
  ];

  static Site of(String id) {
    final normalizedId = id.trim().toLowerCase();
    // Do not construct every platform adapter for a single lookup. Favourite
    // verification performs this operation for every saved room; the previous
    // list scan allocated nine adapters per card and also discarded platform
    // session caches immediately afterwards.
    return switch (normalizedId) {
      weiboSite => Site(id: weiboSite, name: i18n('site_weibo'), logo: 'assets/images/logo.png', liveSite: WeiboSite()),
      niconicoSite => Site(
        id: niconicoSite,
        name: 'niconico',
        logo: 'assets/images/logo.png',
        liveSite: NiconicoSite(),
      ),
      bilibiliSite => Site(
        id: bilibiliSite,
        name: i18n("site_bilibili"),
        logo: "assets/images/bilibili_2.png",
        liveSite: BiliBiliSite(),
      ),
      douyuSite => Site(
        id: douyuSite,
        name: i18n("site_douyu"),
        logo: "assets/images/douyu.png",
        liveSite: DouyuSite(),
      ),
      huyaSite => Site(id: huyaSite, name: i18n("site_huya"), logo: "assets/images/huya.png", liveSite: HuyaSite()),
      douyinSite => Site(
        id: douyinSite,
        name: i18n("site_douyin"),
        logo: "assets/images/douyin.png",
        liveSite: DouyinSite(),
      ),
      kuaishouSite => Site(
        id: kuaishouSite,
        name: i18n("site_kuaishou"),
        logo: "assets/images/kuaishou.png",
        liveSite: KuaishowSite(),
      ),
      ccSite => Site(id: ccSite, name: i18n("site_cc"), logo: "assets/images/cc.png", liveSite: CCSite()),
      twitchSite => Site(
        id: twitchSite,
        name: i18n("site_twitch"),
        logo: "assets/images/twitch.png",
        liveSite: TwitchSite(),
      ),
      soopSite => Site(id: soopSite, name: i18n("site_soop"), logo: "assets/images/soop.png", liveSite: SoopSite()),
      yySite => Site(id: yySite, name: i18n("site_yy"), logo: "assets/images/yy.png", liveSite: YYSite()),
      acfunSite => Site(id: acfunSite, name: i18n('site_acfun'), logo: 'assets/images/logo.png', liveSite: AcfunSite()),
      picartoSite => Site(id: picartoSite, name: 'Picarto', logo: 'assets/images/logo.png', liveSite: PicartoSite()),
      twitcastingSite => Site(
        id: twitcastingSite,
        name: 'TwitCasting',
        logo: 'assets/images/logo.png',
        liveSite: TwitcastingSite(),
      ),
      missevanSite => Site(
        id: missevanSite,
        name: i18n('site_missevan'),
        logo: 'assets/images/logo.png',
        liveSite: MissevanSite(),
      ),
      iptvSite => Site(id: iptvSite, name: i18n("site_iptv"), logo: "assets/images/logo.png", liveSite: IptvSite()),
      inkeSite => Site(id: inkeSite, name: i18n('site_inke'), logo: 'assets/images/logo.png', liveSite: InkeSite()),
      kilakilaSite => Site(
        id: kilakilaSite,
        name: i18n('site_kilakila'),
        logo: 'assets/images/logo.png',
        liveSite: KilakilaSite(),
      ),
      xiaohongshuSite => Site(
        id: xiaohongshuSite,
        name: i18n('site_xiaohongshu'),
        logo: 'assets/images/logo.png',
        liveSite: XiaohongshuSite(),
      ),
      showroomSite => Site(
        id: showroomSite,
        name: i18n('site_showroom'),
        logo: 'assets/images/logo.png',
        liveSite: ShowroomSite(),
      ),
      chzzkSite => Site(id: chzzkSite, name: i18n('site_chzzk'), logo: 'assets/images/logo.png', liveSite: ChzzkSite()),
      kickSite => Site(id: kickSite, name: i18n('site_kick'), logo: 'assets/images/logo.png', liveSite: KickSite()),
      liveMeSite => Site(
        id: liveMeSite,
        name: i18n('site_liveme'),
        logo: 'assets/images/logo.png',
        liveSite: LiveMeSite(),
      ),
      tiktokSite => Site(
        id: tiktokSite,
        name: i18n('site_tiktok'),
        logo: 'assets/images/logo.png',
        liveSite: TikTokSite(),
      ),
      youtubeSite => Site(
        id: youtubeSite,
        name: i18n('site_youtube'),
        logo: 'assets/images/logo.png',
        liveSite: YouTubeSite(),
      ),
      bigoSite => Site(id: bigoSite, name: i18n('site_bigo'), logo: 'assets/images/logo.png', liveSite: BigoSite()),
      pandaLiveSite => Site(
        id: pandaLiveSite,
        name: i18n('site_pandalive'),
        logo: 'assets/images/logo.png',
        liveSite: PandaLiveSite(),
      ),
      fc2LiveSite => Site(
        id: fc2LiveSite,
        name: i18n('site_fc2live'),
        logo: 'assets/images/logo.png',
        liveSite: Fc2Site(),
      ),
      steamBroadcastSite => Site(
        id: steamBroadcastSite,
        name: i18n('site_steambroadcast'),
        logo: 'assets/images/logo.png',
        liveSite: SteamBroadcastSite(),
      ),
      jdLiveSite => Site(
        id: jdLiveSite,
        name: i18n('site_jdlive'),
        logo: 'assets/images/logo.png',
        liveSite: JdLiveSite(),
      ),
      kugouLiveSite => Site(
        id: kugouLiveSite,
        name: i18n('site_kugoulive'),
        logo: 'assets/images/logo.png',
        liveSite: KugouLiveSite(),
      ),
      baiduLiveSite => Site(
        id: baiduLiveSite,
        name: i18n('site_baidulive'),
        logo: 'assets/images/logo.png',
        liveSite: BaiduLiveSite(),
      ),
      sixRoomSite => Site(
        id: sixRoomSite,
        name: i18n('site_sixroom'),
        logo: 'assets/images/logo.png',
        liveSite: SixRoomSite(),
      ),
      lookLiveSite => Site(
        id: lookLiveSite,
        name: i18n('site_looklive'),
        logo: 'assets/images/logo.png',
        liveSite: LookLiveSite(),
      ),
      seventeenLiveSite => Site(
        id: seventeenLiveSite,
        name: i18n('site_17live'),
        logo: 'assets/images/logo.png',
        liveSite: SeventeenLiveSite(),
      ),
      _ => throw StateError('Unsupported live site: $normalizedId'),
    };
  }

  List<Site> availableSites({bool containsAll = false}) {
    final List<String> savedIds = SettingsService.to.fav.hotAreasList.v;
    final supportedById = {for (final site in supportSites) site.id: site};
    final List<Site> result = [];
    final seen = <String>{};
    for (String rawId in savedIds) {
      final id = rawId.trim().toLowerCase();
      if (!seen.add(id)) continue;
      final match = supportedById[id];
      if (match != null) {
        result.add(match);
      }
    }
    if (containsAll) {
      result.insert(0, Site(id: allSite, name: i18n("site_all"), logo: "assets/images/all.png", liveSite: LiveSite()));
    }
    return result;
  }
}

class Site {
  final String id;
  final String _fallbackName;
  final String logo;
  final LiveSite liveSite;

  Site({required this.id, required this.liveSite, required this.logo, required String name}) : _fallbackName = name;

  /// Resolve registry labels when they are painted instead of freezing the
  /// locale that happened to be active when an adapter was constructed.
  /// Popular and search controllers deliberately retain their [Site]
  /// instances so pagination/session state stays stable; the label must still
  /// follow an in-app language change without rebuilding those adapters.
  String get name {
    final normalizedId = id.trim().toLowerCase();
    if (normalizedId != Sites.allSite && !Sites.isSupported(normalizedId)) return _fallbackName;
    return i18nOr('site_$normalizedId', _fallbackName);
  }
}
