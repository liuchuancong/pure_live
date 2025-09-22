import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:pure_live/common/l10n/generated/l10n.dart';
import 'package:pure_live/common/models/live_room.dart';
import 'package:pure_live/common/services/settings_service.dart';
import 'package:pure_live/core/common/core_log.dart';
import 'package:pure_live/core/interface/live_site_mixin.dart';
import 'package:pure_live/core/site/kuaishou/kuaishou_site.dart';
import 'package:url_launcher/url_launcher_string.dart';

import '../../sites.dart';

mixin SoopSiteMixin on SiteAccount, SiteVideoHeaders, SiteOpen, SiteParse {
  var platform =  Sites.soopSite;
  @override
  String getJumpToNativeUrl(LiveRoom liveRoom) {
    try {
      var appUrl =
      "sooplive://player/live?broad_no=${liveRoom.userId}&user_id=${liveRoom.roomId}&channel=";
      return appUrl;
    } catch (e) {
      return "";
    }
  }

  @override
  String getJumpToWebUrl(LiveRoom liveRoom) {
    try {
      var webUrl = "https://play.sooplive.co.kr/${liveRoom.roomId}";
      return webUrl;
    } catch (e) {
      return "";
    }
  }

  /// ------------------ 登录
  @override
  bool isSupportLogin() => true;

  @override
  bool isSupportQrLogin() => false;

  final Map<String, String> loginHeaders = {
    'User-Agent':
        // 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/128.0.0.0 Safari/537.36',
        "Mozilla/5.0 (iPhone; CPU iPhone OS 13_2_3 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/13.0.3 Mobile/15E148 Safari/604.1 Edg/118.0.0.0",
    'accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,image/apng,*/*;q=0.8,application/signed-exchange;v=b3',
    'connection': 'keep-alive',
    'sec-ch-ua': 'Google Chrome;v=107, Chromium;v=107, Not=A?Brand;v=24',
    'sec-ch-ua-platform': 'macOS',
    'Sec-Fetch-Dest': 'document',
    'Sec-Fetch-Mode': 'navigate',
    'Sec-Fetch-Site': 'same-origin',
    'Sec-Fetch-User': '?1'
  };

  @override
  URLRequest webLoginURLRequest() {
    return URLRequest(
      // url: WebUri("https://livev.m.chenzhongtech.com/fw/live/3xvm3rycyegby8y?cc=share_wxms&followRefer=151&shareMethod=CARD&kpn=GAME_ZONE&subBiz=LIVE_STEARM_OUTSIDE&shareId=18525643860104&shareToken=X8Ps8dZZjxzL1xG&shareMode=APP&efid=0&originShareId=18525643860104&shareObjectId=LodZ3A4PKRA&shareUrlOpened=0&timestamp=1755423126453"),
      url: WebUri("https://www.sooplive.co.kr/"),
      headers: loginHeaders,
    );
  }

  @override
  bool webLoginHandle(WebUri? uri) {
    if (uri == null) {
      return false;
    }
    return uri.host == "www.sooplive.co.kr";
  }

  @override
  Future<bool> loadUserInfo(Site site, String cookie) async {
    try {
      userName.value = "Cookie";
      uid = 0;
      var flag = true;
      isLogin.value = flag;
      userCookie.value = cookie;
      var liveSite = site.liveSite as KuaishowSite;
      liveSite.cookie = cookie;
      SettingsService settings = SettingsService.instance;
      settings.siteCookies[site.id] = cookie;
      return flag;
    } catch (e) {
      CoreLog.error(e);
      SmartDialog.showToast(Sites.getSiteName(site.id) + S.current.login_failed);
    }
    return false;
  }


  @override
  Future<SiteParseBean> parse(String url) async {
    String realUrl = getHttpUrl(url);
    var siteParseBean = emptySiteParseBean;
    if(realUrl.isEmpty) return siteParseBean;
    // 解析跳转
    List<RegExp> regExpJumpList = [
      // 网站 解析跳转
    ];
    siteParseBean = await parseJumpUrl(regExpJumpList, realUrl);
    if(siteParseBean.roomId.isNotEmpty) {
      return siteParseBean;
    }

    List<RegExp> regExpBeanList = [
      // soop
      RegExp(r"play\.sooplive\.co\.kr/([^/]+)"),
      RegExp(r"sooplive\.com/([^/]+)"),
    ];
    siteParseBean = await parseUrl(regExpBeanList, realUrl, platform);
    return siteParseBean;
  }

  @override
  List<OtherJumpItem> jumpItems(LiveRoom liveRoom) {
    List<OtherJumpItem> list = [];

    list.add(OtherJumpItem(
      text: '直播录像',
      iconData: Icons.emergency_recording_outlined,
      onTap: () async {
        try {
          await launchUrlString("https://www.sooplive.co.kr/${liveRoom.roomId}/vods", mode: LaunchMode.externalApplication);
        } catch (e) {
          CoreLog.error(e);
        }
      },
    ));
    return list;
  }
}
