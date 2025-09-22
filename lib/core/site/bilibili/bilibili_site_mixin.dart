import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';
import 'package:pure_live/common/l10n/generated/l10n.dart';
import 'package:pure_live/common/models/bilibili_user_info_page.dart';
import 'package:pure_live/common/models/live_room.dart';
import 'package:pure_live/common/services/settings_service.dart';
import 'package:pure_live/core/common/core_log.dart';
import 'package:pure_live/core/common/http_client.dart';
import 'package:pure_live/core/interface/live_site_mixin.dart';
import 'package:pure_live/core/site/bilibili/bilibili_site.dart';
import 'package:pure_live/core/sites.dart';
import 'package:url_launcher/url_launcher_string.dart';

mixin BilibiliSiteMixin on SiteAccount, SiteVideoHeaders, SiteOpen, SiteParse {
  var platform =  Sites.bilibiliSite;
  final Map<String, String> loginHeaders = {
    'User-Agent':
    "Mozilla/5.0 (iPhone; CPU iPhone OS 13_2_3 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/13.0.3 Mobile/15E148 Safari/604.1 Edg/118.0.0.0",
    // 'accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,image/apng,*/*;q=0.8,application/signed-exchange;v=b3',
  };
  /// ------------------ 登录
  @override
  bool isSupportLogin() => true;

  @override
  URLRequest webLoginURLRequest() {
    return URLRequest(
      url: WebUri("https://passport.bilibili.com/login"),
      headers: loginHeaders,
    );
  }

  @override
  bool webLoginHandle(WebUri? uri) {
    if (uri == null) {
      return false;
    }
    return uri.host == "m.bilibili.com" || uri.host == "www.bilibili.com";
  }

  /// 加载二维码
  @override
  Future<QRBean> loadQRCode() async {
    var qrBean = QRBean();
    try {
      qrBean.qrStatus = QRStatus.loading;

      var result = await HttpClient.instance.getJson(
        "https://passport.bilibili.com/x/passport-login/web/qrcode/generate",
      );
      if (result["code"] != 0) {
        throw result["message"];
      }
      qrBean.qrcodeKey = result["data"]["qrcode_key"];
      qrBean.qrcodeUrl = result["data"]["url"];
      qrBean.qrStatus = QRStatus.unscanned;
    } catch (e) {
      CoreLog.error(e);
      SmartDialog.showToast(e.toString());
      qrBean.qrStatus = QRStatus.failed;
    }
    return qrBean;
  }

  ///  获取二维码扫描状态
  @override
  Future<QRBean> pollQRStatus(Site site, QRBean qrBean) async {
    try {
      var response = await HttpClient.instance.get(
        "https://passport.bilibili.com/x/passport-login/web/qrcode/poll",
        queryParameters: {
          "qrcode_key": qrBean.qrcodeKey,
        },
      );
      if (response.data["code"] != 0) {
        throw response.data["message"];
      }
      var data = response.data["data"];
      var code = data["code"];
      if (code == 0) {
        var cookies = <String>[];
        response.headers["set-cookie"]?.forEach((element) {
          var cookie = element.split(";")[0];
          cookies.add(cookie);
        });
        if (cookies.isNotEmpty) {
          var cookieStr = cookies.join(";");
          await loadUserInfo(site, cookieStr);
          qrBean.qrStatus = QRStatus.success;
        }
      } else if (code == 86038) {
        qrBean.qrStatus = QRStatus.expired;
        qrBean.qrcodeKey = "";
      } else if (code == 86090) {
        qrBean.qrStatus = QRStatus.scanned;
      }
    } catch (e) {
      CoreLog.error(e);
      SmartDialog.showToast(e.toString());
    }
    return qrBean;
  }

  @override
  Future<bool> loadUserInfo(Site site, String cookie) async {
    try {
      var result = await HttpClient.instance.getJson(
        "https://api.bilibili.com/x/member/web/account",
        header: {
          "Cookie": cookie,
        },
      );
      if (result["code"] == 0) {
        var info = BiliBiliUserInfoModel.fromJson(result["data"]);
        userName.value = info.uname ?? "";
        uid = info.mid ?? 0;
        var flag = info.uname != null;
        isLogin.value = flag;
        CoreLog.d("isLogin: $flag");
        userCookie.value = cookie;
        var liveSite = site.liveSite as BiliBiliSite;
        liveSite.cookie = cookie;
        liveSite.userId = uid;
        SettingsService settings = Get.find<SettingsService>();
        settings.siteCookies[site.id] = cookie;
        return flag;
      } else {
        SmartDialog.showToast(Sites.getSiteName(site.id) + S.current.login_expired);
        logout(site);
      }
    } catch (e) {
      CoreLog.error(e);
      SmartDialog.showToast(Sites.getSiteName(site.id) + S.current.login_failed);
    }
    return false;
  }

  /// 获取视频播放 http head
  @override
  Map<String, String> getVideoHeaders() {
    return {
      "cookie": userCookie.value,
      "authority": "api.bilibili.com",
      "accept": "text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8,application/signed-exchange;v=b3;q=0.7",
      "accept-language": "zh-CN,zh;q=0.9",
      "cache-control": "no-cache",
      "dnt": "1",
      "pragma": "no-cache",
      "sec-ch-ua": '"Not A(Brand";v="99", "Google Chrome";v="121", "Chromium";v="121"',
      "sec-ch-ua-mobile": "?0",
      "sec-ch-ua-platform": '"macOS"',
      "sec-fetch-dest": "document",
      "sec-fetch-mode": "navigate",
      "sec-fetch-site": "none",
      "sec-fetch-user": "?1",
      "upgrade-insecure-requests": "1",
      "user-agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/121.0.0.0 Safari/537.36",
      "referer": "https://live.bilibili.com"
    };
  }

  @override
  String getJumpToNativeUrl(LiveRoom liveRoom) => "bilibili://live/${liveRoom.roomId}";

  @override
  String getJumpToWebUrl(LiveRoom liveRoom) => "https://live.bilibili.com/${liveRoom.roomId}";

  @override
  Future<SiteParseBean> parse(String url) async {
    String realUrl = getHttpUrl(url);
    var siteParseBean = emptySiteParseBean;
    if(realUrl.isEmpty) return siteParseBean;
    // 解析跳转
    List<RegExp> regExpJumpList = [
      // bilibili 网站 解析跳转
      RegExp(r"https?:\/\/b23.tv\/[0-9a-z-A-Z]+")
    ];
    siteParseBean = await parseJumpUrl(regExpJumpList, realUrl);
    if(siteParseBean.roomId.isNotEmpty) {
      return siteParseBean;
    }

    List<RegExp> regExpBeanList = [
      // bilibili 网站匹配
      RegExp(r"bilibili\.com/([\d|\w]+)$"),
      RegExp(r"bilibili\.com/h5/([\d\w]+)$"),
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
          // await launchUrlString("https://space.bilibili.com/${liveRoom.userId}/lists/405144?type=series", mode: LaunchMode.externalApplication);
          await launchUrlString("https://space.bilibili.com/${liveRoom.userId}/lists?type=series", mode: LaunchMode.externalApplication);
        } catch (e) {
          CoreLog.error(e);
        }
      },
    ));

    list.add(OtherJumpItem(
      text: '动态',
      iconData: Icons.wind_power_outlined,
      onTap: () async {
        try {
          await launchUrlString("https://space.bilibili.com/${liveRoom.userId}/dynamic", mode: LaunchMode.externalApplication);
        } catch (e) {
          CoreLog.error(e);
        }
      },
    ));

    return list;
  }
}
