import 'package:fpdart/fpdart.dart';
import 'package:live_sites/src/capabilities/live_status_check.dart';
import 'package:live_sites/src/core/live_site_error.dart';
import 'package:live_sites/src/models/room/live_room/live_room.dart';
import 'package:live_sites/src/platforms/inke/inke_manifest.dart';
import 'package:live_sites/src/platforms/inke/inke_site.dart';
import 'package:live_sites/src/platforms/inke/parsers/inke_failure.dart';

// Platform-internal code: constructor-name and doc verbosity rules that
// govern the public surface are relaxed here.
// ignore_for_file: unnecessary_type_name_in_constructor

/// Inke's one-bit status ask: the website's share page alone, one request —
/// lighter than the follow refresh, which also asks the app for a live
/// room's broadcast (its audience and title), none of which the bit needs.
final class InkeStatusCheck implements LiveStatusCheck {
  /// Serves [site].
  InkeStatusCheck({required this.site});

  /// The site this capability serves.
  final InkeSite site;

  @override
  Future<Either<LiveSiteError, bool>> getLiveStatus({required LiveRoom room}) async {
    try {
      return right(await site.liveStatus(room.ref.roomId));
    } on InkeFailure catch (failure) {
      return left(failure.toLiveSiteError(inkeSiteId));
    } on Object catch (error) {
      return left(LiveSiteError.unexpected(siteId: inkeSiteId, message: '$error', cause: error));
    }
  }
}
