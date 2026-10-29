import 'dart:convert' show jsonDecode;

import 'package:media_core_audio/media_core_audio.dart' as audio;

import 'package:pure_live/modules/music/controller/sources/lx_platform_source.dart';

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

/// The Kuwo platform: search, boards and lyrics ride Kuwo's own channel;
/// play URLs are asked from the lx scripts first, with Kuwo's anti-server as
/// the fallback.
final class KwMusicSource extends LxPlatformSource {
  /// A Kuwo source over the lx runtime.
  KwMusicSource(super.runtime);

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

  /// The viewer-shown top searches — the reference's 热门搜索.
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
