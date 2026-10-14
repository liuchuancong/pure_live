import 'package:fpdart/fpdart.dart';
import 'package:live_sites/src/capabilities/live_playback_provider.dart';
import 'package:live_sites/src/core/live_site_error.dart';
import 'package:live_sites/src/models/play/live_play_line/live_play_line.dart';
import 'package:live_sites/src/models/play/live_play_quality/live_play_quality.dart';
import 'package:live_sites/src/platforms/acfun/acfun_site.dart';
import 'package:live_sites/src/platforms/acfun/parsers/acfun_failure.dart';
import 'package:live_sites/src/platforms/acfun/parsers/acfun_play_parser.dart';

// Platform-internal code: constructor-name and doc verbosity rules that
// govern the public surface are relaxed here.
// ignore_for_file: unnecessary_type_name_in_constructor

/// AcFun's playback: `startPlay` hands back the signed URLs of every quality,
/// so there is nothing to sign here and nothing to guess about their expiry.
///
/// The room detail carries the broadcast (its stream handle), so the qualities
/// and the lines come off one fresh detail without a second play request. A
/// room the platform called offline, or a paid show this visitor holds no
/// ticket for, is content-unavailable rather than an empty list. A quality the
/// answer does not offer is never swapped for another one: the URLs of a
/// different quality are not what the viewer chose.
final class AcfunPlaybackProvider implements LivePlaybackProvider {
  /// Serves [site].
  AcfunPlaybackProvider({required this.site});

  /// The site this capability serves.
  final AcfunSite site;

  @override
  Future<Either<LiveSiteError, List<LivePlayQuality>>> getQualities({required String roomId}) async {
    try {
      return right(AcfunPlayParser.toModel(await site.qualities(await site.detail(roomId))));
    } on AcfunFailure catch (failure) {
      return left(failure.toLiveSiteError('acfun'));
    } on Object catch (error) {
      return left(LiveSiteError.unexpected(siteId: 'acfun', message: '$error', cause: error));
    }
  }

  @override
  Future<Either<LiveSiteError, List<LivePlayLine>>> getLines({required String roomId, LivePlayQuality? quality}) async {
    try {
      final data = await site.broadcast(await site.detail(roomId));
      final id = quality?.qualityId ?? data.qualities.first.id;
      final lines = AcfunPlayParser.lines(data.qualities, qualityId: id, issuedAt: data.issuedAt);
      if (lines.isEmpty) {
        throw AcfunFailure(AcfunFailureKind.streamUnavailable, 'startPlay: quality $id has no URL');
      }
      return right(lines);
    } on AcfunFailure catch (failure) {
      return left(failure.toLiveSiteError('acfun'));
    } on Object catch (error) {
      return left(LiveSiteError.unexpected(siteId: 'acfun', message: '$error', cause: error));
    }
  }
}
