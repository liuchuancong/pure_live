import 'dart:async' show StreamSubscription, unawaited;

import 'package:desen_ui/desen_ui.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_sites/live_sites.dart';
// The whole library, not a `show`: the handle's volume and mute live in an
// extension the barrel exports, and a show list that names only the handle
// leaves them out of scope.
import 'package:media_core/media_core.dart';
import 'package:media_core_live/media_core_live.dart';
import 'package:pure_live/app/app.dart';
import 'package:pure_live/features/settings/settings.dart';

/// A card's hover preview: the room's own live picture, played on the card
/// the cover stood in for.
///
/// The widget mounts when a pointer has rested on a card and unmounts when it
/// leaves, and its whole life is that one preview: it resolves the room's
/// plan at the lowest tier the site spells (a hover trades picture for the
/// bandwidth the real room will spend), opens a playback over the module's
/// own kernel, mutes it whatever the room's audio rules say, and releases the
/// engine the moment it is taken out of the tree. A room that turns out to
/// have nothing to play leaves the cover where it was.
final class RoomLivePreview extends ConsumerStatefulWidget {
  /// Plays [room]'s live stream for as long as this widget is mounted.
  const RoomLivePreview({required this.room, super.key});

  /// The room whose stream plays.
  final LiveRoom room;

  @override
  ConsumerState<RoomLivePreview> createState() => _RoomLivePreviewState();
}

final class _RoomLivePreviewState extends ConsumerState<RoomLivePreview> {
  LivePlaybackController? _playback;
  PlayerHandle? _handle;
  LiveIngestSession? _ingest;
  LivePlayQuality? _quality;
  StreamSubscription<PlayerHandle>? _handles;
  int _epoch = 0;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    unawaited(_open(widget.room));
  }

  @override
  void didUpdateWidget(RoomLivePreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.room, widget.room)) unawaited(_reopen());
  }

  @override
  void dispose() {
    _epoch++;
    unawaited(_handles?.cancel() ?? Future<void>.value());
    unawaited(_ingest?.close() ?? Future<void>.value());
    unawaited(_playback?.dispose() ?? Future<void>.value());
    super.dispose();
  }

  /// Whether this mount is still the one whose work is wanted.
  bool _stale(int epoch) => !mounted || epoch != _epoch;

  /// Drops whatever is playing and opens the room again — the caller swapped
  /// the room under a mounted preview.
  Future<void> _reopen() async {
    final epoch = ++_epoch;
    final playback = _playback;
    final ingest = _ingest;
    _playback = null;
    _ingest = null;
    _handle = null;
    _failed = false;
    unawaited(_handles?.cancel() ?? Future<void>.value());
    _handles = null;
    unawaited(ingest?.close() ?? Future<void>.value());
    unawaited(playback?.dispose() ?? Future<void>.value());
    if (mounted) setState(() {});
    await _open(widget.room, epoch: epoch);
  }

  /// Resolves [room]'s plan and opens its lowest tier.
  Future<void> _open(LiveRoom room, {int? epoch}) async {
    final at = epoch ?? ++_epoch;
    try {
      final site = ref.read(sitesProvider).getById(room.ref.platform);
      final capability = site?.capability<LivePlaybackProvider>();
      if (capability == null) return _giveUp();
      final qualities = await capability
          .getQualities(room: room)
          .then((answer) => answer.fold((_) => <LivePlayQuality>[], (qualities) => qualities));
      if (_stale(at)) return;
      // The lowest tier the site spells: the preview's picture is a glance,
      // not a viewing.
      final quality = qualities.isEmpty
          ? null
          : qualities[preferredQualityIndex(qualities.map((entry) => entry.label), kPreferredResolutionChoices.last)];
      _quality = quality;
      final lines = await _resolveLines(room, quality);
      if (_stale(at)) return;
      if (lines.isEmpty) return _giveUp();
      final playback = createRoomPlayback(kernel: ref.read(previewKernelProvider), onLinesNeeded: _refreshLines);
      _playback = playback;
      _handles = playback.onHandleChanged.listen((handle) {
        if (_stale(at) || handle.disposed) return;
        _handle = handle;
        // A preview never speaks, whatever the room's own audio rules say.
        unawaited(handle.setVolume(0));
        unawaited(handle.setMute(muted: true));
        if (mounted) setState(() {});
      });
      await playback.play(
        LiveSourceRequest(
          sources: roomSourcesOf(lines, title: room.content.title, artist: room.anchor?.name),
          title: room.content.title,
          allowEngineFallback: true,
          engineOptions: playerStoredEngineOptions(
            hardwareDecoding: ref.read(playbackSettingsProvider).hardwareDecoding,
            tuning: ref.read(playerTuningProvider),
            proxy: ref.read(playerProxyProvider),
          ),
        ),
        preferredBackend: ref.read(playerKernelBackendProvider).id,
      );
    } on Object {
      if (!_stale(at)) _giveUp();
    }
  }

  /// The site's lines for [quality], with a site-declared ingest relay in
  /// front of them (Bigo's scrambled HLS); the previous relay, if any, is
  /// closed once the new one stands.
  Future<List<LivePlayLine>> _resolveLines(LiveRoom room, LivePlayQuality? quality) async {
    final site = ref.read(sitesProvider).getById(room.ref.platform);
    final capability = site?.capability<LivePlaybackProvider>();
    if (capability == null) return const <LivePlayLine>[];
    final answer = await capability.getLines(room: room, quality: quality);
    final lines = answer.fold((_) => <LivePlayLine>[], (lines) => lines);
    if (lines.isEmpty || site == null || site.runtimeInfo.ingest == null) return lines;
    final ingest = await startLiveIngest(proxyRoute: () => ref.read(appProxyRouteProvider), site: site, line: lines.first);
    if (ingest == null) return lines;
    final previous = _ingest;
    _ingest = ingest;
    unawaited(previous?.close() ?? Future<void>.value());
    return [ingestedLine(lines.first, ingest.inputUri), ...lines.skip(1)];
  }

  /// Fresh lines for a recovery or an engine fallback: the same room, the
  /// same tier.
  Future<List<LivePlayLine>> _refreshLines() async {
    if (!mounted) return const <LivePlayLine>[];
    try {
      return await _resolveLines(widget.room, _quality);
    } on Object {
      return const <LivePlayLine>[];
    }
  }

  /// Nothing to play: the cover carries the card alone again.
  void _giveUp() {
    _failed = true;
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final handle = _handle;
    if (handle == null) {
      // Resolving: the cover stays under a small spinner. A room that could
      // not be opened leaves the cover alone.
      return _failed
          ? const SizedBox.shrink()
          : const Center(child: IgnorePointer(child: DsSpinner(style: DsSpinnerStyle(size: 20))));
    }
    // The card's tap opens the room: the preview is a picture only, never a
    // pointer's stop.
    return IgnorePointer(
      child: MediaPlayerView(handle: handle, fit: BoxFit.cover, backgroundColor: const Color(0x00000000), captureBoundary: false),
    );
  }
}
