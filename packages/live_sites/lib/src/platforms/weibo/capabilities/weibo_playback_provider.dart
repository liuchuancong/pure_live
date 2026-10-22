import 'package:fpdart/fpdart.dart';
import 'package:live_sites/src/capabilities/live_playback_provider.dart';
import 'package:live_sites/src/core/live_site_error.dart';
import 'package:live_sites/src/models/play/live_play_line/live_play_line.dart';
import 'package:live_sites/src/models/play/live_play_quality/live_play_quality.dart';
import 'package:live_sites/src/platforms/weibo/parsers/weibo_failure.dart';
import 'package:live_sites/src/platforms/weibo/weibo_manifest.dart';
import 'package:live_sites/src/platforms/weibo/weibo_site.dart';

// Platform-internal code: constructor-name and doc verbosity rules that
// govern the public surface are relaxed here.
// ignore_for_file: unnecessary_type_name_in_constructor

/// Weibo's playback: one quality — 原始流 for a live broadcast, 原画 for a
/// replay's recording — and the lines behind it.
///
/// The media URLs carry no signature and no expiry: the lines need no lease,
/// and are handed out with no headers (the CDN answers the FLV and the replay
/// VOD without any; the player sends its own defaults). A broadcast that
/// ended, was never on, is restricted, or switched off is refused with its
/// reason as a content-unavailable left, never an empty list; a live playback
/// re-reads the detail each call.
final class WeiboPlaybackProvider implements LivePlaybackProvider {
  /// Serves [site].
  WeiboPlaybackProvider({required this.site});

  /// The site this capability serves.
  final WeiboSite site;

  @override
  Future<Either<LiveSiteError, List<LivePlayQuality>>> getQualities({required String roomId}) async {
    try {
      return right(await site.qualitiesOf(roomId));
    } on WeiboFailure catch (failure) {
      return left(failure.toLiveSiteError(weiboSiteId));
    } on Object catch (error) {
      return left(LiveSiteError.unexpected(siteId: weiboSiteId, message: '$error', cause: error));
    }
  }

  @override
  Future<Either<LiveSiteError, List<LivePlayLine>>> getLines({required String roomId, LivePlayQuality? quality}) async {
    try {
      return right(await site.linesOf(roomId, quality: quality));
    } on WeiboFailure catch (failure) {
      return left(failure.toLiveSiteError(weiboSiteId));
    } on Object catch (error) {
      return left(LiveSiteError.unexpected(siteId: weiboSiteId, message: '$error', cause: error));
    }
  }
}
