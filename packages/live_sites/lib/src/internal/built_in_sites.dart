import 'package:live_net/live_net.dart';
import 'package:live_sites/src/core/live_site.dart';
import 'package:live_sites/src/platforms/acfun/acfun_site.dart';
import 'package:live_sites/src/platforms/acfun/api/acfun_http.dart';
import 'package:live_sites/src/platforms/bigo/api/bigo_http.dart';
import 'package:live_sites/src/platforms/bigo/bigo_site.dart';
import 'package:live_sites/src/platforms/bilibili/api/bilibili_http.dart';
import 'package:live_sites/src/platforms/bilibili/bilibili_site.dart';
import 'package:live_sites/src/platforms/cc/api/cc_http.dart';
import 'package:live_sites/src/platforms/cc/cc_site.dart';
import 'package:live_sites/src/platforms/chzzk/api/chzzk_http.dart';
import 'package:live_sites/src/platforms/chzzk/chzzk_site.dart';
import 'package:live_sites/src/platforms/douyin/api/douyin_http.dart';
import 'package:live_sites/src/platforms/douyin/douyin_site.dart';
import 'package:live_sites/src/platforms/douyu/api/douyu_http.dart';
import 'package:live_sites/src/platforms/douyu/douyu_site.dart';
import 'package:live_sites/src/platforms/fc2live/api/fc2live_http.dart';
import 'package:live_sites/src/platforms/fc2live/fc2live_site.dart';
import 'package:live_sites/src/platforms/huya/api/huya_http.dart';
import 'package:live_sites/src/platforms/huya/huya_site.dart';
import 'package:live_sites/src/platforms/inke/api/inke_http.dart';
import 'package:live_sites/src/platforms/inke/inke_site.dart';
import 'package:live_sites/src/platforms/jdlive/api/jdlive_http.dart';
import 'package:live_sites/src/platforms/jdlive/jdlive_site.dart';
import 'package:live_sites/src/platforms/kick/api/kick_http.dart';
import 'package:live_sites/src/platforms/kick/kick_site.dart';
import 'package:live_sites/src/platforms/kilakila/api/kilakila_http.dart';
import 'package:live_sites/src/platforms/kilakila/kilakila_site.dart';
import 'package:live_sites/src/platforms/kuaishou/api/kuaishou_http.dart';
import 'package:live_sites/src/platforms/kuaishou/kuaishou_site.dart';
import 'package:live_sites/src/platforms/kugoulive/api/kugoulive_http.dart';
import 'package:live_sites/src/platforms/kugoulive/kugoulive_site.dart';
import 'package:live_sites/src/platforms/liveme/api/liveme_http.dart';
import 'package:live_sites/src/platforms/liveme/liveme_site.dart';
import 'package:live_sites/src/platforms/looklive/api/looklive_http.dart';
import 'package:live_sites/src/platforms/looklive/looklive_site.dart';
import 'package:live_sites/src/platforms/missevan/api/missevan_http.dart';
import 'package:live_sites/src/platforms/missevan/missevan_site.dart';
import 'package:live_sites/src/platforms/niconico/api/niconico_http.dart';
import 'package:live_sites/src/platforms/niconico/niconico_site.dart';
import 'package:live_sites/src/platforms/pandalive/api/pandalive_http.dart';
import 'package:live_sites/src/platforms/pandalive/pandalive_site.dart';
import 'package:live_sites/src/platforms/picarto/api/picarto_http.dart';
import 'package:live_sites/src/platforms/picarto/picarto_site.dart';
import 'package:live_sites/src/platforms/showroom/api/showroom_http.dart';
import 'package:live_sites/src/platforms/showroom/showroom_site.dart';
import 'package:live_sites/src/platforms/sixroom/api/sixroom_http.dart';
import 'package:live_sites/src/platforms/sixroom/sixroom_site.dart';
import 'package:live_sites/src/platforms/soop/api/soop_http.dart';
import 'package:live_sites/src/platforms/soop/soop_site.dart';
import 'package:live_sites/src/platforms/steambroadcast/api/steambroadcast_http.dart';
import 'package:live_sites/src/platforms/steambroadcast/steambroadcast_site.dart';
import 'package:live_sites/src/platforms/tiktok/api/tiktok_http.dart';
import 'package:live_sites/src/platforms/tiktok/tiktok_site.dart';
import 'package:live_sites/src/platforms/twitcasting/api/twitcasting_http.dart';
import 'package:live_sites/src/platforms/twitcasting/twitcasting_site.dart';
import 'package:live_sites/src/platforms/twitch/api/twitch_http.dart';
import 'package:live_sites/src/platforms/twitch/twitch_site.dart';
import 'package:live_sites/src/platforms/xiaohongshu/api/xiaohongshu_http.dart';
import 'package:live_sites/src/platforms/xiaohongshu/xiaohongshu_site.dart';
import 'package:live_sites/src/platforms/youtube/api/youtube_http.dart';
import 'package:live_sites/src/platforms/youtube/youtube_site.dart';
import 'package:live_sites/src/platforms/yy/api/yy_http.dart';
import 'package:live_sites/src/platforms/yy/yy_site.dart';

/// The single internal construction entry point for built-in sites.
///
/// Only platforms implemented against this contract belong here; an
/// unimplemented platform is not registered. The application composition
/// root calls this and hands the result to `LiveSiteRegistry`.
List<LiveSite> createBuiltInLiveSites({LiveHttp? http}) {
  final transport = http ?? DioFactory().create();
  return <LiveSite>[
    DouyuSite(http: DouyuHttp(transport)),
    HuyaSite(http: HuyaHttp(transport)),
    DouyinSite(http: DouyinHttp(transport)),
    BilibiliSite(http: BilibiliHttp(transport)),
    KuaishouSite(http: KuaishouHttp(transport)),
    YoutubeSite(http: YouTubeHttp(transport)),
    TwitchSite(http: TwitchHttp(transport)),
    AcfunSite(http: AcfunHttp(transport)),
    BigoSite(http: BigoHttp(transport)),
    CcSite(http: CcHttp(transport)),
    ChzzkSite(http: ChzzkHttp(transport)),
    Fc2LiveSite(http: Fc2LiveHttp(transport)),
    KickSite(http: KickHttp(transport)),
    NiconicoSite(http: NiconicoHttp(transport)),
    PicartoSite(http: PicartoHttp(transport)),
    LookliveSite(http: LookliveHttp(transport)),
    InkeSite(http: InkeHttp(transport)),
    JdliveSite(http: JdliveHttp(transport)),
    KilakilaSite(http: KilakilaHttp(transport)),
    KugouliveSite(http: KugouliveHttp(transport)),
    MissevanSite(http: MissevanHttp(transport)),
    PandaliveSite(http: PandaliveHttp(transport)),
    ShowroomSite(http: ShowroomHttp(transport)),
    SixroomSite(http: SixroomHttp(transport)),
    LivemeSite(http: LivemeHttp(transport)),
    XiaohongshuSite(http: XiaohongshuHttp(transport)),
    YySite(http: YyHttp(transport)),
    SoopSite(http: SoopHttp(transport)),
    SteambroadcastSite(http: SteambroadcastHttp(transport)),
    TiktokSite(http: TiktokHttp(transport)),
    TwitcastingSite(http: TwitcastingHttp(transport)),
  ];
}
