import 'dart:async' show unawaited;
import 'dart:math' as math;

import 'package:desen_ui/desen_ui.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:live_cache/live_cache.dart' show ImageCachePolicies;
import 'package:live_sites/live_sites.dart' show LivePlayQuality, LiveRoom, LiveRoomRefIdentity;
import 'package:media_core/media_core.dart' show MediaPlayerView;
import 'package:pure_live/app/app.dart';
import 'package:pure_live/features/settings/settings.dart';
import 'package:pure_live/l10n/translations.dart';
import 'package:pure_live/layouts/page_head_actions.dart';
import 'package:pure_live/layouts/page_layout_scope.dart';
import 'package:pure_live/layouts/tv/tv_input_field.dart' show TvInputField;
import 'package:pure_live/modules/live/favorites/favorites.dart';
import 'package:pure_live/modules/live/history/history.dart';
import 'package:pure_live/modules/live/multiview/multiview_controller.dart';
import 'package:pure_live/modules/live/multiview/multiview_playback.dart';
import 'package:pure_live/modules/live/multiview/multiview_search_handoff.dart';
import 'package:pure_live/modules/live/search/room_search_picker.dart' show showRoomSearchPicker;
import 'package:pure_live/shared/shared.dart';

/// The multi-view wall (the reference's multiview): the 1×1, 1×2, 2×2,
/// 1+3 and 1×4 arrangements, each pane holding a followed room, with the layout
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

  /// The cell the picker dock is choosing for, or null while the dock is
  /// closed.
  int? _pickingSlot;

  /// Whether the first ready wall has been looked at once; the dock opens
  /// on arrival, not on every rebuild.
  bool _dockConsidered = false;

  /// Captured while the page is alive; `ref` is refused by the time dispose
  /// runs, and leaving must still tell the playback owner the wall is gone.
  late final MultiviewPlaybackController _playbackNotifier;

  /// The phone's view of the wall, registered for as long as the page is:
  /// the verbs the selected (audible) pane honestly serves.
  late final RemotePlaybackTarget _remoteTarget;

  @override
  void initState() {
    super.initState();
    _playbackNotifier = ref.read(multiviewPlaybackProvider.notifier);
    ref.listenManual(multiviewPlaybackProvider.select((state) => state.pendingRestore), (previous, next) {
      if (next && previous != true) unawaited(_askRestore());
    });
    // The toolbar's word opens the room search picker over the wall: the
    // room found there lands in the current cell. The listener catches a
    // word handed while the page is showing; the post-frame take catches
    // one handed as the page arrives.
    ref.listenManual(multiviewSearchHandoffProvider, (_, _) => _takeHandoff());
    WidgetsBinding.instance.addPostFrameCallback((_) => _takeHandoff());
    // The closures read the provider at call time, so a pane switch inside
    // the page cannot answer with the pane that was audible before.
    _remoteTarget = RemotePlaybackTarget(
      available: () => mounted && (ModalRoute.isCurrentOf(context) ?? true),
      scope: () => 'multiview',
      snapshot: () {
        final playback = ref.read(multiviewPlaybackProvider);
        final selected = playback.selected;
        final pane = selected == null ? null : playback.panes[selected];
        if (pane == null) return const {'scope': 'multiview', 'commands': <String>[]};
        return {
          'nick': pane.room?.anchor?.name ?? '',
          'title': pane.room?.content.title ?? '',
          'paused': pane.paused,
          'volume': pane.volume,
          'commands': ['play', 'pause', 'refresh', 'volume', 'mute', 'previous', 'next', 'up', 'down'],
        };
      },
      execute: (command, value) async {
        if (!mounted) return false;
        final playback = ref.read(multiviewPlaybackProvider);
        final controller = ref.read(multiviewPlaybackProvider.notifier);
        final selected = playback.selected;
        if (selected == null) return false;
        switch (command) {
          case 'play':
            if (playback.panes[selected]?.paused ?? false) await controller.togglePause(selected);
            return true;
          case 'pause':
            if (!(playback.panes[selected]?.paused ?? true)) await controller.togglePause(selected);
            return true;
          case 'refresh':
            await controller.retry(selected);
            return true;
          case 'volume':
            if (value == null) return false;
            await controller.setVolume(selected, value);
            return true;
          case 'mute':
            controller.toggleMuteAll();
            return true;
          case 'previous':
          case 'up':
            _stepSelection(-1);
            return true;
          case 'next':
          case 'down':
            _stepSelection(1);
            return true;
        }
        return false;
      },
    );
    playbackRemote.register(_remoteTarget);
  }

  /// Walks the audible pane across the wall's assigned panes, wrapping at
  /// the ends; the phone's previous and next are the tap a finger cannot
  /// make on a wall that far away.
  void _stepSelection(int step) {
    final playback = ref.read(multiviewPlaybackProvider);
    final slots = playback.panes.keys.toList()..sort();
    if (slots.isEmpty) return;
    final at = playback.selected == null ? -step : slots.indexOf(playback.selected!);
    ref.read(multiviewPlaybackProvider.notifier).select(slots[(at + step + slots.length) % slots.length]);
  }

  /// The saved wall's ask on arrival: open what it kept, or start blank.
  Future<void> _askRestore() async {
    final t = context.t;
    final wall = ref.read(multiviewProvider);
    final count = wall.slots.where((slot) => slot != null).length;
    final accepted = await showDsConfirm(
      context: context,
      title: t.multiview.restoreAskTitle,
      description: t.multiview.restoreAskBody(count: count),
      confirmLabel: t.multiview.restoreAccept,
      cancelLabel: t.multiview.restoreDecline,
    );
    if (!mounted) return;
    if (accepted) {
      ref.read(multiviewPlaybackProvider.notifier).acceptRestoreWall();
    } else {
      await ref.read(multiviewPlaybackProvider.notifier).declineRestoreWall();
    }
  }

  void _takeHandoff() {
    final word = ref.read(multiviewSearchHandoffProvider.notifier).take();
    if (word == null || word.isEmpty || !mounted) return;
    unawaited(
      showRoomSearchPicker(context, query: word, title: context.t.multiview.searchHint, onPick: _assignFromSearch),
    );
  }

  /// Puts the picked room in the current cell: the one the dock is open
  /// for, else the selected (audible) pane, else the first empty cell,
  /// else the first.
  Future<void> _assignFromSearch(LiveRoom room) async {
    final slots = ref.read(multiviewProvider).slots;
    final selected = ref.read(multiviewPlaybackProvider).selected;
    var target = _pickingSlot ?? ((selected != null && selected >= 0 && selected < slots.length) ? selected : null);
    target ??= slots.indexWhere((slot) => slot == null);
    if (target < 0) target = 0;
    await ref.read(multiviewProvider.notifier).assign(target, room);
  }

  @override
  void dispose() {
    playbackRemote.unregister(_remoteTarget);
    _playbackNotifier.setActive(active: false);
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
    final t = context.t;
    _syncVisibility(
      TickerMode.valuesOf(context).enabled && ref.watch(selectedNavItemProvider) == NavigationItem.multiview,
    );
    final wall = ref.watch(multiviewProvider);
    if (wall.ready) _openDockForFirstEmptyCell(wall);
    if (!wall.ready) {
      // An open that failed is not an open still running: the page
      // names what went wrong and offers the retry the spinner never
      // could.
      if (wall.error case final error?) {
        return Center(
          child: DsEmptyState(
            icon: const DsIcon(DsIcons.cloudOff),
            title: Text(t.multiview.wallFailed),
            description: Text(error),
            actions: [
              DsButton(onPressed: () => ref.invalidate(multiviewRepositoryProvider), child: Text(t.common.retry)),
            ],
          ),
        );
      }
      return const Center(child: DsSpinner(style: DsSpinnerStyle(size: 24)));
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
    // The toolbar's focus pill names the pane that owns the sound; a
    // selection without a place in the wall (a layout just shrunk) shows
    // nothing rather than a stale name.
    final audibleName = selected == null || selected < 0 || selected >= slots.length ? null : slots[selected].title;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(DsSpace.s20, DsSpace.s12, DsSpace.s20, DsSpace.s8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: DsSpace.s8,
            children: [
              _header(wall, playback, activePanes: activePanes, anyPlaying: anyPlaying, audibleName: audibleName),
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
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final picking = _pickingSlot;
              if (picking == null || picking >= slots.length) {
                return _wall(wall, slots, playback);
              }
              final dock = _PanePickerDock(
                slotIndex: picking,
                onAssign: (room) => unawaited(_assign(picking, room)),
                onClose: () => setState(() => _pickingSlot = null),
              );
              // A wide window docks the picker beside the wall so the
              // cell it fills stays in sight; a narrow one is already
              // stacked, so the picker goes under it.
              if (constraints.maxWidth >= 760) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(child: _wall(wall, slots, playback)),
                    SizedBox(width: 340, child: dock),
                  ],
                );
              }
              return Column(
                children: [
                  Expanded(child: _wall(wall, slots, playback)),
                  SizedBox(height: 300, child: dock),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  /// The page's toolbar: the arrangements, the pill naming the pane that
  /// owns the sound, and — once a pane plays — mute-all and pause-all, with
  /// the danmaku hint and the add action at the row's right end. A narrow
  /// window folds everything into the shell's head-line more menu.
  Widget _header(
    MultiviewState wall,
    MultiviewPlaybackState playback, {
    required List<MultiviewPanePlayback> activePanes,
    required bool anyPlaying,
    required String? audibleName,
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
          DsSegment(value: arrangement, label: Text(_arrangementLabel(arrangement))),
      ],
      value: wall.layout,
      semanticLabel: t.multiview.layoutLabel,
      onChanged: (arrangement) {
        setState(() => _swapSource = null);
        unawaited(ref.read(multiviewProvider.notifier).setLayout(arrangement));
      },
    );
    // The focus pill names the pane that owns the sound and opens the dock
    // on it, so replacing what plays there moves the sound with the pane.
    final audibleFocus = selected == null || audibleName == null || audibleName.isEmpty
        ? null
        : _AudibleFocusButton(
            name: audibleName,
            semanticLabel: t.multiview.audibleFocus,
            onPressed: () => _pickForSlot(selected),
          );
    final addRoom = DsButton(
      variant: DsButtonVariant.primary,
      size: DsSize.sm,
      semanticLabel: t.multiview.addRoom,
      leading: const DsIcon(DsIcons.plus, size: 14),
      onPressed: _addRoom,
      child: Text(t.multiview.addRoom),
    );
    final switches = [
      if (playback.panes.isNotEmpty)
        _ToolbarButton(
          iconAsset: wallMuted ? 'assets/icons/volume-muted.svg' : 'assets/icons/volume.svg',
          semanticLabel: wallMuted ? t.multiview.unmuteAll : t.multiview.muteAll,
          active: wallMuted,
          onPressed: () {
            // The global switch outranks the wall's own: while it mutes, the
            // fix is clearing it, not flipping the wall's flag under it.
            if (globallyMuted) {
              unawaited(ref.read(playbackSettingsProvider.notifier).setGlobalMute(value: false));
            } else {
              controls.toggleMuteAll();
            }
          },
        ),
      if (activePanes.isNotEmpty)
        _ToolbarButton(
          iconAsset: anyPlaying ? 'assets/icons/pause.svg' : 'assets/icons/play.svg',
          semanticLabel: anyPlaying ? t.multiview.pauseAll : t.multiview.resumeAll,
          active: !anyPlaying,
          onPressed: () => unawaited(controls.togglePauseAll()),
        ),
    ];
    // A stacked toolbar hands everything to the shell's head line as one
    // labelled more menu: the arrangements, then the wall's switches. The
    // page keeps only the wall below.
    if (PageLayoutScope.isNarrow(context)) {
      void chooseLayout(MultiviewLayout arrangement) {
        setState(() => _swapSource = null);
        unawaited(ref.read(multiviewProvider.notifier).setLayout(arrangement));
      }

      void toggleMute() {
        if (globallyMuted) {
          unawaited(ref.read(playbackSettingsProvider.notifier).setGlobalMute(value: false));
        } else {
          controls.toggleMuteAll();
        }
      }

      publishPageHeadActions(context, ref, NavigationItem.multiview, [
        DsButton(
          variant: DsButtonVariant.secondary,
          size: DsSize.sm,
          semanticLabel: t.common.more,
          leading: const DsIcon(DsIcons.chevronDown, size: 14),
          child: Text(t.common.more),
          onPressed: () => unawaited(
            showActionsPanel(
              context,
              title: t.common.more,
              children: [
                DsListSection(
                  header: Text(t.multiview.layoutLabel),
                  children: [
                    for (final arrangement in MultiviewLayout.values)
                      DsListRow(
                        title: Text(_arrangementLabel(arrangement)),
                        trailing: wall.layout == arrangement ? const DsIcon(DsIcons.check, size: 16) : null,
                        onPressed: () {
                          Navigator.of(context).pop();
                          chooseLayout(arrangement);
                        },
                      ),
                  ],
                ),
                DsListSection(
                  children: [
                    if (audibleFocus case final focus?)
                      DsListRow(
                        leading: const DsIcon(DsIcons.volume),
                        title: Text(focus.name),
                        description: Text(t.multiview.audibleFocus),
                        onPressed: () {
                          Navigator.of(context).pop();
                          focus.onPressed();
                        },
                      ),
                    DsListRow(
                      leading: DsIcon(wallMuted ? DsIcons.volumeOff : DsIcons.volume),
                      title: Text(wallMuted ? t.multiview.unmuteAll : t.multiview.muteAll),
                      onPressed: () {
                        Navigator.of(context).pop();
                        toggleMute();
                      },
                    ),
                    if (activePanes.isNotEmpty)
                      DsListRow(
                        leading: DsIcon(anyPlaying ? DsIcons.pause : DsIcons.play),
                        title: Text(anyPlaying ? t.multiview.pauseAll : t.multiview.resumeAll),
                        onPressed: () {
                          Navigator.of(context).pop();
                          unawaited(controls.togglePauseAll());
                        },
                      ),
                  ],
                ),
                DsListSection(
                  children: [
                    DsListRow(
                      leading: const DsIcon(DsIcons.plus),
                      title: Text(t.multiview.addRoom),
                      onPressed: () {
                        Navigator.of(context).pop();
                        _addRoom();
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ]);
      return const SizedBox.shrink();
    }
    final inline = switches;
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 560) {
          return Wrap(
            spacing: DsSpace.s8,
            runSpacing: DsSpace.s6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [layout, ?audibleFocus, ...inline, addRoom],
          );
        }
        // The reference's 44 px toolbar line: the arrangements and the wall's
        // switches left, the danmaku hint and the add action right, the
        // stretch between the two groups the row's own.
        return SizedBox(
          height: 44,
          child: Row(
            spacing: DsSpace.s8,
            children: [
              layout,
              ?audibleFocus,
              ...inline,
              const Spacer(),
              Flexible(
                child: Text(
                  t.multiview.danmakuHint,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.typography.small.copyWith(color: colors.textSubtle),
                ),
              ),
              addRoom,
            ],
          ),
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
    return (index: index, key: key, room: room, title: _slotTitle(key, room), platform: _slotPlatform(key, room));
  }

  /// The pane's platform's badge text (the brand without the 直播 suffix),
  /// the title tag's first word; a pane whose site is gone falls back to the
  /// raw id, an empty pane to nothing.
  String _slotPlatform(String? key, LiveRoom? room) {
    final at = key?.indexOf(':') ?? -1;
    final id = room?.ref.platform ?? (key == null || at < 0 ? '' : key.substring(0, at));
    if (id.isEmpty) return '';
    final site = ref.read(sitesProvider).getById(id);
    return site == null ? id : localizedSiteShortName(site);
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
          final (columns, rows) = _gridOf(wall.layout, wide: constraints.maxWidth >= constraints.maxHeight);
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
  static (int, int) _gridOf(MultiviewLayout layout, {required bool wide}) => switch (layout) {
    MultiviewLayout.single => (1, 1),
    MultiviewLayout.dual => (2, 1),
    MultiviewLayout.quad || MultiviewLayout.focus => (2, 2),
    // Four across when the wall is wide, stacked when it is tall.
    MultiviewLayout.strip => wide ? (4, 1) : (1, 4),
  };

  /// One pane of the wall, wired to the page's handlers; [compact] keeps
  /// the small pane of the 1+3 arrangement to the two buttons that make
  /// sense at that size (selecting it brings it large, with the rest).
  Widget _pane(List<_Slot> slots, MultiviewPlaybackState playback, int at, {bool compact = false}) {
    final slot = slots[at];
    return _PaneTile(
      fit: ref.watch(playbackSettingsProvider).fit.boxFit,
      slot: slot,
      playback: playback.panes[slot.index],
      selected: playback.selected == slot.index,
      compact: compact,
      swapSource: _swapSource,
      picking: _pickingSlot == slot.index,
      onPick: () => _pickForSlot(slot.index),
      onSelect: () => ref.read(multiviewPlaybackProvider.notifier).select(slot.index, promote: true),
      onPause: () => unawaited(ref.read(multiviewPlaybackProvider.notifier).togglePause(slot.index)),
      onOpen: () => unawaited(_openSlot(slot.key, slot.room)),
      onRetry: () => unawaited(ref.read(multiviewPlaybackProvider.notifier).retry(slot.index)),
      onClear: () => _clearSlot(slot.index),
      onSwapStart: () => setState(() => _swapSource = slot.index),
      onSwapWith: () => _handleSwapTap(slot.index),
    );
  }

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
    await openRoom(context, platform: platform, roomId: roomId, room: room);
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

  /// A wall that has never been arranged opens with its picker dock on the
  /// first empty cell: an empty wall with nothing to look at is the one case
  /// where the picker is the page's subject, and the reference opens there too.
  void _openDockForFirstEmptyCell(MultiviewState wall) {
    if (_dockConsidered) return;
    _dockConsidered = true;
    if (_pickingSlot != null) return;
    if (wall.slots.every((slot) => slot != null)) return;
    final at = wall.slots.indexOf(null);
    if (at < 0) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _pickingSlot = at);
    });
  }

  /// Opens the picker dock for slot [index]: the wall shrinks beside
  /// it rather than losing itself behind a dialog, so a viewer can
  /// still see which cell the room is landing in.
  void _pickForSlot(int index) => setState(() => _pickingSlot = index);

  /// The toolbar's add action: the dock opens on the first empty cell; a
  /// full wall says so instead of pointing at a cell that is not there.
  void _addRoom() {
    final at = ref.read(multiviewProvider).slots.indexOf(null);
    if (at < 0) {
      showDsToast(context: context, title: context.t.multiview.wallFull);
      return;
    }
    _pickForSlot(at);
  }

  /// Puts [room] in slot [index] and moves the dock to the next empty
  /// cell — filling a wall is a run of picks, not one — closing it
  /// once the wall is full.
  Future<void> _assign(int index, LiveRoom room) async {
    await ref.read(multiviewProvider.notifier).assign(index, room);
    if (!mounted) return;
    setState(() => _pickingSlot = _nextFreeSlot(index));
  }

  /// The next cell with nothing in it, after [after]; null when the
  /// wall is full, which is where the dock closes itself.
  int? _nextFreeSlot(int after) {
    final slots = ref.read(multiviewProvider).slots;
    for (var index = after + 1; index < slots.length; index++) {
      if (slots[index] == null) return index;
    }
    for (var index = 0; index < after; index++) {
      if (slots[index] == null) return index;
    }
    return null;
  }
}

/// One pane's place in the wall: the slot, the identity it holds (null for
/// an empty pane), the room that identity resolves to, its title, and its
/// platform's badge text.
typedef _Slot = ({int index, String? key, LiveRoom? room, String title, String platform});

/// One pane of the wall: an assigned one plays its room edge to edge, with
/// its title on a glass tag at the top left, its controls on a glass island
/// at the top right, and the stream facts on a glass badge at the bottom
/// left; an empty one offers the pane picker behind a dashed border. A
/// [compact] pane (a small one of the 1+3 arrangement) keeps only the
/// audible and close buttons — selecting it brings it large, with the rest.
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
    required this.picking,
    required this.onPick,
    required this.onSelect,
    required this.onPause,
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

  /// Whether the pane is a small one of the 1+3 arrangement.
  final bool compact;

  /// The pane a pending swap starts from, null while none is pending.
  final int? swapSource;

  /// Whether the picker dock is choosing for this cell right now.
  final bool picking;

  final VoidCallback onPick;
  final VoidCallback onSelect;
  final VoidCallback onPause;
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
    // The stream facts, bottom-left: what plays and on which line, hidden
    // whole while the pane has no stream to name.
    final pane = playback;
    final streamNote = pane == null || pane.stage != MultiviewPaneStage.playing || pane.quality == null
        ? null
        : [pane.quality!.displayLabel, if (pane.lines.length > 1) t.room.line(n: pane.lineIndex + 1)].join(' · ');
    return DsPressable(
      semanticLabel: assigned ? slot.title : t.multiview.pickRoom,
      onPressed: swapping
          ? onSwapWith
          : assigned
          ? onSelect
          : onPick,
      builder: (context, states, _) {
        final lit = states.contains(WidgetState.hovered) || states.contains(WidgetState.focused);
        final ring = isSource
            ? colors.channel
            : selected && assigned
            ? colors.accent
            : colors.border;
        // DsBoxDecoration paints corners but cannot clip: the Container
        // asks a decoration for its clip path when clipBehavior is set, and
        // DsBoxDecoration refuses that. The clip therefore lives above it.
        return ClipRRect(
          borderRadius: BorderRadius.circular(theme.radii.card),
          child: Container(
            decoration: DsBoxDecoration(
              color: colors.control,
              borderRadius: BorderRadius.circular(theme.radii.card),
              shadows: [DsShadow.innerRing(ring, width: isSource || (selected && assigned) ? 2 : 1)],
            ),
            child: assigned
                ? Stack(
                    fit: StackFit.expand,
                    children: [
                      _picture(context, colors, theme, lit),
                      // One row holds both floating pieces, so a long
                      // title yields to the island instead of sliding
                      // under it.
                      PositionedDirectional(
                        top: DsSpace.s6,
                        start: DsSpace.s6,
                        end: DsSpace.s6,
                        child: Row(
                          spacing: DsSpace.s6,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Flexible(child: _titleTag(theme)),
                            _PaneIsland(
                              buttons: [
                                _PaneIslandButton(
                                  icon: pane?.audible ?? false ? DsIcons.volume2 : DsIcons.volumeX,
                                  semanticLabel: t.multiview.setAudible,
                                  active: pane?.audible ?? false,
                                  onPressed: onSelect,
                                ),
                                // The rest earn their place only on a
                                // pane large enough to carry them.
                                if (!compact) ...[
                                  _PaneIslandButton(
                                    iconAsset: pane?.paused ?? false
                                        ? 'assets/icons/play.svg'
                                        : 'assets/icons/pause.svg',
                                    semanticLabel: pane?.paused ?? false ? t.multiview.playPane : t.multiview.pausePane,
                                    onPressed: onPause,
                                  ),
                                  _PaneIslandButton(
                                    icon: DsIcons.arrowLeftRight,
                                    semanticLabel: t.multiview.swapPane,
                                    active: isSource,
                                    onPressed: isSource ? onSwapWith : onSwapStart,
                                  ),
                                  _PaneIslandButton(
                                    icon: DsIcons.externalLink,
                                    semanticLabel: t.multiview.openRoom,
                                    onPressed: onOpen,
                                  ),
                                ],
                                _PaneIslandButton(
                                  icon: DsIcons.x,
                                  semanticLabel: t.multiview.clearPane,
                                  dangerHover: true,
                                  onPressed: onClear,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      if (streamNote case final note?)
                        PositionedDirectional(
                          bottom: DsSpace.s6,
                          start: DsSpace.s6,
                          child: _PaneStreamBadge(text: note),
                        ),
                    ],
                  )
                : Stack(
                    fit: StackFit.expand,
                    children: [
                      // The dashed border is the empty cell's own
                      // invitation; it takes the accent while this is the
                      // cell the dock or a swap is aiming at.
                      CustomPaint(
                        foregroundPainter: _DashedBorderPainter(
                          color: swapping || picking ? colors.accent : colors.border,
                          radius: theme.radii.card,
                        ),
                      ),
                      Center(
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
                              swapping
                                  ? t.multiview.swapHere
                                  : picking
                                  ? t.multiview.panePicking
                                  : t.multiview.addRoom,
                              style: theme.typography.caption.copyWith(color: colors.textMuted),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                      // The cell's number, so the picker's "第 N 格"
                      // names a cell the viewer can see.
                      PositionedDirectional(
                        top: DsSpace.s8,
                        start: DsSpace.s12,
                        child: Text(
                          '${slot.index + 1}',
                          style: theme.typography.caption.copyWith(color: colors.textSubtle),
                        ),
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
  Widget _picture(BuildContext context, DsColors colors, DsThemeData theme, bool lit) {
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
          _cover(colors, theme, lit),
          if (playback?.stage == MultiviewPaneStage.opening)
            const Center(child: DsSpinner(style: DsSpinnerStyle(size: 22))),
          if (playback?.stage == MultiviewPaneStage.failed) _failure(context, colors, theme),
        ],
        if (handle != null && playback?.switching == true)
          const Positioned.fill(
            child: IgnorePointer(
              child: Center(child: DsSpinner(style: DsSpinnerStyle(size: 22))),
            ),
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
          color: OnVideoColors.dimLight,
          child: Center(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Container(
                height: 26,
                padding: const EdgeInsetsDirectional.only(start: DsSpace.s8, end: DsSpace.s12),
                decoration: BoxDecoration(color: OnVideoColors.scrim, borderRadius: BorderRadius.circular(13)),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  spacing: DsSpace.s6,
                  children: [
                    const DsIcon(DsIcons.pause, size: 14, color: OnVideoColors.foreground),
                    Text(
                      t.multiview.panePaused,
                      style: theme.typography.caption.copyWith(color: OnVideoColors.foreground),
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

  /// The room's cover, cropped to fill the pane under the floating
  /// pieces; a room the follows no longer know shows the stand-in only.
  Widget _cover(DsColors colors, DsThemeData theme, bool lit) {
    final url = slot.room?.content.coverUrl ?? '';
    final fallback = ColoredBox(
      color: colors.channel,
      child: Center(
        child: DsIcon(DsIcons.tv, size: theme.sizes.iconLg, color: colors.textSubtle),
      ),
    );
    if (url.isEmpty) return fallback;
    return DsImage(
      image: cachedImage(url, policy: ImageCachePolicies.liveRoomCover),
      aspectRatio: 16 / 9,
      semanticLabel: slot.title,
      fallback: fallback,
      style: DsImageStyle(borderRadius: lit ? BorderRadius.zero : null),
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
          color: OnVideoColors.scrim,
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

  /// The pane's title tag, top-left: the platform's badge text and the
  /// room's own title on the pane glass, the way the room cards name their
  /// covers. It yields its width to the island beside it and ellipsizes.
  Widget _titleTag(DsThemeData theme) {
    final platform = slot.platform;
    return Container(
      height: 22,
      padding: const EdgeInsetsDirectional.only(start: DsSpace.s8, end: DsSpace.s8),
      decoration: BoxDecoration(
        color: _paneGlass,
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: _paneGlassEdge),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Both words bend: a tiny cell must never see the tag paint
          // past its bounds, whatever the platform's name measures.
          if (platform.isNotEmpty) ...[
            Flexible(
              child: Text(
                platform,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.typography.caption.copyWith(fontWeight: FontWeight.w700, color: OnVideoColors.foreground),
              ),
            ),
            const SizedBox(width: DsSpace.s6),
          ],
          Flexible(
            child: Text(
              slot.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.typography.caption.copyWith(color: OnVideoColors.inkMuted),
            ),
          ),
        ],
      ),
    );
  }
}

/// The translucent glass the pane's floating pieces sit on. Dark enough to
/// read over any stream, light enough to see through; the hairline edge is
/// the pane-scale stand-in for the blur the room's big glass cards use —
/// a wall of live decoders pays for every filter it carries.
const Color _paneGlass = OnVideoColors.paneGlass;
const Color _paneGlassEdge = OnVideoColors.inkHover;

/// A pane's floating island, top-right: a strip of pane glass holding the
/// pane's small controls, so they ride over the picture instead of taking
/// a bar away from it.
final class _PaneIsland extends StatelessWidget {
  const _PaneIsland({required this.buttons});

  /// The buttons, in order.
  final List<Widget> buttons;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 30,
      padding: const EdgeInsetsDirectional.symmetric(horizontal: DsSpace.s3),
      decoration: BoxDecoration(
        color: _paneGlass,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _paneGlassEdge),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, spacing: DsSpace.s3, children: buttons),
    );
  }
}

/// One of the island's buttons: 26 px, the icon alone, a soft ink fill
/// around it when the pointer arrives.
final class _PaneIslandButton extends StatelessWidget {
  const _PaneIslandButton({
    required this.semanticLabel,
    required this.onPressed,
    this.icon,
    this.iconAsset,
    this.active = false,
    this.dangerHover = false,
  }) : assert((icon == null) != (iconAsset == null), 'give exactly one glyph source: icon or iconAsset');

  /// The icon shown.
  final DsIconData? icon;

  /// A bundled svg glyph drawn instead of [icon].
  final String? iconAsset;

  /// The name screen readers hear.
  final String semanticLabel;

  final VoidCallback onPressed;

  /// Whether the button marks a state (the pane owning the sound, a
  /// pending swap's source) and so stays strong when idle.
  final bool active;

  /// Whether hovering takes the danger tone (a destructive action).
  final bool dangerHover;

  @override
  Widget build(BuildContext context) {
    final colors = DsTheme.colorsOf(context);
    return DsPressable(
      semanticLabel: semanticLabel,
      onPressed: onPressed,
      builder: (context, states, _) {
        final lit = states.contains(WidgetState.hovered) || states.contains(WidgetState.focused);
        return Container(
          width: 26,
          height: 26,
          decoration: DsBoxDecoration(
            color: lit ? OnVideoColors.inkHover : null,
            borderRadius: BorderRadius.circular(7),
          ),
          child: Center(
            child: switch (iconAsset) {
              final String asset => SvgPicture.asset(
                asset,
                width: 14,
                height: 14,
                colorFilter: ColorFilter.mode(
                  lit && dangerHover
                      ? colors.danger.fill
                      : lit || active
                      ? OnVideoColors.foreground
                      : OnVideoColors.inkMuted,
                  BlendMode.srcIn,
                ),
              ),
              _ => DsIcon(
                icon!,
                size: 14,
                color: lit && dangerHover
                    ? colors.danger.fill
                    : lit || active
                    ? OnVideoColors.foreground
                    : OnVideoColors.inkMuted,
              ),
            },
          ),
        );
      },
    );
  }
}

/// A pane's stream badge, bottom-left: the quality and the line it plays
/// (「原画 · 线路 2」) on the pane glass. Nothing draws while the pane has
/// no stream facts to name.
final class _PaneStreamBadge extends StatelessWidget {
  const _PaneStreamBadge({required this.text});

  /// The joined note, e.g. 原画 · 线路 2.
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = DsTheme.of(context);
    return Container(
      height: 20,
      constraints: const BoxConstraints(maxWidth: 160),
      padding: const EdgeInsetsDirectional.only(start: DsSpace.s6, end: DsSpace.s8),
      alignment: AlignmentDirectional.center,
      decoration: BoxDecoration(
        color: _paneGlass,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: _paneGlassEdge),
      ),
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: theme.typography.caption.copyWith(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: OnVideoColors.inkMuted,
        ),
      ),
    );
  }
}

/// A rounded dashed border, for the empty cell that asks to be filled.
/// Hand-painted along the rrect's metrics — a plain border cannot dash,
/// and the wall buys no package for one stroke.
final class _DashedBorderPainter extends CustomPainter {
  const _DashedBorderPainter({required this.color, required this.radius});

  /// The dash color.
  final Color color;

  /// The rrect's corner radius, the pane's own.
  final double radius;

  static const double _dash = 5;
  static const double _gap = 4;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    // The path is inset by half the stroke, so the clip along the pane's
    // edge never takes the dash's outer half away.
    final rect = (Offset.zero & size).deflate(0.75);
    final path = Path()..addRRect(RRect.fromRectAndRadius(rect, Radius.circular(math.max(0, radius - 0.75))));
    for (final metric in path.computeMetrics()) {
      for (var distance = 0.0; distance < metric.length; distance += _dash + _gap) {
        canvas.drawPath(metric.extractPath(distance, math.min(distance + _dash, metric.length)), paint);
      }
    }
  }

  @override
  bool shouldRepaint(_DashedBorderPainter oldDelegate) => oldDelegate.color != color || oldDelegate.radius != radius;
}

/// The toolbar's sound-focus pill: an accent outline naming the pane that
/// owns the sound; pressing it opens the dock on that pane, so replacing
/// what plays there moves the sound with it.
final class _AudibleFocusButton extends StatelessWidget {
  const _AudibleFocusButton({required this.name, required this.semanticLabel, required this.onPressed});

  /// The audible pane's name, the pill's text.
  final String name;

  /// The name screen readers hear and the pointer reads on hover.
  final String semanticLabel;

  final VoidCallback onPressed;

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
        builder: (context, states, _) {
          final lit = states.contains(WidgetState.hovered) || states.contains(WidgetState.focused);
          return Container(
            height: theme.sizes.sm,
            constraints: const BoxConstraints(maxWidth: 220),
            padding: const EdgeInsetsDirectional.only(start: DsSpace.s8, end: DsSpace.s12),
            decoration: DsBoxDecoration(
              color: lit ? colors.accentTint : null,
              borderRadius: BorderRadius.circular(theme.sizes.sm / 2),
              shadows: [DsShadow.ring(colors.accent)],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              spacing: DsSpace.s6,
              children: [
                DsIcon(DsIcons.volume2, size: 14, color: colors.accent),
                Flexible(
                  child: Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.typography.caption.copyWith(fontWeight: FontWeight.w600, color: colors.accentText),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// A toolbar switch: an icon alone in the header, filled while its state is
/// on (mute-all, pause-all), with the words in a tooltip.
final class _ToolbarButton extends StatelessWidget {
  const _ToolbarButton({
    required this.semanticLabel,
    required this.onPressed,
    this.icon,
    this.iconAsset,
    this.active = false,
  }) : assert((icon == null) != (iconAsset == null), 'give exactly one glyph source: icon or iconAsset');

  /// The icon shown.
  final DsIconData? icon;

  /// A bundled svg glyph drawn instead of [icon].
  final String? iconAsset;

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
          final lit = states.contains(WidgetState.hovered) || states.contains(WidgetState.focused);
          return Container(
            width: theme.sizes.sm,
            height: theme.sizes.sm,
            decoration: DsBoxDecoration(
              color: active
                  ? colors.accentTint
                  : lit
                  ? colors.hover
                  : null,
              borderRadius: theme.radii.controlCorners(null, theme.sizes.sm),
            ),
            child: Center(
              child: switch (iconAsset) {
                final String asset => SvgPicture.asset(
                  asset,
                  width: theme.sizes.iconSm,
                  height: theme.sizes.iconSm,
                  colorFilter: ColorFilter.mode(active ? colors.accentText : colors.textMuted, BlendMode.srcIn),
                ),
                _ => DsIcon(icon!, size: theme.sizes.iconSm, color: active ? colors.accentText : colors.textMuted),
              },
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
    final pause = _ToolbarButton(
      icon: pane.paused ? DsIcons.play : DsIcons.pause,
      semanticLabel: pane.paused ? t.multiview.playPane : t.multiview.pausePane,
      onPressed: onPause,
    );
    final quality = _StreamChip(
      icon: DsIcons.gauge,
      label: pane.quality?.displayLabel ?? t.multiview.paneQuality,
      semanticLabel: t.multiview.paneQuality,
      enabled: !pane.switching && pane.qualities.isNotEmpty,
      items: [
        for (final quality in pane.qualities)
          DsMenuItem(
            label: Text(quality.displayLabel),
            checked: quality == pane.quality,
            onPressed: () => onQuality(quality),
          ),
      ],
    );
    final lineChip = pane.lines.length > 1
        ? _StreamChip(
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
          )
        : null;
    final volume = Row(
      spacing: DsSpace.s8,
      children: [
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
    return LayoutBuilder(
      builder: (context, constraints) {
        // The pane's switches and its slider cannot share one row down to
        // the window's 300 px floor — two capped chips, the pause switch
        // and the gaps already total ~430 px — so below that the switches
        // wrap and the volume takes the line beneath.
        if (constraints.maxWidth < 440) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: DsSpace.s8,
            children: [
              Wrap(
                spacing: DsSpace.s8,
                runSpacing: DsSpace.s8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [pause, quality, ?lineChip],
              ),
              volume,
            ],
          );
        }
        // The volume row holds an Expanded slider: only the fitted row's
        // remaining space gives it the bounded width that asks for — loose
        // in an outer row it would meet unbounded constraints and die.
        return Row(
          spacing: DsSpace.s8,
          children: [
            pause,
            quality,
            ?lineChip,
            const SizedBox(width: DsSpace.s4),
            Expanded(child: volume),
          ],
        );
      },
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
    Widget chip({required bool lit}) => ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 180),
      child: Container(
        height: theme.sizes.sm,
        padding: const EdgeInsets.symmetric(horizontal: DsSpace.s8),
        decoration: DsBoxDecoration(
          color: lit ? colors.hover : null,
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
    if (!enabled) return chip(lit: false);
    return DsMenuAnchor(
      semanticLabel: semanticLabel,
      items: items,
      builder: (context, controller, _) => DsPressable(
        semanticLabel: semanticLabel,
        onPressed: controller.toggle,
        builder: (context, states, _) =>
            chip(lit: states.contains(WidgetState.hovered) || states.contains(WidgetState.focused)),
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

/// The picker dock: the followed rooms and the watched ones, in a panel
/// beside the wall rather than over it — the cell a pick lands in stays
/// visible while the list is read. Its header names the cell, its tabs
/// choose where the rooms come from, and its search field narrows by
/// title, streamer, room id or platform.
final class _PanePickerDock extends ConsumerStatefulWidget {
  const _PanePickerDock({required this.slotIndex, required this.onAssign, required this.onClose});

  /// The pane (0-based) the picked room lands in.
  final int slotIndex;

  /// Hands the picked room to the wall.
  final void Function(LiveRoom room) onAssign;

  /// Closes the dock.
  final VoidCallback onClose;

  @override
  ConsumerState<_PanePickerDock> createState() => _PanePickerDockState();
}

final class _PanePickerDockState extends ConsumerState<_PanePickerDock> {
  /// The filter's current words.
  String _query = '';

  /// Which list the dock is showing: follows, or what was watched.
  bool _fromHistory = false;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final theme = DsTheme.of(context);
    final colors = DsTheme.colorsOf(context);
    final follows = ref.watch(followsProvider);
    final history = ref.watch(historyProvider);
    final wall = ref.watch(multiviewProvider);
    final shown = <String, int>{};
    for (var index = 0; index < wall.slots.length; index++) {
      final key = wall.slots[index];
      if (key != null && index != widget.slotIndex) shown[key] = index;
    }
    // One row per identity, no duplicates: a room followed and watched
    // still appears once, in whichever list the tab is showing.
    final rooms = <LiveRoom>[];
    final seen = <String>{};
    final source = _fromHistory ? [for (final (room, _) in history.records) room] : follows.rooms;
    for (final room in source) {
      if (seen.add(room.ref.identityKey)) rooms.add(room);
    }
    final needle = _query.trim().toLowerCase();
    final visible = needle.isEmpty
        ? rooms
        : [
            for (final room in rooms)
              if (_matches(room, needle)) room,
          ];
    final loading = !follows.ready || !history.ready;
    return Container(
      decoration: DsBoxDecoration(
        color: colors.channel,
        borderRadius: BorderRadius.circular(theme.radii.card),
        shadows: [DsShadow.innerRing(colors.border)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(DsSpace.s12, DsSpace.s12, DsSpace.s6, DsSpace.s4),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    spacing: DsSpace.s4,
                    children: [
                      // Both lines bend: at the window's floor the dock is
                      // the page's own width and the two cannot stand at
                      // full size — an unbent Text paints past the row. The
                      // title takes two shares, the hint one.
                      Row(
                        spacing: DsSpace.s6,
                        children: [
                          Flexible(
                            flex: 2,
                            child: Text(
                              t.multiview.pickerTitle(index: widget.slotIndex + 1),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.typography.bodyStrong.copyWith(color: colors.text),
                            ),
                          ),
                          Flexible(
                            child: Text(
                              t.multiview.pickerHint,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.typography.caption.copyWith(color: colors.textSubtle),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                DsButton.icon(
                  variant: DsButtonVariant.ghost,
                  size: DsSize.sm,
                  semanticLabel: t.common.close,
                  onPressed: widget.onClose,
                  icon: const DsIcon(DsIcons.x, size: 16),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: DsSpace.s12),
            child: DsSegmentedControl<bool>(
              segments: [
                DsSegment(value: false, label: Text(t.multiview.pickerTabFollows)),
                DsSegment(value: true, label: Text(t.multiview.pickerTabHistory)),
              ],
              value: _fromHistory,
              semanticLabel: t.multiview.pickerTitle(index: widget.slotIndex + 1),
              onChanged: (value) => setState(() => _fromHistory = value),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(DsSpace.s12, DsSpace.s8, DsSpace.s12, DsSpace.s8),
            child: TvInputField(
              placeholder: t.multiview.pickerSearchShort,
              semanticLabel: t.multiview.pickerSearch,
              onChanged: (value) => setState(() => _query = value),
            ),
          ),
          Expanded(
            child: loading
                ? const Center(child: DsSpinner(style: DsSpinnerStyle(size: 22)))
                : rooms.isEmpty
                ? Center(
                    child: DsEmptyState(
                      icon: const DsIcon(DsIcons.heart),
                      title: Text(t.multiview.pickerEmptyTitle),
                      description: Text(t.multiview.pickerEmptyHint),
                    ),
                  )
                : visible.isEmpty
                ? Center(child: Text(t.multiview.pickerNoMatch, style: theme.typography.caption))
                : ListView(
                    padding: const EdgeInsets.fromLTRB(DsSpace.s8, 0, DsSpace.s8, DsSpace.s8),
                    children: [
                      DsListSection(
                        children: [for (final room in visible) _row(context, ref, room, shown[room.ref.identityKey])],
                      ),
                    ],
                  ),
          ),
        ],
      ),
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
        widget.onAssign(room);
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

/// The arrangement's own word on the toolbar and in the more menu.
String _arrangementLabel(MultiviewLayout arrangement) => switch (arrangement) {
  MultiviewLayout.single => '1×1',
  MultiviewLayout.dual => '1×2',
  MultiviewLayout.quad => '2×2',
  MultiviewLayout.focus => '1+3',
  MultiviewLayout.strip => '1×4',
};
