import 'package:live_vod/live_vod.dart' show BilibiliVodClient, LyricLookup, LyricQuery, VodAudioStream, VodVideo;
import 'package:media_core/media_core.dart' show SourceFormat;
import 'package:media_core_audio/media_core_audio.dart' as audio;

final class BilibiliMusicSource extends audio.MusicSource {
  BilibiliMusicSource(this.client) : lyrics = LyricLookup(client.http);

  final BilibiliVodClient client;
  final LyricLookup lyrics;

  static const _quality64 = audio.MusicQuality(id: '64k', label: '64K', bitrateKbps: 64, formatHint: 'm4a');
  static const _quality132 = audio.MusicQuality(
    id: '132k',
    label: '132K',
    bitrateKbps: 132,
    formatHint: 'm4a',
    sort: 1,
  );
  static const _quality192 = audio.MusicQuality(
    id: '192k',
    label: '192K',
    bitrateKbps: 192,
    formatHint: 'm4a',
    sort: 2,
  );
  static const _qualityDolby = audio.MusicQuality(id: 'dolby', label: '杜比全景声', formatHint: 'm4a', sort: 3);

  @override
  String get id => 'bilibili';

  @override
  String get name => '哔哩哔哩音乐';

  @override
  Future<audio.MusicSourcePage<audio.MusicTrack>> search(String keyword, {int page = 1, int pageSize = 30}) async {
    final answer = await client.search(keyword, page: page, pageSize: pageSize);
    final seen = <String>{};
    return audio.MusicSourcePage(
      items: [
        for (final video in answer.videos)
          if (seen.add(video.bvid ?? video.id)) _trackOf(video),
      ],
      page: page,
      total: answer.total,
      hasMore: answer.hasMore,
    );
  }

  @override
  Future<audio.MusicTrack> trackDetail(audio.MusicTrack track) async {
    final detail = await client.detail(track.metadataValue<String>('bvid') ?? track.id);
    return _trackOf(
      VodVideo(
        id: detail.bvid,
        bvid: detail.bvid,
        aid: detail.aid,
        title: detail.title,
        coverUrl: detail.coverUrl,
        uploader: detail.uploader,
        uploaderAvatar: detail.uploaderAvatar,
        duration: detail.parts.isEmpty ? detail.duration : detail.parts.first.duration,
        playCount: detail.playCount,
        danmakuCount: detail.danmakuCount,
      ),
    );
  }

  @override
  Future<List<audio.MusicQuality>> qualities(audio.MusicTrack track) async {
    final streams = await client.audioStreams(_videoOf(track));
    final seen = <String>{};
    final qualities = [
      for (final stream in streams)
        if (seen.add('${stream.id}:${stream.codecs}')) _qualityOf(stream),
    ]..sort((a, b) => a.sort.compareTo(b.sort));
    return qualities;
  }

  @override
  Future<audio.TrackSource> resolveTrackSource(audio.MusicTrack track, {audio.MusicQuality? quality}) async {
    final streams = await client.audioStreams(_videoOf(track));
    final stream = _selectStream(streams, quality);
    final served = _qualityOf(stream);
    return audio.TrackSource(
      uri: Uri.parse(stream.url),
      headers: client.playHeaders,
      quality: served,
      format: _formatOf(stream),
      duration: track.duration,
    );
  }

  @override
  Future<audio.MusicLyricPayload?> resolveLyric(audio.MusicTrack track) async {
    final originalTitle = track.metadataValue<String>('videoTitle') ?? track.title;
    final uploader = track.metadataValue<String>('uploader');
    var query = LyricQuery.fromVideoTitle(originalTitle, uploader: uploader);
    if (!query.isUsable) query = LyricQuery(title: track.title, artist: track.artist);
    final found = await lyrics.search(query, duration: track.duration);
    if (found == null || found.lyric.trim().isEmpty) return null;
    return audio.MusicLyricPayload(lyric: found.lyric);
  }

  @override
  Future<List<audio.MusicCatalog>> catalogs() async => const [
    audio.MusicCatalog(id: 'bilibili:ranking:3', name: '音乐区排行榜'),
  ];

  @override
  Future<audio.MusicSourcePage<audio.MusicTrack>> catalogItems(audio.MusicCatalog catalog, {int page = 1}) async {
    if (page > 1) return const audio.MusicSourcePage.empty();
    final videos = await client.ranking(rid: 3);
    final seen = <String>{};
    return audio.MusicSourcePage(
      items: [
        for (final video in videos)
          if (seen.add(video.bvid ?? video.id)) _trackOf(video),
      ],
      total: videos.length,
    );
  }

  audio.MusicTrack _trackOf(VodVideo video) {
    final originalTitle = video.title.trim();
    final query = LyricQuery.fromVideoTitle(originalTitle, uploader: video.uploader);
    final bvid = video.bvid ?? video.id;
    return audio.MusicTrack(
      id: bvid,
      sourceId: id,
      title: query.title.isEmpty ? originalTitle : query.title,
      artist: query.artist,
      duration: video.duration,
      coverUri: _uriOf(video.coverUrl),
      metadata: {
        'bvid': bvid,
        if (video.aid != null) 'aid': video.aid,
        'videoTitle': originalTitle,
        if (video.uploader != null) 'uploader': video.uploader,
        if (video.coverUrl != null) 'coverUrl': video.coverUrl,
        if (video.uploaderAvatar != null) 'uploaderAvatar': video.uploaderAvatar,
        if (video.playCount != null) 'playCount': video.playCount,
        if (video.danmakuCount != null) 'danmakuCount': video.danmakuCount,
      },
    );
  }

  VodVideo _videoOf(audio.MusicTrack track) => VodVideo(
    id: track.metadataValue<String>('bvid') ?? track.id,
    bvid: track.metadataValue<String>('bvid') ?? track.id,
    title: track.metadataValue<String>('videoTitle') ?? track.title,
    uploader: track.metadataValue<String>('uploader'),
  );

  VodAudioStream _selectStream(List<VodAudioStream> streams, audio.MusicQuality? asked) {
    if (asked == null || asked.isAuto) return streams.first;
    final exact = streams.where((stream) => '${stream.id}' == asked.id || _qualityOf(stream).id == asked.id);
    if (exact.isNotEmpty) return exact.first;
    final lossy = streams.where((stream) => stream.id != 30250 && stream.id != 30251).toList();
    if (asked.id == audio.MusicQuality.k128.id) {
      final standard = lossy.where((stream) => (stream.bandwidth ?? 0) <= 150000).toList();
      if (standard.isNotEmpty) return standard.first;
      return lossy.isEmpty ? streams.last : lossy.last;
    }
    if (asked.id == audio.MusicQuality.k320.id) return lossy.isEmpty ? streams.last : lossy.first;
    if (asked.id == audio.MusicQuality.flac.id || asked.id == audio.MusicQuality.flac24bit.id) {
      final lossless = streams.where((stream) => stream.id == 30251);
      if (lossless.isNotEmpty) return lossless.first;
    }
    return streams.first;
  }

  audio.MusicQuality _qualityOf(VodAudioStream stream) => switch (stream.id) {
    30216 => _quality64,
    30232 => _quality132,
    30280 => _quality192,
    30250 => _qualityDolby,
    30251 => audio.MusicQuality.flac24bit,
    _ => audio.MusicQuality(id: 'bili-${stream.id}', label: '${stream.id}', sort: 2),
  };

  SourceFormat _formatOf(VodAudioStream stream) {
    final codec = stream.codecs?.toLowerCase() ?? '';
    if (stream.id == 30251 || codec.contains('flac')) return SourceFormat.flac;
    return SourceFormat.mp4;
  }

  static Uri? _uriOf(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    return Uri.tryParse(value.trim());
  }
}
