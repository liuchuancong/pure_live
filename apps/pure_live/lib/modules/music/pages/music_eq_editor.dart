import 'dart:async' show unawaited;
import 'dart:math' as math;

import 'package:desen_ui/desen_ui.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:pure_live/l10n/translations.dart';
import 'package:pure_live/modules/music/controller/eq/music_eq_config.dart';
import 'package:pure_live/modules/music/controller/eq/music_eq_dsp.dart';

/// The ten-band graphic equalizer: the predicted response curve drawn over
/// the bands, each band a vertical drag handle.
///
/// The curve is the theory layer's prediction, recomputed from the same
/// configuration the handles show — the two cannot drift apart because
/// neither holds state. Dragging asks the controller for the new gain and
/// the curve follows on the rebuild; the band being dragged reads its gain
/// in a chip above the knob, and a double tap brings a band back to zero.
final class MusicEqEditor extends ConsumerWidget {
  /// The editor shown inside the sound-effect page.
  const MusicEqEditor({super.key});

  /// The horizontal axis label: kHz above a thousand, Hz below.
  static String bandLabel(double frequency) =>
      frequency >= 1000 ? '${(frequency / 1000).toStringAsFixed(0)}k' : frequency.toStringAsFixed(0);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    final colors = DsTheme.colorsOf(context);
    final theme = DsTheme.of(context);
    final eq = ref.watch(musicEqProvider);
    final controller = ref.read(musicEqProvider.notifier);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: DsSpace.s8,
      children: [
        SizedBox(
          height: 180,
          child: _EqBoard(eq: eq, onBandChanged: (band, gain) => unawaited(controller.setGain(band, gain))),
        ),
        Row(
          children: [
            for (final frequency in kMusicEqFrequencies)
              Expanded(
                child: Center(
                  child: Text(bandLabel(frequency), style: theme.typography.caption.copyWith(color: colors.textMuted)),
                ),
              ),
          ],
        ),
        Text(t.music.eqHint, style: theme.typography.caption.copyWith(color: colors.textMuted)),
      ],
    );
  }
}

/// The curve and the band handles share one board: the graph is painted from
/// the configuration, and a gesture column per band turns vertical drags
/// into gain changes. The board owns the one fact the painters cannot hold —
/// which band a finger is on — and hands it to that band's column, so its
/// knob reads its gain and wears the focus ring.
final class _EqBoard extends ConsumerStatefulWidget {
  const _EqBoard({required this.eq, required this.onBandChanged});

  final MusicEqConfig eq;
  final void Function(int band, double gain) onBandChanged;

  @override
  ConsumerState<_EqBoard> createState() => _EqBoardState();
}

final class _EqBoardState extends ConsumerState<_EqBoard> {
  /// The band a finger is on now; null between gestures.
  int? _dragBand;

  @override
  Widget build(BuildContext context) {
    final colors = DsTheme.colorsOf(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);
        return Stack(
          children: [
            Positioned.fill(
              child: CustomPaint(
                painter: _EqCurvePainter(eq: widget.eq, colors: colors),
              ),
            ),
            Positioned.fill(
              child: Row(
                children: [
                  for (var band = 0; band < kMusicEqFrequencies.length; band++)
                    Expanded(
                      child: _EqBandHandle(
                        gain: widget.eq.gains[band],
                        size: size,
                        colors: colors,
                        enabled: widget.eq.enabled,
                        dragging: _dragBand == band,
                        onDragState: (active) => setState(() => _dragBand = active ? band : null),
                        onChanged: (gain) => widget.onBandChanged(band, gain),
                      ),
                    ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

/// The predicted response, drawn in the log-frequency domain the octave-spaced
/// bands themselves live in: 31 Hz and 16 kHz pin the edges, so every band
/// centre lands evenly spaced and the handles sit on their own curve points.
final class _EqCurvePainter extends CustomPainter {
  const _EqCurvePainter({required this.eq, required this.colors});

  final MusicEqConfig eq;
  final DsColors colors;

  static const double _minFreq = 31;
  static const double _maxFreq = 16000;

  @override
  void paint(Canvas canvas, Size size) {
    final grid = Paint()
      ..color = colors.border
      ..strokeWidth = 1;

    // Horizontal grid at ±6/±12 dB, the zero line heavier.
    for (final db in <double>[-12, -6, 0, 6, 12]) {
      final y = _yOf(db, size.height);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }

    if (!eq.enabled) return;

    final curve = musicEqResponseCurve(eq);
    final path = Path();
    var started = false;
    for (final point in curve) {
      final clamped = point.frequency.clamp(_minFreq, _maxFreq);
      final x = _xOf(clamped, size.width);
      final y = _yOf(point.gainDb, size.height);
      if (!started) {
        path.moveTo(x, y);
        started = true;
      } else {
        path.lineTo(x, y);
      }
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = colors.accent
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }

  static double _xOf(double frequency, double width) {
    final span = math.log(_maxFreq / _minFreq);
    return (math.log(frequency / _minFreq) / span) * width;
  }

  static double _yOf(double gainDb, double height) =>
      height * (1 - (gainDb - kMusicEqMinGain) / (kMusicEqMaxGain - kMusicEqMinGain));

  @override
  bool shouldRepaint(_EqCurvePainter oldDelegate) => oldDelegate.eq != eq;
}

/// One band's drag column: a faint track and the knob, mapped top-to-bottom
/// over the gain range. A drag reports continuously so the curve and the
/// chain follow the finger; while it lasts the band reads its gain in a chip
/// above the knob and the knob carries the focus ring. A double tap brings
/// the band back to zero — the reset every band editor offers.
final class _EqBandHandle extends StatelessWidget {
  const _EqBandHandle({
    required this.gain,
    required this.size,
    required this.colors,
    required this.enabled,
    required this.dragging,
    required this.onDragState,
    required this.onChanged,
  });

  final double gain;
  final Size size;
  final DsColors colors;
  final bool enabled;

  /// Whether this column is the finger's band — the chip and the ring ride
  /// on it.
  final bool dragging;

  /// Raises and lowers this band's finger state on the board.
  final ValueChanged<bool> onDragState;

  final ValueChanged<double> onChanged;

  static const double _knobRadius = 6;

  double _yOf(double value, double height) =>
      height * (1 - (value - kMusicEqMinGain) / (kMusicEqMaxGain - kMusicEqMinGain));

  double _gainOf(double y, double height) => (kMusicEqMinGain + (1 - y / height) * (kMusicEqMaxGain - kMusicEqMinGain))
      .clamp(kMusicEqMinGain, kMusicEqMaxGain);

  /// The gain as the chip says it: a sign and one decimal, the axis's own
  /// unit implied.
  String get _label => '${gain > 0 ? '+' : ''}${gain.toStringAsFixed(1)}';

  @override
  Widget build(BuildContext context) {
    final theme = DsTheme.of(context);
    final y = _yOf(gain, size.height);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onVerticalDragStart: enabled
          ? (details) {
              onDragState(true);
              onChanged(_gainOf(details.localPosition.dy, size.height));
            }
          : null,
      onVerticalDragUpdate: enabled ? (details) => onChanged(_gainOf(details.localPosition.dy, size.height)) : null,
      onVerticalDragEnd: enabled ? (_) => onDragState(false) : null,
      onVerticalDragCancel: enabled ? () => onDragState(false) : null,
      onTapDown: enabled ? (details) => onChanged(_gainOf(details.localPosition.dy, size.height)) : null,
      onDoubleTap: enabled ? () => onChanged(0) : null,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          CustomPaint(
            size: Size.infinite,
            painter: _BandPainter(
              knobY: y,
              knobRadius: _knobRadius,
              colors: colors,
              enabled: enabled,
              dragging: dragging,
            ),
          ),
          // The dragged band's own reading: one chip above the knob, kept on
          // the board even when the knob nears its top edge.
          if (dragging)
            Positioned(
              left: 0,
              right: 0,
              top: math.max(0, y - 30),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: DsSpace.s6, vertical: 2),
                  decoration: DsBoxDecoration(
                    color: colors.accentTint,
                    borderRadius: BorderRadius.circular(theme.radii.control(20)),
                  ),
                  child: Text(
                    _label,
                    style: theme.typography.numeric(
                      theme.typography.caption.copyWith(color: colors.accentText, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// The knob and its vertical track, painted in the band's own column; the
/// finger's band draws a ring around its knob.
final class _BandPainter extends CustomPainter {
  const _BandPainter({
    required this.knobY,
    required this.knobRadius,
    required this.colors,
    required this.enabled,
    required this.dragging,
  });

  final double knobY;
  final double knobRadius;
  final DsColors colors;
  final bool enabled;
  final bool dragging;

  @override
  void paint(Canvas canvas, Size size) {
    final track = Paint()
      ..color = colors.border
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    final x = size.width / 2;
    canvas.drawLine(Offset(x, 8), Offset(x, size.height - 8), track);

    final knobY = this.knobY.clamp(8.0, size.height - 8.0);
    final knobPaint = Paint()..color = enabled ? colors.accent : colors.border;
    if (dragging) {
      // The finger's band: a tinted halo under the knob and the ring around
      // it — one column visibly held, the other nine quiet.
      final halo = Offset(x, knobY);
      canvas.drawCircle(halo, _dragRadius, Paint()..color = colors.accentTint);
      canvas.drawCircle(
        halo,
        _dragRadius,
        Paint()
          ..color = colors.accent
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
    }
    canvas.drawCircle(Offset(x, knobY), knobRadius, knobPaint);
  }

  /// The focus ring's radius: a knob that grows a little under the finger.
  static const double _dragRadius = 10;

  @override
  bool shouldRepaint(_BandPainter oldDelegate) =>
      oldDelegate.knobY != knobY || oldDelegate.enabled != enabled || oldDelegate.dragging != dragging;
}
