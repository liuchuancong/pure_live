import 'site/yy/yy_site.dart';
import 'interface/live_site.dart';
import 'site/huya/huya_site.dart';
import 'site/inke/inke_site.dart';
import 'site/soop/soop_site.dart';
import 'site/acfun/acfun_site.dart';
import 'site/douyu/douyu_site.dart';
import 'site/tting/tting_site.dart';
import 'site/weibo/weibo_site.dart';
import 'site/douyin/douyin_site.dart';
import 'site/huajiao/huajiao_site.dart';
import 'site/openrec/openrec_site.dart';
import 'site/picarto/picarto_site.dart';
import 'site/kilakila/kilakila_site.dart';
import 'site/missevan/missevan_site.dart';
import 'site/niconico/niconico_site.dart';
import 'package:pure_live/common/index.dart';
import 'site/twitcasting/twitcasting_site.dart';
import 'site/xiaohongshu/xiaohongshu_site.dart';
import 'package:pure_live/core/site/cc/cc_site.dart';
import 'package:pure_live/core/site/iptv/iptv_site.dart';
import 'package:pure_live/core/site/twitch/twitch_site.dart';
import 'package:pure_live/core/site/kuaishou/kuaishou_site.dart';
import 'package:pure_live/core/site/bilibili/bilibili_site.dart';




class Sites {
  static const String weiboSite = 'weibo';
  static const String niconicoSite = 'niconico';
  static const String allSite = 'all';
  static const String bilibiliSite = 'bilibili';
  static const String douyuSite = 'douyu';
  static const String huyaSite = 'huya';
  static const String douyinSite = 'douyin';
  static const String kuaishouSite = 'kuaishou';
  static const String ccSite = 'cc';
  static const String iptvSite = 'iptv';
  static const String twitchSite = 'twitch';
  static const String soopSite = 'soop';
  static const String yySite = 'yy';
  static const String acfunSite = 'acfun';
  static const String picartoSite = 'picarto';
  static const String twitcastingSite = 'twitcasting';
  static const String missevanSite = 'missevan';
  static const String inkeSite = 'inke';
  static const String kilakilaSite = 'kilakila';
  static const String huajiaoSite = 'huajiao';
  static const String openrecSite = 'openrec';
  static const String ttingSite = 'ttinglive';
  static const String xiaohongshuSite = 'xiaohongshu';

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
    huajiaoSite,
    openrecSite,
    ttingSite,
    xiaohongshuSite,
    iptvSite,
  };

  static const String _assetRoot = 'assets/images';

  /// Keep all platform logos in one place.
  ///
  /// The platform-specific files are preferred over the old generic
  /// `logo.png` placeholder so every site has its own visual identity.
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
    huajiaoSite: '$_assetRoot/huajiao.png',
    openrecSite: '$_assetRoot/openrec.png',
    ttingSite: '$_assetRoot/ttinglive.gif',
    xiaohongshuSite: '$_assetRoot/xiaohongshu.png',
    niconicoSite: '$_assetRoot/niconico.png',
    weiboSite: '$_assetRoot/weibo.png',
  };

  /// Resolve a logo path from the central logo registry.
  ///
  /// Unknown platforms keep the generic application logo instead of
  /// accidentally returning an unrelated platform icon.
  static String logoOf(String id) {
    final normalizedId = id.trim().toLowerCase();

    return _logos[normalizedId] ?? '$_assetRoot/logo.png';
  }

  static bool isSupported(String id) {
    return supportedSiteIds.contains(id.trim().toLowerCase());
  }

  /// Create a single platform adapter.
  ///
  /// Keeping construction in one switch prevents `supportSites`,
  /// `availableSites` and `of` from drifting apart when a new platform
  /// is added.
  static Site _createSite(String id) {
    final normalizedId = id.trim().toLowerCase();

    return switch (normalizedId) {
      weiboSite => Site(id: weiboSite, name: i18n('site_weibo'), logo: logoOf(weiboSite), liveSite: WeiboSite()),
      niconicoSite => Site(id: niconicoSite, name: 'niconico', logo: logoOf(niconicoSite), liveSite: NiconicoSite()),
      bilibiliSite => Site(
        id: bilibiliSite,
        name: i18n('site_bilibili'),
        logo: logoOf(bilibiliSite),
        liveSite: BiliBiliSite(),
      ),
      douyuSite => Site(id: douyuSite, name: i18n('site_douyu'), logo: logoOf(douyuSite), liveSite: DouyuSite()),
      huyaSite => Site(id: huyaSite, name: i18n('site_huya'), logo: logoOf(huyaSite), liveSite: HuyaSite()),
      douyinSite => Site(id: douyinSite, name: i18n('site_douyin'), logo: logoOf(douyinSite), liveSite: DouyinSite()),
      kuaishouSite => Site(
        id: kuaishouSite,
        name: i18n('site_kuaishou'),
        logo: logoOf(kuaishouSite),
        liveSite: KuaishowSite(),
      ),
      ccSite => Site(id: ccSite, name: i18n('site_cc'), logo: logoOf(ccSite), liveSite: CCSite()),
      twitchSite => Site(id: twitchSite, name: i18n('site_twitch'), logo: logoOf(twitchSite), liveSite: TwitchSite()),
      soopSite => Site(id: soopSite, name: i18n('site_soop'), logo: logoOf(soopSite), liveSite: SoopSite()),
      yySite => Site(id: yySite, name: i18n('site_yy'), logo: logoOf(yySite), liveSite: YYSite()),
      acfunSite => Site(id: acfunSite, name: i18n('site_acfun'), logo: logoOf(acfunSite), liveSite: AcfunSite()),
      picartoSite => Site(id: picartoSite, name: 'Picarto', logo: logoOf(picartoSite), liveSite: PicartoSite()),
      twitcastingSite => Site(
        id: twitcastingSite,
        name: 'TwitCasting',
        logo: logoOf(twitcastingSite),
        liveSite: TwitcastingSite(),
      ),
      missevanSite => Site(
        id: missevanSite,
        name: i18n('site_missevan'),
        logo: logoOf(missevanSite),
        liveSite: MissevanSite(),
      ),
      inkeSite => Site(id: inkeSite, name: i18n('site_inke'), logo: logoOf(inkeSite), liveSite: InkeSite()),
      kilakilaSite => Site(
        id: kilakilaSite,
        name: i18n('site_kilakila'),
        logo: logoOf(kilakilaSite),
        liveSite: KilakilaSite(),
      ),
      huajiaoSite => Site(
        id: huajiaoSite,
        name: i18n('site_huajiao'),
        logo: logoOf(huajiaoSite),
        liveSite: HuajiaoSite(),
      ),
      openrecSite => Site(
        id: openrecSite,
        name: 'mellow-fan (OPENREC)',
        logo: logoOf(openrecSite),
        liveSite: OpenrecSite(),
      ),
      ttingSite => Site(id: ttingSite, name: 'FLEX TV (TTingLive)', logo: logoOf(ttingSite), liveSite: TtingSite()),
      xiaohongshuSite => Site(
        id: xiaohongshuSite,
        name: i18n('site_xiaohongshu'),
        logo: logoOf(xiaohongshuSite),
        liveSite: XiaohongshuSite(),
      ),
      iptvSite => Site(id: iptvSite, name: i18n('site_iptv'), logo: logoOf(iptvSite), liveSite: IptvSite()),
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
      huajiaoSite,
      openrecSite,
      ttingSite,
      xiaohongshuSite,
      niconicoSite,
      weiboSite,
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
    // session caches immediately afterwards.
    return _createSite(normalizedId);
  }

  List<Site> availableSites({bool containsAll = false}) {
    final List<String> savedIds = SettingsService.to.fav.hotAreasList.v;

    final supportedById = <String, Site>{for (final site in supportSites) site.id: site};

    final List<Site> result = [];
    final seen = <String>{};

    for (final rawId in savedIds) {
      final id = rawId.trim().toLowerCase();

      if (!seen.add(id)) {
        continue;
      }

      final match = supportedById[id];

      if (match != null) {
        result.add(match);
      }
    }

    if (containsAll) {
      result.insert(0, Site(id: allSite, name: i18n('site_all'), logo: '$_assetRoot/all.png', liveSite: LiveSite()));
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

    if (normalizedId != Sites.allSite && !Sites.isSupported(normalizedId)) {
      return _fallbackName;
    }

    return i18nOr('site_$normalizedId', _fallbackName);
  }
}
