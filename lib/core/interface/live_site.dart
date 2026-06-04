import 'package:pure_live/model/live_category.dart';
import 'package:pure_live/model/live_anchor_item.dart';
import 'package:pure_live/common/models/live_area.dart';
import 'package:pure_live/common/models/live_room.dart';
import 'package:pure_live/model/live_play_quality.dart';
import 'package:pure_live/common/models/live_message.dart';
import 'package:pure_live/core/interface/live_danmaku.dart';

class LiveSite {
  String id = "";
  String name = "";

  LiveDanmaku getDanmaku() {
    throw UnimplementedError();
  }

  Future<List<LiveCategory>> getCategores(int page, int pageSize) async {
    return Future.value(<LiveCategory>[]);
  }

  Future<List<LiveRoom>> searchRooms(String keyword, {int page = 1, int pageSize = 30}) async {
    return Future.value(<LiveRoom>[]);
  }

  Future<List<LiveAnchorItem>> searchAnchors(String keyword, {int page = 1, int pageSize = 30}) async {
    return Future.value(<LiveAnchorItem>[]);
  }

  Future<List<LiveRoom>> getCategoryRooms(LiveArea category, {int page = 1, int pageSize = 30}) async {
    return Future.value(<LiveRoom>[]);
  }

  Future<List<LiveRoom>> getRecommendRooms({int page = 1, int pageSize = 30}) async {
    return Future.value(<LiveRoom>[]);
  }

  Future<LiveRoom> getRoomDetail({required String roomId, required String platform}) async {
    return Future.value(
      LiveRoom(
        cover: '',
        watching: '0',
        roomId: '',
        status: false,
        platform: platform,
        liveStatus: LiveStatus.offline,
        title: '',
        link: '',
        avatar: '',
        nick: '',
        isRecord: false,
      ),
    );
  }

  Future<List<LivePlayQuality>> getPlayQualites({required LiveRoom detail}) async {
    return Future.value(<LivePlayQuality>[]);
  }

  Future<List<String>> getPlayUrls({required LiveRoom detail, required LivePlayQuality quality}) async {
    return Future.value(<String>[]);
  }

  Future<bool> getLiveStatus({required String platform, required String roomId}) async {
    return Future.value(false);
  }

  Future<List<LiveSuperChatMessage>> getSuperChatMessage({required String roomId}) async {
    return Future.value([]);
  }
}
