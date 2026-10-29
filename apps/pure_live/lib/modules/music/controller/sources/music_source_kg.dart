import 'dart:convert' show base64, jsonDecode, utf8;

import 'package:media_core_audio/media_core_audio.dart' as audio;

import 'package:pure_live/modules/music/controller/sources/lx_platform_source.dart';

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
final class KgMusicSource extends LxPlatformSource {
  /// A KuGou source over the lx runtime.
  KgMusicSource(super.runtime);

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
      // KRC needs the word-timed decoder the lyric module owns; until a track
      // has no plain candidate, prefer one whose answer is plain LRC.
      Map<String, Object?>? chosen;
      for (final candidate in candidates) {
        if (candidate is! Map) continue;
        if (candidate['krctype'] != 1 || candidate['contenttype'] == 1) {
          chosen = candidate.cast<String, Object?>();
          break;
        }
        chosen ??= candidate.cast<String, Object?>();
      }
      if (chosen == null) return null;
      final candidate = chosen;
      final downloadUri = Uri.http('lyrics.kugou.com', '/download', {
        'ver': '1',
        'client': 'pc',
        'id': '${candidate['id']}',
        'accesskey': '${candidate['accesskey']}',
        'fmt': 'lrc',
        'charset': 'utf8',
      });
      final download = jsonDecode(await getText(downloadUri, headers: _krcHeaders)) as Map<String, Object?>;
      final status = download['status'];
      if (download['fmt'] == 'krc' || (status is num && status != 200)) return null;
      final content = download['content'];
      if (content is! String || content.isEmpty) return null;
      final lyric = utf8.decode(base64.decode(content), allowMalformed: true);
      if (lyric.trim().isEmpty) return null;
      return audio.MusicLyricPayload(lyric: lyric);
    } on Object {
      return null;
    }
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
}
