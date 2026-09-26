import 'dart:async';

import 'package:pure_live/common/index.dart';
import 'package:pure_live/common/utils/live_url_tool.dart';
import 'package:pure_live/routes/app_navigation.dart';

typedef SharedLiveLinkParser = Future<List<String>> Function(String text);
typedef SharedLiveRoomOpener = Future<void> Function(LiveRoom room);

/// Opens a live room from text shared by a platform app, using the same
/// resolution as the toolbox's "jump to room" (short links included).
class SharedLiveLinkOpener {
  SharedLiveLinkOpener({
    SharedLiveLinkParser? parse,
    SharedLiveRoomOpener? open,
    Future<void> Function()? waitForNavigator,
    void Function(String)? notify,
  }) : _parse = parse ?? LiveUrlTool.parseLiveUrl,
       _waitForNavigator = waitForNavigator ?? (() async {}),
       _open = open ?? ((room) => AppNavigator.toLiveRoomDetail(liveRoom: room)),
       _notify = notify ?? ((key) => ToastUtil.show(i18n(key)));

  final SharedLiveLinkParser _parse;
  final SharedLiveRoomOpener _open;
  final Future<void> Function() _waitForNavigator;
  final void Function(String) _notify;

  static bool containsLiveLink(String text) => LiveUrlTool.containsSupportedLink(text) || Sites.isRetiredLink(text);

  Future<bool> open(String text) async {
    List<String> result;
    try {
      result = await _parse(text);
    } catch (_) {
      result = const [];
    }
    if (result.length != 2 || result.first.trim().isEmpty || !Sites.isSupported(result[1])) {
      _notify(Sites.isRetiredLink(text) ? 'platform_retired' : 'toolbox_parse_failed');
      return false;
    }
    final room = LiveRoom(
      roomId: result.first,
      platform: result[1],
      title: '',
      cover: '',
      nick: '',
      watching: '',
      avatar: '',
      area: '',
      liveStatus: LiveStatus.live,
      status: true,
      data: '',
      danmakuData: '',
    );
    try {
      await _waitForNavigator();
    } catch (_) {
      return false;
    }
    // The room route completes only when it is closed; the share queue must
    // not wait for that.
    unawaited(_open(room).catchError((Object _) {}));
    return true;
  }
}
