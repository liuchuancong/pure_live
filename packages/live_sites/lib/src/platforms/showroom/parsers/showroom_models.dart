import 'package:live_sites/src/models/enums/live_restriction.dart';
import 'package:meta/meta.dart';

// Platform-internal code: constructor-name and doc verbosity rules that
// govern the public surface are relaxed here.
// ignore_for_file: unnecessary_type_name_in_constructor

/// One live room of the `onlives` snapshot (the reference's `ShowroomLive`).
@immutable
final class ShowroomLive {
  /// Creates the live.
  const ShowroomLive({
    required this.roomId,
    required this.roomUrlKey,
    required this.name,
    required this.cover,
    required this.genreId,
    required this.genreName,
    this.followers,
    this.views,
    this.telop = '',
    this.startedAt,
    this.restriction,
  });

  /// `room_id`.
  final int roomId;

  /// `room_url_key`: the public room key of `/r/{key}` links.
  final String roomUrlKey;

  /// `main_name`: the room's name.
  final String name;

  /// `image_square` (else `image`) when it is a SHOWROOM https image.
  final String cover;

  /// `genre_id` of the row (the area the card carries; the reference read and
  /// checked it without keeping it).
  final int genreId;

  /// The live's own `genre_name` (Japanese, `ミュージック`).
  final String genreName;

  /// `follower_num`.
  final int? followers;

  /// `view_num`: the broadcast's visits, shown as total viewers.
  final int? views;

  /// `telop`: the caption the streamer sets, often empty.
  final String telop;

  /// `started_at` (Unix seconds): when the broadcast started.
  final DateTime? startedAt;

  /// The restriction `premium_room_type` shows: 0 is no restriction,
  /// anything else is not known.
  final LiveRestriction? restriction;
}

/// One genre of the snapshot and its live rooms in the site's order.
@immutable
final class ShowroomGenre {
  /// Creates the genre.
  ShowroomGenre({required this.id, required this.name, required List<ShowroomLive> lives})
    : lives = List.unmodifiable(lives);

  /// `genre_id` (0 is Popularity).
  final int id;

  /// `genre_name` of the group (English: `Popularity`, `Music`).
  final String name;

  /// Its live rooms.
  final List<ShowroomLive> lives;
}

/// The `live/onlives` snapshot: every live room, grouped by genre.
@immutable
final class ShowroomSnapshot {
  /// Creates the snapshot.
  ShowroomSnapshot(List<ShowroomGenre> genres) : genres = List.unmodifiable(genres);

  /// Genres in the site's order.
  final List<ShowroomGenre> genres;

  /// Every live once, in genre order.
  Iterable<ShowroomLive> get uniqueLives sync* {
    final seen = <int>{};
    for (final genre in genres) {
      for (final live in genre.lives) {
        if (seen.add(live.roomId)) yield live;
      }
    }
  }

  /// The recommendations: the Popularity genre (0), else every live once.
  List<ShowroomLive> get popular =>
      genres.where((genre) => genre.id == 0).firstOrNull?.lives ?? uniqueLives.toList(growable: false);

  /// The lives of genre [id], or null when the snapshot has no such genre.
  List<ShowroomLive>? genre(int id) => genres.where((genre) => genre.id == id).firstOrNull?.lives;
}

/// `room/profile` of one room, and `current_live_started_at`, the start of
/// the room's broadcast: only meaningful while it is live (an offline room
/// gives its next scheduled or its last start).
typedef ShowroomProfile = ({
  int roomId,
  String roomUrlKey,
  String name,
  String cover,
  int genreId,
  String genreName,
  int? followers,
  int? views,
  String description,
  DateTime? liveStartedAt,
});

/// What a comment connection needs to join one SHOWROOM broadcast: the
/// comment server and the broadcast's key, both from `live/live_info`.
///
/// The connection is `wss://<host>/` with the site's origin and the desktop
/// UA, the text frame `SUB\t<key>` at the open, `PING\tshowroom` every 60 s
/// and `MSG\t<key>\t<json>` frames back. The key is the same for every
/// viewer and changes with each broadcast, so a room that went live again
/// needs a fresh detail.
@immutable
final class ShowroomDanmakuArgs {
  /// Creates the arguments.
  const ShowroomDanmakuArgs({required this.roomId, required this.host, required this.key});

  /// The numeric room id.
  final String roomId;

  /// `bcsvr_host`: the comment server, a host name on `showroom-live.com`,
  /// lower case.
  final String host;

  /// `bcsvr_key`: the broadcast's comment key (`6e6c686835796846:23483509`),
  /// without white space or control characters.
  final String key;

  @override
  String toString() => 'ShowroomDanmakuArgs($roomId, $host)';
}

/// What `live/live_info` says about a room: whether it is live and, when it
/// is, its restriction (0 is no restriction, anything else not known) and
/// comment arguments (null when the answer has no usable comment server).
typedef ShowroomLiveInfo = ({bool live, LiveRestriction? restriction, ShowroomDanmakuArgs? danmaku});

/// One gift of a room's table (`live/gift_list`).
@immutable
final class ShowroomGiftInfo {
  /// Creates the gift.
  const ShowroomGiftInfo({required this.name, required this.point, required this.free, this.image});

  /// `gift_name`.
  final String name;

  /// `point`: what one costs in SHOWROOM points (a free gift's is its
  /// weight in the ranking, not money).
  final int point;

  /// `free`: a free gift (stars, seeds).
  final bool free;

  /// `image`, an https picture on a SHOWROOM host, or null.
  final Uri? image;

  @override
  bool operator ==(Object other) =>
      other is ShowroomGiftInfo &&
      other.name == name &&
      other.point == point &&
      other.free == free &&
      other.image == image;

  @override
  int get hashCode => Object.hash(name, point, free, image);

  @override
  String toString() => 'ShowroomGiftInfo($name, $point${free ? ', free' : ''})';
}

/// The gifts of a SHOWROOM room by gift id (`live/gift_list`).
final class ShowroomGiftCatalog {
  /// Creates the catalog.
  ShowroomGiftCatalog(Map<String, ShowroomGiftInfo> gifts) : _gifts = Map.unmodifiable(gifts);

  const ShowroomGiftCatalog._empty() : _gifts = const {};

  /// No gifts.
  static const ShowroomGiftCatalog empty = ShowroomGiftCatalog._empty();

  final Map<String, ShowroomGiftInfo> _gifts;

  /// The gift [id], or null.
  ShowroomGiftInfo? operator [](String id) => _gifts[id];

  /// How many gifts.
  int get length => _gifts.length;

  @override
  String toString() => 'ShowroomGiftCatalog($length)';
}

/// One `streaming_url_list` row that could be read: its HLS URL and the
/// quality tier it serves.
typedef ShowroomTier = ({String url, LivePlayQualityData quality});

/// The quality of one tier: the label, the id `{type}:{id}:{quality}`, the
/// platform's own order (the adaptive master 自动 is below every `hls` tier)
/// and the row type that named the transport.
typedef LivePlayQualityData = ({String label, String id, int order, String type});

/// What room entry learnt about a live room's streams (the reference's
/// `ShowroomRoomData`): the `streaming_url_list` rows as answered, checked
/// only when played.
final class ShowroomStreamData {
  /// Creates the data.
  const ShowroomStreamData({required this.roomId, this.rows, this.offline = false});

  /// The numeric room id the data belongs to.
  final String roomId;

  /// `streaming_url_list` of `live/streaming_url` at room entry, not yet
  /// checked; null when the room is offline or the request failed (the
  /// qualities then ask again — unless [offline] said there is nothing).
  final List<Object?>? rows;

  /// Whether room entry's `live/live_info` said the room is offline: the
  /// qualities are a content-unavailable error without a request.
  final bool offline;
}
