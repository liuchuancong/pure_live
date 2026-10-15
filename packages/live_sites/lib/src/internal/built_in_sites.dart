import 'package:live_net/live_net.dart';
import 'package:live_sites/src/core/live_site.dart';
import 'package:live_sites/src/platforms/acfun/acfun_site.dart';
import 'package:live_sites/src/platforms/acfun/api/acfun_http.dart';
import 'package:live_sites/src/platforms/bigo/api/bigo_http.dart';
import 'package:live_sites/src/platforms/bigo/bigo_site.dart';
import 'package:live_sites/src/platforms/bilibili/api/bilibili_http.dart';
import 'package:live_sites/src/platforms/bilibili/bilibili_site.dart';
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
import 'package:live_sites/src/platforms/jdlive/api/jdlive_http.dart';
import 'package:live_sites/src/platforms/jdlive/jdlive_site.dart';
import 'package:live_sites/src/platforms/kick/api/kick_http.dart';
import 'package:live_sites/src/platforms/kick/kick_site.dart';
import 'package:live_sites/src/platforms/kuaishou/api/kuaishou_http.dart';
import 'package:live_sites/src/platforms/kuaishou/kuaishou_site.dart';
import 'package:live_sites/src/platforms/niconico/api/niconico_http.dart';
import 'package:live_sites/src/platforms/niconico/niconico_site.dart';
import 'package:live_sites/src/platforms/twitch/api/twitch_http.dart';
import 'package:live_sites/src/platforms/twitch/twitch_site.dart';
import 'package:live_sites/src/platforms/youtube/api/youtube_http.dart';
import 'package:live_sites/src/platforms/youtube/youtube_site.dart';

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
    ChzzkSite(http: ChzzkHttp(transport)),
    Fc2LiveSite(http: Fc2LiveHttp(transport)),
    KickSite(http: KickHttp(transport)),
    NiconicoSite(http: NiconicoHttp(transport)),
    JdliveSite(http: JdliveHttp(transport)),
  ];
}
