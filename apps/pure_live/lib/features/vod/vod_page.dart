import 'dart:async' show unawaited;

import 'package:desen_ui/desen_ui.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_vod/live_vod.dart';
import 'package:pure_live/app/providers/browse_settings_providers.dart';
import 'package:pure_live/features/vod/vod_controller.dart';
import 'package:pure_live/l10n/translations.dart';
import 'package:pure_live/shared/grids/card_grid.dart';
import 'package:pure_live/shared/images/app_image_cache.dart';
import 'package:pure_live/shared/utils/audience_format.dart' show AudienceFormat;

/// How many skeleton cards stand in for a first page that has not landed.

/// The video-on-demand module's entry: a keyword search over the Bilibili
/// video source, its hits as a masonry grid that pages in as the viewer
/// nears its end.
///
/// The source searches videos and resolves play addresses, but offers
/// nothing to browse — no regions, rankings or recommendations — so the
/// page opens on an honest empty state that says a keyword starts
/// everything, and a missing capability is never faked with made-up data.
final class VodPage extends ConsumerStatefulWidget {
  /// The vod module's entry page.
  const VodPage({super.key});

  @override
  ConsumerState<VodPage> createState() => _VodPageState();
}

final class _VodPageState extends ConsumerState<VodPage> {
  final TextEditingController _field = TextEditingController();

  @override
  void dispose() {
    _field.dispose();
    super.dispose();
  }

  /// Runs the field's text as the search's query.
  void _onSubmitted(String draft) {
    unawaited(ref.read(vodProvider.notifier).search(draft));
  }

  @override
  Widget build(BuildContext context) {
    final vod = ref.watch(vodProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(DsSpace.s20, DsSpace.s12, DsSpace.s20, DsSpace.s8),
          child: DsSearchField(
            controller: _field,
            autofocus: true,
            placeholder: context.t.vod.searchHint,
            onSubmitted: _onSubmitted,
          ),
        ),
        Expanded(child: _VodResults(vod: vod)),
      ],
    );
  }
}

/// The results for the committed query: the video grid, or an honest
/// skeleton, empty state or error in its place.
final class _VodResults extends ConsumerWidget {
  const _VodResults({required this.vod});

  /// The search whose results show.
  final VodState vod;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    if (vod.query.isEmpty) {
      return Center(
        child: DsEmptyState(
          icon: const DsIcon(DsIcons.monitorPlay),
          title: Text(t.vod.idleTitle),
          description: Text(t.vod.idleDescription),
        ),
      );
    }
    if (vod.videos.isEmpty && vod.loading) {
      return const _SkeletonGrid();
    }
    if (vod.videos.isEmpty && vod.error != null) {
      return Center(
        child: DsEmptyState(
          icon: const DsIcon(DsIcons.cloudOff),
          title: Text(t.vod.errorTitle),
          description: Text(vod.error!.message),
          actions: [
            DsButton(onPressed: () => unawaited(ref.read(vodProvider.notifier).retry()), child: Text(t.vod.retry)),
          ],
        ),
      );
    }
    if (vod.videos.isEmpty) {
      return Center(
        child: DsEmptyState(
          icon: const DsIcon(DsIcons.searchX),
          title: Text(t.vod.noResultsTitle),
          description: Text(t.vod.noResultsDescription),
        ),
      );
    }
    return _VodGrid(vod: vod);
  }
}

/// The results grid: the hits as cards in the same masonry the home feed
/// uses, paging in as the view nears its end. The card width follows the
/// browse settings, so the settings page reflows this grid at once.
final class _VodGrid extends ConsumerWidget {
  const _VodGrid({required this.vod});

  /// The search whose hits show.
  final VodState vod;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(vodProvider.notifier);
    final cardExtent = ref.watch(browseSettingsProvider.select((settings) => settings.homeCardExtent));
    return CardGrid<VodVideo>(
      items: vod.videos,
      cardExtent: cardExtent,
      isLoading: vod.loading,
      hasMore: vod.hasMore,
      onLoadMore: controller.loadMore,
      itemBuilder: (context, video) => _VodCard(video: video),
    );
  }
}

/// One video hit as a grid card, after the search page's list-card idiom:
/// the pressable surface with its hover shadow, the cover with the duration
/// pill, then the title, the uploader and the play figure. The card stays
/// inert — opening a video is the player page's business, and that page has
/// not arrived yet.
final class _VodCard extends StatelessWidget {
  const _VodCard({required this.video});

  /// The video shown.
  final VodVideo video;

  @override
  Widget build(BuildContext context) {
    final colors = DsTheme.colorsOf(context);
    final theme = DsTheme.of(context);
    final plays = AudienceFormat.format(video.playCount);
    return DsPressable(
      onPressed: null,
      builder: (context, states, _) {
        final hovered = states.contains(WidgetState.hovered);
        return Container(
          decoration: DsBoxDecoration(
            color: hovered ? colors.hover : colors.surface,
            borderRadius: BorderRadius.circular(theme.radii.card),
            shadows: hovered
                ? [DsShadow(color: colors.overlay, blur: DsSpace.s24, offset: const Offset(0, DsSpace.s8))]
                : theme.shadows.surface,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: DsSpace.s6,
            children: [
              AspectRatio(
                aspectRatio: 16 / 9,
                child: ClipRRect(
                  borderRadius: BorderRadius.vertical(top: Radius.circular(theme.radii.card)),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Positioned.fill(
                        child: video.coverUrl == null
                            ? const _CoverFallback()
                            : DsImage(
                                // DsImage needs a reserved box; the stack's
                                // tight fill overrides the ratio here.
                                image: cachedImage(video.coverUrl!),
                                aspectRatio: 16 / 9,
                                semanticLabel: video.title,
                                fallback: const _CoverFallback(),
                              ),
                      ),
                      if (video.duration != null)
                        PositionedDirectional(
                          bottom: DsSpace.s6,
                          end: DsSpace.s6,
                          child: DsBadge(label: Text(_formatDuration(video.duration!)), dot: false),
                        ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: DsSpace.s12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: DsSpace.s4,
                  children: [
                    Text(
                      video.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.typography.body.copyWith(fontWeight: FontWeight.w600, color: colors.text),
                    ),
                    Row(
                      spacing: DsSpace.s4,
                      children: [
                        if ((video.uploader ?? '').trim().isNotEmpty)
                          Flexible(
                            child: Text(
                              video.uploader!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.typography.caption.copyWith(color: colors.textMuted),
                            ),
                          ),
                        const Spacer(),
                        if (plays.isNotEmpty)
                          Row(
                            spacing: DsSpace.s4,
                            children: [
                              DsIcon(DsIcons.eye, size: theme.sizes.iconXs, color: colors.textSubtle),
                              Text(
                                plays,
                                style: theme.typography.numeric(
                                  theme.typography.caption.copyWith(color: colors.textSubtle),
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// The cover's stand-in when the picture is missing: the surface color and
/// a video glyph, so the card keeps its shape.
final class _CoverFallback extends StatelessWidget {
  const _CoverFallback();

  @override
  Widget build(BuildContext context) {
    final colors = DsTheme.colorsOf(context);
    final theme = DsTheme.of(context);
    return ColoredBox(
      color: colors.control,
      child: Center(
        child: DsIcon(DsIcons.video, size: theme.sizes.iconSm, color: colors.textMuted),
      ),
    );
  }
}

/// The first page's placeholder: the same grid shape, no content.
final class _SkeletonGrid extends ConsumerWidget {
  const _SkeletonGrid();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cardExtent = ref.watch(browseSettingsProvider.select((settings) => settings.homeCardExtent));
    return CardGrid<Object>(
      items: const [],
      cardExtent: cardExtent,
      isLoading: true,
      itemBuilder: (context, item) => const SizedBox.shrink(),
    );
  }
}

/// [duration] as "m:ss" or "h:mm:ss" — the shape the source itself writes.
String _formatDuration(Duration duration) {
  final hours = duration.inHours;
  final minutes = duration.inMinutes.remainder(60);
  final seconds = duration.inSeconds.remainder(60);
  String two(int value) => value.toString().padLeft(2, '0');
  return hours > 0 ? '$hours:${two(minutes)}:${two(seconds)}' : '$minutes:${two(seconds)}';
}
