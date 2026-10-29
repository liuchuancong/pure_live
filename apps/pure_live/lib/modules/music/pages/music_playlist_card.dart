import 'dart:async' show unawaited;

import 'package:desen_ui/desen_ui.dart';
import 'package:flutter/widgets.dart';
import 'package:pure_live/l10n/translations.dart';
import 'package:pure_live/modules/music/controller/music_playlists.dart';
import 'package:pure_live/modules/music/controller/sources/online_playlist_models.dart';
import 'package:pure_live/shared/shared.dart';

/// The widest a playlist card gets before the grid takes another column, and
/// the narrowest one may get.
const double kMusicPlaylistCardMaxWidth = 200;
const double kMusicPlaylistCardMinWidth = 132;

/// The information block under a playlist card's cover: the title and the
/// creator beside the avatar, the room card's measure.
const double kMusicPlaylistInfoHeight = 48;

/// One playlist as a card, the room card's design carried over: the cover
/// leads — the track count in a chip over its bottom edge and the page's ⋮ in
/// the top corner — and the title with the creator sits beneath it. A list
/// without a cover of its own draws the title on the fallback tile.
final class MusicPlaylistCard extends StatelessWidget {
  /// A card for the viewer's own list.
  MusicPlaylistCard.own({
    required MusicPlaylist playlist,
    this.onOpen,
    this.menuBuilder,
    super.key,
  }) : title = playlist.name,
       coverUrl = null,
       creator = '',
       trackCount = playlist.tracks.length;

  /// A card for a playlist browsed from the source.
  // A field-initializer body cannot read the parameter's fields, so this
  // constructor is not const.
  MusicPlaylistCard.online({
    required MusicPlaylistInfo info,
    this.onOpen,
    this.menuBuilder,
    super.key,
  }) : title = info.name,
       coverUrl = info.cover,
       creator = info.author,
       trackCount = info.trackCount;

  /// The playlist's display name.
  final String title;

  /// The cover's address; null draws the fallback tile.
  final String? coverUrl;

  /// The creator's name; empty on the viewer's own lists.
  final String creator;

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
    final t = context.t;
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
                  image: (coverUrl ?? '').isEmpty ? null : cachedImage(coverUrl!),
                  aspectRatio: 1,
                  semanticLabel: title,
                  fallback: CoverFallback(title: title),
                  style: DsImageStyle(borderRadius: BorderRadius.vertical(top: Radius.circular(theme.radii.card))),
                ),
                const Positioned.fill(
                  child: IgnorePointer(child: DecoratedBox(decoration: BoxDecoration(gradient: kRoomCoverScrim))),
                ),
                if (menuBuilder != null)
                  PositionedDirectional(top: DsSpace.s8, end: DsSpace.s8, child: Builder(builder: menuBuilder!)),
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
                // The title sits close under the cover: the card reads as one
                // block.
                padding: const EdgeInsets.fromLTRB(10, 4, 10, 8),
                child: Row(
                  spacing: DsSpace.s8,
                  children: [
                    DsAvatar(initials: title, size: DsSize.md, semanticLabel: title),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        spacing: DsSpace.s3,
                        children: [
                          Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.typography.bodyStrong.copyWith(color: theme.colors.text),
                          ),
                          if (creator.isNotEmpty)
                            Text(
                              creator,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.typography.caption.copyWith(color: theme.colors.textMuted),
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
    );
  }
}

/// A playlist collection drawn as the room feed's grid: the columns follow
/// the width, the next page loads as the viewer nears the end and a footer
/// spinner rides the grid while it does.
final class MusicPlaylistGrid<T> extends StatefulWidget {
  /// A grid over [items].
  const MusicPlaylistGrid({
    required this.items,
    required this.itemBuilder,
    this.isLoading = false,
    this.hasMore = false,
    this.onLoadMore,
    this.padding = const EdgeInsets.fromLTRB(DsSpace.s20, DsSpace.s8, DsSpace.s20, DsSpace.s16),
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

  /// The grid's outer padding.
  final EdgeInsetsGeometry padding;

  @override
  State<MusicPlaylistGrid<T>> createState() => _MusicPlaylistGridState<T>();
}

final class _MusicPlaylistGridState<T> extends State<MusicPlaylistGrid<T>> {
  /// One ask in flight at a time: the scroll fires per frame while the
  /// viewer moves.
  bool _asking = false;

  /// Asks for the next page, once.
  void _onScroll(ScrollNotification notification) {
    final onLoadMore = widget.onLoadMore;
    if (_asking || onLoadMore == null || !widget.hasMore || widget.isLoading) return;
    if (notification.depth != 0) return;
    if (notification.metrics.pixels < notification.metrics.maxScrollExtent - 600) return;
    _asking = true;
    unawaited(onLoadMore().whenComplete(() {
      if (mounted) setState(() => _asking = false);
    }));
  }

  @override
  Widget build(BuildContext context) {
    final loadingRow = widget.isLoading && widget.hasMore;
    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        _onScroll(notification);
        return false;
      },
      child: LayoutBuilder(
        builder: (context, constraints) {
          final padding = widget.padding.resolve(Directionality.of(context));
          final content = (constraints.maxWidth - padding.horizontal).clamp(0.0, double.infinity);
          // The fewest columns that keep a card within the wide measure,
          // less one when that would leave a card narrower than the narrow
          // one — a phone shows two or three, a laptop five or six.
          double width(int columns) => (content - DsSpace.s12 * (columns - 1)) / columns;
          var columns = 1;
          while (width(columns) > kMusicPlaylistCardMaxWidth) {
            columns++;
          }
          if (columns > 1 && width(columns) < kMusicPlaylistCardMinWidth) columns--;
          final extent = width(columns) + 0.01;
          return GridView.builder(
            padding: widget.padding,
            gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: extent,
              mainAxisSpacing: DsSpace.s12,
              crossAxisSpacing: DsSpace.s12,
              mainAxisExtent: width(columns) + kMusicPlaylistInfoHeight,
            ),
            itemCount: widget.items.length + (loadingRow ? 1 : 0),
            itemBuilder: (context, index) {
              if (index >= widget.items.length) {
                return const Center(child: DsSpinner(style: DsSpinnerStyle(size: 24)));
              }
              return widget.itemBuilder(context, widget.items[index]);
            },
          );
        },
      ),
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
