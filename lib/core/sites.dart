import 'site/yy/yy_site.dart';
import 'site/kick/kick_site.dart';
import 'site/bigo/bigo_site.dart';
import 'site/inke/inke_site.dart';
import 'site/soop/soop_site.dart';
import 'site/huya/huya_site.dart';
import 'interface/live_site.dart';
import 'site/chzzk/chzzk_site.dart';
import 'site/fc2live/fc2_site.dart';
import 'site/weibo/weibo_site.dart';
import 'site/acfun/acfun_site.dart';
import 'site/douyu/douyu_site.dart';
import 'site/liveme/liveme_site.dart';
import 'site/tiktok/tiktok_site.dart';
import 'site/douyin/douyin_site.dart';
import 'site/jdlive/jd_live_site.dart';
import 'site/youtube/youtube_site.dart';
import 'site/sixroom/sixroom_site.dart';
import 'site/picarto/picarto_site.dart';
import 'site/niconico/niconico_site.dart';
import 'site/showroom/showroom_site.dart';
import 'site/missevan/missevan_site.dart';
import 'site/kilakila/kilakila_site.dart';
import 'site/looklive/look_live_site.dart';
import 'site/pandalive/pandalive_site.dart';
import 'site/kugoulive/kugou_live_site.dart';
import 'site/baidulive/baidu_live_site.dart';

import 'package:pure_live/common/index.dart';

import 'site/xiaohongshu/xiaohongshu_site.dart';
import 'site/twitcasting/twitcasting_site.dart';
import 'site/seventeenlive/seventeenlive_site.dart';

import 'package:pure_live/core/site/cc/cc_site.dart';

import 'site/steambroadcast/steam_broadcast_site.dart';

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

  /// Root directory for all platform artwork.
  static const String _assetRoot = 'assets/images';

  /// Keep all platform logos in one place.
  ///
  /// Every supported platform must resolve to its own asset here; the generic
  /// `logo.png` is only the safety net in [logoForId] for future additions
  /// that have not received artwork yet.
  static const Map<String, String> _logos = {
    bilibiliSite: '$_assetRoot/bilibili_2.png',
    douyuSite: '$_assetRoot/douyu.png',
    huyaSite: '$_assetRoot/huya.png',
    douyinSite: '$_assetRoot/douyin.png',
    kuaishouSite: '$_assetRoot/kuaishou.png',
    ccSite: '$_assetRoot/cc.png',
    iptvSite: '$_assetRoot/iptv.png',
    twitchSite: '$_assetRoot/twitch.png',
    soopSite: '$_assetRoot/soop.png',
    yySite: '$_assetRoot/yy.png',
    acfunSite: '$_assetRoot/acfun.png',
    picartoSite: '$_assetRoot/picarto.png',
    twitcastingSite: '$_assetRoot/twitcasting.png',
    missevanSite: '$_assetRoot/missevan.png',
    inkeSite: '$_assetRoot/inke.png',
    kilakilaSite: '$_assetRoot/kilakila.png',
    xiaohongshuSite: '$_assetRoot/xiaohongshu.png',
    niconicoSite: '$_assetRoot/niconico.png',
    weiboSite: '$_assetRoot/weibo.png',
    showroomSite: '$_assetRoot/showroom.png',
    chzzkSite: '$_assetRoot/chzzk.png',
    kickSite: '$_assetRoot/kick.png',
    pandaLiveSite: '$_assetRoot/panda.png',
    fc2LiveSite: '$_assetRoot/fc2.png',
    steamBroadcastSite: '$_assetRoot/steam.png',
    jdLiveSite: '$_assetRoot/jd.png',
    kugouLiveSite: '$_assetRoot/kugou.png',
    baiduLiveSite: '$_assetRoot/baidu.png',
    lookLiveSite: '$_assetRoot/look.png',
    seventeenLiveSite: '$_assetRoot/17live.png',
    sixRoomSite: '$_assetRoot/sixroom.png',
    youtubeSite: '$_assetRoot/youtube.png',
    bigoSite: '$_assetRoot/bigo.png',
    liveMeSite: '$_assetRoot/liveme.png',
    tiktokSite: '$_assetRoot/tiktok.png',
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

  /// Web hosts of the retired platforms, so a shared link can be answered with
  /// "retired" instead of being ignored as unrecognised text.
  static const Set<String> _retiredHosts = {
    'huajiao.com',
    'openrec.tv',
    'flextv.co.kr',
    'ttinglive.com',
    'popkontv.com',
    'goodgame.ru',
    'vkvideo.ru',
    'vkplay.live',
    'dailymotion.com',
    'dai.ly',
    'rumble.com',
    'nimo.tv',
    'shopee.co.id',
    'taobao.com',
    'm.tb.cn',
  };

  static bool isRetiredLink(String text) {
    for (final match in RegExp(r'https?://[^\s]+', caseSensitive: false).allMatches(text)) {
      final host = Uri.tryParse(match.group(0)!)?.host.toLowerCase() ?? '';
      if (_retiredHosts.any((h) => host == h || host.endsWith('.$h'))) return true;
    }
    return false;
  }

  /// Read-only artwork lookup for frequently rebuilt room and multiview UI.
  /// A badge must not allocate a platform adapter just to obtain its asset.
  static String logoForId(String id) {
    final normalizedId = id.trim().toLowerCase();
    // Retired platforms keep a neutral badge so saved follows still render.
    if (retiredSiteIds.contains(normalizedId)) return '$_assetRoot/logo.png';
    if (!supportedSiteIds.contains(normalizedId)) throw StateError('Unsupported live site: $normalizedId');
    return _logos[normalizedId] ?? '$_assetRoot/logo.png';
  }

  /// Create a single platform adapter.
  ///
  /// Keeping construction in one switch prevents `supportSites`,
  /// `availableSites` and `of` from drifting apart when a new platform
  /// is added, and guarantees every site picks up its logo through
  /// [logoForId] instead of hard-coding asset paths in three places.
  static Site _createSite(String id) {
    final normalizedId = id.trim().toLowerCase();
    return switch (normalizedId) {
      weiboSite => Site(id: weiboSite, name: i18n('site_weibo'), logo: logoForId(weiboSite), liveSite: WeiboSite()),
      niconicoSite => Site(id: niconicoSite, name: 'niconico', logo: logoForId(niconicoSite), liveSite: NiconicoSite()),
      bilibiliSite => Site(
        id: bilibiliSite,
        name: i18n("site_bilibili"),
        logo: logoForId(bilibiliSite),
        liveSite: BiliBiliSite(),
      ),
      douyuSite => Site(id: douyuSite, name: i18n("site_douyu"), logo: logoForId(douyuSite), liveSite: DouyuSite()),
      huyaSite => Site(id: huyaSite, name: i18n("site_huya"), logo: logoForId(huyaSite), liveSite: HuyaSite()),
      douyinSite => Site(
        id: douyinSite,
        name: i18n("site_douyin"),
        logo: logoForId(douyinSite),
        liveSite: DouyinSite(),
      ),
      kuaishouSite => Site(
        id: kuaishouSite,
        name: i18n("site_kuaishou"),
        logo: logoForId(kuaishouSite),
        liveSite: KuaishowSite(),
      ),
      ccSite => Site(id: ccSite, name: i18n("site_cc"), logo: logoForId(ccSite), liveSite: CCSite()),
      twitchSite => Site(
        id: twitchSite,
        name: i18n("site_twitch"),
        logo: logoForId(twitchSite),
        liveSite: TwitchSite(),
      ),
      soopSite => Site(id: soopSite, name: i18n("site_soop"), logo: logoForId(soopSite), liveSite: SoopSite()),
      yySite => Site(id: yySite, name: i18n("site_yy"), logo: logoForId(yySite), liveSite: YYSite()),
      acfunSite => Site(id: acfunSite, name: i18n('site_acfun'), logo: logoForId(acfunSite), liveSite: AcfunSite()),
      picartoSite => Site(id: picartoSite, name: 'Picarto', logo: logoForId(picartoSite), liveSite: PicartoSite()),
      twitcastingSite => Site(
        id: twitcastingSite,
        name: 'TwitCasting',
        logo: logoForId(twitcastingSite),
        liveSite: TwitcastingSite(),
      ),
      missevanSite => Site(
        id: missevanSite,
        name: i18n('site_missevan'),
        logo: logoForId(missevanSite),
        liveSite: MissevanSite(),
      ),
      iptvSite => Site(id: iptvSite, name: i18n("site_iptv"), logo: logoForId(iptvSite), liveSite: IptvSite()),
      inkeSite => Site(id: inkeSite, name: i18n('site_inke'), logo: logoForId(inkeSite), liveSite: InkeSite()),
      kilakilaSite => Site(
        id: kilakilaSite,
        name: i18n('site_kilakila'),
        logo: logoForId(kilakilaSite),
        liveSite: KilakilaSite(),
      ),
      xiaohongshuSite => Site(
        id: xiaohongshuSite,
        name: i18n('site_xiaohongshu'),
        logo: logoForId(xiaohongshuSite),
        liveSite: XiaohongshuSite(),
      ),
      showroomSite => Site(
        id: showroomSite,
        name: i18n('site_showroom'),
        logo: logoForId(showroomSite),
        liveSite: ShowroomSite(),
      ),
      chzzkSite => Site(id: chzzkSite, name: i18n('site_chzzk'), logo: logoForId(chzzkSite), liveSite: ChzzkSite()),
      kickSite => Site(id: kickSite, name: i18n('site_kick'), logo: logoForId(kickSite), liveSite: KickSite()),
      liveMeSite => Site(
        id: liveMeSite,
        name: i18n('site_liveme'),
        logo: logoForId(liveMeSite),
        liveSite: LiveMeSite(),
      ),
      tiktokSite => Site(
        id: tiktokSite,
        name: i18n('site_tiktok'),
        logo: logoForId(tiktokSite),
        liveSite: TikTokSite(),
      ),
      youtubeSite => Site(
        id: youtubeSite,
        name: i18n('site_youtube'),
        logo: logoForId(youtubeSite),
        liveSite: YouTubeSite(),
      ),
      bigoSite => Site(id: bigoSite, name: i18n('site_bigo'), logo: logoForId(bigoSite), liveSite: BigoSite()),
      pandaLiveSite => Site(
        id: pandaLiveSite,
        name: i18n('site_pandalive'),
        logo: logoForId(pandaLiveSite),
        liveSite: PandaLiveSite(),
      ),
      fc2LiveSite => Site(
        id: fc2LiveSite,
        name: i18n('site_fc2live'),
        logo: logoForId(fc2LiveSite),
        liveSite: Fc2Site(),
      ),
      steamBroadcastSite => Site(
        id: steamBroadcastSite,
        name: i18n('site_steambroadcast'),
        logo: logoForId(steamBroadcastSite),
        liveSite: SteamBroadcastSite(),
      ),
      jdLiveSite => Site(
        id: jdLiveSite,
        name: i18n('site_jdlive'),
        logo: logoForId(jdLiveSite),
        liveSite: JdLiveSite(),
      ),
      kugouLiveSite => Site(
        id: kugouLiveSite,
        name: i18n('site_kugoulive'),
        logo: logoForId(kugouLiveSite),
        liveSite: KugouLiveSite(),
      ),
      baiduLiveSite => Site(
        id: baiduLiveSite,
        name: i18n('site_baidulive'),
        logo: logoForId(baiduLiveSite),
        liveSite: BaiduLiveSite(),
      ),
      sixRoomSite => Site(
        id: sixRoomSite,
        name: i18n('site_sixroom'),
        logo: logoForId(sixRoomSite),
        liveSite: SixRoomSite(),
      ),
      lookLiveSite => Site(
        id: lookLiveSite,
        name: i18n('site_looklive'),
        logo: logoForId(lookLiveSite),
        liveSite: LookLiveSite(),
      ),
      seventeenLiveSite => Site(
        id: seventeenLiveSite,
        name: i18n('site_17live'),
        logo: logoForId(seventeenLiveSite),
        liveSite: SeventeenLiveSite(),
      ),
      _ => throw StateError('Unsupported live site: $normalizedId'),
    };
  }

  /// Build the complete supported-site list.
  ///
  /// The list is cached because platform adapters can contain session,
  /// authentication or request-related state. Recreating them every time
  /// `supportSites` is accessed would unnecessarily discard that state.
  static final List<Site> _supportedSites = List<Site>.unmodifiable([
    for (final id in [
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
      niconicoSite,
      weiboSite,
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
    ])
      _createSite(id),
  ]);

  static List<Site> get supportSites => _supportedSites;

  static Site of(String id) {
    final normalizedId = id.trim().toLowerCase();
    // Do not construct every platform adapter for a single lookup. Favourite
    // verification performs this operation for every saved room; the previous
    // list scan allocated nine adapters per card and also discarded platform
    // session caches immediately afterwards. Reusing the cached adapter keeps
    // both allocations and platform session state intact.
    for (final site in _supportedSites) {
      if (site.id == normalizedId) return site;
    }
    return _createSite(normalizedId);
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
      result.insert(0, Site(id: allSite, name: i18n("site_all"), logo: "$_assetRoot/all.png", liveSite: LiveSite()));
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
