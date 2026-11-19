import 'dart:async' show unawaited;
import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:live_sites/live_sites.dart';
import 'package:pure_live/app/app.dart';
import 'package:pure_live/features/settings/settings.dart' show kRoomCardListDesignHeight, roomCardTileHeight;
import 'package:pure_live/modules/live/popular/room_card.dart' show RoomCard;
import 'package:pure_live/modules/live/popular/room_card_menu.dart' show RoomCardMenu;
import 'package:pure_live/shared/shared.dart';

/// The row-card width a shelf draws while two of them still fit beside the
/// page's inset; below that the rail turns into two grid cards across —
/// the vod live rail drew this rule first, on a 390 phone where one row
/// card left a 26px hint of the next and read as a mistake.
const double _kShelfRowCardWidth = 320;

/// The narrowest grid card the fallback still draws.
const double _kShelfCardMinWidth = 150;

/// One horizontal shelf of rooms: the row-card form where two row cards
/// still fit side by side, two grid cards across where they don't. Every
/// page that answers with a rail of rooms — the home's continue-watching
/// and followed-live shelves, the vod live rail — draws this one shelf, so
/// the cards, the gap and the narrow fallback never drift apart.
final class RoomShelf extends ConsumerWidget {
  /// Draws [rooms] as one horizontal rail.
  const RoomShelf({required this.rooms, this.noteOf, super.key});

  /// The rooms the shelf shows, already the ones the page chose.
  final List<LiveRoom> rooms;

  /// A short corner line the page knows about the room — the history's
  /// watch clock, say. Null keeps the audience figure the card already
  /// draws.
  final String? Function(LiveRoom room)? noteOf;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final spacing = ref.watch(browseSettingsProvider).crossSpacing;
    final inset = LiveWindow.pageInset(MediaQuery.sizeOf(context).width);
    return LayoutBuilder(
      builder: (context, constraints) {
        final content = math.max(0, constraints.maxWidth - inset * 2);
        final holdsRows = content >= _kShelfRowCardWidth * 2 + spacing;
        final cardWidth = holdsRows ? _kShelfRowCardWidth : math.max(_kShelfCardMinWidth, (content - spacing) / 2);
        final cardExtent = holdsRows ? kRoomCardListDesignHeight : roomCardTileHeight(cardWidth);
        return SizedBox(
          height: cardExtent,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.symmetric(horizontal: inset),
            itemCount: rooms.length,
            separatorBuilder: (context, index) => SizedBox(width: spacing),
            itemBuilder: (context, index) {
              final room = rooms[index];
              return SizedBox(
                width: cardWidth,
                child: RoomCardMenu(
                  room: room,
                  onOpen: () => unawaited(
                    openRoom(context, platform: room.ref.platform, roomId: room.ref.roomId, room: room, playlist: rooms),
                  ),
                  child: RoomCard(
                    room: room,
                    listRow: holdsRows,
                    cornerNote: noteOf == null ? null : noteOf!(room),
                    onOpen: () => unawaited(
                      openRoom(
                        context,
                        platform: room.ref.platform,
                        roomId: room.ref.roomId,
                        room: room,
                        playlist: rooms,
                      ),
                    ),
                    livePreview: true,
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}
