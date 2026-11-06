import 'dart:async' show unawaited;

import 'package:desen_ui/desen_ui.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_cache/live_cache.dart' show ImageCachePolicies;
import 'package:pure_live/app/app.dart' show browseSettingsProvider;
import 'package:pure_live/l10n/translations.dart';
import 'package:pure_live/modules/music/controller/music_playlists.dart';
import 'package:pure_live/modules/music/controller/sources/online_playlist_models.dart';
import 'package:pure_live/shared/shared.dart';

/// The widest a playlist card gets before the grid takes another column, and
/// the narrowest one may get.
const double kMusicPlaylistCardMaxWidth = 200;
const double kMusicPlaylistCardMinWidth = 132;

/// The information block under a playlist card's cover: the name in two lines
/// and, on a list browsed from the source, its creator under them. The measure
/// the station poster cards use for a name plus one listing line — so the cover
/// keeps the rest of the tile, every card of a wall ends at the same line
/// whatever the column width, and the two lines cannot spill over the block.
const double kMusicPlaylistInfoHeight = 82;

/// One playlist as a card, the room card's design carried over: the cover
/// leads — the track count in a chip over its bottom edge and the page's ⋮ in
/// the top corner — and the name sits beneath it in two lines, with the
/// creator's own name under that. A list without a cover of its own draws the
/// module's mark, not its title: the block underneath is where the name lives,
/// and a card is not the place to say it twice.
final class MusicPlaylistCard extends StatelessWidget {
  /// A card for the viewer's own list.
  MusicPlaylistCard.own({required MusicPlaylist playlist, this.onOpen, this.menuBuilder, super.key})
    : title = playlist.name,
      coverUrl = null,
      creator = '',
      plays = 0,
      trackCount = playlist.tracks.length;

  /// A card for a playlist browsed from the source.
  // A field-initializer body cannot read the parameter's fields, so this
  // constructor is not const.
  MusicPlaylistCard.online({required MusicPlaylistInfo info, this.onOpen, this.menuBuilder, super.key})
    : title = info.name,
      coverUrl = info.cover,
      creator = info.author,
      plays = info.playCount,
      trackCount = info.trackCount;

  /// The playlist's display name.
  final String title;

  /// The cover's address; null draws the fallback tile.
  final String? coverUrl;

  /// The creator's name; empty on the viewer's own lists.
  final String creator;

  /// How many times the list has been played; zero when the platform says no.
  final int plays;

  /// How many tracks the playlist holds; the chip over the cover.
  final int trackCount;

  /// Fired when the card is opened.
  final VoidCallback? onOpen;

  /// Builds the ⋮ in the cover's top-end corner; null leaves the corner to
  /// the chips.
  final WidgetBuilder? menuBuilder;

  @override
  Widget build(BuildContext context) {
    final theme = DsTheme.of(context);
    final colors = theme.colors;
    final t = context.t;
    // The stand-in for a list with no picture: the module's mark on the control
    // fill. Its name is written under the cover, in two lines; the cover is not
    // a second place to write it, and a chip along the foot would print over
    // whatever the tile put there.
    final fallback = ColoredBox(
      color: colors.control,
      child: Center(child: DsIcon(DsIcons.music, size: 28, color: colors.textMuted)),
    );
    return DsCard(
      onPressed: onOpen,
      style: const DsCardStyle(padding: EdgeInsets.zero),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(theme.radii.card),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Stack(
              children: [
                DsImage(
                  image: (coverUrl ?? '').isEmpty
                      ? null
                      : cachedImage(coverUrl!, policy: ImageCachePolicies.albumCover),
                  aspectRatio: 1,
                  semanticLabel: title,
                  fallback: fallback,
                  style: DsImageStyle(borderRadius: BorderRadius.vertical(top: Radius.circular(theme.radii.card))),
                ),
                const Positioned.fill(
                  child: IgnorePointer(
                    child: DecoratedBox(decoration: BoxDecoration(gradient: kRoomCoverScrim)),
                  ),
                ),
                if (menuBuilder != null)
                  PositionedDirectional(
                    top: DsSpace.s8,
                    end: DsSpace.s8,
                    child: Builder(builder: menuBuilder!),
                  ),
                PositionedDirectional(
                  start: DsSpace.s8,
                  end: DsSpace.s8,
                  bottom: DsSpace.s8,
                  child: Row(
                    children: [
                      RoomCoverChip(
                        text: t.music.songsCount(count: trackCount),
                        icon: DsIcons.listMusic,
                        maxWidth: 120,
                        compact: true,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(
              height: kMusicPlaylistInfoHeight,
              child: Padding(
                // The name sits close under the cover: the card reads as one
                // block.
                padding: const EdgeInsets.fromLTRB(DsSpace.s12, DsSpace.s6, DsSpace.s12, DsSpace.s8),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: DsSpace.s4,
                  children: [
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.typography.body.copyWith(fontWeight: FontWeight.w600, color: colors.text),
                    ),
                    // One listing line under the name: who made the list, and
                    // where the platform names no creator — migu's tag rows
                    // give only a play figure — how often it has been played.
                    if (creator.isNotEmpty || plays > 0)
                      Text(
                        creator.isNotEmpty ? creator : t.music.playsCount(count: AudienceFormat.format(plays)),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.typography.caption.copyWith(color: colors.textMuted),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A playlist collection drawn as the room feed's grid: a wide window pages
/// it by number — the wheel's end asks the pager for its next page — while a
/// narrow one appends the source's next page as the viewer scrolls. Its gaps
/// and columns are the browsing settings', not this module's own: the wall
/// breathes the same air the home feed does.
final class MusicPlaylistGrid<T> extends ConsumerStatefulWidget {
  /// A grid over [items].
  const MusicPlaylistGrid({
    required this.items,
    required this.itemBuilder,
    this.isLoading = false,
    this.hasMore = false,
    this.onLoadMore,
    this.onRefresh,
    this.pageSize = 30,
    this.padding,
    super.key,
  });

  /// The items shown.
  final List<T> items;

  /// Builds one card.
  final Widget Function(BuildContext context, T item) itemBuilder;

  /// Whether a page is in flight: the footer row shows a spinner.
  final bool isLoading;

  /// Whether another page may exist; [onLoadMore] fires near the end.
  final bool hasMore;

  /// Fetches the next page.
  final Future<void> Function()? onLoadMore;

  /// Reloads the first page when the viewer pulls the grid down.
  final Future<void> Function()? onRefresh;

  /// How many cards one display page holds on a wide window.
  final int pageSize;

  /// The grid's outer padding; null keeps the window's gutter.
  final EdgeInsetsGeometry? padding;

  @override
  ConsumerState<MusicPlaylistGrid<T>> createState() => _MusicPlaylistGridState<T>();
}

final class _MusicPlaylistGridState<T> extends ConsumerState<MusicPlaylistGrid<T>> {
  /// One ask in flight at a time: the scroll fires per frame while the
  /// viewer moves.
  bool _asking = false;

  /// The page the viewer asked for; a shorter list reads as its first.
  int _asked = 1;

  /// How many display pages the accumulated list fills whole.
  int get _inHandPages => widget.items.length ~/ widget.pageSize;

  /// The page actually shown: [_asked] pulled back into the list's range.
  int get _page {
    if (widget.items.length <= (_asked - 1) * widget.pageSize) return 1;
    return _asked;
  }

  /// Asks for the next page, once.
  void _onScroll(ScrollNotification notification) {
    final onLoadMore = widget.onLoadMore;
    if (_asking || onLoadMore == null || !widget.hasMore || widget.isLoading) return;
    if (notification.depth != 0) return;
    if (notification.metrics.pixels < notification.metrics.maxScrollExtent - 600) return;
    _asking = true;
    unawaited(
      onLoadMore().whenComplete(() {
        if (mounted) setState(() => _asking = false);
      }),
    );
  }

  /// Moves the pager to [next]: a page already in hand moves without a
  /// request, one past the hand asks the source and only moves when the
  /// page arrived.
  Future<void> _goToPage(int next) async {
    final onLoadMore = widget.onLoadMore;
    if (next <= _page || widget.isLoading) return;
    if (next > _inHandPages + 1) return;
    if (next > _inHandPages) {
      if (onLoadMore == null) return;
      final before = widget.items.length;
      await onLoadMore();
      if (!mounted || widget.items.length <= before) return;
    }
    if (!mounted) return;
    setState(() => _asked = next);
  }

  Widget _grid(List<T> items, {required bool pagesOnScrollToEnd, bool hasMore = false}) {
    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        _onScroll(notification);
        return false;
      },
      child: LayoutBuilder(
        builder: (context, constraints) {
          final browse = ref.watch(browseSettingsProvider);
          final padding = feedGutter(context, custom: widget.padding, top: DsSpace.s8, bottom: DsSpace.s16);
          final content = (constraints.maxWidth - padding.horizontal).clamp(0.0, double.infinity);
          // The viewer's gaps, not this module's own: every feed that follows
          // the browsing settings keeps its cards the same distance apart.
          final spacing = browse.crossSpacing;
          // One card's share of the row at [columns] columns.
          double width(int columns) => (content - spacing * (columns - 1)) / columns;
          // The count the wall has always taken on width alone: the fewest
          // columns that keep a card within the wide measure, less one when
          // that would leave a card narrower than the narrow one.
          int columnsOfWidth() {
            var columns = 1;
            while (width(columns) > kMusicPlaylistCardMaxWidth) {
              columns++;
            }
            if (columns > 1 && width(columns) < kMusicPlaylistCardMinWidth) columns--;
            return columns;
          }

          // The columns the wall takes under the viewer's settings: a phone —
          // a row too narrow for two cards at the narrow measure — keeps the
          // mobile column count directly, cards a little narrower for it;
          // elsewhere the viewer's ceiling lowers the width-derived count,
          // and a ceiling of none leaves that count to say.
          var columns = columnsOfWidth();
          if (content <= 0) {
            columns = 1;
          } else if (content < kMusicPlaylistCardMinWidth * 2 + spacing) {
            columns = browse.phoneColumns;
          } else {
            final capped = cappedColumnsForWidth(
              content,
              spacing: spacing,
              ceiling: browse.gridColumns,
              minWidth: kMusicPlaylistCardMinWidth,
            );
            if (capped > 0) columns = capped;
          }
          return GridView.builder(
            padding: padding,
            gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: columnExtentForWidth(content, columns, spacing),
              mainAxisSpacing: browse.mainSpacing,
              crossAxisSpacing: spacing,
              mainAxisExtent: width(columns) + kMusicPlaylistInfoHeight,
            ),
            itemCount: items.length + (widget.isLoading && hasMore ? 1 : 0),
            itemBuilder: (context, index) {
              if (index >= items.length) {
                return const Center(child: DsSpinner(style: DsSpinnerStyle(size: 24)));
              }
              return widget.itemBuilder(context, items[index]);
            },
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= LiveWindow.paging;
    // The grid keeps the page's gutter, the live module's measure.
    final inset = LiveWindow.pageInset(MediaQuery.sizeOf(context).width);
    if (!wide) return _grid(widget.items, pagesOnScrollToEnd: false, hasMore: widget.hasMore);
    final end = _page * widget.pageSize;
    final shown = widget.items.length <= end ? widget.items : widget.items.sublist(0, end);
    final moreInHand = widget.items.length > end;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(child: _grid(shown, pagesOnScrollToEnd: true, hasMore: moreInHand || widget.hasMore)),
        // A collection that fills one page never grows a pager.
        if (_inHandPages + (widget.hasMore ? 1 : 0) > 1)
          Padding(
            padding: EdgeInsets.fromLTRB(inset, DsSpace.s12, inset, DsSpace.s12),
            child: Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                spacing: DsSpace.s8,
                children: [
                  if (widget.isLoading) const SizedBox(width: 14, height: 14, child: DsSpinner()),
                  DsPagination(
                    page: _page,
                    pageCount: _inHandPages + (widget.hasMore ? 1 : 0),
                    onChanged: (next) => unawaited(_goToPage(next)),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

/// The ⋮ a page's own lists carry in the cover's corner: the room card's
/// dark glass circle around a menu anchor.
final class MusicCardMenuButton extends StatelessWidget {
  /// Opens the page's menu for one card.
  const MusicCardMenuButton({required this.semanticLabel, required this.items, super.key});

  /// The button's accessible name.
  final String semanticLabel;

  /// The menu's entries.
  final List<DsMenuItem> items;

  @override
  Widget build(BuildContext context) {
    return DsMenuAnchor(
      semanticLabel: semanticLabel,
      items: items,
      builder: (context, controller, _) => DsButton.icon(
        onPressed: controller.toggle,
        semanticLabel: semanticLabel,
        size: DsSize.xs,
        variant: DsButtonVariant.ghost,
        icon: const DsIcon(DsIcons.ellipsisVertical),
        style: const DsButtonStyle(
          height: 28,
          padding: EdgeInsets.zero,
          background: Color(0x66000000),
          foreground: Color(0xFFFFFFFF),
          borderColor: Color(0x26FFFFFF),
          borderWidth: 1,
        ),
      ),
    );
  }
}
