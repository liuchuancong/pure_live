import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:live_sites/live_sites.dart' show LiveRoom;
import 'package:pure_live/l10n/generated/strings.g.dart';
import 'package:pure_live/shared/formatters/formatters.dart';
import 'package:pure_uikit/pure_uikit.dart';

/// Shared geometry for the room grids (3.x `room_card_layout.dart`): the
/// column count reacts to the window's width and every tile reserves a
/// 16:9 cover plus a caption tall enough for its two text lines.
abstract final class RoomGridMetrics {
  /// Columns for the discovery and area-room grids: tighter on phones,
  /// five across a wide desktop window.
  static int columnsFor(double width) => width > 1280 ? 5 : (width > 960 ? 4 : (width > 640 ? 3 : 2));

  /// The tile height for an [itemWidth]: the cover plus the caption, which
  /// grows with the ambient text scale instead of clipping it.
  static double mainAxisExtent(double itemWidth, TextScaler textScaler) {
    const titleSize = 14.0;
    const anchorSize = 12.0;
    const lineHeight = 1.4;
    final textHeight = textScaler.scale(titleSize) * lineHeight + 3 + textScaler.scale(anchorSize) * lineHeight;
    return itemWidth * 9 / 16 + math.max(64.0, textHeight + 24);
  }

  /// The grid delegate the room cards tile into at [width].
  static SliverGridDelegateWithFixedCrossAxisCount delegateFor(BuildContext context, double width) {
    const spacing = PureSpacing.sm;
    final columns = columnsFor(width);
    final itemWidth = (width - 2 * spacing - spacing * (columns - 1)) / columns;
    return SliverGridDelegateWithFixedCrossAxisCount(
      crossAxisCount: columns,
      crossAxisSpacing: spacing,
      mainAxisSpacing: spacing,
      mainAxisExtent: mainAxisExtent(itemWidth, MediaQuery.textScalerOf(context)),
    );
  }
}

/// One room in a grid (3.x `RoomCard`, cover preset): the 16:9 cover with
/// the platform, viewer-count and status pills over it, then the title and
/// the anchor beside their avatar. Tapping it opens the room; a long press
/// is where the follow page hangs its group assignment.
final class RoomCard extends StatelessWidget {
  /// Renders [room]; [onOpen] opens the room page.
  const new({required this.room, required this.onOpen, this.onLongPress, super.key});

  /// The room this card shows.
  final LiveRoom room;

  /// Called when the card is tapped.
  final VoidCallback onOpen;

  /// Called on long press; null leaves the card without one.
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final theme = PureTheme.of(context);
    final cjk = Localizations.localeOf(context).languageCode == 'zh';
    final viewers = room.audience.onlineViewers ?? room.audience.popularity ?? room.audience.totalViewers;
    final anchorName = room.anchor?.name ?? '';
    final avatarUrl = room.anchor?.avatarUrl ?? '';
    return PureCard(
      onTap: onOpen,
      onLongPress: onLongPress,
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: 16 / 9,
            child: Stack(
              fit: StackFit.expand,
              children: [
                _cover(context, theme),
                if (room.ref.platform.isNotEmpty)
                  _pill(text: room.ref.platform.toUpperCase(), align: Alignment.topLeft),
                if (room.broadcast.isLiveNow && viewers != null)
                  _pill(
                    icon: Icons.visibility_outlined,
                    text: compactCount(viewers, cjk: cjk),
                    align: Alignment.bottomRight,
                  )
                else if (room.broadcast.isRecord)
                  _pill(icon: Icons.videocam_outlined, text: context.t.room.replay, align: Alignment.bottomRight)
                else if (room.broadcast.isExplicitlyOfflineNow)
                  _pill(text: context.t.room.offline, align: Alignment.bottomRight),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
            child: Row(
              children: [
                PureAvatar(
                  name: anchorName.isEmpty ? room.ref.platform : anchorName,
                  src: avatarUrl.isEmpty ? null : CachedNetworkImageProvider(avatarUrl),
                  size: 32,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        room.content.title.isEmpty ? context.t.common.empty : room.content.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.text.body.copyWith(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        anchorName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.text.bodySmall.copyWith(color: theme.colors.textSecondary),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// The cover, or a quiet token-coloured placeholder when there is none or
  /// it fails to load.
  Widget _cover(BuildContext context, PureTheme theme) {
    final fallback = ColoredBox(
      color: theme.colors.fillQuaternary,
      child: Center(child: Icon(Icons.live_tv_outlined, color: theme.colors.textQuaternary)),
    );
    if (room.content.coverUrl.isEmpty) {
      return fallback;
    }
    return CachedNetworkImage(imageUrl: room.content.coverUrl, fit: BoxFit.cover, errorWidget: (_, _, _) => fallback);
  }

  /// A cover pill (3.x `CoverMetricBadge`): a dark scrim keeps it readable
  /// over any thumbnail.
  Widget _pill({required String text, required Alignment align, IconData? icon}) {
    final atTopLeft = align == Alignment.topLeft;
    return Positioned(
      left: atTopLeft ? 6 : null,
      top: atTopLeft ? 6 : null,
      right: atTopLeft ? null : 6,
      bottom: atTopLeft ? null : 6,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.55),
          borderRadius: const BorderRadius.all(Radius.circular(6)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[Icon(icon, color: Colors.white, size: 12), const SizedBox(width: 3)],
            Text(
              text,
              maxLines: 1,
              style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}
