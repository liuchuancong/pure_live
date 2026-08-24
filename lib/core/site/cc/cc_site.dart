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
import 'package:pure_live/modules/live_play/controllers/player_controller.dart';

class CCSite implements LiveSite, LiveSiteRoomRefresher {
  @override
  String id = Sites.ccSite;

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
        final audience = parseRoomAudience(Map<String, dynamic>.from(item as Map));
        var roomItem = LiveRoom(
          roomId: item["cuteid"].toString(),
          title: item["title"].toString(),
          cover: item["cover"].toString(),
          nick: item["nickname"].toString(),
          watching: audience.popularity.isNotEmpty ? audience.popularity : audience.onlineViewers,
          popularity: audience.popularity,
          onlineViewers: audience.onlineViewers,
          audienceMetricType: audience.popularity.isNotEmpty
              ? AudienceMetricType.popularity
              : AudienceMetricType.onlineViewers,
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
    final rawData = detail.data;
    if (rawData is! Map) return Future.value(const <LivePlayQuality>[]);
    final qualities = <LivePlayQuality>[];
    var reflect = {
      'blueray': '原画',
      'original': '原画',
      'high': '高清',
      'medium': '标准',
      'standard': '标准',
      'low': '低清',
      'ultra': '蓝光',
    };

    const priority = ['hs', 'ks', 'ali', 'fws', 'wy'];
    final isLiveStream = rawData['resolution'] == null;
    final qualityData = isLiveStream ? rawData : rawData['resolution'];
    if (qualityData is! Map) return Future.value(const <LivePlayQuality>[]);
    final qulityList = qualityData;
    qulityList.forEach((key, value) {
      if (value is! Map) return;
      final cdn = isLiveStream ? value['CDN_FMT'] : value['cdn'];
      if (cdn is! Map) return;
      final preferredLines = <String>[];
      final otherLines = <String>[];
      cdn.forEach((line, lineValue) {
        final baseUrl = detail.link?.trim() ?? '';
        final url = isLiveStream && baseUrl.isNotEmpty ? '$baseUrl&$lineValue' : lineValue.toString();
        if (Uri.tryParse(url)?.hasScheme != true) return;
        final target = priority.contains(line.toString().toLowerCase()) ? preferredLines : otherLines;
        if (!target.contains(url)) target.add(url);
      });
      final lines = <String>[...preferredLines, ...otherLines];
      if (lines.isEmpty) return;
      final sort = int.tryParse(value['vbr']?.toString() ?? '') ?? 0;
      qualities.add(
        LivePlayQuality(
          quality: reflect[key] ?? key.toString(),
          id: key.toString(),
          sort: sort,
          data: List<String>.unmodifiable(lines),
        ),
      );
    });
    qualities.sort((a, b) => b.sort.compareTo(a.sort));

    return Future.value(qualities);
  }

  @override
  Future<List<String>> getPlayUrls({required LiveRoom detail, required LivePlayQuality quality}) async {
    final data = quality.data;
    if (data is! List) return const <String>[];
    return data.map((item) => item.toString().trim()).where((url) => url.isNotEmpty).toList(growable: false);
  }

  @override
  Future<List<LiveRoom>> getRecommendRooms({int page = 1, int pageSize = 30}) async {
    try {
      var result = await HttpClient.instance.getJson(
        "https://cc.163.com/api/category/live/",
        queryParameters: {"format": "json", "start": (page - 1) * pageSize, "size": pageSize},
      );

      var items = <LiveRoom>[];
      for (var item in result["lives"]) {
        final audience = parseRoomAudience(Map<String, dynamic>.from(item as Map));
        var roomItem = LiveRoom(
          roomId: item["cuteid"].toString(),
          title: item["title"].toString(),
          cover: item["cover"].toString(),
          nick: item["nickname"].toString(),
          watching: audience.popularity.isNotEmpty ? audience.popularity : audience.onlineViewers,
          popularity: audience.popularity,
          onlineViewers: audience.onlineViewers,
          audienceMetricType: audience.popularity.isNotEmpty
              ? AudienceMetricType.popularity
              : AudienceMetricType.onlineViewers,
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
      return await _loadRoomDetail(roomId);
    } catch (e) {
      if (Get.isRegistered<PlayerController>()) {
        final PlayerController playerController = Get.find<PlayerController>();
        final currentRoom = playerController.currentRoom;
        if (currentRoom?.hasIdentity(platform: platform, roomId: roomId) == true) {
          return currentRoom!.getLiveRoomWithError();
        }
      }
      return LiveRoom(roomId: roomId, platform: platform).getLiveRoomWithError();
    }
  }

  @override
  Future<LiveRoom> getRoomDetailForRefresh({required String platform, required String roomId}) {
    // Propagate transport/shape errors to the favourite verifier. Treating a
    // failed request as an authoritative offline response corrupts the card
    // state and hides the failure from the retry policy.
    return _loadRoomDetail(roomId);
  }

  Future<LiveRoom> _loadRoomDetail(String roomId) async {
    const url = "https://api.cc.163.com/v1/activitylives/anchor/lives";
    final result = await HttpClient.instance.getJson(
      url,
      queryParameters: {'anchor_ccid': roomId},
      header: {"user-agent": kUserAgent},
    );
    final channelId = result['data'][roomId]['channel_id'];
    final urlToGetReal = "https://cc.163.com/live/channel/?channelids=$channelId";
    final resultReal = await HttpClient.instance.getJson(urlToGetReal, queryParameters: {'anchor_ccid': roomId});
    final roomInfo = resultReal["data"][0];
    final audience = parseRoomAudience(Map<String, dynamic>.from(roomInfo as Map));
    final nativeMetric = audience.popularity.isNotEmpty ? audience.popularity : audience.onlineViewers;
    return LiveRoom(
      cover: roomInfo["cover"],
      watching: nativeMetric.isNotEmpty ? nativeMetric : roomInfo["follower_num"].toString(),
      popularity: audience.popularity,
      onlineViewers: audience.onlineViewers,
      audienceMetricType: audience.popularity.isNotEmpty
          ? AudienceMetricType.popularity
          : audience.onlineViewers.isNotEmpty
          ? AudienceMetricType.onlineViewers
          : AudienceMetricType.followers,
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
  }

  /// CC exposes two different audience scales in the same payload:
  /// `webcc_visitor` is the large platform heat value, while
  /// `vision_visitor`/`online_num` are the current viewers. Keeping both avoids
  /// presenting values such as 500,000 heat as 500,000 people online.
  static ({String popularity, String onlineViewers}) parseRoomAudience(Map<String, dynamic> room) {
    final popularity = _firstAudienceValue([room['webcc_visitor']]);
    final onlineViewers = _firstAudienceValue([room['vision_visitor'], room['online_num'], room['visitor']]);
    return (popularity: popularity, onlineViewers: onlineViewers);
  }

  static String _firstAudienceValue(Iterable<dynamic> values) {
    for (final value in values) {
      final text = value?.toString().trim() ?? '';
      if (text.isNotEmpty && text != 'null' && RegExp(r'[0-9]').hasMatch(text)) return text;
    }
    return '';
  }

  @override
  Future<List<LiveRoom>> searchRooms(String keyword, {int page = 1, int pageSize = 30}) async {
    final effectivePageSize = pageSize.clamp(1, 50);
    var result = await HttpClient.instance.getJson(
      "https://cc.163.com/search/anchor",
      queryParameters: {"query": keyword, "size": effectivePageSize, "page": page},
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
        followers: item["follower_num"].toString(),
        audienceMetricType: AudienceMetricType.followers,
        platform: Sites.ccSite,
      );
      items.add(roomItem);
    }
    return items;
  }

  @override
  Future<List<LiveAnchorItem>> searchAnchors(String keyword, {int page = 1, int pageSize = 30}) async {
    final rooms = await searchRooms(keyword, page: page, pageSize: pageSize);
    return rooms
        .map(
          (room) => LiveAnchorItem(
            roomId: room.roomId ?? '',
            avatar: room.avatar ?? '',
            userName: room.nick ?? '',
            liveStatus: room.liveStatus == LiveStatus.live,
          ),
        )
        .toList();
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
