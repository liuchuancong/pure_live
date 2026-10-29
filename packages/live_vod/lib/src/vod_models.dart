// The video-on-demand models: what a source finds, what a page carries and
// what a player is handed. One file for every record so the client is only
// about talking to the platform.

/// One video a platform's search returned.
final class VodVideo {
  /// A video hit.
  const new({
    required this.id,
    required this.title,
    this.coverUrl,
    this.uploader,
    this.duration,
    this.playCount,
    this.danmakuCount,
    this.bvid,
    this.aid,
  });

  /// The source's own id (the bvid on Bilibili).
  final String id;

  /// The video's title, with the search's highlight markup stripped.
  final String title;

  /// The cover address; null when the source gave none.
  final String? coverUrl;

  /// The uploader's name.
  final String? uploader;

  /// The length.
  final Duration? duration;

  /// How many times it was played.
  final int? playCount;

  /// How many danmaku it holds.
  final int? danmakuCount;

  /// The bvid, for a source that separates ids.
  final String? bvid;

  /// The numeric aid, for a source that separates ids.
  final int? aid;
}

/// One quality a play answer offers.
final class VodQuality {
  /// A quality choice.
  const new({required this.qn, required this.label});

  /// The source's numeric quality id (Bilibili's `qn`).
  final int qn;

  /// The source's own name for it ("1080P 高清").
  final String label;
}

/// One part of a multi-part archive ("P1", "P2").
final class VodPart {
  /// A part.
  const new({required this.cid, required this.page, required this.title, this.duration});

  /// The part's cid, which play addresses are requested for.
  final int cid;

  /// Its 1-based position.
  final int page;

  /// Its own title.
  final String title;

  /// Its length, when the source gave one.
  final Duration? duration;
}

/// A playable address and what it expects.
final class VodPlayInfo {
  /// A play address.
  const new({
    required this.url,
    this.headers = const {},
    this.expiresAt,
    this.format = 'mp4',
    this.quality,
    this.qualities = const [],
    this.servedQuality,
    this.silent = false,
  });

  /// The address handed to the player.
  final String url;

  /// Headers a CDN requires (a referer, a user agent).
  final Map<String, String> headers;

  /// When the address stops working; null keeps it indefinitely.
  final DateTime? expiresAt;

  /// The container, as the player wants it named (`mp4`, `m4s`, `hls`).
  final String format;

  /// The source's own label for the quality, when it named one.
  final String? quality;

  /// The qualities the source will serve for this part, best first.
  final List<VodQuality> qualities;

  /// The qn the source actually served.
  final int? servedQuality;

  /// Whether the answer carries picture only — a DASH fallback without the
  /// audio track (the player says so instead of pretending it has sound).
  final bool silent;
}

/// A feed page: the videos it carried and whether another page follows.
final class VodVideoPage {
  /// A page of a browse feed.
  const new({required this.videos, this.hasMore = false});

  /// The videos, in the source's order.
  final List<VodVideo> videos;

  /// Whether the source says another page follows.
  final bool hasMore;
}

/// One archive's full detail: the `view` answer's metadata and its parts.
final class VodDetail {
  /// A detail record.
  const new({
    required this.bvid,
    required this.aid,
    required this.title,
    this.coverUrl,
    this.description = '',
    this.uploader,
    this.uploaderMid,
    this.uploaderAvatar,
    this.playCount,
    this.danmakuCount,
    this.likeCount,
    this.coinCount,
    this.favoriteCount,
    this.duration,
    this.parts = const [],
    this.publishedAt,
  });

  /// The archive's bvid.
  final String bvid;

  /// The archive's numeric aid.
  final int aid;

  /// The title.
  final String title;

  /// The cover.
  final String? coverUrl;

  /// The uploader's description, plain text.
  final String description;

  /// The uploader's name.
  final String? uploader;

  /// The uploader's numeric id.
  final int? uploaderMid;

  /// The uploader's avatar.
  final String? uploaderAvatar;

  /// How many times the archive was played.
  final int? playCount;

  /// How many danmaku it holds.
  final int? danmakuCount;

  /// How many likes it received.
  final int? likeCount;

  /// How many coins it received.
  final int? coinCount;

  /// How many favourites it received.
  final int? favoriteCount;

  /// The whole archive's length, when the source gave one.
  final Duration? duration;

  /// The parts, in order.
  final List<VodPart> parts;

  /// When it was published.
  final DateTime? publishedAt;
}

/// The failure a VOD source reports.
final class VodFailure implements Exception {
  /// A failure with the source's [message].
  const new(this.message, {this.statusCode});

  /// What the source said.
  final String message;

  /// The HTTP status, when the failure came with one.
  final int? statusCode;

  @override
  String toString() => 'VodFailure($message)';
}

/// The result of a search: the hits and whether another page exists.
final class VodSearchPage {
  /// A page of hits.
  const new({required this.videos, this.hasMore = false});

  /// The hits, in the source's order.
  final List<VodVideo> videos;

  /// Whether the source says another page follows.
  final bool hasMore;
}

/// One user a search returned.
final class VodUser {
  /// A user hit.
  const new({required this.mid, required this.name, this.avatar, this.sign = '', this.fans, this.videoCount});

  /// The user's numeric id.
  final int mid;

  /// The display name.
  final String name;

  /// The avatar address.
  final String? avatar;

  /// The one-line signature.
  final String sign;

  /// How many followers they have.
  final int? fans;

  /// How many videos they posted.
  final int? videoCount;
}

/// One page of user hits.
final class VodUserSearchPage {
  /// A page of users.
  const new({required this.users, required this.hasMore});

  /// The users.
  final List<VodUser> users;

  /// Whether another page follows.
  final bool hasMore;
}

/// One live room a search returned.
final class VodLiveRoom {
  /// A live room hit.
  const new({required this.roomId, required this.title, this.coverUrl, this.anchor, this.avatar, this.online});

  /// The room's numeric id.
  final int roomId;

  /// The room's title.
  final String title;

  /// The room's cover.
  final String? coverUrl;

  /// The anchor's display name.
  final String? anchor;

  /// The anchor's avatar.
  final String? avatar;

  /// How many viewers it holds.
  final int? online;
}

/// One page of live-room hits.
final class VodLiveRoomSearchPage {
  /// A page of rooms.
  const new({required this.rooms, required this.hasMore});

  /// The rooms.
  final List<VodLiveRoom> rooms;

  /// Whether another page follows.
  final bool hasMore;
}

/// One page of 番剧/影视 hits: the platform's own search names seasons, not
/// archives.
final class VodSeasonSearchPage {
  /// A page of seasons.
  const new({required this.seasons, required this.hasMore});

  /// The seasons.
  final List<VodSeason> seasons;

  /// Whether another page follows.
  final bool hasMore;
}

/// One audio rendition of an archive's first part, from the DASH ladder.
final class VodAudioStream {
  /// An audio stream.
  const new({required this.id, required this.url, this.bandwidth, this.codecs});

  /// The platform's numeric rendition id (Bilibili's `30216` 64k, `30232`
  /// 132k, `30280` 192k, `30250` Dolby, `30251` FLAC).
  final int id;

  /// The address handed to the player.
  final String url;

  /// The stream's bitrate in bits per second, when the answer says.
  final int? bandwidth;

  /// The codec string (`mp4a.40.2`, `fLaC`), when the answer says.
  final String? codecs;
}

/// The signed-in viewer as Bilibili's nav endpoint describes them, or a guest.
final class VodAccount {
  /// An account record.
  const new({required this.isLogin, this.mid, this.name, this.avatar});

  /// Whether a cookie authenticated the request.
  final bool isLogin;

  /// The numeric uid.
  final int? mid;

  /// The display name.
  final String? name;

  /// The avatar address.
  final String? avatar;
}

/// One page of the home recommendation feed.
final class VodRecommendPage {
  /// A page of recommendations.
  const new({required this.videos, required this.page});

  /// The videos, in the source's order.
  final List<VodVideo> videos;

  /// The page that was asked for.
  final int page;
}

/// One dynamic post.
final class VodDynamic {
  /// A dynamic entry.
  const new({
    required this.id,
    required this.author,
    this.avatar,
    this.text = '',
    this.coverUrl,
    this.publishedAt,
    this.bvid,
  });

  /// The post's own id.
  final String id;

  /// The author's display name.
  final String author;

  /// The author's avatar.
  final String? avatar;

  /// The post's words, plain text.
  final String text;

  /// The first picture of the post, when it has one.
  final String? coverUrl;

  /// When it was published.
  final DateTime? publishedAt;

  /// The video the post shares, when it shares one.
  final String? bvid;
}

/// One page of the dynamic feed.
final class VodDynamicPage {
  /// A page of posts.
  const new({required this.items, required this.hasMore, this.offset});

  /// The posts.
  final List<VodDynamic> items;

  /// The cursor the next page asks with; null when the feed is exhausted.
  final String? offset;

  /// Whether another page follows.
  final bool hasMore;
}

/// One comment under a video.
final class VodComment {
  /// A comment.
  const new({
    required this.id,
    required this.author,
    required this.message,
    this.avatar,
    this.likeCount,
    this.replyCount,
    this.createdAt,
  });

  /// The comment's own id.
  final int id;

  /// The author's display name.
  final String author;

  /// The author's avatar.
  final String? avatar;

  /// The comment's text.
  final String message;

  /// How many likes it received.
  final int? likeCount;

  /// How many replies it has.
  final int? replyCount;

  /// When it was posted.
  final DateTime? createdAt;
}

/// One page of a video's comments.
final class VodCommentPage {
  /// A page of comments.
  const new({required this.comments, required this.total, required this.hasMore});

  /// The comments.
  final List<VodComment> comments;

  /// How many comments the video has in total.
  final int total;

  /// Whether another page follows.
  final bool hasMore;
}

/// One PGC title (a season): what the cinema page's cards carry.
final class VodSeason {
  /// A season card.
  const new({
    required this.seasonId,
    required this.title,
    this.subtitle = '',
    this.coverUrl,
    this.rating,
    this.evaluate = '',
    this.playCount,
    this.followed = false,
    this.episodeId,
  });

  /// The season's id (the detail endpoint's key).
  final int seasonId;

  /// The title.
  final String title;

  /// The one-line subtitle (`更新至第 12 话`, `全 24 话`…).
  final String subtitle;

  /// The cover.
  final String? coverUrl;

  /// The score, as the source spells it.
  final String? rating;

  /// The editorial blurb.
  final String evaluate;

  /// How many times it was played, when the source says.
  final int? playCount;

  /// Whether the signed-in viewer follows it.
  final bool followed;

  /// The episode a card opens on, when the card names one.
  final int? episodeId;
}

/// One page of a PGC catalogue.
final class VodSeasonPage {
  /// A page of seasons.
  const new({required this.seasons, required this.hasMore, this.cursor = 0});

  /// The seasons.
  final List<VodSeason> seasons;

  /// The cursor the next page asks with.
  final int cursor;

  /// Whether another page follows.
  final bool hasMore;
}

/// One episode of a season.
final class VodEpisode {
  /// An episode.
  const new({
    required this.id,
    required this.title,
    required this.index,
    this.coverUrl,
    this.duration,
    this.cid,
    this.aid,
  });

  /// The episode id (`ep_id`), the player's key.
  final int id;

  /// The episode's title (usually the season's title and its number).
  final String title;

  /// Its number within the season ("1", "12", "SP1").
  final String index;

  /// Its cover.
  final String? coverUrl;

  /// Its length, when the source gives one.
  final Duration? duration;

  /// The episode's cid, which the play endpoint takes beside `ep_id`.
  final int? cid;

  /// The episode's archive id (`avid`), when the source gives one.
  final int? aid;
}

/// One season's page: its blurb and its episodes.
final class VodSeasonDetail {
  /// A season detail.
  const new({
    required this.seasonId,
    required this.title,
    this.coverUrl,
    this.evaluate = '',
    this.episodes = const [],
    this.publishedAt,
    this.followed = false,
  });

  /// The season's id.
  final int seasonId;

  /// The title.
  final String title;

  /// The cover.
  final String? coverUrl;

  /// The editorial blurb.
  final String evaluate;

  /// The episodes, in the source's order (the newest first for an ongoing
  /// series).
  final List<VodEpisode> episodes;

  /// When the season started airing.
  final DateTime? publishedAt;

  /// Whether the signed-in viewer follows it.
  final bool followed;
}
