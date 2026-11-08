import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_vod/live_vod.dart';
import 'package:media_core/media_core.dart';
import 'package:pure_live/modules/vod/controller/vod_controller.dart' show vodClientProvider;
import 'package:pure_live/shared/shared.dart' show CoverPreviewPlayer, CoverPreviewSource;

/// A VOD archive's hover preview: the video itself, played on the cover at
/// the lowest definition the archive serves — the glance, not the viewing.
/// The DASH answer's picture alone is enough for a muted preview, so the
/// sound's track is never asked for.
final class VodVideoPreview extends ConsumerStatefulWidget {
  /// Previews [video]'s first part.
  const VodVideoPreview({required this.video, super.key});

  /// The archive shown.
  final VodVideo video;

  @override
  ConsumerState<VodVideoPreview> createState() => _VodVideoPreviewState();
}

final class _VodVideoPreviewState extends ConsumerState<VodVideoPreview> {
  @override
  Widget build(BuildContext context) {
    return CoverPreviewPlayer(resolve: _resolve);
  }

  Future<CoverPreviewSource?> _resolve() async {
    final client = ref.read(vodClientProvider);
    final video = widget.video;
    final info = await client.play(video);
    final picture = _lowestPicture(info);
    if (picture == null) return null;
    final uri = Uri.parse(picture.url);
    return (
      source: PlayerSource.of(
        id: SourceId('vod-preview:${video.bvid ?? video.id}'),
        uri: uri,
        type: SourceType.remote,
        protocol: SourceProtocol.fromScheme(uri.scheme),
        format: SourceFormat.fromUri(uri),
        headers: info.headers.isEmpty ? null : SourceHeaders(info.headers),
        title: video.title,
      ),
      onDone: null,
    );
  }

  /// The ladder's own lowest tier, AVC preferred when two tiers tie — the
  /// order the engines decode in, applied to the bottom rather than the top
  /// of the ladder.
  VodDashVideo? _lowestPicture(VodPlayInfo info) {
    if (info.videos.isEmpty) return null;
    int rank(VodDashVideo video) {
      final codec = video.codec.toLowerCase();
      final avc = video.codecId == 7 || codec.startsWith('avc');
      return (avc ? 1 : 0) * 100000000 + (1000000 - video.quality) * 1000;
    }

    final sorted = [...info.videos]..sort((a, b) => rank(a).compareTo(rank(b)));
    return sorted.first;
  }
}

/// A PGC season's hover preview: the episode the card opens on — or, when
/// the listing named none, the season's first — at its lowest definition.
final class VodSeasonPreview extends ConsumerStatefulWidget {
  /// Previews [season].
  const VodSeasonPreview({required this.season, super.key});

  /// The season shown.
  final VodSeason season;

  @override
  ConsumerState<VodSeasonPreview> createState() => _VodSeasonPreviewState();
}

final class _VodSeasonPreviewState extends ConsumerState<VodSeasonPreview> {
  @override
  Widget build(BuildContext context) {
    return CoverPreviewPlayer(resolve: _resolve);
  }

  Future<CoverPreviewSource?> _resolve() async {
    final client = ref.read(vodClientProvider);
    final season = widget.season;
    final episodeId =
        season.episodeId ?? (await client.seasonDetail(seasonId: season.seasonId)).episodes.first.id;
    final info = await client.pgcPlay(episodeId: episodeId);
    if (info.videos.isEmpty) return null;
    final picture = [...info.videos]..sort((a, b) => a.quality.compareTo(b.quality));
    final uri = Uri.parse(picture.first.url);
    return (
      source: PlayerSource.of(
        id: SourceId('vod-preview:pgc:$episodeId'),
        uri: uri,
        type: SourceType.remote,
        protocol: SourceProtocol.fromScheme(uri.scheme),
        format: SourceFormat.fromUri(uri),
        headers: info.headers.isEmpty ? null : SourceHeaders(info.headers),
        title: season.title,
      ),
      onDone: null,
    );
  }
}
