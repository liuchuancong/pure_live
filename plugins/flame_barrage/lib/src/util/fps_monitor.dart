import 'package:flutter/scheduler.dart';

typedef FpsCallback = void Function(double fps);

class FpsMonitor {
  FpsMonitor({this.sampleDuration = const Duration(seconds: 1)});

  final Duration sampleDuration;
  FpsCallback? _onFpsUpdated;
  bool _isListening = false;

  final List<double> _frameTimestamps = [];

  void start(FpsCallback onFpsUpdated) {
    if (_isListening) return;
    _onFpsUpdated = onFpsUpdated;
    _isListening = true;
    _frameTimestamps.clear();

    SchedulerBinding.instance.addPostFrameCallback(_onHardwareTick);
  }

  void stop() {
    _isListening = false;
    _onFpsUpdated = null;
    _frameTimestamps.clear();
  }

  void _onHardwareTick(Duration timestamp) {
    if (!_isListening) return;

    final double currentMs = timestamp.inMicroseconds / 1000.0;
    _frameTimestamps.add(currentMs);

    final double windowStartMs = currentMs - sampleDuration.inMilliseconds;
    _frameTimestamps.removeWhere((t) => t < windowStartMs);

    if (_frameTimestamps.length >= 2) {
      final int frameCount = _frameTimestamps.length;
      final double totalDurationSec = (_frameTimestamps.last - _frameTimestamps.first) / 1000.0;

      if (totalDurationSec > 0) {
        final double realHardwareFps = (frameCount - 1) / totalDurationSec;
        _onFpsUpdated?.call(realHardwareFps.clamp(0.0, 144.0));
      }
    }

    if (_isListening) {
      SchedulerBinding.instance.addPostFrameCallback(_onHardwareTick);
    }
  }
}
