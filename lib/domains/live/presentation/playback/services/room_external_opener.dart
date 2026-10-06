import 'package:pure_live/core/models/live_room.dart';
import 'package:pure_live/domains/live/data/platforms/sites.dart';
import 'package:pure_live/shared/platforms/live_external_room.dart';
import 'package:url_launcher/url_launcher_string.dart';

enum RoomExternalOpenResult { opened, unavailable, failed, cancelled }

class RoomExternalOpener {
  static RoomExternalTarget? resolve(String site, LiveRoom liveroom) {
    final id = site.trim().toLowerCase();
    if (id.isEmpty || !Sites.isSupported(id) || Sites.isRetired(id)) return null;
    final Object liveSite = Sites.of(id).liveSite;
    return liveSite is LiveSiteExternalRoomResolver ? liveSite.externalRoomTarget(liveroom) : null;
  }

  static Future<bool> _launch(String url) => launchUrlString(url, mode: LaunchMode.externalApplication);

  static Future<RoomExternalOpenResult> open({
    required String site,
    required LiveRoom liveroom,
    required bool android,
    RoomExternalLauncher? launch,
    bool Function()? isCurrent,
    void Function()? onBrowserFallback,
  }) async {
    bool current() => isCurrent?.call() ?? true;
    if (!current()) return RoomExternalOpenResult.cancelled;
    final target = resolve(site, liveroom);
    if (target == null) return RoomExternalOpenResult.unavailable;
    final launcher = launch ?? _launch;
    Future<bool> attempt(String url) async {
      try {
        return await launcher(url);
      } catch (_) {
        // Never log targets; they may include platform share parameters.
        return false;
      }
    }

    final native = android ? target.native : null;
    if (native != null && native != target.web) {
      final opened = await attempt(native);
      if (!current()) return RoomExternalOpenResult.cancelled;
      if (opened) return RoomExternalOpenResult.opened;
      onBrowserFallback?.call();
      if (!current()) return RoomExternalOpenResult.cancelled;
    }
    final opened = await attempt(target.web);
    if (!current()) return RoomExternalOpenResult.cancelled;
    return opened ? RoomExternalOpenResult.opened : RoomExternalOpenResult.failed;
  }
}

typedef RoomExternalLauncher = Future<bool> Function(String url);
