import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:live_sites/live_sites.dart' show LiveRoom;
import 'package:pure_live/l10n/generated/strings.g.dart';
import 'package:pure_live/shared/formatters/formatters.dart';
import 'package:pure_uikit/pure_uikit.dart';

/// One room in a discovery grid: cover, title, anchor and viewer count.
/// Tapping it opens the room.
final class RoomCard extends StatelessWidget {
  /// Renders [room]; [onOpen] opens the room page.
  const new({required this.room, required this.onOpen, super.key});

  /// The room this card shows.
  final LiveRoom room;

  /// Called when the card is tapped.
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final cjk = Localizations.localeOf(context).languageCode == 'zh';
    final viewers = room.audience.onlineViewers ?? room.audience.popularity ?? room.audience.totalViewers;
    return PureCard(
      onTap: onOpen,
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: 16 / 9,
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (room.content.coverUrl.isNotEmpty)
                  CachedNetworkImage(imageUrl: room.content.coverUrl, fit: BoxFit.cover)
                else
                  const ColoredBox(color: Color(0x22888888), child: Icon(Icons.live_tv_outlined)),
                if (viewers != null)
                  Positioned(
                    right: 6,
                    bottom: 6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: const BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.all(Radius.circular(6)),
                      ),
                      child: Text(
                        compactCount(viewers, cjk: cjk),
                        style: const TextStyle(color: Colors.white, fontSize: 11),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  room.content.title.isEmpty ? context.t.common.empty : room.content.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: PureTheme.of(context).text.body,
                ),
                const SizedBox(height: 4),
                Text(
                  room.anchor?.name ?? '',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: PureTheme.of(context).text.bodySmall
                      .copyWith(color: PureTheme.of(context).colors.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
