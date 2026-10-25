import 'package:desen_ui/desen_ui.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_sites/live_sites.dart';
import 'package:pure_live/features/settings/audience_metric_provider.dart'
    show audienceFigureOf, audienceMetricProvider;
import 'package:pure_live/l10n/translations.dart';
import 'package:pure_live/shared/grids/room_cover_chip.dart';
import 'package:pure_live/shared/images/app_image_cache.dart';
import 'package:pure_live/shared/utils/audience_format.dart' show AudienceFormat;
import 'package:pure_live/shared/utils/room_broadcast_text.dart' show roomBroadcastText;

/// One recommended room as a card: the cover, the title, the streamer and
/// the room's audience figure. Opening the room is [onOpen] — the player
/// page arrives later, so the card is inert until then.
final class RoomCard extends ConsumerWidget {
  /// Shows [room]; [compact] draws the one-column list row instead of the
  /// cover-on-top card.
  const RoomCard({required this.room, this.onOpen, this.compact = false, super.key});

  /// The room shown.
  final LiveRoom room;

  /// Fired when the card is opened.
  final VoidCallback? onOpen;

  /// Whether this is the list layout's compact row.
  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = DsTheme.colorsOf(context);
    final theme = DsTheme.of(context);
    final live = room.broadcast.isLiveNow;
    final figure = audienceFigureOf(room, ref.watch(audienceMetricProvider));
    final meta = [room.anchor?.name ?? room.ref.roomId, ?roomBroadcastText(context.t, room)].join(' · ');
    if (compact) {
      return DsCard(
        onPressed: onOpen,
        style: DsCardStyle(padding: EdgeInsets.zero, borderRadius: BorderRadius.circular(theme.radii.card)),
        child: SizedBox(
          height: 84,
          child: Row(
            children: [
              SizedBox(
                width: 148,
                child: DsImage(
                  image: cachedImage(room.content.coverUrl),
                  width: 148,
                  height: 84,
                  semanticLabel: room.content.title,
                  fallback: _CoverFallback(title: room.content.title),
                  style: DsImageStyle(borderRadius: BorderRadius.horizontal(left: Radius.circular(theme.radii.card))),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    spacing: 4,
                    children: [
                      Text(
                        room.content.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.typography.body.copyWith(fontWeight: FontWeight.w600, color: colors.text),
                      ),
                      Text(
                        meta,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.typography.caption.copyWith(color: colors.textMuted),
                      ),
                    ],
                  ),
                ),
              ),
              if (figure != null)
                Padding(
                  padding: const EdgeInsetsDirectional.only(end: 8),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    spacing: 4,
                    children: [
                      DsIcon(DsIcons.flame, size: 14, color: colors.accent),
                      Text(
                        AudienceFormat.format(figure),
                        style: theme.typography.numeric(theme.typography.caption.copyWith(color: colors.textMuted)),
                      ),
                    ],
                  ),
                ),
              if (!live)
                Padding(
                  padding: const EdgeInsetsDirectional.only(end: 12),
                  child: DsIcon(DsIcons.circleSlash, size: 14, color: colors.textSubtle),
                ),
            ],
          ),
        ),
      );
    }
    // The card component carries the theme's fill, radius, hover lift and
    // focus ring itself — the page only shapes what is inside.
    return DsCard(
      onPressed: onOpen,
      style: DsCardStyle(padding: EdgeInsets.zero, borderRadius: BorderRadius.circular(theme.radii.card)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // The cover keeps 16:9 whatever the tile's height; the text
          // row absorbs the remainder of the grid tile. DsImage needs
          // its own reserved box — the ratio is its parameter, not an
          // outer wrapper's.
          Stack(
            children: [
              DsImage(
                image: cachedImage(room.content.coverUrl),
                aspectRatio: 16 / 9,
                semanticLabel: room.content.title,
                fallback: _CoverFallback(title: room.content.title),
                style: DsImageStyle(borderRadius: BorderRadius.vertical(top: Radius.circular(theme.radii.card))),
              ),
              // The reference's cover hints: the room's own words and its
              // audience over the picture, where a feed can be read without
              // leaving the image.
              const PositionedDirectional(
                start: 0,
                end: 0,
                bottom: 0,
                height: 56,
                child: IgnorePointer(
                  child: DecoratedBox(decoration: BoxDecoration(gradient: kRoomCoverScrim)),
                ),
              ),
              PositionedDirectional(
                start: 8,
                end: 8,
                bottom: 8,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Flexible(
                      child: RoomCoverChip(
                        text: room.content.title,
                        style: theme.typography.caption.copyWith(
                          color: const Color(0xFFFFFFFF),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    if (figure != null) ...[
                      const Spacer(),
                      RoomCoverChip(text: AudienceFormat.format(figure), icon: DsIcons.flame, maxWidth: 120),
                    ],
                  ],
                ),
              ),
            ],
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: 3,
                children: [
                  Flexible(
                    child: Text(
                      room.content.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.typography.body.copyWith(fontWeight: FontWeight.w600, color: colors.text),
                    ),
                  ),
                  Row(
                    spacing: 6,
                    children: [
                      Expanded(
                        child: Text(
                          meta,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.typography.caption.copyWith(color: colors.textMuted),
                        ),
                      ),
                      // An off-air room keeps its place in the feed; the
                      // room page will say why it cannot play.
                      if (!live) DsIcon(DsIcons.circleSlash, size: 12, color: colors.textSubtle),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The cover's stand-in when the picture does not load: the room's title
/// over the surface color, so the card keeps its shape.
final class _CoverFallback extends StatelessWidget {
  const _CoverFallback({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final colors = DsTheme.colorsOf(context);
    return ColoredBox(
      color: colors.control,
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Align(
          alignment: Alignment.bottomLeft,
          child: Text(
            title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: DsTheme.of(context).typography.caption.copyWith(color: colors.textMuted),
          ),
        ),
      ),
    );
  }
}

/// The card's placeholder while its page loads: the same shape, no content.
final class RoomCardSkeleton extends StatelessWidget {
  /// Shows a card-sized skeleton.
  const RoomCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = DsTheme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 8,
      children: [
        AspectRatio(
          aspectRatio: 16 / 9,
          child: ClipRRect(
            borderRadius: BorderRadius.vertical(top: Radius.circular(theme.radii.card)),
            child: const DsSkeleton.block(height: double.infinity),
          ),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 6,
            children: [DsSkeleton(width: 200, height: 12), DsSkeleton(width: 120, height: 10)],
          ),
        ),
      ],
    );
  }
}
