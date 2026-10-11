import 'dart:convert';

import 'package:live_sites/live_sites.dart';

/// Static parsers for the NetEase CC web APIs.
abstract final class CcParser {
  static final RegExp _htmlPage = RegExp(r'^\s*<', multiLine: true);

  /// Decodes a JSON body; an HTML body is an API change (the site served
  /// a page where JSON was expected).
  static Map<String, Object?> decode(String body, {int status = 200, String what = 'response'}) {
    if (status != 200 && body.trimLeft().startsWith(_htmlPage)) {
      throw SiteApiChangedError('cc $what: HTTP $status (HTML page)');
    }
    final Object? decoded;
    try {
      decoded = jsonDecode(body);
    } on FormatException {
      throw SiteApiChangedError('cc $what: body is not JSON');
    }
    if (decoded is! Map<String, Object?>) {
      throw SiteApiChangedError('cc $what: body is not an object');
    }
    return decoded;
  }

  /// `activitylives/anchor/lives` → the live channel id for [ccid], or
  /// null when the anchor has none.
  static String? liveChannel(String body, {required String ccid, int status = 200}) {
    if (status == 400) {
      throw SiteNotFoundError('cc activitylives: HTTP 400 for $ccid');
    }
    final root = decode(body, status: status, what: 'activitylives');
    if (root['code']?.toString() != 'OK') {
      throw SiteApiChangedError('cc activitylives: code ${root['code']}');
    }
    final data = root['data'];
    final entry = data is Map<String, Object?> ? data[ccid] : null;
    if (entry is! Map<String, Object?>) {
      throw SiteApiChangedError('cc activitylives: no entry for $ccid');
    }
    final channel = entry['channel_id']?.toString();
    return channel == null || channel.isEmpty ? null : channel;
  }

  /// `live/channel/?channelids=` → the room broadcasting in the channel.
  /// Null when the channel no longer broadcasts (`nolive` or no rows).
  /// The room identity keeps the [ccid] the user asked for; the media
  /// channel id rides in `data` as `channel`.
  static LiveRoom? channelRoom(String body, {required String ccid, int status = 200}) {
    final root = decode(body, status: status, what: 'live/channel');
    final rows = root['data'];
    if (rows != null && rows is! List) {
      throw const SiteApiChangedError('cc live/channel: data is not a list');
    }
    final room = rows is List && rows.isNotEmpty ? rows.first : null;
    if (room is! Map<String, Object?> || room['nolive']?.toString() == '1') {
      return null;
    }
    final answered = room['ccid']?.toString() ?? room['cuteid']?.toString() ?? '';
    if (answered != ccid) {
      throw SiteApiChangedError('cc live/channel: answered ccid $answered for $ccid');
    }
    final statusText = room['status']?.toString();
    final title = room['title']?.toString() ?? '';
    final isReplay = title.startsWith('【重播】');
    final live = statusText == '1' && !isReplay;
    final popularity = room['hot']?.toString() ?? '';
    final online = room['online']?.toString() ?? '';
    final followers = room['follower_num']?.toString() ?? '';
    final watching = int.tryParse(popularity.isNotEmpty ? popularity : (online.isNotEmpty ? online : followers));
    return LiveRoom(
      platform: SiteIds.cc,
      roomId: ccid,
      data: room['cid']?.toString() ?? room['channel_id']?.toString(),
      title: title,
      nick: room['nickname']?.toString() ?? '',
      avatar: _image(room['purl']),
      cover: _image(room['cover'] ?? room['poster']),
      areaName: room['gamename']?.toString(),
      watching: watching,
      status: isReplay ? LiveStatus.replay : (live ? LiveStatus.live : LiveStatus.offline),
    );
  }

  /// The offline room for an anchor with no live channel: identity and
  /// state only; a merge keeps everything stored.
  static LiveRoom offlineRoom(String ccid) => LiveRoom(platform: SiteIds.cc, roomId: ccid, status: LiveStatus.offline);

  /// `video_play_url` payload → the play data (already the `data`
  /// object).
  static Map<String, Object?> playData(String body, {int status = 200}) {
    if (status == 410 || status == 404) {
      throw SiteNotFoundError('cc video_play_url: HTTP $status');
    }
    final data = decode(body, status: status, what: 'video_play_url');
    return data;
  }

  /// The quality codes of a play answer: `vbrname_list` in platform
  /// order, falling back to the single `vbrname_sel`.
  static List<LivePlayQuality> qualities(Map<String, Object?> data) {
    final codes = <String>[];
    final rawCodes = data['vbrname_list'];
    if (rawCodes is List) {
      for (final code in rawCodes) {
        final text = code?.toString() ?? '';
        if (text.isNotEmpty) {
          codes.add(text);
        }
      }
    }
    if (codes.isEmpty) {
      final selected = data['vbrname_sel']?.toString();
      if (selected == null) {
        throw const SiteApiChangedError('cc video_play_url: no vbrname_list or vbrname_sel');
      }
      codes.add(selected);
    }
    return [
      for (final (index, code) in codes.toSet().toList().indexed)
        LivePlayQuality(quality: index, label: code == 'original' ? '原画' : code, sort: codes.length - index),
    ];
  }

  /// Play lines from a play answer: the answered line (`videourl`) plus
  /// the backup (`bakvideourl`).
  static List<LivePlayLine> playLines(Map<String, Object?> data, String ccid, {required String cdn}) {
    final lines = <LivePlayLine>[];
    for (final (urlKey, cdnKey) in const [('videourl', 'cdn_sel'), ('bakvideourl', 'bakcdn_sel')]) {
      final url = data[urlKey]?.toString() ?? '';
      if (!url.startsWith('http')) {
        continue;
      }
      lines.add(
        LivePlayLine(
          url: url,
          headers: mediaHeaders(ccid),
          format: url.toLowerCase().endsWith('.m3u8') ? StreamFormat.hls : StreamFormat.flv,
          lineId: cdnKey == 'cdn_sel' ? cdn : '$cdn-bak',
        ),
      );
    }
    return lines;
  }

  /// Media headers: UA, Origin and the room page as Referer. CC has no
  /// cookie.
  static Map<String, String> mediaHeaders(String roomId) {
    final id = Uri.encodeComponent(roomId.trim());
    return {
      'user-agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36',
      'origin': 'https://cc.163.com',
      'referer': id.isEmpty ? 'https://cc.163.com/' : 'https://cc.163.com/$id/',
    };
  }

  /// The media lease expiry encoded in a media URL's `auth_key`: the first field of
  /// its `auth_key` is the Unix expiry (issued + 300 s).
  static DateTime? leaseExpiry(String url) {
    final match = RegExp(r'(?:^|&)auth_key=(\d+)-').firstMatch(Uri.parse(url).query);
    final seconds = match == null ? null : int.tryParse(match.group(1)!);
    return seconds == null ? null : DateTime.fromMillisecondsSinceEpoch(seconds * 1000);
  }

  static String? _image(Object? value) {
    final url = value?.toString() ?? '';
    return url.isEmpty ? null : url;
  }
}
