import 'dart:convert';

import 'package:live_sites/src/common/normalization/html_entities.dart';
import 'package:live_sites/src/common/normalization/site_urls.dart';
import 'package:live_sites/src/models/anchor/live_anchor/live_anchor.dart';
import 'package:live_sites/src/models/area/live_area/live_area.dart';
import 'package:live_sites/src/models/enums/live_audience_metric_type.dart';
import 'package:live_sites/src/models/enums/live_play_format_source.dart';
import 'package:live_sites/src/models/enums/live_restriction.dart';
import 'package:live_sites/src/models/enums/live_status.dart';
import 'package:live_sites/src/models/enums/live_stream_codec.dart';
import 'package:live_sites/src/models/enums/live_stream_format.dart';
import 'package:live_sites/src/models/play/live_play_line/live_play_line.dart';
import 'package:live_sites/src/models/play/live_play_quality/live_play_quality.dart';
import 'package:live_sites/src/models/play/play_geometry/play_geometry.dart';
import 'package:live_sites/src/models/room/live_room/live_room.dart';
import 'package:live_sites/src/models/room/room_audience/room_audience.dart';
import 'package:live_sites/src/models/room/room_broadcast/room_broadcast.dart';
import 'package:live_sites/src/models/room/room_content/room_content.dart';
import 'package:live_sites/src/models/room/room_links/room_links.dart';
import 'package:live_sites/src/platforms/picarto/api/picarto_endpoints.dart';
import 'package:live_sites/src/platforms/picarto/parsers/picarto_failure.dart';
import 'package:live_sites/src/platforms/picarto/parsers/picarto_json.dart';

// Platform-internal code: constructor-name and doc verbosity rules that
// govern the public surface are relaxed here.
// ignore_for_file: unnecessary_type_name_in_constructor

/// One quality of a master playlist: the reported quality and the variant
/// URLs on the edge it was read from.
final class PicartoQuality {
  /// Creates the quality.
  PicartoQuality({
    required this.quality,
    required List<String> urls,
    this.height = 0,
    this.frameRate = 0,
    this.bitrateKbps = 0,
  }) : urls = List.unmodifiable(urls);

  /// The quality as the playback capability reports it.
  final LivePlayQuality quality;

  /// The variant playlist URLs of this profile; the auto quality's one URL
  /// is the master playlist itself.
  final List<String> urls;

  /// The declared height in pixels; 0 for the auto quality (or no
  /// `RESOLUTION`).
  final int height;

  /// The declared frame rate; 0 when not given.
  final double frameRate;

  /// The declared `BANDWIDTH` in kilobits per second; 0 when not given.
  final int bitrateKbps;
}

/// The stream behind a live room: the master playlist on the edge the load
/// balancer chose, and its qualities (best first).
final class PicartoStreamData {
  /// Creates the data.
  PicartoStreamData({
    required this.name,
    required this.channelId,
    required this.master,
    required List<PicartoQuality> qualities,
    String? requestedId,
  }) : qualities = List.unmodifiable(qualities),
       requestedId = requestedId ?? name;

  /// The channel name as the platform writes it (`TheBaker`), which is also
  /// the room id.
  final String name;

  /// The name as it was asked for (`thebaker` from a lower-case link); kept
  /// for reference only.
  final String requestedId;

  /// The channel's numeric id, which picks its own stream in a multistream
  /// group.
  final int channelId;

  /// The HLS master playlist on the edge the load balancer chose.
  final Uri master;

  /// Qualities of [master], best first; a line request resolves against
  /// them.
  final List<PicartoQuality> qualities;

  /// The qualities as reported.
  List<LivePlayQuality> get options => [for (final quality in qualities) quality.quality];

  /// The quality whose id is [qualityId], or null.
  PicartoQuality? byId(String? qualityId) =>
      qualities.where((entry) => entry.quality.qualityId == qualityId).firstOrNull;
}

/// A `channel/detail` answer: the room under the platform's spelling of its
/// name, and what streams and danmaku need.
final class PicartoChannel {
  /// Creates the answer.
  const PicartoChannel({
    required this.room,
    required this.name,
    required this.channelId,
    required this.requestedId,
    this.master,
  });

  /// The room, without stream data or danmaku arguments.
  final LiveRoom room;

  /// The channel name as the platform writes it, the room id.
  final String name;

  /// The name as it was asked for.
  final String requestedId;

  /// The channel's numeric id.
  final int channelId;

  /// The HLS master playlist when the channel is live and public, else null.
  final Uri? master;
}

/// Pure parsing of Picarto responses (the reference `PicartoApi`, on the v2
/// models).
///
/// Answers are checked strictly (a page that does not match its request is
/// api-changed), except that a bad row is left out and only an answer
/// without any usable row fails, so a change of format is still not shown as
/// an empty list.
abstract final class PicartoRoomParser {
  /// How much one line of height weighs in a quality's order against the
  /// bandwidth (bits per second, far below it).
  static const int heightWeight = 1000000000;

  /// The id of the one quality of a master played as it is.
  static const String autoQualityId = 'master';

  /// The label of [autoQualityId].
  static const String autoQualityName = '自动';

  // Catalog -------------------------------------------------------------------

  /// The catalog's areas: the public directory first, then
  /// `api/languages-categories`'s categories in answer order, all under the
  /// one category. An entry without a valid id or label, or repeating an
  /// id, is left out; no list, more than 200 entries or no valid entry at
  /// all is api-changed (a changed format is never an empty catalog).
  static List<LiveArea> areas(String body, {int status = 200}) {
    const what = 'languages-categories';
    final root = PicartoJson.json(body, what, status);
    final rows = root['categories'];
    if (rows is! List || rows.isEmpty || rows.length > 200) {
      throw PicartoFailure(PicartoFailureKind.apiChanged, '$what: no category list${PicartoJson.snippet(body)}');
    }
    final areas = <String, LiveArea>{};
    for (final raw in rows) {
      final item = PicartoJson.object(raw, '$what row', body);
      final id = PicartoJson.integer(item['id']);
      final label = PicartoJson.string(item['label']) ?? '';
      if (id == null || id <= 0 || label.isEmpty || label.length > 100 || areas.containsKey('$id')) continue;
      areas['$id'] = LiveArea.normalized(
        platform: PicartoEndpoints.siteId,
        areaId: '$id',
        areaName: label,
        parentAreaId: PicartoEndpoints.category.id,
        parentAreaName: PicartoEndpoints.category.name,
      );
    }
    if (areas.isEmpty) {
      throw PicartoFailure(PicartoFailureKind.apiChanged, '$what: no valid category${PicartoJson.snippet(body)}');
    }
    return [directoryArea(), ...areas.values];
  }

  /// The catalog's first area: every public live channel, adult content
  /// excluded (the recommendations).
  static LiveArea directoryArea() => LiveArea.normalized(
    platform: PicartoEndpoints.siteId,
    areaId: PicartoEndpoints.publicDirectory.id,
    areaName: PicartoEndpoints.publicDirectory.name,
    parentAreaId: PicartoEndpoints.category.id,
    parentAreaName: PicartoEndpoints.category.name,
  );

  /// The category id an area id names: null for the public directory, a
  /// canonical positive id for a category area. Anything else is a caller
  /// error, refused before any request.
  static int? categoryIdOf(String areaId) {
    final id = areaId.trim();
    if (id == PicartoEndpoints.publicDirectory.id) return null;
    final number = int.tryParse(id);
    if (number == null || number <= 0 || '$number' != id) {
      throw PicartoFailure(PicartoFailureKind.invalidArgument, 'area "$areaId" is not a Picarto area');
    }
    return number;
  }

  // Directory -----------------------------------------------------------------

  /// An `api/explore` page: live, non-adult channels by viewers, one per
  /// name (case ignored). The page must be the one asked for ([page],
  /// [pageSize]). A row that is no channel or, with [categoryId], not of
  /// that category is left out; a page none of whose rows is usable is
  /// api-changed (a changed format, or a category filter the API ignored).
  /// More pages follow while [page] is below `last_page` (the row count
  /// proves nothing: offline and adult rows are left out).
  static ({List<LiveRoom> rooms, bool hasMore}) directoryPage(
    String body, {
    required int page,
    required int pageSize,
    int? categoryId,
    int status = 200,
  }) {
    const what = 'explore';
    final root = PicartoJson.json(body, what, status);
    final rows = root['data'];
    final last = PicartoJson.integer(root['last_page']);
    final total = PicartoJson.integer(root['total']);
    if (rows is! List ||
        rows.length > pageSize ||
        PicartoJson.integer(root['current_page']) != page ||
        PicartoJson.integer(root['per_page']) != pageSize ||
        last == null ||
        last < 1 ||
        total == null ||
        total < 0 ||
        (page > last && rows.isNotEmpty)) {
      throw PicartoFailure(PicartoFailureKind.apiChanged, '$what: not page $page of $pageSize');
    }
    final rooms = <String, LiveRoom>{};
    var usable = 0;
    for (final raw in rows) {
      final row = _objectOrNull(raw);
      if (row == null || row['adult'] is! bool || !_isChannel(row)) continue;
      if (categoryId != null) {
        final categories = row['categories'];
        if (categories is! List ||
            !categories.any((value) => PicartoJson.integer(_objectOrNull(value)?['id']) == categoryId)) {
          continue;
        }
      }
      usable++;
      final room = _card(row);
      // Filtering, not an invented offline state: adult and offline rows
      // are left out, and a short page is not topped up from the next.
      if (row['adult'] != false || !room.broadcast.isLiveNow) continue;
      rooms.putIfAbsent(room.roomId.toLowerCase(), () => room);
    }
    if (rows.isNotEmpty && usable == 0) {
      throw PicartoFailure(
        PicartoFailureKind.apiChanged,
        '$what: no usable row${categoryId == null ? '' : ' of category $categoryId'}',
      );
    }
    return (rooms: rooms.values.toList(), hasMore: page < last);
  }

  // Search --------------------------------------------------------------------

  /// An `api/search` (`searchProfiles`) page: channel profiles, live and
  /// offline, one per name. Profiles have no stream title, cover or
  /// audience: the title is the channel name and the introduction the
  /// profile's `bio`; the followers are `follower_count`. A profile without
  /// a valid name, id or state, or with negative followers, is left out; a
  /// page none of whose profiles is usable is api-changed. The answer's
  /// `count` differs between pages and is not read: a page that read
  /// nothing ends the keyword.
  static List<LiveRoom> searchRooms(String body, {required int pageSize, int status = 200}) {
    const what = 'search';
    final root = PicartoJson.json(body, what, status);
    final result = _objectOrNull(root['searchProfiles']);
    final rows = result?['data'];
    if (rows is! List || rows.length > pageSize) {
      throw PicartoFailure(PicartoFailureKind.apiChanged, '$what: no searchProfiles.data of at most $pageSize');
    }
    final rooms = <String, LiveRoom>{};
    var usable = 0;
    for (final raw in rows) {
      final profile = _objectOrNull(raw);
      final followers = PicartoJson.integer(profile?['follower_count']);
      if (profile == null || !_isChannel(profile) || (followers != null && followers < 0)) continue;
      usable++;
      final name = PicartoJson.string(profile['name'])!;
      final bio = decodeHtmlEntities(PicartoJson.string(profile['bio']) ?? '').trim();
      rooms.putIfAbsent(
        name.toLowerCase(),
        () => LiveRoom.normalized(
          platform: PicartoEndpoints.siteId,
          roomId: name,
          content: RoomContent.of(title: name, introduction: bio.isEmpty ? null : bio),
          anchor: _anchor(profile, name, followers: followers),
          audience: RoomAudience.of(primaryMetric: LiveAudienceMetricType.unknown),
          broadcast: RoomBroadcast.of(liveStatus: profile['online'] == true ? LiveStatus.live : LiveStatus.offline),
          links: RoomLinks.of(webUrl: PicartoEndpoints.roomPageUrl(name)),
        ),
      );
    }
    if (rows.isNotEmpty && usable == 0) {
      throw const PicartoFailure(PicartoFailureKind.apiChanged, '$what: no usable profile');
    }
    return rooms.values.toList();
  }

  // Rooms ---------------------------------------------------------------------

  /// `api/channel/detail/<name>` for the channel asked for as
  /// [requestedId]. The platform matches names ignoring case and answers in
  /// its own spelling (`thebaker` → `TheBaker`), which is the room id, as
  /// the reference's follows were stored under it.
  ///
  /// - `channel: null`: not-found.
  /// - A channel of another name, or without id, state or `private` flag:
  ///   api-changed.
  /// - A private channel (the viewer needs the streamer's private key) is
  ///   shown as usual, live or offline, with the restriction `private` and
  ///   no stream; any other channel has the restriction `none`. Adult
  ///   channels are not restricted: they play without an account.
  /// - With [stream], a live channel that is not private carries the master
  ///   playlist on the load balancer's edge, of the one stream in
  ///   `getMultiStreams` that is this channel's (a multistream group lists
  ///   the others too). Without an edge or exactly one own stream the answer
  ///   is api-changed. Without [stream] (a state-only refresh) these fields
  ///   are not checked and there is no master.
  ///
  /// The room's viewers are concurrent, `total_views` cumulative; plus the
  /// description panels as the introduction and `followers_count`. The
  /// cover is the own stream's thumbnail, of the broadcast on air or,
  /// offline, of the last one, else the channel's `image_thumbnail`. The
  /// answer has no start time (the public API's has).
  static PicartoChannel roomDetail(String body, {required String requestedId, int status = 200, bool stream = true}) {
    const what = 'channel/detail';
    final root = PicartoJson.json(body, what, status);
    final id = requestedId.trim();
    if (root.containsKey('channel') && root['channel'] == null) {
      throw PicartoFailure(PicartoFailureKind.notFound, '$what: no channel "$id"');
    }
    final channel = PicartoJson.object(root['channel'], '$what channel', body);
    if (!_isChannel(channel) ||
        (PicartoJson.string(channel['name']) ?? '').toLowerCase() != id.toLowerCase() ||
        channel['private'] is! bool) {
      throw PicartoFailure(
        PicartoFailureKind.apiChanged,
        '$what: channel "$id" without a valid name, id, state or private flag',
      );
    }
    final card = _card(channel);
    final channelId = int.parse(card.anchor!.anchorId);
    final streams = _objectOrNull(root['getMultiStreams'])?['streams'];
    final own = [
      if (streams is List && streams.length <= 100)
        for (final raw in streams)
          if (_objectOrNull(raw) case final entry? when PicartoJson.integer(entry['channelId']) == channelId) entry,
    ];
    Uri? master;
    if (stream && card.broadcast.isLiveNow && card.broadcast.effectiveRestriction != LiveRestriction.private) {
      final edge = PicartoJson.string(_objectOrNull(root['getLoadBalancerUrl'])?['origin']) ?? '';
      if (edge.length > 63 || !RegExp(r'^[a-z0-9]+(?:-[a-z0-9]+)*$').hasMatch(edge)) {
        throw const PicartoFailure(PicartoFailureKind.apiChanged, '$what: no load balancer edge');
      }
      if (streams is! List || streams.length > 100) {
        throw const PicartoFailure(PicartoFailureKind.apiChanged, '$what: no stream list');
      }
      if (own.length != 1) {
        throw PicartoFailure(PicartoFailureKind.apiChanged, '$what: ${own.length} streams of channel $channelId');
      }
      final streamName = PicartoJson.string(own.single['stream_name']) ?? '';
      if (!RegExp(r'^[a-zA-Z0-9_+-]{1,150}$').hasMatch(streamName)) {
        throw PicartoFailure(PicartoFailureKind.apiChanged, '$what: bad stream name "$streamName"');
      }
      master = Uri.parse('https://$edge.picarto.tv/stream/hls/$streamName/index.m3u8');
    }
    // The stream's thumbnail when live; the channel's is the fallback.
    final thumbnail = own.length == 1 ? normalizeImageUrl(own.single['thumbnail_image']) : '';
    final followers = PicartoJson.count(channel['followers_count']);
    final detailed = card.rebuild(
      (b) => b
        ..content.replace(
          card.content.rebuild(
            (b) => b
              ..coverUrl = thumbnail.isEmpty ? card.content.coverUrl : thumbnail
              ..introduction = _introduction(channel['descriptions']),
          ),
        )
        ..anchor = followers == null ? null : card.anchor?.rebuild((b) => b..followerCount = followers).toBuilder(),
    );
    return PicartoChannel(room: detailed, name: card.roomId, channelId: channelId, requestedId: id, master: master);
  }

  /// When the broadcast on air started: `last_live` of the public API's
  /// `api/v1/channel/name/<name>`, in UTC (`2026-09-28 16:12:10`). Null when
  /// the answer is of another channel, the channel is offline (`last_live`
  /// is then the previous broadcast's start) or the time is missing or
  /// malformed. Statuses as the internal API (404 is not-found).
  static DateTime? liveSince(String body, {required String name, int status = 200}) {
    const what = 'channel/name';
    final root = PicartoJson.json(body, what, status);
    if ((PicartoJson.string(root['name']) ?? '').toLowerCase() != name.trim().toLowerCase() || root['online'] != true) {
      return null;
    }
    final match = RegExp(r'^(\d{4})-(\d{2})-(\d{2}) (\d{2}):(\d{2}):(\d{2})$')
        .firstMatch((PicartoJson.string(root['last_live']) ?? '').trim());
    if (match == null) return null;
    final parts = [for (var group = 1; group <= 6; group++) int.parse(match.group(group)!)];
    final time = DateTime.utc(parts[0], parts[1], parts[2], parts[3], parts[4], parts[5]);
    final exact = [time.year, time.month, time.day, time.hour, time.minute, time.second];
    for (var index = 0; index < parts.length; index++) {
      if (exact[index] != parts[index]) return null;
    }
    return time.year > 1970 ? time : null;
  }

  // Streams -------------------------------------------------------------------

  /// The master playlist [body] fetched from [master]: one quality per video
  /// profile (resolution, frame rate, codecs and groups; the bandwidth and
  /// host are not part of it, so a renewed playlist keeps its ids), labelled
  /// `720p 60fps` (or `HLS 3.5 Mbps` without a resolution). The tallest
  /// first, then the highest bandwidth. A quality's id is the JSON of its
  /// profile, which a line request matches by.
  ///
  /// A master with separate audio renditions, or a media playlist, is one
  /// quality [autoQualityName] whose id is [autoQualityId] and whose URL is
  /// [master] itself (a bare variant would play without sound). HTTP 404 is
  /// stream-unavailable (the broadcast ended since the detail); anything
  /// that is not a playlist, a variant without a bandwidth or with a
  /// malformed resolution or frame rate, or a URL that is not http(s) is
  /// api-changed.
  static List<PicartoQuality> qualities(String body, {required Uri master, int status = 200}) {
    const what = 'master playlist';
    if (status == 404) {
      throw const PicartoFailure(PicartoFailureKind.streamUnavailable, '$what: HTTP 404');
    }
    PicartoJson.checkBody(body, what, status);
    if (body.trimLeft().split('\n').first.trim() != '#EXTM3U') {
      throw PicartoFailure(PicartoFailureKind.apiChanged, '$what: not a playlist${PicartoJson.snippet(body)}');
    }
    final grouped = <String, ({String label, int height, double frameRate, int rank, Set<String> urls})>{};
    Map<String, String>? pending;
    var externalAudio = false;
    var media = false;
    var mediaUri = false;
    for (final raw in body.split('\n')) {
      final line = raw.trim();
      if (line.startsWith('#EXT-X-MEDIA:') && line.contains('TYPE=AUDIO') && line.contains('URI=')) {
        externalAudio = true;
      }
      if (line.startsWith('#EXTINF:')) media = true;
      if (line.startsWith('#EXT-X-STREAM-INF:')) {
        if (pending != null) {
          throw const PicartoFailure(PicartoFailureKind.apiChanged, '$what: a variant without a URL');
        }
        pending = {
          for (final match in RegExp('([A-Z0-9-]+)=("[^"]*"|[^,]*)').allMatches(line.substring(18)))
            match.group(1)!: match.group(2)!.replaceAll('"', ''),
        };
        continue;
      }
      if (line.isEmpty || line.startsWith('#')) continue;
      if (pending == null) {
        if (media) {
          _webUri(master, line);
          mediaUri = true;
        }
        continue;
      }
      final attributes = pending;
      pending = null;
      final uri = _webUri(master, line);
      final bandwidth = int.tryParse(attributes['BANDWIDTH'] ?? '');
      final resolution = attributes['RESOLUTION'] ?? '';
      final size = RegExp(r'^([1-9][0-9]*)x([1-9][0-9]*)$').firstMatch(resolution);
      final fps = double.tryParse(attributes['FRAME-RATE'] ?? '0');
      if (bandwidth == null ||
          bandwidth <= 0 ||
          (resolution.isNotEmpty && size == null) ||
          fps == null ||
          !fps.isFinite ||
          fps < 0) {
        throw PicartoFailure(PicartoFailureKind.apiChanged, '$what: bad variant ${jsonEncode(attributes)}');
      }
      final codecs = attributes['CODECS'] ?? '';
      final id = jsonEncode([
        resolution,
        fps,
        codecs,
        attributes['VIDEO'],
        attributes['AUDIO'],
        if (size == null) bandwidth,
      ]);
      final label = size == null
          ? 'HLS ${(bandwidth / 1000000).toStringAsFixed(1)} Mbps'
          : '${size.group(2)}p${fps > 0 ? ' ${fps == fps.roundToDouble() ? fps.toInt() : fps}fps' : ''}';
      final previous = grouped[id];
      grouped[id] = (
        label: previous?.label ?? label,
        height: size == null ? 0 : int.parse(size.group(2)!),
        frameRate: previous != null && previous.frameRate > 0 ? previous.frameRate : fps,
        rank: previous != null && previous.rank >= bandwidth ? previous.rank : bandwidth,
        urls: {...?previous?.urls, uri.toString()},
      );
    }
    if (pending != null || (grouped.isEmpty && !mediaUri)) {
      throw PicartoFailure(PicartoFailureKind.apiChanged, '$what: no variant or media${PicartoJson.snippet(body)}');
    }
    if (externalAudio || grouped.isEmpty) {
      return [
        PicartoQuality(
          quality: LivePlayQuality.of(label: autoQualityName, qualityId: autoQualityId),
          urls: [master.toString()],
        ),
      ];
    }
    final ordered = grouped.entries.indexed.toList()
      ..sort((a, b) {
        final byHeight = b.$2.value.height.compareTo(a.$2.value.height);
        if (byHeight != 0) return byHeight;
        final byRank = b.$2.value.rank.compareTo(a.$2.value.rank);
        return byRank != 0 ? byRank : a.$1.compareTo(b.$1);
      });
    return [
      for (final (_, MapEntry(:key, :value)) in ordered)
        PicartoQuality(
          quality: LivePlayQuality.of(
            label: value.label,
            qualityId: key,
            platformOrder: value.height * heightWeight + value.rank,
            codec: codecOfId(key),
          ),
          urls: value.urls.toList(),
          height: value.height,
          frameRate: value.frameRate,
          bitrateKbps: value.rank ~/ 1000,
        ),
    ];
  }

  /// The video codec (`avc`, `hevc`) named by a quality's [qualityId] (the
  /// JSON of its `CODECS`), or null (the auto quality, or none declared).
  static LiveStreamCodec? codecOfId(String qualityId) {
    if (!qualityId.startsWith('[')) return null;
    final Object? fields;
    try {
      fields = jsonDecode(qualityId);
    } on FormatException {
      return null;
    }
    if (fields is! List || fields.length < 3) return null;
    for (final codec in '${fields[2]}'.toLowerCase().split(',')) {
      final name = codec.trim();
      if (name.startsWith('avc1') || name.startsWith('avc3')) return LiveStreamCodec.avc;
      if (name.startsWith('hvc1') || name.startsWith('hev1')) return LiveStreamCodec.hevc;
    }
    return null;
  }

  /// The lines of [quality] on [master]'s edge: one per variant URL, with
  /// the platform's headers, HLS, the codec and the edge host as the line
  /// label. The URLs carry no signature, so there is no lease; the edge can
  /// change between detail requests, which recovery asks again.
  static List<LivePlayLine> lines(PicartoQuality quality, {required Uri master}) {
    if (quality.urls.isEmpty) {
      throw PicartoFailure(PicartoFailureKind.streamUnavailable, 'quality ${quality.quality.label} has no playlist');
    }
    return [
      for (final url in quality.urls)
        LivePlayLine.of(
          url: url,
          format: LiveStreamFormat.hls,
          formatSource: LivePlayFormatSource.declared,
          headers: PicartoEndpoints.headers,
          codec: quality.quality.codec,
          lineLabel: master.host,
          geometry: quality.height > 0
              ? PlayGeometry.of(
                  height: quality.height,
                  frameRate: quality.frameRate > 0 ? quality.frameRate.round() : null,
                  bitrateKbps: quality.bitrateKbps > 0 ? quality.bitrateKbps : null,
                )
              : null,
        ),
    ];
  }

  // Channels ------------------------------------------------------------------

  /// Whether [channel] (an explore row, a detail's channel, a search
  /// profile) is one: a valid channel name, a positive id and a boolean
  /// state.
  static bool _isChannel(Map<String, dynamic> channel) {
    final id = PicartoJson.integer(channel['id']);
    return PicartoEndpoints.isChannelName(PicartoJson.string(channel['name']) ?? '') &&
        id != null &&
        id > 0 &&
        channel['online'] is bool;
  }

  /// The anchor of a channel the checks passed: its numeric id and the
  /// platform's spelling of its name.
  static LiveAnchor _anchor(Map<String, dynamic> channel, String name, {int? followers}) => LiveAnchor.normalized(
    platform: PicartoEndpoints.siteId,
    anchorId: '${PicartoJson.integer(channel['id'])}',
    name: name,
    avatarUrl: _imageUrl(channel['avatar']),
    followerCount: followers,
  );

  /// The room of a channel that [_isChannel] accepted, under the platform's
  /// spelling of its name. The audience is `viewers` (concurrent) and
  /// `total_views` (cumulative, details only). A `private` flag gives the
  /// restriction (`private` or `none`); rows without it leave it unknown.
  /// [PicartoEndpoints.placeholderTitle] is left empty. The category names
  /// ride along as the room's platform tags.
  static LiveRoom _card(Map<String, dynamic> channel) {
    final name = PicartoJson.string(channel['name'])!;
    final viewers = PicartoJson.count(channel['viewers']);
    final total = PicartoJson.count(channel['total_views']);
    final categories = channel['categories'];
    final title = PicartoJson.string(channel['title']) ?? '';
    final private = channel['private'];
    return LiveRoom.normalized(
      platform: PicartoEndpoints.siteId,
      roomId: name,
      content: RoomContent.of(
        title: title.trim() == PicartoEndpoints.placeholderTitle ? '' : title,
        coverUrl: normalizeImageUrl(channel['image_thumbnail']),
        platformTags: categories is List
            ? [for (final category in categories) ?PicartoJson.string(_objectOrNull(category)?['name'])]
            : const [],
      ),
      anchor: _anchor(channel, name),
      audience: RoomAudience.of(
        onlineViewers: viewers,
        totalViewers: total,
        primaryMetric: LiveAudienceMetricType.onlineViewers,
      ),
      broadcast: RoomBroadcast.of(
        liveStatus: channel['online'] == true ? LiveStatus.live : LiveStatus.offline,
        restriction: private is bool ? (private ? LiveRestriction.private : LiveRestriction.none) : null,
      ),
      links: RoomLinks.of(webUrl: PicartoEndpoints.roomPageUrl(name)),
    );
  }

  /// The description panels' texts, entities decoded, a blank line apart;
  /// null without any.
  static String? _introduction(Object? descriptions) {
    if (descriptions is! List) return null;
    final text = [
      for (final panel in descriptions)
        if (PicartoJson.string(_objectOrNull(panel)?['body']) case final body?) decodeHtmlEntities(body),
    ].join('\n\n');
    return text.isEmpty ? null : text;
  }

  /// An image address as the platform returns it, made absolute; empty for
  /// anything else.
  static String _imageUrl(Object? value) => normalizeImageUrl(value is String ? value : null);

  /// [line] of a playlist resolved against [master]; anything but an http(s)
  /// URL without user info is api-changed.
  static Uri _webUri(Uri master, String line) {
    final Uri uri;
    try {
      uri = master.resolve(line);
    } on FormatException {
      throw PicartoFailure(PicartoFailureKind.apiChanged, 'master playlist: bad URL "$line"');
    }
    if (!(uri.isScheme('http') || uri.isScheme('https')) || uri.host.isEmpty || uri.userInfo.isNotEmpty) {
      throw PicartoFailure(PicartoFailureKind.apiChanged, 'master playlist: not a web URL "$line"');
    }
    return uri;
  }
}

Map<String, dynamic>? _objectOrNull(Object? value) => value is Map<String, dynamic> ? value : null;
