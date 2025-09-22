import 'dart:convert';

import 'package:pure_live/common/models/live_area.dart';
import 'package:pure_live/common/models/live_room.dart';
import 'package:pure_live/core/common/core_log.dart';
import 'package:pure_live/core/common/http_client.dart';
import 'package:pure_live/core/interface/live_danmaku.dart';
import 'package:pure_live/core/interface/live_site.dart';
import 'package:pure_live/core/site/cc/cc_danmaku.dart';
import 'package:pure_live/core/sites.dart';
import 'package:pure_live/model/live_anchor_item.dart';
import 'package:pure_live/model/live_category.dart';
import 'package:pure_live/model/live_category_result.dart';
import 'package:pure_live/model/live_play_quality.dart';
import 'package:pure_live/model/live_play_quality_play_url_info.dart';
import 'package:pure_live/model/live_search_result.dart';
import 'package:pure_live/plugins/extension/string_extension.dart';

import 'cc_site_mixin.dart';

class CCSite extends LiveSite with CCSiteMixin {
  @override
  String get id => "cc";

  @override
  String get name => "网易CC直播";

  @override
  LiveDanmaku getDanmaku() => CCDanmaku();

  @override
  Future<List<LiveCategory>> getCategores(int page, int pageSize) async {
    List<LiveCategory> categories = [
      LiveCategory(id: "1", name: "网游", children: []),
      LiveCategory(id: "2", name: "单机", children: []),
      LiveCategory(id: "4", name: "网游竞技", children: []),
      LiveCategory(id: "5", name: "娱乐", children: []),
    ];

    List<Future> futures = [];
    for (var item in categories) {
      futures.add(Future(() async {
        var items = await getSubCategores(item);
        item.children.addAll(items);
      }));
    }
    await Future.wait(futures);
    return categories;
  }

  final String kUserAgent =
      "Mozilla/5.0 (Linux; Android 11; Pixel 5) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/90.0.4430.91 Mobile Safari/537.36 Edg/117.0.0.0";

  Future<List<LiveArea>> getSubCategores(LiveCategory liveCategory) async {
    var result = await HttpClient.instance.getJson("https://api.cc.163.com/v1/wapcc/gamecategory", queryParameters: {
      "catetype": liveCategory.id,
    }, header: {
      "user-agent": kUserAgent,
    });

    List<LiveArea> subs = [];
    for (var item in result["data"]["category_info"]["game_list"]) {
      var gid = item["gametype"].toString();
      var subCategory = LiveArea(
        areaId: gid,
        areaName: item["name"] ?? '',
        areaType: liveCategory.id,
        platform: Sites.ccSite,
        areaPic: item["cover"],
        typeName: liveCategory.name,
      );
      subs.add(subCategory);
    }

    return subs;
  }

  @override
  Future<LiveCategoryResult> getCategoryRooms(LiveArea category, {int page = 1}) async {
    var result = await HttpClient.instance.getJson(
      "https://cc.163.com/api/category/${category.areaId}",
      queryParameters: {"format": "json", "tag_id": "0", "start": (page - 1) * 20, "size": 20},
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
    var hasMore = result["lives"].length >= 20;
    return LiveCategoryResult(hasMore: hasMore, items: items);
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

    List<LivePlayQualityPlayUrlInfo> playUrlList = [];

    var priority = ['hs', 'ks', 'ali', 'fws', 'wy'];
    bool isLiveStream = detail.data['resolution'] == null;
    Map qulityList = isLiveStream ? detail.data : detail.data['resolution'];
    qulityList.forEach((key, value) {
      Map cdn = isLiveStream ? value['CDN_FMT'] : value['cdn'];
      List<String> lines = [];
      cdn.forEach((line, lineValue) {
        if (priority.contains(line) || true) {
          var url = lineValue.toString();
          if (isLiveStream) {
            url = '${detail.link!}&$lineValue';
          } else {
            lines.add(lineValue.toString());
          }
          lines.add(url);
          playUrlList.add(LivePlayQualityPlayUrlInfo(playUrl: url, info: "($line)"));
        }
      });
      var qualityItem = LivePlayQuality(
        quality: reflect[key]!,
        sort: value['vbr'],
        data: lines,
        bitRate: value['vbr'] ?? 0,
      );

      qualityItem.playUrlList = playUrlList;

      qualities.add(qualityItem);
    });
    qualities.sort((a, b) => b.sort.compareTo(a.sort));

    return Future.value(qualities);
  }

  @override
  Future<List<LivePlayQualityPlayUrlInfo>> getPlayUrls({required LiveRoom detail, required LivePlayQuality quality}) async {
    return quality.playUrlList;
  }

  @override
  Future<LiveCategoryResult> getRecommendRooms({int page = 1, required String nick}) async {
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
    var hasMore = result["lives"].length >= 20;
    return LiveCategoryResult(hasMore: hasMore, items: items);
  }

  @override
  Future<LiveRoom> getRoomDetail({required LiveRoom detail}) async {
    var roomId = detail.roomId ?? "";
    try {
      // var url = "https://api.cc.163.com/v1/activitylives/anchor/lives";
      // var result = await HttpClient.instance.getJson(url, queryParameters: {
      //   'anchor_ccid': roomId
      // }, header: {
      //   "user-agent": kUserAgent,
      // });
      // var channelId = result['data'][roomId]['channel_id'];
      // String urlToGetReal = "https://cc.163.com/live/channel/?channelids=$channelId";
      // var resultReal = await HttpClient.instance.getJson(urlToGetReal, queryParameters: {'anchor_ccid': roomId});
      // var roomInfo = resultReal["data"][0];
      String ccUrl = "https://cc.163.com/live/userlive/?ccids=$roomId";
      Map ccResult = await HttpClient.instance.getJson(ccUrl, queryParameters: {});
      CoreLog.d("ccResult: ${jsonEncode(ccResult)}");
      var values = ccResult.values.toList();
      var roomInfo = values[0];
      var gameType = roomInfo["gametype"];
      var channelId = roomInfo["channelid"];
      var cclId = roomInfo["ccid"];
      CCDanmakuArgs args = CCDanmakuArgs(roomId: cclId, channelId: channelId,gameType: gameType);
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
        danmakuData: args,
      );
    } catch (e) {
      CoreLog.error(e);
      return getLiveRoomWithError(detail);
    }
  }

  @override
  Future<LiveSearchRoomResult> searchRooms(String keyword, {int page = 1}) async {
    var result = await HttpClient.instance.getJson(
      "https://cc.163.com/search/anchor",
      queryParameters: {
        "query": keyword,
        "size": 20,
        "page": page,
      },
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
    var hasMore = queryList.length > 0;
    return LiveSearchRoomResult(hasMore: hasMore, items: items);
  }

  @override
  Future<LiveSearchAnchorResult> searchAnchors(String keyword, {int page = 1}) async {
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
        "rows": 20,
        "start": (page - 1) * 20,
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
    var hasMore = result["response"]["1"]["numFound"] > (page * 20);
    return LiveSearchAnchorResult(hasMore: hasMore, items: items);
  }

  @override
  bool isSupportBatchUpdateLiveStatus() {
    return true;
  }

  @override
  Future<List<LiveRoom>> getLiveRoomDetailList(
      {required List<LiveRoom> list})  async {
    if(list.isEmpty) {
      return List.empty();
    }
    try {
      Map<String, LiveRoom> map = {};
      var idList = <String>[];
      for(var room in list) {
        var roomId = room.roomId;
        if(roomId.isNullOrEmpty) {
          continue;
        }
        idList.add(roomId!);
        map[roomId] = room;
      }
      if(idList.isEmpty) {
        return List.empty();
      }
      var roomIds = idList.join(",");
      String ccUrl = "https://cc.163.com/live/userlive/?ccids=$roomIds";
      Map ccResult = await HttpClient.instance.getJson(ccUrl, queryParameters: {});
      var values = ccResult.values.toList();
      var keys = ccResult.keys.toList();
      // CoreLog.d(jsonEncode(values));

      var rsList = <LiveRoom>[];
      for(var roomInfo in values){
        var tmp = LiveRoom(
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
        rsList.add(tmp);
      }

      // 没有数据的 room
      idList.toSet().difference(keys.toSet())
      .map( (rid) {
        var liveRoom = map[rid];
        if(liveRoom != null) {
          liveRoom.liveStatus = LiveStatus.offline;
          liveRoom.status = false;
          rsList.add(liveRoom);
        }
      });
      // CoreLog.d(jsonEncode(rsList));
      return rsList;
    } catch (e)  {
      CoreLog.error(e);
      for(var liveRoom in list){
        liveRoom.liveStatus = LiveStatus.offline;
        liveRoom.status = false;
      }
      return list;
    }
  }



}
