import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:live_sites/live_sites.dart' show LiveRoom;
import 'package:pure_uikit/pure_uikit.dart';

/// A room card for the ten-foot wall: the cover, the room's title, its anchor
/// and audience, and a focus ring that is the only affordance a D-pad has.
///
/// Focus is drawn with scale and an accent border rather than a hover fill —
/// a viewer three metres away reads a lift, not a tint — and the card takes
/// the focus itself, so the traversal order is the grid's order.
final class TvFocusCard extends StatefulWidget {
  /// A card for [room]; [onSelect] runs on OK/Enter.
  const new({required this.room, required this.onSelect, this.autofocus = false, super.key});

  /// The room shown.
  final LiveRoom room;

  /// Runs when the card is activated.
  final VoidCallback onSelect;

  /// Whether the card takes the focus when the wall first shows.
  final bool autofocus;

  @override
  State<TvFocusCard> createState() => _TvFocusCardState();
}

final class _TvFocusCardState extends State<TvFocusCard> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final theme = PureTheme.of(context);
    final room = widget.room;
    final cover = room.content.coverUrl.trim();
    final anchor = room.anchor?.name.trim() ?? '';
    final viewers = room.audience.onlineViewers ?? room.audience.popularity;
    final live = room.broadcast.effectiveLiveStatus.name == 'live';
    return Semantics(
      button: true,
      label: room.content.title.isEmpty ? room.ref.roomId : room.content.title,
      child: Focus(
        autofocus: widget.autofocus,
        onFocusChange: (value) {
          if (value != _focused) {
            setState(() => _focused = value);
          }
        },
        child: GestureDetector(
          onTap: widget.onSelect,
          child: AnimatedScale(
            scale: _focused ? 1.06 : 1,
            duration: const Duration(milliseconds: 120),
            curve: Curves.easeOut,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 120),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: _focused ? theme.colors.primary : Colors.transparent, width: 3),
                boxShadow: _focused
                    ? [BoxShadow(color: theme.colors.primary.withValues(alpha: 0.35), blurRadius: 18)]
                    : null,
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(11),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (cover.isEmpty)
                      ColoredBox(color: theme.colors.fillQuaternary)
                    else
                      CachedNetworkImage(
                        imageUrl: cover,
                        fit: BoxFit.cover,
                        errorWidget: (_, _, _) => ColoredBox(color: theme.colors.fillQuaternary),
                      ),
                    // The caption band: title over the anchor, readable over
                    // any cover.
                    Align(
                      alignment: Alignment.bottomCenter,
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.fromLTRB(12, 20, 12, 10),
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [Color(0x00000000), Color(0xE6000000)],
                          ),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              room.content.title.isEmpty ? room.ref.roomId : room.content.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.text.body.copyWith(color: Colors.white, fontWeight: FontWeight.w700),
                            ),
                            if (anchor.isNotEmpty)
                              Text(
                                anchor,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.text.caption.copyWith(color: Colors.white70),
                              ),
                          ],
                        ),
                      ),
                    ),
                    if (live)
                      PositionedDirectional(
                        top: 10,
                        start: 10,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(color: theme.colors.error, borderRadius: BorderRadius.circular(6)),
                          child: Text(
                            'LIVE',
                            style: theme.text.caption.copyWith(color: Colors.white, fontWeight: FontWeight.w700),
                          ),
                        ),
                      ),
                    if (viewers != null)
                      PositionedDirectional(
                        bottom: 10,
                        end: 12,
                        child: Text(
                          _compact(viewers),
                          style: theme.text.caption.copyWith(color: Colors.white, fontWeight: FontWeight.w600),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  static String _compact(int value) => value >= 10000 ? '${(value / 10000).toStringAsFixed(1)}万' : '$value';
}
