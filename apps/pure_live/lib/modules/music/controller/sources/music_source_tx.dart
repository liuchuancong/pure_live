import 'dart:convert' show base64Encode, jsonDecode, jsonEncode;

import 'package:crypto/crypto.dart' show sha1;
import 'package:media_core_audio/media_core_audio.dart' as audio;

import 'package:pure_live/modules/music/controller/music_comments.dart' show MusicComment;
import 'package:pure_live/modules/music/controller/sources/comment_emojis.dart' show kTxCommentEmojis;
import 'package:pure_live/modules/music/controller/sources/lx_platform_source.dart';
import 'package:pure_live/modules/music/controller/sources/lyric_decoders.dart' show decodeQrc, parseQrc;
import 'package:pure_live/modules/music/controller/sources/music_comment_source.dart';
import 'package:pure_live/modules/music/controller/sources/music_hot_words.dart';
import 'package:pure_live/modules/music/controller/sources/online_playlist_models.dart'
    show MusicPlaylistInfo, MusicPlaylistPage, MusicPlaylistTag, MusicPlaylistTagGroup, MusicPlazaSort,
        OnlinePlaylists, PlaylistTagTree, SonglistSearch;

/// The QQ-music leaderboard view's boards, in its own order.
const List<(String, String)> _kTxBoards = [
  ('4', '流行榜'),
  ('26', '热歌榜'),
  ('28', '网络榜'),
  ('60', '抖音榜'),
  ('5', '内地榜'),
  ('59', '香港榜'),
  ('61', '台湾榜'),
  ('3', '欧美榜'),
  ('16', '韩国榜'),
  ('17', '日本榜'),
  ('128', 'YouTube榜'),
];

const String _qqUserAgent = 'QQMusic 14090508(android 12)';

/// The hex indexes lx-music picks out of the search request's SHA-1.
const List<int> _part1Indexes = [23, 14, 6, 36, 16, 40, 7, 19];
const List<int> _part2Indexes = [16, 1, 32, 12, 19, 27, 8, 5];
const List<int> _scrambleValues = [
  89,
  39,
  179,
  150,
  218,
  82,
  58,
  252,
  177,
  52,
  186,
  123,
  120,
  64,
  242,
  133,
  143,
  161,
  121,
  179,
];

/// The `zzc` signature QQ music's android gateway expects on the search URL.
String zzcSign(String text) {
  final hash = sha1.convert(text.codeUnits).toString();
  String pick(List<int> indexes) => [for (final index in indexes) hash[index]].join();
  final scrambled = [
    for (var i = 0; i < _scrambleValues.length; i++)
      _scrambleValues[i] ^ int.parse(hash.substring(i * 2, i * 2 + 2), radix: 16),
  ];
  final encoded = base64Encode(scrambled).replaceAll(RegExp(r'[\\/+.=]'), '');
  return 'zzc${pick(_part1Indexes)}$encoded${pick(_part2Indexes)}'.toLowerCase();
}

/// The QQ music platform: search and boards ride the signed android gateway;
/// play URLs come from the lx scripts (the open gateway serves no URLs).
final class TxMusicSource extends LxPlatformSource with OnlinePlaylists, PlaylistTagTree, SonglistSearch
implements MusicHotWords, MusicCommentsSource {
  /// A QQ music source over the lx runtime.
  TxMusicSource(super.runtime, super.http);

  @override
  String get id => 'tx';

  @override
  String get name => 'QQ音乐';

  /// The PC search id: 32 uppercase hex chars + 5 digits, lx-music's shape.
  static String _searchId() {
    final guid = [for (var i = 0; i < 32; i++) '0123456789ABCDEF'[DateTime.now().microsecondsSinceEpoch.remainder(16)]]
        .join();
    return '$guid${DateTime.now().microsecondsSinceEpoch.remainder(100000).abs()}';
  }

  Future<Map<String, Object?>> _musicu(Map<String, Object?> body, {bool signed = false}) async {
    final uri = signed
        ? Uri.https('u.y.qq.com', '/cgi-bin/musics.fcg', {'sign': zzcSign(jsonEncode(body))})
        : Uri.https('u.y.qq.com', '/cgi-bin/musicu.fcg');
    final answer = await postJson(uri, {
      'User-Agent': signed ? _qqUserAgent : 'Mozilla/5.0 (compatible; MSIE 9.0; Windows NT 6.1; WOW64; Trident/5.0)',
    }, body);
    if (answer is! Map<String, Object?>) throw StateError('tx answered a non-object');
    return answer;
  }

  @override
  Future<audio.MusicSourcePage<audio.MusicTrack>> search(String keyword, {int page = 1, int pageSize = 30}) async {
    final json = await _musicu({
      'comm': {
        '_channelid': '0',
        '_os_version': '6.2.9200-2',
        'ct': '19',
        'cv': '2151',
        'guid': '1F70E520B2EAA7D25E11760783C53CA9',
        'patch': '118',
        'psrf_access_token_expiresAt': 0,
        'psrf_qqaccess_token': '',
        'psrf_qqopenid': '',
        'psrf_qqunionid': '',
        'tmeAppID': 'qqmusic',
        'tmeLoginType': 0,
        'uin': '0',
        'wid': '7223299733393904640',
      },
      'music.search.SearchCgiService': {
        'module': 'music.search.SearchCgiService',
        'method': 'DoSearchForQQMusicDesktop',
        'param': {
          'grp': 1,
          'num_per_page': pageSize,
          'page_num': page,
          'query': keyword,
          'remoteplace': 'txt.newclient.top',
          'search_type': 0,
          'searchid': _searchId(),
        },
      },
    }, signed: true);
    final req = json['music.search.SearchCgiService'] ?? json['req'];
    if (json['code'] != 0 || req is! Map || req['code'] != 0) {
      return const audio.MusicSourcePage.empty();
    }
    final data = req['data'];
    if (data is! Map) return const audio.MusicSourcePage.empty();
    final meta = data['meta'];
    final total = meta is Map ? (meta['sum'] as num?)?.toInt() ?? 0 : 0;
    final body = data['body'];
    final song = body is Map ? body['song'] : null;
    final raw = song is Map ? song['list'] : null;
    final items = <audio.MusicTrack>[
      if (raw is List)
        for (final entry in raw) ?_trackOf(entry),
    ];
    return audio.MusicSourcePage(items: items, page: page, total: total, hasMore: total > page * pageSize);
  }

  @override
  Future<List<audio.MusicCatalog>> catalogs() async => [
    for (final (bangid, name) in _kTxBoards) audio.MusicCatalog(id: 'tx:$bangid', name: name),
  ];

  @override
  Future<audio.MusicSourcePage<audio.MusicTrack>> catalogItems(audio.MusicCatalog catalog, {int page = 1}) async {
    if (page > 1) return const audio.MusicSourcePage.empty();
    final bangid = catalog.id.split(':').last;
    final json = await _musicu({
      'toplist': {
        'module': 'musicToplist.ToplistInfoServer',
        'method': 'GetDetail',
        'param': {'topid': int.parse(bangid), 'num': 300, 'period': await _period(bangid)},
      },
      'comm': {'uin': 0, 'format': 'json', 'ct': 20, 'cv': 1859},
    });
    final toplist = json['toplist'];
    if (json['code'] != 0 || toplist is! Map || toplist['code'] != 0) {
      return const audio.MusicSourcePage.empty();
    }
    final data = toplist['data'];
    final raw = data is Map ? data['songInfoList'] : null;
    final items = <audio.MusicTrack>[
      if (raw is List)
        for (final entry in raw) ?_trackOf(entry),
    ];
    return audio.MusicSourcePage(items: items, total: items.length);
  }

  /// A board's `period` is its current cycle key; lx-music scrapes it off the
  /// PC top-list page. Today's date is the shape the page carries, so it is
  /// the fallback when the scrape comes up empty.
  Future<String> _period(String bangid) async {
    try {
      final html = await getText(Uri.https('c.y.qq.com', '/node/pc/wk_v15/top.html'));
      final pattern = RegExp(r'data-listname="[^"]*" data-tid="[^"]*/(\d+)" data-date="(\d+)"');
      for (final match in pattern.allMatches(html)) {
        if (match[1] == bangid) return match[2] ?? '';
      }
    } on Object {
      // Fall through to today's date.
    }
    final now = DateTime.now();
    final month = now.month.toString().padLeft(2, '0');
    final day = now.day.toString().padLeft(2, '0');
    return '${now.year}$month$day';
  }

  @override
  Future<audio.MusicLyricPayload?> resolveLyric(audio.MusicTrack track) async {
    try {
      final songId = '${track.metadata['songId'] ?? ''}';
      if (songId.isEmpty) return null;
      final json = await _musicu({
        'comm': {'ct': '19', 'cv': '1859', 'uin': '0'},
        'req': {
          'method': 'GetPlayLyricInfo',
          'module': 'music.musichallSong.PlayLyricInfo',
          'param': {
            'format': 'json',
            'crypt': 1,
            'ct': 19,
            'cv': 1873,
            'interval': 0,
            'lrc_t': 0,
            'qrc': 1,
            'qrc_t': 0,
            'roma': 1,
            'roma_t': 0,
            'songID': int.tryParse(songId) ?? songId,
            'trans': 1,
            'trans_t': 0,
            'type': -1,
          },
        },
      });
      final req = json['req'];
      if (json['code'] != 0 || req is! Map || req['code'] != 0) return null;
      final data = req['data'];
      if (data is! Map) return null;
      final decoded = parseQrc(
        decodeQrc('${data['lyric'] ?? ''}'),
        decodeQrc('${data['trans'] ?? ''}'),
        decodeQrc('${data['roma'] ?? ''}'),
      );
      if (decoded == null) return null;
      return audio.MusicLyricPayload(
        lyric: decoded.lyric,
        translation: decoded.translation,
        romanization: decoded.romanization,
      );
    } on Object {
      return null;
    }
  }

  /// The online playlists (在线歌单): the PC plaza's categories and the
  /// detail call lx-music's tx `songList` rides.
  @override
  Future<List<String>> hotTags() async {
    try {
      final html = await getText(Uri.https('c.y.qq.com', '/node/pc/wk_v15/category_playlist.html'));
      return [
        for (final match in RegExp(r'data-id="(\w+)">(.+?)</a>').allMatches(html))
          if (match[2] != null && match[2]!.trim().isNotEmpty) match[2]!.trim(),
      ];
    } on Object {
      return const <String>[];
    }
  }

  /// The plaza's sort tabs — the reference's tx `sortList`: without a tag
  /// the sort rides in place of one, 推荐 being the feed.
  @override
  List<MusicPlazaSort> get sorts => const [
    MusicPlazaSort(id: 'recommend', name: '推荐'),
    MusicPlazaSort(id: 'hot', name: '最热'),
    MusicPlazaSort(id: 'new', name: '最新'),
  ];

  static const Map<String, int> _sortCategoryIds = {'hot': 3, 'new': 2};

  @override
  Future<MusicPlaylistPage> playlists({String tag = '', String order = 'recommend', int page = 1, int pageSize = 30}) async {
    final tagId = int.tryParse(tag) ?? (tag.isEmpty ? _sortCategoryIds[order] : null);
    if (tagId == null) {
      // No numeric category: the plaza falls back to its feed.
      return await _recommendPage(page, pageSize);
    }
    return await _categoryPage(tagId, page, pageSize);
  }

  Future<MusicPlaylistPage> _categoryPage(int tagId, int page, int pageSize) async {
    final data = jsonEncode({
      'comm': {'cv': 1602, 'ct': 20},
      'playlist': {
        'method': 'get_category_content',
        'param': {
          'titleid': tagId,
          'caller': '0',
          'category_id': tagId,
          'size': pageSize,
          'page': page - 1,
          'use_page': 1,
        },
        'module': 'playlist.PlayListCategoryServer',
      },
    });
    final uri = Uri.https('u.y.qq.com', '/cgi-bin/musicu.fcg', {
      'loginUin': '0',
      'hostUin': '0',
      'format': 'json',
      'inCharset': 'utf-8',
      'outCharset': 'utf-8',
      'notice': '0',
      'platform': 'wk_v15.json',
      'needNewCode': '0',
      'data': data,
    });
    final json = jsonDecode(await getText(uri)) as Map<String, Object?>;
    final playlist = json['playlist'];
    final playlistData = playlist is Map ? playlist['data'] as Map? : null;
    final content = playlistData?['content'];
    if (json['code'] != 0 || content is! Map) return const MusicPlaylistPage(items: [], total: 0);
    final raw = content['v_item'];
    final total = (content['total_cnt'] as num?)?.toInt() ?? 0;
    return MusicPlaylistPage(
      items: [
        if (raw is List)
          for (final entry in raw)
            if (entry is Map && entry['basic'] is Map) _playlistOf((entry['basic'] as Map).cast<String, Object?>()),
      ],
      total: total,
    );
  }

  Future<MusicPlaylistPage> _recommendPage(int page, int pageSize) async {
    final json = await _musicu({
      'comm': {'cv': 1602, 'ct': 20},
      'playlist': {
        'module': 'music.playlist.PlaylistSquare',
        'method': 'GetRecommendWhole',
        'param': {
          'IsReqFeed': true,
          'FeedReq': {'From': (page - 1) * pageSize, 'Size': pageSize},
        },
      },
    });
    final playlist = json['playlist'];
    final data = playlist is Map ? playlist['data'] : null;
    final feed = data is Map ? data['FeedRsp'] : null;
    if (json['code'] != 0 || feed is! Map) return const MusicPlaylistPage(items: [], total: 0);
    final raw = feed['List'];
    return MusicPlaylistPage(
      items: [
        if (raw is List)
          for (final entry in raw)
            if (entry is Map && entry['Playlist'] is Map)
              _playlistOf(((entry['Playlist'] as Map)['basic'] as Map).cast<String, Object?>()),
      ],
      total: (feed['FromLimit'] as num?)?.toInt() ?? 0,
    );
  }

  /// The plaza's category tree — the reference's tx `getTag` on the
  /// all-categories gateway: groups with their numeric tag ids inside.
  @override
  Future<List<MusicPlaylistTagGroup>> tagGroups() async {
    final uri = Uri.https('u.y.qq.com', '/cgi-bin/musicu.fcg', {
      'loginUin': '0',
      'hostUin': '0',
      'format': 'json',
      'inCharset': 'utf-8',
      'outCharset': 'utf-8',
      'notice': '0',
      'platform': 'wk_v15.json',
      'needNewCode': '0',
      'data': jsonEncode({
        'tags': {'method': 'get_all_categories', 'param': {'qq': ''}, 'module': 'playlist.PlaylistAllCategoriesServer'},
      }),
    });
    final json = jsonDecode(await getText(uri)) as Map<String, Object?>;
    final tags = json['tags'];
    final data = tags is Map ? tags['data'] : null;
    if (json['code'] != 0 || data is! Map) return const <MusicPlaylistTagGroup>[];
    final raw = data['v_group'];
    final groups = <MusicPlaylistTagGroup>[];
    if (raw is List) {
      for (final group in raw) {
        if (group is! Map) continue;
        final items = group['v_item'];
        final groupTags = [
          if (items is List)
            for (final item in items)
              if (item is Map && '${item['id'] ?? ''}'.isNotEmpty)
                MusicPlaylistTag(id: '${item['id']}', name: '${item['name'] ?? ''}'),
        ];
        final name = '${group['group_name'] ?? ''}';
        if (groupTags.isNotEmpty && name.isNotEmpty) groups.add(MusicPlaylistTagGroup(name: name, tags: groupTags));
      }
    }
    return groups;
  }

  /// One page of the keyword's playlists — the reference's tx `songList`
  /// search on the y.qq.com soso gateway.
  @override
  Future<MusicPlaylistPage> searchPlaylists(String keyword, {int page = 1, int pageSize = 20}) async {
    final json = jsonDecode(
      await getText(
        Uri.https('c.y.qq.com', '/soso/fcgi-bin/client_music_search_songlist', {
          'page_no': '${page - 1}',
          'num_per_page': '$pageSize',
          'format': 'json',
          'query': keyword,
          'remoteplace': 'txt.yqq.playlist',
          'inCharset': 'utf8',
          'outCharset': 'utf-8',
        }),
        headers: {
          'User-Agent': 'Mozilla/5.0 (compatible; MSIE 9.0; Windows NT 6.1; WOW64; Trident/5.0)',
          'Referer': 'https://y.qq.com/portal/search.html',
        },
      ),
    ) as Map<String, Object?>;
    final data = json['data'];
    if (json['code'] != 0 || data is! Map) return const MusicPlaylistPage(items: [], total: 0);
    final raw = data['list'];
    final total = (data['sum'] as num?)?.toInt() ?? 0;
    return MusicPlaylistPage(
      items: [
        if (raw is List)
          for (final entry in raw)
            if (entry is Map)
              MusicPlaylistInfo(
                id: '${entry['dissid'] ?? ''}',
                name: '${entry['dissname'] ?? ''}',
                cover: '${entry['imgurl'] ?? ''}',
                author: switch (entry['creator']) {
                  final Map<dynamic, dynamic> creator => '${creator['name'] ?? ''}',
                  _ => '',
                },
                trackCount: (entry['song_count'] as num?)?.toInt() ?? 0,
              ),
      ],
      total: total,
    );
  }

  /// lx-music's `getListId`: a share link yields its playlist id, a bare id
  /// stands as it is.
  static String _playlistIdOf(String raw) {
    final id = raw.trim();
    final path = RegExp(r'/playlist/(\d+)').firstMatch(id);
    if (path != null) return path[1]!;
    final query = RegExp(r'id=(\d+)').firstMatch(id);
    if (query != null) return query[1]!;
    return id;
  }

  @override
  Future<(MusicPlaylistInfo, List<audio.MusicTrack>)> playlistDetail(String rawId) async {
    final id = _playlistIdOf(rawId);
    final numericId = int.tryParse(id);
    if (numericId == null) throw StateError('tx playlist id $id is not numeric');
    final json = await _musicu({
      'comm': {
        'cv': 4747474,
        'ct': 24,
        'format': 'json',
        'inCharset': 'utf-8',
        'outCharset': 'utf-8',
        'platform': 'yqq.json',
        'needNewCode': 1,
        'uin': 0,
      },
      'req_1': {
        'module': 'music.srfDissInfo.aiDissInfo',
        'method': 'uniform_get_Dissinfo',
        'param': {
          'disstid': numericId,
          'userinfo': 1,
          'tag': 1,
          'orderlist': 1,
          'song_begin': 0,
          'song_num': 100000,
          'onlysonglist': 0,
          'enc_host_uin': '',
        },
      },
    });
    final req = json['req_1'];
    if (json['code'] != 0 || req is! Map || req['code'] != 0) {
      throw StateError('tx playlist $id unavailable');
    }
    final data = req['data'];
    if (data is! Map) throw StateError('tx playlist $id unavailable');
    final dirinfo = data['dirinfo'];
    final raw = data['songlist'];
    final info = MusicPlaylistInfo(
      id: id,
      name: dirinfo is Map ? '${dirinfo['title'] ?? ''}' : '',
      cover: dirinfo is Map ? '${dirinfo['picurl'] ?? ''}' : '',
      author: dirinfo is Map ? '${dirinfo['host_nick'] ?? ''}' : '',
      trackCount: (data['total_song_num'] as num?)?.toInt() ?? 0,
    );
    final tracks = <audio.MusicTrack>[
      if (raw is List)
        for (final entry in raw) ?_trackOf(entry),
    ];
    return (info, tracks);
  }

  static MusicPlaylistInfo _playlistOf(Map<String, Object?> basic) {
    final cover = basic['cover'];
    final coverUrl = cover is Map ? '${cover['medium_url'] ?? cover['default_url'] ?? ''}' : '';
    return MusicPlaylistInfo(
      id: '${basic['tid'] ?? ''}',
      name: '${basic['title'] ?? ''}',
      cover: coverUrl,
      author: switch (basic['creator']) {
        final Map<dynamic, dynamic> creator => '${creator['nick'] ?? ''}',
        _ => '',
      },
      trackCount: (basic['song_cnt'] as num?)?.toInt() ?? 0,
    );
  }

  static audio.MusicTrack? _trackOf(Object? entry) {
    if (entry is! Map) return null;
    final file = entry['file'];
    if (file is! Map || '${file['media_mid'] ?? ''}'.isEmpty) return null;
    final id = '${entry['mid'] ?? ''}';
    final title = '${entry['title'] ?? ''}'.trim();
    if (id.isEmpty || title.isEmpty) return null;
    final qualities = <String>{
      if ((file['size_128mp3'] as num? ?? 0) != 0) '128k',
      if ((file['size_320mp3'] as num? ?? 0) != 0) '320k',
      if ((file['size_flac'] as num? ?? 0) != 0) 'flac',
      if ((file['size_hires'] as num? ?? 0) != 0) 'flac24bit',
    };
    final qualityIds = ['128k', '320k', 'flac', 'flac24bit'].where(qualities.contains).toList();
    final album = entry['album'];
    final albumName = album is Map ? '${album['name'] ?? ''}' : '';
    final albumMid = album is Map ? '${album['mid'] ?? ''}' : '';
    final seconds = entry['interval'];
    final picUrl = albumMid.isEmpty || albumName == '空'
        ? ''
        : 'https://y.gtimg.cn/music/photo_new/T002R500x500M000$albumMid.jpg';
    return audio.MusicTrack(
      id: id,
      sourceId: 'tx',
      title: title,
      artist: _singersOf(entry['singer']),
      album: albumName,
      albumId: albumMid.isEmpty ? null : albumMid,
      duration: seconds is num ? Duration(seconds: seconds.toInt()) : null,
      coverUri: picUrl.isEmpty ? null : Uri.tryParse(picUrl),
      qualities: [for (final quality in qualityIds) LxPlatformSource.qualityOf(quality)],
      metadata: {
        'types': qualityIds,
        'albumId': albumMid,
        'songId': '${entry['id'] ?? ''}',
        'mediaMid': '${file['media_mid'] ?? ''}',
        if (picUrl.isNotEmpty) 'pic': picUrl,
      },
    );
  }

  static String _singersOf(Object? singers) {
    if (singers is! List) return '';
    return [
      for (final singer in singers)
        if (singer is Map && singer['name'] is String) singer['name'] as String,
    ].join('、');
  }

  /// The hot-search words the PC gateway's hotkey service answers — the
  /// reference's tx `hotSearch.js`.
  @override
  Future<List<String>> hotSearches() async {
    try {
      final json = await _musicu({
        'comm': {
          'ct': '19',
          'cv': '1803',
          'guid': '0',
          'patch': '118',
          'psrf_access_token_expiresAt': 0,
          'psrf_qqaccess_token': '',
          'psrf_qqopenid': '',
          'psrf_qqunionid': '',
          'tmeAppID': 'qqmusic',
          'tmeLoginType': 0,
          'uin': '0',
          'wid': '0',
        },
        'hotkey': {
          'method': 'GetHotkeyForQQMusicPC',
          'module': 'tencent_musicsoso_hotkey.HotkeyService',
          'param': {'search_id': '', 'uin': 0},
        },
      });
      final hotkey = json['hotkey'];
      final data = hotkey is Map ? hotkey['data'] : null;
      if (json['code'] != 0 || data is! Map) return const [];
      final raw = data['vec_hotkey'];
      if (raw is! List) return const [];
      return [
        for (final entry in raw)
          if (entry is Map && entry['query'] is String && (entry['query'] as String).trim().isNotEmpty)
            (entry['query'] as String).trim(),
      ];
    } on Object {
      return const [];
    }
  }

  /// The completions for a partially typed query — smartbox's song items
  /// rendered `name - singer`, the reference's tx `tipSearch.js`.

  /// One page of a song's comments, hot or newest — the reference's tx
  /// `comment.js`: newest rides the legacy h5 form gateway, hot the musicu
  /// `CommentRead` module. QQ's `[em]e…[/em]` codes become characters.
  @override
  Future<MusicCommentsPage> comments(audio.MusicTrack track, {required bool hot, required int page, int pageSize = 20}) async {
    final songId = '${track.metadata['songId'] ?? ''}';
    if (songId.isEmpty) throw StateError('tx comments need a songId');
    if (hot) {
      final json = await _musicu({
        'comm': {
          'cv': 4747474,
          'ct': 24,
          'format': 'json',
          'inCharset': 'utf-8',
          'outCharset': 'utf-8',
          'notice': 0,
          'platform': 'yqq.json',
          'needNewCode': 1,
          'uin': 0,
        },
        'req': {
          'module': 'music.globalComment.CommentRead',
          'method': 'GetHotCommentList',
          'param': {
            'BizType': 1,
            'BizId': songId,
            'LastCommentSeqNo': '',
            'PageSize': pageSize,
            'PageNum': page - 1,
            'HotType': 1,
            'WithAirborne': 0,
            'PicEnable': 1,
          },
        },
      });
      final req = json['req'];
      final data = req is Map ? req['data'] : null;
      final comment = data is Map ? data['CommentList'] : null;
      if (json['code'] != 0 || req is! Map || req['code'] != 0 || comment is! Map) {
        throw StateError('tx hot comments answered ${json['code']}');
      }
      final rows = comment['Comments'];
      final total = (comment['Total'] as num?)?.toInt() ?? 0;
      return (comments: commentsOf(rows is List ? rows : const [], _hotCommentOf), hasMore: page * pageSize < total);
    }
    final json = await postForm(
      Uri.http('c.y.qq.com', '/base/fcgi-bin/fcg_global_comment_h5.fcg'),
      {
        'uin': '0',
        'format': 'json',
        'cid': '205360772',
        'reqtype': '2',
        'biztype': '1',
        'topid': songId,
        'cmd': '8',
        'needmusiccrit': '1',
        'pagenum': '${page - 1}',
        'pagesize': '$pageSize',
      },
      {'User-Agent': 'Mozilla/5.0 (compatible; MSIE 9.0; Windows NT 6.1; WOW64; Trident/5.0)'},
    );
    if (json is! Map<String, Object?> || json['code'] != 0) {
      throw StateError('tx comments answered ${json is Map ? json['code'] : json.runtimeType}');
    }
    final comment = json['comment'];
    if (comment is! Map) return (comments: const <MusicComment>[], hasMore: false);
    final rows = comment['commentlist'];
    final total = (comment['commenttotal'] as num?)?.toInt() ?? 0;
    return (comments: commentsOf(rows is List ? rows : const [], _newCommentOf), hasMore: page * pageSize < total);
  }

  static final RegExp _txEmojiTag = RegExp(r'\[em\](e\d+)\[/em\]');

  /// Turns QQ's `[em]e400846[/em]` codes into their characters, unknown codes
  /// dropped like lx-music's `replaceEmoji`.
  static String _replaceEmoji(String text) => text.replaceAllMapped(_txEmojiTag, (match) {
    final face = kTxCommentEmojis['${match[1]}'];
    return face ?? '';
  });

  /// lx-music's `formatTime`: a value shorter than ten digits is an id, not
  /// a timestamp; otherwise the seconds grow into millis.
  static DateTime? _txTime(Object? raw) {
    final text = '$raw';
    if (text.length < 10) return null;
    final value = int.tryParse(text);
    if (value == null || value <= 0) return null;
    return DateTime.fromMillisecondsSinceEpoch(text.length <= 10 ? value * 1000 : value);
  }

  static MusicComment? _newCommentOf(Map<String, Object?> raw) {
    final time = _txTime(raw['time']);
    final text = _replaceEmoji('${raw['rootcommentcontent'] ?? ''}').replaceAll(r'\n', '\n').trim();
    if (text.isEmpty) return null;
    final nick = '${raw['rootcommentnick'] ?? ''}';
    final replies = <MusicComment>[];
    final middle = raw['middlecommentcontent'];
    if (middle is List) {
      for (final row in middle.reversed) {
        if (row is! Map) continue;
        final replyText = _replaceEmoji('${row['subcommentcontent'] ?? ''}').replaceAll(r'\n', '\n').trim();
        if (replyText.isEmpty) continue;
        final replyNick = '${row['replynick'] ?? ''}';
        replies.add(
          MusicComment(
            id: 'sub_${raw['rootcommentid'] ?? ''}_${row['subcommentid'] ?? ''}',
            text: replyText,
            userName: replyNick.isEmpty ? '' : replyNick.substring(1),
            avatar: commentTextOf(row['avatarurl']),
            time: '${row['subcommentid'] ?? ''}' == '${raw['commentid'] ?? ''}' ? time : null,
            likedCount: (row['praisenum'] as num?)?.toInt() ?? 0,
          ),
        );
      }
    }
    return MusicComment(
      id: '${raw['rootcommentid'] ?? ''}_${raw['commentid'] ?? ''}',
      text: text,
      userName: nick.isEmpty ? '' : nick.substring(1),
      avatar: commentTextOf(raw['avatarurl']),
      time: time,
      likedCount: (raw['praisenum'] as num?)?.toInt() ?? 0,
      replies: replies,
    );
  }

  static MusicComment? _hotCommentOf(Map<String, Object?> raw) {
    final text = _replaceEmoji('${raw['Content'] ?? ''}').replaceAll(r'\n', '\n').trim();
    if (text.isEmpty) return null;
    final replies = <MusicComment>[];
    final subs = raw['SubComments'];
    if (subs is List) {
      for (final row in subs) {
        if (row is! Map) continue;
        final replyText = _replaceEmoji('${row['Content'] ?? ''}').replaceAll(r'\n', '\n').trim();
        if (replyText.isEmpty) continue;
        replies.add(
          MusicComment(
            id: 'sub_${row['SeqNo'] ?? ''}_${row['CmId'] ?? ''}',
            text: replyText,
            userName: '${row['Nick'] ?? ''}',
            avatar: commentTextOf(row['Avatar']),
            time: _txTime(row['PubTime']),
            likedCount: (row['PraiseNum'] as num?)?.toInt() ?? 0,
          ),
        );
      }
    }
    return MusicComment(
      id: '${raw['SeqNo'] ?? ''}_${raw['CmId'] ?? ''}',
      text: text,
      userName: '${raw['Nick'] ?? ''}',
      avatar: commentTextOf(raw['Avatar']),
      time: _txTime(raw['PubTime']),
      likedCount: (raw['PraiseNum'] as num?)?.toInt() ?? 0,
      replies: replies,
    );
  }
  @override
  Future<List<String>> suggestions(String query) async {
    try {
      final uri = Uri.https('c.y.qq.com', '/splcloud/fcgi-bin/smartbox_new.fcg', {
        'is_xml': '0',
        'format': 'json',
        'key': query,
        'loginUin': '0',
        'hostUin': '0',
        'inCharset': 'utf8',
        'outCharset': 'utf-8',
        'notice': '0',
        'platform': 'yqq',
        'needNewCode': '0',
      });
      final json = jsonDecode(
        await getText(uri, headers: {'Referer': 'https://y.qq.com/portal/player.html'}),
      ) as Map<String, Object?>;
      final data = json['data'];
      if (json['code'] != 0 || data is! Map) return const [];
      final song = data['song'];
      final itemlist = song is Map ? song['itemlist'] : null;
      if (itemlist is! List) return const [];
      return [
        for (final entry in itemlist)
          if (entry is Map && entry['name'] is String)
            '${entry['name']} - ${entry['singer'] ?? ''}'.trim(),
      ];
    } on Object {
      return const [];
    }
  }
}
