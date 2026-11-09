import 'dart:convert';

import 'package:live_net/live_net.dart' show LiveHttp, LiveRequest, LiveResponse;
import 'package:live_vod/src/archive.dart' show ArchiveQuality, ArchiveVideo;
import 'package:live_vod/src/huya_ssr.dart' show HuyaSsr;
import 'package:live_vod/src/vod_models.dart' show VodFailure, VodVideo;

final RegExp _id = RegExp(r'^[1-9][0-9]{0,18}$');

/// Public metadata for one officially archived Huya broadcast; no media URL
/// or credential is retained.
final class HuyaArchiveVideo implements ArchiveVideo {
  /// Creates one archive row.
  const new({
    required this.id,
    required this.title,
    required this.authorId,
    this.authorName = '',
    this.cover = '',
    this.duration = Duration.zero,
    this.date = '',
  });

  @override
  final String id;

  @override
  final String title;

  /// The presenter's public uid, distinct from the room number.
  final String authorId;

  /// The presenter's display name.
  final String authorName;

  /// The public cover.
  final String cover;

  @override
  final Duration duration;

  /// The date label the official archive carries.
  final String date;

  /// The recording as the shared video model, for the row and card widgets
  /// a video list already renders with.
  VodVideo asVideo() => VodVideo(
    id: id,
    title: title,
    coverUrl: cover.isEmpty ? null : cover,
    duration: duration == Duration.zero ? null : duration,
    uploader: authorName.isEmpty ? null : authorName,
  );
}

/// One page of archived broadcasts, in the platform's order.
typedef HuyaArchiveList = ({List<HuyaArchiveVideo> videos, bool hasMore});

/// One permitted rendition, freshly resolved for playback. The id is the
/// https playlist itself — a recording's playlist does not expire — while
/// the address behind it stays transient and is never written into local
/// progress.
final class HuyaArchiveQuality implements ArchiveQuality {
  /// Wraps a validated playlist address and its label.
  const new({required this.id, required this.label, required this.url});

  @override
  final String id;

  @override
  final String label;

  /// The validated https playlist.
  final String url;

  @override
  bool get playable => url.isNotEmpty;
}

/// The official Huya presenter archive: the video station's own SSR page
/// for the list, and `getMomentContent` for a recording's permitted
/// renditions. Only the page's official data assignment is read — the
/// scripts' prototype functions are discarded as metadata, never
/// evaluated.
final class HuyaArchiveApi {
  /// Builds the source over the shared proxied transport.
  new(this.http);

  /// The shared transport; this wrapper does not close it.
  final LiveHttp http;

  /// Media carries no application cookie and no cross-platform headers.
  static const Map<String, String> mediaHeaders = {
    'referer': 'https://www.huya.com/',
    'user-agent':
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) '
        'Chrome/128.0.0.0 Safari/537.36',
  };

  /// The replay definitions the station names, for the ones `defName` does
  /// not.
  static const Map<String, String> _definitionNames = {'yuanhua': '原画', '1300': '720P', '350': '360P'};

  /// The archive's own rank for the source recording, above every
  /// transcode.
  static const int _sourceRank = 1 << 30;

  /// The presenter's archive, paged without a login requirement.
  Future<HuyaArchiveList> list(String uid, {int page = 1}) async {
    if (!_id.hasMatch(uid) || page < 1 || page > 10000) {
      throw const VodFailure('the replay page asked for is not a page');
    }
    final response = await _get(Uri.https('www.huya.com', '/video/u/$uid', {'tabName': 'live', 'pageIndex': '$page'}));
    return parseList(response.text, uid: uid, page: page);
  }

  /// The recording's permitted renditions, source first; an empty answer
  /// refuses with its own message.
  Future<List<HuyaArchiveQuality>> qualities(String videoId) async {
    if (!_id.hasMatch(videoId)) {
      throw const VodFailure('the recording id is not one the station gives out');
    }
    final response = await _get(Uri.https('liveapi.huya.com', '/moment/getMomentContent', {'videoId': videoId}));
    final qualities = parseQualities(response.text, status: response.statusCode);
    if (qualities.isEmpty) {
      throw const VodFailure('the recording keeps no permitted rendition');
    }
    return qualities;
  }

  Future<LiveResponse> _get(Uri url, {Map<String, String> headers = mediaHeaders}) async {
    final response = await http.send(LiveRequest.get(url, headers: headers, site: 'huya'));
    if (response.statusCode == 404) {
      throw const VodFailure('the station keeps no such replay');
    }
    if (response.statusCode == 401) {
      throw const VodFailure('the station asks a login for this replay');
    }
    if (response.statusCode == 403 || response.statusCode == 429) {
      throw const VodFailure('the station refused the replay request');
    }
    if (response.statusCode != 200) {
      throw VodFailure('HTTP ${response.statusCode}', statusCode: response.statusCode);
    }
    return response;
  }

  /// Parses only the official data assignment out of the video page; a
  /// presenter's video never lands under another uid's name. A presenter who
  /// never recorded live answers with an empty list rather than an error.
  static HuyaArchiveList parseList(String html, {required String uid, required int page}) {
    if (!_id.hasMatch(uid) || page < 1) {
      throw const VodFailure('the replay list answer broke its bounds');
    }
    final root = HuyaSsr.parse(html);
    final answer = HuyaSsr.record(root['userPageLiveRecordVideoRsp']);
    if (answer == null) return (videos: const <HuyaArchiveVideo>[], hasMore: false);
    final code = HuyaSsr.integer(HuyaSsr.record(answer['respHeader'])?['code']);
    if (code != null && code != 0) return (videos: const <HuyaArchiveVideo>[], hasMore: false);
    final rows = HuyaSsr.rows(answer['videoDataList']);
    if (rows.length > 100) {
      throw const VodFailure('the replay list changed its shape');
    }
    final seen = <String>{};
    final videos = <HuyaArchiveVideo>[];
    for (final row in rows) {
      final data = HuyaSsr.record(row['videoData']);
      if (data == null) continue;
      final id = HuyaSsr.text(data['vid']);
      final title = HuyaSsr.entities(HuyaSsr.text(data['videoTitle'])).trim();
      final user = HuyaSsr.record(data['userInfo']);
      if (!_id.hasMatch(id) || title.isEmpty || !seen.add(id)) continue;
      // The requested uid names the archive; a row another presenter owns
      // stays out.
      final actual = user == null ? '' : HuyaSsr.text(user['uid']);
      if (actual.isNotEmpty && actual != uid) continue;
      final covers = HuyaSsr.record(data['covers']);
      videos.add(
        HuyaArchiveVideo(
          id: id,
          title: title,
          authorId: uid,
          authorName: user == null ? '' : HuyaSsr.entities(HuyaSsr.text(user['userNick'])).trim(),
          cover: HuyaSsr.image(covers?['cover320'] ?? covers?['cover']),
          duration: HuyaSsr.duration(data['duration']),
          date: HuyaSsr.text(row['date']),
        ),
      );
    }
    final total = HuyaSsr.integer(root['total'] ?? answer['total']);
    return (
      videos: List<HuyaArchiveVideo>.unmodifiable(videos),
      hasMore: videos.isNotEmpty && total != null && page * 10 < total,
    );
  }

  /// The renditions of one recording: `data.moment.videoInfo.definitions`,
  /// the source first and transcodes by height, deduplicated by playlist.
  static List<HuyaArchiveQuality> parseQualities(String body, {int status = 200}) {
    if (status != 200) {
      throw VodFailure('HTTP $status', statusCode: status);
    }
    final root = _decode(body);
    final moment = HuyaSsr.record(HuyaSsr.record(root['data'])?['moment']);
    final info = HuyaSsr.record(HuyaSsr.value(moment?['videoInfo']));
    final rows = HuyaSsr.rows(info?['definitions']);
    final seen = <String>{};
    final ranked = <({HuyaArchiveQuality quality, int rank})>[];
    for (final item in rows) {
      final url = _playlist(item['m3u8']) ?? _playlist(item['url']);
      if (url == null || !seen.add(url)) continue;
      final definition = Uri.tryParse(url)?.queryParameters['definition'] ?? '';
      final source = definition == 'yuanhua';
      final name = HuyaSsr.entities(HuyaSsr.text(item['defName'])).trim();
      final height = HuyaSsr.integer(item['height']) ?? 0;
      ranked.add((
        quality: HuyaArchiveQuality(
          id: url,
          label: source || name.isEmpty ? (_definitionNames[definition] ?? '默认') : name,
          url: url,
        ),
        rank: source ? _sourceRank : (height > 0 ? height : 0),
      ));
    }
    ranked.sort((a, b) => b.rank.compareTo(a.rank));
    return [for (final entry in ranked) entry.quality];
  }

  /// The answer as a record; a body that is not the station's JSON refuses.
  static Map<String, Object?> _decode(String body) {
    final Object? decoded;
    try {
      decoded = jsonDecode(body);
    } on FormatException {
      throw const VodFailure('the recording answer is not JSON the station sends');
    }
    final root = HuyaSsr.record(decoded);
    if (root == null) {
      throw const VodFailure('the recording answer is not an object');
    }
    return root;
  }

  /// A recording playlist: an http(s) `.m3u8` address, `http://` on the
  /// station's own hosts upgraded to https (the VOD CDN serves both); null
  /// for anything else, so a live quality's bit rate is never taken for a
  /// recording.
  static String? _playlist(Object? value) {
    final url = HuyaSsr.media(value);
    if (url == null || !Uri.parse(url).path.toLowerCase().endsWith('.m3u8')) return null;
    return url;
  }
}
