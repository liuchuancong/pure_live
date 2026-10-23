import 'package:live_sites/src/models/enums/live_play_format_source.dart';
import 'package:live_sites/src/models/enums/live_stream_codec.dart';
import 'package:live_sites/src/models/enums/live_stream_format.dart';
import 'package:live_sites/src/models/play/live_play_lease/live_play_lease.dart';
import 'package:live_sites/src/models/play/live_play_line/live_play_line.dart';
import 'package:live_sites/src/models/play/live_play_quality/live_play_quality.dart';
import 'package:live_sites/src/platforms/bilibili/api/bilibili_endpoints.dart';
import 'package:live_sites/src/platforms/bilibili/parsers/bilibili_failure.dart';
import 'package:live_sites/src/platforms/bilibili/parsers/bilibili_json.dart';
import 'package:live_sites/src/platforms/bilibili/parsers/bilibili_room_parser.dart';

// Platform-internal code: constructor-name rules that govern the public
// surface are relaxed here.
// ignore_for_file: unnecessary_type_name_in_constructor

/// The play path of a Bilibili live room: qualities and lines built from a
/// `getRoomPlayInfo` answer, plus the carousel (轮播) fallback that plays the
/// video a room is looping.
///
/// Bilibili hands out plain media addresses: `host + base_url + url_info.extra`
/// is the whole URL, with no deadline or signature to assemble. Their lifetime
/// rides in the `expires=` query parameter and becomes a [LivePlayLease].
abstract final class BilibiliPlayParser {
  /// The id and label of the one quality of a carousel played from its video:
  /// the video's own tiers are not offered (a guest gets 480P at most).
  static const String carouselQualityId = 'carousel';

  /// The label of [carouselQualityId].
  static const String carouselLabel = '轮播';

  /// How long before `expires` a play URL is renewed (at most a quarter of its
  /// lifetime).
  static const Duration leaseLead = Duration(seconds: 60);

  /// The one quality of a carousel, named by [carouselQualityId].
  static final LivePlayQuality carouselQuality = LivePlayQuality.of(label: carouselLabel, qualityId: carouselQualityId);

  /// `getRoomPlayInfo` → its `data`, whatever the room's state: a carousel
  /// that comes with a stream (possibly only for a signed-in user) is played.
  /// A `playurl_info` of null (offline, a carousel for guests, a paid
  /// broadcast without a ticket) is [BilibiliFailureKind.streamUnavailable]
  /// naming the state; one without `playurl` is api-changed. A paid broadcast
  /// has 1 in `all_special_types`.
  static Map<String, dynamic> playData(String body, {int status = 200}) {
    final data = jsonObject(BilibiliRoomParser.checked(body, status: status, what: 'getRoomPlayInfo')['data']);
    if (data == null) {
      throw BilibiliFailure(BilibiliFailureKind.apiChanged, 'getRoomPlayInfo: no data (${jsonSnippet(body)})');
    }
    if (data['playurl_info'] == null) {
      final paid = jsonList(data['all_special_types']).any((type) => jsonInt(type) == 1);
      final state = switch (jsonInt(data['live_status'])) {
        1 when paid => 'paid broadcast without a ticket',
        1 => 'live without a stream for this client',
        2 => 'carousel without a stream for this client',
        _ => 'offline',
      };
      throw BilibiliFailure(
        BilibiliFailureKind.streamUnavailable,
        'getRoomPlayInfo: $state (live_status ${data['live_status']})',
      );
    }
    _playurl(data);
    return data;
  }

  /// Whether a `getRoomPlayInfo` answer is a carousel (`live_status` 2)
  /// without a stream for this client (guests): its video is then played from
  /// `getRoundPlayVideo`. Anything that does not read as such an answer is
  /// false, and [playData] explains it.
  static bool carouselWithoutStream(String body, {int status = 200}) {
    try {
      final data = jsonObject(BilibiliRoomParser.checked(body, status: status, what: 'getRoomPlayInfo')['data']);
      return data != null && data['playurl_info'] == null && jsonInt(data['live_status']) == 2;
    } on BilibiliFailure {
      return false;
    }
  }

  /// `live/getRoundPlayVideo?room_id=` of the long [roomId].
  static Uri roundPlayVideo(String roomId) => BilibiliEndpoints.roundPlayVideo(roomId);

  /// The video a carousel is playing (`getRoundPlayVideo`'s `data`): its
  /// `bvid`, part `cid` and the seconds already played, where playback starts.
  /// The answer's own `play_url` is dead and is not read. No `bvid` or no
  /// positive `cid` (nothing in rotation, or the room went live) is
  /// [BilibiliFailureKind.streamUnavailable]; a `play_time` that does not read
  /// as seconds starts at the beginning.
  static ({String bvid, int cid, Duration start}) roundPlayVideoData(String body, {int status = 200}) {
    final data = jsonObject(BilibiliRoomParser.checked(body, status: status, what: 'getRoundPlayVideo')['data']);
    if (data == null) {
      throw BilibiliFailure(BilibiliFailureKind.apiChanged, 'getRoundPlayVideo: no data (${jsonSnippet(body)})');
    }
    final bvid = jsonString(data['bvid'])?.trim() ?? '';
    final cid = jsonInt(data['cid']) ?? 0;
    if (!RegExp(r'^BV[0-9A-Za-z]{10}$').hasMatch(bvid) || cid <= 0) {
      throw BilibiliFailure(
        BilibiliFailureKind.streamUnavailable,
        'getRoundPlayVideo: no video in rotation (cid ${data['cid']})',
      );
    }
    final played = jsonInt(data['play_time']) ?? 0;
    return (bvid: bvid, cid: cid, start: Duration(seconds: played > 0 ? played : 0));
  }

  /// The lines of a carousel video's `x/player/playurl` answer: one per `durl`
  /// part's `url` and `backup_url` (http or https only), whole MP4 files with
  /// the video page's media headers. No `durl` is
  /// [BilibiliFailureKind.streamUnavailable].
  static List<LivePlayLine> videoLines(String body, {required String bvid, int status = 200, String cookie = ''}) {
    final data = jsonObject(BilibiliRoomParser.checked(body, status: status, what: 'x/player/playurl')['data']);
    if (data == null) {
      throw BilibiliFailure(BilibiliFailureKind.apiChanged, 'x/player/playurl: no data (${jsonSnippet(body)})');
    }
    final headers = BilibiliEndpoints.videoHeaders(bvid, cookie: cookie);
    final urls = <String>[];
    for (final part in jsonList(data['durl'])) {
      final map = jsonObject(part);
      if (map == null) continue;
      for (final raw in [map['url'], ...jsonList(map['backup_url'])]) {
        final url = jsonString(raw)?.trim() ?? '';
        final uri = Uri.tryParse(url);
        if (uri == null || (!uri.isScheme('http') && !uri.isScheme('https')) || uri.host.isEmpty) continue;
        if (!urls.contains(url)) urls.add(url);
      }
    }
    if (urls.isEmpty) {
      throw BilibiliFailure(BilibiliFailureKind.streamUnavailable, 'x/player/playurl: no file for $bvid');
    }
    return [
      for (final (index, url) in urls.indexed)
        LivePlayLine.of(
          url: url,
          format: LiveStreamFormat.mp4,
          formatSource: LivePlayFormatSource.declared,
          headers: headers,
          lineLabel: '${Uri.parse(url).host}|mp4|$index',
        ),
    ];
  }

  /// Qualities: the union of every codec's `accept_qn` and `current_qn`,
  /// positive only, best first. Never `g_qn_desc` alone — it lists tiers no
  /// codec serves. Labels come from `g_qn_desc` (10000 is `源`).
  static List<LivePlayQuality> qualities(Map<String, dynamic> data) {
    final playurl = _playurl(data);
    final names = _qnNames(playurl);
    final codes = <int>{};
    for (final entry in _codecs(playurl)) {
      for (final raw in jsonList(entry.codec['accept_qn'])) {
        if (jsonInt(raw) case final qn? when qn > 0) codes.add(qn);
      }
      if (jsonInt(entry.codec['current_qn']) case final current? when current > 0) codes.add(current);
    }
    return [
      for (final qn in codes.toList()..sort((a, b) => b.compareTo(a)))
        LivePlayQuality.of(label: names[qn] ?? (qn == 10000 ? '源' : '$qn'), qualityId: '$qn', platformOrder: qn),
    ];
  }

  /// The lines of one play response requested at [requestedQn] (the quality id,
  /// a Unix-`qn` number; null or unparsable asks for the default).
  ///
  /// Candidates are ordered: `current_qn` equal to the request first, then
  /// `http_stream` before `http_hls`, `flv` < `ts` < `fmp4`, `avc` first,
  /// `mcdn` hosts last, then URL. The first candidate fixes the delivered qn
  /// (the platform's acknowledgement: guests asking 10000 get 250) and the
  /// codec; only lines with both are kept. Each line carries the media headers
  /// for the long room id [roomId] with [cookie] and its lease.
  static List<LivePlayLine> lines(
    Map<String, dynamic> data, {
    required Object? requestedQn,
    required String roomId,
    required DateTime issuedAt,
    String cookie = '',
  }) {
    final playurl = _playurl(data);
    final requested = jsonInt(requestedQn);
    final candidates = <_Candidate>[];
    for (final entry in _codecs(playurl)) {
      final format = _format(entry.format);
      final base = _text(entry.codec['base_url']);
      final current = jsonInt(entry.codec['current_qn']);
      if (format == null || base.isEmpty || current == null || current <= 0) continue;
      final codec = jsonString(entry.codec['codec_name'])?.toLowerCase();
      for (final info in jsonList(entry.codec['url_info'])) {
        final map = jsonObject(info);
        if (map == null) continue;
        final url = Uri.tryParse('${_text(map['host'])}$base${_text(map['extra'])}');
        if (url == null || (!url.isScheme('http') && !url.isScheme('https')) || url.host.isEmpty) continue;
        candidates.add((
          url: url,
          qn: current,
          protocol: entry.protocol,
          format: entry.format,
          codec: codec,
          type: format,
        ));
      }
    }
    if (candidates.isEmpty) return const [];
    candidates.sort((a, b) => _compareCandidates(a, b, requested));
    final first = candidates.first;
    final headers = BilibiliEndpoints.mediaHeaders(roomId, cookie: cookie);
    final seen = <String>{};
    return [
      for (final candidate in candidates)
        if (candidate.qn == first.qn && candidate.codec == first.codec && seen.add(candidate.url.toString()))
          LivePlayLine.of(
            url: candidate.url.toString(),
            format: candidate.type,
            formatSource: LivePlayFormatSource.declared,
            headers: headers,
            codec: _codecOf(candidate.codec),
            lineLabel: '${candidate.url.host}|${candidate.protocol}|${candidate.format}|${candidate.codec ?? ''}',
            lease: lease(candidate.url, issuedAt),
          ),
    ];
  }

  /// The lease of a media URL received at [issuedAt], from its `expires`
  /// (Unix seconds, about an hour after issue): renew [leaseLead] — at most a
  /// quarter of the lifetime — before. Expiry does not cut an established
  /// connection. No `expires`, or one already past, is no lease.
  static LivePlayLease? lease(Uri url, DateTime issuedAt) {
    final match = RegExp(r'(?:^|&)expires=(\d+)(?:&|$)').firstMatch(url.query);
    final expires = match == null ? null : int.tryParse(match.group(1)!);
    if (expires == null || expires <= 0) return null;
    final expiresAt = DateTime.fromMillisecondsSinceEpoch(expires * 1000, isUtc: true);
    final lifetime = expiresAt.difference(issuedAt.toUtc());
    if (lifetime <= Duration.zero) return null;
    final quarter = lifetime ~/ 4;
    return LivePlayLease.of(
      refreshAt: expiresAt.subtract(quarter < leaseLead ? quarter : leaseLead),
      expiresAt: expiresAt,
    );
  }

  /// `playurl_info.playurl`, api-changed when the answer has none.
  static Map<String, dynamic> _playurl(Map<String, dynamic> data) {
    final playurl = jsonObject(jsonObject(data['playurl_info'])?['playurl']);
    if (playurl == null) {
      throw const BilibiliFailure(BilibiliFailureKind.apiChanged, 'getRoomPlayInfo: playurl_info.playurl missing');
    }
    return playurl;
  }

  static Map<int, String> _qnNames(Map<String, dynamic> playurl) => {
    for (final raw in jsonList(playurl['g_qn_desc']))
      if (jsonObject(raw) case final map? when jsonInt(map['qn']) != null && jsonString(map['desc']) != null)
        jsonInt(map['qn'])!: jsonString(map['desc'])!,
  };

  static Iterable<_CodecEntry> _codecs(Map<String, dynamic> playurl) sync* {
    for (final stream in jsonList(playurl['stream'])) {
      final streamMap = jsonObject(stream);
      if (streamMap == null) continue;
      final protocol = jsonString(streamMap['protocol_name']) ?? '';
      for (final format in jsonList(streamMap['format'])) {
        final formatMap = jsonObject(format);
        if (formatMap == null) continue;
        final name = jsonString(formatMap['format_name']) ?? '';
        for (final codec in jsonList(formatMap['codec'])) {
          if (jsonObject(codec) case final codecMap?) yield _CodecEntry(protocol, name, codecMap);
        }
      }
    }
  }

  /// `flv` is an HTTP-FLV stream, `ts` the HLS family's segment format and
  /// `fmp4` the fragmented-MP4 stream (beyond the shared model's formats, so
  /// its container stays the player's `other`).
  static LiveStreamFormat? _format(String name) => switch (name) {
    'flv' => LiveStreamFormat.flv,
    'ts' => LiveStreamFormat.hls,
    'fmp4' => LiveStreamFormat.other,
    _ => null,
  };

  static LiveStreamCodec? _codecOf(String? name) => switch (name) {
    'avc' || 'h264' => LiveStreamCodec.avc,
    'hevc' || 'h265' => LiveStreamCodec.hevc,
    'av1' => LiveStreamCodec.av1,
    _ => null,
  };

  static int _compareCandidates(_Candidate a, _Candidate b, int? requestedQn) {
    final byRequest = (a.qn == requestedQn ? 0 : 1).compareTo(b.qn == requestedQn ? 0 : 1);
    if (byRequest != 0) return byRequest;
    final byProtocol = (a.protocol == 'http_stream' ? 0 : 1).compareTo(b.protocol == 'http_stream' ? 0 : 1);
    if (byProtocol != 0) return byProtocol;
    final byFormat = _formatRank(a.format).compareTo(_formatRank(b.format));
    if (byFormat != 0) return byFormat;
    final byCodec = (a.codec == 'avc' ? 0 : 1).compareTo(b.codec == 'avc' ? 0 : 1);
    if (byCodec != 0) return byCodec;
    final byEdge = (a.url.toString().contains('mcdn') ? 1 : 0).compareTo(b.url.toString().contains('mcdn') ? 1 : 0);
    if (byEdge != 0) return byEdge;
    return a.url.toString().compareTo(b.url.toString());
  }

  static int _formatRank(String format) => switch (format) {
    'flv' => 0,
    'ts' => 1,
    'fmp4' => 2,
    _ => 3,
  };
}

/// One codec node of the play answer with its protocol and format names.
final class _CodecEntry {
  /// Wraps the node.
  const _CodecEntry(this.protocol, this.format, this.codec);

  /// `protocol_name` (`http_stream`, `http_hls`).
  final String protocol;

  /// `format_name` (`flv`, `ts`, `fmp4`).
  final String format;

  /// The `codec[]` node.
  final Map<String, dynamic> codec;
}

/// One candidate line before ordering.
typedef _Candidate = ({Uri url, int qn, String protocol, String format, String? codec, LiveStreamFormat type});

/// A trimmed non-empty text that is neither a map nor a list; empty for
/// anything else (bilibili sends `host`, `extra` and `base_url` as plain
/// strings, but an absent key must not print `null` into a URL).
String _text(Object? value) {
  if (value == null || value is Map || value is Iterable) return '';
  return value.toString().trim();
}
