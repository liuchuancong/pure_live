import 'dart:async' show StreamSubscription, unawaited;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_playback/live_playback.dart' show EngineStopped, PlaybackEngineEvent;
import 'package:live_sites/live_sites.dart'
    show LiveLinkResolver, LivePlayLine, LivePlaybackProvider, LiveRoomProvider, LiveSite;
import 'package:live_uikit/styling.dart' show LiveButton;
import 'package:media_core_media_kit/media_core_media_kit.dart' show MediaKitVideoView;
import 'package:mosaic_grid/mosaic_grid.dart';

import 'package:pure_live/app/engine/playback_engine.dart';
import 'package:pure_live/app/providers/app_providers.dart';
import 'package:pure_live/l10n/generated/strings.g.dart';
import 'package:pure_live/shared/widgets/settings_entry_button.dart';

/// Multi-view (3.x `MultiViewPage`): up to four rooms playing side by
/// side, each cell its own engine instance, added by link.
///
/// The ticket-reuse rule holds per cell: a cell resolves the room's lines
/// once through the site's playback capability and re-opens the same line
/// on retry. Layout switching, audio focus arbitration and the followed-
/// rooms picker join with their waves.
final class MultiviewPage extends ConsumerStatefulWidget {
  /// The multiview page.
  const new({super.key});

  @override
  ConsumerState<MultiviewPage> createState() => _MultiviewPageState();
}

final class _MultiviewPageState extends ConsumerState<MultiviewPage> {
  final List<_Cell> _cells = [];

  void _addCell(String siteId, String roomId, String name) {
    setState(() => _cells.add(_Cell(siteId: siteId, roomId: roomId, name: name)));
  }

  void _removeCell(String key) {
    setState(() => _cells.removeWhere((cell) => cell.key == key));
  }

  @override
  Widget build(BuildContext context) {
    final resolvers = ref
        .watch(sitesProvider)
        .registry
        .all
        .where((site) => site.capability<LiveLinkResolver>() != null)
        .toList();
    return Scaffold(
      appBar: AppBar(title: Text(context.t.multiview.title), actions: const [SettingsEntryButton()]),
      body: MosaicGrid(
        columnGap: 10,
        padding: const EdgeInsets.all(12),
        children: [
          for (final cell in _cells)
            _PlayingCell(key: ValueKey(cell.key), cell: cell, onClose: () => _removeCell(cell.key)),
          if (_cells.length < 4) _AddCellTile(resolvers: resolvers, onAdded: _addCell),
        ],
      ),
    );
  }
}

/// One user-added cell descriptor; [key] is the identity the grid keeps.
final class _Cell {
  new({required this.siteId, required this.roomId, required this.name});

  /// The process-unique cell identity.
  final String key = DateTime.now().microsecondsSinceEpoch.toString();

  /// The platform the room belongs to.
  final String siteId;

  /// The platform-specific room id.
  final String roomId;

  /// A title hint.
  final String name;
}

/// A cell that resolves and plays one room through its own engine.
final class _PlayingCell extends ConsumerStatefulWidget {
  const new({required this.cell, required this.onClose, super.key});

  /// The cell descriptor (platform, room id, title hint).
  final _Cell cell;

  /// Closes the cell.
  final VoidCallback onClose;

  @override
  ConsumerState<_PlayingCell> createState() => _PlayingCellState();
}

final class _PlayingCellState extends ConsumerState<_PlayingCell> {
  late final MediaCorePlaybackEngine _engine = MediaCorePlaybackEngine();
  StreamSubscription<PlaybackEngineEvent>? _engineSub;
  bool _engineStopped = false;
  String? _title;

  @override
  void initState() {
    super.initState();
    _engineSub = _engine.events.listen((event) {
      if (event is EngineStopped && mounted) {
        setState(() => _engineStopped = true);
      }
    });
    unawaited(_open());
  }

  @override
  void dispose() {
    unawaited(_engineSub?.cancel());
    unawaited(_engine.dispose());
    super.dispose();
  }

  Future<void> _open() async {
    final site = ref.read(sitesProvider).registry.getById(widget.cell.siteId);
    final capability = site?.capability<LivePlaybackProvider>();
    if (capability == null) {
      return;
    }
    final result = await capability.getLines(roomId: widget.cell.roomId);
    final lines = result.fold((error) => <LivePlayLine>[], (lines) => lines);
    if (lines.isEmpty || !mounted) {
      return;
    }
    final detail = await site?.capability<LiveRoomProvider>()?.getRoom(widget.cell.roomId);
    final title = detail?.fold((error) => null, (room) => room.content.title);
    if (mounted && title != null && title.isNotEmpty) {
      setState(() => _title = title);
    }
    await _engine.open(lines.first);
  }

  @override
  Widget build(BuildContext context) {
    final adapter = _engine.surfaceAdapter;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          ColoredBox(
            color: Colors.black,
            child: adapter != null
                ? MediaKitVideoView(adapter: adapter)
                : Center(
                    child: _engineStopped
                        ? LiveButton(
                            label: context.t.common.retry,
                            icon: Icons.refresh,
                            onPressed: () => unawaited(_open()),
                          )
                        : const CircularProgressIndicator(),
                  ),
          ),
          Positioned(
            top: 6,
            left: 6,
            right: 6,
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    _title ?? widget.cell.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ),
                GestureDetector(
                  onTap: widget.onClose,
                  child: const Icon(Icons.close, size: 18, color: Colors.white70),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The empty-slot tile: paste a platform link, a playing cell appears.
final class _AddCellTile extends ConsumerStatefulWidget {
  const new({required this.resolvers, required this.onAdded});

  /// The platforms whose links are understood.
  final List<LiveSite> resolvers;

  /// Adds a playing cell for the resolved room.
  final void Function(String siteId, String roomId, String name) onAdded;

  @override
  ConsumerState<_AddCellTile> createState() => _AddCellTileState();
}

final class _AddCellTileState extends ConsumerState<_AddCellTile> {
  final _link = TextEditingController();

  @override
  void dispose() {
    _link.dispose();
    super.dispose();
  }

  Future<void> _addFromLink() async {
    final text = _link.text.trim();
    final uri = Uri.tryParse(text);
    if (uri == null || !uri.hasScheme) {
      return;
    }
    for (final site in widget.resolvers) {
      final result = await site.capability<LiveLinkResolver>()!.resolve(uri);
      final owned = result.fold((failure) => null, (canonical) => canonical);
      if (owned == null) {
        continue;
      }
      final roomId = owned.pathSegments.last;
      widget.onAdded(site.manifest.id, roomId, roomId);
      return;
    }
  }

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          TextField(
            controller: _link,
            decoration: InputDecoration(hintText: context.t.toolbox.hint),
            onSubmitted: (_) => unawaited(_addFromLink()),
          ),
          const SizedBox(height: 8),
          LiveButton(label: context.t.multiview.add, icon: Icons.add, onPressed: () => unawaited(_addFromLink())),
        ],
      ),
    ),
  );
}
