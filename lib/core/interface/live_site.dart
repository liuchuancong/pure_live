import 'package:pure_live/model/live_category.dart';
import 'package:pure_live/model/live_anchor_item.dart';
import 'package:pure_live/common/models/live_area.dart';
import 'package:pure_live/common/models/live_room.dart';
import 'package:pure_live/model/live_play_quality.dart';
import 'package:pure_live/model/live_search_result.dart';
import 'package:pure_live/common/models/live_message.dart';
import 'package:pure_live/model/live_category_result.dart';
import 'package:pure_live/core/interface/live_danmaku.dart';

class LiveSite {
  /// 站点唯一ID
  String id = "";

  /// 站点名称
  String name = "";

  /// 站点名称
  LiveDanmaku getDanmaku() {
    throw UnimplementedError();
  }

  /// 读取网站的分类
  Future<List<LiveCategory>> getCategores(int page, int pageSize) {
    return Future.value(<LiveCategory>[]);
  }

  /// 搜索直播间
  Future<LiveSearchRoomResult> searchRooms(String keyword, {int page = 1}) {
    return Future.value(LiveSearchRoomResult(hasMore: false, items: <LiveRoom>[]));
  }

  /// 搜索直播间
  Future<LiveSearchAnchorResult> searchAnchors(String keyword, {int page = 1}) {
    return Future.value(LiveSearchAnchorResult(hasMore: false, items: <LiveAnchorItem>[]));
  }

  /// 读取类目下房间
  Future<LiveCategoryResult> getCategoryRooms(LiveArea category, {int page = 1}) {
    return Future.value(LiveCategoryResult(hasMore: false, items: <LiveRoom>[]));
  }

  /// 读取推荐的房间
  Future<LiveCategoryResult> getRecommendRooms({int page = 1, required String nick}) {
    return Future.value(LiveCategoryResult(hasMore: false, items: <LiveRoom>[]));
  }

  /// 读取房间详情
  Future<LiveRoom> getRoomDetail({required String roomId, required String platform}) {
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

  /// 读取房间清晰度
  Future<List<LivePlayQuality>> getPlayQualites({required LiveRoom detail}) {
    return Future.value(<LivePlayQuality>[]);
  }

  /// 读取播放链接
  Future<List<String>> getPlayUrls({required LiveRoom detail, required LivePlayQuality quality}) {
    return Future.value(<String>[]);
  }

  /// 查询直播状态
  Future<bool> getLiveStatus({required String platform, required String roomId}) {
    return Future.value(false);
  }

  /// 读取指定房间的SC
  Future<List<LiveSuperChatMessage>> getSuperChatMessage({required String roomId}) {
    return Future.value([]);
  }
}
