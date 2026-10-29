import 'dart:convert' show base64, jsonDecode, utf8;

import 'package:crypto/crypto.dart' show md5;
import 'package:media_core_audio/media_core_audio.dart' as audio;
import 'package:pure_live/modules/music/controller/music_comments.dart' show MusicComment;
import 'package:pure_live/modules/music/controller/sources/lx_platform_source.dart';
import 'package:pure_live/modules/music/controller/sources/lyric_decoders.dart' show decodeKrc;
import 'package:pure_live/modules/music/controller/sources/music_comment_source.dart';
import 'package:pure_live/modules/music/controller/sources/music_hot_words.dart';
import 'package:pure_live/modules/music/controller/sources/online_playlist_models.dart'
    show MusicPlaylistInfo, MusicPlaylistPage, MusicPlaylistTag, MusicPlaylistTagGroup, MusicPlazaSort,
        OnlinePlaylists, PlaylistTagTree, SonglistSearch;

/// The lx-music leaderboard view's KuGou boards, in its own order.
const List<(String, String)> _kKgBoards = [
  ('8888', 'TOP500'),
  ('23784', '网络榜'),
  ('6666', '飙升榜'),
  ('21101', '分享榜'),
  ('33164', '纯音乐榜'),
  ('33161', '古风榜'),
  ('33165', '粤语榜'),
  ('33166', '欧美榜'),
  ('33160', '电音榜'),
  ('24971', 'DJ热歌榜'),
  ('31308', '华语新歌榜'),
];

/// The headers KuGou's lyric and picture endpoints only answer with.
const Map<String, String> _krcHeaders = {
  'KG-RC': '1',
  'KG-THash': 'expand_search_manager.cpp:852736169:451',
  'User-Agent': 'KuGou2012-9020-ExpandSearchManager',
};

/// The KuGou platform: search, boards and lyrics ride KuGou's own channel;
/// play URLs come from the lx scripts (KuGou has no open URL endpoint), keyed
/// by the per-quality file hashes the search response carries.
final class KgMusicSource extends LxPlatformSource with OnlinePlaylists, PlaylistTagTree, SonglistSearch
implements MusicHotWords, MusicCommentsSource {
  /// A KuGou source over the lx runtime.
  KgMusicSource(super.runtime, super.http);

  @override
  String get id => 'kg';

  @override
  String get name => '酷狗音乐';

  @override
  Future<audio.MusicSourcePage<audio.MusicTrack>> search(String keyword, {int page = 1, int pageSize = 30}) async {
    final uri = Uri.http('songsearch.kugou.com', '/song_search_v2', {
      'platform': 'AndroidFilter',
      'iscorrection': '1',
      'keyword': keyword,
      'hifiquality': '0',
      'pagesize': '$pageSize',
      'PrivilegeFilter': '0',
      'page': '$page',
    });
    final json = jsonDecode(await getText(uri)) as Map<String, Object?>;
    final data = json['data'];
    if (json['error_code'] != 0 || data is! Map) {
      return const audio.MusicSourcePage.empty();
    }
    final total = (data['total'] as num?)?.toInt() ?? 0;
    final raw = data['lists'];
    final items = <audio.MusicTrack>[];
    if (raw is List) {
      for (final entry in raw) {
        items.addAll(_tracksOf(entry) ?? const <audio.MusicTrack>[]);
      }
    }
    return audio.MusicSourcePage(items: items, page: page, total: total, hasMore: total > page * pageSize);
  }

  @override
  Future<List<audio.MusicCatalog>> catalogs() async => [
    for (final (bangid, name) in _kKgBoards) audio.MusicCatalog(id: 'kg:$bangid', name: name),
  ];

  @override
  Future<audio.MusicSourcePage<audio.MusicTrack>> catalogItems(audio.MusicCatalog catalog, {int page = 1}) async {
    final bangid = catalog.id.split(':').last;
    final uri = Uri.http('mobilecdnbj.kugou.com', '/api/v3/rank/song', {
      'version': '9108',
      'ranktype': '1',
      'plat': '0',
      'pagesize': '100',
      'area_code': '1',
      'page': '$page',
      'rankid': bangid,
      'with_res_tag': '0',
      'show_portrait_mv': '1',
    });
    final json = jsonDecode(await getText(uri)) as Map<String, Object?>;
    final data = json['data'];
    if (json['errcode'] != 0 || data is! Map) {
      return const audio.MusicSourcePage.empty();
    }
    final total = (data['total'] as num?)?.toInt() ?? 0;
    final raw = data['info'];
    final items = <audio.MusicTrack>[
      if (raw is List)
        for (final entry in raw) ?_boardTracksOf(entry),
    ];
    return audio.MusicSourcePage(items: items, page: page, total: total, hasMore: total > page * 100);
  }

  @override
  Future<audio.MusicLyricPayload?> resolveLyric(audio.MusicTrack track) async {
    try {
      final seconds = track.duration?.inSeconds ?? 0;
      final searchUri = Uri.http('lyrics.kugou.com', '/search', {
        'ver': '1',
        'man': 'yes',
        'client': 'pc',
        'keyword': track.title,
        'hash': '${track.metadata['hash'] ?? ''}',
        'timelength': '$seconds',
        'lrctxt': '1',
      });
      final search = jsonDecode(await getText(searchUri, headers: _krcHeaders)) as Map<String, Object?>;
      final candidates = search['candidates'];
      if (candidates is! List || candidates.isEmpty) return null;
      Map<String, Object?>? krcCandidate;
      Map<String, Object?>? lrcCandidate;
      for (final candidate in candidates) {
        if (candidate is! Map) continue;
        final isKrc = candidate['krctype'] == 1 && candidate['contenttype'] != 1;
        if (isKrc) {
          krcCandidate ??= candidate.cast<String, Object?>();
        } else {
          lrcCandidate ??= candidate.cast<String, Object?>();
        }
      }
      if (krcCandidate != null) {
        final payload = await _downloadLyric(krcCandidate, 'krc');
        if (payload != null) return payload;
      }
      if (lrcCandidate != null) {
        final payload = await _downloadLyric(lrcCandidate, 'lrc');
        if (payload != null) return payload;
      }
      return null;
    } on Object {
      return null;
    }
  }

  Future<audio.MusicLyricPayload?> _downloadLyric(Map<String, Object?> candidate, String fmt) async {
    final downloadUri = Uri.http('lyrics.kugou.com', '/download', {
      'ver': '1',
      'client': 'pc',
      'id': '${candidate['id']}',
      'accesskey': '${candidate['accesskey']}',
      'fmt': fmt,
      'charset': 'utf8',
    });
    final download = jsonDecode(await getText(downloadUri, headers: _krcHeaders)) as Map<String, Object?>;
    final status = download['status'];
    if (status is num && status != 200) return null;
    final content = download['content'];
    if (content is! String || content.isEmpty) return null;
    if (fmt == 'krc') {
      final decoded = decodeKrc(content);
      if (decoded == null) return null;
      return audio.MusicLyricPayload(
        lyric: decoded.lyric,
        translation: decoded.translation,
        romanization: decoded.romanization,
      );
    }
    final lyric = utf8.decode(base64.decode(content), allowMalformed: true);
    if (lyric.trim().isEmpty) return null;
    return audio.MusicLyricPayload(lyric: lyric);
  }

  /// The online playlists (在线歌单): the yueku v9 plaza for the lists and
  /// the mobile song_v2 pages with the gateway enrichment lx-music's kg
  /// `songList` rides. JSON throughout, signed with the sorted-params MD5.
  @override
  Future<List<String>> hotTags() async {
    try {
      final json = jsonDecode(
        await getText(
          Uri.http('www2.kugou.kugou.com', '/yueku/v9/special/getSpecial', {'is_smarty': '1', 'cdn': 'cdn', 't': '5'}),
        ),
      ) as Map<String, Object?>;
      final data = json['data'];
      final tags = <String>[];
      if (data is Map) {
        for (final value in data.values) {
          if (value is! List) continue;
          for (final tag in value) {
            if (tag is Map) {
              final name = '${tag['special_name'] ?? ''}'.trim();
              if (name.isNotEmpty) tags.add(name);
            }
          }
        }
      }
      return tags;
    } on Object {
      return const <String>[];
    }
  }

  /// The plaza's category tree — the reference's kg `getTags` on the
  /// smarty getSpecial: categories keyed by name, the tag rows inside.
  @override
  Future<List<MusicPlaylistTagGroup>> tagGroups() async {
    final json = jsonDecode(
      await getText(Uri.http('www2.kugou.kugou.com', '/yueku/v9/special/getSpecial', {'is_smarty': '1'})),
    ) as Map<String, Object?>;
    final data = json['data'];
    if (json['status'] != 1 || data is! Map) return const <MusicPlaylistTagGroup>[];
    final tagids = data['tagids'];
    if (tagids is! Map) return const <MusicPlaylistTagGroup>[];
    final groups = <MusicPlaylistTagGroup>[];
    for (final key in tagids.keys) {
      final bucket = tagids[key];
      if (bucket is! Map) continue;
      final raw = bucket['data'];
      final tags = [
        if (raw is List)
          for (final tag in raw)
            if (tag is Map && '${tag['id'] ?? ''}'.isNotEmpty && '${tag['name'] ?? ''}'.isNotEmpty)
              MusicPlaylistTag(id: '${tag['id']}', name: '${tag['name']}'),
      ];
      if (tags.isNotEmpty) groups.add(MusicPlaylistTagGroup(name: '$key', tags: tags));
    }
    return groups;
  }

  /// One page of the keyword's playlists — the reference's kg `songList`
  /// search on msearchretry's special endpoint.
  @override
  Future<MusicPlaylistPage> searchPlaylists(String keyword, {int page = 1, int pageSize = 20}) async {
    final json = jsonDecode(
      await getText(
        Uri.http('msearchretry.kugou.com', '/api/v3/search/special', {
          'keyword': keyword,
          'page': '$page',
          'pagesize': '$pageSize',
          'showtype': '10',
          'filter': '0',
          'version': '7910',
          'sver': '2',
        }),
      ),
    ) as Map<String, Object?>;
    final data = json['data'];
    if (json['errcode'] != 0 || data is! Map) return const MusicPlaylistPage(items: [], total: 0);
    final raw = data['info'];
    final total = (data['total'] as num?)?.toInt() ?? 0;
    return MusicPlaylistPage(
      items: [
        if (raw is List)
          for (final entry in raw)
            if (entry is Map)
              MusicPlaylistInfo(
                id: '${entry['specialid'] ?? ''}',
                name: '${entry['specialname'] ?? ''}',
                cover: '${entry['imgurl'] ?? entry['img'] ?? ''}'.replaceFirst('{size}', '240'),
                author: '${entry['nickname'] ?? ''}',
                trackCount: (entry['songcount'] as num?)?.toInt() ?? 0,
              ),
      ],
      total: total,
    );
  }

  /// The plaza's sort tabs — the reference's kg `sortList`, the t codes its
  /// getSpecial answers by.
  @override
  List<MusicPlazaSort> get sorts => const [
    MusicPlazaSort(id: 'recommend', name: '推荐'),
    MusicPlazaSort(id: 'hot', name: '最热'),
    MusicPlazaSort(id: 'new', name: '最新'),
    MusicPlazaSort(id: 'hot_collect', name: '热藏'),
    MusicPlazaSort(id: 'rise', name: '飙升'),
  ];

  static const Map<String, String> _sortIds = {
    'recommend': '5',
    'hot': '6',
    'new': '7',
    'hot_collect': '3',
    'rise': '8',
  };

  @override
  Future<MusicPlaylistPage> playlists({String tag = '', String order = 'recommend', int page = 1, int pageSize = 30}) async {
    final uri = Uri.http('www2.kugou.kugou.com', '/yueku/v9/special/getSpecial', {
      'is_ajax': '1',
      'cdn': 'cdn',
      't': _sortIds[order] ?? '5',
      'c': tag,
      'p': '$page',
    });
    final json = jsonDecode(await getText(uri)) as Map<String, Object?>;
    final raw = json['special_db'];
    if (json['status'] != 1 || raw is! List) return const MusicPlaylistPage(items: [], total: 0);
    return MusicPlaylistPage(
      items: [
        for (final entry in raw)
          if (entry is Map)
            MusicPlaylistInfo(
              id: '${entry['specialid'] ?? ''}',
              name: '${entry['specialname'] ?? ''}',
              cover: '${entry['img'] ?? entry['imgurl'] ?? ''}'.replaceFirst('{size}', '240'),
              author: '${entry['nickname'] ?? ''}',
              trackCount: (entry['songcount'] as num?)?.toInt() ?? 0,
            ),
      ],
      total: 0,
    );
  }

  @override
  Future<(MusicPlaylistInfo, List<audio.MusicTrack>)> playlistDetail(String id) async {
    final globalId = id.startsWith('id_') ? id.substring(3) : id;
    final info = await _specialInfo(globalId);
    final rows = await _specialSongs(globalId);
    final enriched = await _enrich(rows);
    final tracks = <audio.MusicTrack>[];
    final seen = <String>{};
    for (final entry in enriched) {
      if (entry is! Map) continue;
      final track = _enrichedTrackOf(entry.cast<String, Object?>());
      if (track == null || !seen.add('${track.id}:${track.metadata['hash']}')) continue;
      tracks.add(track);
    }
    return (info, tracks);
  }

  Future<MusicPlaylistInfo> _specialInfo(String globalId) async {
    const now = '1586163242519';
    final params =
        'appid=1058&specialid=0&global_specialid=$globalId&format=json&srcappid=2919&clientver=20000'
        '&clienttime=$now&mid=$now&uuid=$now&dfid=-';
    final json = jsonDecode(
      await getText(
        Uri.https('mobiles.kugou.com', '/api/v5/special/info_v2', _signed(params)),
        headers: _mobileHeaders,
      ),
    ) as Map<String, Object?>;
    final data = json['data'];
    final info = data is Map ? data['info'] : null;
    if (info is! Map) return MusicPlaylistInfo(id: globalId, name: '', cover: '', author: '', trackCount: 0);
    return MusicPlaylistInfo(
      id: globalId,
      name: '${info['specialname'] ?? info['name'] ?? ''}',
      cover: '${info['img'] ?? info['imgurl'] ?? ''}'.replaceFirst('{size}', '240'),
      author: '${info['nickname'] ?? info['list_create_username'] ?? ''}',
      trackCount: (info['count'] as num?)?.toInt() ?? 0,
    );
  }

  Future<List<Map<String, Object?>>> _specialSongs(String globalId) async {
    final rows = <Map<String, Object?>>[];
    var page = 0;
    var total = 1;
    while (rows.length < total) {
      page += 1;
      const now = '1586163263991';
      final params =
          'appid=1058&global_specialid=$globalId&specialid=0&plat=0&version=8000&page=$page'
          '&pagesize=300&srcappid=2919&clientver=20000&clienttime=$now&mid=$now&uuid=$now&dfid=-';
      final json = jsonDecode(
        await getText(
          Uri.https('mobiles.kugou.com', '/api/v5/special/song_v2', _signed(params)),
          headers: _mobileHeaders,
        ),
      ) as Map<String, Object?>;
      final data = json['data'];
      if (data is! Map) break;
      total = (data['total'] as num?)?.toInt() ?? 0;
      final raw = data['info'];
      if (raw is! List || raw.isEmpty) break;
      rows.addAll([
        for (final entry in raw)
          if (entry is Map) entry.cast<String, Object?>(),
      ]);
    }
    return rows;
  }

  static const Map<String, String> _mobileHeaders = {
    'mid': '1586163263991',
    'Referer': 'https://m3ws.kugou.com/share/index.php',
    'User-Agent':
        'Mozilla/5.0 (iPhone; CPU iPhone OS 11_0 like Mac OS X) AppleWebKit/604.1.38 (KHTML, like Gecko) '
        'Version/11.0 Mobile/15A372 Safari/604.1',
    'dfid': '-',
    'clienttime': '1586163263991',
  };

  /// lx-music's `signatureParams`: sort the query pairs, salt with the
  /// platform key front and back, MD5 the whole thing.
  static Map<String, String> _signed(String params) {
    final pairs = params.split('&')..sort();
    const key = 'NVPh5oo715z5DIWAeQlhMDsWXXQV4hwt';
    final sign = md5.convert(utf8.encode('$key${pairs.join()}$key')).toString();
    final query = <String, String>{};
    for (final pair in params.split('&')) {
      final split = pair.indexOf('=');
      if (split > 0) query[pair.substring(0, split)] = pair.substring(split + 1);
    }
    query['signature'] = sign;
    return query;
  }

  /// The gateway answers a posted hash batch with full song rows; the fixed
  /// headers and key are lx-music's `createGetMusicInfosTask`.
  Future<List<Object?>> _enrich(List<Map<String, Object?>> rows) async {
    if (rows.isEmpty) return const <Object?>[];
    const gatewayHeaders = {
      'KG-THash': '13a3164',
      'KG-RC': '1',
      'KG-Fake': '0',
      'KG-RF': '00869891',
      'User-Agent': 'Android712-AndroidPhone-11451-376-0-FeeCacheUpdate-wifi',
      'x-router': 'kmr.service.kugou.com',
      'Content-Type': 'application/json',
    };
    final answers = <Object?>[];
    for (var i = 0; i < rows.length; i += 100) {
      final batch = {
        'area_code': '1',
        'show_privilege': 1,
        'show_album_info': '1',
        'is_publish': '',
        'appid': 1005,
        'clientver': 11451,
        'mid': '1',
        'dfid': '-',
        'clienttime': DateTime.now().millisecondsSinceEpoch,
        'key': 'OIlwieks28dk2k092lksi2UIkp',
        'fields': 'album_info,author_name,audio_info,ori_audio_name,base,songname,classification',
        'data': rows.sublist(i, (i + 100).clamp(0, rows.length)),
      };
      try {
        final answer = await postJson(Uri.http('gateway.kugou.com', '/v3/album_audio/audio'), gatewayHeaders, batch);
        if (answer is List) {
          for (final entry in answer) {
            if (entry is List && entry.isNotEmpty && entry.first is Map) {
              answers.add((entry.first as Map).cast<String, Object?>());
            }
          }
        }
      } on Object {
        // A batch that fails loses its rows, not the playlist.
      }
    }
    return answers;
  }

  static audio.MusicTrack? _enrichedTrackOf(Map<String, Object?> raw) {
    final audioInfo = raw['audio_info'];
    final albumInfo = raw['album_info'];
    if (audioInfo is! Map) return null;
    final info = audioInfo.cast<String, Object?>();
    final id = '${info['audio_id'] ?? ''}';
    final title = '${raw['songname'] ?? raw['ori_audio_name'] ?? ''}'.trim();
    if (id.isEmpty || title.isEmpty) return null;
    final hashes = <String, String>{};
    void put(String quality, Object? size, Object? hash) {
      if ('$size' != '0' && size != null && hash is String && hash.isNotEmpty) hashes[quality] = hash;
    }

    put('128k', info['filesize'], info['hash']);
    put('320k', info['filesize_320'], info['hash_320']);
    put('flac', info['filesize_flac'], info['hash_flac']);
    put('flac24bit', info['filesize_high'], info['hash_high']);
    final qualityIds = ['128k', '320k', 'flac', 'flac24bit'].where(hashes.containsKey).toList();
    final millis = int.tryParse('${info['timelength'] ?? ''}');
    final album = albumInfo is Map ? albumInfo.cast<String, Object?>() : const <String, Object?>{};
    return audio.MusicTrack(
      id: id,
      sourceId: 'kg',
      title: title,
      artist: '${raw['author_name'] ?? ''}',
      album: '${album['album_name'] ?? ''}',
      albumId: '${album['album_id'] ?? ''}',
      duration: millis == null ? null : Duration(milliseconds: millis),
      qualities: [for (final quality in qualityIds) LxPlatformSource.qualityOf(quality)],
      metadata: {
        'types': qualityIds,
        'albumId': '${album['album_id'] ?? ''}',
        'hash': hashes['128k'] ?? hashes.values.firstOrNull ?? '',
        'hashes': hashes,
      },
    );
  }

  /// Search rows may carry alternate takes under `Grp`; lx-music flattens
  /// them into sibling tracks and dedupes on audioid+hash.
  static List<audio.MusicTrack>? _tracksOf(Object? entry) {
    if (entry is! Map) return null;
    final rows = <Map<String, Object?>>[entry.cast<String, Object?>()];
    final grp = entry['Grp'];
    if (grp is List) {
      for (final child in grp) {
        if (child is Map) rows.add(child.cast<String, Object?>());
      }
    }
    final tracks = <audio.MusicTrack>[];
    final seen = <String>{};
    for (final row in rows) {
      final track = _trackOf(
        row,
        songmid: '${row['Audioid'] ?? ''}',
        title: '${row['OriSongName'] ?? ''}',
        suffix: '${row['Suffix'] ?? ''}',
        singers: row['Singers'],
        albumName: '${row['AlbumName'] ?? ''}',
        albumId: '${row['AlbumID'] ?? ''}',
      );
      if (track == null) continue;
      if (!seen.add('${track.id}:${track.metadata['hash']}')) continue;
      tracks.add(track);
    }
    return tracks;
  }

  static audio.MusicTrack? _boardTracksOf(Object? entry) {
    if (entry is! Map) return null;
    return _trackOf(
      entry.cast<String, Object?>(),
      songmid: '${entry['audio_id'] ?? ''}',
      title: '${entry['songname'] ?? ''}',
      suffix: '',
      singers: entry['authors'],
      singerKey: 'author_name',
      albumName: '${entry['remark'] ?? ''}',
      albumId: '${entry['album_id'] ?? ''}',
    );
  }

  static audio.MusicTrack? _trackOf(
    Map<String, Object?> raw, {
    required String songmid,
    required String title,
    required String suffix,
    required Object? singers,
    required String albumName,
    required String albumId,
    String singerKey = 'name',
  }) {
    final named = title.isEmpty ? '${raw['SongName'] ?? ''}' : title;
    final name = LxPlatformSource.decodeName(suffix.isEmpty ? named : '$named $suffix').trim();
    if (songmid.isEmpty || name.isEmpty) return null;
    final artist = _singersOf(singers, singerKey);
    final hashes = <String, String>{};
    void put(String quality, Object? size, Object? hash) {
      if (size is num && size != 0 && hash is String && hash.isNotEmpty) hashes[quality] = hash;
    }

    put('128k', raw['FileSize'] ?? raw['filesize'], raw['FileHash'] ?? raw['hash']);
    put('320k', raw['HQFileSize'] ?? raw['320filesize'], raw['HQFileHash'] ?? raw['320hash']);
    put('flac', raw['SQFileSize'] ?? raw['sqfilesize'], raw['SQFileHash'] ?? raw['sqhash']);
    put('flac24bit', raw['ResFileSize'] ?? raw['filesize_high'], raw['ResFileHash'] ?? raw['hash_high']);
    final seconds = raw['Duration'] ?? raw['duration'];
    final duration = seconds is num ? Duration(seconds: seconds.toInt()) : null;
    final qualityIds = ['128k', '320k', 'flac', 'flac24bit'].where(hashes.containsKey).toList();
    final album = LxPlatformSource.decodeName(albumName).trim();
    return audio.MusicTrack(
      id: songmid,
      sourceId: 'kg',
      title: name,
      artist: artist,
      album: album,
      albumId: albumId.isEmpty ? null : albumId,
      duration: duration,
      qualities: [for (final quality in qualityIds) LxPlatformSource.qualityOf(quality)],
      metadata: {
        'types': qualityIds,
        'albumId': albumId,
        'hash': hashes['128k'] ?? hashes.values.firstOrNull ?? '',
        'hashes': hashes,
      },
    );
  }

  static String _singersOf(Object? singers, String key) {
    if (singers is! List) return '';
    return [
      for (final singer in singers)
        if (singer is Map && singer[key] is String) singer[key] as String,
    ].join('、');
  }

  /// The hot-search board lx-music's kg `hotSearch.js` rides: a fixed
  /// signature on the gateway's hot_tab, keywords nested per row.
  @override
  Future<List<String>> hotSearches() async {
    try {
      final json = jsonDecode(
        await getText(
          Uri.http('gateway.kugou.com', '/api/v3/search/hot_tab', {
            'signature': 'ee44edb9d7155821412d220bcaf509dd',
            'appid': '1005',
            'clientver': '10026',
            'plat': '0',
          }),
          headers: {
            'dfid': '1ssiv93oVqMp27cirf2CvoF1',
            'mid': '156798703528610303473757548878786007104',
            'clienttime': '1584257267',
            'x-router': 'msearch.kugou.com',
            'User-Agent': 'Android9-AndroidPhone-10020-130-0-searchrecommendprotocol-wifi',
            'kg-rc': '1',
          },
        ),
      ) as Map<String, Object?>;
      final data = json['data'];
      if (json['errcode'] != 0 || data is! Map) return const [];
      final raw = data['list'];
      final words = <String>[];
      if (raw is List) {
        for (final row in raw) {
          if (row is! Map) continue;
          final keywords = row['keywords'];
          if (keywords is! List) continue;
          for (final keyword in keywords) {
            if (keyword is! Map) continue;
            final word = LxPlatformSource.decodeName('${keyword['keyword'] ?? ''}').trim();
            if (word.isNotEmpty) words.add(word);
          }
        }
      }
      return words;
    } on Object {
      return const [];
    }
  }

  /// The completions for a partially typed query — the reference's
  /// `tipSearch.js` on searchtip.kugou.com; the answer is a one-element list.
  @override
  Future<List<String>> suggestions(String query) async {
    try {
      final json = jsonDecode(
        await getText(
          Uri.https('searchtip.kugou.com', '/getSearchTip', {'MusicTipCount': '10', 'keyword': query}),
          headers: {'Referer': 'https://www.kugou.com/'},
        ),
      );
      final record = json is List && json.isNotEmpty && json.first is Map ? (json.first as Map)['RecordDatas'] : null;
      if (record is! List) return const [];
      return [
        for (final entry in record)
          if (entry is Map && entry['HintInfo'] is String)
            if ((entry['HintInfo'] as String).trim().isNotEmpty) (entry['HintInfo'] as String).trim(),
      ];
    } on Object {
      return const [];
    }
  }

  /// One page of a song's comments, hot (topliked) or newest — the reference's
  /// kg `comment.js`, signed like every mobiles.kugou.com call.
  @override
  Future<MusicCommentsPage> comments(audio.MusicTrack track, {required bool hot, required int page, int pageSize = 20}) async {
    final hash = '${track.metadata['hash'] ?? ''}';
    if (hash.isEmpty) throw StateError('kg comments need a file hash');
    final params = 'dfid=0&mid=16249512204336365674023395779019'
        '&clienttime=${DateTime.now().millisecondsSinceEpoch}'
        '&uuid=0&extdata=$hash&appid=1005&code=fc4be23b4e972707f36b8a828a93ba8a&schash=$hash'
        '&clientver=11409&p=$page&clienttoken=&pagesize=$pageSize&ver=10&kugouid=0';
    final json = jsonDecode(
      await getText(
        Uri.http(
          'm.comment.service.kugou.com',
          hot ? '/r/v1/rank/topliked' : '/r/v1/rank/newest',
          _signed(params),
        ),
        headers: {'User-Agent': _commentUserAgent},
      ),
    ) as Map<String, Object?>;
    if (json['err_code'] != 0) throw StateError('kg comments answered ${json['err_code']}');
    final rows = json['list'];
    final total = (json['count'] as num?)?.toInt() ?? 0;
    return (comments: commentsOf(rows is List ? rows : const [], _commentOf), hasMore: page * pageSize < total);
  }

  /// A row starting with `pcontent` is a reply wrapper: its own text becomes
  /// the parent comment and the content row nests under it.
  static MusicComment? _commentOf(Map<String, Object?> raw) {
    final quoted = commentTextOf(raw['pcontent']);
    final own = _commentRowOf(raw);
    if (quoted == null) return own;
    if (own == null) return null;
    return MusicComment(
      id: own.id,
      text: LxPlatformSource.decodeName(quoted),
      userName: '${raw['puser'] ?? ''}',
      replies: [own],
    );
  }

  static MusicComment? _commentRowOf(Map<String, Object?> raw) {
    var text = LxPlatformSource.decodeName('${raw['content'] ?? ''}').trim();
    if (text.isEmpty) return null;
    final atlist = raw['atlist'];
    if (atlist is List) {
      for (final at in atlist) {
        if (at is Map) text = text.replaceAll('[at=${at['id']}]', '@${at['name']} ');
      }
    }
    final like = raw['like'];
    return MusicComment(
      id: '${raw['id'] ?? ''}',
      text: text,
      userName: '${raw['user_name'] ?? ''}',
      avatar: commentTextOf(raw['user_pic']),
      time: commentTimeOf(raw['addtime']),
      likedCount: like is Map ? int.tryParse('${like['likenum'] ?? ''}') ?? 0 : 0,
    );
  }
}

/// The desktop user agent kg's comment service only answers with.
const String _commentUserAgent =
    'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/107.0.0.0 Safari/537.36 Edg/107.0.1418.24';
