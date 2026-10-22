import 'package:fpdart/fpdart.dart';
import 'package:live_sites/src/capabilities/live_playback_provider.dart';
import 'package:live_sites/src/core/live_site_error.dart';
import 'package:live_sites/src/models/play/live_play_line/live_play_line.dart';
import 'package:live_sites/src/models/play/live_play_quality/live_play_quality.dart';
import 'package:live_sites/src/platforms/baidulive/baidulive_manifest.dart';
import 'package:live_sites/src/platforms/baidulive/baidulive_site.dart';
import 'package:live_sites/src/platforms/baidulive/parsers/baidulive_failure.dart';

// Platform-internal code: constructor-name and doc verbosity rules that
// govern the public surface are relaxed here.
// ignore_for_file: unnecessary_type_name_in_constructor

/// Baidu Live's playback: the qualities (原画 and the heights of a live
/// broadcast, the recording of an ended one) and the lines behind them, from
/// the room command its room entry brought — or a new one when none is kept.
///
/// The addresses carry no signature or expiry, so no line holds a lease; the
/// media headers (a `live.baidu.com` Referer, without which the FLV hosts
/// answer 403) travel on every line. The lines the entry's answer gave are
/// handed out once: a second request — a recovery — asks a new room command
/// and never reuses them, as 3.x did. A room that cannot be played names why
/// (not live, restricted, ended without a recording, live without a stream, a
/// quality the room no longer offers); none of them is an empty list.
final class BaidulivePlaybackProvider implements LivePlaybackProvider {
  /// Serves [site].
  BaidulivePlaybackProvider({required this.site});

  /// The site this capability serves.
  final BaiduliveSite site;

  @override
  Future<Either<LiveSiteError, List<LivePlayQuality>>> getQualities({required String roomId}) async {
    try {
      return right(await site.qualitiesOf(roomId));
    } on BaiduliveFailure catch (failure) {
      return left(failure.toLiveSiteError(baiduliveSiteId));
    } on Object catch (error) {
      return left(LiveSiteError.unexpected(siteId: baiduliveSiteId, message: '$error', cause: error));
    }
  }

  @override
  Future<Either<LiveSiteError, List<LivePlayLine>>> getLines({required String roomId, LivePlayQuality? quality}) async {
    try {
      return right(await site.linesOf(roomId, quality: quality));
    } on BaiduliveFailure catch (failure) {
      return left(failure.toLiveSiteError(baiduliveSiteId));
    } on Object catch (error) {
      return left(LiveSiteError.unexpected(siteId: baiduliveSiteId, message: '$error', cause: error));
    }
  }
}
