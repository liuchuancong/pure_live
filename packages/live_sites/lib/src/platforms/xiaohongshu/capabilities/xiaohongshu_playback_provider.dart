import 'package:fpdart/fpdart.dart';
import 'package:live_sites/src/capabilities/live_playback_provider.dart';
import 'package:live_sites/src/core/live_site_error.dart';
import 'package:live_sites/src/models/play/live_play_line/live_play_line.dart';
import 'package:live_sites/src/models/play/live_play_quality/live_play_quality.dart';
import 'package:live_sites/src/platforms/xiaohongshu/parsers/xiaohongshu_failure.dart';
import 'package:live_sites/src/platforms/xiaohongshu/xiaohongshu_site.dart';

// Platform-internal code: constructor-name and doc verbosity rules that
// govern the public surface are relaxed here.
// ignore_for_file: unnecessary_type_name_in_constructor

/// Xiaohongshu's playback: one quality per `quality_type`, its H.264 and
/// H.265 addresses as lines, from the room's share page (the one its entry
/// brought, else a fresh read — the addresses are checked when they are
/// played, as 3.x checked them).
///
/// The addresses are plain CDN links without a signature, so a line carries
/// no lease. An ended room, a paid one, one for the host's group chat or
/// family and one without a pull address are errors that name the reason,
/// never an empty list; a room fenced to a region says so.
final class XiaohongshuPlaybackProvider implements LivePlaybackProvider {
  /// Serves [site].
  XiaohongshuPlaybackProvider({required this.site});

  /// The site this capability serves.
  final XiaohongshuSite site;

  @override
  Future<Either<LiveSiteError, List<LivePlayQuality>>> getQualities({required String roomId}) async {
    try {
      return right(await site.qualitiesOf(roomId));
    } on XiaohongshuFailure catch (failure) {
      return left(failure.toLiveSiteError('xiaohongshu'));
    } on Object catch (error) {
      return left(LiveSiteError.unexpected(siteId: 'xiaohongshu', message: '$error', cause: error));
    }
  }

  @override
  Future<Either<LiveSiteError, List<LivePlayLine>>> getLines({required String roomId, LivePlayQuality? quality}) async {
    try {
      return right(await site.linesOf(roomId, quality: quality));
    } on XiaohongshuFailure catch (failure) {
      return left(failure.toLiveSiteError('xiaohongshu'));
    } on Object catch (error) {
      return left(LiveSiteError.unexpected(siteId: 'xiaohongshu', message: '$error', cause: error));
    }
  }
}
