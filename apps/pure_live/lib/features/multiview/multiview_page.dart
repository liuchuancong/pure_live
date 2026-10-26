import 'dart:async' show unawaited;
import 'dart:math' as math;

import 'package:desen_ui/desen_ui.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_sites/live_sites.dart' show LivePlayQuality, LiveRoom, LiveRoomRefIdentity;
import 'package:media_core/media_core.dart' show MediaPlayerView;
import 'package:pure_live/app/app.dart';
import 'package:pure_live/features/favorites/favorites.dart';
import 'package:pure_live/features/history/history.dart';
import 'package:pure_live/features/multiview/multiview_controller.dart';
import 'package:pure_live/features/multiview/multiview_playback.dart';
import 'package:pure_live/features/settings/settings.dart';
import 'package:pure_live/l10n/translations.dart';
import 'package:pure_live/shared/shared.dart';

/// The multi-view wall (the reference's multiview): the 1×1, 1×2, 2×2 and
/// 1+3 arrangements, each pane holding a followed room, with the layout
/// switcher in the header and every pane picking, playing, selecting,
/// clearing or exchanging its room. The arrangement persists in the
/// multiview store, so a revisit opens the same wall.
///
/// Every assigned pane plays live through its own `LivePlaybackController`
/// and `MediaPlayerView`; the selected pane owns the sound, and leaving the
/// page releases every engine. A pane without a session yet shows its
/// room's cover. In the 1+3 arrangement the selected pane is the large one,
/// so choosing a small pane brings it forward and gives it the sound.
final class MultiviewPage extends ConsumerStatefulWidget {
  /// The multi-view page.
  const MultiviewPage({super.key});

  @override
  ConsumerState<MultiviewPage> createState() => _MultiviewPageState();
}

final class _MultiviewPageState extends ConsumerState<MultiviewPage> {
  /// The pane a pending swap starts from; null while none is pending.
  int? _swapSource;

  /// Whether the wall is the branch on screen; the branch keeps its widgets
  /// while another branch shows, so this — not disposal — ends playback.
  bool _visible = false;

  @override
  void dispose() {
    ref.read(multiviewPlaybackProvider.notifier).setActive(active: false);
    super.dispose();
  }

  /// Tells the playback owner whether the wall is on screen. The shell's
  /// branches stay mounted, so the selected destination (and a route's
  /// ticker mode) is what decides — never disposal alone.
  void _syncVisibility(bool visible) {
    if (visible == _visible) return;
    _visible = visible;
    // A provider write inside the build phase is rejected.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(multiviewPlaybackProvider.notifier).setActive(active: visible);
    });
  }

  @override
  Widget build(BuildContext context) {
    _syncVisibility(
      TickerMode.valuesOf(context).enabled && ref.watch(selectedNavItemProvider) == NavigationItem.multiview,
    );
    final wall = ref.watch(multiviewProvider);
    if (!wall.ready) {
      return const Center(child: AppLoadingIndicator(size: 24));
    }
    final rooms = ref.watch(followsProvider.select((state) => state.rooms));
    final playback = ref.watch(multiviewPlaybackProvider);
    final selected = playback.selected;
    final selectedPane = selected == null ? null : playback.panes[selected];
    final activePanes = [
      for (final pane in playback.panes.values)
        if (pane.stage == MultiviewPaneStage.playing) pane,
    ];
    final anyPlaying = activePanes.any((pane) => !pane.paused);
    final controls = ref.read(multiviewPlaybackProvider.notifier);
    final byIdentity = {for (final room in rooms) room.ref.identityKey: room};
    final slots = [
      for (var index = 0; index < wall.slots.length; index++)
        _slotOf(index, wall.slots[index], byIdentity[wall.slots[index]], playback.panes[index]?.room),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(DsSpace.s20, DsSpace.s12, DsSpace.s20, DsSpace.s8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: DsSpace.s8,
            children: [
              _header(wall, playback, activePanes: activePanes, anyPlaying: anyPlaying),
              if (selectedPane != null && selectedPane.stage == MultiviewPaneStage.playing)
                _PaneControls(
                  pane: selectedPane,
                  onPause: () => unawaited(controls.togglePause(selectedPane.slot)),
                  onQuality: (quality) => unawaited(_selectQuality(selectedPane.slot, quality)),
                  onLine: (index) => unawaited(controls.selectLine(selectedPane.slot, index)),
                  onVolume: (value) => unawaited(controls.setVolume(selectedPane.slot, value, commit: false)),
                  onVolumeCommit: (value) => unawaited(controls.setVolume(selectedPane.slot, value)),
                ),
            ],
          ),
        ),
        Expanded(child: _wall(wall, slots, playback)),
      ],
    );
  }

  /// The page's toolbar: the four arrangements, the sound on the wall, and —
  /// once a pane plays — mute-all and pause-all. A narrow window drops the
  /// words and lets the switches follow the arrangements on their own line.
  Widget _header(
    MultiviewState wall,
    MultiviewPlaybackState playback, {
    required List<MultiviewPanePlayback> activePanes,
    required bool anyPlaying,
  }) {
    final t = context.t;
    final colors = DsTheme.colorsOf(context);
    final theme = DsTheme.of(context);
    final controls = ref.read(multiviewPlaybackProvider.notifier);
    final selected = playback.selected;
    // The app-wide mute is a second reason the wall can be silent; the
    // button reflects either and clears both in one press.
    final globallyMuted = ref.watch(playbackSettingsProvider.select((settings) => settings.globalMute));
    final wallMuted = playback.allMuted || globallyMuted;
    final layout = DsSegmentedControl<MultiviewLayout>(
      segments: [
        for (final arrangement in MultiviewLayout.values)
          DsSegment(
            value: arrangement,
            label: Text(switch (arrangement) {
              MultiviewLayout.single => '1×1',
              MultiviewLayout.dual => '1×2',
              MultiviewLayout.quad => '2×2',
              MultiviewLayout.focus => '1+3',
            }),
          ),
      ],
      value: wall.layout,
      semanticLabel: t.multiview.layoutLabel,
      onChanged: (arrangement) {
        setState(() => _swapSource = null);
        unawaited(ref.read(multiviewProvider.notifier).setLayout(arrangement));
      },
    );
    final switches = [
      if (playback.panes.isNotEmpty)
        _ToolbarButton(
          icon: wallMuted ? DsIcons.volumeOff : DsIcons.volume,
          semanticLabel: wallMuted ? t.multiview.unmuteAll : t.multiview.muteAll,
          active: wallMuted,
          onPressed: () {
            if (playback.allMuted) controls.toggleMuteAll();
            if (globallyMuted) {
              unawaited(ref.read(playbackSettingsProvider.notifier).setGlobalMute(value: false));
            }
          },
        ),
      if (activePanes.isNotEmpty)
        _ToolbarButton(
          icon: anyPlaying ? DsIcons.pause : DsIcons.play,
          semanticLabel: anyPlaying ? t.multiview.pauseAll : t.multiview.resumeAll,
          active: !anyPlaying,
          onPressed: () => unawaited(controls.togglePauseAll()),
        ),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 560) {
          return Wrap(
            spacing: DsSpace.s8,
            runSpacing: DsSpace.s6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [layout, ...switches],
          );
        }
        return Row(
          spacing: DsSpace.s16,
          children: [
            layout,
            Expanded(
              child: Align(
                alignment: AlignmentDirectional.centerEnd,
                child: Text(
                  selected == null ? t.multiview.selectHint : t.multiview.selectedPane(index: selected + 1),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.typography.small.copyWith(color: colors.textSubtle),
                ),
              ),
            ),
            ...switches,
          ],
        );
      },
    );
  }

  /// Switches the selected pane's quality; a failure keeps the stream it
  /// plays and says so.
  Future<void> _selectQuality(int slot, LivePlayQuality quality) async {
    final opened = await ref.read(multiviewPlaybackProvider.notifier).selectQuality(slot, quality);
    if (opened || !mounted) return;
    showDsToast(context: context, title: context.t.multiview.qualityFailed);
  }

  /// One pane's data: its place in the wall, the identity it holds and the
  /// room that identity resolves to.
  _Slot _slotOf(int index, String? key, LiveRoom? followed, LiveRoom? played) {
    final room = followed ?? played;
    return (index: index, key: key, room: room, title: _slotTitle(key, room));
  }

  /// The wall: the layout's grid of panes, each an equal share of the
  /// body's width and height; the 1+3 arrangement instead gives its
  /// selected pane the large place and the other three a rail.
  Widget _wall(MultiviewState wall, List<_Slot> slots, MultiviewPlaybackState playback) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(DsSpace.s20, DsSpace.s4, DsSpace.s20, DsSpace.s20),
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Tight windows tighten the gaps before the panes give up
          // anything else.
          final gap = constraints.maxWidth < 560 ? DsSpace.s4 : DsSpace.s8;
          if (wall.layout == MultiviewLayout.focus) {
            return _focusWall(slots, playback, gap, constraints);
          }
          final (columns, rows) = _gridOf(wall.layout);
          return Column(
            spacing: gap,
            children: [
              for (var row = 0; row < rows; row++)
                Expanded(
                  child: Row(
                    spacing: gap,
                    children: [
                      for (var column = 0; column < columns; column++)
                        Expanded(child: _pane(slots, playback, row * columns + column)),
                    ],
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  /// The 1+3 wall: the selected pane large, the other three in a rail
  /// beside it (or below it when that leaves the large pane more room).
  /// A tap on a small pane selects it, so it moves into the large place.
  Widget _focusWall(List<_Slot> slots, MultiviewPlaybackState playback, double gap, BoxConstraints constraints) {
    final largeAt = _largeSlot(slots, playback);
    final smalls = [
      for (final slot in slots)
        if (slot.index != largeAt) slot.index,
    ];
    final side = _focusSideRail(constraints, gap);
    final large = Expanded(flex: 3, child: _pane(slots, playback, largeAt));
    final rail = Expanded(
      child: side
          ? Column(
              spacing: gap,
              children: [for (final at in smalls) Expanded(child: _pane(slots, playback, at, compact: true))],
            )
          : Row(
              spacing: gap,
              children: [for (final at in smalls) Expanded(child: _pane(slots, playback, at, compact: true))],
            ),
    );
    return side ? Row(spacing: gap, children: [large, rail]) : Column(spacing: gap, children: [large, rail]);
  }

  /// The pane that fills the large place: the audible one while it holds a
  /// room, the first assigned one otherwise, and slot 0 for an empty wall.
  int _largeSlot(List<_Slot> slots, MultiviewPlaybackState playback) {
    final selected = playback.selected;
    if (selected != null && selected >= 0 && selected < slots.length && slots[selected].key != null) {
      return selected;
    }
    for (final slot in slots) {
      if (slot.key != null) return slot.index;
    }
    return 0;
  }

  /// Whether the small panes sit beside the large one: whichever of the
  /// rail and the bottom row lets the large pane be wider (the
  /// reference's `WallGeometry.focus`).
  static bool _focusSideRail(BoxConstraints constraints, double gap) {
    final width = constraints.maxWidth;
    final height = constraints.maxHeight;
    if (!width.isFinite || !height.isFinite) return true;
    // Below: w is a small pane's width.
    final belowByWidth = (width - gap * 2) / 3;
    final belowByHeight = ((height - gap) * 16 / 9 - gap * 2) / 4;
    final below = math.max(0, math.min(belowByWidth, belowByHeight));
    final belowLarge = below * 3 + gap * 2;
    // Beside: s is a small pane's height.
    final besideByWidth = ((width - gap) * 9 / 16 - gap * 2) / 4;
    final besideByHeight = (height - gap * 2) / 3;
    final beside = math.max(0, math.min(besideByWidth, besideByHeight));
    final besideLarge = (beside * 3 + gap * 2) * 16 / 9;
    return besideLarge > belowLarge;
  }

  /// The (columns, rows) a layout's pane count fills (the 1+3 arrangement
  /// lays itself out and never asks).
  static (int, int) _gridOf(MultiviewLayout layout) => switch (layout) {
    MultiviewLayout.single => (1, 1),
    MultiviewLayout.dual => (2, 1),
    MultiviewLayout.quad || MultiviewLayout.focus => (2, 2),
  };

  /// One pane of the wall, wired to the page's handlers; [compact] leaves
  /// the controls off a small pane of the 1+3 arrangement (selecting it
  /// brings it large, with its controls).
  Widget _pane(List<_Slot> slots, MultiviewPlaybackState playback, int at, {bool compact = false}) {
    final slot = slots[at];
    return _PaneTile(
      fit: ref.watch(playbackSettingsProvider).fit.boxFit,
      slot: slot,
      playback: playback.panes[slot.index],
      selected: playback.selected == slot.index,
      compact: compact,
      swapSource: _swapSource,
      onPick: () => unawaited(_pickForSlot(slot.index)),
      onSelect: () => ref.read(multiviewPlaybackProvider.notifier).select(slot.index),
      onOpen: () => unawaited(_openSlot(slot.key, slot.room)),
      onRetry: () => unawaited(ref.read(multiviewPlaybackProvider.notifier).retry(slot.index)),
      onClear: () => _clearSlot(slot.index),
      onSwapStart: () => setState(() => _swapSource = slot.index),
      onSwapWith: () => _handleSwapTap(slot.index),
    );
  }

  /// The (columns, rows) a layout's pane count fills.
  /// The pane's title: the room's own title, or the identity a pane holds
  /// whose room left the follows (the pane keeps its place until cleared).
  String _slotTitle(String? key, LiveRoom? room) {
    if (room != null) return room.content.title;
    if (key == null) return '';
    final at = key.indexOf(':');
    final platform = at < 0 ? key : key.substring(0, at);
    final roomId = at < 0 ? '' : key.substring(at + 1);
    final site = ref.read(sitesProvider).getById(platform);
    return '${site == null ? platform : localizedSiteName(site)} · $roomId';
  }

  /// Opens the room a pane holds above the shell. The wall's engines are
  /// released first (the room page plays the sound now) and start again when
  /// the room closes back onto this page.
  Future<void> _openSlot(String? key, LiveRoom? room) async {
    if (key == null) return;
    final at = key.indexOf(':');
    if (at < 0) return;
    final platform = room?.ref.platform ?? key.substring(0, at);
    final roomId = room?.ref.roomId ?? key.substring(at + 1);
    final playback = ref.read(multiviewPlaybackProvider.notifier)..setActive(active: false);
    await openRoom(context, platform: platform, roomId: roomId);
    if (!mounted) return;
    playback.setActive(active: TickerMode.valuesOf(context).enabled);
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

  /// The pane picker over the wall: the followed and recently watched
  /// rooms, each row assigning into the pane that asked.
  Future<void> _pickForSlot(int index) {
    return showDsDialog<void>(
      context: context,
      builder: (context) => _PanePickerDialog(slotIndex: index),
    );
  }
}

/// One pane's place in the wall: the slot, the identity it holds (null for
/// an empty pane), the room that identity resolves to, and its title.
typedef _Slot = ({int index, String? key, LiveRoom? room, String title});

/// One pane of the wall: an assigned one plays its room, shows its title,
/// and offers the enter, exchange and clear buttons; an empty one offers the
/// pane picker. A [compact] pane (a small one of the 1+3 arrangement) keeps
/// its title over the picture and leaves the buttons to its large place.
/// While a swap is pending ([swapSource]), every pane joins in — the source
/// rings and each tap elsewhere exchanges.
final class _PaneTile extends StatelessWidget {
  const _PaneTile({
    required this.fit,
    required this.slot,
    required this.playback,
    required this.selected,
    required this.compact,
    required this.swapSource,
    required this.onPick,
    required this.onSelect,
    required this.onOpen,
    required this.onRetry,
    required this.onClear,
    required this.onSwapStart,
    required this.onSwapWith,
  });

  /// The picture's fit, the viewer's shared 画面比例 setting (KER-02).
  final BoxFit fit;

  /// The pane's data: its place in the wall, the identity it holds and
  /// the room that identity resolves to.
  final _Slot slot;

  /// The pane's playback, null before a session exists (or while empty).
  final MultiviewPanePlayback? playback;

  /// Whether this pane owns the sound.
  final bool selected;

  /// Whether the pane is a small one without a title bar of its own.
  final bool compact;

  /// The pane a pending swap starts from, null while none is pending.
  final int? swapSource;

  final VoidCallback onPick;
  final VoidCallback onSelect;
  final VoidCallback onOpen;
  final VoidCallback onRetry;
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
          ? onSelect
          : onPick,
      builder: (context, states, _) {
        final hovered = states.contains(WidgetState.hovered);
        final ring = isSource
            ? colors.channel
            : selected && assigned
            ? colors.accent
            : colors.border;
        return Container(
          clipBehavior: Clip.antiAlias,
          decoration: DsBoxDecoration(
            color: colors.control,
            borderRadius: BorderRadius.circular(theme.radii.card),
            shadows: [DsShadow.innerRing(ring, width: isSource || selected ? 2 : 1)],
          ),
          child: assigned
              ? compact
                    ? Stack(
                        fit: StackFit.expand,
                        children: [
                          _picture(context, colors, theme, hovered),
                          PositionedDirectional(start: 0, end: 0, bottom: 0, child: _compactCaption(theme)),
                        ],
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(child: _picture(context, colors, theme, hovered)),
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

  /// The pane's picture: the live stream once an engine is attached, the
  /// room's cover while it opens or after a failure; a paused pane dims and
  /// says so, and a quality switch spins over the old picture while the new
  /// lines resolve.
  Widget _picture(BuildContext context, DsColors colors, DsThemeData theme, bool hovered) {
    final handle = playback?.handle;
    return Stack(
      fit: StackFit.expand,
      children: [
        if (handle != null)
          IgnorePointer(
            child: MediaPlayerView(
              handle: handle,
              fit: fit,
              backgroundColor: colors.overlay,
              // A wall of players pays for no capture boundary it never uses.
              captureBoundary: false,
            ),
          )
        else ...[
          _cover(colors, theme, hovered),
          if (playback?.stage == MultiviewPaneStage.opening) const Center(child: AppLoadingIndicator(size: 22)),
          if (playback?.stage == MultiviewPaneStage.failed) _failure(context, colors, theme),
        ],
        if (handle != null && playback?.switching == true)
          const Positioned.fill(
            child: IgnorePointer(child: Center(child: AppLoadingIndicator(size: 22))),
          ),
        if (handle != null && playback?.paused == true) _pausedBadge(context, theme),
      ],
    );
  }

  /// A paused pane: the picture dims under a small "paused" badge, as the
  /// reference's cells do.
  Widget _pausedBadge(BuildContext context, DsThemeData theme) {
    final t = context.t;
    return Positioned.fill(
      child: IgnorePointer(
        child: ColoredBox(
          color: const Color(0x66000000),
          child: Center(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Container(
                height: 26,
                padding: const EdgeInsetsDirectional.only(start: DsSpace.s8, end: DsSpace.s12),
                decoration: BoxDecoration(color: const Color(0xB3000000), borderRadius: BorderRadius.circular(13)),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  spacing: DsSpace.s6,
                  children: [
                    const DsIcon(DsIcons.pause, size: 14, color: Color(0xFFFFFFFF)),
                    Text(
                      t.multiview.panePaused,
                      style: theme.typography.caption.copyWith(color: const Color(0xFFFFFFFF)),
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
    return DsImage(
      image: cachedImage(url),
      aspectRatio: 16 / 9,
      semanticLabel: slot.title,
      fallback: fallback,
      style: DsImageStyle(borderRadius: hovered ? BorderRadius.zero : null),
    );
  }

  /// Why the pane is not playing, with a way to try again; the site's own
  /// words ride in the tooltip, the pane keeps its room.
  Widget _failure(BuildContext context, DsColors colors, DsThemeData theme) {
    final t = context.t;
    return Positioned.fill(
      child: DsTooltip(
        message: playback?.error ?? t.multiview.paneFailed,
        child: ColoredBox(
          color: const Color(0xB3000000),
          // A small pane may be shorter than the words and the button;
          // scaling down keeps them whole.
          child: Center(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Padding(
                padding: const EdgeInsets.all(DsSpace.s8),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  spacing: DsSpace.s6,
                  children: [
                    Text(
                      t.multiview.paneFailed,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: theme.typography.caption.copyWith(color: colors.text),
                    ),
                    DsButton(
                      size: DsSize.sm,
                      semanticLabel: t.multiview.retryPane,
                      onPressed: onRetry,
                      child: Text(t.common.retry),
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

  /// A small pane's title over the picture: one line on a scrim, with the
  /// sound mark when it plays aloud. The scrim keeps the words readable on
  /// any cover or stream.
  Widget _compactCaption(DsThemeData theme) {
    return Container(
      height: 26,
      padding: const EdgeInsetsDirectional.only(start: DsSpace.s6, end: DsSpace.s8),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0x00000000), Color(0xB3000000)],
        ),
      ),
      child: Row(
        children: [
          if (playback?.audible ?? false)
            const Padding(
              padding: EdgeInsetsDirectional.only(end: DsSpace.s4),
              child: DsIcon(DsIcons.volume, size: 11, color: Color(0xFFFFFFFF)),
            ),
          Expanded(
            child: Text(
              slot.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.typography.caption.copyWith(fontWeight: FontWeight.w600, color: const Color(0xFFFFFFFF)),
            ),
          ),
        ],
      ),
    );
  }

  /// The title bar: the room's title, then the enter, exchange and clear
  /// buttons.
  Widget _bar(BuildContext context, DsColors colors, DsThemeData theme) {
    final t = context.t;
    return Container(
      height: 30,
      padding: const EdgeInsetsDirectional.only(start: DsSpace.s8, end: DsSpace.s3),
      decoration: DsBoxDecoration(shadows: [DsShadow.topLine(colors.border, hairline: true)]),
      child: Row(
        children: [
          if (playback?.audible ?? false)
            Padding(
              padding: const EdgeInsetsDirectional.only(end: DsSpace.s4),
              child: DsIcon(DsIcons.volume, size: 12, color: colors.accent),
            ),
          Expanded(
            child: Text(
              slot.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.typography.caption.copyWith(color: colors.text),
            ),
          ),
          _PaneBarButton(icon: DsIcons.externalLink, semanticLabel: t.multiview.openRoom, onPressed: onOpen),
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

/// A toolbar switch: an icon alone in the header, filled while its state is
/// on (mute-all, pause-all), with the words in a tooltip.
final class _ToolbarButton extends StatelessWidget {
  const _ToolbarButton({required this.icon, required this.semanticLabel, required this.onPressed, this.active = false});

  /// The icon shown.
  final DsIconData icon;

  /// The name screen readers hear and the pointer reads on hover.
  final String semanticLabel;

  final VoidCallback? onPressed;

  /// Whether the switch's state is on and so filled.
  final bool active;

  @override
  Widget build(BuildContext context) {
    final colors = DsTheme.colorsOf(context);
    final theme = DsTheme.of(context);
    return DsTooltip(
      message: semanticLabel,
      excludeFromSemantics: true,
      child: DsPressable(
        semanticLabel: semanticLabel,
        onPressed: onPressed,
        selected: active,
        builder: (context, states, _) {
          final hovered = states.contains(WidgetState.hovered);
          return Container(
            width: theme.sizes.sm,
            height: theme.sizes.sm,
            decoration: DsBoxDecoration(
              color: active
                  ? colors.accentTint
                  : hovered
                  ? colors.hover
                  : null,
              borderRadius: theme.radii.controlCorners(null, theme.sizes.sm),
            ),
            child: Center(
              child: DsIcon(icon, size: theme.sizes.iconSm, color: active ? colors.accentText : colors.textMuted),
            ),
          );
        },
      ),
    );
  }
}

/// The selected pane's controls, under the toolbar: pause, quality, line and
/// volume. A pane's own settings are reached by selecting it — the audible
/// pane is the one the wall controls, as the reference's cell column does.
final class _PaneControls extends StatelessWidget {
  const _PaneControls({
    required this.pane,
    required this.onPause,
    required this.onQuality,
    required this.onLine,
    required this.onVolume,
    required this.onVolumeCommit,
  });

  final MultiviewPanePlayback pane;
  final VoidCallback onPause;
  final ValueChanged<LivePlayQuality> onQuality;
  final ValueChanged<int> onLine;

  /// Moves the slider while it drags.
  final ValueChanged<double> onVolume;

  /// Lands the slider's value when the finger lifts.
  final ValueChanged<double> onVolumeCommit;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final colors = DsTheme.colorsOf(context);
    final theme = DsTheme.of(context);
    final line = pane.lines.isEmpty ? null : pane.lines[pane.lineIndex.clamp(0, pane.lines.length - 1)];
    return Row(
      spacing: DsSpace.s8,
      children: [
        _ToolbarButton(
          icon: pane.paused ? DsIcons.play : DsIcons.pause,
          semanticLabel: pane.paused ? t.multiview.playPane : t.multiview.pausePane,
          onPressed: onPause,
        ),
        _StreamChip(
          icon: DsIcons.gauge,
          label: pane.quality?.label ?? t.multiview.paneQuality,
          semanticLabel: t.multiview.paneQuality,
          enabled: !pane.switching && pane.qualities.isNotEmpty,
          items: [
            for (final quality in pane.qualities)
              DsMenuItem(
                label: Text(quality.label),
                checked: quality == pane.quality,
                onPressed: () => onQuality(quality),
              ),
          ],
        ),
        if (pane.lines.length > 1)
          _StreamChip(
            icon: DsIcons.route,
            label: line?.lineLabel ?? t.room.line(n: pane.lineIndex + 1),
            semanticLabel: t.room.lineLabel,
            enabled: !pane.switching,
            items: [
              for (final (index, option) in pane.lines.indexed)
                DsMenuItem(
                  label: Text(option.lineLabel ?? t.room.line(n: index + 1)),
                  checked: index == pane.lineIndex,
                  onPressed: () => onLine(index),
                ),
            ],
          ),
        const SizedBox(width: DsSpace.s4),
        DsTooltip(
          message: t.room.volume,
          excludeFromSemantics: true,
          child: DsIcon(DsIcons.volume, size: theme.sizes.iconSm, color: colors.textMuted),
        ),
        Expanded(
          child: _PaneVolume(
            value: pane.volume,
            semanticLabel: t.room.volume,
            onChanged: onVolume,
            onCommitted: onVolumeCommit,
          ),
        ),
      ],
    );
  }
}

/// A compact menu over one of the pane's stream dimensions: its current
/// choice, a chevron and the catalogue in a menu; disabled while the pane
/// switches quality.
final class _StreamChip extends StatelessWidget {
  const _StreamChip({
    required this.icon,
    required this.label,
    required this.semanticLabel,
    required this.items,
    this.enabled = true,
  });

  final DsIconData icon;
  final String label;
  final String semanticLabel;
  final List<Widget> items;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final colors = DsTheme.colorsOf(context);
    final theme = DsTheme.of(context);
    Widget chip({required bool hovered}) => ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 180),
      child: Container(
        height: theme.sizes.sm,
        padding: const EdgeInsets.symmetric(horizontal: DsSpace.s8),
        decoration: DsBoxDecoration(
          color: hovered ? colors.hover : null,
          borderRadius: theme.radii.controlCorners(null, theme.sizes.sm),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          spacing: DsSpace.s4,
          children: [
            DsIcon(icon, size: theme.sizes.iconSm, color: enabled ? colors.textMuted : colors.textSubtle),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.typography.caption.copyWith(color: enabled ? colors.text : colors.textSubtle),
              ),
            ),
            if (enabled) DsIcon(DsIcons.chevronDown, size: 12, color: colors.textMuted),
          ],
        ),
      ),
    );
    if (!enabled) return chip(hovered: false);
    return DsMenuAnchor(
      semanticLabel: semanticLabel,
      items: items,
      builder: (context, controller, _) => DsPressable(
        semanticLabel: semanticLabel,
        onPressed: controller.toggle,
        builder: (context, states, _) => chip(hovered: states.contains(WidgetState.hovered)),
      ),
    );
  }
}

/// The selected pane's volume: the slider follows the finger; the engine is
/// told every step, the wall rebuilds only when the finger lifts.
final class _PaneVolume extends StatefulWidget {
  const _PaneVolume({
    required this.value,
    required this.semanticLabel,
    required this.onChanged,
    required this.onCommitted,
  });

  final double value;
  final String semanticLabel;
  final ValueChanged<double> onChanged;
  final ValueChanged<double> onCommitted;

  @override
  State<_PaneVolume> createState() => _PaneVolumeState();
}

final class _PaneVolumeState extends State<_PaneVolume> {
  double? _dragging;

  @override
  Widget build(BuildContext context) {
    final value = (_dragging ?? widget.value).clamp(0.0, 1.0);
    return DsSlider(
      value: value,
      semanticLabel: widget.semanticLabel,
      onChanged: (next) {
        setState(() => _dragging = next);
        widget.onChanged(next);
      },
      onChangeEnd: (next) {
        setState(() => _dragging = null);
        widget.onCommitted(next);
      },
    );
  }
}

/// The pane picker: the followed and watched rooms as list rows, each
/// assigning its room into the pane that asked; a room already on the wall
/// is refused with a word about where it plays. A search field narrows the
/// list by title, streamer, room id or platform.
final class _PanePickerDialog extends ConsumerStatefulWidget {
  const _PanePickerDialog({required this.slotIndex});

  /// The pane (0-based) the picked room lands in.
  final int slotIndex;

  @override
  ConsumerState<_PanePickerDialog> createState() => _PanePickerDialogState();
}

final class _PanePickerDialogState extends ConsumerState<_PanePickerDialog> {
  /// The filter's current words.
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final follows = ref.watch(followsProvider);
    final history = ref.watch(historyProvider);
    final wall = ref.watch(multiviewProvider);
    final shown = <String, int>{};
    for (var index = 0; index < wall.slots.length; index++) {
      final key = wall.slots[index];
      if (key != null && index != widget.slotIndex) shown[key] = index;
    }
    // The reference's picker: follows first, then the rooms already
    // watched — one row per identity, no duplicates.
    final rooms = <LiveRoom>[];
    final seen = <String>{};
    for (final room in follows.rooms) {
      if (seen.add(room.ref.identityKey)) rooms.add(room);
    }
    for (final (room, _) in history.records) {
      if (seen.add(room.ref.identityKey)) rooms.add(room);
    }
    final needle = _query.trim().toLowerCase();
    final visible = needle.isEmpty
        ? rooms
        : [
            for (final room in rooms)
              if (_matches(room, needle)) room,
          ];
    final Widget content;
    if (!follows.ready || !history.ready) {
      content = const Center(child: AppLoadingIndicator(size: 24));
    } else if (rooms.isEmpty) {
      content = DsEmptyState(
        icon: const DsIcon(DsIcons.heart),
        title: Text(t.multiview.pickerEmptyTitle),
        description: Text(t.multiview.pickerEmptyHint),
      );
    } else {
      content = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: DsSpace.s8,
        children: [
          DsSearchField(
            autofocus: true,
            placeholder: t.multiview.pickerSearch,
            semanticLabel: t.multiview.pickerSearch,
            onChanged: (value) => setState(() => _query = value),
          ),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 340),
            child: visible.isEmpty
                ? DsEmptyState(icon: const DsIcon(DsIcons.searchX), title: Text(t.multiview.pickerNoMatch))
                : SingleChildScrollView(
                    child: DsListSection(
                      children: [for (final room in visible) _row(context, ref, room, shown[room.ref.identityKey])],
                    ),
                  ),
          ),
        ],
      );
    }
    return DsDialog(
      title: Text(t.multiview.pickerTitle(index: widget.slotIndex + 1)),
      description: content,
    );
  }

  /// Whether [room] matches the picker's [needle] in any of its names.
  bool _matches(LiveRoom room, String needle) {
    final platform = _platformName(context, ref, room.ref.platform).toLowerCase();
    return room.content.title.toLowerCase().contains(needle) ||
        (room.anchor?.name ?? '').toLowerCase().contains(needle) ||
        room.ref.roomId.toLowerCase().contains(needle) ||
        room.ref.platform.toLowerCase().contains(needle) ||
        platform.contains(needle);
  }

  /// One room as a picker row: the platform's letter tile, the room
  /// title, its anchor and platform, and — when it already plays — the
  /// pane it sits in.
  DsListRow _row(BuildContext context, WidgetRef ref, LiveRoom room, int? shownAt) {
    final t = context.t;
    return DsListRow(
      leading: _platformTile(context, ref, room),
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
        unawaited(ref.read(multiviewProvider.notifier).assign(widget.slotIndex, room));
        Navigator.of(context).pop();
      },
    );
  }

  /// The platform's letter tile (the picker's identity mark until
  /// platform logos arrive).
  Widget _platformTile(BuildContext context, WidgetRef ref, LiveRoom room) {
    final colors = DsTheme.colorsOf(context);
    final theme = DsTheme.of(context);
    final platform = room.ref.platform;
    final site = ref.read(sitesProvider).getById(platform);
    final icon = localizedSiteIcon(site, size: theme.sizes.lg);
    if (icon != null) return icon;
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
    return site == null ? platform : localizedSiteName(site);
  }
}
