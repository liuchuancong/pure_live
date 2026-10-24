import 'dart:async' show unawaited;

import 'package:desen_ui/desen_ui.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart' show GoRouterHelper;
import 'package:live_sites/live_sites.dart' show LiveRoom, LiveRoomRefIdentity;
import 'package:pure_live/app/providers/sites_providers.dart' show sitesProvider;
import 'package:pure_live/app/routing/app_router.dart' show RoomRoute;
import 'package:pure_live/features/favorites/follow_repository.dart' show followsProvider;
import 'package:pure_live/features/multiview/multiview_controller.dart';
import 'package:pure_live/l10n/translations.dart';

/// The multi-view wall (the reference's multiview): 1, 2, 4, 6 or 9 panes,
/// each holding a followed room, with the layout switcher in the header
/// and every pane picking, opening, clearing or exchanging its room. The
/// arrangement persists in the multiview store, so a revisit opens the
/// same wall.
///
/// The panes preview their room's cover; the video itself arrives with
/// the player stack (`media_core_multiview`), so a pane is a picture and
/// its controls today.
final class MultiviewPage extends ConsumerStatefulWidget {
  /// The multi-view page.
  const MultiviewPage({super.key});

  @override
  ConsumerState<MultiviewPage> createState() => _MultiviewPageState();
}

final class _MultiviewPageState extends ConsumerState<MultiviewPage> {
  /// The pane a pending swap starts from; null while none is pending.
  int? _swapSource;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final colors = DsTheme.colorsOf(context);
    final theme = DsTheme.of(context);
    final wall = ref.watch(multiviewProvider);
    if (!wall.ready) {
      return const Center(child: SizedBox(width: 24, height: 24, child: DsSpinner()));
    }
    final rooms = ref.watch(followsProvider.select((state) => state.rooms));
    final byIdentity = {for (final room in rooms) room.ref.identityKey: room};
    final slots = [
      for (var index = 0; index < wall.slots.length; index++)
        (
          index: index,
          key: wall.slots[index],
          room: wall.slots[index] == null ? null : byIdentity[wall.slots[index]],
          title: _slotTitle(wall.slots[index], byIdentity[wall.slots[index]]),
        ),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(DsSpace.s20, DsSpace.s12, DsSpace.s20, DsSpace.s8),
          child: Row(
            spacing: DsSpace.s16,
            children: [
              DsSegmentedControl<int>(
                segments: [for (final count in kMultiviewLayouts) DsSegment(value: count, label: Text('$count'))],
                value: wall.layout,
                semanticLabel: t.multiview.layoutLabel,
                onChanged: (count) {
                  setState(() => _swapSource = null);
                  unawaited(ref.read(multiviewProvider.notifier).setLayout(count));
                },
              ),
              Expanded(
                child: Align(
                  alignment: AlignmentDirectional.centerEnd,
                  child: Text(
                    t.multiview.videoComingSoon,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.typography.small.copyWith(color: colors.textSubtle),
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(child: _wall(wall, slots)),
      ],
    );
  }

  /// The wall: the layout's grid of panes, each an equal share of the
  /// body's width and height.
  Widget _wall(MultiviewState wall, List<({int index, String? key, LiveRoom? room, String title})> slots) {
    final (columns, rows) = _gridOf(wall.layout);
    return Padding(
      padding: const EdgeInsets.fromLTRB(DsSpace.s20, DsSpace.s4, DsSpace.s20, DsSpace.s20),
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Tight windows tighten the gaps before the panes give up
          // anything else.
          final gap = constraints.maxWidth < 560 ? DsSpace.s4 : DsSpace.s8;
          return Column(
            spacing: gap,
            children: [
              for (var row = 0; row < rows; row++)
                Expanded(
                  child: Row(
                    spacing: gap,
                    children: [
                      for (var column = 0; column < columns; column++)
                        Expanded(child: _pane(slots, row * columns + column)),
                    ],
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  /// One pane of the wall, wired to the page's handlers.
  Widget _pane(List<({int index, String? key, LiveRoom? room, String title})> slots, int at) {
    final slot = slots[at];
    return _PaneTile(
      slot: slot,
      swapSource: _swapSource,
      onPick: () => unawaited(_pickForSlot(slot.index)),
      onOpen: () => _openSlot(slot.key, slot.room),
      onClear: () => _clearSlot(slot.index),
      onSwapStart: () => setState(() => _swapSource = slot.index),
      onSwapWith: () => _handleSwapTap(slot.index),
    );
  }

  /// The (columns, rows) a layout's pane count fills.
  static (int, int) _gridOf(int layout) => switch (layout) {
    1 => (1, 1),
    2 => (2, 1),
    4 => (2, 2),
    6 => (2, 3),
    9 => (3, 3),
    _ => (2, 2),
  };

  /// The pane's title: the room's own title, or the identity a pane holds
  /// whose room left the follows (the pane keeps its place until cleared).
  String _slotTitle(String? key, LiveRoom? room) {
    if (room != null) return room.content.title;
    if (key == null) return '';
    final at = key.indexOf(':');
    final platform = at < 0 ? key : key.substring(0, at);
    final roomId = at < 0 ? '' : key.substring(at + 1);
    final site = ref.read(sitesProvider).getById(platform);
    return '${site?.manifest.name['zh-CN'] ?? platform} · $roomId';
  }

  /// Opens the room a pane holds; the pane keeps playing nothing yet, the
  /// room page opens above the shell as usual.
  void _openSlot(String? key, LiveRoom? room) {
    if (key == null) return;
    final at = key.indexOf(':');
    if (at < 0) return;
    final platform = room?.ref.platform ?? key.substring(0, at);
    final roomId = room?.ref.roomId ?? key.substring(at + 1);
    unawaited(context.push(RoomRoute(platform: platform, roomId: roomId).location));
  }

  /// Empties a pane; a pending swap that starts here ends too.
  void _clearSlot(int index) {
    setState(() {
      if (_swapSource == index) _swapSource = null;
    });
    unawaited(ref.read(multiviewProvider.notifier).clearSlot(index));
  }

  /// A tap on a pane while a swap is pending: the source pane cancels,
  /// any other pane exchanges its room with the source's (an empty one
  /// receives it).
  void _handleSwapTap(int index) {
    final source = _swapSource;
    setState(() => _swapSource = null);
    if (source == null || source == index) return;
    unawaited(ref.read(multiviewProvider.notifier).swapSlots(source, index));
  }

  /// The pane picker over the wall: the followed rooms, each row
  /// assigning into the pane that asked.
  Future<void> _pickForSlot(int index) {
    return showDsDialog<void>(
      context: context,
      builder: (context) => _PanePickerDialog(slotIndex: index),
    );
  }
}

/// One pane of the wall: an assigned one shows its room's cover, its
/// title, and the exchange and clear buttons; an empty one offers the
/// pane picker. While a swap is pending ([swapSource]), every pane joins
/// in — the source rings and each tap elsewhere exchanges.
final class _PaneTile extends StatelessWidget {
  const _PaneTile({
    required this.slot,
    required this.swapSource,
    required this.onPick,
    required this.onOpen,
    required this.onClear,
    required this.onSwapStart,
    required this.onSwapWith,
  });

  /// The pane's data: its place in the wall, the identity it holds and
  /// the room that identity resolves to.
  final ({int index, String? key, LiveRoom? room, String title}) slot;

  /// The pane a pending swap starts from, null while none is pending.
  final int? swapSource;

  final VoidCallback onPick;
  final VoidCallback onOpen;
  final VoidCallback onClear;
  final VoidCallback onSwapStart;
  final VoidCallback onSwapWith;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final colors = DsTheme.colorsOf(context);
    final theme = DsTheme.of(context);
    final assigned = slot.key != null;
    final swapping = swapSource != null;
    final isSource = swapSource == slot.index;
    return DsPressable(
      semanticLabel: assigned ? slot.title : t.multiview.pickRoom,
      onPressed: swapping
          ? onSwapWith
          : assigned
          ? onOpen
          : onPick,
      builder: (context, states, _) {
        final hovered = states.contains(WidgetState.hovered);
        return Container(
          clipBehavior: Clip.antiAlias,
          decoration: DsBoxDecoration(
            color: colors.control,
            borderRadius: BorderRadius.circular(theme.radii.card),
            shadows: [DsShadow.innerRing(isSource ? colors.channel : colors.border, width: isSource ? 2 : 1)],
          ),
          child: assigned
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(child: _cover(colors, theme, hovered)),
                    _bar(context, colors, theme),
                  ],
                )
              : Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    spacing: DsSpace.s8,
                    children: [
                      DsIcon(
                        swapping ? DsIcons.arrowLeftRight : DsIcons.plus,
                        size: theme.sizes.iconLg,
                        color: colors.textSubtle,
                      ),
                      Text(
                        swapping ? t.multiview.swapHere : t.multiview.pickRoom,
                        style: theme.typography.caption.copyWith(color: colors.textMuted),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
        );
      },
    );
  }

  /// The room's cover, cropped to fill the pane above the title bar; a
  /// room the follows no longer know shows the stand-in only.
  Widget _cover(DsColors colors, DsThemeData theme, bool hovered) {
    final url = slot.room?.content.coverUrl ?? '';
    final fallback = ColoredBox(
      color: colors.channel,
      child: Center(
        child: DsIcon(DsIcons.tv, size: theme.sizes.iconLg, color: colors.textSubtle),
      ),
    );
    if (url.isEmpty) return fallback;
    return DsImage.network(
      url,
      aspectRatio: 16 / 9,
      semanticLabel: slot.title,
      fallback: fallback,
      style: DsImageStyle(borderRadius: hovered ? BorderRadius.zero : null),
    );
  }

  /// The title bar: the room's title, then the exchange and clear
  /// buttons.
  Widget _bar(BuildContext context, DsColors colors, DsThemeData theme) {
    final t = context.t;
    return Container(
      height: 30,
      padding: const EdgeInsetsDirectional.only(start: DsSpace.s8, end: DsSpace.s3),
      decoration: DsBoxDecoration(shadows: [DsShadow.topLine(colors.border, hairline: true)]),
      child: Row(
        children: [
          Expanded(
            child: Text(
              slot.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.typography.caption.copyWith(color: colors.text),
            ),
          ),
          _PaneBarButton(
            icon: DsIcons.arrowLeftRight,
            semanticLabel: t.multiview.swapPane,
            active: swapSource == slot.index,
            onPressed: onSwapStart,
          ),
          _PaneBarButton(icon: DsIcons.x, semanticLabel: t.multiview.clearPane, dangerHover: true, onPressed: onClear),
        ],
      ),
    );
  }
}

/// One of the pane title bar's small buttons: the icon alone, a hover
/// fill around it.
final class _PaneBarButton extends StatelessWidget {
  const _PaneBarButton({
    required this.icon,
    required this.semanticLabel,
    required this.onPressed,
    this.active = false,
    this.dangerHover = false,
  });

  /// The icon shown.
  final DsIconData icon;

  /// The name screen readers hear.
  final String semanticLabel;

  final VoidCallback onPressed;

  /// Whether the button marks a state (a pending swap's source) and so
  /// stays strong when idle.
  final bool active;

  /// Whether hovering takes the danger tone (a destructive action).
  final bool dangerHover;

  @override
  Widget build(BuildContext context) {
    final colors = DsTheme.colorsOf(context);
    final theme = DsTheme.of(context);
    return DsPressable(
      semanticLabel: semanticLabel,
      onPressed: onPressed,
      builder: (context, states, _) {
        final hovered = states.contains(WidgetState.hovered);
        return Container(
          width: theme.sizes.md,
          height: theme.sizes.md,
          margin: const EdgeInsetsDirectional.only(start: DsSpace.s3),
          decoration: DsBoxDecoration(
            color: hovered ? colors.hover : null,
            borderRadius: theme.radii.controlCorners(null, theme.sizes.md),
          ),
          child: Center(
            child: DsIcon(
              icon,
              size: theme.sizes.iconSm,
              color: hovered && dangerHover
                  ? colors.danger.fill
                  : hovered || active
                  ? colors.text
                  : colors.textSubtle,
            ),
          ),
        );
      },
    );
  }
}

/// The pane picker: the followed rooms as list rows, each assigning its
/// room into the pane that asked; a room already on the wall is refused
/// with a word about where it plays; without follows, an honest empty
/// state.
final class _PanePickerDialog extends ConsumerWidget {
  const _PanePickerDialog({required this.slotIndex});

  /// The pane (0-based) the picked room lands in.
  final int slotIndex;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    final follows = ref.watch(followsProvider);
    final wall = ref.watch(multiviewProvider);
    final shown = <String, int>{};
    for (var index = 0; index < wall.slots.length; index++) {
      final key = wall.slots[index];
      if (key != null && index != slotIndex) shown[key] = index;
    }
    final Widget content;
    if (!follows.ready) {
      content = const Center(child: SizedBox(width: 24, height: 24, child: DsSpinner()));
    } else if (follows.rooms.isEmpty) {
      content = DsEmptyState(
        icon: const DsIcon(DsIcons.heart),
        title: Text(t.multiview.pickerEmptyTitle),
        description: Text(t.multiview.pickerEmptyHint),
      );
    } else {
      content = ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 380),
        child: SingleChildScrollView(
          child: DsListSection(
            children: [for (final room in follows.rooms) _row(context, ref, room, shown[room.ref.identityKey])],
          ),
        ),
      );
    }
    return DsDialog(
      title: Text(t.multiview.pickerTitle(index: slotIndex + 1)),
      description: content,
    );
  }

  /// One room as a picker row: the platform's letter tile, the room
  /// title, its anchor and platform, and — when it already plays — the
  /// pane it sits in.
  DsListRow _row(BuildContext context, WidgetRef ref, LiveRoom room, int? shownAt) {
    final t = context.t;
    return DsListRow(
      leading: _platformTile(context, room),
      title: Text(room.content.title, maxLines: 1, overflow: TextOverflow.ellipsis),
      description: Text(
        [
          if (room.anchor?.name case final name? when name.isNotEmpty) name else room.ref.roomId,
          _platformName(context, ref, room.ref.platform),
        ].join(' · '),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      detail: shownAt == null ? null : Text(t.multiview.shownIn(index: shownAt + 1)),
      onPressed: () {
        if (shownAt != null) {
          showDsToast(
            context: context,
            title: t.multiview.alreadyShown(index: shownAt + 1),
          );
          return;
        }
        unawaited(ref.read(multiviewProvider.notifier).assign(slotIndex, room));
        Navigator.of(context).pop();
      },
    );
  }

  /// The platform's letter tile (the picker's identity mark until
  /// platform logos arrive).
  Widget _platformTile(BuildContext context, LiveRoom room) {
    final colors = DsTheme.colorsOf(context);
    final theme = DsTheme.of(context);
    final platform = room.ref.platform;
    return Container(
      width: theme.sizes.lg,
      height: theme.sizes.lg,
      alignment: AlignmentDirectional.center,
      decoration: DsBoxDecoration(
        color: colors.accentTint,
        borderRadius: BorderRadius.circular(theme.radii.nested(theme.radii.card, DsSpace.s12)),
      ),
      child: Text(
        platform.isEmpty ? '?' : platform[0].toUpperCase(),
        style: theme.typography.body.copyWith(fontWeight: FontWeight.w700, color: colors.accentText),
      ),
    );
  }

  /// A platform id's display name, or the id itself when the registry
  /// does not know it.
  String _platformName(BuildContext context, WidgetRef ref, String platform) {
    final site = ref.read(sitesProvider).getById(platform);
    return site?.manifest.name['zh-CN'] ?? platform;
  }
}
