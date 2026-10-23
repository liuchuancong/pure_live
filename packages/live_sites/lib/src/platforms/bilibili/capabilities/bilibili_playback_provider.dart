import 'package:fpdart/fpdart.dart';
import 'package:live_sites/src/capabilities/live_playback_provider.dart';
import 'package:live_sites/src/core/live_site_error.dart';
import 'package:live_sites/src/models/play/live_play_line/live_play_line.dart';
import 'package:live_sites/src/models/play/live_play_quality/live_play_quality.dart';
import 'package:live_sites/src/platforms/bilibili/api/bilibili_endpoints.dart';
import 'package:live_sites/src/platforms/bilibili/bilibili_manifest.dart';
import 'package:live_sites/src/platforms/bilibili/bilibili_site.dart';
import 'package:live_sites/src/platforms/bilibili/parsers/bilibili_failure.dart';
import 'package:live_sites/src/platforms/bilibili/parsers/bilibili_play_parser.dart';

// Platform-internal code: constructor-name and doc verbosity rules that
// govern the public surface are relaxed here.
// ignore_for_file: unnecessary_type_name_in_constructor

/// Bilibili's playback: `getRoomPlayInfo` for the room's canonical long id.
///
/// Bilibili answers with plain media addresses — no signature to assemble —
/// so a line only joins `host + base_url + extra` and carries the media
/// headers and the lease its `expires=` parameter implies. A carousel
/// (`live_status` 2) that gives this client no stream plays the video in
/// rotation instead, as one [BilibiliPlayParser.carouselQuality].
final class BilibiliPlaybackProvider implements LivePlaybackProvider {
  /// Serves [site].
  BilibiliPlaybackProvider({required this.site});

  /// The site this capability serves.
  final BilibiliSite site;

  @override
  Future<Either<LiveSiteError, List<LivePlayQuality>>> getQualities({required String roomId}) async {
    try {
      final play = await _play(site.longId(roomId), 0);
      final data = play.data;
      return right(data == null ? [BilibiliPlayParser.carouselQuality] : BilibiliPlayParser.qualities(data));
    } on BilibiliFailure catch (failure) {
      return left(failure.toLiveSiteError(bilibiliSiteId));
    } on Object catch (error) {
      return left(LiveSiteError.unexpected(siteId: bilibiliSiteId, message: '$error', cause: error));
    }
  }

  @override
  Future<Either<LiveSiteError, List<LivePlayLine>>> getLines({required String roomId, LivePlayQuality? quality}) async {
    try {
      final longId = site.longId(roomId);
      if (quality?.qualityId == BilibiliPlayParser.carouselQualityId) return right(await _carousel(longId));
      final requested = int.tryParse(quality?.qualityId ?? '') ?? 0;
      final play = await _play(longId, requested);
      final data = play.data;
      // A carousel a guest gets no stream for plays its video (1-1).
      if (data == null) return right(await _carousel(longId));
      final lines = BilibiliPlayParser.lines(
        data,
        requestedQn: requested,
        roomId: longId,
        issuedAt: play.issuedAt,
        cookie: play.cookie,
      );
      if (lines.isEmpty) {
        throw BilibiliFailure(BilibiliFailureKind.streamUnavailable, 'getRoomPlayInfo: no line for $longId');
      }
      return right(lines);
    } on BilibiliFailure catch (failure) {
      return left(failure.toLiveSiteError(bilibiliSiteId));
    } on Object catch (error) {
      return left(LiveSiteError.unexpected(siteId: bilibiliSiteId, message: '$error', cause: error));
    }
  }

  /// `getRoomPlayInfo` at [qn]; `data` is null for a carousel without a stream
  /// for this client (see [BilibiliPlayParser.carouselWithoutStream]).
  Future<({Map<String, dynamic>? data, DateTime issuedAt, String cookie})> _play(String longId, Object qn) async {
    final cookie = await site.cookie();
    final response = await site.httpGet(
      BilibiliEndpoints.playInfo(roomId: longId, qn: qn),
      headers: site.apiHeaders(cookie),
    );
    final issuedAt = site.now();
    if (BilibiliPlayParser.carouselWithoutStream(response.text, status: response.status)) {
      return (data: null, issuedAt: issuedAt, cookie: cookie);
    }
    return (
      data: BilibiliPlayParser.playData(response.text, status: response.status),
      issuedAt: issuedAt,
      cookie: cookie,
    );
  }

  /// The video [longId]'s carousel is playing: `getRoundPlayVideo`, then its
  /// MP4 (`x/player/playurl`). Two requests; when the video ends, asking again
  /// gets the next one in rotation.
  Future<List<LivePlayLine>> _carousel(String longId) async {
    final cookie = await site.cookie();
    final headers = site.apiHeaders(cookie);
    final round = await site.httpGet(BilibiliPlayParser.roundPlayVideo(longId), headers: headers);
    final video = BilibiliPlayParser.roundPlayVideoData(round.text, status: round.status);
    final file = await site.httpGet(BilibiliEndpoints.videoPlayUrl(video.bvid, video.cid), headers: headers);
    return BilibiliPlayParser.videoLines(file.text, bvid: video.bvid, status: file.status, cookie: cookie);
  }
}
