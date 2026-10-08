import 'package:pure_live/shared/platforms/live_quality_discovery.dart';
import 'package:flutter/services.dart';
import 'package:pure_live/core/models/live_room.dart';
import 'package:pure_live/shared/platforms/live_site.dart';
import 'package:pure_live/domains/live/data/platforms/sites.dart';
import 'package:pure_live/core/models/live_play_quality.dart';
import 'package:pure_live/core/utils/action_scope.dart';

class LiveDirectLinkFlow {
  LiveDirectLinkFlow({LiveSite Function(String)? siteFor, Future<void> Function(String)? copyText})
    : _siteFor = siteFor ?? ((platform) => Sites.of(platform).liveSite),
      _copyText = copyText ?? ((text) => Clipboard.setData(ClipboardData(text: text)));

  final LiveSite Function(String) _siteFor;
  final Future<void> Function(String) _copyText;

  Future<void> run({
    required LiveRoom liveroom,
    required ActionScope scope,
    required Future<LivePlayQuality?> Function(List<LivePlayQuality>) chooseQuality,
    required Future<String?> Function(List<String>) chooseLine,
    required void Function(String) notify,
    Future<void> Function(String)? useUrl,
  }) async {
    scope.checkActive();
    final platform = liveroom.normalizedPlatformId;
    final roomId = liveroom.normalizedRoomId;
    if (platform.isEmpty || roomId.isEmpty || !Sites.isSupported(platform)) {
      notify('toolbox_parse_failed');
      return;
    }
    final site = _siteFor(platform);
    final detail = await scope.wait(() => site.getRoomDetail(liveroom.normalizedIdentityCopy()));
    final qualities = site is LiveQualityDiscovery
        ? await scope.waitCancellable((cancel) => site.discoverPlayQualities(liveroom: detail, cancel: cancel))
        : await scope.wait(() => site.discoverPlayQualities(liveroom: detail, cancel: scope.cancelToken));
    if (qualities.isEmpty) {
      notify('toolbox_quality_failed');
      return;
    }
    // User choices have no timer. Only network/platform operations are timed.
    final quality = await scope.wait(() => chooseQuality(qualities), timed: false);
    if (quality == null || !qualities.contains(quality)) return;
    final resolution = await scope.wait(() => site.resolvePlayUrls(liveroom: detail, quality: quality));
    // Owned inputs are playable, but their private relay URI belongs to an
    // in-app session. Do not acquire a seat or export a native-only address.
    if (resolution.inputRecipe != null) {
      notify('toolbox_session_source');
      return;
    }
    final urls = resolution.urls;
    if (urls.isEmpty) {
      notify('toolbox_get_url_failed');
      return;
    }
    final selected = await scope.wait(() => chooseLine(urls), timed: false);
    if (selected == null || !urls.contains(selected)) return;
    if (useUrl != null) {
      await scope.wait(() => useUrl(selected), timed: false);
      return;
    }
    try {
      await scope.wait(() => _copyText(selected));
    } on ActionCancelled {
      rethrow;
    } catch (_) {
      if (scope.isActive) notify('toolbox_copy_failed');
      return;
    }
    notify('toolbox_copy_success');
  }
}
