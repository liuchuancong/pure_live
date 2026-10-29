import 'package:media_core_audio/media_core_audio.dart' as audio;

import 'package:pure_live/modules/music/controller/music_comments.dart' show MusicComment;
import 'package:pure_live/modules/music/controller/sources/comment_emojis.dart' show kWyCommentEmojis;
import 'package:pure_live/modules/music/controller/sources/lx_platform_source.dart';
import 'package:pure_live/modules/music/controller/sources/lyric_decoders.dart' show parseYrc;
import 'package:pure_live/modules/music/controller/sources/music_comment_source.dart';
import 'package:pure_live/modules/music/controller/sources/music_hot_words.dart';
import 'package:pure_live/modules/music/controller/sources/online_playlist_models.dart'
    show MusicPlaylistInfo, MusicPlaylistPage, MusicPlaylistTag, MusicPlaylistTagGroup, MusicPlazaSort,
        OnlinePlaylists, PlaylistTagTree, SonglistSearch;
import 'package:pure_live/modules/music/controller/sources/wy_crypto.dart';

/// The wy-music leaderboard view's Netease boards, in its own order.
const List<(String, String)> _kWyBoards = [
  ('19723756', '飙升榜'),
  ('3778678', '热歌榜'),
  ('3779629', '新歌榜'),
  ('2884035', '原创榜'),
  ('71384707', '古典榜'),
  ('2250011882', '抖音榜'),
  ('745956260', '韩语榜'),
  ('1978921795', '电音榜'),
  ('2006508653', '电竞榜'),
  ('21845217', 'KTV唛榜'),
];

const String _neteaseUserAgent =
    'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/60.0.3112.90 Safari/537.36';

/// The Netease platform: search, boards and lyrics ride the eapi/weapi
/// encrypted channels; play URLs come from the lx scripts.
final class WyMusicSource extends LxPlatformSource with OnlinePlaylists, PlaylistTagTree, SonglistSearch
implements MusicHotWords, MusicCommentsSource {
  /// A Netease source over the lx runtime.
  WyMusicSource(super.runtime, super.http);

  @override
  String get id => 'wy';

  @override
  String get name => '网易云音乐';

  Future<Map<String, Object?>> _eapi(String path, Object data) async {
    final answer = await postForm(Uri.https('interface.music.163.com', '/eapi/batch'), eapi(path, data), {
      'User-Agent': _neteaseUserAgent,
      'origin': 'https://music.163.com',
    });
    if (answer is! Map<String, Object?>) throw StateError('wy answered a non-object');
    return answer;
  }

  Future<Map<String, Object?>> _weapi(String path, Object data) async {
    final (form, _) = weapi(data);
    final answer = await postForm(Uri.https('music.163.com', path), form, {
      'User-Agent': _neteaseUserAgent,
      'origin': 'https://music.163.com',
    });
    if (answer is! Map<String, Object?>) throw StateError('wy answered a non-object');
    return answer;
  }

  @override
  Future<audio.MusicSourcePage<audio.MusicTrack>> search(String keyword, {int page = 1, int pageSize = 30}) async {
    final json = await _eapi('/api/search/song/list/page', {
      'keyword': keyword,
      'needCorrect': '1',
      'channel': 'typing',
      'offset': pageSize * (page - 1),
      'scene': 'normal',
      'total': page == 1,
      'limit': pageSize,
    });
    if (json['code'] != 200) return const audio.MusicSourcePage.empty();
    final data = json['data'];
    if (data is! Map) return const audio.MusicSourcePage.empty();
    final total = (data['totalCount'] as num?)?.toInt() ?? 0;
    final raw = data['resources'];
    final items = <audio.MusicTrack>[
      if (raw is List)
        for (final entry in raw)
          if (entry is Map && entry['baseInfo'] is Map) ?_trackOf((entry['baseInfo'] as Map)['simpleSongData']),
    ];
    return audio.MusicSourcePage(items: items, page: page, total: total, hasMore: total > page * pageSize);
  }

  @override
  Future<List<audio.MusicCatalog>> catalogs() async => [
    for (final (bangid, name) in _kWyBoards) audio.MusicCatalog(id: 'wy:$bangid', name: name),
  ];

  @override
  Future<audio.MusicSourcePage<audio.MusicTrack>> catalogItems(audio.MusicCatalog catalog, {int page = 1}) async {
    if (page > 1) return const audio.MusicSourcePage.empty();
    final json = await _weapi('/weapi/v3/playlist/detail', {'id': catalog.id.split(':').last, 'n': 100000, 'p': 1});
    if (json['code'] != 200) return const audio.MusicSourcePage.empty();
    final playlist = json['playlist'];
    if (playlist is! Map) return const audio.MusicSourcePage.empty();
    final raw = playlist['tracks'];
    final items = <audio.MusicTrack>[
      if (raw is List)
        for (final song in raw) ?_trackOf(song),
    ];
    return audio.MusicSourcePage(items: items, total: items.length);
  }

  /// The plaza's sort tabs — the reference's wy `sortList` keeps only 最热.
  @override
  List<MusicPlazaSort> get sorts => const [MusicPlazaSort(id: 'hot', name: '最热')];

  /// The viewer-browsable online playlists (在线歌单): hot tags, the pages
  /// under a tag, and one playlist's tracks. lx-music's wy `songList`.
  @override
  Future<List<String>> hotTags() async {
    final json = await _weapi('/weapi/playlist/hottags', {});
    if (json['code'] != 200) return const <String>[];
    final tags = json['tags'];
    return [
      if (tags is List)
        for (final tag in tags)
          if (tag is Map && tag['playlistTag'] is Map) '${(tag['playlistTag'] as Map)['name'] ?? ''}',
    ].where((name) => name.isNotEmpty).toList();
  }

  /// The plaza's category tree — the reference's wy `getTag` on the
  /// catalogue endpoint: categories named by id, the subs filed under them,
  /// a tag's id being its own words.
  @override
  Future<List<MusicPlaylistTagGroup>> tagGroups() async {
    final json = await _weapi('/weapi/playlist/catalogue', {});
    if (json['code'] != 200) return const <MusicPlaylistTagGroup>[];
    final categories = json['categories'];
    final sub = json['sub'];
    if (categories is! Map || sub is! List) return const <MusicPlaylistTagGroup>[];
    final byCategory = <String, List<MusicPlaylistTag>>{};
    for (final entry in sub) {
      if (entry is! Map) continue;
      final name = '${entry['name'] ?? ''}'.trim();
      final category = '${entry['category'] ?? ''}';
      if (name.isEmpty || category.isEmpty) continue;
      (byCategory[category] ??= []).add(MusicPlaylistTag(id: name, name: name));
    }
    final groups = <MusicPlaylistTagGroup>[];
    for (final key in categories.keys) {
      final tags = byCategory['$key'];
      if (tags == null || tags.isEmpty) continue;
      groups.add(MusicPlaylistTagGroup(name: '${categories[key]}', tags: tags));
    }
    return groups;
  }

  @override
  Future<MusicPlaylistPage> playlists({
    String tag = '全部',
    String order = 'hot',
    int page = 1,
    int pageSize = 30,
  }) async {
    final json = await _weapi('/weapi/playlist/list', {
      'cat': tag,
      'order': order,
      'limit': pageSize,
      'offset': pageSize * (page - 1),
      'total': true,
    });
    if (json['code'] != 200) return const MusicPlaylistPage(items: [], total: 0);
    final raw = json['playlists'];
    final total = int.tryParse('${json['total'] ?? ''}') ?? 0;
    return MusicPlaylistPage(
      items: [
        if (raw is List)
          for (final entry in raw)
            if (entry is Map) _playlistOf(entry.cast<String, Object?>()),
      ],
      total: total,
    );
  }

  /// The keyword's playlists, the lx wy `songList.search`: the eapi
  /// cloudsearch with type 1000 (歌单) pages over the same playlist shape
  /// the tag browser reads.
  @override
  Future<MusicPlaylistPage> searchPlaylists(String keyword, {int page = 1, int pageSize = 20}) async {
    final json = await _eapi('/api/cloudsearch/pc', {
      's': keyword,
      'type': 1000,
      'limit': pageSize,
      'total': page == 1,
      'offset': pageSize * (page - 1),
    });
    if (json['code'] != 200) return const MusicPlaylistPage(items: [], total: 0);
    final result = json['result'];
    final raw = result is Map ? result['playlists'] : null;
    final count = result is Map ? (result['playlistCount'] as num?)?.toInt() ?? 0 : 0;
    return MusicPlaylistPage(
      items: [
        if (raw is List)
          for (final entry in raw)
            if (entry is Map) _playlistOf(entry.cast<String, Object?>()),
      ],
      total: count,
    );
  }

  /// lx-music's `getListId`: a share link yields its playlist id, a bare id
  /// stands as it is.
  static String _playlistIdOf(String raw) {
    final id = raw.trim();
    final query = RegExp(r'(?:\?|&)id=(\d+)').firstMatch(id);
    if (query != null) return query[1]!;
    final path = RegExp(r'/playlist/(\d+)/\d+/').firstMatch(id);
    if (path != null) return path[1]!;
    return id;
  }

  @override
  Future<(MusicPlaylistInfo, List<audio.MusicTrack>)> playlistDetail(String rawId) async {
    final id = _playlistIdOf(rawId);
    final json = await _weapi('/weapi/v3/playlist/detail', {'id': id, 'n': 100000, 'p': 1});
    if (json['code'] != 200) throw StateError('wy playlist $id unavailable');
    final playlist = json['playlist'] as Map?;
    if (playlist == null) throw StateError('wy playlist $id unavailable');
    final privileges = _privilegeMap(json);
    final raw = playlist['tracks'];
    final tracks = <audio.MusicTrack>[
      if (raw is List)
        for (final song in raw)
          if (song is Map)
            ?_trackOf(song.cast<String, Object?>(), privilege: song['id'] == null ? null : privileges['${song['id']}']),
    ];
    return (_playlistOf(playlist.cast<String, Object?>()), tracks);
  }

  @override
  Future<audio.MusicLyricPayload?> resolveLyric(audio.MusicTrack track) async {
    try {
      final answer = await postForm(
        Uri.https('interface3.music.163.com', '/eapi/song/lyric/v1'),
        eapi('/api/song/lyric/v1', {
          'id': track.id,
          'cp': false,
          'tv': 0,
          'lv': 0,
          'rv': 0,
          'kv': 0,
          'yv': 0,
          'ytv': 0,
          'yrv': 0,
        }),
        {'User-Agent': _neteaseUserAgent, 'origin': 'https://music.163.com'},
      );
      if (answer is! Map<String, Object?>) return null;
      final json = answer;
      if (json['code'] != 200) return null;
      final yrc = json['yrc'] as Map?;
      if (yrc != null && '${yrc['lyric'] ?? ''}'.trim().isNotEmpty) {
        final ytlrc = json['ytlrc'] as Map?;
        final yromalrc = json['yromalrc'] as Map?;
        final decoded = parseYrc(
          '${yrc['lyric'] ?? ''}',
          ytlrc == null ? null : '${ytlrc['lyric'] ?? ''}',
          yromalrc == null ? null : '${yromalrc['lyric'] ?? ''}',
        );
        if (decoded != null) {
          return audio.MusicLyricPayload(
            lyric: decoded.lyric,
            translation: decoded.translation,
            romanization: decoded.romanization,
          );
        }
      }
      final lrc = json['lrc'] as Map?;
      final lyric = '${lrc?['lyric'] ?? ''}';
      if (lyric.trim().isEmpty) return null;
      final tlyric = json['tlyric'] as Map?;
      final translation = '${tlyric?['lyric'] ?? ''}';
      return audio.MusicLyricPayload(
        lyric: _fixTimeLabel(lyric),
        translation: translation.trim().isEmpty ? null : _fixTimeLabel(translation),
      );
    } on Object {
      return null;
    }
  }

  /// Netease stamps two-digit milliseconds; the player wants three.
  static String _fixTimeLabel(String lyric) =>
      lyric.replaceAllMapped(RegExp(r'\[(\d{2}:\d{2}):(\d{2})]'), (match) => '[${match[1]}.${match[2]}]');

  static audio.MusicTrack? _trackOf(Object? entry, {Map<String, Object?>? privilege}) {
    if (entry is! Map) return null;
    final row = entry.cast<String, Object?>();
    final song = ((row['simpleSongData'] as Map?) ?? row).cast<String, Object?>();
    final id = '${song['id'] ?? ''}';
    final title = '${song['name'] ?? ''}'.trim();
    if (id.isEmpty || title.isEmpty) return null;
    final album = song['al'] as Map?;
    final resolvedPrivilege = privilege ?? song['privilege'];
    final typedPrivilege = switch (resolvedPrivilege) {
      final Map<String, Object?> typed => typed,
      final Map<dynamic, dynamic> other => other.cast<String, Object?>(),
      _ => null,
    };
    final maxbr = (typedPrivilege?['maxbr'] as num?)?.toInt() ?? 0;
    final isHires = typedPrivilege?['maxBrLevel'] == 'hires';
    final qualities = <String>{
      if (isHires) 'flac24bit',
      if (maxbr >= 999000) 'flac',
      if (maxbr >= 320000) '320k',
      if (maxbr >= 128000) '128k',
    };
    final qualityIds = ['128k', '320k', 'flac', 'flac24bit'].where(qualities.contains).toList();
    final durationMs = song['dt'];
    final picUrl = '${album?['picUrl'] ?? ''}';
    final albumId = '${album?['id'] ?? ''}';
    return audio.MusicTrack(
      id: id,
      sourceId: 'wy',
      title: title,
      artist: _singersOf(song['ar']),
      album: '${album?['name'] ?? ''}',
      albumId: albumId.isEmpty ? null : albumId,
      duration: durationMs is num ? Duration(milliseconds: durationMs.toInt()) : null,
      coverUri: picUrl.isEmpty ? null : Uri.tryParse(picUrl),
      qualities: [for (final quality in qualityIds) LxPlatformSource.qualityOf(quality)],
      metadata: {'types': qualityIds, 'albumId': albumId, if (picUrl.isNotEmpty) 'pic': picUrl},
    );
  }

  static String _singersOf(Object? singers) {
    if (singers is! List) return '';
    return [
      for (final singer in singers)
        if (singer is Map && singer['name'] is String) singer['name'] as String,
    ].join('、');
  }

  /// The hot-search chart lx-music's wy `hotSearch.js` rides; the request is
  /// eapi-sealed like every Netease call.
  @override
  Future<List<String>> hotSearches() async {
    try {
      final form = eapi('/api/search/chart/detail', {'id': 'HOT_SEARCH_SONG#@#'});
      final answer = await postForm(Uri.https('interface.music.163.com', '/eapi/api/search/chart/detail'), form, {
        'User-Agent': _neteaseUserAgent,
        'origin': 'https://music.163.com',
      });
      if (answer is! Map<String, Object?>) return const [];
      final data = answer['data'];
      if (data is! Map) return const [];
      final raw = data['itemList'];
      if (raw is! List) return const [];
      return [
        for (final entry in raw)
          if (entry is Map && entry['searchWord'] is String && (entry['searchWord'] as String).trim().isNotEmpty)
            (entry['searchWord'] as String).trim(),
      ];
    } on Object {
      return const [];
    }
  }

  /// The completions for a partially typed query — the web suggest endpoint,
  /// each song rendered `name - artists` like the reference's `tipSearch.js`.
  @override
  Future<List<String>> suggestions(String query) async {
    try {
      final json = await _weapi('/weapi/search/suggest/web', {'s': query});
      final result = json['result'];
      final songs = result is Map ? result['songs'] : null;
      if (songs is! List) return const [];
      return [
        for (final song in songs)
          if (song is Map && song['name'] is String)
            '${song['name']} - ${_singersOf(song['artists'])}'.trim(),
      ];
    } on Object {
      return const [];
    }
  }

  /// The newest tab pages through a cursor the gateway hands back per answer,
  /// so the source remembers one per song — lx-music's `cursorTools`.
  final Map<String, ({String cursor, int orderType, int offset, int page})> _newestCursors = {};

  /// One page of a song's comments, hot or newest — the reference's wy
  /// `comment.js` over the weapi comment endpoints. `[大笑]` short codes
  /// become characters.
  @override
  Future<MusicCommentsPage> comments(audio.MusicTrack track, {required bool hot, required int page, int pageSize = 20}) async {
    final id = 'R_SO_4_${track.id}';
    if (hot) {
      final json = await _weapi('/weapi/v1/resource/hotcomments/$id', {
        'rid': id,
        'limit': pageSize,
        'offset': pageSize * (page - 1),
        'beforeTime': DateTime.now().millisecondsSinceEpoch.toString(),
      });
      final total = (json['total'] as num?)?.toInt() ?? 0;
      final rows = json['hotComments'];
      return (comments: commentsOf(rows is List ? rows : const [], _commentOf), hasMore: page * pageSize < total);
    }
    final cached = _newestCursors[track.id];
    String cursor;
    int orderType;
    int offset;
    if (page == 1 || cached == null) {
      cursor = DateTime.now().millisecondsSinceEpoch.toString();
      orderType = 1;
      offset = 0;
    } else {
      cursor = cached.cursor;
      orderType = page > cached.page ? 1 : 0;
      offset = page > cached.page ? (page - cached.page - 1) * pageSize : (cached.page - page - 1) * pageSize;
    }
    final json = await _weapi('/weapi/comment/resource/comments/get', {
      'cursor': cursor,
      'offset': offset,
      'orderType': orderType,
      'pageNo': page,
      'pageSize': pageSize,
      'rid': id,
      'threadId': id,
    });
    final data = json['data'];
    if (data is! Map) throw StateError('wy comments answered no data');
    _newestCursors[track.id] = (
      cursor: '${data['cursor'] ?? ''}',
      orderType: orderType,
      offset: offset,
      page: page,
    );
    final total = (data['totalCount'] as num?)?.toInt() ?? 0;
    final rows = data['comments'];
    return (comments: commentsOf(rows is List ? rows : const [], _commentOf), hasMore: page * pageSize < total);
  }

  static final RegExp _wyEmojiTag = RegExp(r'\[([^\[\]]{1,6})\]');

  /// Turns Netease's `[大笑]` short codes into their characters, unknown
  /// names left as written.
  static String _replaceEmoji(String text) =>
      text.replaceAllMapped(_wyEmojiTag, (match) => kWyCommentEmojis['${match[1]}'] ?? '${match[0]}');

  static MusicComment? _commentOf(Map<String, Object?> raw) {
    final own = _commentRowOf(raw);
    final replied = raw['beReplied'];
    final quoted = switch (replied) {
      final List<Object?> rows when rows.isNotEmpty => switch (rows.first) {
        final Map<Object?, Object?> row => row.cast<String, Object?>(),
        _ => null,
      },
      _ => null,
    };
    if (quoted == null || own == null) return own;
    final user = quoted['user'];
    return MusicComment(
      id: own.id,
      text: _replaceEmoji('${quoted['content'] ?? ''}').trim(),
      userName: user is Map ? '${user['nickname'] ?? ''}' : '',
      avatar: user is Map ? commentTextOf(user['avatarUrl']) : null,
      time: commentTimeOf(raw['time'], seconds: false),
      replies: [own],
    );
  }

  static MusicComment? _commentRowOf(Map<String, Object?> raw) {
    final text = _replaceEmoji('${raw['content'] ?? ''}').trim();
    if (text.isEmpty) return null;
    final user = raw['user'];
    return MusicComment(
      id: '${raw['commentId'] ?? ''}',
      text: text,
      userName: user is Map ? '${user['nickname'] ?? ''}' : '',
      avatar: user is Map ? commentTextOf(user['avatarUrl']) : null,
      time: commentTimeOf(raw['time'], seconds: false),
      likedCount: (raw['likedCount'] as num?)?.toInt() ?? 0,
    );
  }
}

MusicPlaylistInfo _playlistOf(Map<String, Object?> raw) => MusicPlaylistInfo(
  id: '${raw['id'] ?? ''}',
  name: '${raw['name'] ?? ''}',
  cover: '${raw['coverImgUrl'] ?? raw['picUrl'] ?? ''}',
  author: switch (raw['creator']) {
    final Map<dynamic, dynamic> creator => '${creator['nickname'] ?? ''}',
    _ => '',
  },
  trackCount: (raw['trackCount'] as num?)?.toInt() ?? 0,
);

Map<String, Map<String, Object?>> _privilegeMap(Map<String, Object?> json) {
  final raw = json['privileges'];
  return {
    if (raw is List)
      for (final privilege in raw)
        if (privilege is Map && privilege['id'] != null) '${privilege['id']}': privilege.cast<String, Object?>(),
  };
}
