import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_core/media_core.dart';
import 'package:pure_live/modules/hongguo/controller/hongguo_client.dart'
    show hongguoClientProvider, hongguoStreamProxyProvider;
import 'package:pure_live/modules/hongguo/controller/hongguo_models.dart' show HongguoSeries;
import 'package:pure_live/modules/hongguo/official/hongguo_official.dart' show HongguoRendition;
import 'package:pure_live/shared/shared.dart' show CoverPreviewPlayer, CoverPreviewSource;

/// A series' hover preview: its first episode, played on the poster at the
/// lowest tier the station serves — the glance, not the viewing.
///
/// The episode's picture rides the module's own decrypt relay (the station's
/// files are CENC-sealed), so the preview's address is a loopback one, and
/// its entry is forgotten the moment the preview leaves: an address that
/// lingers behind a hover nobody watched is a leak, not a cache.
final class HongguoSeriesPreview extends ConsumerStatefulWidget {
  /// Previews [series].
  const HongguoSeriesPreview({required this.series, super.key});

  /// The series shown.
  final HongguoSeries series;

  @override
  ConsumerState<HongguoSeriesPreview> createState() => _HongguoSeriesPreviewState();
}

/// The glance's tier: the ladder's lowest, and where the station ties the
/// tiers, the one every engine on this device decodes (h264). A ladder with
/// nothing on it hands back nothing.
@visibleForTesting
HongguoRendition? hongguoPreviewRendition(List<HongguoRendition> ladder) {
  if (ladder.isEmpty) return null;
  int rank(HongguoRendition rendition) {
    final avc = rendition.codec.toLowerCase().contains('264');
    return (avc ? 0 : 1) * 1000000 + rendition.quality * 10;
  }

  return ([...ladder]..sort((a, b) => rank(a).compareTo(rank(b)))).first;
}

final class _HongguoSeriesPreviewState extends ConsumerState<HongguoSeriesPreview> {
  @override
  Widget build(BuildContext context) {
    return CoverPreviewPlayer(resolve: _resolve, viaPlayerProxy: false);
  }

  Future<CoverPreviewSource?> _resolve() async {
    final client = ref.read(hongguoClientProvider);
    final detail = await client.detail(widget.series.seriesId);
    if (detail.episodes.isEmpty) return null;
    final ladder = await client.playbackLadder(detail.episodes.first.vid);
    final rendition = hongguoPreviewRendition(ladder);
    if (rendition == null) return null;
    final url = await ref.read(hongguoStreamProxyProvider).register(rendition);
    return (
      source: PlayerSource.of(
        id: SourceId('hongguo-preview:${widget.series.seriesId}'),
        uri: Uri.parse(url),
        type: SourceType.remote,
        protocol: SourceProtocol.fromScheme(Uri.parse(url).scheme),
        format: SourceFormat.fromUri(Uri.parse(url)),
        title: widget.series.title,
      ),
      onDone: () => ref.read(hongguoStreamProxyProvider).forget(url),
    );
  }
}
