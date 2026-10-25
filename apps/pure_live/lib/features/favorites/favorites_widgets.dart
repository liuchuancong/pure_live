import 'package:desen_ui/desen_ui.dart';
import 'package:flutter/services.dart' show FilteringTextInputFormatter, TextInputType;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_sites/live_sites.dart';
import 'package:pure_live/features/settings/audience_metric_provider.dart' show audienceFigureOf, audienceMetricProvider;
import 'package:pure_live/l10n/translations.dart';
import 'package:pure_live/shared/grids/room_cover_chip.dart';
import 'package:pure_live/shared/images/app_image_cache.dart';
import 'package:pure_live/shared/utils/audience_format.dart' show AudienceFormat;
import 'package:pure_live/shared/utils/room_broadcast_text.dart' show roomBroadcastText;

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
    final audience = _audienceText(ref);
    final meta = _metaText(context);
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
                  style: DsImageStyle(
                    borderRadius: BorderRadius.horizontal(left: Radius.circular(theme.radii.card)),
                  ),
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
                        [?platformName, ?meta].join(' · '),
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
          style: DsCardStyle(padding: EdgeInsets.zero, borderRadius: BorderRadius.circular(theme.radii.card)),
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
                    style: DsImageStyle(borderRadius: BorderRadius.vertical(top: Radius.circular(theme.radii.card))),
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
                  if (platformName != null)
                    PositionedDirectional(
                      top: DsSpace.s8,
                      start: DsSpace.s8,
                      child: RoomCoverChip(text: platformName!, maxWidth: 132),
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
                      if (_metaText(context) case final meta?)
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
    final figure = audienceFigureOf(room, ref.watch(audienceMetricProvider));
    if (figure == null) return null;
    return AudienceFormat.format(figure);
  }

  /// Streamer · broadcast, each only where the room has it; the audience
  /// stays on the cover.
  String? _metaText(BuildContext context) {
    final streamer = room.anchor?.name.trim() ?? '';
    final status = roomBroadcastText(context.t, room);
    final parts = [if (streamer.isNotEmpty) streamer, ?status];
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
        const SizedBox(width: DsSpace.s8),
        Text(t.favorites.perPage, style: muted),
        DsSelect<int>(
          value: widget.pageSize,
          onChanged: busy
              ? null
              : (value) {
                  if (value != null) widget.onPageSize(value);
                },
          options: [for (final size in widget.pageSizes) DsSelectOption(value: size, label: '$size')],
          semanticLabel: t.favorites.perPage,
        ),
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
