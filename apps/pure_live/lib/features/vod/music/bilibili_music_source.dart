import 'package:live_vod/live_vod.dart' show BilibiliVodClient, LyricQuery, VodVideo;
import 'package:media_core/media_core.dart' show SourceFormat;
import 'package:media_core_audio/media_core_audio.dart'
    show MusicLyricPayload, MusicQuality, MusicSource, MusicSourcePage, MusicTrack, TrackSource;
import 'package:pure_live/features/vod/music/lyric_provider.dart' show LyricProvider;

/// Bilibili as a music source for media_core_audio: a video's audio stream is
/// the song, the uploader is the artist, and the search is the video search.
///
/// The module owns the queue, play modes, lyrics and the background binding;
/// this class only answers "find" and "resolve", which is the contract a
/// source carries its platform's headers in.
final class BilibiliMusicSource extends MusicSource {
  /// A source over the video client.
  new(this.client, {this.lyrics});

  /// The video client (search, audio address).
  final BilibiliVodClient client;

  /// Where lyrics come from, when the build ships a service; null is the
  /// shipping answer and the music page draws no strip.
  final LyricProvider? lyrics;

  @override
  String get id => 'bilibili';

  @override
  String get name => '哔哩哔哩';

  @override
  Future<MusicSourcePage<MusicTrack>> search(String keyword, {int page = 1, int pageSize = 30}) async {
    final hits = await client.search(keyword, page: page, pageSize: pageSize);
    return MusicSourcePage(
      items: [
        for (final video in hits.videos)
          MusicTrack(
            id: video.id,
            title: video.title,
            sourceId: id,
            artist: video.uploader ?? '',
            duration: video.duration,
            coverUri: video.coverUrl == null ? null : Uri.tryParse(video.coverUrl!),
          ),
      ],
      hasMore: hits.hasMore,
    );
  }

  @override
  Future<MusicLyricPayload?> resolveLyric(MusicTrack track) async {
    final provider = lyrics;
    if (provider == null) {
      return null;
    }
    final query = LyricQuery.fromVideoTitle(track.title, uploader: track.artist.isEmpty ? null : track.artist);
    if (!query.isUsable) {
      return null;
    }
    final text = await provider.fetch(query);
    if (text == null || text.trim().isEmpty) {
      return null;
    }
    return MusicLyricPayload(lyric: text);
  }

  @override
  Future<TrackSource> resolveTrackSource(MusicTrack track, {MusicQuality? quality}) async {
    final info = await client.audio(VodVideo(id: track.id, bvid: track.id, title: track.title));
    return TrackSource(
      uri: Uri.parse(info.url),
      headers: info.headers,
      format: info.format == 'm4s' ? SourceFormat.mp4 : SourceFormat.unknown,
      expiresAt: info.expiresAt,
    );
  }
}
