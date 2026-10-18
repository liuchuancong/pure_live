import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_sites/live_sites.dart' show LiveRoom;
import 'package:pure_live/app/preferences/app_preferences_providers.dart';
import 'package:pure_live/l10n/generated/strings.g.dart';
import 'package:pure_live/shared/formatters/formatters.dart';
import 'package:pure_uikit/pure_uikit.dart';

/// Shared geometry for the room grids (3.x `room_card_layout.dart`): the
/// column count reacts to the window's width and every tile reserves a
/// cover of the room-card aspect preference plus a caption tall enough for
/// its two text lines.
///
/// Both ladders are anchored to the adaptive width classes (600 / 1024 / 1440)
/// rather than ad-hoc thresholds, so the cards re-flow at exactly the widths
/// the shell's navigation changes at.
abstract final class RoomGridMetrics {
  /// Columns for the discovery and area-room grids: two through the compact
  /// class, three on a tablet, four on an expanded desktop and five from the
  /// large class up — the reference's single row.
  static int columnsFor(double width) => AdaptiveBreakpoints.fromWidth(width).resolve<int>(
    compact: 2,
    medium: 3,
    expanded: 4,
    large: 5,
  );

  /// Columns for the favourites grid: **one wide card on a phone**, and from
  /// the medium class up a column fewer than the discovery grid until the
  /// large class joins it at the five-across reference row.
  ///
  /// The two ladders share their classes and differ only in how many cards
  /// fit, which is the point — a room you followed reads larger than one the
  /// feed is recommending. Keeping both numbers here rather than one of them
  /// inline in a page is what makes that difference legible instead of
  /// looking like a stale copy.
  static int favouriteColumnsFor(double width) => AdaptiveBreakpoints.fromWidth(width).resolve<int>(
    compact: 1,
    medium: 3,
    expanded: 4,
    large: 5,
  );

  /// The tile height for an [itemWidth]: the cover — [coverAspect] wide
  /// over tall — plus the caption, which grows with the ambient text scale
  /// instead of clipping it.
  static double mainAxisExtent(double itemWidth, TextScaler textScaler, {double coverAspect = 16 / 9}) {
    const titleSize = 14.0;
    const anchorSize = 12.0;
    const lineHeight = 1.4;
    final textHeight = textScaler.scale(titleSize) * lineHeight + 3 + textScaler.scale(anchorSize) * lineHeight;
    return itemWidth / coverAspect + math.max(64.0, textHeight + 24);
  }

  /// The grid delegate the room cards tile into at [width]; [coverAspect] is
  /// the room-card aspect preference's cover shape.
  static SliverGridDelegateWithFixedCrossAxisCount delegateFor(
    BuildContext context,
    double width, {
    double coverAspect = 16 / 9,
    int? columns,
    double? gutter,
  }) {
    const gap = PureSpacing.sm;
    final count = columns ?? columnsFor(width);
    // Two different measurements, whatever the old single `spacing` implied.
    // `gap` separates neighbouring tiles and is the grid's own business;
    // [gutter] is the padding the *caller* put on the `GridView`, which
    // `width` still has to give back before the tiles share what is left.
    // Passing one and not the other is how a grid ends up overflowing by
    // exactly the difference.
    final side = gutter ?? gap;
    final itemWidth = (width - 2 * side - gap * (count - 1)) / count;
    return SliverGridDelegateWithFixedCrossAxisCount(
      crossAxisCount: count,
      crossAxisSpacing: gap,
      mainAxisSpacing: gap,
      mainAxisExtent: mainAxisExtent(itemWidth, MediaQuery.textScalerOf(context), coverAspect: coverAspect),
    );
  }
}

/// One room in a grid (3.x `RoomCard`, cover preset): the cover — the room
/// card aspect preference's shape — with the platform, viewer-count and
/// status pills over it, then the title and, when the anchor line is kept,
/// the anchor beside their avatar. Tapping it opens the room; a long press
/// is where the follow page hangs its group assignment. The corner radius,
/// the pills and the cover shape all read the room-card preferences live.
final class RoomCard extends ConsumerWidget {
  /// Renders [room]; [onOpen] opens the room page.
  const new({required this.room, required this.onOpen, this.onLongPress, super.key});

  /// The room this card shows.
  final LiveRoom room;

  /// Called when the card is tapped.
  final VoidCallback onOpen;

  /// Called on long press; null leaves the card without one.
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = PureTheme.of(context);
    final style = ref.watch(roomCardStyleProvider);
    final cjk = Localizations.localeOf(context).languageCode == 'zh';
    final viewers = room.audience.onlineViewers ?? room.audience.popularity ?? room.audience.totalViewers;
    final anchorName = room.anchor?.name ?? '';
    final avatarUrl = room.anchor?.avatarUrl ?? '';
    return PureCard(
      onTap: onOpen,
      onLongPress: onLongPress,
      padding: EdgeInsets.zero,
      // The corner radius preference rides the card's own style slot; the
      // languages that map it (Fluent, Material, Yaru) round to it, the rest
      // keep their character.
      style: Style(borderRadius: BorderRadius.circular(style.cornerRadius)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: style.aspect.ratio,
            child: Stack(
              fit: StackFit.expand,
              children: [
                _cover(context, theme),
                if (style.showPlatform && room.ref.platform.isNotEmpty)
                  _pill(text: room.ref.platform.toUpperCase(), align: Alignment.topLeft),
                if (style.showAudience && room.broadcast.isLiveNow && viewers != null)
                  _pill(
                    icon: Icons.visibility_outlined,
                    text: compactCount(viewers, cjk: cjk),
                    align: Alignment.bottomRight,
                  )
                else if (style.showAudience && room.broadcast.isRecord)
                  _pill(icon: Icons.videocam_outlined, text: context.t.room.replay, align: Alignment.bottomRight)
                else if (style.showAudience && room.broadcast.isExplicitlyOfflineNow)
                  _pill(text: context.t.room.offline, align: Alignment.bottomRight),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
            child: Row(
              children: [
                if (style.showAnchor) ...[
                  PureAvatar(
                    name: anchorName.isEmpty ? room.ref.platform : anchorName,
                    src: avatarUrl.isEmpty ? null : CachedNetworkImageProvider(avatarUrl),
                    size: 32,
                  ),
                  const SizedBox(width: 8),
                ],
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
                      if (style.showAnchor) ...[
                        const SizedBox(height: 3),
                        Text(
                          anchorName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.text.bodySmall.copyWith(color: theme.colors.textSecondary),
                        ),
                      ],
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
