import 'dart:developer';
import 'package:dio/dio.dart' as dio;
import 'package:flutter/services.dart';
import 'package:pure_live/common/index.dart';
import 'package:pure_live/modules/live_play/widgets/live_dlna_dialog.dart';

class LiveUrlTool {
  static Future<List<String>> parseLiveUrl(String url) async {
    if (url.isEmpty) return [];
    final urlRegExp = RegExp(
      r"((https?:www\.)|(https?:\/\/)|(www\.))[-a-zA-Z0-9@:%._\+~#=]{1,256}\.[a-zA-Z0-9]{1,6}(\/[-a-zA-Z0-9()@:%_\+.~#?&\/=]*)?",
    );
    List<String?> urlMatches = urlRegExp.allMatches(url).map((m) => m.group(0)).toList();
    if (urlMatches.isEmpty) return [];

    String realUrl = urlMatches.first!;

    // B站短链跳转
    if (realUrl.contains("b23.tv")) {
      var location = await _getRedirectLocation(realUrl);
      return await parseLiveUrl(location);
    }

    // B站直播间
    if (realUrl.contains("bilibili.com")) {
      var reg = RegExp(r"bilibili\.com/([\d|\w]+)");
      String id = reg.firstMatch(realUrl)?.group(1) ?? "";
      return [id, Sites.bilibiliSite];
    }

    // 斗鱼
    if (realUrl.contains("douyu.com")) {
      realUrl = realUrl.trimEndChar('/');
      var reg = RegExp(r"douyu\.com/([\d|\w]+)");
      String id = reg.firstMatch(realUrl)?.group(1) ?? "";
      return [id, Sites.douyuSite];
    }

    // 虎牙
    if (realUrl.contains("huya.com")) {
      realUrl = realUrl.trimEndChar('/');
      var reg = RegExp(r"huya\.com/([\d|\w]+)");
      String id = reg.firstMatch(realUrl)?.group(1) ?? "";
      return [id, Sites.huyaSite];
    }

    // 抖音直播
    if (realUrl.contains("live.douyin.com")) {
      realUrl = realUrl.trimEndChar('/');
      var reg = RegExp(r"live\.douyin\.com/([\d|\w]+)");
      String id = reg.firstMatch(realUrl)?.group(1) ?? "";
      return [id, Sites.douyinSite];
    }
    if (realUrl.contains("www.douyin.com")) {
      realUrl = realUrl.split("?")[0].trimEndChar('/');
      Uri uri = Uri.parse(realUrl);
      return [uri.pathSegments.last, Sites.douyinSite];
    }
    if (realUrl.contains("v.douyin.com")) {
      String id = await _getRealDouyinRoomId(realUrl);
      return [id, Sites.douyinSite];
    }
    if (url.contains("webcast.amemv.com")) {
      var reg = RegExp(r"reflow/(\d+)");
      String id = reg.firstMatch(url)?.group(1) ?? "";
      return [id, Sites.douyinSite];
    }

    // 快手
    if (realUrl.contains("live.kuaishou.com") || realUrl.contains("live.kuaishou.cn")) {
      realUrl = realUrl.trimEndChar('/');
      var reg = RegExp(r"live\.kuaishou\.(com|cn)/u/([a-zA-Z0-9]+)$");
      String id = reg.firstMatch(realUrl)?.group(2) ?? "";
      return [id, Sites.kuaishouSite];
    }

    // 网易CC
    if (realUrl.contains("cc.163.com")) {
      realUrl = realUrl.trimEndChar('/');
      var reg = RegExp(r"cc\.163\.com/([a-zA-Z0-9]+)$");
      String id = reg.firstMatch(realUrl)?.group(1) ?? "";
      return [id, Sites.ccSite];
    }

    return [];
  }

  /// 获取直播播放直链
  /// [liveUrl] 直播间链接
  static Future<void> getLivePlayUrl(String liveUrl) async {
    if (liveUrl.isEmpty) {
      ToastUtil.show(i18n("toolbox_empty_link"));
      return;
    }

    // 1. 解析链接
    List<String> parseResult = await parseLiveUrl(liveUrl);
    if (parseResult.length < 2 || parseResult[0].isEmpty) {
      ToastUtil.show(i18n("toolbox_parse_failed"));
      return;
    }

    String roomId = parseResult[0];
    String platform = parseResult[1];

    try {
      // 2. 获取房间详情
      SmartDialog.showLoading(msg: "");
      final detail = await Sites.of(platform).liveSite.getRoomDetail(roomId: roomId, platform: platform);

      // 3. 获取清晰度列表
      final qualities = await Sites.of(platform).liveSite.getPlayQualites(detail: detail);
      SmartDialog.dismiss(status: SmartStatus.loading);

      if (qualities.isEmpty) {
        ToastUtil.show(i18n("toolbox_quality_failed"));
        return;
      }

      // 4. 选择清晰度
      final selectedQuality = await Get.dialog(
        SimpleDialog(
          title: Text(i18n("toolbox_select_quality")),
          children: qualities
              .map(
                (e) => ListTile(
                  title: Text(e.quality, textAlign: TextAlign.center),
                  onTap: () => Navigator.pop(Get.context!, e),
                ),
              )
              .toList(),
        ),
      );
      if (selectedQuality == null) return;

      // 5. 获取播放线路
      SmartDialog.showLoading(msg: "");
      final playUrls = await Sites.of(platform).liveSite.getPlayUrls(detail: detail, quality: selectedQuality);
      SmartDialog.dismiss(status: SmartStatus.loading);

      // 6. 选择线路并复制
      await Get.dialog(
        SimpleDialog(
          title: Text(i18n("toolbox_select_line")),
          children: playUrls
              .asMap()
              .entries
              .map(
                (entry) => ListTile(
                  title: Text(i18n("toolbox_line", args: {"index": "${entry.key + 1}"})),
                  subtitle: Text(entry.value, maxLines: 1, overflow: TextOverflow.ellipsis),
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: entry.value));
                    Navigator.pop(Get.context!);
                    ToastUtil.show(i18n("toolbox_copy_success"));
                  },
                ),
              )
              .toList(),
        ),
      );
    } catch (e) {
      log("获取直链失败: $e", name: "LiveUrlTool");
      ToastUtil.show(i18n("toolbox_get_url_failed"));
    } finally {
      SmartDialog.dismiss(status: SmartStatus.loading);
    }
  }

  static Future<String> _getRedirectLocation(String url) async {
    try {
      await dio.Dio().get(url, options: dio.Options(followRedirects: false));
    } on dio.DioException catch (e) {
      if (e.response?.statusCode == 302) {
        return e.response?.headers.value("Location") ?? "";
      }
    } catch (e) {
      log(e.toString(), name: "_getRedirectLocation");
    }
    return "";
  }

  static Future<String> _getRealDouyinRoomId(String url) async {
    try {
      final headers = {
        "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36",
        "Accept": "*/*",
        "Origin": "https://live.douyin.com",
        "Referer": "https://live.douyin.com/",
      };

      final resp = await dio.Dio().get(
        url,
        options: dio.Options(followRedirects: true, headers: headers, maxRedirects: 100),
      );

      final reg = RegExp(r"reflow/(\d+)");
      String? roomId = reg.firstMatch(resp.realUri.toString())?.group(1);
      if (roomId == null) return "";

      final infoResp = await dio.Dio().get(
        "https://webcast.amemv.com/webcast/room/reflow/info/",
        queryParameters: {
          "room_id": roomId,
          'verifyFp': '',
          'type_id': 0,
          'live_id': 1,
          'sec_user_id': '',
          'app_id': 1128,
        },
      );

      return infoResp.data['data']['room']['owner']['web_rid']?.toString() ?? "";
    } catch (e) {
      log(e.toString(), name: "_getRealDouyinRoomId");
      return "";
    }
  }

  static Future<void> getPlayUrlByRoomId({required String roomId, required String platform}) async {
    if (roomId.isEmpty || platform.isEmpty) {
      ToastUtil.show(i18n("toolbox_empty_link"));
      return;
    }
    try {
      SmartDialog.showLoading(msg: "");

      final detail = await Sites.of(platform).liveSite.getRoomDetail(roomId: roomId, platform: platform);

      final qualities = await Sites.of(platform).liveSite.getPlayQualites(detail: detail);
      SmartDialog.dismiss(status: SmartStatus.loading);

      if (qualities.isEmpty) {
        ToastUtil.show(i18n("toolbox_quality_failed"));
        return;
      }

      final selectedQuality = await Get.dialog(
        SimpleDialog(
          title: Text(i18n("toolbox_select_quality")),
          children: qualities
              .map(
                (e) => ListTile(
                  title: Text(e.quality, textAlign: TextAlign.center),
                  onTap: () => Navigator.pop(Get.context!, e),
                ),
              )
              .toList(),
        ),
      );
      if (selectedQuality == null) return;

      SmartDialog.showLoading(msg: "");
      final playUrls = await Sites.of(platform).liveSite.getPlayUrls(detail: detail, quality: selectedQuality);
      SmartDialog.dismiss(status: SmartStatus.loading);

      await Get.dialog(
        SimpleDialog(
          title: Text(i18n("toolbox_select_line")),
          children: playUrls
              .asMap()
              .entries
              .map(
                (entry) => ListTile(
                  title: Text(i18n("toolbox_line", args: {"index": "${entry.key + 1}"})),
                  subtitle: Text(entry.value, maxLines: 1, overflow: TextOverflow.ellipsis),
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: entry.value));
                    Navigator.pop(Get.context!);
                    ToastUtil.show(i18n("toolbox_copy_success"));
                  },
                ),
              )
              .toList(),
        ),
      );
    } catch (e) {
      log("已知房间号获取直链失败: $e", name: "LiveUrlTool");
      ToastUtil.show(i18n("toolbox_get_url_failed"));
    } finally {
      SmartDialog.dismiss(status: SmartStatus.loading);
    }
  }

  static Future<void> castPlayUrlByRoomId({required String roomId, required String platform}) async {
    if (roomId.isEmpty || platform.isEmpty) {
      ToastUtil.show(i18n("toolbox_empty_link"));
      return;
    }

    try {
      SmartDialog.showLoading(msg: "");
      final detail = await Sites.of(platform).liveSite.getRoomDetail(roomId: roomId, platform: platform);

      final qualities = await Sites.of(platform).liveSite.getPlayQualites(detail: detail);
      SmartDialog.dismiss(status: SmartStatus.loading);

      if (qualities.isEmpty) {
        ToastUtil.show(i18n("toolbox_quality_failed"));
        return;
      }

      final selectedQuality = await Get.dialog(
        SimpleDialog(
          title: Text(i18n("toolbox_select_quality")),
          children: qualities
              .map(
                (e) => ListTile(
                  title: Text(e.quality, textAlign: TextAlign.center),
                  onTap: () {
                    Navigator.pop(Get.context!, e);
                  },
                ),
              )
              .toList(),
        ),
      );
      if (selectedQuality == null) return;

      SmartDialog.showLoading(msg: "");
      final playUrls = await Sites.of(platform).liveSite.getPlayUrls(detail: detail, quality: selectedQuality);
      SmartDialog.dismiss(status: SmartStatus.loading);

      if (playUrls.isEmpty) {
        ToastUtil.show(i18n("toolbox_get_url_failed"));
        return;
      }

      final selectedUrl = await Get.dialog(
        SimpleDialog(
          title: Text(i18n("toolbox_select_line")),
          children: playUrls
              .asMap()
              .entries
              .map(
                (entry) => ListTile(
                  title: Text(i18n("toolbox_line", args: {"index": "${entry.key + 1}"})),
                  subtitle: Text(entry.value, maxLines: 1, overflow: TextOverflow.ellipsis),
                  onTap: () {
                    Navigator.pop(Get.context!, entry.value);
                  },
                ),
              )
              .toList(),
        ),
      );

      // 选中url后直接投屏
      if (selectedUrl != null && selectedUrl.isNotEmpty) {
        Get.dialog(LiveDlnaPage(datasource: selectedUrl));
      }
    } catch (e) {
      SmartDialog.dismiss(status: SmartStatus.loading);
      ToastUtil.show(i18n("toolbox_get_url_failed"));
    }
  }
}

extension StringTrim on String {
  String trimEndChar(String char) {
    if (endsWith(char)) return substring(0, length - 1);
    return this;
  }
}
