import 'package:desen_ui/desen_ui.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_sites/live_sites.dart';
import 'package:pure_live/app/app.dart';
import 'package:pure_live/features/settings/settings.dart';
import 'package:pure_live/l10n/translations.dart';
import 'package:pure_live/shared/shared.dart';

/// One recommended room as a card: the cover, the title, the streamer and
/// the room's audience figure. Opening the room is [onOpen] — the player
/// page arrives later, so the card is inert until then.
///
/// The card follows the room-card appearance for the surface it is drawn
/// on: cover or compact shape, avatar, anchor name, platform and replay
/// badges, audience figure and corner radius. [viewport] pins the preview's
/// target in the settings pane; a feed passes none and the current device's
/// set applies.
final class RoomCard extends ConsumerWidget {
  /// Shows [room]; [compact] draws the one-column list row instead of the
  /// cover-on-top card.
  const RoomCard({required this.room, this.onOpen, this.compact = false, this.viewport, super.key});

  /// The room shown.
  final LiveRoom room;

  /// Fired when the card is opened.
  final VoidCallback? onOpen;

  /// Whether this is the list layout's compact row.
  final bool compact;

  /// The appearance set to read, or null for the current device's.
  final RoomCardViewport? viewport;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = DsTheme.colorsOf(context);
    final theme = DsTheme.of(context);
    final appearance = viewport == null
        ? ref.watch(roomCardAppearanceProvider)
        : ref.watch(
            roomCardSettingsProvider.select(
              (targets) => viewport == RoomCardViewport.mobile ? targets.mobile : targets.desktop,
            ),
          );
    final site = ref.read(sitesProvider).getById(room.ref.platform);
    final platformName = site == null ? room.ref.platform : localizedSiteName(site);
    final platformIcon = localizedSiteIcon(site, size: 12);
    final live = room.broadcast.isLiveNow;
    final replay = room.broadcast.isRecord;
    final anchorName = (room.anchor?.name ?? '').trim();
    final avatarUrl = (room.anchor?.avatarUrl ?? '').trim();
    final figure = appearance.showAudience
        ? audienceFigureOf(room, ref.watch(audienceMetricProvider), policy: ref.watch(audiencePolicyProvider))
        : null;
    final radius = BorderRadius.circular(appearance.cornerRadius);
    final row = compact || appearance.layout == RoomCardLayout.compact;
    final metaParts = [
      if (appearance.showAnchorName && anchorName.isNotEmpty) anchorName,
      ?roomBroadcastText(context.t, room),
    ];
    final meta = metaParts.join(' · ');
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 280;
        final badgeOnCover = appearance.platformBadge == RoomCardPlatformBadgeMode.always;
        final badgeAutomatic = appearance.platformBadge == RoomCardPlatformBadgeMode.automatic && wide;
        if (row) {
          // The list row is a card of its own: the cover sits inside its
          // padding instead of running to the card's edge, so the rows read
          // as cards rather than one full-width band.
          final line = SizedBox(
            height: 84,
            child: Row(
              children: [
                // The list layout keeps the small cover; a compact grid
                // card is the identity row alone, as in the reference.
                if (compact) ...[
                  SizedBox(
                    width: 148,
                    child: DsImage(
                      image: cachedImage(room.content.coverUrl),
                      width: 148,
                      height: 84,
                      semanticLabel: room.content.title,
                      fallback: _CoverFallback(title: room.content.title),
                      style: const DsImageStyle(borderRadius: BorderRadius.all(Radius.circular(8))),
                    ),
                  ),
                  const SizedBox(width: DsSpace.s12),
                ],
                if (appearance.showAvatar)
                  Padding(
                    padding: EdgeInsetsDirectional.only(start: compact ? 0 : DsSpace.s8),
                    child: DsAvatar(
                      initials: anchorName.isEmpty ? room.content.title : anchorName,
                      image: avatarUrl.isEmpty ? null : cachedImage(avatarUrl),
                      size: DsSize.sm,
                      semanticLabel: anchorName.isEmpty ? room.content.title : anchorName,
                    ),
                  ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: DsSpace.s12),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      spacing: 4,
                      children: [
                        Text(
                          room.content.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.typography.bodyStrong.copyWith(color: colors.text),
                        ),
                        if (meta.isNotEmpty)
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
                if (appearance.platformBadge == RoomCardPlatformBadgeMode.always ||
                    (appearance.platformBadge == RoomCardPlatformBadgeMode.automatic && constraints.maxWidth >= 300))
                  Padding(
                    padding: const EdgeInsetsDirectional.only(end: DsSpace.s6),
                    child: DsBadge(icon: platformIcon, label: Text(platformName)),
                  ),
                if (appearance.showReplayBadge && replay)
                  Padding(
                    padding: const EdgeInsetsDirectional.only(end: DsSpace.s6),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      spacing: 3,
                      children: [
                        DsIcon(DsIcons.history, size: 13, color: colors.textMuted),
                        Text(
                          context.t.settings.roomCardReplay,
                          style: theme.typography.caption.copyWith(color: colors.textMuted),
                        ),
                      ],
                    ),
                  ),
                if (figure != null)
                  Padding(
                    padding: const EdgeInsetsDirectional.only(end: DsSpace.s8),
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
                    padding: const EdgeInsetsDirectional.only(end: DsSpace.s12),
                    child: DsIcon(DsIcons.circleSlash, size: 14, color: colors.textSubtle),
                  ),
              ],
            ),
          );
          return DsCard(
            onPressed: onOpen,
            style: DsCardStyle(padding: EdgeInsets.zero, borderRadius: radius),
            child: compact ? Padding(padding: const EdgeInsets.all(DsSpace.s8), child: line) : line,
          );
        }
        // The card component carries the theme's fill, hover lift and focus
        // ring itself — the page only shapes what is inside.
        return DsCard(
          onPressed: onOpen,
          style: DsCardStyle(padding: EdgeInsets.zero, borderRadius: radius),
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
                    style: DsImageStyle(
                      borderRadius: BorderRadius.vertical(top: Radius.circular(appearance.cornerRadius)),
                    ),
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
                  if (badgeOnCover)
                    PositionedDirectional(
                      start: 8,
                      top: 8,
                      child: DsBadge(
                        icon: platformIcon,
                        label: Text(platformName),
                        style: DsBadgeStyle(
                          background: const Color(0x94000000),
                          foreground: const Color(0xFFFFFFFF),
                          textStyle: theme.typography.caption.copyWith(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                  if (appearance.showReplayBadge && replay)
                    PositionedDirectional(
                      end: 8,
                      top: 8,
                      child: RoomCoverChip(
                        text: context.t.settings.roomCardReplay,
                        icon: DsIcons.history,
                        maxWidth: 120,
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
                  child: Row(
                    spacing: 8,
                    children: [
                      if (appearance.showAvatar)
                        DsAvatar(
                          initials: anchorName.isEmpty ? room.content.title : anchorName,
                          image: avatarUrl.isEmpty ? null : cachedImage(avatarUrl),
                          size: DsSize.sm,
                          semanticLabel: anchorName.isEmpty ? room.content.title : anchorName,
                        ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
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
                            if (meta.isNotEmpty)
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
                                  // An off-air room keeps its place in the feed;
                                  // the room page will say why it cannot play.
                                  if (!live) DsIcon(DsIcons.circleSlash, size: 12, color: colors.textSubtle),
                                ],
                              ),
                          ],
                        ),
                      ),
                      if (badgeAutomatic) DsBadge(icon: platformIcon, label: Text(platformName)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
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
