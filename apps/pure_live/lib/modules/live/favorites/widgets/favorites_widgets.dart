import 'package:desen_ui/desen_ui.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_sites/live_sites.dart';
import 'package:pure_live/features/settings/settings.dart';
import 'package:pure_live/l10n/translations.dart';
import 'package:pure_live/shared/shared.dart';

/// A followed room's card: the feed card's cover hints — the title at the
/// bottom-left, the audience with its flame at the bottom-right, the
/// platform mark when the list mixes them — the unfollow heart, and
/// "streamer · live for …" under the title.
///
/// The reference's follow card carries the cover hints there; the
/// workspace card shares the same chip and broadcast-line helpers.
final class FollowedRoomCard extends ConsumerWidget {
  /// Shows [room]; [onUnfollow] is the heart's action.
  const FollowedRoomCard({
    required this.room,
    required this.onOpen,
    required this.onUnfollow,
    this.platformName,
    this.tags = const [],
    this.listRow = false,
    super.key,
  });

  /// The followed room.
  final LiveRoom room;

  /// Opens the room.
  final VoidCallback onOpen;

  /// Removes the room from the follows.
  final VoidCallback onUnfollow;

  /// The platform's name, shown as a cover mark while the list mixes
  /// platforms (the reference's mixed-list badge); null hides it.
  final String? platformName;

  /// The local tags this room carries, in the tag list's order; an empty
  /// list shows no line.
  final List<String> tags;

  /// Whether this is the feed's list layout, not its grid.
  final bool listRow;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = DsTheme.colorsOf(context);
    final theme = DsTheme.of(context);
    final appearance = ref.watch(roomCardAppearanceProvider);
    final radius = BorderRadius.circular(appearance.cornerRadius);
    final visibility = appearance.visibility;
    final audience = visibility.shows(RoomCardElement.audience) ? _audienceText(ref) : null;
    final showPlatform = platformName != null && visibility.shows(RoomCardElement.platformBadge);
    final replay = visibility.shows(RoomCardElement.replayBadge) && room.broadcast.isRecord;
    final meta = _metaText(context, showAnchor: visibility.shows(RoomCardElement.anchorName));
    final showAvatar = visibility.shows(RoomCardElement.avatar);
    final showTitle = visibility.shows(RoomCardElement.title);
    final anchorName = (room.anchor?.name ?? '').trim();
    final avatarUrl = (room.anchor?.avatarUrl ?? '').trim();
    if (listRow) {
      // The list row is a card of its own and follows the feed's fixed
      // design: a round avatar, the title over a muted line, the audience,
      // and the unfollow heart instead of the feed's chevron.
      final subtitle = [
        if (showPlatform) platformName!,
        ?meta,
        if (replay) context.t.settings.roomCardReplay,
      ].join(' · ');
      final line = SizedBox(
        height: kRoomCardListDesignHeight,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: DsSpace.s12, vertical: DsSpace.s8),
          child: Row(
            spacing: DsSpace.s12,
            children: [
              if (showAvatar)
                DsAvatar(
                  initials: anchorName.isEmpty ? room.content.title : anchorName,
                  image: avatarUrl.isEmpty ? null : cachedImage(avatarUrl),
                  size: DsSize.lg,
                  semanticLabel: anchorName.isEmpty ? room.content.title : anchorName,
                ),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: 4,
                  children: [
                    if (showTitle)
                      Text(
                        room.content.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.typography.bodyStrong.copyWith(color: colors.text),
                      ),
                    if (subtitle.isNotEmpty)
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.typography.caption.copyWith(color: colors.textMuted),
                      ),
                    if (tags.isNotEmpty)
                      Text(
                        tags.join(' · '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.typography.caption.copyWith(color: colors.textSubtle),
                      ),
                  ],
                ),
              ),
              if (audience != null)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  spacing: 4,
                  children: [
                    DsIcon(DsIcons.flame, size: 14, color: colors.accent),
                    Text(
                      audience,
                      style: theme.typography.numeric(theme.typography.caption.copyWith(color: colors.textMuted)),
                    ),
                  ],
                ),
              DsButton.icon(
                variant: DsButtonVariant.ghost,
                size: DsSize.sm,
                semanticLabel: context.t.favorites.unfollow,
                onPressed: onUnfollow,
                icon: DsIcon(DsIcons.heart, size: theme.sizes.iconSm),
              ),
            ],
          ),
        ),
      );
      return DsCard(
        onPressed: onOpen,
        style: DsCardStyle(padding: EdgeInsets.zero, borderRadius: radius),
        child: line,
      );
    }
    return Stack(
      children: [
        DsCard(
          onPressed: onOpen,
          style: DsCardStyle(padding: EdgeInsets.zero, borderRadius: radius),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Stack(
                children: [
                  DsImage(
                    image: cachedImage(room.content.coverUrl),
                    aspectRatio: 16 / 9,
                    semanticLabel: room.content.title,
                    fallback: CoverFallback(title: room.content.title),
                    style: DsImageStyle(
                      borderRadius: BorderRadius.vertical(top: Radius.circular(appearance.cornerRadius)),
                    ),
                  ),
                  const PositionedDirectional(
                    start: 0,
                    end: 0,
                    bottom: 0,
                    height: 56,
                    child: IgnorePointer(
                      child: DecoratedBox(decoration: BoxDecoration(gradient: kRoomCoverScrim)),
                    ),
                  ),
                  if (showPlatform || replay)
                    PositionedDirectional(
                      top: DsSpace.s8,
                      start: DsSpace.s8,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        spacing: 6,
                        children: [
                          if (showPlatform) RoomCoverChip(text: platformName!, maxWidth: 132),
                          if (replay)
                            RoomCoverChip(
                              text: context.t.settings.roomCardReplay,
                              icon: DsIcons.history,
                              maxWidth: 120,
                            ),
                        ],
                      ),
                    ),
                  PositionedDirectional(
                    start: DsSpace.s8,
                    end: DsSpace.s8,
                    bottom: DsSpace.s8,
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
                        if (audience != null) ...[
                          const Spacer(),
                          RoomCoverChip(
                            text: audience,
                            icon: DsIcons.flame,
                            maxWidth: 132,
                            style: theme.typography.numeric(
                              theme.typography.caption.copyWith(
                                color: const Color(0xFFFFFFFF),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
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
                      if (showAvatar)
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
                            if (showTitle)
                              Flexible(
                                child: Text(
                                  room.content.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.typography.body.copyWith(
                                    fontWeight: FontWeight.w600,
                                    color: colors.text,
                                  ),
                                ),
                              ),
                            if (meta != null)
                              Text(
                                meta,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.typography.caption.copyWith(color: colors.textMuted),
                              ),
                            if (tags.isNotEmpty)
                              Text(
                                tags.join(' · '),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.typography.caption.copyWith(color: colors.textSubtle),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        PositionedDirectional(
          top: DsSpace.s8,
          end: DsSpace.s8,
          child: DsPressable(
            semanticLabel: context.t.favorites.unfollow,
            onPressed: onUnfollow,
            builder: (context, states, _) {
              final hovered = states.contains(WidgetState.hovered);
              return Container(
                width: theme.sizes.sm,
                height: theme.sizes.sm,
                decoration: DsBoxDecoration(
                  color: hovered ? colors.danger.fill : colors.overlay,
                  borderRadius: theme.radii.controlCorners(null, theme.sizes.sm),
                ),
                child: Center(
                  child: DsIcon(DsIcons.heart, size: theme.sizes.iconSm, color: colors.text),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  /// The room's one audience figure: the metric the list leads with, else
  /// the first figure the source gave; null when it gave none.
  /// The audience badge's words, or null when no figure exists.
  String? _audienceText(WidgetRef ref) {
    final figure = audienceFigureOf(room, ref.watch(audienceMetricProvider), policy: ref.watch(audiencePolicyProvider));
    if (figure == null) return null;
    return AudienceFormat.format(figure);
  }

  /// Streamer · broadcast, each only where the room has it; the audience
  /// stays on the cover. [showAnchor] hides the streamer's name only.
  String? _metaText(BuildContext context, {required bool showAnchor}) {
    final streamer = room.anchor?.name.trim() ?? '';
    final status = roomBroadcastText(context.t, room);
    final parts = [if (showAnchor && streamer.isNotEmpty) streamer, ?status];
    return parts.isEmpty ? null : parts.join(' · ');
  }
}

/// The follows' bottom pager: a refresh and the kit's pagination — the page
/// numbers with their arrows, nothing else.
///
/// The workspace has no shared pager, so the favorites page carries this
/// one; it pages the already-loaded follows locally.
final class FavoritesPager extends StatefulWidget {
  /// Creates the pager over [pageCount] pages.
  const FavoritesPager({
    required this.page,
    required this.pageCount,
    required this.busy,
    required this.onPage,
    required this.onRefresh,
    super.key,
  });

  /// The page shown, from 1.
  final int page;

  /// How many pages the follows fill.
  final int pageCount;

  /// A refresh is running: the buttons are inert.
  final bool busy;

  /// Shows another page.
  final ValueChanged<int> onPage;

  /// Refreshes the visible slice.
  final VoidCallback onRefresh;

  @override
  State<FavoritesPager> createState() => _FavoritesPagerState();
}

final class _FavoritesPagerState extends State<FavoritesPager> {
  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final colors = DsTheme.colorsOf(context);
    final busy = widget.busy;
    final row = Row(
      mainAxisSize: MainAxisSize.min,
      spacing: DsSpace.s8,
      children: [
        DsButton(
          variant: DsButtonVariant.secondary,
          size: DsSize.sm,
          leading: busy
              ? const SizedBox(width: 12, height: 12, child: DsSpinner())
              : const DsIcon(DsIcons.refreshCw, size: 14),
          onPressed: busy ? null : widget.onRefresh,
          child: Text(t.favorites.refresh),
        ),
        DsPagination(
          page: widget.page,
          pageCount: widget.pageCount,
          onChanged: busy ? null : widget.onPage,
          previousLabel: t.popular.prevPage,
          nextLabel: t.popular.nextPage,
        ),
      ],
    );
    return LayoutBuilder(
      builder: (context, constraints) => DecoratedBox(
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: colors.border)),
        ),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: DsSpace.s20, vertical: DsSpace.s8),
          child: ConstrainedBox(
            constraints: BoxConstraints(minWidth: constraints.maxWidth - DsSpace.s20 * 2),
            child: Align(alignment: AlignmentDirectional.center, child: row),
          ),
        ),
      ),
    );
  }
}
