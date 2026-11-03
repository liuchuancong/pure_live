import 'dart:async' show Timer;

import 'package:desen_ui/desen_ui.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_core/media_core.dart';
import 'package:pure_live/l10n/translations.dart';
import 'package:pure_live/shared/player/player_overlay.dart' show playerInk, playerInkMuted;

/// Whether a player surface shows its playback statistics.
///
/// A view preference, not a saved setting: whoever wants the numbers turns them
/// on for the surface in front and the next one in the same session starts
/// plain. The room toggles it with `I` and in its overflow menu; the media
/// preview carries the verb on its bar.
final playerStatsVisibleProvider = NotifierProvider<PlayerStatsVisibleController, bool>(
  PlayerStatsVisibleController.new,
);

/// Owns [playerStatsVisibleProvider].
final class PlayerStatsVisibleController extends Notifier<bool> {
  @override
  bool build() => false;

  /// Flips the panel; answers the new state.
  bool toggle() => state = !state;
}

/// The stream's own numbers over the picture: resolution, frame rate, bitrate,
/// buffer, dropped frames, the decoder and renderer in use, and the process
/// cost — everything a viewer reaches for when a stream looks wrong.
///
/// It polls the handle once a second while visible rather than listening to a
/// metrics stream: not every adapter emits one, and a number that updates once a
/// second is what the eye can read anyway. Frame rate is derived from two
/// consecutive readings, so a backend that reports counters and not fps still
/// gets an honest figure.
final class PlayerStatsOverlay extends StatefulWidget {
  /// Shows [handle]'s live statistics.
  const PlayerStatsOverlay({required this.handle, super.key});

  /// The player whose numbers are shown.
  final PlayerHandle handle;

  @override
  State<PlayerStatsOverlay> createState() => _PlayerStatsOverlayState();
}

final class _PlayerStatsOverlayState extends State<PlayerStatsOverlay> {
  Timer? _ticker;
  PlayerAdapterMetrics? _metrics;
  int? _width;
  int? _height;
  double? _fps;
  DateTime? _lastAt;
  int? _lastRendered;

  @override
  void initState() {
    super.initState();
    _read();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _read());
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  void _read() {
    if (!mounted) return;
    final handle = widget.handle;
    if (handle.disposed) {
      _ticker?.cancel();
      return;
    }
    final metrics = handle.metrics;
    final geometry = handle.combinedSnapshot.geometry;
    final now = DateTime.now();
    final rendered = metrics.renderedFrames;
    var fps = _fps;
    if (_lastAt != null && _lastRendered != null && rendered >= _lastRendered!) {
      final seconds = now.difference(_lastAt!).inMilliseconds / 1000;
      if (seconds > 0.2) fps = (rendered - _lastRendered!) / seconds;
    }
    setState(() {
      _metrics = metrics;
      _width = geometry.hasVideo ? geometry.geometry.videoSize.width : null;
      _height = geometry.hasVideo ? geometry.geometry.videoSize.height : null;
      _fps = fps;
      _lastAt = now;
      _lastRendered = rendered;
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final theme = DsTheme.of(context);
    final metrics = _metrics;
    if (metrics == null) return const SizedBox.shrink();
    final rows = <(String, String)>[
      (
        t.room.statsPicture,
        _width == null || _height == null
            ? '—'
            : '${_width!}×${_height!}${_fps == null ? '' : ' · ${_fps!.toStringAsFixed(0)} fps'}',
      ),
      (t.room.statsBitrate, _bitrate(metrics)),
      (t.room.statsBuffer, _buffer(metrics)),
      (t.room.statsDropped, _dropped(metrics)),
      if ((metrics.decoder ?? '').isNotEmpty) (t.room.statsDecoder, metrics.decoder!),
      if ((metrics.renderer ?? '').isNotEmpty) (t.room.statsRenderer, metrics.renderer!),
      (t.room.statsProcess, _process(metrics)),
      (t.room.statsBackend, widget.handle.backendId),
    ];
    return IgnorePointer(
      child: Container(
        width: 244,
        padding: const EdgeInsets.symmetric(horizontal: DsSpace.s12, vertical: DsSpace.s8),
        decoration: BoxDecoration(
          // The player's own glass, the same ink the bars use: over a picture the
          // app's theme has nothing to say.
          color: const Color(0xCC0B0D12),
          borderRadius: BorderRadius.circular(theme.radii.card),
          border: Border.all(color: const Color(0x26FFFFFF)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: DsSpace.s3,
          children: [
            for (final (label, value) in rows)
              Row(
                children: [
                  Expanded(
                    child: Text(label, style: theme.typography.caption.copyWith(color: playerInkMuted)),
                  ),
                  Text(value, style: theme.typography.numeric(theme.typography.caption.copyWith(color: playerInk))),
                ],
              ),
          ],
        ),
      ),
    );
  }

  static String _bitrate(PlayerAdapterMetrics metrics) {
    final bitrate = metrics.bitrate;
    if (bitrate == null || bitrate <= 0) return '—';
    final bandwidth = metrics.bandwidth;
    final head = _megabits(bitrate);
    return bandwidth == null || bandwidth <= 0 ? head : '$head · ${_megabits(bandwidth)}';
  }

  static String _megabits(int bitsPerSecond) => '${(bitsPerSecond / 1000000).toStringAsFixed(2)} Mbps';

  static String _buffer(PlayerAdapterMetrics metrics) {
    final video = metrics.videoBuffered;
    final audio = metrics.audioBuffered;
    if (video == null && audio == null) return '—';
    String seconds(Duration? value) => value == null ? '—' : '${(value.inMilliseconds / 1000).toStringAsFixed(1)}s';
    return '${seconds(video)} · ${seconds(audio)}';
  }

  static String _dropped(PlayerAdapterMetrics metrics) {
    final dropped = metrics.droppedFrames;
    final rendered = metrics.renderedFrames;
    if (rendered <= 0) return '$dropped';
    final ratio = dropped / rendered;
    return '$dropped · ${(ratio * 100).toStringAsFixed(ratio < 0.001 ? 2 : 1)}%';
  }

  static String _process(PlayerAdapterMetrics metrics) {
    final cpu = metrics.cpuUsage;
    final memory = metrics.memoryUsage;
    final parts = <String>[
      if (cpu != null) 'cpu ${(cpu * 100).toStringAsFixed(0)}%',
      if (memory != null && memory > 0) '${(memory / (1024 * 1024)).toStringAsFixed(0)} MB',
    ];
    return parts.isEmpty ? '—' : parts.join(' · ');
  }
}
