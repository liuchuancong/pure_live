import 'package:fpdart/fpdart.dart';
import 'package:live_sites/src/capabilities/live_playback_provider.dart';
import 'package:live_sites/src/core/live_site_error.dart';
import 'package:live_sites/src/models/play/live_play_line/live_play_line.dart';
import 'package:live_sites/src/models/play/live_play_quality/live_play_quality.dart';
import 'package:live_sites/src/platforms/kick/api/kick_endpoints.dart';
import 'package:live_sites/src/platforms/kick/kick_site.dart';
import 'package:live_sites/src/platforms/kick/parsers/kick_failure.dart';
import 'package:live_sites/src/platforms/kick/parsers/kick_play_parser.dart';

// Platform-internal code: constructor-name and doc verbosity rules that
// govern the public surface are relaxed here.
// ignore_for_file: unnecessary_type_name_in_constructor

/// The stream of one channel as read from its master playlist.
typedef KickStreamData = ({String slug, Uri master, List<KickVariant> variants, DateTime? expiresAt, DateTime at});

/// How long a read master playlist is reused for the lines that follow a
/// qualities request; past its token's expiry nothing is reused.
const Duration _masterLifetime = Duration(minutes: 10);

/// How close to the token's expiry still counts as "the lease is spent" for a
/// lines request: inside it, the master is re-read rather than handed out.
const Duration _recoveryLead = Duration(minutes: 2);

/// Kick's playback: the channel answer's signed IVS master playlist is read
/// once, and its variants are the qualities and the lines.
///
/// A channel that is offline, banned or answers a `playback_url` that names
/// no IVS host has nothing to play — content-unavailable, not an empty list.
/// The quality id is the rendition name (`1080p60`), so a recovered master
/// selects the same one; a name the new master no longer has falls back to
/// the best variant. Every line carries the token's lease: `LivePlayLine.
/// lease` says when to ask for a fresh master.
final class KickPlaybackProvider implements LivePlaybackProvider {
  /// Serves [site].
  KickPlaybackProvider({required this.site});

  /// The site this capability serves.
  final KickSite site;

  /// The last master playlist per channel, so the lines request after a
  /// qualities request costs nothing extra.
  final Map<String, KickStreamData> _streams = {};

  @override
  Future<Either<LiveSiteError, List<LivePlayQuality>>> getQualities({required String roomId}) async {
    try {
      return right(KickPlayParser.qualities((await _read(roomId)).variants));
    } on KickFailure catch (failure) {
      return left(failure.toLiveSiteError('kick'));
    } on Object catch (error) {
      return left(LiveSiteError.unexpected(siteId: 'kick', message: '$error', cause: error));
    }
  }

  @override
  Future<Either<LiveSiteError, List<LivePlayLine>>> getLines({required String roomId, LivePlayQuality? quality}) async {
    try {
      var data = await _read(roomId);
      // A recovery read: the reference re-reads the channel and its master on
      // recovery, because a token revoked early server-side otherwise has no
      // way back. Same trigger kept here — the cached lease is spent, so the
      // lines it would build are certain to die mid-play.
      if (_leaseRunningOut(data)) data = await _read(roomId, force: true);
      final variant = KickPlayParser.pick(data.variants, quality?.qualityId ?? quality?.label);
      if (variant == null) {
        throw const KickFailure(KickFailureKind.streamUnavailable, 'master playlist: no variant');
      }
      return right(
        KickPlayParser.lines(variant, slug: data.slug, master: data.master, expiresAt: data.expiresAt, now: site.now()),
      );
    } on KickFailure catch (failure) {
      return left(failure.toLiveSiteError('kick'));
    } on Object catch (error) {
      return left(LiveSiteError.unexpected(siteId: 'kick', message: '$error', cause: error));
    }
  }

  /// The channel [roomId]'s stream: the cached master playlist while it is
  /// fresh, else the channel answer and the master it points at. A new
  /// master (a new token) comes with a new lease.
  Future<KickStreamData> _read(String roomId, {bool force = false}) async {
    final slug = KickEndpoints.normalizeSlug(roomId);
    if (slug == null) {
      throw KickFailure(KickFailureKind.notFound, 'room id "${roomId.trim()}" is not a Kick channel');
    }
    final cached = _streams[slug];
    if (!force && cached != null && _usable(cached)) return cached;
    final channel = await site.channel(slug);
    final master = channel.master;
    if (master == null) {
      throw KickFailure(
        KickFailureKind.streamUnavailable,
        'channel $slug is ${channel.room.broadcast.effectiveLiveStatus.name}',
      );
    }
    final response = await site.mediaGet(master, headers: KickEndpoints.mediaHeaders(slug));
    final variants = KickPlayParser.variants(response.text, master: master, status: response.status);
    final data = (
      slug: slug,
      master: master,
      variants: variants,
      expiresAt: KickPlayParser.tokenExpiry(master),
      at: site.now(),
    );
    _streams
      ..remove(slug)
      ..[slug] = data;
    if (_streams.length > 16) _streams.remove(_streams.keys.first);
    return data;
  }

  bool _usable(KickStreamData data) {
    final at = site.now();
    if (data.expiresAt != null && !at.isBefore(data.expiresAt!)) return false;
    return at.difference(data.at) < _masterLifetime;
  }

  /// Whether the cached master's token expires inside [_recoveryLead] — its
  /// lines would stop mid-play, so ask for a new token instead.
  bool _leaseRunningOut(KickStreamData data) {
    final expiresAt = data.expiresAt;
    if (expiresAt == null) return false;
    return expiresAt.difference(site.now()) < _recoveryLead;
  }
}
