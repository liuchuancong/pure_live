import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_vod/live_vod.dart';
import 'package:media_core/media_core.dart' show SourceFormat;
import 'package:media_core_audio/media_core_audio.dart' as audio;
import 'package:pure_live/modules/vod/controller/vod_controller.dart' show vodClientProvider;

/// The registered id of the module's Bilibili source.
const String kBilibiliMusicSourceId = 'bilibili';

/// The leaderboards the source advertises: Bilibili's classic ranking ids with
/// the platform's own region names — the same boards the video station's
/// ranking tab offers, asked through the music source so a song list and a
/// video list never disagree about what a board is.
const List<(int, String)> kMusicRankCatalogs = [
  (0, '全部'),
  (3, '音乐'),
  (1, '动画'),
  (4, '游戏'),
  (36, '知识'),
  (188, '科技'),
  (5, '娱乐'),
  (181, '影视'),
  (211, '美食'),
  (160, '生活'),
  (119, '鬼畜'),
  (129, '舞蹈'),
  (155, '时尚'),
  (223, '汽车'),
  (234, '运动'),
  (217, '动物圈'),
  (177, '纪录片'),
];

/// Turns a video hit into a song.
///
/// The title is parsed the way the lyric lookup wants — "artist - title" and
/// "title《artist》" apart, decorations dropped — because a music upload's
/// title is the only place the artist is written; the uploader is the
/// fallback artist. The raw title and cover travel in the metadata so the
/// player can resolve the same video again without the search around.
audio.MusicTrack musicTrackOfVideo(VodVideo video) {
  final query = LyricQuery.fromVideoTitle(video.title, uploader: video.uploader);
  final cover = video.coverUrl;
  return audio.MusicTrack(
    id: video.bvid ?? video.id,
    sourceId: kBilibiliMusicSourceId,
    title: query.title,
    artist: query.artist,
    duration: video.duration,
    coverUri: cover == null ? null : Uri.tryParse(cover),
    metadata: {
      'bvid': video.bvid ?? video.id,
      'rawTitle': video.title,
      'uploader': ?video.uploader,
      'cover': ?cover,
      if (video.duration != null) 'durationMs': video.duration!.inMilliseconds,
    },
  );
}

/// The video a song came from, rebuilt from its metadata; a queue entry that
/// outlived its source list still resolves.
VodVideo musicVideoOfTrack(audio.MusicTrack track) => VodVideo(
  id: track.metadataValue<String>('bvid') ?? track.id,
  bvid: track.metadataValue<String>('bvid') ?? track.id,
  title: track.metadataValue<String>('rawTitle') ?? track.title,
  coverUrl: track.metadataValue<String>('cover') ?? track.coverUri?.toString(),
  uploader: track.metadataValue<String>('uploader') ?? (track.artist.isEmpty ? null : track.artist),
  duration: track.duration,
);

/// The module's one source: Bilibili's audio streams, with LRCLIB answering
/// the lyrics.
///
/// It rides the video station's own client, so the sign-in, the proxy and the
/// User-Agent that make a video play are the same facts here — a viewer who
/// signed in for higher renditions gets them for songs too. The platform
/// serves one AAC ladder (64/132/192 kbps) plus FLAC on some titles, so a
/// requested tier resolves to the closest stream at or below it.
final class BilibiliMusicSource extends audio.MusicSource {
  /// A source over the station's client.
  BilibiliMusicSource(this._client) : _lyrics = LyricLookup(_client.http);

  final BilibiliVodClient _client;
  final LyricLookup _lyrics;

  /// Bilibili's DASH audio rendition ids, as the tier they represent.
  static const Map<int, audio.MusicQuality> _renditions = {
    30216: audio.MusicQuality(id: '64k', label: '64K', bitrateKbps: 64),
    30232: audio.MusicQuality.k128,
    30280: audio.MusicQuality.k192,
    30250: audio.MusicQuality(id: 'dolby', label: '杜比全景声', formatHint: 'ec-3', sort: 4),
    30251: audio.MusicQuality.flac,
  };

  /// The rendition id a requested tier means, best-fit: the platform's AAC
  /// tops out at 192 kbps, and FLAC exists only on some titles.
  static int _renditionFor(audio.MusicQuality quality) => switch (quality.id) {
    '64k' => 30216,
    '128k' => 30232,
    '192k' || '320k' || 'hires' || 'auto' => 30280,
    _ => 30251,
  };

  @override
  String get id => kBilibiliMusicSourceId;

  @override
  String get name => 'Bilibili';

  @override
  Future<audio.MusicSourcePage<audio.MusicTrack>> search(String keyword, {int page = 1, int pageSize = 30}) async {
    final answer = await _client.search(keyword, page: page, pageSize: pageSize);
    return audio.MusicSourcePage(
      items: [for (final video in answer.videos) musicTrackOfVideo(video)],
      page: page,
      hasMore: answer.hasMore,
    );
  }

  @override
  Future<List<audio.MusicCatalog>> catalogs() async => [
    for (final (rid, name) in kMusicRankCatalogs) audio.MusicCatalog(id: 'rank:$rid', name: name),
  ];

  @override
  Future<audio.MusicSourcePage<audio.MusicTrack>> catalogItems(audio.MusicCatalog catalog, {int page = 1}) async {
    // A board is one answer, not a paged feed: the ranking endpoint returns
    // the whole list in one call.
    if (page > 1) return const audio.MusicSourcePage.empty();
    final rid = int.tryParse(catalog.id.split(':').last) ?? 0;
    final videos = await _client.ranking(rid: rid);
    return audio.MusicSourcePage(items: [for (final video in videos) musicTrackOfVideo(video)]);
  }

  @override
  Future<List<audio.MusicQuality>> qualities(audio.MusicTrack track) async {
    final streams = await _client.audioStreams(musicVideoOfTrack(track));
    final tiers = <audio.MusicQuality>[for (final stream in streams) ?_renditions[stream.id]]
      ..sort((a, b) => a.sort.compareTo(b.sort));
    return tiers;
  }

  @override
  Future<audio.TrackSource> resolveTrackSource(audio.MusicTrack track, {audio.MusicQuality? quality}) async {
    final streams = await _client.audioStreams(musicVideoOfTrack(track));
    final automatic = quality == null || quality.id == 'auto';
    final wanted = automatic ? null : _renditionFor(quality);
    // Take the requested rendition when the title has it, else the closest
    // one below it, else the lowest there is.
    final byTier = [...streams]..sort((a, b) => b.id.compareTo(a.id));
    var chosen = automatic ? streams.first : byTier.last;
    if (wanted != null) {
      for (final stream in byTier) {
        if (stream.id <= wanted) {
          chosen = stream;
          break;
        }
      }
    }
    final uri = Uri.parse(chosen.url);
    return audio.TrackSource(
      uri: uri,
      headers: _client.playHeaders,
      format: SourceFormat.fromUri(uri),
      quality: _renditions[chosen.id] ?? quality,
    );
  }

  @override
  Future<audio.MusicLyricPayload?> resolveLyric(audio.MusicTrack track) async {
    final query = LyricQuery.fromVideoTitle(
      track.metadataValue<String>('rawTitle') ?? track.title,
      uploader: track.artist,
    );
    final lyric = await _lyrics.search(query, duration: track.duration);
    return lyric == null ? null : audio.MusicLyricPayload(lyric: lyric.lyric);
  }
}

/// The module's source, over the video station's signed-in client.
final musicSourceProvider = Provider<BilibiliMusicSource>((ref) => BilibiliMusicSource(ref.watch(vodClientProvider)));
