import 'package:fpdart/fpdart.dart';
import 'package:live_sites/src/capabilities/live_playback_provider.dart';
import 'package:live_sites/src/core/live_site_error.dart';
import 'package:live_sites/src/models/play/live_play_line/live_play_line.dart';
import 'package:live_sites/src/models/play/live_play_quality/live_play_quality.dart';
import 'package:live_sites/src/platforms/douyu/api/douyu_endpoints.dart';
import 'package:live_sites/src/platforms/douyu/douyu_site.dart';
import 'package:live_sites/src/platforms/douyu/parsers/douyu_failure.dart';
import 'package:live_sites/src/platforms/douyu/parsers/douyu_play_parser.dart';
import 'package:live_sites/src/platforms/douyu/parsers/douyu_room_parser.dart';

// Platform-internal code: constructor-name and doc verbosity rules that
// govern the public surface are relaxed here.
// ignore_for_file: unnecessary_type_name_in_constructor

/// Douyu's playback: qualities from one metadata request, lines signed per
/// CDN at a quality's rate.
/// Douyu's playback: qualities from one metadata request, lines signed per CDN at a quality's rate.
final class DouyuPlaybackProvider implements LivePlaybackProvider {
  /// Serves [site].
  /// Serves [site].
  DouyuPlaybackProvider({required this.site});

  /// The site this capability serves.
  final DouyuSite site;

  /// The CDN set each room's last metadata answer advertised, keyed by the
  /// rid; `getLines` signs the committed rate on these.
  final Map<String, List<String>> _cdns = {};

  @override
  @override
  Future<Either<LiveSiteError, List<LivePlayQuality>>> getQualities({required String roomId}) async {
    try {
      final play = await _play(roomId, rate: -1, cdn: '');
      final data = DouyuPlayParser.playData(play.text, status: play.status);
      final lines = DouyuPlayParser.cdns(data);
      if (roomId.trim().isNotEmpty) {
        _cdns.remove(roomId.trim());
        _cdns[roomId.trim()] = lines;
      }
      return right(DouyuPlayParser.qualities(data));
    } on DouyuFailure catch (failure) {
      return left(failure.toLiveSiteError('douyu'));
    } on Object catch (error) {
      return left(LiveSiteError.unexpected(siteId: 'douyu', message: '$error', cause: error));
    }
  }

  @override
  @override
  Future<Either<LiveSiteError, List<LivePlayLine>>> getLines({required String roomId, LivePlayQuality? quality}) async {
    try {
      final rid = await _ridOf(roomId);
      final rate = int.tryParse(quality?.qualityId ?? '') ?? -1;
      final cdns = _cdns[rid] ?? await _refreshCdns(rid);
      final issuedAt = DateTime.now().toUtc();
      final cookie = site.identity().cookie;
      final answers = <({LivePlayLine line, int? rate})>[];
      DouyuFailure? last;
      for (final cdn in cdns) {
        try {
          final play = await _play(rid, rate: rate, cdn: cdn);
          final data = DouyuPlayParser.playData(play.text, status: play.status);
          answers.add(DouyuPlayParser.answer(data, roomId: rid, cdn: cdn, cookie: cookie, issuedAt: issuedAt));
        } on DouyuFailure catch (failure) {
          last = failure;
        }
      }
      if (answers.isEmpty) {
        throw last ?? const DouyuFailure(DouyuFailureKind.streamUnavailable, 'no CDN answered');
      }
      return right(_linesFor(answers, requestedRate: rate));
    } on DouyuFailure catch (failure) {
      return left(failure.toLiveSiteError('douyu'));
    } on Object catch (error) {
      return left(LiveSiteError.unexpected(siteId: 'douyu', message: '$error', cause: error));
    }
  }

  /// The lines for one requested rate from the CDNs' answers (in CDN
  /// order). CDNs may confirm different rates, and one quality must never
  /// cover a mix: the group confirming [requestedRate] wins, else the
  /// first confirmed group, else the unconfirmed one.
  static List<LivePlayLine> _linesFor(List<({LivePlayLine line, int? rate})> answers, {required int requestedRate}) {
    final groups = <int?, List<LivePlayLine>>{};
    for (final answer in answers) {
      final group = groups.putIfAbsent(answer.rate, () => []);
      if (group.every((line) => line.url != answer.line.url)) group.add(answer.line);
    }
    final applied = groups.containsKey(requestedRate) ? requestedRate : groups.keys.whereType<int>().firstOrNull;
    return groups[applied] ?? const [];
  }

  Future<String> _ridOf(String roomId) async {
    final id = roomId.trim();
    if (!DouyuRoomParser.isNumericRid(id)) {
      final rid = await site.ridFor(id);
      if (rid == null) {
        throw DouyuFailure(DouyuFailureKind.notFound, 'room id "$id" is not a number');
      }
      return rid;
    }
    return id;
  }

  Future<List<String>> _refreshCdns(String rid) async {
    final play = await _play(rid, rate: -1, cdn: '');
    final data = DouyuPlayParser.playData(play.text, status: play.status);
    final lines = DouyuPlayParser.cdns(data);
    _cdns.remove(rid);
    _cdns[rid] = lines;
    return lines;
  }

  /// One signed `getH5PlayV1` for (rate, cdn), at most twice: after a
  /// failed first attempt the login is renewed and the second attempt
  /// fetches a new descriptor. A room-state failure (`-5` 未开播) is not
  /// retried.
  Future<({String text, int status})> _play(String rid, {required int rate, required String cdn}) async {
    if (!DouyuRoomParser.isNumericRid(rid)) {
      throw DouyuFailure(DouyuFailureKind.notFound, 'room id "$rid" is not a number');
    }
    await site.renewLogin();
    DouyuFailure? last;
    for (var attempt = 0; attempt < 2; attempt++) {
      try {
        final identity = site.identity();
        final descriptor = await site.descriptorFor(identity.did, () async {
          final response = await site.httpGet(
            DouyuEndpoints.encryption(identity.did),
            headers: site.apiHeaders(identity.cookie),
          );
          return DouyuPlayParser.descriptor(response.text, now: DateTime.now().toUtc(), status: response.status);
        });
        final issuedAt = DateTime.now().toUtc();
        return await site.httpPostForm(
          DouyuEndpoints.play(rid),
          fields: DouyuPlayParser.signedForm(
            descriptor,
            roomId: rid,
            tt: issuedAt.millisecondsSinceEpoch ~/ 1000,
            did: identity.did,
            rate: rate,
            cdn: cdn,
          ),
          headers: site.apiHeaders(identity.cookie, roomId: rid),
        );
      } on DouyuFailure catch (failure) {
        if (failure.kind == DouyuFailureKind.streamUnavailable) rethrow;
        last = failure;
      }
      if (attempt == 0) await site.renewLogin();
    }
    throw last!;
  }
}
