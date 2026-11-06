import 'package:fpdart/fpdart.dart';
import 'package:live_sites/src/capabilities/live_danmaku_provider.dart';
import 'package:live_sites/src/core/live_site_error.dart';
import 'package:live_sites/src/models/room/live_room/live_room.dart';
import 'package:live_sites/src/platforms/xiaohongshu/api/xiaohongshu_endpoints.dart';
import 'package:live_sites/src/platforms/xiaohongshu/danmaku/xiaohongshu_danmaku_session.dart';
import 'package:live_sites/src/platforms/xiaohongshu/parsers/xiaohongshu_failure.dart';
import 'package:live_sites/src/platforms/xiaohongshu/xiaohongshu_guest.dart';
import 'package:live_sites/src/platforms/xiaohongshu/xiaohongshu_manifest.dart';
import 'package:live_sites/src/platforms/xiaohongshu/xiaohongshu_site.dart';

// Platform-internal code: constructor-name and doc verbosity rules that
// govern the public surface are relaxed here.
// ignore_for_file: unnecessary_type_name_in_constructor

/// Creates read-only chat sessions for Xiaohongshu broadcasts.
///
/// The session subscribes by the broadcast's room id, which room entry
/// carries on the danmaku handle only where a visitor bootstrap was injected
/// — so a session is built from a fresh detail. A shell without the guest,
/// or a room read before one existed, has no handle and is reported
/// content-unavailable rather than joined empty; the credentials themselves
/// are obtained only when the session connects.
final class XiaohongshuDanmakuProvider implements LiveDanmakuProvider {
  /// The provider over [site] (which resolves the room and owns the guest).
  XiaohongshuDanmakuProvider({required this.site});

  /// The site this capability serves.
  final XiaohongshuSite site;

  @override
  Future<Either<LiveSiteError, LiveDanmakuSession>> createSession({required LiveRoom room}) async {
    if (site.guest == null) {
      return left(
        const LiveSiteError.contentUnavailable(siteId: xiaohongshuSiteId, message: 'no visitor chat in this shell'),
      );
    }
    final XiaohongshuDanmakuArgs args;
    try {
      final handle = (await site.detail(room.roomId)).runtime.danmakuHandle;
      if (handle is! XiaohongshuDanmakuArgs || !XiaohongshuEndpoints.isRoomId(handle.roomId)) {
        return left(
          LiveSiteError.contentUnavailable(siteId: xiaohongshuSiteId, message: 'room ${room.roomId} opens no chat'),
        );
      }
      args = handle;
    } on XiaohongshuFailure catch (failure) {
      return left(failure.toLiveSiteError(xiaohongshuSiteId));
    } on Object catch (error) {
      return left(LiveSiteError.unexpected(siteId: xiaohongshuSiteId, message: '$error', cause: error));
    }
    final session = XiaohongshuDanmakuSession(args: args, guest: site.guest!);
    final failure = await session.connect();
    if (failure != null) {
      await session.dispose();
      return left(failure);
    }
    return right(session);
  }
}
