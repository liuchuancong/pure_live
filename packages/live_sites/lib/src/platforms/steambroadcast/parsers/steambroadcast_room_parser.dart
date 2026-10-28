import 'dart:convert';

import 'package:live_sites/src/common/hls/hls_master.dart';
import 'package:live_sites/src/common/normalization/html_entities.dart';
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
import 'package:live_sites/src/models/room/room_runtime/room_runtime.dart';
import 'package:live_sites/src/platforms/steambroadcast/api/steambroadcast_endpoints.dart';
import 'package:live_sites/src/platforms/steambroadcast/parsers/steambroadcast_failure.dart';
import 'package:live_sites/src/platforms/steambroadcast/parsers/steambroadcast_html.dart';
import 'package:live_sites/src/platforms/steambroadcast/parsers/steambroadcast_json.dart';

// Platform-internal code: constructor-name and doc verbosity rules that
// govern the public surface are relaxed here.
// ignore_for_file: unnecessary_type_name_in_constructor

/// The site id of every failure and room.
const String siteId = 'steambroadcast';

/// A broadcast's state, from `getbroadcastmpd`'s `success` (room entry,
/// recording, recovery) or `getbroadcastinfo` (refresh).
enum SteambroadcastState {
  /// `ready`, or `missing_subscription` (a broadcast for subscribers only);
  /// `getbroadcastinfo` online.
  live,

  /// A replay (`is_replay`, which Steam's player plays as one): `ready` with
  /// its master, or `getbroadcastinfo` online. Played like a live.
  replay,

  /// `unavailable`, `offline`, `not_live`, `no_broadcast`;
  /// `getbroadcastinfo`'s `success: 42` or not online.
  offline,

  /// `user_restricted`: the broadcaster's account is restricted from
  /// broadcasting on Steam; there is no broadcast to watch, whoever asks.
  /// Shown as banned.
  accountRestricted,

  /// `waiting`, `waiting_to_start`, `waiting_for_start` and any other value.
  unknown,
}

/// One variant of a broadcast's HLS master, as Steam's own player lists it
/// (`<height>p`, the frame rate added above 30 fps: `1080p60`).
///
/// Steam's variants carry no audio of their own (the audio is a rendition of
/// the master), so a variant is not playable alone; it is the quality list's
/// entry, and its codec is what the line names.
final class SteambroadcastVariant {
  /// Creates the variant.
  const SteambroadcastVariant({
    required this.id,
    required this.width,
    required this.height,
    required this.bandwidth,
    this.frameRate = 0,
    this.codec,
  });

  /// The quality id and name: `720p`, `1080p60`.
  final String id;

  /// The width in pixels.
  final int width;

  /// The height in pixels.
  final int height;

  /// The frame rate; 0 when not given.
  final double frameRate;

  /// The `BANDWIDTH` in bits per second.
  final int bandwidth;

  /// The video codec the variant names, when one.
  final LiveStreamCodec? codec;

  @override
  String toString() => 'SteambroadcastVariant($id, ${width}x$height, $bandwidth)';
}

/// One broadcast: a directory card, or a room read from its answers (the
/// mini profile or watch page, `getbroadcastinfo` and `getbroadcastmpd`,
/// and on room entry its checked HLS master).
final class SteambroadcastBroadcast {
  /// Creates the broadcast.
  SteambroadcastBroadcast({
    required this.steamId,
    required this.state,
    this.broadcaster = '',
    this.title = '',
    this.game = '',
    this.cover = '',
    this.avatar = '',
    this.viewers,
    this.restriction,
    this.broadcastId,
    this.master,
    this.masterChecked = false,
    this.codec,
    Iterable<SteambroadcastVariant> variants = const [],
    this.mediaError,
  }) : variants = List.unmodifiable(variants);

  /// The broadcaster's 64-bit Steam id: the room's identity.
  final String steamId;

  /// The broadcaster's name; '' when none is known (a name that is only the
  /// id is none: Steam writes the id for an account that does not exist).
  final String broadcaster;

  /// The broadcast's title, else its game; '' when unknown.
  final String title;

  /// The game; '' when unknown.
  final String game;

  /// The live thumbnail; '' when there is none.
  final String cover;

  /// The broadcaster's avatar (any https host, 184 px), '' when there is
  /// none or it is Steam's default avatar.
  final String avatar;

  /// Concurrent viewers, when given.
  final int? viewers;

  /// The broadcast's state.
  final SteambroadcastState state;

  /// Who may watch, when the answer says: [LiveRestriction.none] for
  /// `ready`, [LiveRestriction.subscribersOnly] for `missing_subscription`;
  /// null otherwise (a refresh, a card, not live).
  final LiveRestriction? restriction;

  /// `getbroadcastmpd`'s `broadcastid` of the current broadcast, when one
  /// (the chat's key besides the Steam id).
  final String? broadcastId;

  /// The HLS master of a live broadcast or replay, when `getbroadcastmpd`
  /// gave a usable one.
  final Uri? master;

  /// Whether [master] was fetched and passed the check (room entry).
  final bool masterChecked;

  /// The video codec the checked master names, when one.
  final LiveStreamCodec? codec;

  /// The checked master's variants, best first, when it has more than one;
  /// empty otherwise.
  final List<SteambroadcastVariant> variants;

  /// Why the broadcast's media cannot be played, when known: an unusable
  /// `hls_url`, or a master that failed to load or the check. It never fails
  /// the room itself.
  final SteambroadcastFailure? mediaError;

  /// This broadcast with its fields replaced where given.
  SteambroadcastBroadcast _copy({
    String? broadcaster,
    String? title,
    String? game,
    String? cover,
    String? avatar,
    int? viewers,
    bool? masterChecked,
    LiveStreamCodec? codec,
    Iterable<SteambroadcastVariant>? variants,
    SteambroadcastFailure? mediaError,
  }) => SteambroadcastBroadcast(
    steamId: steamId,
    state: state,
    broadcaster: broadcaster ?? this.broadcaster,
    title: title ?? this.title,
    game: game ?? this.game,
    cover: cover ?? this.cover,
    avatar: avatar ?? this.avatar,
    viewers: viewers ?? this.viewers,
    restriction: restriction,
    broadcastId: broadcastId,
    master: master,
    masterChecked: masterChecked ?? this.masterChecked,
    codec: codec ?? this.codec,
    variants: variants ?? this.variants,
    mediaError: mediaError ?? this.mediaError,
  );

  /// This room with the fields its answers lack taken from [known], an
  /// earlier card or room of the same broadcaster: the name, title, game,
  /// cover and avatar when empty; the viewers only while this broadcast is
  /// live and has none of its own (an ended broadcast keeps none of the last
  /// card's count). State, restriction and media stay this room's.
  SteambroadcastBroadcast enrich(SteambroadcastBroadcast known) => _copy(
    broadcaster: broadcaster.isEmpty ? known.broadcaster : broadcaster,
    title: title.isEmpty ? known.title : title,
    game: game.isEmpty ? known.game : game,
    cover: cover.isEmpty ? known.cover : cover,
    avatar: avatar.isEmpty ? known.avatar : avatar,
    viewers: viewers ?? (state == SteambroadcastState.live ? known.viewers : null),
  );

  /// This `getbroadcastmpd` room with `getbroadcastinfo`'s title, game and
  /// cover where [info] has them; its viewers only when this room has none.
  SteambroadcastBroadcast withInfo(SteambroadcastBroadcast info) => _copy(
    title: info.title.isEmpty ? null : info.title,
    game: info.game.isEmpty ? null : info.game,
    cover: info.cover.isEmpty ? null : info.cover,
    viewers: viewers ?? info.viewers,
  );

  /// This broadcast with its master checked ([codec] and [variants] as it
  /// names them), or with [mediaError] when loading or checking it failed.
  SteambroadcastBroadcast withMaster({
    LiveStreamCodec? codec,
    Iterable<SteambroadcastVariant> variants = const [],
    SteambroadcastFailure? mediaError,
  }) => _copy(masterChecked: mediaError == null, codec: codec, variants: variants, mediaError: mediaError);
}

/// The broadcaster's name and avatar (the mini profile, or the watch page's
/// name when it fails).
typedef SteambroadcastProfile = ({String name, String avatar});

/// One page of the trending broadcasts.
final class SteambroadcastPage {
  /// Creates the page.
  SteambroadcastPage({required Iterable<SteambroadcastBroadcast> broadcasts, required this.hasMore})
    : broadcasts = List.unmodifiable(broadcasts);

  /// The page's broadcasts, once per broadcaster, in page order.
  final List<SteambroadcastBroadcast> broadcasts;

  /// Whether another page exists.
  final bool hasMore;
}

/// What a room detail carries besides its fields: the broadcast's state and
/// restriction and, after room entry, its checked master and variants.
final class SteambroadcastRoomData {
  /// Creates the data.
  SteambroadcastRoomData({
    required this.steamId,
    required this.state,
    this.restriction,
    this.master,
    this.codec,
    Iterable<SteambroadcastVariant> variants = const [],
    this.mediaError,
  }) : variants = List.unmodifiable(variants);

  /// The room's Steam id.
  final String steamId;

  /// The broadcast's state.
  final SteambroadcastState state;

  /// Who may watch, when the answer said.
  final LiveRestriction? restriction;

  /// The HLS master, checked on room entry; null for a refresh, which does
  /// not load it.
  final Uri? master;

  /// The video codec the master names, when one.
  final LiveStreamCodec? codec;

  /// The master's variants, best first, when it has more than one.
  final List<SteambroadcastVariant> variants;

  /// Why the broadcast's media cannot be played, when known.
  final SteambroadcastFailure? mediaError;

  /// The qualities: the adaptive master first (the player chooses), then one
  /// per variant, each named as Steam's player names it.
  List<LivePlayQuality> get qualities => [
    LivePlayQuality.of(label: SteambroadcastEndpoints.qualityLabel, qualityId: SteambroadcastEndpoints.qualityId),
    for (final variant in variants) LivePlayQuality.of(label: variant.id, qualityId: variant.id, codec: variant.codec),
  ];

  /// Why this room cannot be played, or null: not live (offline, restricted
  /// account, waiting or unknown) is stream-unavailable, and so is a
  /// broadcast for subscribers only; a live one with a media problem says
  /// what; a live one without a checked master (a refresh) is
  /// stream-unavailable until the room is entered.
  SteambroadcastFailure? get streamError => switch (state) {
    SteambroadcastState.offline => SteambroadcastFailure(
      SteambroadcastFailureKind.streamUnavailable,
      '$steamId is offline',
    ),
    SteambroadcastState.accountRestricted => SteambroadcastFailure(
      SteambroadcastFailureKind.streamUnavailable,
      "$steamId: the broadcaster's account is restricted from broadcasting (user_restricted)",
    ),
    SteambroadcastState.unknown => SteambroadcastFailure(
      SteambroadcastFailureKind.streamUnavailable,
      '$steamId: broadcast state unknown',
    ),
    _ when restriction == LiveRestriction.subscribersOnly => SteambroadcastFailure(
      SteambroadcastFailureKind.streamUnavailable,
      "$steamId: a broadcast for the broadcaster's subscribers only (missing_subscription)",
    ),
    _ when mediaError != null => mediaError,
    _ when master == null => SteambroadcastFailure(
      SteambroadcastFailureKind.streamUnavailable,
      '$steamId: no checked master; enter the room',
    ),
    _ => null,
  };
}

/// Pure parsing of Steam broadcast answers: the trending directory, the
/// watch page, the mini profile, `getbroadcastinfo`, `getbroadcastmpd`, the
/// profile XML of a custom address, the HLS master check and its variants,
/// and the v2 rooms, qualities and lines.
///
/// Answers are checked strictly; a directory card that cannot be read only
/// loses itself. A media problem never fails the room: it is reported when
/// the stream is asked for.
abstract final class SteambroadcastRoomParser {
  /// The platform's one area: the trending broadcasts, without a request.
  static List<LiveArea> areas() => [
    LiveArea.normalized(
      platform: siteId,
      areaId: SteambroadcastEndpoints.areaId,
      areaName: SteambroadcastEndpoints.areaName,
      parentAreaId: siteId,
      parentAreaName: SteambroadcastEndpoints.siteName,
    ),
  ];

  /// Whether [areaId] is the one area's id.
  static bool isArea(String areaId) => areaId == SteambroadcastEndpoints.areaId;

  // Directory -----------------------------------------------------------------

  /// `allcontenthome` (an HTML fragment): one `Broadcast_Card` per broadcast,
  /// read as the reference did — the watch link's id (a card without one, a
  /// repeated broadcaster, or one that cannot be read is skipped), the
  /// content type without `: Broadcast` as title (else the game), the game,
  /// the author's name (else none), the thumbnail, the avatar at 184 px,
  /// `N viewers`, all live. The hidden form says whether page [page] has a
  /// next one: `p == page + 1` and `broadcastsoffset == page × 10`, with
  /// cards.
  static SteambroadcastPage directory(String body, {required int page, int status = 200}) {
    const what = 'allcontenthome';
    SteambroadcastJson.checkBody(body, what, status);
    final root = SteambroadcastHtml.parse(body);
    final seen = <String>{};
    final broadcasts = <SteambroadcastBroadcast>[];
    for (final card in root.all((element) => element.hasClass('Broadcast_Card'))) {
      final watch = card.first(
        (element) => element.name == 'a' && (element.attributes['href'] ?? '').contains('/broadcast/watch/'),
      );
      final href = watch?.attributes['href'] ?? '';
      final steamId = SteambroadcastEndpoints.watchIdOf(href);
      if (steamId == null || seen.contains(steamId)) continue;
      try {
        broadcasts.add(_card(card, steamId));
        seen.add(steamId);
      } on SteambroadcastFailure {
        // One card that cannot be read only loses itself.
      }
    }
    String? hidden(String name) =>
        root.first((element) => element.name == 'input' && element.attributes['name'] == name)?.attributes['value'];
    final nextPage = int.tryParse(hidden('p') ?? '');
    final nextOffset = int.tryParse(hidden('broadcastsoffset') ?? '');
    return SteambroadcastPage(
      broadcasts: broadcasts,
      hasMore: broadcasts.isNotEmpty && nextPage == page + 1 && nextOffset == page * SteambroadcastEndpoints.pageSize,
    );
  }

  static SteambroadcastBroadcast _card(SteambroadcastHtml card, String steamId) {
    SteambroadcastHtml? classed(String name) => card.first((element) => element.hasClass(name));
    final contentType = _elementText(classed('apphub_CardContentType'));
    final game = _elementText(classed('apphub_CardContentTitle'));
    final authorLink = card.first(
      (element) => element.name == 'a' && element.insideClass('apphub_CardContentAuthorName'),
    );
    final broadcaster = [
      SteambroadcastJson.clean(authorLink?.text ?? ''),
      _elementText(classed('apphub_CardContentAuthorName')),
    ].firstWhere((name) => name.isNotEmpty, orElse: () => '');
    final avatarImage = card.first((element) => element.name == 'img' && element.insideClass('appHubIconHolder'));
    return SteambroadcastBroadcast(
      steamId: steamId,
      broadcaster: broadcaster == steamId ? '' : broadcaster,
      title: _stripBroadcastSuffix(contentType.isEmpty ? game : contentType),
      game: game,
      cover: thumbnail(classed('apphub_CardContentPreviewImage')?.attributes['src'], steamId),
      avatar: avatar(avatarImage?.attributes['src']),
      viewers: viewerCount(_elementText(classed('apphub_CardContentViewers'))),
      state: SteambroadcastState.live,
    );
  }

  /// `6,763 viewers` → 6763: digits with `,`, `.`, `_` or spaces, then
  /// `viewer(s)`; null for anything else or more than 12 digits.
  static int? viewerCount(String text) {
    final match = RegExp(r'^\s*([0-9][0-9,._\s]*)\s+viewers?\b', caseSensitive: false).firstMatch(text);
    final digits = match?.group(1)?.replaceAll(RegExp('[^0-9]'), '') ?? '';
    if (digits.isEmpty || digits.length > 12) return null;
    return int.tryParse(digits);
  }

  /// The broadcasts of [broadcasts] whose id contains [query] (trimmed and
  /// lower-cased by the caller), or whose name, title or game does, case
  /// ignored (the search over one directory page).
  static List<SteambroadcastBroadcast> filter(List<SteambroadcastBroadcast> broadcasts, String query) => [
    for (final broadcast in broadcasts)
      if (broadcast.steamId.contains(query) ||
          broadcast.broadcaster.toLowerCase().contains(query) ||
          broadcast.title.toLowerCase().contains(query) ||
          broadcast.game.toLowerCase().contains(query))
        broadcast,
  ];

  // Room ----------------------------------------------------------------------

  static final RegExp _pageTitle = RegExp(r'^Steam Community\s*::\s*(.+?)\s*::\s*Broadcast$', caseSensitive: false);

  /// The watch page of [steamId] (the fallback when the mini profile fails):
  /// its application config must name the same account (`data-broadcastsinfo`,
  /// JSON), the broadcaster's name is in `og:title` (else `<title>`,
  /// `Steam Community :: <name> :: Broadcast`); '' when it names nobody or
  /// only the id. A page without the config is not-found, another account or
  /// a broken config api-changed. An account that does not exist still has a
  /// page; its title names the id.
  static String broadcaster(String body, {required String steamId, int status = 200}) {
    const what = 'watch page';
    SteambroadcastJson.checkBody(body, what, status);
    final root = SteambroadcastHtml.parse(body);
    final config = root
        .first((element) => element.attributes['id'] == 'application_config')
        ?.attributes['data-broadcastsinfo'];
    if (config == null) {
      throw SteambroadcastFailure(SteambroadcastFailureKind.notFound, '$what of $steamId has no broadcast config');
    }
    Object? decoded;
    try {
      decoded = jsonDecode(config);
    } on FormatException {
      throw SteambroadcastFailure(
        SteambroadcastFailureKind.apiChanged,
        '$what: broadcast config is not JSON (${SteambroadcastJson.snippet(config)})',
      );
    }
    if (decoded is! Map) {
      throw const SteambroadcastFailure(
        SteambroadcastFailureKind.apiChanged,
        '$what: broadcast config is not an object',
      );
    }
    final owner = SteambroadcastJson.requiredText(decoded['steamid'], '$what steamid');
    if (owner != steamId) {
      throw SteambroadcastFailure(SteambroadcastFailureKind.apiChanged, '$what of $steamId names $owner');
    }
    final title =
        root
            .first((element) => element.name == 'meta' && element.attributes['property'] == 'og:title')
            ?.attributes['content'] ??
        root.first((element) => element.name == 'title')?.text ??
        '';
    final name = _pageTitle.firstMatch(title)?.group(1)?.trim() ?? '';
    return name == steamId ? '' : name;
  }

  /// The mini profile of [steamId]: `persona_name` (HTML characters decoded;
  /// '' when it is only the id, which Steam writes for an account that does
  /// not exist) and `avatar_url`. Not an object, or a `persona_name` that is
  /// not text, is api-changed.
  static SteambroadcastProfile profile(String body, {required String steamId, int status = 200}) {
    const what = 'miniprofile';
    final decoded = SteambroadcastJson.object(body, what, status);
    final name = decoded['persona_name'];
    if (name is! String) {
      throw SteambroadcastFailure(SteambroadcastFailureKind.apiChanged, '$what: persona_name is $name');
    }
    final cleaned = SteambroadcastJson.clean(decodeHtmlEntities(name));
    final avatarUrl = decoded['avatar_url'];
    return (name: cleaned == steamId ? '' : cleaned, avatar: avatar(avatarUrl is String ? avatarUrl : null));
  }

  /// `getbroadcastinfo` of [steamId] (the state of a refresh): `success: 42`
  /// is offline; `success: 1` is live, or a replay with `is_replay`, when
  /// `is_online`, else offline; any other `success` is api-changed. While
  /// online: the title (`title`, else `app_title`), the game (`app_title`,
  /// HTML characters decoded), the cover (`thumbnail_url`) and
  /// `viewer_count`. Fields that only fill the card are left empty when
  /// malformed. The name and avatar are [profile]'s.
  static SteambroadcastBroadcast info(
    String body, {
    required String steamId,
    SteambroadcastProfile profile = (name: '', avatar: ''),
    int status = 200,
  }) {
    const what = 'getbroadcastinfo';
    final decoded = SteambroadcastJson.object(body, what, status);
    final success = _integer(decoded['success']);
    if (success != 1 && success != 42) {
      throw SteambroadcastFailure(SteambroadcastFailureKind.apiChanged, '$what: success ${decoded['success']}');
    }
    final online = success == 1 && SteambroadcastJson.flag(decoded['is_online']);
    if (!online) {
      return SteambroadcastBroadcast(
        steamId: steamId,
        state: SteambroadcastState.offline,
        broadcaster: profile.name,
        avatar: profile.avatar,
      );
    }
    final game = SteambroadcastJson.lenientText(decoded['app_title']);
    final title = SteambroadcastJson.lenientText(decoded['title']);
    final coverUrl = decoded['thumbnail_url'];
    return SteambroadcastBroadcast(
      steamId: steamId,
      state: SteambroadcastJson.flag(decoded['is_replay']) ? SteambroadcastState.replay : SteambroadcastState.live,
      broadcaster: profile.name,
      avatar: profile.avatar,
      title: title.isEmpty ? game : title,
      game: game,
      cover: thumbnail(coverUrl is String ? coverUrl : null, steamId),
      viewers: SteambroadcastJson.viewers(decoded['viewer_count']),
    );
  }

  /// `getbroadcastmpd` of [steamId]: the state of `success` (see
  /// [SteambroadcastState]; `ready` with `is_replay` is a replay), its
  /// restriction (`none` for `ready`, subscribers only for
  /// `missing_subscription`), the title ('' when empty), `num_viewers` and
  /// `broadcastid`; for `ready` the HLS master of `hls_url` with
  /// `cdn_auth_url_parameters` appended. A missing or non-text `success` or
  /// `title` is api-changed. A `ready` answer whose `hls_url` or CDN
  /// parameters break the address rules keeps its state and carries the
  /// reason as [SteambroadcastBroadcast.mediaError]. The name and avatar are
  /// [profile]'s.
  static SteambroadcastBroadcast broadcast(
    String body, {
    required String steamId,
    SteambroadcastProfile profile = (name: '', avatar: ''),
    int status = 200,
  }) {
    const what = 'getbroadcastmpd';
    final decoded = SteambroadcastJson.object(body, what, status);
    final success = SteambroadcastJson.requiredText(decoded['success'], '$what success').toLowerCase();
    final (state, restriction) = switch (success) {
      'ready' => (
        SteambroadcastJson.flag(decoded['is_replay']) ? SteambroadcastState.replay : SteambroadcastState.live,
        LiveRestriction.none,
      ),
      'missing_subscription' => (SteambroadcastState.live, LiveRestriction.subscribersOnly),
      'unavailable' || 'offline' || 'not_live' || 'no_broadcast' => (SteambroadcastState.offline, null),
      'user_restricted' => (SteambroadcastState.accountRestricted, null),
      _ => (SteambroadcastState.unknown, null),
    };
    Uri? master;
    SteambroadcastFailure? mediaError;
    if (success == 'ready') {
      try {
        master = withCdnAuth(masterOf(decoded['hls_url'], steamId), decoded['cdn_auth_url_parameters']);
      } on SteambroadcastFailure catch (error) {
        mediaError = error;
      }
    }
    final broadcastId = switch (decoded['broadcastid']) {
      final String id when RegExp(r'^[1-9][0-9]{0,19}$').hasMatch(id) => id,
      final int id when id > 0 => '$id',
      _ => null,
    };
    return SteambroadcastBroadcast(
      steamId: steamId,
      broadcaster: profile.name,
      avatar: profile.avatar,
      title: SteambroadcastJson.optionalText(decoded['title'], '$what title'),
      viewers: SteambroadcastJson.viewers(decoded['num_viewers']),
      state: state,
      restriction: restriction,
      broadcastId: broadcastId,
      master: master,
      mediaError: mediaError,
    );
  }

  /// The Steam id in the XML of a profile's custom address:
  /// `<steamID64>`; null when Steam says the profile does not exist
  /// (`<error>`); anything else is api-changed.
  static String? steamIdOfProfileXml(String body, {int status = 200}) {
    const what = 'profile XML';
    SteambroadcastJson.checkBody(body, what, status);
    final id = RegExp(r'<steamID64>\s*(\d+)\s*</steamID64>').firstMatch(body)?.group(1);
    if (id != null && SteambroadcastEndpoints.isSteamId(id)) return id;
    if (RegExp(r'<response>\s*<error>').hasMatch(body)) return null;
    throw SteambroadcastFailure(
      SteambroadcastFailureKind.apiChanged,
      '$what: no steamID64 (${SteambroadcastJson.snippet(body)})',
    );
  }

  // HLS master ----------------------------------------------------------------

  /// The check of the HLS master at [master]: `#EXTM3U`, at most
  /// [SteambroadcastEndpoints.masterLimit] characters, 1–16 variants, and
  /// every variant and rendition an https URL on the master's host, under
  /// `/broadcast/<steamId>/…/hls_manifest/0/`, with a Steam
  /// `broadcast_origin`. Returns the video codec the variants name (`avc`,
  /// `hevc`, or null when they name none or several); anything else is
  /// api-changed.
  static LiveStreamCodec? checkMaster(String body, {required Uri master, required String steamId, int status = 200}) {
    const what = 'HLS master';
    SteambroadcastJson.checkBody(body, what, status);
    if (body.length > SteambroadcastEndpoints.masterLimit || !body.trimLeft().startsWith('#EXTM3U')) {
      throw SteambroadcastFailure(
        SteambroadcastFailureKind.apiChanged,
        '$what: not an HLS master (${SteambroadcastJson.snippet(body)})',
      );
    }
    final lines = const LineSplitter().convert(body);
    final codecs = <LiveStreamCodec>{};
    var variants = 0;
    for (var index = 0; index < lines.length; index++) {
      final line = lines[index].trim();
      if (line.startsWith('#EXT-X-STREAM-INF:')) {
        variants++;
        var next = index + 1;
        while (next < lines.length && lines[next].trim().startsWith('#')) {
          next++;
        }
        if (next >= lines.length || !validChild(lines[next].trim(), steamId, master.host)) {
          throw SteambroadcastFailure(
            SteambroadcastFailureKind.apiChanged,
            '$what: variant ${next < lines.length ? SteambroadcastJson.snippet(lines[next]) : 'missing'}',
          );
        }
        final codec = hlsVideoCodecOf(videoCodecs(line));
        if (codec != null) codecs.add(codec);
      }
      if (line.startsWith('#EXT-X-MEDIA:')) {
        final uri = RegExp('URI="([^"]+)"').firstMatch(line)?.group(1);
        if (uri == null || !validChild(uri, steamId, master.host)) {
          throw SteambroadcastFailure(
            SteambroadcastFailureKind.apiChanged,
            '$what: rendition ${SteambroadcastJson.snippet(line)}',
          );
        }
      }
    }
    if (variants < 1 || variants > 16) {
      throw SteambroadcastFailure(SteambroadcastFailureKind.apiChanged, '$what: $variants variants');
    }
    return codecs.length == 1 ? codecs.single : null;
  }

  /// The id and name of a variant [height] pixels high at [frameRate], as
  /// Steam's player writes it: `<height>p`, with the rounded frame rate
  /// above 30 fps (`1080p60`).
  static String variantId(int height, double frameRate) => '${height}p${frameRate > 30 ? frameRate.round() : ''}';

  static final RegExp _variantId = RegExp(r'^[1-9][0-9]{0,4}p(?:[1-9][0-9]{0,3})?$');

  /// Whether [id] has the shape of a variant id ([variantId]).
  static bool isVariantId(String id) => _variantId.hasMatch(id);

  /// The variants of [text], the master at [master] that passed
  /// [checkMaster], best first (height, frame rate, then bandwidth), one per
  /// [variantId] (the highest bandwidth), when there are at least two
  /// (Steam's player too offers a choice only then). A variant without a
  /// resolution, or whose audio group the master does not carry, is left
  /// out; a master the shared parser refuses gives none, which leaves the
  /// adaptive quality alone.
  static List<SteambroadcastVariant> variants(String text, {required Uri master}) {
    final parsed = parseHlsMaster(text, masterUrl: master);
    if (parsed == null) return const [];
    final audioGroups = {
      for (final rendition in parsed.master.renditions)
        if (rendition.type == HlsMediaType.audio) rendition.groupId,
    };
    final byId = <String, SteambroadcastVariant>{};
    for (final variant in parsed.master.variants) {
      final size = variant.width == null || variant.height == null
          ? null
          : (width: variant.width!, height: variant.height!);
      if (size == null) continue;
      final audioGroup = variant.audioGroupId;
      if (audioGroup != null && !audioGroups.contains(audioGroup)) continue;
      final frameRate = variant.frameRate ?? 0;
      final choice = SteambroadcastVariant(
        id: variantId(size.height, frameRate),
        width: size.width,
        height: size.height,
        frameRate: frameRate,
        bandwidth: variant.bandwidth,
        codec: hlsVideoCodecOf(variant.codecs),
      );
      final current = byId[choice.id];
      if (current == null || choice.bandwidth > current.bandwidth) byId[choice.id] = choice;
    }
    if (byId.length < 2) return const [];
    return List.unmodifiable(
      byId.values.toList()..sort((a, b) {
        final byHeight = b.height.compareTo(a.height);
        if (byHeight != 0) return byHeight;
        final byRate = b.frameRate.compareTo(a.frameRate);
        return byRate != 0 ? byRate : b.bandwidth.compareTo(a.bandwidth);
      }),
    );
  }

  // Rooms, qualities, lines ---------------------------------------------------

  /// The card or room of [broadcast]: the Steam id as room and anchor id;
  /// the title, name, avatar, cover and game ('' when unknown); the viewers
  /// as concurrent audience; the state (a restricted account is banned,
  /// waiting and unknown are unknown, never offline) and restriction; the
  /// notice; [data] as the room's stream handle.
  static LiveRoom room(SteambroadcastBroadcast broadcast, {SteambroadcastRoomData? data}) {
    final viewers = broadcast.viewers;
    final liveStatus = switch (broadcast.state) {
      SteambroadcastState.live => LiveStatus.live,
      SteambroadcastState.replay => LiveStatus.replay,
      SteambroadcastState.offline => LiveStatus.offline,
      SteambroadcastState.accountRestricted => LiveStatus.banned,
      SteambroadcastState.unknown => LiveStatus.unknown,
    };
    return LiveRoom.normalized(
      platform: siteId,
      roomId: broadcast.steamId,
      content: RoomContent.of(
        title: broadcast.title,
        coverUrl: broadcast.cover,
        notice: broadcast.state == SteambroadcastState.accountRestricted
            ? SteambroadcastEndpoints.restrictedNotice
            : SteambroadcastEndpoints.chatNotice,
        platformTags: broadcast.game.isEmpty ? const [] : [broadcast.game],
      ),
      anchor: LiveAnchor.normalized(
        platform: siteId,
        anchorId: broadcast.steamId,
        name: broadcast.broadcaster,
        avatarUrl: broadcast.avatar,
        profileUrl: SteambroadcastEndpoints.link(broadcast.steamId),
        liveStatus: liveStatus,
      ),
      audience: RoomAudience.of(
        onlineViewers: viewers,
        primaryMetric: viewers == null ? LiveAudienceMetricType.unknown : LiveAudienceMetricType.onlineViewers,
      ),
      broadcast: RoomBroadcast.of(liveStatus: liveStatus, restriction: broadcast.restriction),
      links: RoomLinks.of(webUrl: SteambroadcastEndpoints.link(broadcast.steamId)),
      runtime: RoomRuntime.of(streamHandle: data),
    );
  }

  /// The room data of [broadcast]: the master and its variants only when it
  /// was checked.
  static SteambroadcastRoomData roomData(SteambroadcastBroadcast broadcast) => SteambroadcastRoomData(
    steamId: broadcast.steamId,
    state: broadcast.state,
    restriction: broadcast.restriction,
    master: broadcast.masterChecked ? broadcast.master : null,
    codec: broadcast.codec,
    variants: broadcast.masterChecked ? broadcast.variants : const [],
    mediaError: broadcast.mediaError,
  );

  /// The one line of a checked master: HLS, the codec it names, no headers
  /// (the CDN answers without them) and no lease (no expiry in the address;
  /// Steam needs no heartbeat). A variant's quality plays the same line —
  /// the master restricted to a variant is not expressible as a line here —
  /// and names the variant as its label, with the variant's codec.
  static LivePlayLine line(SteambroadcastRoomData data, String wanted) {
    final error = data.streamError;
    if (error != null) throw error;
    final variant = data.variants.where((entry) => entry.id == wanted).firstOrNull;
    if (wanted != SteambroadcastEndpoints.qualityId && variant == null) {
      throw SteambroadcastFailure(SteambroadcastFailureKind.streamUnavailable, 'quality $wanted is not offered');
    }
    return LivePlayLine.of(
      url: '${data.master}',
      format: LiveStreamFormat.hls,
      formatSource: LivePlayFormatSource.declared,
      codec: variant?.codec ?? data.codec,
      lineLabel: variant?.id,
      geometry: variant == null
          ? null
          : PlayGeometry.of(
              width: variant.width,
              height: variant.height,
              frameRate: variant.frameRate > 0 ? variant.frameRate.round() : null,
              bitrateKbps: variant.bandwidth > 0 ? variant.bandwidth ~/ 1000 : null,
            ),
    );
  }
}

/// The `CODECS` attribute of an `#EXT-X-STREAM-INF` line, or null.
String? videoCodecs(String line) => RegExp('CODECS="([^"]*)"').firstMatch(line)?.group(1);

/// The `hls_url` of `getbroadcastmpd` as a master address: https on
/// `steamcontent.com` or a subdomain (port 443), no user info or fragment,
/// the path `/broadcast/<steamId>/<digits>/hls_manifest/0/<host>/master.m3u8`
/// (the same host), a Steam `broadcast_origin`; at most 8192 characters
/// without spaces or control characters. Anything else is api-changed.
Uri masterOf(Object? value, String steamId) {
  final raw = SteambroadcastJson.requiredText(value, 'getbroadcastmpd hls_url');
  final uri = raw.length > 8192 || RegExp(r'[\s\x00-\x1f]').hasMatch(raw) ? null : Uri.tryParse(raw);
  final host = uri?.host.toLowerCase() ?? '';
  final path = RegExp('^/broadcast/${RegExp.escape(steamId)}/[1-9][0-9]{0,19}/hls_manifest/0/([^/]+)/master[.]m3u8\$')
      .firstMatch(uri?.path ?? '');
  if (uri == null ||
      uri.scheme != 'https' ||
      uri.userInfo.isNotEmpty ||
      uri.hasFragment ||
      !(host == 'steamcontent.com' || host.endsWith('.steamcontent.com')) ||
      (uri.hasPort && uri.port != 443) ||
      path == null ||
      path.group(1)?.toLowerCase() != host ||
      !steamOrigin(uri.queryParameters['broadcast_origin'])) {
    throw SteambroadcastFailure(
      SteambroadcastFailureKind.apiChanged,
      'getbroadcastmpd: hls_url ${SteambroadcastJson.snippet(raw)}',
    );
  }
  return uri;
}

/// `cdn_auth_url_parameters` (text, leading `&` and `?` removed) appended to
/// [master] with `&`; null or blank adds nothing. At most 4096 characters
/// without spaces or `#`, 1–16 names of `[A-Za-z0-9_.~-]`, each with 1–8
/// non-empty values of at most 2048 characters, no `broadcast_origin`;
/// anything else is api-changed.
Uri withCdnAuth(Uri master, Object? value) {
  if (value == null) return master;
  if (value is! String) {
    throw SteambroadcastFailure(
      SteambroadcastFailureKind.apiChanged,
      'getbroadcastmpd: cdn_auth_url_parameters is $value',
    );
  }
  var raw = value.trim();
  if (raw.isEmpty) return master;
  while (raw.startsWith('&') || raw.startsWith('?')) {
    raw = raw.substring(1);
  }
  final problem = SteambroadcastFailure(
    SteambroadcastFailureKind.apiChanged,
    'getbroadcastmpd: cdn_auth_url_parameters ${SteambroadcastJson.snippet(value)}',
  );
  if (raw.isEmpty || raw.length > 4096 || RegExp(r'[\s#]').hasMatch(raw)) throw problem;
  final Map<String, List<String>> parameters;
  try {
    parameters = Uri(query: raw).queryParametersAll;
  } on FormatException {
    throw problem;
  }
  if (parameters.isEmpty || parameters.length > 16 || parameters.containsKey('broadcast_origin')) throw problem;
  for (final MapEntry(:key, :value) in parameters.entries) {
    if (!RegExp(r'^[A-Za-z0-9_.~-]{1,128}$').hasMatch(key) ||
        value.isEmpty ||
        value.length > 8 ||
        value.any((item) => item.isEmpty || item.length > 2048)) {
      throw problem;
    }
  }
  return Uri.parse('$master&$raw');
}

/// A child of a checked master: an https URL on [host] under
/// `/broadcast/<steamId>/` with `/hls_manifest/0/` and a Steam
/// `broadcast_origin`.
bool validChild(String raw, String steamId, String host) {
  final uri = Uri.tryParse(raw);
  return uri != null &&
      uri.scheme == 'https' &&
      uri.userInfo.isEmpty &&
      !uri.hasFragment &&
      uri.host.toLowerCase() == host.toLowerCase() &&
      uri.path.startsWith('/broadcast/$steamId/') &&
      uri.path.contains('/hls_manifest/0/') &&
      steamOrigin(uri.queryParameters['broadcast_origin']);
}

/// `steamserver.net` or a subdomain, at most 255 characters.
bool steamOrigin(String? value) {
  if (value == null || value.length > 255) return false;
  final host = value.toLowerCase();
  return host == 'steamserver.net' || host.endsWith('.steamserver.net');
}

/// An https thumbnail on `steambroadcast.akamaized.net` under
/// `/broadcast/<steamId>/`, no user info or fragment; '' otherwise. An
/// over-long text is api-changed, like any cleaned text.
String thumbnail(String? value, String steamId) {
  final uri = Uri.tryParse(SteambroadcastJson.clean(value ?? ''));
  if (uri == null ||
      uri.scheme != 'https' ||
      uri.userInfo.isNotEmpty ||
      uri.hasFragment ||
      uri.host.toLowerCase() != 'steambroadcast.akamaized.net' ||
      !uri.path.startsWith('/broadcast/$steamId/')) {
    return '';
  }
  return '$uri';
}

/// Steam's default avatar (the question mark), which is no avatar.
const String _defaultAvatar = 'fef49e7fa7e1997310d705b2a6158ff8dc1cdfeb';

final RegExp _avatarPath = RegExp(r'^/([0-9a-f]{40})(?:_medium|_full)?\.jpg$');

/// An avatar: an https URL with a host, no user info or fragment. A Steam
/// avatar (`avatars.*.steamstatic.com/<hash>.jpg`, 32 px on the cards) is
/// taken at its 184 px size `<hash>_full.jpg`, which the mini profile names;
/// Steam's default avatar is ''. '' otherwise. An over-long text is
/// api-changed, like any cleaned text.
String avatar(String? value) {
  final uri = Uri.tryParse(SteambroadcastJson.clean(value ?? ''));
  if (uri == null || uri.scheme != 'https' || uri.host.isEmpty || uri.userInfo.isNotEmpty || uri.hasFragment) {
    return '';
  }
  final host = uri.host.toLowerCase();
  final hash = host.startsWith('avatars.') && host.endsWith('.steamstatic.com')
      ? _avatarPath.firstMatch(uri.path)?.group(1)
      : null;
  if (hash == null) return '$uri';
  if (hash == _defaultAvatar) return '';
  return '${Uri.https(uri.authority, '/${hash}_full.jpg')}';
}

/// An integer, or an integer text; null otherwise.
int? _integer(Object? value) => switch (value) {
  final int number => number,
  final String text => int.tryParse(text.trim()),
  _ => null,
};

String _stripBroadcastSuffix(String value) =>
    value.replaceFirst(RegExp(r':\s*Broadcast\s*$', caseSensitive: false), '').trim();

String _elementText(SteambroadcastHtml? element) => element == null ? '' : SteambroadcastJson.clean(element.text);
