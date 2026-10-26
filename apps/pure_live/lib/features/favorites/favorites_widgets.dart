import 'package:desen_ui/desen_ui.dart';
import 'package:flutter/services.dart' show FilteringTextInputFormatter, TextInputType;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_sites/live_sites.dart';
import 'package:pure_live/features/settings/audience_metric_provider.dart'
    show audienceFigureOf, audienceMetricProvider, audiencePolicyProvider;
import 'package:pure_live/features/settings/room_card_settings.dart';
import 'package:pure_live/l10n/translations.dart';
import 'package:pure_live/shared/grids/room_cover_chip.dart';
import 'package:pure_live/shared/images/app_image_cache.dart';
import 'package:pure_live/shared/utils/audience_format.dart' show AudienceFormat;
import 'package:pure_live/shared/utils/room_broadcast_text.dart' show roomBroadcastText;
import 'package:pure_live/shared/widgets/choice_dialog.dart' show AdaptiveChoiceField;

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
    this.compact = false,
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

  /// Whether this is the list layout's compact row.
  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = DsTheme.colorsOf(context);
    final theme = DsTheme.of(context);
    final appearance = ref.watch(roomCardAppearanceProvider);
    final radius = BorderRadius.circular(appearance.cornerRadius);
    final audience = appearance.showAudience ? _audienceText(ref) : null;
    final showPlatform = platformName != null && appearance.platformBadge != RoomCardPlatformBadgeMode.hidden;
    final replay = appearance.showReplayBadge && room.broadcast.isRecord;
    final meta = _metaText(context, showAnchor: appearance.showAnchorName);
    final anchorName = (room.anchor?.name ?? '').trim();
    final avatarUrl = (room.anchor?.avatarUrl ?? '').trim();
    final row = compact || appearance.layout == RoomCardLayout.compact;
    if (row) {
      return DsCard(
        onPressed: onOpen,
        style: DsCardStyle(padding: EdgeInsets.zero, borderRadius: radius),
        child: SizedBox(
          height: 84,
          child: Row(
            children: [
              if (compact)
                SizedBox(
                  width: 148,
                  child: DsImage(
                    image: cachedImage(room.content.coverUrl),
                    width: 148,
                    height: 84,
                    semanticLabel: room.content.title,
                    fallback: _CoverFallback(title: room.content.title),
                    style: DsImageStyle(
                      borderRadius: BorderRadius.horizontal(left: Radius.circular(appearance.cornerRadius)),
                    ),
                  ),
                ),
              if (appearance.showAvatar)
                Padding(
                  padding: const EdgeInsetsDirectional.only(start: 10),
                  child: DsAvatar(
                    initials: anchorName.isEmpty ? room.content.title : anchorName,
                    image: avatarUrl.isEmpty ? null : cachedImage(avatarUrl),
                    size: DsSize.sm,
                    semanticLabel: anchorName.isEmpty ? room.content.title : anchorName,
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
                        [if (showPlatform) platformName, ?meta].join(' · '),
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
              ),
              if (replay)
                Padding(
                  padding: const EdgeInsetsDirectional.only(end: 6),
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
              if (audience != null)
                Padding(
                  padding: const EdgeInsetsDirectional.only(end: 8),
                  child: Row(
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
                ),
              Padding(
                padding: const EdgeInsetsDirectional.only(end: 8),
                child: DsPressable(
                  semanticLabel: context.t.favorites.unfollow,
                  onPressed: onUnfollow,
                  builder: (context, states, _) {
                    final hovered = states.contains(WidgetState.hovered);
                    return Container(
                      width: 30,
                      height: 30,
                      decoration: DsBoxDecoration(
                        color: hovered ? colors.danger.fill : null,
                        borderRadius: theme.radii.controlCorners(null, 30),
                      ),
                      child: Center(
                        child: DsIcon(DsIcons.heart, size: theme.sizes.iconSm, color: colors.textMuted),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
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
                    fallback: _CoverFallback(title: room.content.title),
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
    final figure = audienceFigureOf(
      room,
      ref.watch(audienceMetricProvider),
      policy: ref.watch(audiencePolicyProvider),
    );
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

/// The cover's stand-in when the picture does not load.
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

/// The follows' bottom pager (the reference's `PaginationBar`): refresh,
/// the page numbers with their arrows, rooms per page, and "go to page".
///
/// The workspace has no shared pager, so the favorites page carries this
/// one; it pages the already-loaded follows locally.
final class FavoritesPager extends StatefulWidget {
  /// Creates the pager over [pageCount] pages.
  const FavoritesPager({
    required this.page,
    required this.pageCount,
    required this.pageSize,
    required this.busy,
    required this.showPageSize,
    required this.showGoto,
    required this.pageSizes,
    required this.onPage,
    required this.onPageSize,
    required this.onRefresh,
    super.key,
  });

  /// The page shown, from 1.
  final int page;

  /// How many pages the follows fill.
  final int pageCount;

  /// Rooms per page.
  final int pageSize;

  /// A refresh is running: the buttons are inert.
  final bool busy;

  /// Whether the rooms-per-page selector shows (the reference's
  /// `showPageSizeSelector`); [pageSize] keeps paging when it is hidden.
  final bool showPageSize;

  /// Whether the jump-to-page field shows (the reference's
  /// `showGotoButton`); the page numbers keep paging when it is hidden.
  final bool showGoto;

  /// The rooms-per-page choices.
  final List<int> pageSizes;

  /// Shows another page.
  final ValueChanged<int> onPage;

  /// Picks rooms per page.
  final ValueChanged<int> onPageSize;

  /// Refreshes the visible slice.
  final VoidCallback onRefresh;

  @override
  State<FavoritesPager> createState() => _FavoritesPagerState();
}

final class _FavoritesPagerState extends State<FavoritesPager> {
  final TextEditingController _input = TextEditingController();

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  void _jump() {
    final target = int.tryParse(_input.text.trim());
    if (target == null) return;
    final page = target < 1 ? 1 : (target > widget.pageCount ? widget.pageCount : target);
    widget.onPage(page);
    _input.clear();
    FocusManager.instance.primaryFocus?.unfocus();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final colors = DsTheme.colorsOf(context);
    final theme = DsTheme.of(context);
    final muted = theme.typography.caption.copyWith(color: colors.textMuted);
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
        if (widget.showPageSize) ...[
          const SizedBox(width: DsSpace.s8),
          Text(t.favorites.perPage, style: muted),
          SizedBox(
            width: 88,
            child: AdaptiveChoiceField<int>(
              value: widget.pageSize,
              title: t.favorites.perPage,
              onChanged: busy ? null : widget.onPageSize,
              options: [for (final size in widget.pageSizes) DsSelectOption(value: size, label: '$size')],
              semanticLabel: t.favorites.perPage,
            ),
          ),
        ],
        if (widget.showGoto) ...[
          const SizedBox(width: DsSpace.s8),
          Text(t.favorites.goTo, style: muted),
          SizedBox(
            width: 56,
            child: DsTextField(
              controller: _input,
              enabled: !busy,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              onSubmitted: (_) => _jump(),
              semanticLabel: t.favorites.goTo,
              style: const DsTextFieldStyle(height: 30, padding: EdgeInsets.symmetric(horizontal: 6)),
            ),
          ),
          Text(t.favorites.pageUnit, style: muted),
        ],
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
