import 'package:pure_live/core/models/live_room.dart';

/// 直播间在站点的官方地址：网页地址，以及可选的客户端 scheme。
///
/// 每次用户动作解析一次；绝不把相对地址或空串交给系统。
class RoomExternalTarget {
  const RoomExternalTarget({required this.web, this.native});

  final String web;
  final String? native;
}

/// 站点自己的"官方房间地址"解析。
///
/// 构造规则属于站点自己（域名、分享参数、客户端 scheme、各站点的 id 校验），
/// 因此由站点实现；通用代码只问能力，不再维护 `case Sites.xSite:` 分支。
abstract interface class LiveSiteExternalRoomResolver {
  RoomExternalTarget? externalRoomTarget(LiveRoom liveroom);
}

/// 房间 id 的通用清洗：只接受能安全拼进 URL 路径的标识。
String? sanitizedExternalRoomId(String? value) {
  final id = value?.trim();
  if (id == null || id.isEmpty || id == '.' || id == '..' || RegExp(r'[\s\x00-\x1f/\\?#%]').hasMatch(id)) {
    return null;
  }
  return id;
}

/// 用站点的链接构造器建房；构造失败（如 FormatException）时返回 null。
RoomExternalTarget? officialExternalRoom(String Function() build) {
  try {
    return RoomExternalTarget(web: build());
  } on FormatException {
    return null;
  }
}
