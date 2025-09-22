import 'package:dio/dio.dart' as dio;
import 'package:pure_live/common/models/live_room.dart';
import 'package:pure_live/core/common/core_log.dart';
import 'package:pure_live/core/site/douyin/douyin_danmaku.dart';
import 'package:pure_live/core/interface/live_site_mixin.dart';

import '../../sites.dart';

mixin DouyinSiteMixin on SiteAccount, SiteVideoHeaders, SiteOpen, SiteParse {
  var platform = Sites.douyinSite;

  @override
  String getJumpToNativeUrl(LiveRoom liveRoom) {
    try {
      var args = liveRoom.danmakuData as DouyinDanmakuArgs;
      return "snssdk1128://webcast_room?room_id=${args.roomId}";
    } catch (e) {
      CoreLog.w("$e");
      return "";
    }
  }

  @override
  String getJumpToWebUrl(LiveRoom liveRoom) {
    try {
      var args = liveRoom.danmakuData as DouyinDanmakuArgs;
      return "https://live.douyin.com/${args.webRid}";
    } catch (e) {
      CoreLog.w("$e");
      return "";
    }
  }

  @override
  Future<SiteParseBean> parse(String url) async {
    String realUrl = getHttpUrl(url);
    var siteParseBean = emptySiteParseBean;
    if (realUrl.isEmpty) return siteParseBean;
    // 解析跳转
    List<RegExp> regExpJumpList = [
      //网站 解析跳转
    ];
    siteParseBean = await parseJumpUrl(regExpJumpList, realUrl);
    if (siteParseBean.roomId.isNotEmpty) {
      return siteParseBean;
    }

    if (realUrl.contains("v.douyin.com")) {
      final id = await getRealDouyinUrl(realUrl);
      if(id.isEmpty) return siteParseBean;
      return SiteParseBean(roomId: id, platform: platform);
    }

    List<RegExp> regExpBeanList = [
      // 抖音
      RegExp(r"live\.douyin\.com/([\d|\w]+)"),
    ];
    siteParseBean = await parseUrl(regExpBeanList, realUrl, platform);
    return siteParseBean;
  }

  Future<String> getRealDouyinUrl(String url) async {
    try {
      String realUrl = getHttpUrl(url);
      var headers = {
        "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/123.0.0.0 Safari/537.36",
        "Accept": "*/*",
        "Accept-Encoding": "gzip, deflate, br, zstd",
        "Origin": "https://live.douyin.com",
        "Referer": "https://live.douyin.com/",
        "Sec-Fetch-Site": "cross-site",
        "Sec-Fetch-Mode": "cors",
        "Sec-Fetch-Dest": "empty",
        "Accept-Language": "zh-CN,zh;q=0.9"
      };
      dio.Response response = await dio.Dio().get(
        realUrl,
        options: dio.Options(followRedirects: true, headers: headers, maxRedirects: 100),
      );
      final liveResponseRegExp = RegExp(r"/reflow/(\d+)");
      String reflow = liveResponseRegExp.firstMatch(response.realUri.toString())?.group(0) ?? "";
      var liveResponse = await dio.Dio().get("https://webcast.amemv.com/webcast/room/reflow/info/", queryParameters: {
        "room_id": reflow.split("/").last.toString(),
        'verifyFp': '',
        'type_id': 0,
        'live_id': 1,
        'sec_user_id': '',
        'app_id': 1128,
        'msToken': '',
        'X-Bogus': '',
      });
      var room = liveResponse.data['data']['room']['owner']['web_rid'];
      return room.toString();
    } catch (e) {
      CoreLog.error(e);
    }
    return "";
  }
}
