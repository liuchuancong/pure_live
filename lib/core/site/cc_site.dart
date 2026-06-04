import 'dart:convert';
import 'package:pure_live/common/index.dart';
import 'package:pure_live/model/live_category.dart';
import 'package:pure_live/core/common/core_log.dart';
import 'package:pure_live/model/live_anchor_item.dart';
import 'package:pure_live/core/common/http_client.dart';
import 'package:pure_live/model/live_play_quality.dart';
import 'package:pure_live/core/interface/live_site.dart';
import 'package:pure_live/core/danmaku/empty_danmaku.dart';
import 'package:pure_live/core/interface/live_danmaku.dart';

class CCSite implements LiveSite {
  @override
  String id = "cc";

  @override
  String name = "网易CC直播";

  @override
  LiveDanmaku getDanmaku() => EmptyDanmaku();
  final String kUserAgent =
      "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/140.0.0.0 Safari/537.36";

  @override
  Future<List<LiveCategory>> getCategores(int page, int pageSize) async {
    List<LiveCategory> categories = [
      LiveCategory(id: "1", name: "全部", children: []),
      LiveCategory(id: "2", name: "端游", children: []),
      LiveCategory(id: "4", name: "手游", children: []),
      LiveCategory(id: "5", name: "其他", children: []),
    ];
    var res = await HttpClient.instance.getText(
      "https://cc.163.com/category/",
      queryParameters: {"format": "json"},
      header: {"user-agent": kUserAgent},
    );
    var result = jsonDecode(res);
    try {
      for (var item in categories) {
        List games = result['game_list'];
        if (item.id == "2") {
          games = games.where((x) => x["game_tag"] == "pc_game").toList();
        } else if (item.id == "4") {
          games = games.where((x) => x["game_tag"] == "mobile_game").toList();
        } else if (item.id == "5") {
          games = games.where((x) => x["game_tag"] == "other").toList();
        }
        var items = await getSubCategores(item, games);
        item.children.addAll(items);
      }
    } catch (e) {
      CoreLog.error(e);
    }
    return categories;
  }

  Future<List<LiveArea>> getSubCategores(LiveCategory liveCategory, List result) async {
    List<LiveArea> subs = [];
    for (var item in result) {
      var gid = item["gametype"].toString();
      var subCategory = LiveArea(
        areaId: gid,
        areaName: item["gamename"] ?? '',
        areaType: liveCategory.id,
        platform: Sites.ccSite,
        areaPic: item["img"],
        typeName: liveCategory.name,
      );
      subs.add(subCategory);
    }
    return subs;
  }

  @override
  Future<List<LiveRoom>> getCategoryRooms(LiveArea category, {int page = 1, int pageSize = 30}) async {
    var result = await HttpClient.instance.getJson(
      "https://cc.163.com/_next/data/nextjs/category/${category.areaId}.json",
      queryParameters: {"game": category.areaId},
    );
    var items = <LiveRoom>[];
    try {
      for (var item in result["pageProps"]["gametypeData"]["lives"]) {
        var roomItem = LiveRoom(
          roomId: item["cuteid"].toString(),
          title: item["title"].toString(),
          cover: item["cover"].toString(),
          nick: item["nickname"].toString(),
          watching: item["webcc_visitor"].toString(),
          avatar: item["purl"],
          area: item["game_name"] ?? '',
          liveStatus: LiveStatus.live,
          status: true,
          platform: Sites.ccSite,
        );
        items.add(roomItem);
      }
    } catch (e) {
      CoreLog.error(e);
    }
    return items;
  }

  @override
  Future<List<LivePlayQuality>> getPlayQualites({required LiveRoom detail}) {
    List<LivePlayQuality> qualities = <LivePlayQuality>[];
    var reflect = {
      'blueray': '原画',
      'original': '原画',
      'high': '高清',
      'medium': '标准',
      'standard': '标准',
      'low': '低清',
      'ultra': '蓝光',
    };

    var priority = ['hs', 'ks', 'ali', 'fws', 'wy'];
    bool isLiveStream = detail.data['resolution'] == null;
    Map qulityList = isLiveStream ? detail.data : detail.data['resolution'];
    qulityList.forEach((key, value) {
      Map cdn = isLiveStream ? value['CDN_FMT'] : value['cdn'];
      List<String> lines = [];
      cdn.forEach((line, lineValue) {
        if (priority.contains(line)) {
          if (isLiveStream) {
            lines.add('${detail.link!}&$lineValue');
          } else {
            lines.add(lineValue.toString());
          }
        }
      });
      var qualityItem = LivePlayQuality(quality: reflect[key]!, sort: value['vbr'], data: lines);
      qualities.add(qualityItem);
    });
    qualities.sort((a, b) => b.sort.compareTo(a.sort));

    return Future.value(qualities);
  }

  @override
  Future<List<String>> getPlayUrls({required LiveRoom detail, required LivePlayQuality quality}) async {
    return Future.value(quality.data as List<String>);
  }

  @override
  Future<List<LiveRoom>> getRecommendRooms({int page = 1, int pageSize = 30}) async {
    try {
      var result = await HttpClient.instance.getJson(
        "https://cc.163.com/api/category/live/",
        queryParameters: {"format": "json", "start": (page - 1) * 20, "size": 20},
      );

      var items = <LiveRoom>[];
      for (var item in result["lives"]) {
        var roomItem = LiveRoom(
          roomId: item["cuteid"].toString(),
          title: item["title"].toString(),
          cover: item["cover"].toString(),
          nick: item["nickname"].toString(),
          watching: item["vision_visitor"].toString(),
          avatar: item["purl"],
          area: item["game_name"] ?? '',
          liveStatus: LiveStatus.live,
          status: true,
          platform: Sites.ccSite,
        );
        items.add(roomItem);
      }
      return items;
    } catch (e) {
      throw Exception(e.toString());
    }
  }

  @override
  Future<LiveRoom> getRoomDetail({required String platform, required String roomId}) async {
    try {
      var url = "https://api.cc.163.com/v1/activitylives/anchor/lives";
      var result = await HttpClient.instance.getJson(
        url,
        queryParameters: {'anchor_ccid': roomId},
        header: {"user-agent": kUserAgent},
      );
      var channelId = result['data'][roomId]['channel_id'];
      String urlToGetReal = "https://cc.163.com/live/channel/?channelids=$channelId";
      var resultReal = await HttpClient.instance.getJson(urlToGetReal, queryParameters: {'anchor_ccid': roomId});
      var roomInfo = resultReal["data"][0];
      return LiveRoom(
        cover: roomInfo["cover"],
        watching: roomInfo["follower_num"].toString(),
        roomId: roomInfo["ccid"].toString(),
        area: roomInfo["gamename"],
        title: roomInfo["title"],
        nick: roomInfo["nickname"].toString(),
        avatar: roomInfo["purl"].toString(),
        introduction: roomInfo["personal_label"],
        notice: roomInfo["personal_label"],
        status: roomInfo["status"] == 1,
        liveStatus: roomInfo["status"] == 1 ? LiveStatus.live : LiveStatus.offline,
        platform: Sites.ccSite,
        link: roomInfo['m3u8'],
        userId: roomInfo['cid'].toString(),
        data: roomInfo["quickplay"] ?? roomInfo["stream_list"],
      );
    } catch (e) {
      LiveRoom liveRoom =
          SettingsService.to.fav.favoriteRooms.v.firstWhereOrNull(
            (r) => r.roomId == roomId && r.platform == platform,
          ) ??
          LiveRoom(roomId: roomId, platform: platform);

      liveRoom.liveStatus = LiveStatus.offline;
      liveRoom.status = false;
      return liveRoom;
    }
  }

  @override
  Future<List<LiveRoom>> searchRooms(String keyword, {int page = 1, int pageSize = 30}) async {
    var result = await HttpClient.instance.getJson(
      "https://cc.163.com/search/anchor",
      queryParameters: {"query": keyword, "size": 20, "page": page},
    );
    var items = <LiveRoom>[];
    var queryList = result["webcc_anchor"]["result"] ?? [];
    for (var item in queryList) {
      var roomItem = LiveRoom(
        roomId: item["cuteid"].toString(),
        title: item["title"],
        cover: item["portrait"],
        nick: item["nickname"].toString(),
        area: item["game_name"] ?? '',
        status: item['status'] == 1,
        liveStatus: item['status'] != null && item['status'] == 1 ? LiveStatus.live : LiveStatus.offline,
        avatar: item["portrait"].toString(),
        watching: item["follower_num"].toString(),
        platform: Sites.ccSite,
      );
      items.add(roomItem);
    }
    return items;
  }

  @override
  Future<List<LiveAnchorItem>> searchAnchors(String keyword, {int page = 1, int pageSize = 30}) async {
    var resultText = await HttpClient.instance.getJson(
      "https://search.cdn.huya.com/",
      queryParameters: {
        "m": "Search",
        "do": "getSearchContent",
        "q": keyword,
        "uid": 0,
        "v": 1,
        "typ": -5,
        "livestate": 0,
        "rows": pageSize,
        "start": (page - 1) * pageSize,
      },
    );
    var result = json.decode(resultText);
    var items = <LiveAnchorItem>[];
    for (var item in result["response"]["1"]["docs"]) {
      var anchorItem = LiveAnchorItem(
        roomId: item["room_id"].toString(),
        avatar: item["game_avatarUrl180"].toString(),
        userName: item["game_nick"].toString(),
        liveStatus: item["gameLiveOn"],
      );
      items.add(anchorItem);
    }
    return items;
  }

  @override
  Future<bool> getLiveStatus({required String platform, required String roomId}) async {
    return Future.value(true);
  }

  @override
  Future<List<LiveSuperChatMessage>> getSuperChatMessage({required String roomId}) {
    //尚不支持
    return Future.value([]);
  }
}
