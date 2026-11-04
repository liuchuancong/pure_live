import 'dart:convert' show jsonDecode;
import 'dart:math' show Random;

import 'package:media_core_audio/media_core_audio.dart' as audio;

import 'package:pure_live/modules/music/controller/music_comments.dart' show MusicComment;
import 'package:pure_live/modules/music/controller/sources/lx_platform_source.dart';
import 'package:pure_live/modules/music/controller/sources/music_browse_source.dart';
import 'package:pure_live/modules/music/controller/sources/music_comment_source.dart';
import 'package:pure_live/modules/music/controller/sources/music_hot_words.dart';
import 'package:pure_live/modules/music/controller/sources/music_source_failure.dart';
import 'package:pure_live/modules/music/controller/sources/online_playlist_models.dart'
    show
        MusicPlaylistInfo,
        MusicPlaylistPage,
        MusicPlaylistTag,
        MusicPlaylistTagGroup,
        MusicPlazaSort,
        OnlinePlaylists,
        PlaylistTagTree,
        SonglistSearch;

/// The Kuwo boards lx-music exposes, in its own order.
const List<(int, String)> kMusicRankCatalogs = [
  (93, '飙升榜'),
  (16, '热歌榜'),
  (145, '会员榜'),
  (158, '抖音榜'),
  (187, '趋势榜'),
  (26, '怀旧榜'),
  (104, '华语榜'),
  (182, '粤语榜'),
  (22, '欧美榜'),
  (184, '韩语榜'),
  (183, '日语榜'),
];

/// Kuwo's hot-word endpoint only answers the mobile client's user agent.
const String _hotUserAgent = 'Dalvik/2.1.0 (Linux; U; Android 9;)';

/// The Kuwo platform: search, boards, playlists and lyrics ride Kuwo's own
/// channel; play URLs are asked from the lx scripts first, with Kuwo's
/// anti-server as the fallback.
final class KwMusicSource extends LxPlatformSource
    with SonglistSearch, OnlinePlaylists, PlaylistTagTree
    implements MusicHotWords, MusicCommentsSource, MusicAlbumSource, MusicArtistSource {
  /// A Kuwo source over the lx runtime.
  KwMusicSource(super.runtime, super.http);

  @override
  String get id => 'kw';

  @override
  String get name => '酷我音乐';

  @override
  Map<String, String> get playHeaders => {'User-Agent': platformUserAgent, 'Referer': 'https://www.kuwo.cn/'};

  @override
  Future<audio.MusicSourcePage<audio.MusicTrack>> search(String keyword, {int page = 1, int pageSize = 30}) async {
    await runtime.ensureLoaded();
    final uri = Uri.https('search.kuwo.cn', '/r.s', {
      'client': 'kt',
      'all': keyword,
      'pn': '${page - 1}',
      'rn': '$pageSize',
      'uid': '794762570',
      'ver': 'kwplayer_ar_9.2.2.1',
      'vipver': '1',
      'show_copyright_off': '1',
      'newver': '1',
      'ft': 'music',
      'cluster': '0',
      'strategy': '2012',
      'encoding': 'utf8',
      'rformat': 'json',
      'vermerge': '1',
      'mobi': '1',
      'issubtitle': '1',
    });
    final json = jsonDecode(await getText(uri)) as Map<String, Object?>;
    final total = int.tryParse('${json['TOTAL'] ?? ''}') ?? 0;
    final raw = json['abslist'];
    final items = raw is List
        ? [
            for (final entry in raw)
              if (entry is Map) ?trackOf(entry.cast<String, Object?>(), scriptQualities()),
          ]
        : const <audio.MusicTrack>[];
    return audio.MusicSourcePage(items: items, page: page, total: total, hasMore: total > page * pageSize);
  }

  /// One page of the keyword's playlists — the reference's kw `songList`
  /// search: the r.s gateway again, this time with `ft=playlist`.
  @override
  Future<MusicPlaylistPage> searchPlaylists(String keyword, {int page = 1, int pageSize = 20}) async {
    final uri = Uri.https('search.kuwo.cn', '/r.s', {
      'all': keyword,
      'pn': '${page - 1}',
      'rn': '$pageSize',
      'rformat': 'json',
      'encoding': 'utf8',
      'ver': 'mbox',
      'vipver': 'MUSIC_8.7.7.0_BCS37',
      'plat': 'pc',
      'devid': '28156413',
      'ft': 'playlist',
      'pay': '0',
      'needliveshow': '0',
    });
    // The gateway answers this `ft` as a Python repr, not JSON — the reference
    // runs the same body through its `objStr2JSON` first.
    final json = jsonDecode(_reprToJson(await getText(uri))) as Map<String, Object?>;
    final raw = json['abslist'];
    if (raw is! List) return const MusicPlaylistPage(items: [], total: 0);
    final total = int.tryParse('${json['TOTAL'] ?? ''}') ?? 0;
    return MusicPlaylistPage(
      items: [
        for (final entry in raw)
          if (entry is Map)
            MusicPlaylistInfo(
              id: '${entry['playlistid'] ?? ''}',
              name: LxPlatformSource.decodeName('${entry['name'] ?? ''}').trim(),
              cover: '${entry['pic'] ?? ''}',
              author: LxPlatformSource.decodeName('${entry['nickname'] ?? ''}').trim(),
              trackCount: int.tryParse('${entry['songnum'] ?? ''}') ?? 0,
              playCount: int.tryParse('${entry['playcnt'] ?? ''}') ?? 0,
            ),
      ],
      total: total,
    );
  }

  /// The plaza pages 36 lists a page — the reference's `limit_list`.
  static const int _plazaLimit = 36;

  /// Kuwo's hot plaza tags, from its pc classify `getRcmTagList` — the set the
  /// online-playlist browser starts from.
  @override
  Future<List<MusicPlaylistTag>> hotTags() async {
    final json = jsonDecode(
      await getText(
        Uri.http('wapi.kuwo.cn', '/api/pc/classify/playlist/getRcmTagList', {
          'loginUid': '0',
          'loginSid': '0',
          'appUid': '76039576',
        }),
      ),
    ) as Map<String, Object?>;
    final data = json['data'];
    final raw = data is List && data.isNotEmpty && data.first is Map ? (data.first as Map)['data'] : null;
    if (raw is! List) return const <MusicPlaylistTag>[];
    // Kuwo's listing call takes the tag's `id-digest` pair, so that is the
    // tag's request half; the name is only what the chip shows.
    return [
      for (final entry in raw)
        if (entry is Map && '${entry['name'] ?? ''}'.trim().isNotEmpty)
          MusicPlaylistTag(id: '${entry['id'] ?? ''}-${entry['digest'] ?? ''}', name: '${entry['name'] ?? ''}'.trim()),
    ];
  }

  /// The plaza's category tree — the reference's `getTagList`, each tag's
  /// request id the `id-digest` pair its listing call splits apart.
  @override
  Future<List<MusicPlaylistTagGroup>> tagGroups() async {
    final json = jsonDecode(
      await getText(
        Uri.http('wapi.kuwo.cn', '/api/pc/classify/playlist/getTagList', {
          'cmd': 'rcm_keyword_playlist',
          'user': '0',
          'prod': 'kwplayer_pc_9.0.5.0',
          'vipver': '9.0.5.0',
          'source': 'kwplayer_pc_9.0.5.0',
          'loginUid': '0',
          'loginSid': '0',
          'appUid': '76039576',
        }),
      ),
    ) as Map<String, Object?>;
    final data = json['data'];
    if (json['code'] != 200 || data is! List) return const <MusicPlaylistTagGroup>[];
    return [
      for (final group in data)
        if (group is Map && '${group['name'] ?? ''}'.isNotEmpty)
          MusicPlaylistTagGroup(
            name: '${group['name']}',
            tags: [
              if (group['data'] is List)
                for (final tag in group['data'] as List)
                  if (tag is Map && '${tag['name'] ?? ''}'.trim().isNotEmpty)
                    MusicPlaylistTag(id: '${tag['id'] ?? ''}-${tag['digest'] ?? ''}', name: '${tag['name']}'),
            ],
          ),
    ];
  }

  /// The plaza's sort tabs — the reference's kw `sortList`, the order codes
  /// the recommend flow answers by.
  @override
  List<MusicPlazaSort> get sorts => const [
    MusicPlazaSort(id: 'new', name: '最新'),
    MusicPlazaSort(id: 'hot', name: '最热'),
  ];

  @override
  Future<MusicPlaylistPage> playlists({String tag = '', String order = 'new', int page = 1, int pageSize = 30}) async {
    if (tag.trim().isEmpty) return await _recommendPage(order: order, page: page);
    final resolved = _resolveTag(tag);
    if (resolved == null) return const MusicPlaylistPage(items: [], total: 0);
    final (id, digest) = resolved;
    if (digest == '10000') {
      final json = jsonDecode(
        await getText(
          Uri.http('wapi.kuwo.cn', '/api/pc/classify/playlist/getTagPlayList', {
            'loginUid': '0',
            'loginSid': '0',
            'appUid': '76039576',
            'pn': '$page',
            'id': id,
            'rn': '$_plazaLimit',
          }),
        ),
      ) as Map<String, Object?>;
      final data = json['data'];
      if (json['code'] != 200 || data is! Map) return const MusicPlaylistPage(items: [], total: 0);
      return MusicPlaylistPage(items: _plazaPlaylistsOf(data['data']), total: _intOf(data['total']) ?? 0);
    }
    // The other digests are the 专题 pages: the qz gateway answers grouped
    // rows the reference flattens without a total.
    final body = jsonDecode(
      await getText(
        Uri.http('mobileinterfaces.kuwo.cn', '/er.s', {'type': 'get_pc_qz_data', 'f': 'web', 'id': id, 'prod': 'pc'}),
      ),
    ) as Object?;
    return MusicPlaylistPage(items: _qzPlaylistsOf(body is List ? body : const <Object?>[]), total: 1000);
  }

  /// The tag's request halves — the reference splits the `id-digest` pair the
  /// plaza's tags are keyed by, and a tag that carries no digest is not one
  /// this call can answer.
  (String, String)? _resolveTag(String tag) {
    final trimmed = tag.trim();
    final dash = trimmed.indexOf('-');
    return dash > 0 ? (trimmed.substring(0, dash), trimmed.substring(dash + 1)) : null;
  }

  /// The recommend flow — the reference's getRcmPlayList, the only page the
  /// sort codes answer.
  Future<MusicPlaylistPage> _recommendPage({required String order, required int page}) async {
    final json = jsonDecode(
      await getText(
        Uri.http('wapi.kuwo.cn', '/api/pc/classify/playlist/getRcmPlayList', {
          'loginUid': '0',
          'loginSid': '0',
          'appUid': '76039576',
          'pn': '$page',
          'rn': '$_plazaLimit',
          'order': order,
        }),
      ),
    ) as Map<String, Object?>;
    final data = json['data'];
    if (json['code'] != 200 || data is! Map) return const MusicPlaylistPage(items: [], total: 0);
    return MusicPlaylistPage(items: _plazaPlaylistsOf(data['data']), total: _intOf(data['total']) ?? 0);
  }

  /// Kuwo's `r.s` answers some `ft` values as a Python repr — a dict of
  /// single-quoted keys and values — which is not JSON, so `jsonDecode` throws
  /// on the second character. Only the delimiters become double quotes: outside
  /// a quoted run every `'` opens one, and one ends only when the next
  /// non-space is a structural mark (`: , } ]`) or the text stops — so an
  /// apostrophe inside a name survives. The reference does the same with
  /// look-behind patterns, which Dart's RegExp cannot express.
  static String _reprToJson(String text) {
    final out = StringBuffer();
    var inString = false;
    for (var index = 0; index < text.length; index++) {
      final char = text[index];
      if (char != "'") {
        out.write(char);
        continue;
      }
      if (!inString) {
        inString = true;
        out.write('"');
        continue;
      }
      var next = index + 1;
      while (next < text.length && text[next] == ' ') {
        next++;
      }
      if (next >= text.length || const <String>{':', ',', '}', ']'}.contains(text[next])) {
        inString = false;
        out.write('"');
      } else {
        out.write(char);
      }
    }
    return out.toString();
  }

  /// A number the platform may answer either as a JSON number or as a decimal
  /// string — the wapi counts are strings on some digests — so a cast would
  /// throw on whichever shape it chose. Null stays null: it is the model's own
  /// "the platform never said".
  static int? _intOf(Object? raw) {
    if (raw == null) return null;
    if (raw is num) return raw.toInt();
    return int.tryParse('$raw'.trim());
  }

  /// The plaza rows the wapi answers — the reference's `filterList`, the
  /// `digest-<digest>__<id>` compound id the detail dispatch re-reads.
  List<MusicPlaylistInfo> _plazaPlaylistsOf(Object? raw) {
    if (raw is! List) return const <MusicPlaylistInfo>[];
    return [
      for (final entry in raw)
        if (entry is Map && '${entry['name'] ?? ''}'.trim().isNotEmpty)
          MusicPlaylistInfo(
            id: 'digest-${entry['digest'] ?? ''}__${entry['id'] ?? ''}',
            name: LxPlatformSource.decodeName('${entry['name']}').trim(),
            cover: '${entry['img'] ?? ''}',
            author: LxPlatformSource.decodeName('${entry['uname'] ?? ''}').trim(),
            trackCount: _intOf(entry['total']) ?? 0,
            playCount: _intOf(entry['listencnt']) ?? 0,
          ),
    ];
  }

  /// The 专题 flow's rows — the reference's `filterList2`, the grouped qz
  /// payload flattened to the songlist/list/album kinds.
  List<MusicPlaylistInfo> _qzPlaylistsOf(List<Object?> groups) {
    const allowed = {'songlist', 'list', 'album'};
    return [
      for (final group in groups)
        if (group is Map && group['list'] is List)
          for (final entry in group['list'] as List)
            if (entry is Map &&
                allowed.contains('${entry['type'] ?? ''}') &&
                '${entry['name'] ?? ''}'.trim().isNotEmpty)
              MusicPlaylistInfo(
                id: 'digest-${entry['digest'] ?? ''}__${entry['id'] ?? ''}',
                name: LxPlatformSource.decodeName('${entry['name']}').trim(),
                cover: '${entry['img'] ?? ''}',
                author: LxPlatformSource.decodeName('${entry['uname'] ?? ''}').trim(),
                trackCount: _intOf(entry['total']) ?? 0,
              ),
    ];
  }

  /// The playlist's link shapes — the reference's `listDetailLink`, the
  /// www/h5 playlist urls a paste carries.
  static final RegExp _listDetailLink = RegExp(r'^.+\/playlist(?:_detail)?\/(\d+)(?:\?.*|&.*$|#.*$|$)');

  /// The bd-api pages answer the desktop browser agent with the h5 plat mark.
  static const Map<String, String> _bodianHeaders = {
    'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; WOW64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/86.0.4240.198 Safari/537.36',
    'plat': 'h5',
  };

  @override
  Future<(MusicPlaylistInfo, List<audio.MusicTrack>)> playlistDetail(String rawId) async {
    final id = rawId.trim();
    if (id.contains('/bodian/')) return await _bodianDetail(id);
    if (RegExp('[?&:/]').hasMatch(id)) {
      final match = _listDetailLink.firstMatch(id);
      if (match == null) throw StateError('kuwo playlist link not understood: $id');
      return await _listDetail(match[1]!);
    }
    if (id.startsWith('digest-')) {
      final split = id.split('__');
      final digest = split.first.replaceFirst('digest-', '');
      final inner = split.length > 1 ? split.last : '';
      return await switch (digest) {
        '13' => _albumPlaylist(inner),
        '8' => _listDetail(inner),
        _ => _digest5Detail(inner),
      };
    }
    return await _listDetail(id);
  }

  /// The songlist detail — the reference's `getListDetailDigest8`, pl.svc's
  /// paginated getlistinfo walked to the end.
  Future<(MusicPlaylistInfo, List<audio.MusicTrack>)> _listDetail(String pid) async {
    final rows = <Map<String, Object?>>[];
    var page = 0;
    var total = 1;
    MusicPlaylistInfo? info;
    while (rows.length < total) {
      page += 1;
      final json = jsonDecode(
        await getText(
          Uri.http('nplserver.kuwo.cn', '/pl.svc', {
            'op': 'getlistinfo',
            'pid': pid,
            'pn': '${page - 1}',
            'rn': '1000',
            'encode': 'utf8',
            'keyset': 'pl2012',
            'identity': 'kuwo',
            'pcmp4': '1',
            'vipver': 'MUSIC_9.0.5.0_W1',
            'newver': '1',
          }),
        ),
      ) as Map<String, Object?>;
      if (json['result'] != 'ok') throw StateError('kuwo playlist detail failed: $pid');
      total = int.tryParse('${json['total'] ?? ''}') ?? 0;
      final raw = json['musiclist'];
      if (raw is! List || raw.isEmpty) break;
      rows.addAll([
        for (final entry in raw)
          if (entry is Map) entry.cast<String, Object?>(),
      ]);
      info ??= MusicPlaylistInfo(
        id: pid,
        name: LxPlatformSource.decodeName('${json['title'] ?? ''}').trim(),
        cover: '${json['pic'] ?? ''}',
        author: LxPlatformSource.decodeName('${json['uname'] ?? ''}').trim(),
        trackCount: total,
        playCount: int.tryParse('${json['playnum'] ?? ''}') ?? 0,
      );
    }
    if (info == null) throw StateError('kuwo playlist detail empty: $pid');
    final tracks = <audio.MusicTrack>[];
    for (final entry in rows) {
      final track = trackOf(entry, scriptQualities());
      if (track != null) tracks.add(track);
    }
    return (info, tracks);
  }

  /// The list digest — the reference's `getListDetailDigest5`: qukudata's
  /// ninfo names the real pl.svc id first.
  Future<(MusicPlaylistInfo, List<audio.MusicTrack>)> _digest5Detail(String id) async {
    final json = jsonDecode(
      await getText(
        Uri.http('qukudata.kuwo.cn', '/q.k', {
          'op': 'query',
          'cont': 'ninfo',
          'node': id,
          'pn': '0',
          'rn': '1',
          'fmt': 'json',
          'src': 'mbox',
          'level': '2',
        }),
      ),
    ) as Map<String, Object?>;
    final child = json['child'];
    final sourceid = child is List && child.isNotEmpty && child.first is Map
        ? '${(child.first as Map)['sourceid'] ?? ''}'
        : '';
    if (sourceid.isEmpty) throw StateError('kuwo playlist id unresolved: $id');
    return await _listDetail(sourceid);
  }

  /// The album digest — the reference routes it to kw `album.js`: the r.s
  /// albuminfo page answers the album's own facts and its tracks together.
  ///
  /// The mobile parameter set is the one that answers strict JSON; the
  /// browser set answers a single-quoted object `jsonDecode` refuses.
  @override
  Future<MusicAlbumDetail> album(String albumId) => _albumDetail(albumId);

  /// The album as the playlist pages name it.
  Future<(MusicPlaylistInfo, List<audio.MusicTrack>)> _albumPlaylist(String albumId) async {
    final (:album, :tracks) = await _albumDetail(albumId);
    return (
      MusicPlaylistInfo(
        id: album.id,
        name: album.name,
        cover: album.coverUri?.toString() ?? '',
        author: album.artist,
        trackCount: album.trackCount,
      ),
      tracks,
    );
  }

  Future<MusicAlbumDetail> _albumDetail(String albumId) async {
    final json = jsonDecode(
      await getText(
        Uri.https('search.kuwo.cn', '/r.s', {
          'pn': '0',
          'rn': '1000',
          'stype': 'albuminfo',
          'albumid': albumId,
          'show_copyright_off': '0',
          'encoding': 'utf',
          'vipver': 'MUSIC_9.1.0',
          'mobi': '1',
          'newver': '1',
          'client': 'kt',
          'uid': '0',
          'rformat': 'json',
        }),
      ),
    ) as Map<String, Object?>;
    final raw = json['musiclist'];
    if (raw is! List) throw StateError('kuwo album detail failed: $albumId');
    final albumName = LxPlatformSource.decodeName('${json['name'] ?? ''}').trim();
    final artistId = '${json['artistid'] ?? ''}'.trim();
    final cover = '${json['hts_img'] ?? json['img'] ?? ''}'.trim();
    final album = MusicAlbum(
      id: albumId,
      name: albumName,
      artist: LxPlatformSource.decodeName('${json['artist'] ?? ''}').trim(),
      artistId: artistId.isEmpty ? null : artistId,
      coverUri: cover.isEmpty ? null : Uri.tryParse(cover),
      trackCount: int.tryParse('${json['songnum'] ?? ''}') ?? raw.length,
      year: _yearOf(json['pub']),
    );
    final tracks = <audio.MusicTrack>[
      for (final entry in raw)
        if (entry is Map) ?_albumTrackOf(entry.cast<String, Object?>(), albumName, albumId, cover),
    ];
    return (album: album, tracks: tracks);
  }

  /// The artist's page — who they are, their songs and their albums.
  ///
  /// Kuwo answers no artist track list to a plain request, so the songs are
  /// the platform's own search for the artist, kept to the rows it credits
  /// to them; the albums are its album search under the same filter, and the
  /// profile is the artist card when [artistId] is already known.
  @override
  Future<MusicArtistDetail> artist(String name, {String? artistId}) async {
    final subject = musicMainArtist(name);
    final songs = await _artistSongs(subject);
    final albums = await _artistAlbums(subject);
    final id = artistId ?? _artistIdIn(songs) ?? _artistIdInAlbums(albums);
    final profile = id == null ? null : await _artistProfile(id);
    return (name: profile?.name ?? subject, artistId: id, avatarUri: profile?.avatar, songs: songs, albums: albums);
  }

  /// The songs the platform's search credits to [name], in its own order.
  Future<List<audio.MusicTrack>> _artistSongs(String name) async {
    final page = await search(name, pageSize: 100);
    return [
      for (final track in page.items)
        if (track.artist.contains(name)) track,
    ];
  }

  /// The albums whose credit line carries [name] — the platform's album
  /// search, whose rows also carry collaborations the artist only features on.
  Future<List<MusicAlbum>> _artistAlbums(String name) async {
    final json = jsonDecode(
      await getText(
        Uri.https('search.kuwo.cn', '/r.s', {
          'all': name,
          'pn': '0',
          'rn': '50',
          'ft': 'album',
          'show_copyright_off': '1',
          'encoding': 'utf8',
          'mobi': '1',
          'newver': '1',
          'client': 'kt',
          'uid': '0',
          'rformat': 'json',
        }),
      ),
    ) as Map<String, Object?>;
    final raw = json['albumlist'];
    if (raw is! List) return const <MusicAlbum>[];
    return [
      for (final entry in raw)
        if (entry is Map && LxPlatformSource.decodeName('${entry['artist'] ?? ''}').contains(name))
          ?_albumOf(entry.cast<String, Object?>()),
    ];
  }

  /// One album-search row as an album card.
  static MusicAlbum? _albumOf(Map<String, Object?> raw) {
    final id = '${raw['albumid'] ?? raw['id'] ?? ''}'.trim();
    final name = LxPlatformSource.decodeName('${raw['name'] ?? ''}').trim();
    if (id.isEmpty || name.isEmpty) return null;
    final artistId = '${raw['artistid'] ?? ''}'.trim();
    final cover = '${raw['hts_img'] ?? raw['img'] ?? ''}'.trim();
    return MusicAlbum(
      id: id,
      name: name,
      artist: LxPlatformSource.decodeName('${raw['artist'] ?? ''}').trim(),
      artistId: artistId.isEmpty ? null : artistId,
      coverUri: cover.isEmpty ? null : Uri.tryParse(cover),
      trackCount: int.tryParse('${raw['musiccnt'] ?? ''}') ?? 0,
      year: _yearOf(raw['pub']),
    );
  }

  /// The artist's card on the platform — its canonical name and avatar; the
  /// page works without it when the platform refuses.
  Future<({String name, Uri? avatar})?> _artistProfile(String artistId) async {
    try {
      final json = jsonDecode(
        await getText(
          Uri.https('search.kuwo.cn', '/r.s', {
            'stype': 'artistinfo',
            'artistid': artistId,
            'pn': '0',
            'rn': '1',
            'show_copyright_off': '1',
            'encoding': 'utf8',
            'mobi': '1',
            'newver': '1',
            'client': 'kt',
            'uid': '0',
            'rformat': 'json',
          }),
        ),
      ) as Map<String, Object?>;
      final name = LxPlatformSource.decodeName('${json['name'] ?? ''}').trim();
      if (name.isEmpty) return null;
      final avatar = '${json['hts_pic'] ?? json['pic'] ?? ''}'.trim();
      return (name: name, avatar: avatar.isEmpty ? null : Uri.tryParse(avatar));
    } on Object catch (error, stackTrace) {
      noteMusicSourceSilence('kw artist profile', error, stackTrace);
      return null;
    }
  }

  /// The first artist id the platform attached to these songs.
  static String? _artistIdIn(List<audio.MusicTrack> songs) {
    for (final song in songs) {
      final id = '${song.metadata['artistId'] ?? ''}'.trim();
      if (id.isNotEmpty) return id;
    }
    return null;
  }

  static String? _artistIdInAlbums(List<MusicAlbum> albums) {
    for (final album in albums) {
      final id = album.artistId;
      if (id != null && id.isNotEmpty) return id;
    }
    return null;
  }

  /// The release year of `pub`/`showtime`, whose values are `yyyy-MM-dd`.
  static int? _yearOf(Object? raw) {
    final match = RegExp(r'^\s*(\d{4})').firstMatch('$raw');
    return match == null ? null : int.tryParse(match.group(1)!);
  }

  /// The album track rows — the reference's album `filterListDetail`, the
  /// `formats` pipe list standing in for the usual N_MINFO.
  /// One song of the album's own list. The row carries a picture only when the
  /// platform chose to fill it in, so an empty one wears the album's cover —
  /// the same picture the page's hero already shows, and the alternative is a
  /// column of initials.
  static audio.MusicTrack? _albumTrackOf(
    Map<String, Object?> raw,
    String albumName,
    String albumId,
    String albumCover,
  ) {
    final songId = '${raw['id'] ?? ''}';
    final title = LxPlatformSource.decodeName('${raw['name'] ?? ''}').trim();
    if (songId.isEmpty || title.isEmpty) return null;
    final formats = '${raw['formats'] ?? ''}'.split('|');
    final found = <String>{
      if (formats.contains('MP3128')) '128k',
      if (formats.contains('MP3H')) '320k',
      if (formats.contains('ALFLAC')) 'flac',
      if (formats.contains('HIRFLAC')) 'flac24bit',
    };
    final qualities = ['128k', '320k', 'flac', 'flac24bit'].where(found.contains).toList();
    final pic = '${raw['pic'] ?? ''}'.trim();
    final picture = pic.isEmpty ? albumCover.trim() : pic;
    final artistId = '${raw['artistid'] ?? raw['allartistid'] ?? ''}'.trim();
    return audio.MusicTrack(
      id: songId,
      sourceId: 'kw',
      title: title,
      artist: LxPlatformSource.decodeName('${raw['artist'] ?? ''}').trim(),
      album: albumName,
      albumId: albumId.isEmpty ? null : albumId,
      coverUri: picture.isEmpty ? null : Uri.tryParse(picture),
      qualities: [for (final quality in qualities) LxPlatformSource.qualityOf(quality)],
      metadata: {'types': qualities, 'albumId': albumId, if (artistId.isNotEmpty) 'artistId': artistId},
    );
  }

  /// The 博单 links — the reference's `getListDetailMusicListByBD`: the
  /// bd-api music list plus the info page the `source` code picks.
  Future<(MusicPlaylistInfo, List<audio.MusicTrack>)> _bodianDetail(String link) async {
    final uid = RegExp(r'uid=(\d+)').firstMatch(link)?.group(1);
    final listId = RegExp(r'playlistId=(\d+)').firstMatch(link)?.group(1);
    final source = RegExp(r'source=(\d+)').firstMatch(link)?.group(1);
    if (listId == null) throw StateError('kuwo bodian link not understood: $link');
    final reqId = _reqId();
    var info = MusicPlaylistInfo(id: listId, name: '', cover: '', author: '', trackCount: 0);
    if (source == '4' || source == '5') {
      try {
        info = source == '4' ? await _bodianListInfo(listId, reqId) : await _bodianUserInfo(uid ?? listId, reqId);
      } on Object catch (error, stackTrace) {
        // The reference keeps the list even when the info page fails.
        noteMusicSourceSilence('kw playlist info page', error, stackTrace);
      }
    }
    final rows = <Map<String, Object?>>[];
    var page = 0;
    var total = 1;
    while (rows.length < total) {
      page += 1;
      final json = await getJson(
        Uri.https('bd-api.kuwo.cn', '/api/service/playlist/$listId/musicList', {
          'reqId': reqId,
          'source': ?source,
          'pn': '$page',
          'rn': '1000',
        }),
        headers: _bodianHeaders,
      );
      if (json['code'] != 200) throw StateError('kuwo bodian list failed: $listId');
      final data = json['data'];
      if (data is! Map) break;
      total = _intOf(data['total']) ?? 0;
      final raw = data['list'];
      if (raw is! List || raw.isEmpty) break;
      rows.addAll([
        for (final entry in raw)
          if (entry is Map) entry.cast<String, Object?>(),
      ]);
    }
    final tracks = <audio.MusicTrack>[for (final entry in rows) ?_bodianTrackOf(entry)];
    return (
      MusicPlaylistInfo(id: info.id, name: info.name, cover: info.cover, author: info.author, trackCount: total),
      tracks,
    );
  }

  Future<MusicPlaylistInfo> _bodianListInfo(String listId, String reqId) async {
    final json = await getJson(
      Uri.https('bd-api.kuwo.cn', '/api/service/playlist/info/$listId', {'reqId': reqId, 'source': '4'}),
      headers: _bodianHeaders,
    );
    final data = json['data'];
    if (json['code'] != 200 || data is! Map) throw StateError('kuwo bodian info failed: $listId');
    return MusicPlaylistInfo(
      id: listId,
      name: '${data['name'] ?? ''}',
      cover: '${data['pic'] ?? ''}',
      author: '${data['creatorName'] ?? ''}',
      trackCount: 0,
    );
  }

  Future<MusicPlaylistInfo> _bodianUserInfo(String uid, String reqId) async {
    final json = await getJson(
      Uri.https('bd-api.kuwo.cn', '/api/ucenter/users/pub/$uid', {'reqId': reqId}),
      headers: _bodianHeaders,
    );
    final data = json['data'];
    final user = data is Map ? data['userInfo'] : null;
    if (json['code'] != 200 || user is! Map) throw StateError('kuwo bodian user failed: $uid');
    final nickname = '${user['nickname'] ?? ''}';
    return MusicPlaylistInfo(
      id: uid,
      name: '$nickname喜欢的音乐',
      cover: '${user['headImg'] ?? ''}',
      author: nickname,
      trackCount: 0,
    );
  }

  /// The bodian track rows — the reference's `filterBDListDetail`, the
  /// audios' bitrate list standing in for the usual N_MINFO.
  static audio.MusicTrack? _bodianTrackOf(Map<String, Object?> raw) {
    final songId = '${raw['id'] ?? ''}';
    final title = '${raw['name'] ?? ''}'.trim();
    if (songId.isEmpty || title.isEmpty) return null;
    final found = <String>{};
    final audios = raw['audios'];
    if (audios is List) {
      for (final info in audios) {
        if (info is! Map) continue;
        switch ('${info['bitrate'] ?? ''}') {
          case '4000':
            found.add('flac24bit');
          case '2000':
            found.add('flac');
          case '320':
            found.add('320k');
          case '128':
            found.add('128k');
        }
      }
    }
    final qualities = ['128k', '320k', 'flac', 'flac24bit'].where(found.contains).toList();
    final artists = raw['artists'];
    final names = [
      if (artists is List)
        for (final one in artists)
          if (one is Map && one['name'] is String) one['name'] as String,
    ];
    final albumId = '${raw['albumId'] ?? ''}';
    final pic = '${raw['albumPic'] ?? ''}';
    final seconds = int.tryParse('${raw['duration'] ?? ''}');
    return audio.MusicTrack(
      id: songId,
      sourceId: 'kw',
      title: title,
      artist: names.join('、'),
      album: '${raw['album'] ?? ''}',
      albumId: albumId.isEmpty ? null : albumId,
      duration: seconds == null ? null : Duration(seconds: seconds),
      coverUri: pic.isEmpty ? null : Uri.tryParse(pic),
      qualities: [for (final quality in qualities) LxPlatformSource.qualityOf(quality)],
      metadata: {'types': qualities, 'albumId': albumId},
    );
  }

  /// The reference's `getReqId` — eight hex quartets.
  String _reqId() {
    final random = Random();
    return [for (var i = 0; i < 8; i++) random.nextInt(0x10000).toRadixString(16).padLeft(4, '0')].join();
  }

  /// The viewer-shown top searches — the reference's 热门搜索.
  @override
  Future<List<String>> hotSearches() async {
    final uri = Uri.https('hotword.kuwo.cn', '/hotword.s', {
      'prod': 'kwplayer_ar_9.3.0.1',
      'corp': 'kuwo',
      'newver': '2',
      'vipver': '9.3.0.1',
      'source': 'kwplayer_ar_9.3.0.1_40.apk',
      'p2p': '1',
      'notrace': '0',
      'uid': '0',
      'plat': 'kwplayer_ar',
      'rformat': 'json',
      'encoding': 'utf8',
      'tabid': '1',
    });
    final json = jsonDecode(await getText(uri, userAgent: _hotUserAgent)) as Map<String, Object?>;
    final raw = json['tagvalue'];
    if (raw is! List) return const [];
    return [
      for (final entry in raw)
        if (entry is Map && entry['key'] is String && (entry['key'] as String).trim().isNotEmpty)
          (entry['key'] as String).trim(),
    ];
  }

  /// The completions for a partially typed query — the reference's
  /// `tipSearch.js`, which swapped the 403-prone www endpoint for tips.kuwo.cn.
  @override
  Future<List<String>> suggestions(String query) async {
    final uri = Uri.https('tips.kuwo.cn', '/t.s', {
      'corp': 'kuwo',
      'newver': '3',
      'p2p': '1',
      'notrace': '0',
      'c': 'mbox',
      'w': query,
      'encoding': 'utf8',
      'rformat': 'json',
    });
    final json = jsonDecode(await getText(uri, headers: {'Referer': 'http://www.kuwo.cn/'})) as Map<String, Object?>;
    final raw = json['WORDITEMS'];
    if (raw is! List) return const [];
    return [
      for (final entry in raw)
        if (entry is Map && entry['RELWORD'] is String && (entry['RELWORD'] as String).trim().isNotEmpty)
          (entry['RELWORD'] as String).trim(),
    ];
  }

  /// One page of a song's comments, hot or newest — the reference's kw
  /// `comment.js` on ncomment.kuwo.cn.
  @override
  Future<MusicCommentsPage> comments(
    audio.MusicTrack track, {
    required bool hot,
    required int page,
    int pageSize = 20,
  }) async {
    final uri = Uri.http('ncomment.kuwo.cn', '/com.s', {
      'f': 'web',
      'type': hot ? 'get_rec_comment' : 'get_comment',
      'aapiver': '1',
      'prod': 'kwplayer_ar_10.5.2.0',
      'digest': '15',
      'sid': track.id,
      'start': '${pageSize * (page - 1)}',
      'msgflag': '1',
      'count': '$pageSize',
      'newver': '3',
      'uid': '0',
    });
    final json = await getJson(uri, userAgent: _hotUserAgent);
    final raw = json[hot ? 'hot_comments' : 'comments'];
    final total = int.tryParse('${json[hot ? 'hot_comments_counts' : 'comments_counts'] ?? ''}') ?? 0;
    final rows = commentsOf(raw is List ? raw : const [], MusicComment.fromJson);
    final maxPage = total <= 0 ? 1 : (total / pageSize).ceil();
    return (comments: rows, hasMore: page < maxPage);
  }

  @override
  Future<List<audio.MusicCatalog>> catalogs() async => [
    for (final (id, name) in kMusicRankCatalogs) audio.MusicCatalog(id: 'kw:$id', name: name),
  ];

  @override
  Future<audio.MusicSourcePage<audio.MusicTrack>> catalogItems(audio.MusicCatalog catalog, {int page = 1}) async {
    if (page > 1) return const audio.MusicSourcePage.empty();
    final id = catalog.id.split(':').last;
    final uri = Uri.https('kbangserver.kuwo.cn', '/ksong.s', {
      'from': 'pc',
      'fmt': 'json',
      'pn': '0',
      'rn': '100',
      'type': 'bang',
      'data': 'content',
      'id': id,
      'show_copyright_off': '0',
      'pcmp4': '1',
      'isbang': '1',
    });
    final json = jsonDecode(await getText(uri)) as Map<String, Object?>;
    final raw = json['musiclist'];
    return audio.MusicSourcePage(
      items: raw is List
          ? [
              for (final entry in raw)
                if (entry is Map) ?trackOf(entry.cast<String, Object?>(), scriptQualities()),
            ]
          : const <audio.MusicTrack>[],
    );
  }

  @override
  Future<List<audio.MusicQuality>> qualities(audio.MusicTrack track) async {
    await runtime.ensureLoaded();
    final declared = runtime.qualitysFor(id);
    final source = declared.isEmpty ? const ['128k'] : declared;
    return [for (final qualityId in source) LxPlatformSource.qualityOf(qualityId)];
  }

  /// Re-reads the song's metadata — the reference's `getMusicInfo`
  /// (`kw/index.js`): `api/www/music/musicInfo?mid=` fills name, singer,
  /// album and cover over the track it already has.
  @override
  Future<audio.MusicTrack> trackDetail(audio.MusicTrack track) async {
    final json = await getJson(
      Uri.https('www.kuwo.cn', '/api/www/music/musicInfo', {'mid': track.id}),
      headers: {'Referer': 'https://www.kuwo.cn/'},
    );
    if (json['code'] != 200) throw StateError('kuwo musicInfo failed: ${json['code']}');
    final data = json['data'];
    if (data is! Map) return track;

    final artist = data['artist'];
    final names = artist is List
        ? [
            for (final one in artist)
              if (one is Map && one['name'] is String) one['name'] as String,
          ]
        : const <String>[];
    final title = data['name'];
    final album = data['album'];
    final albumId = _intOf(data['albumid']);
    final cover = data['pic'];
    final seconds = _intOf(data['duration']);

    return track.copyWith(
      title: title is String && title.isNotEmpty ? title : null,
      artist: names.isNotEmpty ? names.join('、') : null,
      album: album is String && album.isNotEmpty ? album : null,
      coverUri: cover is String && cover.isNotEmpty ? Uri.tryParse(cover) : null,
      duration: seconds != null && seconds > 0 ? Duration(seconds: seconds) : null,
      metadata: albumId == null ? track.metadata : {...track.metadata, 'albumId': '$albumId'},
    );
  }

  @override
  Future<String?> fallbackUrl(audio.MusicTrack track, String qualityId) async {
    try {
      final uri = Uri.https('antiserver.kuwo.cn', '/anti.s', {
        'type': 'convert_url',
        'format': 'mp3',
        'response': 'url',
        'rid': 'MUSIC_${track.id}',
      });
      final body = (await getText(uri)).trim();
      return body.startsWith('http') ? body : null;
    } on Object catch (error, stackTrace) {
      noteMusicSourceSilence('kw fallback url', error, stackTrace);
      return null;
    }
  }

  @override
  Future<audio.MusicLyricPayload?> resolveLyric(audio.MusicTrack track) async {
    try {
      final uri = Uri.https('m.kuwo.cn', '/newh5/singles/songinfoandlrc', {'musicId': track.id});
      final json = jsonDecode(await getText(uri)) as Map<String, Object?>;
      final data = json['data'];
      final raw = data is Map ? data['lrclist'] : null;
      if (raw is! List || raw.isEmpty) return null;
      final base = StringBuffer();
      final translation = StringBuffer();
      final times = <String>{};
      for (final entry in raw) {
        if (entry is! Map) continue;
        final text = LxPlatformSource.decodeName('${entry['lineLyric'] ?? ''}').trim();
        if (text.isEmpty) continue;
        final time = double.tryParse('${entry['time'] ?? ''}');
        if (time == null) continue;
        final stamp = _stamp(time);
        if (times.add(stamp)) {
          base.writeln('[$stamp]$text');
        } else {
          translation.writeln('[$stamp]$text');
        }
      }
      if (base.isEmpty) return null;
      return audio.MusicLyricPayload(
        lyric: base.toString(),
        translation: translation.isEmpty ? null : translation.toString(),
      );
    } on Object catch (error, stackTrace) {
      noteMusicSourceSilence('kw resolveLyric', error, stackTrace);
      return null;
    }
  }

  static audio.MusicTrack? trackOf(Map<String, Object?> raw, List<String> scriptQualities) {
    final rid = '${raw['MUSICRID'] ?? raw['id'] ?? ''}';
    final songId = rid.replaceFirst('MUSIC_', '');
    final title = LxPlatformSource.decodeName('${raw['SONGNAME'] ?? raw['name'] ?? ''}').trim();
    if (songId.isEmpty || title.isEmpty) return null;
    final artist = LxPlatformSource.decodeName('${raw['ARTIST'] ?? raw['artist'] ?? ''}').trim();
    final album = LxPlatformSource.decodeName('${raw['ALBUM'] ?? raw['album'] ?? ''}').trim();
    final albumId = '${raw['ALBUMID'] ?? raw['albumid'] ?? ''}';
    final artistId = '${raw['ARTISTID'] ?? raw['artistid'] ?? ''}'.trim();
    final seconds = int.tryParse('${raw['DURATION'] ?? raw['song_duration'] ?? raw['duration'] ?? ''}');
    final qualities = _qualitysOf(raw, scriptQualities);
    // The search row names its cover as a CDN-relative path (`web_albumpic_short`),
    // the digest rows hand over a full URL; either way the list would otherwise
    // wear initials.
    final pic = '${raw['albumPic'] ?? raw['pic'] ?? ''}'.trim();
    final short = '${raw['web_albumpic_short'] ?? ''}'.trim();
    final cover = pic.isNotEmpty ? pic : (short.isEmpty ? '' : 'https://img2.kuwo.cn/star/albumcover/$short');
    return audio.MusicTrack(
      id: songId,
      sourceId: 'kw',
      title: title,
      artist: artist,
      album: album,
      albumId: albumId.isEmpty ? null : albumId,
      duration: seconds == null ? null : Duration(seconds: seconds),
      coverUri: cover.isEmpty ? null : Uri.tryParse(cover),
      qualities: [for (final quality in qualities) LxPlatformSource.qualityOf(quality)],
      metadata: {'types': qualities, 'albumId': albumId, if (artistId.isNotEmpty) 'artistId': artistId},
    );
  }

  /// The tiers Kuwo's own search response advertises, falling back to what the
  /// imported scripts declare.
  static List<String> _qualitysOf(Map<String, Object?> raw, List<String> scriptQualities) {
    final found = <String>{};
    final info = '${raw['N_MINFO'] ?? raw['MINFO'] ?? ''}';
    final pattern = RegExp(r'bitrate:(\d+),format:(\w+)');
    for (final match in pattern.allMatches(info)) {
      switch (match.group(1)) {
        case '4000' || '20900' || '24000':
          found.add('flac24bit');
        case '2000' || '20501' || '20201' || '22000':
          found.add('flac');
        case '320':
          found.add('320k');
        case '128':
          found.add('128k');
      }
    }
    if (found.isEmpty) found.addAll(scriptQualities.isEmpty ? const ['128k'] : scriptQualities);
    return ['128k', '320k', 'flac', 'flac24bit'].where(found.contains).toList();
  }

  static String _stamp(double seconds) {
    final totalMs = (seconds * 1000).round().clamp(0, 359999999);
    final minutes = totalMs ~/ 60000;
    final rest = (totalMs ~/ 1000) % 60;
    final millis = totalMs % 1000;
    return '${minutes.toString().padLeft(2, '0')}:${rest.toString().padLeft(2, '0')}.'
        '${millis.toString().padLeft(3, '0')}';
  }
}
