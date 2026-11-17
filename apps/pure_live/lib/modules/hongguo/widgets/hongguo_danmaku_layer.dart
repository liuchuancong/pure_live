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

  /// Per lane, the (spawn, width) of the runner still on it — the chase
  /// guard's memory. Cleared with the sky.
  final Map<int, ({int spawnMs, double width})> _laneLast = {};

  /// The gap a lane keeps between the runner ahead and the next word.
  static const double _chaseGapPx = 24;
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
    _syncTicker();
  }

  @override
  void dispose() {
    _ticker.dispose();
    // Every flight carries a laid-out paragraph; dropping the references
    // alone leaves them to the finalizer.
    for (final flight in _flights) {
      flight.painter.dispose();
    }
    _flights.clear();
    _frame.dispose();
    super.dispose();
  }

  /// The ticker only runs while it has work: a paused sky with nothing in
  /// it (or a take whose words are all past) stops the frame pump, and a
  /// play, a seek or new words arm it again. The paused early return below
  /// stays as the belt for the frames before the stop lands.
  void _syncTicker() {
    final wanted = widget.playing() || _flights.isNotEmpty || _cursor < widget.items.length;
    if (wanted && !_ticker.isActive) {
      _ticker.start();
      // The anchor re-reads the position: a stopped period's elapsed book
      // keeping is stale by definition, and the flights are empty here by
      // the same fact that stopped the ticker.
      _rewind();
    } else if (!wanted && _ticker.isActive) {
      _ticker.stop();
      _frame.value++;
    }
  }

  void _rewind() {
    for (final flight in _flights) {
      flight.painter.dispose();
    }
    _flights.clear();
    _laneLast.clear();
    _planner.reset();
    _lastSample = widget.positionMs();
    _anchorMs = _lastSample;
    _anchorTick = _lastElapsed;
    _currentMs = _lastSample;
    _cursor = _indexAt(_lastSample);
    // The cleared sky must reach the screen even while the ticks are frozen.
    _frame.value++;
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
    // Paused with an empty sky and nothing left to spawn: the last frame
    // these ticks drew is the frame they would draw, so stop paying for
    // them. A seek rewinds (and bumps the frame below) even while paused,
    // so a jumped-to position still shows its own words.
    if (!widget.playing() && _flights.isEmpty && _cursor >= widget.items.length) return;
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
      // A wider word flies faster on this layer's fixed travel time, so a
      // lane that only looked at spawn times lets the fast one catch the
      // slow one it follows and the two overlap for seconds. The lane
      // stands down until the runner ahead has cleared its own length.
      final last = _laneLast[lane];
      if (last != null) {
        final speed = (_size.width + last.width) / _travel;
        if ((_currentMs - last.spawnMs) * speed < last.width + _chaseGapPx) {
          painter.dispose();
          continue;
        }
      }
      _laneLast[lane] = (spawnMs: _currentMs, width: painter.width);
      _flights.add(_Flight(lane: lane, spawnMs: _currentMs, painter: painter));
    }

    if (_size.width > 0) {
      _flights.removeWhere((flight) {
        final gone = flight.painter.width + _xOf(flight) < -12;
        if (gone) flight.painter.dispose();
        return gone;
      });
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
