import 'package:flutter/scheduler.dart' show Ticker;
import 'package:flutter/widgets.dart';

import 'package:pure_live/modules/hongguo/controller/hongguo_danmaku.dart';

/// Draws the episode's comments over the picture: each one starts when
/// playback reaches its moment and flies right-to-left on its own row.
///
/// The clock is the player's position, sampled every frame and interpolated
/// with the wall clock in between, so a paused picture freezes the comments
/// and a seek drops the ones that no longer belong to the moment.
final class HongguoDanmakuLayer extends StatefulWidget {
  /// Creates the layer over an episode's [items] (`(timeMs, text)`).
  const HongguoDanmakuLayer({
    required this.items,
    required this.positionMs,
    required this.playing,
    required this.settings,
    super.key,
  });

  /// The fetched comments, time-ordered.
  final List<(int, String)> items;

  /// Where playback is, in milliseconds.
  final int Function() positionMs;

  /// Whether playback is advancing.
  final bool Function() playing;

  /// The size, opacity, speed and density the comments use.
  final HongguoDanmakuSettings settings;

  @override
  State<HongguoDanmakuLayer> createState() => _HongguoDanmakuLayerState();
}

/// How long one comment takes to cross the picture at 1×.
const double _travelMs = 9000;

/// A seek is any jump the player makes beyond this.
const int _seekThresholdMs = 1500;

final class _Flight {
  _Flight({required this.lane, required this.spawnMs, required this.painter});

  final int lane;
  final int spawnMs;
  final TextPainter painter;

  double get width => painter.width;
}

final class _HongguoDanmakuLayerState extends State<HongguoDanmakuLayer> with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  final _planner = HongguoDanmakuPlanner();
  final _flights = <_Flight>[];
  final _frame = ValueNotifier<int>(0);

  var _cursor = 0;
  var _lastSample = 0;
  var _anchorMs = 0;
  Duration _anchorTick = Duration.zero;
  var _currentMs = 0;
  var _lanes = 1;
  double _travel = _travelMs;
  Size _size = Size.zero;
  Duration _lastElapsed = Duration.zero;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick)..start();
  }

  @override
  void didUpdateWidget(HongguoDanmakuLayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.items, widget.items)) _rewind();
  }

  @override
  void dispose() {
    _ticker.dispose();
    _frame.dispose();
    super.dispose();
  }

  void _rewind() {
    _flights.clear();
    _planner.reset();
    _lastSample = widget.positionMs();
    _anchorMs = _lastSample;
    _anchorTick = _lastElapsed;
    _currentMs = _lastSample;
    _cursor = _indexAt(_lastSample);
  }

  int _indexAt(int positionMs) {
    final index = widget.items.indexWhere((item) => item.$1 >= positionMs);
    return index < 0 ? widget.items.length : index;
  }

  void _onTick(Duration elapsed) {
    _lastElapsed = elapsed;
    final real = widget.positionMs();
    if ((real - _lastSample).abs() > _seekThresholdMs) {
      _rewind();
    } else if (real != _lastSample) {
      _lastSample = real;
      _anchorMs = real;
      _anchorTick = elapsed;
    }
    _currentMs = widget.playing() ? _anchorMs + (elapsed - _anchorTick).inMilliseconds : _anchorMs;
    _travel = _travelMs / widget.settings.speed;

    while (_cursor < widget.items.length && widget.items[_cursor].$1 <= _currentMs) {
      final (timeMs, text) = widget.items[_cursor++];
      final clean = text.trim();
      if (clean.isEmpty || _currentMs - timeMs > 2500) continue;
      final lane = _planner.laneFor(_currentMs, lanes: _lanes);
      if (lane == null) continue;
      final painter = TextPainter(
        text: TextSpan(text: clean, style: _style),
        textDirection: TextDirection.ltr,
        maxLines: 1,
      )..layout();
      if (painter.width <= 0) continue;
      _flights.add(_Flight(lane: lane, spawnMs: _currentMs, painter: painter));
    }

    if (_size.width > 0) {
      _flights.removeWhere((flight) => flight.painter.width + _xOf(flight) < -12);
    }
    _frame.value++;
  }

  double _xOf(_Flight flight) => _size.width - (_currentMs - flight.spawnMs) * (_size.width + flight.width) / _travel;

  TextStyle get _style => TextStyle(
    fontSize: widget.settings.fontSize,
    fontWeight: FontWeight.w600,
    color: Color.fromRGBO(255, 255, 255, widget.settings.opacity),
    shadows: const [
      Shadow(blurRadius: 2, color: Color(0xCC000000)),
      Shadow(blurRadius: 4, color: Color(0x99000000)),
    ],
  );

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        _size = constraints.biggest;
        _lanes = widget.settings.lanesFor(_size.height);
        return IgnorePointer(
          child: ClipRect(
            child: CustomPaint(
              size: Size.infinite,
              painter: _DanmakuPainter(
                flights: _flights,
                lineHeight: widget.settings.lineHeight,
                currentMs: () => _currentMs,
                xOf: _xOf,
                repaint: _frame,
              ),
            ),
          ),
        );
      },
    );
  }
}

final class _DanmakuPainter extends CustomPainter {
  _DanmakuPainter({
    required this.flights,
    required this.lineHeight,
    required this.currentMs,
    required this.xOf,
    required super.repaint,
  });

  final List<_Flight> flights;
  final double lineHeight;
  final int Function() currentMs;
  final double Function(_Flight flight) xOf;

  @override
  void paint(Canvas canvas, Size size) {
    for (final flight in flights) {
      flight.painter.paint(canvas, Offset(xOf(flight), flight.lane * lineHeight + 6));
    }
  }

  @override
  bool shouldRepaint(_DanmakuPainter oldDelegate) =>
      currentMs() != oldDelegate.currentMs() || flights.length != oldDelegate.flights.length;
}
