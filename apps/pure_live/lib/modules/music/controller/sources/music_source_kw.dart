import 'dart:convert' show jsonDecode;
import 'dart:math' show Random;

import 'package:media_core_audio/media_core_audio.dart' as audio;

import 'package:pure_live/modules/music/controller/music_comments.dart' show MusicComment;
import 'package:pure_live/modules/music/controller/sources/lx_platform_source.dart';
import 'package:pure_live/modules/music/controller/sources/music_comment_source.dart';
import 'package:pure_live/modules/music/controller/sources/music_hot_words.dart';
import 'package:pure_live/modules/music/controller/sources/online_playlist_models.dart'
    show MusicPlaylistInfo, MusicPlaylistPage, MusicPlaylistTag, MusicPlaylistTagGroup, MusicPlazaSort,
        OnlinePlaylists, PlaylistTagTree, SonglistSearch;

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
    implements MusicHotWords, MusicCommentsSource {
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
    final json = jsonDecode(await getText(uri)) as Map<String, Object?>;
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
            ),
      ],
      total: total,
    );
  }

  /// The plaza pages 36 lists a page — the reference's `limit_list`.
  static const int _plazaLimit = 36;

  /// The hot tags' request halves, keyed by shown name — the reference's
  /// hot tags carry `id-digest` pairs while the browser passes bare names.
  final Map<String, (String, String)> _hotTagIds = <String, (String, String)>{};

  /// The online playlists (在线歌单): Kuwo's pc classify plaza — the hot
  /// tags, the tag tree, the pages and the digest-dispatched detail
  /// lx-music's kw `songList` rides.
  @override
  Future<List<String>> hotTags() async {
    final json = jsonDecode(
      await getText(Uri.http('wapi.kuwo.cn', '/api/pc/classify/playlist/getRcmTagList', {
        'loginUid': '0',
        'loginSid': '0',
        'appUid': '76039576',
      })),
    ) as Map<String, Object?>;
    final data = json['data'];
    final raw = data is List && data.isNotEmpty && data.first is Map ? (data.first as Map)['data'] : null;
    _hotTagIds.clear();
    if (raw is! List) return const <String>[];
    final names = <String>[];
    for (final entry in raw) {
      if (entry is! Map) continue;
      final name = '${entry['name'] ?? ''}'.trim();
      if (name.isEmpty) continue;
      _hotTagIds[name] = ('${entry['id'] ?? ''}', '${entry['digest'] ?? ''}');
      names.add(name);
    }
    return names;
  }

  /// The plaza's category tree — the reference's `getTagList`, each tag's
  /// request id the `id-digest` pair its listing call splits apart.
  @override
  Future<List<MusicPlaylistTagGroup>> tagGroups() async {
    final json = jsonDecode(
      await getText(Uri.http('wapi.kuwo.cn', '/api/pc/classify/playlist/getTagList', {
        'cmd': 'rcm_keyword_playlist',
        'user': '0',
        'prod': 'kwplayer_pc_9.0.5.0',
        'vipver': '9.0.5.0',
        'source': 'kwplayer_pc_9.0.5.0',
        'loginUid': '0',
        'loginSid': '0',
        'appUid': '76039576',
      })),
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
    final resolved = await _resolveTag(tag);
    if (resolved == null) return const MusicPlaylistPage(items: [], total: 0);
    final (id, digest) = resolved;
    if (digest == '10000') {
      final json = jsonDecode(
        await getText(Uri.http('wapi.kuwo.cn', '/api/pc/classify/playlist/getTagPlayList', {
          'loginUid': '0',
          'loginSid': '0',
          'appUid': '76039576',
          'pn': '$page',
          'id': id,
          'rn': '$_plazaLimit',
        })),
      ) as Map<String, Object?>;
      final data = json['data'];
      if (json['code'] != 200 || data is! Map) return const MusicPlaylistPage(items: [], total: 0);
      return MusicPlaylistPage(items: _plazaPlaylistsOf(data['data']), total: (data['total'] as num?)?.toInt() ?? 0);
    }
    // The other digests are the 专题 pages: the qz gateway answers grouped
    // rows the reference flattens without a total.
    final body = jsonDecode(
      await getText(Uri.http('mobileinterfaces.kuwo.cn', '/er.s', {'type': 'get_pc_qz_data', 'f': 'web', 'id': id, 'prod': 'pc'})),
    ) as Object?;
    return MusicPlaylistPage(
      items: _qzPlaylistsOf(body is List ? body : const <Object?>[]),
      total: 1000,
    );
  }

  /// The tag's request halves — the reference splits the `id-digest` pair;
  /// a bare hot-tag name re-joins through the getRcmTagList map.
  Future<(String, String)?> _resolveTag(String tag) async {
    final trimmed = tag.trim();
    final dash = trimmed.indexOf('-');
    if (dash > 0) return (trimmed.substring(0, dash), trimmed.substring(dash + 1));
    if (!_hotTagIds.containsKey(trimmed) && _hotTagIds.isEmpty) await hotTags();
    return _hotTagIds[trimmed];
  }

  /// The recommend flow — the reference's getRcmPlayList, the only page the
  /// sort codes answer.
  Future<MusicPlaylistPage> _recommendPage({required String order, required int page}) async {
    final json = jsonDecode(
      await getText(Uri.http('wapi.kuwo.cn', '/api/pc/classify/playlist/getRcmPlayList', {
        'loginUid': '0',
        'loginSid': '0',
        'appUid': '76039576',
        'pn': '$page',
        'rn': '$_plazaLimit',
        'order': order,
      })),
    ) as Map<String, Object?>;
    final data = json['data'];
    if (json['code'] != 200 || data is! Map) return const MusicPlaylistPage(items: [], total: 0);
    return MusicPlaylistPage(items: _plazaPlaylistsOf(data['data']), total: (data['total'] as num?)?.toInt() ?? 0);
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
            trackCount: (entry['total'] as num?)?.toInt() ?? 0,
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
            if (entry is Map && allowed.contains('${entry['type'] ?? ''}') && '${entry['name'] ?? ''}'.trim().isNotEmpty)
              MusicPlaylistInfo(
                id: 'digest-${entry['digest'] ?? ''}__${entry['id'] ?? ''}',
                name: LxPlatformSource.decodeName('${entry['name']}').trim(),
                cover: '${entry['img'] ?? ''}',
                author: LxPlatformSource.decodeName('${entry['uname'] ?? ''}').trim(),
                trackCount: (entry['total'] as num?)?.toInt() ?? 0,
              ),
    ];
  }

  /// The playlist's link shapes — the reference's `listDetailLink`, the
  /// www/h5 playlist urls a paste carries.
  static final RegExp _listDetailLink = RegExp(r'^.+\/playlist(?:_detail)?\/(\d+)(?:\?.*|&.*$|#.*$|$)');

  /// The bd-api pages answer the desktop browser agent with the h5 plat mark.
  static const Map<String, String> _bodianHeaders = {
    'User-Agent':
        'Mozilla/5.0 (Windows NT 10.0; WOW64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/86.0.4240.198 Safari/537.36',
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
        '13' => _albumDetail(inner),
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
        await getText(Uri.http('nplserver.kuwo.cn', '/pl.svc', {
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
        })),
      ) as Map<String, Object?>;
      if (json['result'] != 'ok') throw StateError('kuwo playlist detail failed: $pid');
      total = int.tryParse('${json['total'] ?? ''}') ?? 0;
      final raw = json['musiclist'];
      if (raw is! List || raw.isEmpty) break;
      rows.addAll([for (final entry in raw) if (entry is Map) entry.cast<String, Object?>()]);
      info ??= MusicPlaylistInfo(
        id: pid,
        name: LxPlatformSource.decodeName('${json['title'] ?? ''}').trim(),
        cover: '${json['pic'] ?? ''}',
        author: LxPlatformSource.decodeName('${json['uname'] ?? ''}').trim(),
        trackCount: total,
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
      await getText(Uri.http('qukudata.kuwo.cn', '/q.k', {
        'op': 'query',
        'cont': 'ninfo',
        'node': id,
        'pn': '0',
        'rn': '1',
        'fmt': 'json',
        'src': 'mbox',
        'level': '2',
      })),
    ) as Map<String, Object?>;
    final child = json['child'];
    final sourceid = child is List && child.isNotEmpty && child.first is Map ? '${(child.first as Map)['sourceid'] ?? ''}' : '';
    if (sourceid.isEmpty) throw StateError('kuwo playlist id unresolved: $id');
    return await _listDetail(sourceid);
  }

  /// The album digest — the reference routes it to kw `album.js`: the r.s
  /// albuminfo page answers the tracks and the summary together.
  Future<(MusicPlaylistInfo, List<audio.MusicTrack>)> _albumDetail(String albumId) async {
    final json = jsonDecode(
      await getText(Uri.http('search.kuwo.cn', '/r.s', {
        'pn': '0',
        'rn': '1000',
        'stype': 'albuminfo',
        'albumid': albumId,
        'show_copyright_off': '0',
        'encoding': 'utf',
        'vipver': 'MUSIC_9.1.0',
      })),
    ) as Map<String, Object?>;
    final raw = json['musiclist'];
    if (raw is! List) throw StateError('kuwo album detail failed: $albumId');
    final albumName = LxPlatformSource.decodeName('${json['name'] ?? ''}').trim();
    final info = MusicPlaylistInfo(
      id: albumId,
      name: albumName,
      cover: '${json['img'] ?? json['hts_img'] ?? ''}',
      author: LxPlatformSource.decodeName('${json['artist'] ?? ''}').trim(),
      trackCount: int.tryParse('${json['songnum'] ?? ''}') ?? raw.length,
    );
    final tracks = <audio.MusicTrack>[
      for (final entry in raw)
        if (entry is Map) ?_albumTrackOf(entry.cast<String, Object?>(), albumName, albumId),
    ];
    return (info, tracks);
  }

  /// The album track rows — the reference's album `filterListDetail`, the
  /// `formats` pipe list standing in for the usual N_MINFO.
  static audio.MusicTrack? _albumTrackOf(Map<String, Object?> raw, String albumName, String albumId) {
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
    final pic = '${raw['pic'] ?? ''}';
    return audio.MusicTrack(
      id: songId,
      sourceId: 'kw',
      title: title,
      artist: LxPlatformSource.decodeName('${raw['artist'] ?? ''}').trim(),
      album: albumName,
      albumId: albumId.isEmpty ? null : albumId,
      coverUri: pic.isEmpty ? null : Uri.tryParse(pic),
      qualities: [for (final quality in qualities) LxPlatformSource.qualityOf(quality)],
      metadata: {'types': qualities, 'albumId': albumId},
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
      } on Object {
        // The reference keeps the list even when the info page fails.
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
      total = (data['total'] as num?)?.toInt() ?? 0;
      final raw = data['list'];
      if (raw is! List || raw.isEmpty) break;
      rows.addAll([for (final entry in raw) if (entry is Map) entry.cast<String, Object?>()]);
    }
    final tracks = <audio.MusicTrack>[
      for (final entry in rows) ?_bodianTrackOf(entry),
    ];
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
    final json = jsonDecode(
      await getText(uri, headers: {'Referer': 'http://www.kuwo.cn/'}),
    ) as Map<String, Object?>;
    final raw = json['WORDITEMS'];
    if (raw is! List) return const [];
    return [
      for (final entry in raw)
        if (entry is Map
            && entry['RELWORD'] is String
            && (entry['RELWORD'] as String).trim().isNotEmpty)
          (entry['RELWORD'] as String).trim(),
    ];
  }

  /// One page of a song's comments, hot or newest — the reference's kw
  /// `comment.js` on ncomment.kuwo.cn.
  @override
  Future<MusicCommentsPage> comments(audio.MusicTrack track, {required bool hot, required int page, int pageSize = 20}) async {
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
        ? [for (final one in artist) if (one is Map && one['name'] is String) one['name'] as String]
        : const <String>[];
    final title = data['name'];
    final album = data['album'];
    final albumId = (data['albumid'] as num?)?.toInt();
    final cover = data['pic'];
    final seconds = (data['duration'] as num?)?.toInt();

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
    } on Object {
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
    } on Object {
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
    final seconds = int.tryParse('${raw['DURATION'] ?? raw['song_duration'] ?? raw['duration'] ?? ''}');
    final qualities = _qualitysOf(raw, scriptQualities);
    return audio.MusicTrack(
      id: songId,
      sourceId: 'kw',
      title: title,
      artist: artist,
      album: album,
      albumId: albumId.isEmpty ? null : albumId,
      duration: seconds == null ? null : Duration(seconds: seconds),
      qualities: [for (final quality in qualities) LxPlatformSource.qualityOf(quality)],
      metadata: {'types': qualities, 'albumId': albumId},
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
