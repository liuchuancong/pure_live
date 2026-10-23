import 'package:fpdart/fpdart.dart';
import 'package:live_sites/src/capabilities/live_playback_provider.dart';
import 'package:live_sites/src/core/live_site_error.dart';
import 'package:live_sites/src/models/play/live_play_line/live_play_line.dart';
import 'package:live_sites/src/models/play/live_play_quality/live_play_quality.dart';
import 'package:live_sites/src/models/room/live_room/live_room.dart';
import 'package:live_sites/src/platforms/twitch/parsers/twitch_failure.dart';
import 'package:live_sites/src/platforms/twitch/parsers/twitch_play_parser.dart';
import 'package:live_sites/src/platforms/twitch/twitch_manifest.dart';
import 'package:live_sites/src/platforms/twitch/twitch_site.dart';

// Platform-internal code: constructor-name and doc verbosity rules that
// govern the public surface are relaxed here.
// ignore_for_file: unnecessary_type_name_in_constructor

/// The 3.x client kept a quality's variant URLs on the quality itself; this
/// keeps the last playlist read, so the [LivePlaybackProvider.getLines] that
/// follows a [LivePlaybackProvider.getQualities] costs nothing extra. Twenty
/// minutes is the access token's own lifetime — the playlist it signed is not
/// reused past that.
const Duration _playlistLifetime = Duration(minutes: 20);

/// Twitch's playback: `PlaybackAccessToken` signs usher's master playlist, and
/// the playlist's variants are the lines.
///
/// A channel the detail called unplayable has nothing to play, reported as
/// content-unavailable rather than an empty quality list. The variant URLs
/// outlive the 20-minute access token, so they carry no lease; a recovery asks
/// for a fresh playlist ([TwitchSite.playlist]) and matches the wanted quality
/// by its id, then by its `VIDEO` group (an id's bandwidth moves between
/// playlists), then by its label — and only when none of those name a variant
/// does it fall back to the best one. A stream the detail marked restricted
/// whose token or usher refuses this viewer is content-unavailable naming the
/// restriction, not a login error.
final class TwitchPlaybackProvider implements LivePlaybackProvider {
  /// Serves [site]; [now] reads the clock for the playlist cache.
  TwitchPlaybackProvider({required this.site, DateTime Function()? now}) : _now = now ?? DateTime.now;

  /// The site this capability serves.
  final TwitchSite site;

  final DateTime Function() _now;

  ({String login, List<TwitchVariantGroup> groups, DateTime at})? _cached;

  @override
  Future<Either<LiveSiteError, List<LivePlayQuality>>> getQualities({required LiveRoom room}) async {
    try {
      final detail = await site.detail(room.roomId);
      return right(TwitchPlayParser.qualities(await _resolve(detail)));
    } on TwitchFailure catch (failure) {
      return left(failure.toLiveSiteError(twitchSiteId));
    } on Object catch (error) {
      return left(LiveSiteError.unexpected(siteId: twitchSiteId, message: '$error', cause: error));
    }
  }

  @override
  Future<Either<LiveSiteError, List<LivePlayLine>>> getLines({required LiveRoom room, LivePlayQuality? quality}) async {
    try {
      final detail = await site.detail(room.roomId);
      final groups = await _resolve(detail);
      final chosen =
          TwitchPlayParser.sameGroup(groups, quality?.qualityId, label: quality?.label ?? '') ?? groups.first;
      return right(TwitchPlayParser.lines(chosen, roomId: room.roomId));
    } on TwitchFailure catch (failure) {
      return left(failure.toLiveSiteError(twitchSiteId));
    } on Object catch (error) {
      return left(LiveSiteError.unexpected(siteId: twitchSiteId, message: '$error', cause: error));
    }
  }

  /// usher's variant groups for [room]: the playlist just read for this channel
  /// while it is under the token's lifetime old, else a new token and
  /// playlist. A channel with nothing to play is stream-unavailable.
  Future<List<TwitchVariantGroup>> _resolve(LiveRoom room) async {
    if (!room.broadcast.isPlayableNow) {
      throw TwitchFailure(TwitchFailureKind.streamUnavailable, '${room.roomId}: nothing on air');
    }
    final login = room.roomId.trim().toLowerCase();
    final cached = _cached;
    if (cached != null && cached.login == login && _now().difference(cached.at) < _playlistLifetime) {
      return cached.groups;
    }
    final groups = await site.playlist(
      login,
      restriction: room.broadcast.isRestricted ? room.broadcast.effectiveRestriction : null,
    );
    _cached = (login: login, groups: groups, at: _now());
    return groups;
  }
}
