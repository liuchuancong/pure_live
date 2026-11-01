import 'dart:async' show StreamSubscription, unawaited;
import 'dart:math' as math;
import 'dart:typed_data' show Float32List;

import 'package:desen_ui/desen_ui.dart';
import 'package:flutter/foundation.dart' show ValueListenable, ValueNotifier;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_core_mpv_audio/media_core_mpv_audio.dart' show FftFrame, PcmFrame;
import 'package:pure_live/modules/music/controller/music_playback.dart' show musicPlayerProvider;
import 'package:pure_live/modules/music/controller/music_ui_settings.dart'
    show MusicSpectrumStyle, MusicUiElement, musicUiSettingsProvider;

/// The stage's live visualiser: the engine's own taps, drawn as bars, a
/// ring, or a wave.
///
/// Frames only reach the painter — a [ValueNotifier] drives the repaint, so
/// a 30 Hz tap never rebuilds the stage around it. Silence (paused, muted,
/// or no audio yet) settles to a still baseline instead of freezing the
/// last frame, because a picture of sound that is not sounding is a lie.
final class MusicSpectrum extends ConsumerStatefulWidget {
  /// The visualiser.
  const MusicSpectrum({super.key});

  @override
  ConsumerState<MusicSpectrum> createState() => _MusicSpectrumState();
}

/// Peak buckets kept per PCM frame: smooth on a wide stage, cheap at 30 Hz.
const int _waveColumns = 96;

final class _MusicSpectrumState extends ConsumerState<MusicSpectrum> {
  final ValueNotifier<_SpectrumSamples?> _samples = ValueNotifier(null);

  StreamSubscription<FftFrame>? _fftSub;
  StreamSubscription<PcmFrame>? _pcmSub;
  Stream<FftFrame>? _fftSource;
  Stream<PcmFrame>? _pcmSource;

  @override
  void dispose() {
    unawaited(_fftSub?.cancel() ?? Future<void>.value());
    unawaited(_pcmSub?.cancel() ?? Future<void>.value());
    _samples.dispose();
    super.dispose();
  }

  void _publish(_SpectrumSamples? next) {
    if (mounted) _samples.value = next;
  }

  /// Subscribes to exactly the tap the current style draws, and leaves the
  /// other unsubscribed: the engine only computes the taps someone listens
  /// to. Passing neither detaches both (hidden, or no engine yet).
  void _bind({Stream<FftFrame>? fft, Stream<PcmFrame>? pcm}) {
    if (!identical(fft, _fftSource)) {
      unawaited(_fftSub?.cancel() ?? Future<void>.value());
      _fftSub = null;
      _fftSource = fft;
      _publish(null);
      if (fft != null) {
        _fftSub = fft.listen(
          (frame) => _publish(_SpectrumSamples(bands: frame.bands)),
          onError: (Object _) => _publish(null),
          onDone: () => _publish(null),
        );
      }
    }
    if (!identical(pcm, _pcmSource)) {
      unawaited(_pcmSub?.cancel() ?? Future<void>.value());
      _pcmSub = null;
      _pcmSource = pcm;
      _publish(null);
      if (pcm != null) {
        _pcmSub = pcm.listen(
          (frame) => _publish(_SpectrumSamples(peaks: _peaks(frame))),
          onError: (Object _) => _publish(null),
          onDone: () => _publish(null),
        );
      }
    }
    if (fft == null && pcm == null) _publish(null);
  }

  /// One peak per column over the frame's first channel. Each frame holds
  /// the latest output, not the next slice, so peaks — not samples — are
  /// what a scrolling picture can honestly show.
  static Float32List _peaks(PcmFrame frame) {
    final channels = frame.channels <= 0 ? 1 : frame.channels;
    final frames = frame.samples.length ~/ channels;
    if (frames == 0) return Float32List(0);
    final columns = math.min(_waveColumns, frames);
    final peaks = Float32List(columns);
    for (var column = 0; column < columns; column++) {
      final start = column * frames ~/ columns;
      final end = math.max(start + 1, (column + 1) * frames ~/ columns);
      var peak = 0.0;
      for (var i = start; i < end && i < frames; i++) {
        final value = frame.samples[i * channels].abs();
        if (value > peak) peak = value;
      }
      peaks[column] = peak > 1 ? 1 : peak;
    }
    return peaks;
  }

  @override
  Widget build(BuildContext context) {
    final ui = ref.watch(musicUiSettingsProvider);
    if (!ui.shows(MusicUiElement.spectrum)) {
      _bind();
      return const SizedBox.shrink();
    }
    // A state watch re-runs this when the engine appears or is replaced and
    // when the listener pauses or mutes — exactly when the taps or the
    // quiet verdict change.
    final player = ref.watch(musicPlayerProvider);
    final controller = ref.read(musicPlayerProvider.notifier);
    final wantsWave = ui.spectrumStyle == MusicSpectrumStyle.wave;
    final fft = wantsWave ? null : controller.spectrum;
    final pcm = wantsWave ? controller.waveform : null;
    // A backend without taps leaves the stage exactly as it was.
    if ((wantsWave ? pcm : fft) == null) {
      _bind();
      return const SizedBox.shrink();
    }
    _bind(fft: fft, pcm: pcm);
    final colors = DsTheme.colorsOf(context);
    return SizedBox(
      height: ui.spectrumStyle == MusicSpectrumStyle.circle ? 104 : 44,
      width: double.infinity,
      child: CustomPaint(
        painter: _SpectrumPainter(
          samples: _samples,
          style: ui.spectrumStyle,
          color: colors.accent,
          quietColor: colors.textSubtle,
          quiet: !player.playing || player.muted,
        ),
      ),
    );
  }
}

/// The frame the painter reads, either FFT bands or PCM peaks.
final class _SpectrumSamples {
  const _SpectrumSamples({this.bands, this.peaks});

  final Float32List? bands;
  final Float32List? peaks;
}

/// Draws the current frame; [samples] drives repaints, so no build is
/// involved as frames arrive.
final class _SpectrumPainter extends CustomPainter {
  _SpectrumPainter({
    required this.samples,
    required this.style,
    required this.color,
    required this.quietColor,
    required this.quiet,
  }) : super(repaint: samples);

  final ValueListenable<_SpectrumSamples?> samples;
  final MusicSpectrumStyle style;
  final Color color;
  final Color quietColor;
  final bool quiet;

  static const double _pad = 2;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final data = samples.value;
    final values = style == MusicSpectrumStyle.wave ? data?.peaks : data?.bands;
    if (quiet || values == null || values.isEmpty) {
      _paintQuiet(canvas, size);
      return;
    }
    switch (style) {
      case MusicSpectrumStyle.bars:
        _paintBars(canvas, size, values);
      case MusicSpectrumStyle.circle:
        _paintCircle(canvas, size, values);
      case MusicSpectrumStyle.wave:
        _paintWave(canvas, size, values);
    }
  }

  /// One bar per band, bottom-aligned, rounded caps.
  void _paintBars(Canvas canvas, Size size, Float32List bands) {
    final paint = Paint()
      ..color = color
      ..strokeCap = StrokeCap.round;
    final count = bands.length;
    final gap = size.width / (count * 4);
    final barWidth = (size.width - gap * (count + 1)) / count;
    final available = size.height - _pad * 2;
    for (var i = 0; i < count; i++) {
      final height = bands[i].clamp(0.0, 1.0) * available;
      if (height < 0.5) continue;
      final left = gap + i * (barWidth + gap) + barWidth / 2;
      canvas.drawLine(
        Offset(left, size.height - _pad),
        Offset(left, size.height - _pad - height),
        paint..strokeWidth = barWidth,
      );
    }
  }

  /// The same bands as spokes growing inward from a ring.
  void _paintCircle(Canvas canvas, Size size, Float32List bands) {
    final center = size.center(Offset.zero);
    final radius = math.min(size.width, size.height) / 2 - _pad * 3;
    if (radius <= 0) return;
    final count = bands.length;
    final sweep = math.pi * 2 / count;
    final paint = Paint()
      ..color = color
      ..strokeCap = StrokeCap.round;
    final thickness = math.max(1.5, radius * sweep * 0.4);
    for (var i = 0; i < count; i++) {
      final value = bands[i].clamp(0.0, 1.0);
      final length = radius * 0.6 * value;
      if (length < 0.5) continue;
      final angle = -math.pi / 2 + i * sweep;
      final near = center + Offset(math.cos(angle), math.sin(angle)) * (radius - length);
      final far = center + Offset(math.cos(angle), math.sin(angle)) * radius;
      canvas.drawLine(near, far, paint..strokeWidth = thickness);
    }
  }

  /// The PCM peaks mirrored around the centreline, filled faintly.
  void _paintWave(Canvas canvas, Size size, Float32List peaks) {
    final count = peaks.length;
    if (count == 0) return;
    final middle = size.height / 2;
    final amplitude = middle - _pad;
    double x(int index) => count == 1 ? size.width / 2 : index * size.width / (count - 1);
    double top(int index) => middle - peaks[index].clamp(0.0, 1.0) * amplitude;
    double bottom(int index) => middle + (middle - top(index));

    final outline = Path()..moveTo(x(0), top(0));
    for (var i = 1; i < count; i++) {
      outline.lineTo(x(i), top(i));
    }
    for (var i = count - 1; i >= 0; i--) {
      outline.lineTo(x(i), bottom(i));
    }
    outline.close();
    canvas.drawPath(outline, Paint()..color = color.withValues(alpha: 0.22));

    final stroke = Paint()
      ..color = color
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    final upper = Path()..moveTo(x(0), top(0));
    final lower = Path()..moveTo(x(0), bottom(0));
    for (var i = 1; i < count; i++) {
      upper.lineTo(x(i), top(i));
      lower.lineTo(x(i), bottom(i));
    }
    canvas
      ..drawPath(upper, stroke)
      ..drawPath(lower, stroke);
  }

  /// The still shape of each style at rest: no data, paused, or muted.
  void _paintQuiet(Canvas canvas, Size size) {
    final paint = Paint()..color = quietColor.withValues(alpha: 0.4);
    switch (style) {
      case MusicSpectrumStyle.bars:
        paint
          ..strokeWidth = 2
          ..strokeCap = StrokeCap.round;
        final y = size.height - _pad;
        canvas.drawLine(Offset(_pad, y), Offset(size.width - _pad, y), paint);
      case MusicSpectrumStyle.circle:
        paint
          ..strokeWidth = 1.5
          ..style = PaintingStyle.stroke;
        final radius = math.min(size.width, size.height) / 2 - _pad * 3;
        if (radius > 0) canvas.drawCircle(size.center(Offset.zero), radius, paint);
      case MusicSpectrumStyle.wave:
        paint
          ..strokeWidth = 2
          ..strokeCap = StrokeCap.round;
        final y = size.height / 2;
        canvas.drawLine(Offset(_pad, y), Offset(size.width - _pad, y), paint);
    }
  }

  @override
  bool shouldRepaint(_SpectrumPainter old) =>
      old.style != style || old.color != color || old.quietColor != quietColor || old.quiet != quiet;
}
