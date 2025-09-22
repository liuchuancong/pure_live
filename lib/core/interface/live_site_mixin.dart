import 'package:dio/dio.dart' as dio;
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:get/get.dart';
import 'package:pure_live/common/index.dart';

import '../common/core_log.dart';

mixin class SiteAccount {
  /// 是否登录
  var isLogin = false.obs;

  /// cookie 内容
  var userCookie = "".obs;

  /// 用户ID
  var uid = 0;

  /// 用户名
  var userName = "".obs;

  /// 获取用户ID
  int getUserId() => uid;

  /// 获取用户Cookie
  String getUserCookie() => userCookie.value;

  /// 是否支持登录
  bool isSupportLogin() => false;

  /// 是否支持Web登录
  bool isSupportWebLogin() => true;

  /// 是否支持二维码登录
  bool isSupportQrLogin() => true;

  /// 是否支持Cookie登录
  bool isSupportCookieLogin() => true;

  /// 退出登录
  Future<void> logout(Site site) async {
    userCookie.value = "";
    uid = 0;
    userName.value = S.current.login_not;
    isLogin.value = false;
    SettingsService settings = Get.find<SettingsService>();
    settings.siteCookies.remove(site.id);
    CookieManager cookieManager = CookieManager.instance();
    await cookieManager.deleteAllCookies();
  }

  /// 加载用户信息
  Future<bool> loadUserInfo(Site site, String cookie) async {
    userCookie.value = "";
    uid = 0;
    userName.value = S.current.login_not;
    isLogin.value = false;
    return false;
  }

  /// web登录请求
  URLRequest webLoginURLRequest() => URLRequest(headers: {}, url: WebUri(""),);

  /// web登录处理，判断是否成功
  bool webLoginHandle(WebUri? uri) => false;

  /// 加载二维码
  Future<QRBean> loadQRCode() async {
    return QRBean();
  }

  ///  获取二维码扫描状态
  Future<QRBean> pollQRStatus(Site site, QRBean qrBean) async {
    return qrBean;
  }

}

/// 二维码状态
enum QRStatus {
  /// 加载中
  loading,

  /// 没有使用
  unscanned,

  /// 扫描中
  scanned,

  /// 过期
  expired,

  /// 失败
  failed,

  /// 成功
  success,
}

/// 二维码实体
class QRBean {
  /// 二维码状态
  QRStatus qrStatus = QRStatus.loading;

  /// 二维码链接
  var qrcodeUrl = "";

  /// 二维码验证秘钥
  var qrcodeKey = "";
}

mixin class SiteVideoHeaders {
  /// 获取视频播放 http head
  Map<String, String> getVideoHeaders() => {};
}

mixin class SiteOpen {
  /// 跳转 APP url
  String getJumpToNativeUrl(LiveRoom liveRoom) => "";

  /// 跳转 Web url
  String getJumpToWebUrl(LiveRoom liveRoom) => "";
}

// 站点解析
final emptySiteParseBean = SiteParseBean(roomId: '', platform: '');
final urlRegExp = RegExp(r"((https?:www\.)|(https?:\/\/)|(www\.))[-a-zA-Z0-9@:%._\+~#=]{1,256}\.[a-zA-Z0-9]{1,6}(\/[-a-zA-Z0-9()@:%_\+.~#?&\/=]*)?");
mixin class SiteParse {
  /// 站点解析 url
  Future<SiteParseBean> parse(String url) async {
    // roomId, platform
    return emptySiteParseBean;
  }

  String getHttpUrl(String text) {
    List<String?> urlMatches = urlRegExp.allMatches(text).map((m) => m.group(0)).toList();
    if (urlMatches.isEmpty) return "";
    String realUrl = urlMatches.first!;
    return realUrl;
  }

  /// 解析跳转 url
  Future<SiteParseBean> parseJumpUrl(List<RegExp> regExpJumpList, String realUrl) async {
    for (var i = 0; i < regExpJumpList.length; i++) {
      var regExp = regExpJumpList[i];
      var u = regExp.firstMatch(realUrl)?.group(0) ?? "";
      if(u != "") {
        var location = await getHttpResponseLocation(u);
        return await parse(location);
      }
    }
    return emptySiteParseBean;
  }

  /// 解析 url
  Future<SiteParseBean> parseUrl(List<RegExp> regExpList, String realUrl, platform) async {
    for (var i = 0; i < regExpList.length; i++) {
      var regExp = regExpList[i];
      var id = regExp.firstMatch(realUrl)?.group(1) ?? "";
      if (id != "") {
        return SiteParseBean(roomId: id, platform: platform);
      }
    }
    return emptySiteParseBean;
  }

  /// 获取 http response Location
  Future<String> getHttpResponseLocation(String url) async {
    try {
      if (url.isEmpty) return "";
      await dio.Dio().get(
        url,
        options: dio.Options(
          followRedirects: false,
        ),
      );
    } on dio.DioException catch (e) {
      CoreLog.error(e);
      if (e.response!.statusCode == 302) {
        var redirectUrl = e.response!.headers.value("Location");
        if (redirectUrl != null) {
          return redirectUrl;
        }
      }
    } catch (e) {
      CoreLog.error(e);
    }
    return "";
  }

}

class SiteParseBean {
  String roomId;
  String platform;

  SiteParseBean({
    required this.roomId,
    required this.platform,
  });
}

class RegExpBean {
  late RegExp regExp;
  late String siteType;

  RegExpBean({
    required this.regExp,
    required this.siteType,
  });
}

/// 跳转
mixin class SiteOtherJump {
  List<OtherJumpItem> jumpItems(LiveRoom liveRoom) {
    return [];
  }
}

/// 跳转选项
class OtherJumpItem {
  late IconData? iconData;
  late void Function() onTap;
  late String text;

  OtherJumpItem({
    required this.text,
    this.iconData,
    required this.onTap,
  });
}