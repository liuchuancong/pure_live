import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:pure_live/common/l10n/generated/l10n.dart';
import 'package:pure_live/common/models/bilibili_user_info_page.dart';
import 'package:pure_live/common/models/live_room.dart';
import 'package:pure_live/core/common/core_log.dart';
import 'package:pure_live/core/common/http_client.dart';
import 'package:pure_live/core/site/huya/huya_danmaku.dart';
import 'package:pure_live/core/interface/live_site_mixin.dart';
import 'package:pure_live/core/site/bilibili/bilibili_site.dart';
import 'package:pure_live/core/sites.dart';
import 'package:url_launcher/url_launcher_string.dart';

mixin HuyaSiteMixin on SiteAccount, SiteVideoHeaders, SiteOpen, SiteParse {
  var platform =  Sites.huyaSite;
  /// ------------------ 登录
  @override
  bool isSupportLogin() => false;

  @override
  URLRequest webLoginURLRequest() {
    // https://passport.douyu.com/member/login?
    return URLRequest(
      url: WebUri("https://passport.douyu.com/h5/loginActivity?"),
    );
  }

  @override
  bool webLoginHandle(WebUri? uri) {
    if (uri == null) {
      return false;
    }
    return uri.host == "m.huya.com" || uri.host == "www.huya.com";
  }

  /// 加载二维码
  @override
  Future<QRBean> loadQRCode() async {
    var qrBean = QRBean();
    try {
      qrBean.qrStatus = QRStatus.loading;

      var result = await HttpClient.instance.postJson("https://udblgn.huya.com/qrLgn/getQrId", data: {
        "uri": "70001",
        "version": "2.6",
        "context": "WB-58916e5b37344847bb1e992697fab1d0-CAEA8C3B19D00001867416302D4D1A06-0a7db71f78dff9667001473048303f3d",
        "appId": "5002",
        "appSign": "1ce3bf682483d03f146f58232ec10635",
        "authId": "",
        "sdid":
            "0UnHUgv0_qmfD4KAKlwzhqcAY7-3gj360qkcN5k4wYdI0XJtscrVr62o1YYZzg1B4zkULKxJq6oV-2xAQpnZ5xbqJSN_H8_Q3j8DgA3cO31XWVkn9LtfFJw_Qo4kgKr8OZHDqNnuwg612sGyflFn1dlDml87FNjrVrYPzfR4qgh-nojBVXkQR-6PcXF4Egs16",
        "lcid": "2052",
        "byPass": "3",
        "requestId": "54445967",
        "data": {
          "behavior": "%7B%22furl%22%3A%22https%3A%2F%2Fwww.huya.com%2Fkasha233%22%2C%22curl%22%3A%22https%3A%2F%2Fwww.huya.com%2Fg%22%2C%22user_action%22%3A%5B%5D%7D",
          "type": "",
          "domainList": "",
          "page": "https%3A%2F%2Fwww.huya.com%2F"
        }
      });
      CoreLog.d("result: $result");
      if (result["returnCode"] != 0) {
        throw result["message"];
      }

      /// 验证码链接
      /// https://udblgn.huya.com/qrLgn/getQrImg?k=doOvYRrvpvvuYqDVEa&appId=5002
      var qrCode = result["data"]["qrId"];
      var appId = "5002";
      var qrcodeUrl = "https://udblgn.huya.com/qrLgn/getQrImg?k=$qrCode&appId=$appId";
      var qrcodeImageResp = await HttpClient.instance.get(qrcodeUrl);
      qrBean.qrcodeKey = qrCode;
      qrBean.qrcodeUrl = qrcodeImageResp.data;
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
      // var milliseconds = DateTime.now().millisecondsSinceEpoch;
      var response = await HttpClient.instance.postJson("https://udblgn.huya.com/qrLgn/tryQrLogin", queryParameters: {
        "uri": "70003",
        "version": "2.6",
        "context": "WB-58916e5b37344847bb1e992697fab1d0-CAEA8C3B19D00001867416302D4D1A06-0a7db71f78dff9667001473048303f3d",
        "appId": "5002",
        "appSign": "1ce3bf682483d03f146f58232ec10635",
        "authId": "",
        "sdid":
            "0UnHUgv0_qmfD4KAKlwzhqZsHXvm4vLFryBc-n8pgX2AFXa8OP8eAbEAn4uaK4tX6xLV5iPDs18bgLfmm9W7t7aaP-ya6EOTIx0jAeaKPRUXWVkn9LtfFJw_Qo4kgKr8OZHDqNnuwg612sGyflFn1dlDml87FNjrVrYPzfR4qgh-nojBVXkQR-6PcXF4Egs16",
        "lcid": "2052",
        "byPass": "3",
        "requestId": "54449589",
        "data": {
          "qrId": "doOvYRrvpvvuYqDVEa",
          "remember": "1",
          "domainList": "",
          "behavior": "%7B%22furl%22%3A%22https%3A%2F%2Fwww.huya.com%2Fkasha233%22%2C%22curl%22%3A%22https%3A%2F%2Fwww.huya.com%2Fg%22%2C%22user_action%22%3A%5B%5D%7D",
          "page": "https%3A%2F%2Fwww.huya.com%2"
        }
      }, header: {
        "referer": "https://www.huya.com/",
      });
      // if (response.data["error"] != 0) {
      //   throw response.data["msg"];
      // }
      /// error -2 msg "客户端还未扫码"
      /// error -1 msg "code不存在或者是已经过期"
      CoreLog.d("response: $response");

      /// {
      //     "uri": 70004,
      //     "version": null,
      //     "context": "WB-58916e5b37344847bb1e992697fab1d0-CAEA8C3B19D00001867416302D4D1A06-0a7db71f78dff9667001473048303f3d",
      //     "requestId": 54449589,
      //     "returnCode": 0,
      //     "message": null,
      //     "description": "",
      //     "traceid": null,
      //     "data": {
      //         "stage": 0,
      //         "wupData": null,
      //         "domainUrlList": null
      //     }
      // }
      // var data = response.data["data"];
      var code = response.data["returnCode"];
      // var message = response.data["message"];
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
      } else if (code == -1) {
        qrBean.qrStatus = QRStatus.expired;
        qrBean.qrcodeKey = "";
      } else if (code == 86090) {
        qrBean.qrStatus = QRStatus.scanned;
      } else {
        qrBean.qrStatus = QRStatus.unscanned;
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

  @override
  Map<String, String> getVideoHeaders() {
    var validTs = 20000308;
    var sysTs = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    var last8 = sysTs % 10 ^ 8;
    var currentTs = last8 > validTs ? last8 : (validTs + sysTs ~/ 100);
    return {
      // "Referer": "https://m.huya.com",
      // "User-Agent": "Mozilla/5.0 (iPhone; CPU iPhone OS 16_6 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/16.6 Mobile/15E148 Safari/604.1 Edg/130.0.0.0"
      "User-Agent": "HYSDK(Windows, $currentTs)",
      // "Referer": "https://www.huya.com/",
      "Origin": "https://www.huya.com",
    };
  }

  @override
  String getJumpToNativeUrl(LiveRoom liveRoom) {
    try {
      var args = liveRoom.data as HuyaDanmakuArgs;
      return "yykiwi://homepage/index.html?banneraction=https%3A%2F%2Fdiy-front.cdn.huya.com%2Fzt%2Ffrontpage%2Fcc%2Fupdate.html%3Fhyaction%3Dlive%26channelid%3D${args.subSid}%26subid%3D${args.subSid}%26liveuid%3D${args.subSid}%26screentype%3D1%26sourcetype%3D0%26fromapp%3Dhuya_wap%252Fclick%252Fopen_app_guide%26&fromapp=huya_wap/click/open_app_guide";
    } catch (e) {
      return "";
    }
  }

  @override
  String getJumpToWebUrl(LiveRoom liveRoom) => "https://www.huya.com/${liveRoom.roomId}";


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
      // 虎牙
      RegExp(r"huya\.com/([\d|\w]+)$"),
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
          await launchUrlString("https://www.huya.com/video/u/${liveRoom.userId}?tabName=live&pageIndex=1", mode: LaunchMode.externalApplication);
        } catch (e) {
          CoreLog.error(e);
        }
      },
    ));
    return list;
  }
}
