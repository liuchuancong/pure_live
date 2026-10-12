import 'dart:convert';

import 'package:live_sites/live_sites.dart';

/// Static parsers for the SHOWROOM APIs.
abstract final class ShowroomParser {
  /// Web origin.
  static const String origin = 'https://www.showroom-live.com';

  /// Request headers.
  static const Map<String, String> headers = {
    'user-agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36',
    'referer': '$origin/',
  };

  /// Media headers of room [roomId].
  static Map<String, String> mediaHeaders(int roomId) => {
    'user-agent': headers['user-agent']!,
    'referer': '$origin/$roomId',
  };

  /// A room number from a reference; null for a url key or anything else.
  static int? roomNumber(String reference) {
    final digits = int.tryParse(reference.trim());
    return digits != null && digits > 0 ? digits : null;
  }

  /// Whether [reference] is a room url key (non-numeric).
  static bool isUrlKey(String reference) {
    final value = reference.trim();
    return int.tryParse(value) == null && RegExp(r'^[A-Za-z0-9_\-]{1,64}$').hasMatch(value);
  }

  /// Decodes an answer and returns it. SHOWROOM puts fields at the top
  /// level of the payload (no envelope); `error` marks refusals.
  static Map<String, Object?> data(String body, {int status = 200, String what = 'response'}) {
    if (status < 200 || status >= 300) {
      throw SiteApiChangedError('showroom $what: HTTP $status');
    }
    final Object? decoded;
    try {
      decoded = jsonDecode(body);
    } on FormatException {
      throw SiteApiChangedError('showroom $what: body is not JSON');
    }
    if (decoded is! Map<String, Object?>) {
      throw SiteApiChangedError('showroom $what: body is not an object');
    }
    final error = decoded['error'];
    if (error is String || (error is num && error != 0)) {
      throw SiteNotFoundError('showroom $what: $error');
    }
    return decoded;
  }

  /// `room/status` → the numeric room id.
  static int roomIdOfStatus(String body, {int status = 200}) {
    final data = ShowroomParser.data(body, status: status, what: 'room/status');
    final id = SiteCounts.integer(data['room_id']);
    if (id == null || id <= 0) {
      throw const SiteNotFoundError('showroom room/status: no room id');
    }
    return id;
  }

  /// `room/profile` + `live/live_info` → the room snapshot. `live_status`
  /// 2 is on air.
  static LiveRoom room(Map<String, Object?> profile, Map<String, Object?> info, {required int roomId}) {
    final actual = SiteCounts.integer(profile['room_id']);
    if (actual != roomId) {
      throw SiteApiChangedError('showroom room/profile: answered $actual for $roomId');
    }
    final state = SiteCounts.integer(info['live_status']);
    final live = state == 2;
    final startSeconds = SiteCounts.integer(profile['current_live_started_at']);
    return LiveRoom(
      platform: SiteIds.showroom,
      roomId: '$roomId',
      title: (profile['main_name'] ?? profile['room_name'])?.toString() ?? '',
      nick: (profile['main_name'] ?? profile['room_name'])?.toString() ?? '',
      cover: _image(profile['image_square']),
      areaName: profile['genre_name']?.toString(),
      watching: SiteCounts.integer(profile['follower_num']),
      status: live ? LiveStatus.live : LiveStatus.offline,
      startedAt: live && startSeconds != null && startSeconds > 0
          ? DateTime.fromMillisecondsSinceEpoch(startSeconds * 1000, isUtc: true)
          : null,
    );
  }

  /// `streaming_url` rows → the play lines: the `hls` and `hls_all` tiers
  /// with their labels, each URL once.
  static List<LivePlayLine> playLines(String body, {required int roomId, int status = 200}) {
    final data = ShowroomParser.data(body, status: status, what: 'streaming_url');
    final rows = data['streaming_url_list'];
    if (rows is! List) {
      throw const SiteApiChangedError('showroom streaming_url: no streaming_url_list');
    }
    final lines = <LivePlayLine>[];
    final seen = <String>{};
    for (final row in rows) {
      if (row is! Map<String, Object?>) {
        continue;
      }
      final type = row['type']?.toString();
      if (type != 'hls' && type != 'hls_all') {
        continue;
      }
      final url = row['url']?.toString() ?? '';
      if (!url.startsWith('https://') || !seen.add(url)) {
        continue;
      }
      final label = row['label']?.toString() ?? (type == 'hls_all' ? '自动' : '');
      lines.add(
        LivePlayLine(
          url: url,
          headers: mediaHeaders(roomId),
          format: StreamFormat.hls,
          codec: 'avc',
          lineId: label.isEmpty ? type : label,
        ),
      );
    }
    if (lines.isEmpty) {
      throw SiteNotFoundError('showroom streaming_url: no HLS tier for $roomId');
    }
    return lines;
  }

  /// The rooms one directory page lists: the snapshot is sliced locally, so
  /// this is the site's own page size rather than a request parameter.
  static const int directoryPageSize = 30;

  /// `live/onlives` → the live rooms of one group, in the snapshot's order.
  ///
  /// The snapshot is the whole directory in one answer: the groups it is
  /// divided into (`onlives[]` with `genre_id` and `lives`) carry the rooms,
  /// and [genreId] picks one. Genre 0 is the site's "Popularity" group — the
  /// recommendations rather than a subject — and null means every live once,
  /// in group order. A group without a usable genre id is skipped, a repeated
  /// live listed once (the site shows a room in more than one group), and a
  /// genre the snapshot does not have is not found rather than empty.
  static List<LiveRoom> lives(Map<String, Object?> root, {int? genreId}) {
    final groups = SiteJson.list(root['onlives']);
    if (groups.isEmpty) {
      throw const SiteApiChangedError('showroom onlives: no onlives groups');
    }
    final rooms = <LiveRoom>[];
    final seen = <String>{};
    var found = genreId == null;
    for (final group in groups) {
      final groupMap = SiteJson.object(group);
      final id = SiteCounts.integer(groupMap['genre_id']);
      if (id == null || (genreId != null && id != genreId)) {
        continue;
      }
      found = true;
      for (final raw in SiteJson.list(groupMap['lives'])) {
        final room = card(SiteJson.object(raw));
        if (room != null && seen.add(room.roomId)) {
          rooms.add(room);
        }
      }
    }
    if (!found) {
      throw SiteNotFoundError('showroom genre $genreId is not in the snapshot');
    }
    return rooms;
  }

  /// One live of the snapshot as a room, or null for a row without a room id.
  ///
  /// The room's name is the room's own name (`main_name`) and its caption
  /// (`telop`), when the streamer set one, is the title — the site shows it
  /// that way. `view_num` is the broadcast's visits, the figure the site
  /// publishes beside a live, and the site's premium flag has no counterpart
  /// in the unified restriction enum, so the play path is where a refusal
  /// lands.
  static LiveRoom? card(Map<String, Object?> row) {
    final roomId = SiteCounts.integer(row['room_id']);
    if (roomId == null || roomId <= 0) {
      return null;
    }
    final name = SiteText.title(SiteText.text(row['main_name']));
    final telop = SiteText.title(SiteText.text(row['telop']));
    final seconds = SiteCounts.integer(row['started_at']);
    return LiveRoom(
      platform: SiteIds.showroom,
      roomId: '$roomId',
      title: telop.isEmpty ? name : telop,
      nick: name,
      avatar: _image(row['image_square'] ?? row['image']),
      cover: _image(row['image_square'] ?? row['image']),
      areaName: SiteText.trimmed(row['genre_name']),
      watching: SiteCounts.integer(row['view_num']),
      status: LiveStatus.live,
      startedAt: seconds != null && seconds > 0
          ? DateTime.fromMillisecondsSinceEpoch(seconds * 1000, isUtc: true)
          : null,
      httpHeaders: mediaHeaders(roomId),
    );
  }

  /// `live/onlives` → the site's genres, flattened.
  ///
  /// SHOWROOM has no catalogue endpoint: the genres are the groups the live
  /// snapshot is already divided into (`onlives[]` with `genre_id` and
  /// `genre_name`), so this reads the same answer the room list does rather
  /// than asking for something else. Genre 0 is the site's "Popularity"
  /// group — the recommendations rather than a subject — and is kept,
  /// because that is how the site's own side bar starts.
  static List<LiveArea> genres(Map<String, Object?> root) {
    final groups = SiteJson.list(root['onlives']);
    if (groups.isEmpty) {
      throw const SiteApiChangedError('showroom onlives: no onlives groups');
    }
    final areas = <LiveArea>[];
    final seen = <String>{};
    for (final group in groups) {
      final groupMap = SiteJson.object(group);
      final id = SiteCounts.integer(groupMap['genre_id']);
      if (id == null || !seen.add('$id')) {
        continue;
      }
      areas.add(LiveArea(id: '$id', name: SiteText.title(SiteText.text(groupMap['genre_name'])), sort: id));
    }
    return areas;
  }

  static String? _image(Object? value) {
    final url = value?.toString() ?? '';
    return url.isEmpty ? null : url;
  }
}
