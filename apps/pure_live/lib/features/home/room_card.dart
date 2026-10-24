import 'package:desen_ui/desen_ui.dart';
import 'package:flutter/widgets.dart';
import 'package:live_sites/live_sites.dart';
import 'package:pure_live/shared/utils/audience_format.dart' show AudienceFormat;

/// One recommended room as a card: the cover, the title, the streamer and
/// the room's audience figure. Opening the room is [onOpen] — the player
/// page arrives later, so the card is inert until then.
final class RoomCard extends StatelessWidget {
  /// Shows [room].
  const RoomCard({required this.room, this.onOpen, super.key});

  /// The room shown.
  final LiveRoom room;

  /// Fired when the card is opened.
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) {
    final colors = DsTheme.colorsOf(context);
    final theme = DsTheme.of(context);
    final live = room.broadcast.isLiveNow;
    final figure = room.audience.primaryMetric == LiveAudienceMetricType.onlineViewers
        ? room.audience.onlineViewers
        : room.audience.popularity;
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
          DsImage.network(
            room.content.coverUrl,
            aspectRatio: 16 / 9,
            semanticLabel: room.content.title,
            fallback: _CoverFallback(title: room.content.title),
            style: DsImageStyle(
              borderRadius: BorderRadius.vertical(top: Radius.circular(theme.radii.card)),
            ),
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
                      Flexible(
                        child: Text(
                          room.anchor?.name ?? room.ref.roomId,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.typography.caption.copyWith(color: colors.textMuted),
                        ),
                      ),
                      if (figure != null)
                        Text(
                          AudienceFormat.format(figure),
                          style: theme.typography.numeric(theme.typography.caption.copyWith(color: colors.textSubtle)),
                        ),
                      const Spacer(),
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
