import 'dart:convert' show jsonDecode, utf8;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:media_core/media_core.dart' show SourceFormat;
import 'package:media_core_audio/media_core_audio.dart' as audio;

import 'package:pure_live/modules/music/controller/lx_script_runtime.dart';

/// The platform key lx-music uses for Kuwo; a track's source id.
const String kLxMusicSourceId = 'kw';

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

const String _userAgent =
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0 Safari/537.36';

/// The music module's lx-music source.
///
/// Search, boards and lyrics ride lx-music's Kuwo channel; playback URLs are
/// asked from the imported lx source scripts first, with Kuwo's own URL
/// endpoint as the fallback. The scripts keep the whole lx contract
/// (`lx.on('request')`, `lx.send('inited')`, `lx.request`, `lx.utils`), so a
/// script written for lx-music desktop or mobile works unchanged.
final class LxMusicSource extends audio.MusicSource {
  /// A source over the lx runtime and an HTTP client.
  LxMusicSource(this._runtime) : _http = http.Client();

  final LxScriptRuntime _runtime;
  final http.Client _http;

  @override
  String get id => kLxMusicSourceId;

  @override
  String get name => 'lx-music';

  @override
  Future<audio.MusicSourcePage<audio.MusicTrack>> search(String keyword, {int page = 1, int pageSize = 30}) async {
    await _runtime.ensureLoaded();
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
    final json = jsonDecode(await _get(uri)) as Map<String, Object?>;
    final total = int.tryParse('${json['TOTAL'] ?? ''}') ?? 0;
    final raw = json['abslist'];
    final items = raw is List
        ? [
            for (final entry in raw)
              if (entry is Map) ?_trackOf(entry.cast<String, Object?>(), _runtime.qualitysFor(kLxMusicSourceId)),
          ]
        : const <audio.MusicTrack>[];
    return audio.MusicSourcePage(items: items, page: page, total: total, hasMore: total > page * pageSize);
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
    final json = jsonDecode(await _get(uri)) as Map<String, Object?>;
    final raw = json['musiclist'];
    return audio.MusicSourcePage(
      items: raw is List
          ? [
              for (final entry in raw)
                if (entry is Map) ?_trackOf(entry.cast<String, Object?>(), _runtime.qualitysFor(kLxMusicSourceId)),
            ]
          : const <audio.MusicTrack>[],
    );
  }

  @override
  Future<List<audio.MusicQuality>> qualities(audio.MusicTrack track) async {
    await _runtime.ensureLoaded();
    final declared = _runtime.qualitysFor(kLxMusicSourceId);
    final source = declared.isEmpty ? const ['128k'] : declared;
    return [for (final id in source) _qualityOf(id)];
  }

  @override
  Future<audio.TrackSource> resolveTrackSource(audio.MusicTrack track, {audio.MusicQuality? quality}) async {
    final qualityId = quality?.id ?? '128k';
    final scripted = await _runtime.resolveMusicUrl(track, qualityId);
    final url = scripted ?? await _fallbackUrl(track.id);
    if (url == null || url.isEmpty) {
      throw StateError('lx-music: no playable URL for ${track.title}');
    }
    final uri = Uri.parse(url);
    return audio.TrackSource(
      uri: uri,
      headers: {'User-Agent': _userAgent, 'Referer': 'https://www.kuwo.cn/'},
      format: SourceFormat.fromUri(uri),
      quality: scripted == null ? audio.MusicQuality.k128 : quality,
    );
  }

  @override
  Future<audio.MusicLyricPayload?> resolveLyric(audio.MusicTrack track) async {
    try {
      final uri = Uri.https('m.kuwo.cn', '/newh5/singles/songinfoandlrc', {'musicId': track.id});
      final json = jsonDecode(await _get(uri)) as Map<String, Object?>;
      final data = json['data'];
      final raw = data is Map ? data['lrclist'] : null;
      if (raw is! List || raw.isEmpty) return null;
      final base = StringBuffer();
      final translation = StringBuffer();
      final times = <String>{};
      for (final entry in raw) {
        if (entry is! Map) continue;
        final text = _decodeName('${entry['lineLyric'] ?? ''}').trim();
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

  Future<String?> _fallbackUrl(String songId) async {
    try {
      final uri = Uri.https('antiserver.kuwo.cn', '/anti.s', {
        'type': 'convert_url',
        'format': 'mp3',
        'response': 'url',
        'rid': 'MUSIC_$songId',
      });
      final body = (await _get(uri)).trim();
      return body.startsWith('http') ? body : null;
    } on Object {
      return null;
    }
  }

  Future<String> _get(Uri uri) async {
    final response = await _http.get(uri, headers: {'User-Agent': _userAgent}).timeout(const Duration(seconds: 20));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError('Kuwo HTTP ${response.statusCode}');
    }
    return utf8.decode(response.bodyBytes, allowMalformed: true);
  }

  static audio.MusicTrack? _trackOf(Map<String, Object?> raw, List<String> scriptQualities) {
    final rid = '${raw['MUSICRID'] ?? raw['id'] ?? ''}';
    final songId = rid.replaceFirst('MUSIC_', '');
    final title = _decodeName('${raw['SONGNAME'] ?? raw['name'] ?? ''}').trim();
    if (songId.isEmpty || title.isEmpty) return null;
    final artist = _decodeName('${raw['ARTIST'] ?? raw['artist'] ?? ''}').trim();
    final album = _decodeName('${raw['ALBUM'] ?? raw['album'] ?? ''}').trim();
    final albumId = '${raw['ALBUMID'] ?? raw['albumid'] ?? ''}';
    final seconds = int.tryParse('${raw['DURATION'] ?? raw['song_duration'] ?? raw['duration'] ?? ''}');
    final qualities = _qualitysOf(raw, scriptQualities);
    return audio.MusicTrack(
      id: songId,
      sourceId: kLxMusicSourceId,
      title: title,
      artist: artist,
      album: album,
      albumId: albumId.isEmpty ? null : albumId,
      duration: seconds == null ? null : Duration(seconds: seconds),
      qualities: [for (final quality in qualities) _qualityOf(quality)],
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

  static audio.MusicQuality _qualityOf(String id) => switch (id) {
    '320k' => audio.MusicQuality.k320,
    'flac' => audio.MusicQuality.flac,
    'flac24bit' => audio.MusicQuality.flac24bit,
    _ => audio.MusicQuality.k128,
  };

  static String _stamp(double seconds) {
    final totalMs = (seconds * 1000).round().clamp(0, 359999999);
    final minutes = totalMs ~/ 60000;
    final rest = (totalMs ~/ 1000) % 60;
    final millis = totalMs % 1000;
    return '${minutes.toString().padLeft(2, '0')}:${rest.toString().padLeft(2, '0')}.'
        '${millis.toString().padLeft(3, '0')}';
  }

  static String _decodeName(String value) => value
      .replaceAll('&nbsp;', ' ')
      .replaceAll('&amp;', '&')
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&quot;', '"')
      .replaceAll('&#39;', "'");
}

/// The module's source over the imported lx scripts.
final musicSourceProvider = Provider<LxMusicSource>((ref) => LxMusicSource(ref.watch(lxScriptRuntimeProvider)));
