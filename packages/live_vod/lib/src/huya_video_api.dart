import 'dart:convert';

import 'package:live_net/live_net.dart' show LiveHttp, LiveRequest, LiveResponse;
import 'package:live_vod/src/archive.dart' show ArchiveQuality, ArchiveVideo;
import 'package:live_vod/src/huya_ssr.dart' show HuyaSsr;
import 'package:live_vod/src/vod_models.dart' show VodFailure, VodVideo;

/// The station's video ids are decimal and fit the numbers it prints.
final RegExp _videoId = RegExp(r'^[1-9][0-9]{0,18}$');

/// The uploader ids are the same decimal numbers.
final RegExp _userId = RegExp(r'^[1-9][0-9]{0,18}$');

/// A channel id the listing paths accept: the station spells them as words,
/// numbers and the punctuation `cs:go` needs.
final RegExp _channelId = RegExp(r'^[A-Za-z0-9:_-]{1,32}$');

/// One video as the station's own cards carry it, without media credentials.
final class HuyaVideo implements ArchiveVideo {
  /// One video row.
  const new({
    required this.id,
    required this.title,
    this.cover = '',
    this.duration = Duration.zero,
    this.playCount = 0,
    this.danmakuCount = 0,
    this.publishedAt,
    this.channelId = '',
    this.channelName = '',
    this.uploaderId = '',
    this.uploaderName = '',
    this.uploaderAvatar = '',
    this.brief = '',
  });

  /// The station's `vid`.
  @override
  final String id;

  /// The title, its HTML entities decoded and its line breaks folded.
  @override
  final String title;

  /// The public cover.
  final String cover;

  @override
  final Duration duration;

  /// How many times the video was played.
  final int playCount;

  /// How many bullet comments it collected; zero when the station did not
  /// say, which its list rows do not.
  final int danmakuCount;

  /// When it was published.
  final DateTime? publishedAt;

  /// The channel the station filed it under.
  final String channelId;

  /// The channel's display name.
  final String channelName;

  /// The uploader's uid.
  final String uploaderId;

  /// The uploader's display name.
  final String uploaderName;

  /// The uploader's picture.
  final String uploaderAvatar;

  /// The video's own description, when the detail answer carries one.
  final String brief;

  /// The row as the shared card widgets already render one.
  VodVideo asVideo() => VodVideo(
    id: id,
    title: title,
    coverUrl: cover.isEmpty ? null : cover,
    duration: duration == Duration.zero ? null : duration,
    uploader: uploaderName.isEmpty ? null : uploaderName,
    uploaderAvatar: uploaderAvatar.isEmpty ? null : uploaderAvatar,
    playCount: playCount,
    danmakuCount: danmakuCount,
  );
}

/// One channel chip the station offers.
final class HuyaChannel {
  /// A channel.
  const new({required this.id, required this.name});

  /// The id the listing paths take.
  final String id;

  /// The display name.
  final String name;
}

/// One group of channels: the station's own top row (全部 / 手机游戏 / …).
final class HuyaChannelGroup {
  /// A group.
  const new({required this.setId, required this.title, required this.channels});

  /// The group's number, the listing's `set_id`.
  final int setId;

  /// The group's name.
  final String title;

  /// The channels in it, 全部 first as the station ships it.
  final List<HuyaChannel> channels;
}

/// One shelf of the station's home: a channel's own picks.
final class HuyaVideoShelf {
  /// A shelf.
  const new({required this.title, this.cover = '', this.channelId = '', this.setId = 0, this.videos = const []});

  /// The shelf's name.
  final String title;

  /// The shelf's own art.
  final String cover;

  /// The channel the shelf walks into; empty when it names none.
  final String channelId;

  /// The group the channel sits in, for the walk.
  final int setId;

  /// The videos in the station's order.
  final List<HuyaVideo> videos;
}

/// The station's home as one answer.
final class HuyaVideoHome {
  /// The home.
  const new({required this.shelves});

  /// The shelves, top to bottom.
  final List<HuyaVideoShelf> shelves;
}

/// The order a listing walks in, as the station's own path segment.
enum HuyaVideoOrder {
  /// 最热视频.
  hot('hot'),

  /// 最新发布.
  new_('new'),

  /// 最多播放.
  most('most');

  new(this.key);

  /// The segment the listing path carries.
  final String key;
}

/// One page of a listing.
final class HuyaVideoList {
  /// A page.
  const new({required this.videos, required this.page, required this.hasMore, this.total = 0});

  /// The rows, in the station's order.
  final List<HuyaVideo> videos;

  /// The page the answer names.
  final int page;

  /// Whether another page follows.
  final bool hasMore;

  /// How many rows the listing holds in all.
  final int total;
}

/// One stand on the station's ranking boards.
final class HuyaRankBoard {
  /// A board.
  const new({required this.id, required this.name});

  /// The board's channel id.
  final String id;

  /// The board's name.
  final String name;
}

/// One page of a board.
final class HuyaRank {
  /// A page.
  const new({required this.videos, required this.page, required this.hasMore, this.total = 0, this.updatedAt});

  /// The rows, best first.
  final List<HuyaVideo> videos;

  /// The page the answer names.
  final int page;

  /// Whether another page follows.
  final bool hasMore;

  /// How many videos the board holds in all.
  final int total;

  /// When the station last recomputed the board.
  final DateTime? updatedAt;
}

/// One permitted rendition, freshly resolved for playback. The address is
/// signed and transient; the id is the station's own definition, and is the
/// only part ever held across a session.
final class HuyaVideoQuality implements ArchiveQuality {
  /// A rendition.
  const new({
    required this.id,
    required this.label,
    required this.url,
    this.format = 'mp4',
    this.height = 0,
    this.hdr = false,
  });

  @override
  final String id;

  @override
  final String label;

  /// The validated media address.
  final String url;

  /// The container the address carries: `mp4` (progressive, seekable by
  /// range) or `m3u8`.
  final String format;

  /// The picture's height in pixels, when the station states one.
  final int height;

  /// Whether the station labels the rendition as high dynamic range.
  final bool hdr;

  @override
  bool get playable => url.isNotEmpty;
}

/// One uploader's public page.
final class HuyaUploader {
  /// The uploader.
  const new({
    required this.id,
    required this.name,
    this.avatar = '',
    this.intro = '',
    this.videoCount = 0,
    this.playCount = 0,
    this.subscriberCount = 0,
    this.isLiving = false,
    this.roomId = 0,
  });

  /// The uid.
  final String id;

  /// The display name.
  final String name;

  /// The picture.
  final String avatar;

  /// The introduction the station prints.
  final String intro;

  /// How many videos the uploader posted.
  final int videoCount;

  /// How many times they were played in all.
  final int playCount;

  /// How many viewers subscribed.
  final int subscriberCount;

  /// Whether the uploader is broadcasting right now.
  final bool isLiving;

  /// The live room to walk into while they are.
  final int roomId;
}

/// One page of an uploader's videos.
final class HuyaUploaderFeed {
  /// A page.
  const new({required this.uploader, required this.videos, required this.page, required this.hasMore});

  /// The uploader the page belongs to.
  final HuyaUploader uploader;

  /// The rows, newest first.
  final List<HuyaVideo> videos;

  /// The page the answer names.
  final int page;

  /// Whether another page follows.
  final bool hasMore;
}

/// One search answer. The station's index walks one block of forty and does
/// not advance past it, so an answer is the whole result a reader can reach.
final class HuyaSearchPage {
  /// An answer.
  const new({required this.videos, this.total = 0});

  /// The rows, best match first.
  final List<HuyaVideo> videos;

  /// How many the index says it holds in all.
  final int total;
}

/// One video's own page: what it is, who posted it and what it offers.
final class HuyaVideoDetail {
  /// A detail.
  const new({required this.video, this.qualities = const [], this.tags = const []});

  /// The video itself, with its uploader and its brief.
  final HuyaVideo video;

  /// The permitted renditions, best first.
  final List<HuyaVideoQuality> qualities;

  /// The tags the station attached.
  final List<String> tags;
}

/// The station's video site: the home's shelves, the channel listings, the
/// boards, the search index, one video with its renditions, the videos beside
/// it and an uploader's page.
///
/// Every page is the station's own server-rendered answer, read through
/// [HuyaSsr]; the search index and one video's renditions are the two JSON
/// answers the site itself asks for. Nothing needs a login, and no answer's
/// media credentials are retained beyond the session that asked.
final class HuyaVideoApi {
  /// Builds the client over the shared proxied transport.
  new(this.http);

  /// The shared transport; this wrapper does not close it.
  final LiveHttp http;

  /// Every page asks as a desktop browser: the station redirects a mobile
  /// identity to surfaces that carry none of this data.
  static const Map<String, String> pageHeaders = {
    'referer': 'https://www.huya.com/',
    'user-agent':
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) '
        'Chrome/128.0.0.0 Safari/537.36',
  };

  /// The station lays its listings out twenty to a page, its boards fifty and
  /// its uploaders' videos sixteen.
  static const int listPageSize = 20;

  /// How many stands one board page holds.
  static const int rankPageSize = 50;

  /// How many rows one uploader page holds.
  static const int uploadPageSize = 16;

  /// The tallest rendition the player opens at when the station offers one:
  /// the app's own default for a video, not the station's ceiling.
  static const int defaultHeight = 1080;

  /// The home's shelves.
  Future<HuyaVideoHome> home() async => parseHome(await _page(Uri.https('www.huya.com', '/video/')));

  /// The station's channel groups, in its own order.
  Future<List<HuyaChannelGroup>> groups() async => parseGroups(await _page(Uri.https('www.huya.com', '/video/g/all')));

  /// One page of [channelId]'s listing in [order], narrowed to the group
  /// [setId] when it is not zero.
  Future<HuyaVideoList> list({
    required String channelId,
    int setId = 0,
    HuyaVideoOrder order = HuyaVideoOrder.hot,
    int page = 1,
  }) async {
    if (!_channelId.hasMatch(channelId) || setId < 0 || setId > 100000 || page < 1 || page > 10000) {
      throw const VodFailure('the station keeps no such listing');
    }
    final base = Uri.https('www.huya.com', '/video/g/${channelId}_${order.key}_$setId');
    return parseList(await _page(base.replace(queryParameters: {'page': '$page'})), page: page);
  }

  /// The boards the station ranks videos on.
  Future<List<HuyaRankBoard>> boards() async =>
      parseBoards(await _page(Uri.https('www.huya.com', '/video/rank/all.html')));

  /// One page of [channelId]'s board, best first.
  Future<HuyaRank> rank({required String channelId, int page = 1}) async {
    if (!_channelId.hasMatch(channelId) || page < 1 || page > 10000) {
      throw const VodFailure('the station keeps no such board');
    }
    return parseRank(
      await _page(Uri.https('www.huya.com', '/video/rank/$channelId.html', {'page': '$page'})),
      page: page,
    );
  }

  /// The search index's answer for [keyword]: one block of up to forty rows.
  /// The index does not advance past its first block, so this walks no pages.
  Future<HuyaSearchPage> search(String keyword) async {
    final word = keyword.trim();
    if (word.isEmpty || word.length > 64) {
      throw const VodFailure('the word is not one the station searches');
    }
    final uri = Uri.https('search.cdn.huya.com', '/', {
      'm': 'Search',
      'do': 'getSearchContent',
      'q': word,
      'uid': '0',
      'v': '4',
      'typ': '-5',
      'livestate': '0',
      'start': '0',
      'rows': '40',
    });
    return parseSearch((await _send(uri)).text);
  }

  /// One video's own page, from the answer the site's own player asks for.
  Future<HuyaVideoDetail> detail(String id) async {
    if (!_videoId.hasMatch(id)) {
      throw const VodFailure('the video id is not one the station gives out');
    }
    return parseDetail((await _send(Uri.https('liveapi.huya.com', '/moment/getMomentContent', {'videoId': id}))).text);
  }

  /// The videos the station puts beside [id], from its own play page.
  Future<List<HuyaVideo>> related(String id) async {
    if (!_videoId.hasMatch(id)) {
      throw const VodFailure('the video id is not one the station gives out');
    }
    return parseRelated(await _page(Uri.https('www.huya.com', '/video/play/$id.html')));
  }

  /// One page of [uid]'s own uploaded videos, newest first.
  Future<HuyaUploaderFeed> uploader(String uid, {int page = 1}) async {
    if (!_userId.hasMatch(uid) || page < 1 || page > 10000) {
      throw const VodFailure('the station keeps no such uploader page');
    }
    final root = await _page(Uri.https('www.huya.com', '/video/u/$uid', {'tabName': 'video', 'pageIndex': '$page'}));
    return parseUploader(root, page: page);
  }

  /// The home's shelves, top to bottom; a shelf with no videos is not one.
  static HuyaVideoHome parseHome(Map<String, Object?> root) {
    final shelves = <HuyaVideoShelf>[];
    for (final row in HuyaSsr.rows(root['aggregationList'])) {
      final item = HuyaSsr.record(HuyaSsr.value(row['recommendItem'])) ?? const <String, Object?>{};
      final videos = _videos(HuyaSsr.rows(HuyaSsr.value(row['videoInfoList'])));
      if (videos.isEmpty) continue;
      final channels = HuyaSsr.rows(HuyaSsr.value(item['channelItemList']));
      final channel = channels.isEmpty ? null : channels.first;
      shelves.add(
        HuyaVideoShelf(
          title: _text(item['title']),
          cover: HuyaSsr.image(item['cover']),
          channelId: channel == null ? '' : HuyaSsr.text(channel['id']),
          setId: HuyaSsr.integer(item['setId']) ?? 0,
          videos: videos,
        ),
      );
    }
    return HuyaVideoHome(shelves: List<HuyaVideoShelf>.unmodifiable(shelves));
  }

  /// The station's channel groups, in its own order.
  static List<HuyaChannelGroup> parseGroups(Map<String, Object?> root) {
    final groups = <HuyaChannelGroup>[];
    for (final row in HuyaSsr.rows(root['channelList'])) {
      final title = _text(row['title']);
      final setId = HuyaSsr.integer(row['setId']);
      if (title.isEmpty || setId == null) continue;
      final channels = <HuyaChannel>[];
      final seen = <String>{};
      for (final item in HuyaSsr.rows(HuyaSsr.value(row['channelItemList']))) {
        final id = HuyaSsr.text(item['id']).trim();
        final name = _text(item['name']);
        if (id.isEmpty || name.isEmpty || !_channelId.hasMatch(id) || !seen.add(id)) continue;
        channels.add(HuyaChannel(id: id, name: name));
      }
      if (channels.isEmpty) continue;
      groups.add(HuyaChannelGroup(setId: setId, title: title, channels: List<HuyaChannel>.unmodifiable(channels)));
    }
    if (groups.isEmpty) throw const VodFailure('the station sent no channel groups');
    return List<HuyaChannelGroup>.unmodifiable(groups);
  }

  /// One listing page.
  static HuyaVideoList parseList(Map<String, Object?> root, {required int page}) {
    final info = HuyaSsr.record(root['channelInfo']);
    final data = HuyaSsr.record(root['videoData']);
    _refuse(data?['respHeader']);
    final videos = _videos(HuyaSsr.rows(HuyaSsr.value(data?['videoDataList'])));
    final total = HuyaSsr.integer(data?['total']) ?? 0;
    final answered = HuyaSsr.integer(info?['pageIndex']) ?? page;
    return HuyaVideoList(
      videos: videos,
      page: answered,
      hasMore: videos.isNotEmpty && answered * listPageSize < total,
      total: total,
    );
  }

  /// The station's ranking boards.
  static List<HuyaRankBoard> parseBoards(Map<String, Object?> root) {
    final boards = <HuyaRankBoard>[];
    final seen = <String>{};
    for (final item in HuyaSsr.rows(HuyaSsr.value(root['channelItemList']))) {
      final id = HuyaSsr.text(item['id']).trim();
      final name = _text(item['name']);
      if (id.isEmpty || name.isEmpty || !_channelId.hasMatch(id) || !seen.add(id)) continue;
      boards.add(HuyaRankBoard(id: id, name: name));
    }
    if (boards.isEmpty) throw const VodFailure('the station sent no ranking boards');
    return List<HuyaRankBoard>.unmodifiable(boards);
  }

  /// One board page.
  static HuyaRank parseRank(Map<String, Object?> root, {required int page}) {
    final data = HuyaSsr.record(root['rankData']);
    _refuse(data?['respHeader']);
    final videos = <HuyaVideo>[];
    final seen = <String>{};
    for (final row in HuyaSsr.rows(HuyaSsr.value(data?['list']))) {
      final video = _videoFrom(HuyaSsr.record(row['videoData']));
      if (video != null && seen.add(video.id)) videos.add(video);
    }
    final total = HuyaSsr.integer(data?['total']) ?? 0;
    final answered = HuyaSsr.integer(root['page']) ?? page;
    return HuyaRank(
      videos: List<HuyaVideo>.unmodifiable(videos),
      page: answered,
      hasMore: videos.isNotEmpty && answered * rankPageSize < total,
      total: total,
      updatedAt: HuyaSsr.stamp(data?['updateTime']),
    );
  }

  /// The search index's JSON answer.
  static HuyaSearchPage parseSearch(String body) {
    final Object? decoded;
    try {
      decoded = jsonDecode(body);
    } on FormatException {
      throw const VodFailure('the search answer is not JSON the station sends');
    }
    final root = HuyaSsr.record(decoded);
    final header = HuyaSsr.record(root?['responseHeader']);
    final status = HuyaSsr.integer(header?['status']);
    if (root == null || status == null || status < 0) {
      throw const VodFailure('the search index refused the word');
    }
    final block = HuyaSsr.record(HuyaSsr.record(root['response'])?['122']);
    final videos = <HuyaVideo>[];
    final seen = <String>{};
    for (final row in HuyaSsr.rows(block?['docs'])) {
      final id = HuyaSsr.text(row['vid']);
      final title = _text(row['title']);
      if (!_videoId.hasMatch(id) || title.isEmpty || !seen.add(id)) continue;
      videos.add(
        HuyaVideo(
          id: id,
          title: title,
          cover: HuyaSsr.image(row['cover']),
          playCount: HuyaSsr.integer(row['play_sum']) ?? 0,
          publishedAt: HuyaSsr.stamp(row['uptime']),
          uploaderId: HuyaSsr.text(row['user_id']),
          uploaderName: _text(row['user_nickname']),
          uploaderAvatar: HuyaSsr.image(row['user_avatar']),
        ),
      );
    }
    return HuyaSearchPage(
      videos: List<HuyaVideo>.unmodifiable(videos),
      total: HuyaSsr.integer(block?['numFound']) ?? 0,
    );
  }

  /// One video's detail answer: the video, its renditions and its tags.
  static HuyaVideoDetail parseDetail(String body) {
    final Object? decoded;
    try {
      decoded = jsonDecode(body);
    } on FormatException {
      throw const VodFailure('the video answer is not JSON the station sends');
    }
    final root = HuyaSsr.record(decoded);
    final status = HuyaSsr.integer(root?['status']);
    if (root == null || status != 200) {
      throw VodFailure('the station refused the video (${status ?? 'no status'})');
    }
    final moment = HuyaSsr.record(HuyaSsr.record(root['data'])?['moment']);
    final info = HuyaSsr.record(HuyaSsr.value(moment?['videoInfo']));
    if (info == null) {
      throw const VodFailure('the video answer lost the video');
    }
    final id = HuyaSsr.text(info['vid']);
    if (!_videoId.hasMatch(id)) {
      throw const VodFailure('the video answer lost its id');
    }
    final cover = HuyaSsr.image(info['videoCover']);
    final video = HuyaVideo(
      id: id,
      title: _text(info['videoTitle']),
      cover: cover.isEmpty ? HuyaSsr.image(info['videoBigCover']) : cover,
      duration: HuyaSsr.duration(info['videoDuration']),
      playCount: HuyaSsr.integer(info['videoPlayNum']) ?? 0,
      danmakuCount: HuyaSsr.integer(info['videoCommentNum']) ?? 0,
      publishedAt: HuyaSsr.stamp(info['videoUploadTime']),
      channelId: HuyaSsr.text(info['videoChannel']),
      channelName: _text(info['category']),
      uploaderId: HuyaSsr.text(info['uid']),
      uploaderName: _text(info['nickName']),
      uploaderAvatar: HuyaSsr.image(info['avatarUrl']),
      brief: _text(info['briefIntroduction']),
    );
    final tags = <String>[];
    final raw = info['tags'];
    final pieces = raw is List ? raw : [raw];
    for (final piece in pieces) {
      for (final tag in HuyaSsr.text(piece).split(',')) {
        final text = _text(tag);
        if (text.isNotEmpty && !tags.contains(text)) tags.add(text);
      }
    }
    return HuyaVideoDetail(
      video: video,
      qualities: _qualities(info['definitions']),
      tags: List<String>.unmodifiable(tags),
    );
  }

  /// The videos the play page puts beside the one being watched.
  static List<HuyaVideo> parseRelated(Map<String, Object?> root) {
    final rows = HuyaSsr.rows(HuyaSsr.value(HuyaSsr.record(root['relateVideoRsp'])?['videoDataList']));
    final videos = <HuyaVideo>[];
    final seen = <String>{};
    for (final row in rows) {
      final video = _videoFrom(row);
      if (video != null && seen.add(video.id)) videos.add(video);
    }
    return List<HuyaVideo>.unmodifiable(videos);
  }

  /// One uploader page.
  static HuyaUploaderFeed parseUploader(Map<String, Object?> root, {required int page}) {
    final info = HuyaSsr.record(HuyaSsr.value(HuyaSsr.record(root['userInfoRsp'])?['userInfo']));
    if (info == null) {
      throw const VodFailure('the uploader page lost its owner');
    }
    final rows = HuyaSsr.rows(HuyaSsr.value(HuyaSsr.record(root['userPageVideoLisRsp'])?['videoDataList']));
    final videos = <HuyaVideo>[];
    final seen = <String>{};
    for (final row in rows) {
      final video = _videoFrom(row);
      if (video != null && seen.add(video.id)) videos.add(video);
    }
    final total = HuyaSsr.integer(info['videoNum']) ?? 0;
    return HuyaUploaderFeed(
      uploader: HuyaUploader(
        id: HuyaSsr.text(info['uid']),
        name: _text(info['nick']),
        avatar: HuyaSsr.image(info['avatar']),
        intro: _text(info['intro']),
        videoCount: total,
        playCount: HuyaSsr.integer(info['videoPlayNum']) ?? 0,
        subscriberCount: HuyaSsr.integer(info['subscribedNum']) ?? 0,
        isLiving: HuyaSsr.integer(info['isLiving']) == 1,
        roomId: HuyaSsr.integer(info['roomId']) ?? 0,
      ),
      videos: List<HuyaVideo>.unmodifiable(videos),
      page: page,
      hasMore: videos.isNotEmpty && page * uploadPageSize < total,
    );
  }

  /// The rendition the player opens at: the best one that does not stand
  /// above [maxHeight] and carries no HDR grade, or the best plain one, or
  /// the best one at all when the ladder is HDR throughout.
  static HuyaVideoQuality? openingQuality(List<HuyaVideoQuality> qualities, {int maxHeight = defaultHeight}) {
    final playable = [
      for (final quality in qualities)
        if (quality.playable) quality,
    ];
    if (playable.isEmpty) return null;
    for (final quality in playable) {
      if (!quality.hdr && quality.height > 0 && quality.height <= maxHeight) return quality;
    }
    for (final quality in playable) {
      if (!quality.hdr) return quality;
    }
    return playable.first;
  }

  /// The station's rendition rows as one ladder, best first: taller above
  /// shorter, an HDR grade above the plain one at the same height.
  static List<HuyaVideoQuality> _qualities(Object? raw) {
    final rows = HuyaSsr.rows(HuyaSsr.value(raw));
    final ranked = <({HuyaVideoQuality quality, int rank})>[];
    final seen = <String>{};
    for (final row in rows) {
      final url = HuyaSsr.media(row['url']) ?? HuyaSsr.media(row['m3u8']);
      if (url == null) continue;
      final definition = HuyaSsr.text(row['definition']).trim();
      final name = _text(row['defName']);
      final height = HuyaSsr.integer(row['height']) ?? 0;
      final hdr = name.toUpperCase().contains('HDR');
      var id = definition.isEmpty ? '$height' : definition;
      if (!seen.add(id)) id = '$id-${seen.length}';
      seen.add(id);
      final label = name.isEmpty ? (height > 0 ? '${height}P' : '默认') : name;
      ranked.add((
        quality: HuyaVideoQuality(
          id: id,
          label: label,
          url: url,
          format: Uri.parse(url).path.toLowerCase().endsWith('.m3u8') ? 'm3u8' : 'mp4',
          height: height,
          hdr: hdr,
        ),
        rank: height * 10 + (hdr ? 1 : 0),
      ));
    }
    ranked.sort((a, b) => b.rank.compareTo(a.rank));
    return [for (final entry in ranked) entry.quality];
  }

  /// One list row as a video, or null when the row carries no id or title.
  static HuyaVideo? _videoFrom(Map<String, Object?>? row) {
    if (row == null) return null;
    final id = HuyaSsr.text(row['vid']);
    final title = _text(row['videoTitle']);
    if (!_videoId.hasMatch(id) || title.isEmpty) return null;
    final covers = HuyaSsr.record(row['covers']);
    final uploader = HuyaSsr.record(HuyaSsr.value(row['userInfo'])) ?? const <String, Object?>{};
    final duration = HuyaSsr.duration(row['duration']);
    return HuyaVideo(
      id: id,
      title: title,
      cover: _cover(covers, row['cover']),
      duration: duration == Duration.zero ? HuyaSsr.duration(row['rawDuration']) : duration,
      playCount: HuyaSsr.integer(row['playNums']) ?? 0,
      danmakuCount: HuyaSsr.integer(row['danmuNums']) ?? 0,
      publishedAt: HuyaSsr.epoch(row['publishTime']) ?? HuyaSsr.epoch(row['uploadStartTime']),
      channelId: HuyaSsr.text(row['channelId']).trim(),
      channelName: _text(row['channelName']),
      uploaderId: HuyaSsr.text(uploader['uid']),
      uploaderName: _text(uploader['userNick']),
      uploaderAvatar: HuyaSsr.image(uploader['avatar']),
      brief: _text(row['brief']),
    );
  }

  /// The widest cover a row offers: the card grid's 16:9 crop first, the
  /// plain field last, because the home's shelves carry that shape alone.
  static String _cover(Map<String, Object?>? covers, Object? plain) {
    for (final candidate in [
      covers?['cover640'],
      covers?['cover375'],
      covers?['cover'],
      covers?['cover320'],
      covers?['originCover'],
      covers?['firstFrameCover'],
    ]) {
      final image = HuyaSsr.image(candidate);
      if (image.isNotEmpty) return image;
    }
    return HuyaSsr.image(plain);
  }

  static List<HuyaVideo> _videos(List<Map<String, Object?>> rows) {
    final seen = <String>{};
    final videos = <HuyaVideo>[];
    for (final row in rows) {
      final video = _videoFrom(row);
      if (video != null && seen.add(video.id)) videos.add(video);
    }
    return List<HuyaVideo>.unmodifiable(videos);
  }

  /// A title as the viewer reads it: entities decoded, breaks folded to one
  /// space.
  static String _text(Object? raw) => HuyaSsr.entities(HuyaSsr.text(raw)).replaceAll(RegExp(r'\s+'), ' ').trim();

  /// The page's data, or the station's refusal.
  Future<Map<String, Object?>> _page(Uri url) async => HuyaSsr.parse((await _send(url)).text);

  Future<LiveResponse> _send(Uri url) async {
    final response = await http.send(LiveRequest.get(url, headers: pageHeaders, site: 'huya'));
    if (response.statusCode == 404) {
      throw const VodFailure('the station keeps no such page');
    }
    if (response.statusCode == 401) {
      throw const VodFailure('the station asks a login for this page');
    }
    if (response.statusCode == 403 || response.statusCode == 429) {
      throw const VodFailure('the station refused the request');
    }
    if (response.statusCode != 200) {
      throw VodFailure('HTTP ${response.statusCode}', statusCode: response.statusCode);
    }
    return response;
  }

  /// A response header's own refusal, when it carries one.
  static void _refuse(Object? header) {
    final record = HuyaSsr.record(header);
    if (record == null) return;
    final code = HuyaSsr.integer(record['code']);
    if (code == null || code == 0) return;
    final message = HuyaSsr.entities(HuyaSsr.text(record['msg'])).trim();
    throw VodFailure(message.isEmpty ? 'the station refused the listing' : message);
  }
}
