import 'dart:async' show StreamSubscription, unawaited;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_library/live_library.dart' show LibraryRoom, WatchRecord;
import 'package:live_playback/live_playback.dart' show EngineProgress, EngineReady, EngineStopped, PlaybackEngineEvent;
import 'package:live_sites/live_sites.dart';
import 'package:media_core_media_kit/media_core_media_kit.dart' show MediaKitVideoView;
import 'package:mosaic_grid/mosaic_grid.dart' show MosaicColumns, MosaicGrid;
import 'package:pure_live/app/engine/playback_engine.dart';
import 'package:pure_live/app/providers/app_providers.dart';
import 'package:pure_live/features/multiview/multiview_preferences.dart';
import 'package:pure_live/l10n/generated/strings.g.dart';
import 'package:pure_live/shared/widgets/settings_entry_button.dart';
import 'package:pure_uikit/pure_uikit.dart';

/// Multi-view: a wall of rooms playing side by side, each cell its own
/// engine instance.
///
/// Playback is genuinely multi-instance: every cell owns a
/// [MediaCorePlaybackEngine] — its own media_core kernel and media_kit
/// (libmpv) player behind the `live_playback` `PlaybackEngine` seam — so the
/// wall plays as many decoders as the layout shows. What the wall
/// arbitrates is *audio*: exactly one cell (the focused one) is audible,
/// mirroring the reference app's audio-focus model, and each cell can be
/// muted on its own or all cells at once, applied as adapter volume.
///
/// The layout (1/2/4/6/9) persists through the appearance-preferences
/// document pattern; the cells themselves are a session.
final class MultiviewPage extends ConsumerStatefulWidget {
  /// The multiview page.
  const new({super.key});

  @override
  ConsumerState<MultiviewPage> createState() => _MultiviewPageState();
}

final class _MultiviewPageState extends ConsumerState<MultiviewPage> {
  /// The cells, one slot per grid position; a slot with a null room is an
  /// empty tile.
  List<_WallCell?> _cells = const [];

  /// The one cell allowed to sound.
  int _audioFocus = 0;

  /// Cells muted individually.
  final Set<int> _muted = {};

  /// Every cell silent at once.
  bool _allMuted = false;

  @override
  void initState() {
    super.initState();
    _cells = List<_WallCell?>.filled(ref.read(multiviewPreferencesProvider).layout.capacity, null);
  }

  MultiviewLayout get layout => ref.watch(multiviewPreferencesProvider).layout;

  /// Whether a cell is audible: it holds the audio focus and neither it nor
  /// the whole wall is muted.
  bool _audibleAt(int index) => index == _audioFocus && !_muted.contains(index) && !_allMuted;

  void _setLayout(MultiviewLayout next) {
    if (next == layout) {
      return;
    }
    setState(() {
      final capacity = next.capacity;
      _cells = List<_WallCell?>.filled(capacity, null)
        ..setAll(0, [
          for (var i = 0; i < capacity; i++)
            if (i < _cells.length) _cells[i] else null,
        ]);
      _audioFocus = _audioFocus.clamp(0, capacity - 1);
      _muted.removeWhere((index) => index >= capacity);
    });
    unawaited(
      ref.read(multiviewPreferencesProvider.notifier).update((preferences) => preferences.copyWith(layout: next)),
    );
  }

  void _assign(int index, _WallCell cell) {
    setState(() {
      _cells = [
        for (var i = 0; i < _cells.length; i++)
          if (i == index) cell else _cells[i],
      ];
      // A fresh assignment takes the room's sound with it.
      _audioFocus = index;
      _muted.remove(index);
    });
  }

  void _clear(int index) {
    setState(() {
      _cells = [
        for (var i = 0; i < _cells.length; i++)
          if (i == index) null else _cells[i],
      ];
      _muted.remove(index);
      if (_audioFocus == index) {
        _audioFocus = 0;
      }
    });
  }

  /// The first empty slot a fresh pick lands in, or the picked-over focused
  /// cell when the wall is full.
  int _targetSlot() {
    final index = _cells.indexWhere((cell) => cell == null);
    return index < 0 ? _audioFocus : index;
  }

  Future<void> _pickRoom() async {
    final picked = await showPureDialog<({String siteId, String roomId, String title})>(
      context: context,
      title: context.t.multiview.pickRoom,
      child: const _RoomPicker(),
    );
    if (picked == null) {
      return;
    }
    _assign(_targetSlot(), _WallCell(siteId: picked.siteId, roomId: picked.roomId, title: picked.title));
  }

  @override
  Widget build(BuildContext context) {
    final current = layout;
    return PureScaffold(
      appBar: PureAppBar(
        title: context.t.multiview.title,
        actions: [
          PureIconButton(
            tooltip: _allMuted ? context.t.multiview.unmuteAll : context.t.multiview.muteAll,
            icon: _allMuted ? Icons.volume_off : Icons.volume_up,
            onPressed: () => setState(() => _allMuted = !_allMuted),
          ),
          PureIconButton(
            tooltip: context.t.multiview.pickRoom,
            icon: Icons.add,
            onPressed: () => unawaited(_pickRoom()),
          ),
          const SettingsEntryButton(),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(52),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            child: Row(
              children: [
                Text(context.t.multiview.layout),
                const SizedBox(width: 12),
                Expanded(
                  child: PureSegmented(
                    labels: const ['1', '2', '4', '6', '9'],
                    index: const [
                      MultiviewLayout.single,
                      MultiviewLayout.dual,
                      MultiviewLayout.quad,
                      MultiviewLayout.six,
                      MultiviewLayout.nine,
                    ].indexOf(current),
                    onChanged: (index) => _setLayout(MultiviewLayout.values[index]),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      body: MosaicGrid(
        columns: MosaicColumns.count(current.columns),
        columnGap: 10,
        rowGap: 10,
        padding: const EdgeInsets.all(12),
        children: [
          for (final (index, cell) in _cells.indexed)
            if (cell == null)
              _EmptyCellTile(key: ValueKey('cell$index:empty'), onPicked: () => unawaited(_pickRoom()))
            else
              _PlayingCell(
                key: ValueKey('cell$index:${cell.siteId}:${cell.roomId}'),
                cell: cell,
                audible: _audibleAt(index),
                muted: _muted.contains(index) || _allMuted,
                focused: index == _audioFocus,
                onFocus: () => setState(() => _audioFocus = index),
                onToggleMute: () => setState(() {
                  _muted.contains(index) ? _muted.remove(index) : _muted.add(index);
                }),
                onClear: () => _clear(index),
              ),
        ],
      ),
    );
  }
}

/// One user-added cell descriptor.
final class _WallCell {
  /// A cell playing [roomId] off [siteId].
  const new({required this.siteId, required this.roomId, this.title = ''});

  /// The platform the room belongs to.
  final String siteId;

  /// The platform-specific room id.
  final String roomId;

  /// A title hint, replaced by the room's own title once it loads.
  final String title;
}

/// An empty grid slot: tap to pick a room for it.
final class _EmptyCellTile extends StatelessWidget {
  /// The empty tile.
  const new({required this.onPicked, super.key});

  /// Opens the room picker.
  final VoidCallback onPicked;

  @override
  Widget build(BuildContext context) => PureCard(
    onTap: onPicked,
    child: Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.add, size: 32, color: PureTheme.of(context).colors.textQuaternary),
          const SizedBox(height: 8),
          Text(
            context.t.multiview.emptyCell,
            style: PureTheme.of(context).text.caption.copyWith(color: PureTheme.of(context).colors.textSecondary),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    ),
  );
}

/// A cell that resolves and plays one room through its own engine.
///
/// `audible`, `muted` and `focused` arrive from the wall; the engine applies
/// the volume decision they encode whenever it changes.
final class _PlayingCell extends ConsumerStatefulWidget {
  /// The playing cell.
  const new({
    required this.cell,
    required this.audible,
    required this.muted,
    required this.focused,
    required this.onFocus,
    required this.onToggleMute,
    required this.onClear,
    super.key,
  });

  /// The cell descriptor (platform, room id, title hint).
  final _WallCell cell;

  /// Whether this cell is the wall's one audible cell.
  final bool audible;

  /// Whether sound is suppressed here (its own mute or the wall's).
  final bool muted;

  /// Whether this cell holds the audio focus.
  final bool focused;

  /// Takes the audio focus.
  final VoidCallback onFocus;

  /// Toggles this cell's own mute.
  final VoidCallback onToggleMute;

  /// Empties the cell.
  final VoidCallback onClear;

  @override
  ConsumerState<_PlayingCell> createState() => _PlayingCellState();
}

final class _PlayingCellState extends ConsumerState<_PlayingCell> {
  late final MediaCorePlaybackEngine _engine = MediaCorePlaybackEngine();
  StreamSubscription<PlaybackEngineEvent>? _engineSub;
  bool _engineStopped = false;
  bool _resolving = true;
  String? _title;

  @override
  void initState() {
    super.initState();
    _engineSub = _engine.events.listen((event) {
      if (!mounted) {
        return;
      }
      switch (event) {
        case EngineReady():
          setState(() {
            _engineStopped = false;
            _resolving = false;
          });
          _applyVolume();
        case EngineStopped():
          setState(() {
            _engineStopped = true;
            _resolving = false;
          });
        case EngineProgress():
          break;
      }
    });
    unawaited(_open());
  }

  @override
  void didUpdateWidget(_PlayingCell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.audible != widget.audible || oldWidget.muted != widget.muted) {
      _applyVolume();
    }
  }

  @override
  void dispose() {
    unawaited(_engineSub?.cancel());
    unawaited(_engine.dispose());
    super.dispose();
  }

  /// Whether this cell should sound right now.
  bool get _shouldSound => widget.audible && !widget.muted;

  /// Drives the volume decision into the engine's adapter: the wall keeps
  /// one audible cell and mutes the rest rather than pausing them, so
  /// returning to a cell resumes sound without a reopen.
  void _applyVolume() {
    unawaited(_engine.surfaceAdapter?.setVolume(_shouldSound ? 1.0 : 0.0));
  }

  Future<void> _open() async {
    setState(() {
      _resolving = true;
      _engineStopped = false;
    });
    final site = ref.read(sitesProvider).registry.getById(widget.cell.siteId);
    final capability = site?.capability<LivePlaybackProvider>();
    if (site == null || capability == null) {
      setState(() => _engineStopped = true);
      return;
    }
    final result = await capability.getLines(roomId: widget.cell.roomId);
    final lines = result.fold((error) => <LivePlayLine>[], (lines) => lines);
    if (!mounted) {
      return;
    }
    if (lines.isEmpty) {
      setState(() => _engineStopped = true);
      return;
    }
    unawaited(
      ref.read(roomProvider(widget.cell.siteId))?.getRoom(widget.cell.roomId).then((detail) {
        final room = detail.fold((error) => null, (room) => room);
        if (room != null && mounted && room.content.title.isNotEmpty) {
          setState(() => _title = room.content.title);
        }
      }),
    );
    await _engine.open(lines.first);
    _applyVolume();
  }

  @override
  Widget build(BuildContext context) {
    final adapter = _engine.surfaceAdapter;
    final colors = PureTheme.of(context).colors;
    return PureCard(
      padding: EdgeInsets.zero,
      onTap: widget.focused ? null : widget.onFocus,
      child: Stack(
        fit: StackFit.expand,
        children: [
          ColoredBox(
            color: Colors.black,
            child: adapter != null
                ? MediaKitVideoView(adapter: adapter)
                : Center(
                    child: _engineStopped
                        ? PureButton(
                            label: context.t.common.retry,
                            icon: Icons.refresh,
                            onPressed: () => unawaited(_open()),
                          )
                        : _resolving
                        ? const PureSpinner(size: 32)
                        : const SizedBox.shrink(),
                  ),
          ),
          Positioned(
            top: 6,
            left: 6,
            right: 6,
            child: Row(
              children: [
                if (widget.focused)
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: Tooltip(
                      message: context.t.multiview.audioFocus,
                      child: Icon(
                        _shouldSound ? Icons.volume_up : Icons.volume_off,
                        size: 16,
                        color: _shouldSound ? colors.primary : Colors.white38,
                      ),
                    ),
                  ),
                Expanded(
                  child: Text(
                    _title ?? widget.cell.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ),
                _CellGlyph(
                  icon: _shouldSound && !widget.muted ? Icons.volume_up : Icons.volume_off,
                  tooltip: widget.muted ? context.t.multiview.unmute : context.t.multiview.mute,
                  onTap: widget.onToggleMute,
                ),
                _CellGlyph(icon: Icons.close, tooltip: context.t.multiview.removeCell, onTap: widget.onClear),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// One overlay glyph on a playing cell, with its own scrim so it reads over
/// video.
final class _CellGlyph extends StatelessWidget {
  /// The glyph.
  const new({required this.icon, required this.tooltip, required this.onTap});

  /// The icon to draw.
  final IconData icon;

  /// The tooltip and accessibility label.
  final String tooltip;

  /// The tap handler.
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Tooltip(
    message: tooltip,
    child: InkWell(
      onTap: onTap,
      customBorder: const CircleBorder(),
      child: Container(
        margin: const EdgeInsets.only(left: 4),
        padding: const EdgeInsets.all(3),
        decoration: const BoxDecoration(color: Colors.black38, shape: BoxShape.circle),
        child: Icon(icon, size: 16, color: Colors.white),
      ),
    ),
  );
}

/// The room picker the empty tiles open: a pasted platform link or a room
/// from the follow list or the watch history, the same two sources the
/// reference picker draws from.
final class _RoomPicker extends ConsumerStatefulWidget {
  /// The picker body.
  const new();

  @override
  ConsumerState<_RoomPicker> createState() => _RoomPickerState();
}

final class _RoomPickerState extends ConsumerState<_RoomPicker> {
  final _link = TextEditingController();
  final _query = TextEditingController();
  bool _fromHistory = false;
  bool _resolving = false;

  @override
  void dispose() {
    _link.dispose();
    _query.dispose();
    super.dispose();
  }

  List<LibraryRoom> get _followed => ref.read(followRepositoryProvider).rooms;

  List<WatchRecord> get _history => ref.read(historyRepositoryProvider).records;

  ({String siteId, String roomId, String title}) _of(LiveRoom room) =>
      (siteId: room.ref.platform, roomId: room.ref.roomId, title: room.anchor?.name ?? room.content.title);

  Future<void> _addFromLink() async {
    final text = _link.text.trim();
    final uri = Uri.tryParse(text);
    if (uri == null || !uri.hasScheme) {
      return;
    }
    setState(() => _resolving = true);
    try {
      for (final site in ref.read(sitesProvider).registry.all) {
        final resolver = site.capability<LiveLinkResolver>();
        if (resolver == null) {
          continue;
        }
        final result = await resolver.resolve(uri);
        final owned = result.fold((failure) => null, (canonical) => canonical);
        if (owned == null) {
          continue;
        }
        if (!mounted) {
          return;
        }
        Navigator.of(context).pop((siteId: site.manifest.id, roomId: owned.pathSegments.last, title: ''));
        return;
      }
      if (mounted) {
        PureToast.show(context, context.t.toolbox.failed, type: PureToastType.error);
      }
    } finally {
      if (mounted) {
        setState(() => _resolving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final needle = _query.text.trim().toLowerCase();
    final rooms = [
      for (final entry in _fromHistory ? _history.map((record) => record.room) : _followed.map((e) => e.room))
        if (needle.isEmpty ||
            entry.content.title.toLowerCase().contains(needle) ||
            (entry.anchor?.name.toLowerCase().contains(needle) ?? false))
          _of(entry),
    ];
    return SizedBox(
      width: 420,
      height: 420,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            context.t.multiview.pickHint,
            style: PureTheme.of(context).text.caption.copyWith(color: PureTheme.of(context).colors.textSecondary),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: PureTextField(
                  controller: _link,
                  placeholder: context.t.toolbox.hint,
                  onSubmitted: (_) => unawaited(_addFromLink()),
                ),
              ),
              const SizedBox(width: 8),
              PureButton(
                label: context.t.multiview.add,
                icon: Icons.add,
                onPressed: _resolving ? null : () => unawaited(_addFromLink()),
              ),
            ],
          ),
          const SizedBox(height: 12),
          PureSegmented(
            labels: [context.t.tabs.follow, context.t.tabs.history],
            index: _fromHistory ? 1 : 0,
            onChanged: (index) => setState(() => _fromHistory = index == 1),
          ),
          const SizedBox(height: 8),
          PureTextField(
            controller: _query,
            placeholder: context.t.search.hint,
            prefix: const Icon(Icons.search),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: rooms.isEmpty
                ? Center(child: Text(context.t.multiview.noPick))
                : ListView.builder(
                    itemCount: rooms.length,
                    itemBuilder: (context, index) => PureListRow(
                      title: rooms[index].title,
                      subtitle: rooms[index].siteId,
                      onTap: () => Navigator.of(context).pop(rooms[index]),
                      divided: false,
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
