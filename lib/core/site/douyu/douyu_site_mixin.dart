import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:pure_live/common/index.dart';
import 'package:pure_live/common/models/bilibili_user_info_page.dart';
import 'package:pure_live/common/models/live_room.dart';
import 'package:pure_live/core/common/core_log.dart';
import 'package:pure_live/core/common/http_client.dart';
import 'package:pure_live/core/interface/live_site_mixin.dart';
import 'package:pure_live/core/site/bilibili/bilibili_site.dart';
import 'package:pure_live/core/sites.dart';
import 'package:url_launcher/url_launcher_string.dart';

mixin DouyuSiteMixin on SiteAccount, SiteVideoHeaders, SiteOpen, SiteParse, SiteOtherJump {
  var platform = Sites.douyuSite;

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
    return uri.host == "m.douyu.com" || uri.host == "www.douyu.com";
  }

  /// 加载二维码
  @override
  Future<QRBean> loadQRCode() async {
    var qrBean = QRBean();
    try {
      qrBean.qrStatus = QRStatus.loading;

      var result = await HttpClient.instance.postJson("https://passport.douyu.com/scan/generateCode", data: {
        "client_id": 1,
        "isMultiAccount": 0
      }, header: {
        "referer": "https://passport.douyu.com/member/login?",
        "origin": "https://passport.douyu.com",
        "user-agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/128.0.0.0 Safari/537.36",
      });
      CoreLog.d("result: $result");
      if (result["error"] != 0) {
        throw result["msg"];
      }
      qrBean.qrcodeKey = result["data"]["code"];
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
      var milliseconds = DateTime.now().millisecondsSinceEpoch;
      var response = await HttpClient.instance.get("https://passport.douyu.com/japi/scan/auth", queryParameters: {
        "time": milliseconds,
        "code": qrBean.qrcodeKey,
      }, header: {
        "referer": "https://www.douyu.com/",
      });
      // if (response.data["error"] != 0) {
      //   throw response.data["msg"];
      // }
      /// error -2 msg "客户端还未扫码"
      /// error -1 msg "code不存在或者是已经过期"
      CoreLog.d("response: $response");
      // var data = response.data["data"];
      var code = response.data["error"];
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
        userName.value = info.uname ?? "未登录";
        uid = info.mid ?? 0;
        var flag = info.uname != null;
        isLogin.value = flag;
        CoreLog.d("isLogin: $flag");
        userCookie.value = cookie;
        var liveSite = site.liveSite as BiliBiliSite;
        liveSite.cookie = cookie;
        return flag;
      } else {
        SmartDialog.showToast("${Sites.getSiteName(site.id)}登录已失效，请重新登录");
        logout(site);
      }
    } catch (e) {
      CoreLog.error(e);
      SmartDialog.showToast("获取${Sites.getSiteName(site.id)}用户信息失败，可前往账号管理重试");
    }
    return false;
  }

  @override
  String getJumpToNativeUrl(LiveRoom liveRoom) {
    try {
      // naviteUrl = "douyulink://?type=90001&schemeUrl=douyuapp%3A%2F%2Froom%3FliveType%3D0%26rid%3D${liveRoomRx.roomId}";
      return "dydeeplink://platformapi/startApp?room_id=${liveRoom.roomId}";
    } catch (e) {
      return "";
    }
  }

  @override
  String getJumpToWebUrl(LiveRoom liveRoom) {
    try {
      return "https://www.douyu.com/${liveRoom.roomId}";
    } catch (e) {
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
      // 网站 解析跳转
    ];
    siteParseBean = await parseJumpUrl(regExpJumpList, realUrl);
    if (siteParseBean.roomId.isNotEmpty) {
      return siteParseBean;
    }

    List<RegExp> regExpBeanList = [
      // 斗鱼
      RegExp(r"douyu\.com/([\d|\w]+)[/]?$"),
      RegExp(r"douyu\.com/topic/[\w\d]+\?.*rid=([^&]+).*$"),
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
          await launchUrlString("https://v.douyu.com/author/${liveRoom.userId}?type=liveReplay", mode: LaunchMode.externalApplication);
        } catch (e) {
          CoreLog.error(e);
        }
      },
    ));

    list.add(OtherJumpItem(
      text: '鱼吧',
      iconData: Icons.web_outlined,
      onTap: () async {
        try {
          await launchUrlString("http://yuba.douyu.com/api/dy/anchor/anchorTopic?room_id=${liveRoom.roomId}", mode: LaunchMode.externalApplication);
        } catch (e) {
          CoreLog.error(e);
        }
      },
    ));

    return list;
  }
}
