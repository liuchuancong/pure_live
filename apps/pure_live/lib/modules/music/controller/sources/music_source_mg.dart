import 'dart:convert' show jsonDecode, utf8;

import 'package:crypto/crypto.dart' show md5;
import 'package:media_core_audio/media_core_audio.dart' as audio;
import 'package:pure_live/modules/music/controller/music_comments.dart' show MusicComment;
import 'package:pure_live/modules/music/controller/sources/lx_platform_source.dart';
import 'package:pure_live/modules/music/controller/sources/lyric_decoders.dart' show decryptMrc, parseMrc;
import 'package:pure_live/modules/music/controller/sources/music_comment_source.dart';
import 'package:pure_live/modules/music/controller/sources/music_hot_words.dart';
import 'package:pure_live/modules/music/controller/sources/online_playlist_models.dart'
    show MusicPlaylistInfo, MusicPlaylistPage, MusicPlaylistTag, MusicPlaylistTagGroup, MusicPlazaSort,
        OnlinePlaylists, PlaylistTagTree, SonglistSearch;

/// The mg-music leaderboard view's boards, in its own order.
const List<(String, String)> _kMgBoards = [
  ('27553319', '音乐榜'),
  ('23603721', '影视榜'),
  ('23603926', '华语内地榜'),
  ('23603954', '华语港台榜'),
  ('23603974', '欧美榜'),
  ('23603982', '日韩榜'),
  ('23604058', '网络榜'),
  ('23604023', '彩铃榜'),
  ('23604040', 'KTV榜'),
  ('23604032', '原创榜'),
];

const String _mgDeviceId = '963B7AA0D21511ED807EE5846EC87D20';
const String _mgSignatureMd5 = '6cdc72a439cef99a3418d2a78aa28c73';
const String _mgAppSecret = 'yyapp2d16148780a1dcc7408e06336b98cfd50';
const String _mgUserAgent =
    'Mozilla/5.0 (Linux; U; Android 11.0.0; zh-cn; MI 11 Build/OPR1.170623.032) AppleWebKit/534.30 '
    '(KHTML, like Gecko) Version/4.0 Mobile Safari/534.30';

/// The search signature migu's v3 gateway expects: MD5 of the query salted
/// with the app secret, device id and timestamp.
(String sign, String deviceId) _createSignature(String time, String query) =>
    (md5.convert(utf8.encode('$query$_mgSignatureMd5$_mgAppSecret$_mgDeviceId$time')).toString(), _mgDeviceId);

/// The Migu platform: search rides the signed v3 gateway, boards and lyrics
/// the open app endpoints; play URLs come from the lx scripts.
final class MgMusicSource extends LxPlatformSource with OnlinePlaylists, PlaylistTagTree, SonglistSearch
implements MusicHotWords, MusicCommentsSource {
  /// A Migu source over the lx runtime.
  MgMusicSource(super.runtime, super.http);

  @override
  String get id => 'mg';

  @override
  String get name => '咪咕音乐';

  @override
  Future<audio.MusicSourcePage<audio.MusicTrack>> search(String keyword, {int page = 1, int pageSize = 20}) async {
    final time = DateTime.now().millisecondsSinceEpoch.toString();
    final (sign, deviceId) = _createSignature(time, keyword);
    final uri = Uri.https('jadeite.migu.cn', '/music_search/v3/search/searchAll', {
      'isCorrect': '0',
      'isCopyright': '1',
      'searchSwitch': '{"song":1,"album":0,"singer":0,"tagSong":1,"mvSong":0,"bestShow":1,"songlist":0,"lyricSong":0}',
      'pageSize': '$pageSize',
      'text': keyword,
      'pageNo': '$page',
      'sort': '0',
      'sid': 'USS',
    });
    final json = jsonDecode(
      await getText(
        uri,
        headers: {
          'uiVersion': 'A_music_3.6.1',
          'deviceId': deviceId,
          'timestamp': time,
          'sign': sign,
          'channel': '0146921',
          'User-Agent': _mgUserAgent,
        },
      ),
    ) as Map<String, Object?>;
    if (json['code'] != '000000') return const audio.MusicSourcePage.empty();
    final data = json['songResultData'];
    final total = data is Map ? int.tryParse('${data['totalCount'] ?? ''}') ?? 0 : 0;
    final raw = data is Map ? data['resultList'] : null;
    // Migu nests the song rows one level deep: one row per tag match group.
    final items = <audio.MusicTrack>[];
    final seen = <String>{};
    if (raw is List) {
      for (final group in raw) {
        if (group is! List) continue;
        for (final entry in group) {
          if (entry is! Map) continue;
          if (!seen.add('${entry['copyrightId'] ?? ''}')) continue;
          final track = _trackOf(entry.cast<String, Object?>(), entry['copyrightId'], entry['songId']);
          if (track != null) items.add(track);
        }
      }
    }
    return audio.MusicSourcePage(items: items, page: page, total: total, hasMore: total > page * pageSize);
  }

  @override
  Future<List<audio.MusicCatalog>> catalogs() async => [
    for (final (bangid, name) in _kMgBoards) audio.MusicCatalog(id: 'mg:$bangid', name: name),
  ];

  @override
  Future<audio.MusicSourcePage<audio.MusicTrack>> catalogItems(audio.MusicCatalog catalog, {int page = 1}) async {
    if (page > 1) return const audio.MusicSourcePage.empty();
    final uri = Uri.https('app.c.nf.migu.cn', '/MIGUM2.0/v1.0/content/querycontentbyId.do', {
      'columnId': catalog.id.split(':').last,
      'needAll': '0',
    });
    final json = jsonDecode(await getText(uri)) as Map<String, Object?>;
    if (json['code'] != '000000') return const audio.MusicSourcePage.empty();
    final columnInfo = json['columnInfo'];
    final raw = columnInfo is Map ? columnInfo['contents'] : null;
    final items = <audio.MusicTrack>[];
    final seen = <String>{};
    if (raw is List) {
      for (final entry in raw) {
        final info = entry is Map ? entry['objectInfo'] : null;
        if (info is! Map) continue;
        if (!seen.add('${info['songId'] ?? ''}')) continue;
        final track = _trackOf(info.cast<String, Object?>(), info['copyrightId'], info['songId']);
        if (track != null) items.add(track);
      }
    }
    return audio.MusicSourcePage(items: items, total: items.length);
  }

  @override
  Future<audio.MusicLyricPayload?> resolveLyric(audio.MusicTrack track) async {
    try {
      var lyricUrl = '${track.metadata['lrc'] ?? ''}';
      var translationUrl = '${track.metadata['trc'] ?? ''}';
      if (lyricUrl.isEmpty) {
        final refreshed = await _musicInfoOf('${track.metadata['copyrightId'] ?? track.id}');
        if (refreshed == null) return null;
        lyricUrl = refreshed.$1;
        translationUrl = refreshed.$2;
      }
      final translation = translationUrl.isEmpty ? null : await _lyricText(translationUrl);
      final cleanTranslation = translation == null || translation.trim().isEmpty ? null : translation;
      final mrcUrl = '${track.metadata['mrc'] ?? ''}';
      if (mrcUrl.isNotEmpty) {
        final decoded = parseMrc(decryptMrc(await _lyricText(mrcUrl)));
        if (decoded != null) {
          return audio.MusicLyricPayload(lyric: decoded.lyric, translation: cleanTranslation);
        }
      }
      if (lyricUrl.isEmpty) return null;
      final lyric = await _lyricText(lyricUrl);
      if (lyric.trim().isEmpty) return null;
      return audio.MusicLyricPayload(lyric: lyric, translation: cleanTranslation);
    } on Object {
      return null;
    }
  }

  static const _lyricHeaders = {
    'Referer': 'https://app.c.nf.migu.cn/',
    'User-Agent':
        'Mozilla/5.0 (Linux; Android 5.1.1; Nexus 6 Build/LYZ28E) AppleWebKit/537.36 (KHTML, like Gecko) '
        'Chrome/59.0.3071.115 Mobile Safari/537.36',
    'channel': '0146921',
  };

  Future<String> _lyricText(String url) async {
    try {
      return await getText(Uri.parse(url), headers: _lyricHeaders);
    } on Object {
      return '';
    }
  }

  /// The detail endpoint carries the lyric addresses a search row omitted.
  Future<(String, String)?> _musicInfoOf(String copyrightId) async {
    final answer = await postForm(
      Uri.https('c.musicapp.migu.cn', '/MIGUM2.0/v1.0/content/resourceinfo.do', {'resourceType': '2'}),
      {'resourceId': copyrightId},
      null,
    );
    if (answer is! Map<String, Object?>) return null;
    final json = answer;
    final resource = json['resource'];
    if (resource is! List || resource.isEmpty || resource.first is! Map) return null;
    final info = (resource.first as Map).cast<String, Object?>();
    return ('${info['lrcUrl'] ?? ''}', '${info['trcUrl'] ?? ''}');
  }

  /// The plaza's shared headers; the endpoints answer only with them.
  static const Map<String, String> _plazaHeaders = {
    'Referer': 'https://m.music.migu.cn/',
    'User-Agent':
        'Mozilla/5.0 (Linux; Android 5.1.1; Nexus 6 Build/LYZ28E) AppleWebKit/537.36 (KHTML, like Gecko) '
        'Chrome/59.0.3071.115 Mobile Safari/537.36',
    'channel': '0146921',
  };

  /// The plaza's sort tabs — the reference's mg `sortList` keeps only 推荐,
  /// and its active listing path asks the recommend feed regardless.
  @override
  List<MusicPlazaSort> get sorts => const [MusicPlazaSort(id: 'recommend', name: '推荐')];

  /// The online playlists (在线歌单): the plaza's tag list, the per-tag pages
  /// and the MIGUM3.0 playlist detail lx-music's mg `songList` rides.
  @override
  Future<List<String>> hotTags() async {
    try {
      final json = jsonDecode(
        await getText(
          Uri.https('app.c.nf.migu.cn', '/pc/v1.0/template/musiclistplaza-taglist/release'),
          headers: _plazaHeaders,
        ),
      ) as Map<String, Object?>;
      if (json['code'] != '000000') return const <String>[];
      final data = json['data'];
      if (data is! List || data.isEmpty || data.first is! Map) return const <String>[];
      final content = (data.first as Map)['content'];
      return [
        if (content is List)
          for (final entry in content)
            if (entry is Map && entry['texts'] is List && (entry['texts'] as List).length >= 2)
              '${(entry['texts'] as List)[1]}',
      ];
    } on Object {
      return const <String>[];
    }
  }

  @override
  Future<MusicPlaylistPage> playlists({String tag = '', String order = 'hot', int page = 1, int pageSize = 30}) async {
    final Uri uri;
    if (tag.isEmpty) {
      uri = Uri.https('app.c.nf.migu.cn', '/pc/bmw/page-data/playlist-square-recommend/v1.0', {
        'templateVersion': '2',
        'pageNo': '$page',
      });
    } else {
      uri = Uri.https('app.c.nf.migu.cn', '/pc/v1.0/template/musiclistplaza-listbytag/release', {
        'pageNumber': '$page',
        'templateVersion': '2',
        'tagId': tag,
      });
    }
    final json = jsonDecode(await getText(uri, headers: _plazaHeaders)) as Map<String, Object?>;
    if (json['code'] != '000000') return const MusicPlaylistPage(items: [], total: 0);
    final data = json['data'];
    if (data is! Map) return const MusicPlaylistPage(items: [], total: 0);
    final items = <MusicPlaylistInfo>[];
    if (tag.isEmpty) {
      final columns = data['contentItemList'];
      final column = columns is List && columns.length >= 2 ? columns[1] : null;
      final raw = column is Map ? column['itemList'] : null;
      if (raw is List) {
        for (final entry in raw) {
          if (entry is! Map) continue;
          final barList = entry['barList'];
          items.add(
            MusicPlaylistInfo(
              id: entry['logEvent'] is Map ? '${(entry['logEvent'] as Map)['contentId'] ?? ''}' : '',
              name: '${entry['title'] ?? ''}',
              cover: '${entry['imageUrl'] ?? ''}',
              author: barList is List && barList.isNotEmpty && barList.first is Map
                  ? '${(barList.first as Map)['title'] ?? ''}'
                  : '',
              trackCount: 0,
            ),
          );
        }
      }
    } else {
      final rows = <Map<String, Object?>>[];
      _collectPlaylists(data['contents'], rows);
      for (final row in rows) {
        items.add(
          MusicPlaylistInfo(
            id: '${row['resId'] ?? ''}',
            name: '${row['txt'] ?? ''}',
            cover: '${row['img'] ?? ''}',
            author: '',
            trackCount: 0,
          ),
        );
      }
    }
    return MusicPlaylistPage(items: items, total: 0);
  }

  /// The tag pages nest playlists at any depth under `contents`.
  static void _collectPlaylists(Object? listData, List<Map<String, Object?>> out) {
    if (listData is! List) return;
    for (final entry in listData) {
      if (entry is! Map) continue;
      if (entry['contents'] != null) {
        _collectPlaylists(entry['contents'], out);
      } else if (entry['resType'] == '2021') {
        out.add(entry.cast<String, Object?>());
      }
    }
  }

  /// The plaza's category tree — the reference's mg `getTag`: the template's
  /// first block is the hot tags, the rest are groups of `texts` name/id
  /// pairs.
  @override
  Future<List<MusicPlaylistTagGroup>> tagGroups() async {
    final json = jsonDecode(
      await getText(
        Uri.https('app.c.nf.migu.cn', '/pc/v1.0/template/musiclistplaza-taglist/release'),
        headers: _plazaHeaders,
      ),
    ) as Map<String, Object?>;
    final data = json['data'];
    if (json['code'] != '000000' || data is! List) return const <MusicPlaylistTagGroup>[];
    final groups = <MusicPlaylistTagGroup>[];
    for (final entry in data.skip(1)) {
      if (entry is! Map) continue;
      final header = entry['header'];
      final content = entry['content'];
      final name = header is Map ? '${header['title'] ?? ''}' : '';
      final tags = [
        if (content is List)
          for (final item in content)
            if (item is Map && item['texts'] is List && ((item['texts'] as List).length >= 2))
              MusicPlaylistTag(id: '${(item['texts'] as List)[1]}', name: '${(item['texts'] as List)[0]}'),
      ];
      if (tags.isNotEmpty && name.isNotEmpty) groups.add(MusicPlaylistTagGroup(name: name, tags: tags));
    }
    return groups;
  }

  /// One page of the keyword's playlists — the reference's mg `songList`
  /// search: the same v3 gateway as songs, switched to the songlist slice.
  @override
  Future<MusicPlaylistPage> searchPlaylists(String keyword, {int page = 1, int pageSize = 20}) async {
    final time = DateTime.now().millisecondsSinceEpoch.toString();
    final (sign, deviceId) = _createSignature(time, keyword);
    final uri = Uri.https('jadeite.migu.cn', '/music_search/v3/search/searchAll', {
      'isCorrect': '1',
      'isCopyright': '1',
      'searchSwitch': '{"song":0,"album":0,"singer":0,"tagSong":0,"mvSong":0,"bestShow":0,"songlist":1,"lyricSong":0}',
      'pageSize': '$pageSize',
      'text': keyword,
      'pageNo': '$page',
      'sort': '0',
      'sid': 'USS',
    });
    final json = jsonDecode(
      await getText(
        uri,
        headers: {
          'uiVersion': 'A_music_3.6.1',
          'deviceId': deviceId,
          'timestamp': time,
          'sign': sign,
          'channel': '0146921',
          'User-Agent': _mgUserAgent,
        },
      ),
    ) as Map<String, Object?>;
    final data = json['songListResultData'];
    if (json['code'] != '000000' || data is! Map) return const MusicPlaylistPage(items: [], total: 0);
    final raw = data['result'];
    final total = int.tryParse('${data['totalCount'] ?? ''}') ?? 0;
    return MusicPlaylistPage(
      items: [
        if (raw is List)
          for (final entry in raw)
            if (entry is Map && '${entry['id'] ?? ''}'.isNotEmpty)
              MusicPlaylistInfo(
                id: '${entry['id'] ?? ''}',
                name: '${entry['name'] ?? ''}',
                cover: '${entry['musicListPicUrl'] ?? ''}',
                author: '${entry['userName'] ?? ''}',
                trackCount: int.tryParse('${entry['musicNum'] ?? ''}') ?? 0,
              ),
      ],
      total: total,
    );
  }

  @override
  Future<(MusicPlaylistInfo, List<audio.MusicTrack>)> playlistDetail(String id) async {
    final songsUri = Uri.https('app.c.nf.migu.cn', '/MIGUM3.0/resource/playlist/song/v2.0', {
      'pageNo': '1',
      'pageSize': '100000',
      'playlistId': id,
    });
    final infoUri = Uri.https('c.musicapp.migu.cn', '/MIGUM3.0/resource/playlist/v2.0', {'playlistId': id});
    final songsJson = jsonDecode(await getText(songsUri, headers: _plazaHeaders)) as Map<String, Object?>;
    if (songsJson['code'] != '000000') throw StateError('mg playlist $id unavailable');
    final songsData = songsJson['data'];
    final raw = songsData is Map ? songsData['songList'] : null;
    final tracks = <audio.MusicTrack>[];
    final seen = <String>{};
    if (raw is List) {
      for (final entry in raw) {
        if (entry is! Map) continue;
        if (!seen.add('${entry['songId'] ?? ''}')) continue;
        final track = _trackOf(entry.cast<String, Object?>(), entry['copyrightId'], entry['songId']);
        if (track != null) tracks.add(track);
      }
    }
    var info = MusicPlaylistInfo(id: id, name: id, cover: '', author: '', trackCount: tracks.length);
    try {
      final infoJson = jsonDecode(await getText(infoUri, headers: _plazaHeaders)) as Map<String, Object?>;
      final infoData = infoJson['data'];
      if (infoJson['code'] == '000000' && infoData is Map) {
        final img = infoData['imgItem'];
        final opNum = infoData['opNumItem'];
        info = MusicPlaylistInfo(
          id: id,
          name: '${infoData['title'] ?? ''}',
          cover: img is Map ? '${img['img'] ?? ''}' : '',
          author: '${infoData['ownerName'] ?? ''}',
          trackCount: opNum is Map ? (opNum['playNum'] as num?)?.toInt() ?? tracks.length : tracks.length,
        );
      }
    } on Object {
      // The tracks still stand without their cover sheet.
    }
    return (info, tracks);
  }

  static audio.MusicTrack? _trackOf(Map<String, Object?> raw, Object? copyrightId, Object? songId) {
    final id = '$songId';
    final title = '${raw['name'] ?? raw['songName'] ?? ''}'.trim();
    if (id.isEmpty || id == 'null' || title.isEmpty) return null;
    final qualities = <String>{};
    final formats = raw['audioFormats'] ?? raw['newRateFormats'];
    if (formats is List) {
      for (final format in formats) {
        if (format is! Map) continue;
        switch (format['formatType']) {
          case 'PQ':
            qualities.add('128k');
          case 'HQ':
            qualities.add('320k');
          case 'SQ':
            qualities.add('flac');
          case 'ZQ24' || 'ZQ':
            qualities.add('flac24bit');
        }
      }
    }
    final qualityIds = ['128k', '320k', 'flac', 'flac24bit'].where(qualities.contains).toList();
    final seconds = int.tryParse('${raw['duration'] ?? ''}');
    final pic = '${raw['img3'] ?? raw['img2'] ?? raw['img1'] ?? ''}';
    final picUrl = pic.isEmpty || pic.startsWith('http') ? pic : 'http://d.musicapp.migu.cn$pic';
    final copyright = '$copyrightId';
    final singers = raw['singerList'];
    return audio.MusicTrack(
      id: id,
      sourceId: 'mg',
      title: title,
      artist: _singersOf(singers),
      album: '${raw['album'] ?? ''}',
      albumId: '${raw['albumId'] ?? ''}',
      duration: seconds == null ? null : Duration(seconds: seconds),
      coverUri: picUrl.isEmpty ? null : Uri.tryParse(picUrl),
      qualities: [for (final quality in qualityIds) LxPlatformSource.qualityOf(quality)],
      metadata: {
        'types': qualityIds,
        'copyrightId': copyright,
        'lrc': '${raw['lrcUrl'] ?? ''}',
        'mrc': '${raw['mrcurl'] ?? raw['mrcUrl'] ?? ''}',
        'trc': '${raw['trcUrl'] ?? ''}',
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

  /// The hot words the search gateway answers unsigned — the reference's mg
  /// `hotSearch.js`, which keeps only the song rows.
  @override
  Future<List<String>> hotSearches() async {
    try {
      final json = jsonDecode(
        await getText(Uri.http('jadeite.migu.cn:7090', '/music_search/v3/search/hotword')),
      ) as Map<String, Object?>;
      if (json['code'] != '000000') return const [];
      final data = json['data'];
      final hotwords = data is Map ? data['hotwords'] : null;
      if (hotwords is! List || hotwords.isEmpty) return const [];
      final first = hotwords.first;
      final list = first is Map ? first['hotwordList'] : null;
      if (list is! List) return const [];
      return [
        for (final entry in list)
          if (entry is Map && entry['resourceType'] == 'song' && entry['word'] is String)
            if ((entry['word'] as String).trim().isNotEmpty) (entry['word'] as String).trim(),
      ];
    } on Object {
      return const [];
    }
  }

  /// The completions for a partially typed query — the v3 web suggest, each
  /// song rendered `name - singerName` like the reference's `tipSearch.js`.
  @override
  Future<List<String>> suggestions(String query) async {
    try {
      final json = jsonDecode(
        await getText(
          Uri.https('music.migu.cn', '/v3/api/search/suggest', {'keyword': query}),
          headers: {'Referer': 'https://music.migu.cn/v3'},
        ),
      ) as Map<String, Object?>;
      final songs = json['songs'];
      if (songs is! List) return const [];
      return [
        for (final song in songs)
          if (song is Map && song['name'] is String)
            '${song['name']} - ${song['singerName'] ?? ''}'.trim(),
      ];
    } on Object {
      return const [];
    }
  }

  /// The newest tab pages by the previous page's last comment id, so the
  /// source remembers one per song — the reference's `lastCommentIds`.
  final Map<String, String> _newestCursors = {};

  /// One page of a song's comments, hot or newest — the reference's mg
  /// `comment.js` on the app comment stack.
  @override
  Future<MusicCommentsPage> comments(audio.MusicTrack track, {required bool hot, required int page, int pageSize = 20}) async {
    final songId = await _commentSongId(track);
    if (hot) {
      final json = await _commentStack(songId, {
        'pageSize': '$pageSize',
        'queryType': '2',
        'resourceId': songId,
        'resourceType': '2',
        'hotCommentStart': '${(page - 1) * pageSize}',
      });
      final total = int.tryParse('${json['cfgHotCount'] ?? ''}') ?? 0;
      final rows = json['hotComments'];
      return (comments: commentsOf(rows is List ? rows : const [], _commentOf), hasMore: page * pageSize < total);
    }
    if (page == 1) _newestCursors.remove(track.id);
    final cursor = _newestCursors[track.id];
    if (cursor == null && page > 1) throw StateError('mg comments lost the page cursor');
    final json = await _commentStack(songId, {
      'pageSize': '$pageSize',
      'queryType': '1',
      'resourceId': songId,
      'resourceType': '2',
      'commentId': cursor ?? '',
    });
    final total = int.tryParse('${json['commentNums'] ?? ''}') ?? 0;
    final rows = json['comments'];
    final comments = commentsOf(rows is List ? rows : const [], _commentOf);
    _newestCursors[track.id] = comments.isEmpty ? '' : comments.last.id;
    return (comments: comments, hasMore: page * pageSize < total);
  }

  Future<Map<String, Object?>> _commentStack(String songId, Map<String, String> query) async {
    final json = jsonDecode(
      await getText(
        Uri.https('app.c.nf.migu.cn', '/MIGUM3.0/user/comment/stack/v1.0', query),
        headers: {'User-Agent': _mgCommentUserAgent},
      ),
    ) as Map<String, Object?>;
    if (json['code'] != '000000') throw StateError('mg comments answered ${json['code']}');
    final data = json['data'];
    if (data is! Map) throw StateError('mg comments answered no data');
    return data.cast<String, Object?>();
  }

  /// Comments hang off the song id, not the copyright id this platform's
  /// search rows carry; lx-music's `songId.js` swaps it through the detail
  /// endpoint when the two collide.
  Future<String> _commentSongId(audio.MusicTrack track) async {
    final copyrightId = '${track.metadata['copyrightId'] ?? ''}';
    if (track.id != copyrightId) return track.id;
    if (copyrightId.isEmpty) throw StateError('mg comments need a copyright id');
    final answer = await postForm(
      Uri.https('c.musicapp.migu.cn', '/MIGUM2.0/v1.0/content/resourceinfo.do', {'resourceType': '2'}),
      {'resourceId': copyrightId},
      null,
    );
    if (answer is! Map<String, Object?>) throw StateError('mg comments detail answered a non-object');
    final resource = answer['resource'];
    if (resource is List && resource.isNotEmpty && resource.first is Map) {
      final songId = '${(resource.first as Map)['songId'] ?? ''}'.trim();
      if (songId.isNotEmpty) return songId;
    }
    throw StateError('mg comments could not resolve a song id');
  }

  static MusicComment? _commentOf(Map<String, Object?> raw) {
    final text = '${raw['commentInfo'] ?? ''}'.trim();
    if (text.isEmpty) return null;
    final user = raw['user'];
    final replies = <MusicComment>[];
    final replyRows = raw['replyComments'];
    if (replyRows is List) {
      for (final row in replyRows) {
        if (row is! Map) continue;
        final replyText = '${row['replyInfo'] ?? ''}'.trim();
        if (replyText.isEmpty) continue;
        final replyUser = row['user'];
        replies.add(
          MusicComment(
            id: '${row['replyId'] ?? ''}',
            text: replyText,
            userName: replyUser is Map ? '${replyUser['nickName'] ?? ''}' : '',
            avatar: replyUser is Map ? _iconOf(replyUser) : null,
            time: _mgTime(row['replyTime']),
          ),
        );
      }
    }
    return MusicComment(
      id: '${raw['commentId'] ?? ''}',
      text: text,
      userName: user is Map ? '${user['nickName'] ?? ''}' : '',
      avatar: user is Map ? _iconOf(user) : null,
      time: _mgTime(raw['commentTime']),
      likedCount: _thumbNum(raw['opNumItem']),
      replies: replies,
    );
  }

  /// Migu stamps comments with ISO date strings, not epoch numbers.
  static DateTime? _mgTime(Object? raw) => DateTime.tryParse('${raw ?? ''}');

  static String? _iconOf(Map<Object?, Object?> user) =>
      commentTextOf(user['middleIcon']) ?? commentTextOf(user['bigIcon']) ?? commentTextOf(user['smallIcon']);

  static int _thumbNum(Object? raw) => raw is Map ? int.tryParse('${raw['thumbNum'] ?? ''}') ?? 0 : 0;
}

/// The iPhone user agent migu's comment stack only answers with.
const String _mgCommentUserAgent =
    'Mozilla/5.0 (iPhone; CPU iPhone OS 13_2_3 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) '
    'Version/13.0.3 Mobile/15E148 Safari/604.1';
