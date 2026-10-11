import 'package:live_net/live_net.dart';

import 'package:live_sites/src/contracts/live_site.dart';
import 'package:live_sites/src/platforms/acfun/acfun_site.dart';
import 'package:live_sites/src/platforms/baidulive/baidulive_site.dart';
import 'package:live_sites/src/platforms/bigo/bigo_site.dart';
import 'package:live_sites/src/platforms/bilibili/bilibili_site.dart';
import 'package:live_sites/src/platforms/cc/cc_site.dart';
import 'package:live_sites/src/platforms/chzzk/chzzk_site.dart';
import 'package:live_sites/src/platforms/douyin/douyin_site.dart';
import 'package:live_sites/src/platforms/douyu/douyu_site.dart';
import 'package:live_sites/src/platforms/fc2live/fc2live_site.dart';
import 'package:live_sites/src/platforms/huya/huya_site.dart';
import 'package:live_sites/src/platforms/inke/inke_site.dart';
import 'package:live_sites/src/platforms/iptv/iptv_site.dart';
import 'package:live_sites/src/platforms/jdlive/jdlive_site.dart';
import 'package:live_sites/src/platforms/kick/kick_site.dart';
import 'package:live_sites/src/platforms/kilakila/kilakila_site.dart';
import 'package:live_sites/src/platforms/kuaishou/kuaishou_site.dart';
import 'package:live_sites/src/platforms/kugoulive/kugoulive_site.dart';
import 'package:live_sites/src/platforms/liveme/liveme_site.dart';
import 'package:live_sites/src/platforms/looklive/looklive_site.dart';
import 'package:live_sites/src/platforms/missevan/missevan_site.dart';
import 'package:live_sites/src/platforms/niconico/niconico_site.dart';
import 'package:live_sites/src/platforms/pandalive/pandalive_site.dart';
import 'package:live_sites/src/platforms/picarto/picarto_site.dart';
import 'package:live_sites/src/platforms/showroom/showroom_site.dart';
import 'package:live_sites/src/platforms/sixroom/sixroom_site.dart';
import 'package:live_sites/src/platforms/soop/soop_site.dart';
import 'package:live_sites/src/platforms/steambroadcast/steambroadcast_site.dart';
import 'package:live_sites/src/platforms/tiktok/tiktok_site.dart';
import 'package:live_sites/src/platforms/twitcasting/twitcasting_site.dart';
import 'package:live_sites/src/platforms/twitch/twitch_site.dart';
import 'package:live_sites/src/platforms/weibo/weibo_site.dart';
import 'package:live_sites/src/platforms/xiaohongshu/xiaohongshu_site.dart';
import 'package:live_sites/src/platforms/youtube/youtube_site.dart';
import 'package:live_sites/src/platforms/yy/yy_site.dart';
import 'package:live_sites/src/registry/site_ids.dart';

/// Every adapter this package ships, as factories keyed by site id.
///
/// The list lives here, next to the adapters, because that is the only place
/// it can be kept complete: an app that hand-writes its own registry silently
/// loses any site added after it was written, and the site itself has no way
/// to announce that it exists. [http] is the transport every adapter shares;
/// [iptvSource] is the user's channel library, which the IPTV site reads
/// instead of a platform — pass null to leave IPTV out.
Map<String, LiveSite Function()> defaultSiteFactories(LiveHttp http, {IptvChannelSource? iptvSource}) => {
  SiteIds.acfun: () => AcfunSite(http: http),
  SiteIds.baiduLive: () => BaiduLiveSite(http: http),
  SiteIds.bigo: () => BigoSite(http: http),
  SiteIds.bilibili: () => BilibiliSite(http: http),
  SiteIds.cc: () => CcSite(http: http),
  SiteIds.chzzk: () => ChzzkSite(http: http),
  SiteIds.douyin: () => DouyinSite(http: http),
  SiteIds.douyu: () => DouyuSite(http: http),
  SiteIds.fc2Live: () => Fc2LiveSite(http: http),
  SiteIds.huya: () => HuyaSite(http: http),
  SiteIds.inke: () => InkeSite(http: http),
  SiteIds.jdLive: () => JdLiveSite(http: http),
  SiteIds.kick: () => KickSite(http: http),
  SiteIds.kilakila: () => KilakilaSite(http: http),
  SiteIds.kuaishou: () => KuaishouSite(http: http),
  SiteIds.kugouLive: () => KugouLiveSite(http: http),
  SiteIds.liveme: () => LiveMeSite(http: http),
  SiteIds.looklive: () => LookLiveSite(http: http),
  SiteIds.missevan: () => MissevanSite(http: http),
  SiteIds.niconico: () => NiconicoSite(http: http),
  SiteIds.pandalive: () => PandaLiveSite(http: http),
  SiteIds.picarto: () => PicartoSite(http: http),
  SiteIds.showroom: () => ShowroomSite(http: http),
  SiteIds.sixroom: () => SixRoomSite(http: http),
  SiteIds.soop: () => SoopSite(http: http),
  SiteIds.steamBroadcast: () => SteamBroadcastSite(http: http),
  SiteIds.tiktok: () => TikTokSite(http: http),
  SiteIds.twitcasting: () => TwitcastingSite(http: http),
  SiteIds.twitch: () => TwitchSite(http: http),
  SiteIds.weibo: () => WeiboSite(http: http),
  SiteIds.xiaohongshu: () => XiaohongshuSite(http: http),
  SiteIds.youtube: () => YouTubeSite(http: http),
  SiteIds.yy: () => YySite(http: http),
  if (iptvSource != null) SiteIds.iptv: () => IptvSite(source: iptvSource),
};
