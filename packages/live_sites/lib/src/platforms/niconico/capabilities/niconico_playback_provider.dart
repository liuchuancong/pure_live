import 'package:fpdart/fpdart.dart';
import 'package:live_sites/src/capabilities/live_playback_provider.dart';
import 'package:live_sites/src/core/live_site_error.dart';
import 'package:live_sites/src/models/play/live_play_line/live_play_line.dart';
import 'package:live_sites/src/models/play/live_play_quality/live_play_quality.dart';
import 'package:live_sites/src/platforms/niconico/api/niconico_endpoints.dart';
import 'package:live_sites/src/platforms/niconico/danmaku/niconico_seat_session.dart';
import 'package:live_sites/src/platforms/niconico/niconico_manifest.dart';
import 'package:live_sites/src/platforms/niconico/niconico_site.dart';
import 'package:live_sites/src/platforms/niconico/parsers/niconico_failure.dart';
import 'package:live_sites/src/platforms/niconico/parsers/niconico_play_parser.dart';

// Platform-internal code: constructor-name and doc verbosity rules that
// govern the public surface are relaxed here.
// ignore_for_file: unnecessary_type_name_in_constructor

/// Niconico's playback: a watching seat of its own grants the HLS master (and
/// the path-scoped media cookies), whose `EXT-X-STREAM-INF` variants are the
/// qualities. A line carries the master's media headers and the cookies of its
/// own path; the grant's cookie expiry is the lease (a new seat revokes it).
///
/// Qualities and each line request open a fresh seat, since a seat's grant is
/// short-lived and is never stored as permanent room metadata.
final class NiconicoPlaybackProvider implements LivePlaybackProvider {
  /// Serves [site].
  NiconicoPlaybackProvider({required this.site});

  /// The site this capability serves: the source of the seat and the transport.
  final NiconicoSite site;

  /// How long the master playlist read may take (the reference's
  /// `masterTimeout`): a delivery host that hangs must not hold the seat and
  /// the caller past the point where a retry would help.
  static const Duration masterTimeout = Duration(seconds: 5);

  @override
  Future<Either<LiveSiteError, List<LivePlayQuality>>> getQualities({required String roomId}) async {
    final NiconicoSeat seat;
    try {
      seat = await site.openSeat(roomId);
    } on NiconicoFailure catch (failure) {
      return left(failure.toLiveSiteError(niconicoSiteId));
    } on Object catch (error) {
      return left(LiveSiteError.unexpected(siteId: niconicoSiteId, message: '$error', cause: error));
    }
    try {
      final grant = seat.currentGrant;
      if (grant == null) {
        return left(
          const LiveSiteError.contentUnavailable(siteId: niconicoSiteId, message: 'the seat granted no stream'),
        );
      }
      final response = await site.httpGet(grant.uri, headers: _mediaHeaders(roomId, grant), timeout: masterTimeout);
      return right(
        NiconicoPlayParser.qualities(
          NiconicoPlayParser.variants(response.text, source: grant.uri, status: response.status),
        ),
      );
    } on NiconicoFailure catch (failure) {
      return left(failure.toLiveSiteError(niconicoSiteId));
    } on Object catch (error) {
      return left(LiveSiteError.unexpected(siteId: niconicoSiteId, message: '$error', cause: error));
    } finally {
      await seat.close();
    }
  }

  @override
  Future<Either<LiveSiteError, List<LivePlayLine>>> getLines({required String roomId, LivePlayQuality? quality}) async {
    final NiconicoSeat seat;
    try {
      seat = await site.openSeat(roomId);
    } on NiconicoFailure catch (failure) {
      return left(failure.toLiveSiteError(niconicoSiteId));
    } on Object catch (error) {
      return left(LiveSiteError.unexpected(siteId: niconicoSiteId, message: '$error', cause: error));
    }
    try {
      final grant = seat.currentGrant;
      if (grant == null) {
        return left(
          const LiveSiteError.contentUnavailable(siteId: niconicoSiteId, message: 'the seat granted no stream'),
        );
      }
      final response = await site.httpGet(grant.uri, headers: _mediaHeaders(roomId, grant), timeout: masterTimeout);
      final variants = NiconicoPlayParser.variants(response.text, source: grant.uri, status: response.status);
      final variant = NiconicoPlayParser.pick(variants, quality?.qualityId);
      if (variant == null) {
        return left(
          const LiveSiteError.contentUnavailable(siteId: niconicoSiteId, message: 'the master named no variant'),
        );
      }
      // The line captures the cookie header now: closing the seat below
      // revokes the grant, and the player reuses the captured header.
      return right(NiconicoPlayParser.lines(grant, variant, roomId: roomId, now: site.now()));
    } on NiconicoFailure catch (failure) {
      return left(failure.toLiveSiteError(niconicoSiteId));
    } on Object catch (error) {
      return left(LiveSiteError.unexpected(siteId: niconicoSiteId, message: '$error', cause: error));
    } finally {
      await seat.close();
    }
  }

  /// The headers of a media GET for [roomId] under [grant]: the user agent and
  /// the watch page referer, plus the cookies of the master's own path.
  Map<String, String> _mediaHeaders(String roomId, NiconicoGrant grant) {
    final cookie = grant.cookieHeaderFor(grant.uri, now: site.now());
    return {
      'user-agent': NiconicoEndpoints.userAgent,
      'referer': '${NiconicoEndpoints.origin}/watch/${roomId.trim()}',
      'cookie': ?cookie,
    };
  }
}
