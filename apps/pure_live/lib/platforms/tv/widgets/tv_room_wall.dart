import 'package:flutter/material.dart';
import 'package:live_sites/live_sites.dart' show LiveRoom;
import 'package:pure_live/platforms/tv/widgets/tv_focus_card.dart';
import 'package:pure_uikit/pure_uikit.dart';

/// The ten-foot wall of rooms: a D-pad grid whose first card takes the focus,
/// four to a row by width, and an empty state that keeps the remote useful.
///
/// The traversal order is the grid's own: Flutter's reading-order policy walks
/// the cards in index order, row by row — the order a remote expects.
final class TvRoomWall extends StatelessWidget {
  /// A wall of [rooms].
  const new({
    required this.rooms,
    required this.onSelect,
    this.emptyTitle,
    this.emptyIcon = Icons.live_tv_outlined,
    super.key,
  });

  /// The rooms shown, in order.
  final List<LiveRoom> rooms;

  /// Runs when a card is activated.
  final ValueChanged<LiveRoom> onSelect;

  /// The empty state's title; null means the caller wants nothing.
  final String? emptyTitle;

  /// The empty state's glyph.
  final IconData emptyIcon;

  @override
  Widget build(BuildContext context) {
    if (rooms.isEmpty) {
      final title = emptyTitle;
      return title == null
          ? const SizedBox.shrink()
          : Center(
              child: PureEmpty(title: title, icon: emptyIcon),
            );
    }
    return FocusTraversalGroup(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final columns = constraints.maxWidth >= 1600
              ? 5
              : constraints.maxWidth >= 1100
              ? 4
              : 3;
          return GridView.builder(
            padding: const EdgeInsets.fromLTRB(48, 24, 48, 48),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: columns,
              mainAxisSpacing: 24,
              crossAxisSpacing: 24,
              childAspectRatio: 16 / 10,
            ),
            itemCount: rooms.length,
            itemBuilder: (context, index) => TvFocusCard(
              key: ValueKey('tv-room-${rooms[index].ref.platform}-${rooms[index].ref.roomId}'),
              room: rooms[index],
              autofocus: index == 0,
              onSelect: () => onSelect(rooms[index]),
            ),
          );
        },
      ),
    );
  }
}
