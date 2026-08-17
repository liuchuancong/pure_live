// GestureDetector callbacks are void and return futures that are intentionally not awaited
// ignore_for_file: cascade_invocations, discarded_futures

import 'dart:async';
import 'package:better_player_plus/src/controls/better_player_progress_colors.dart';
import 'package:better_player_plus/src/core/better_player_controller.dart';
import 'package:better_player_plus/src/video_player/video_player.dart';
import 'package:better_player_plus/src/video_player/video_player_platform_interface.dart';
import 'package:flutter/material.dart';

class BetterPlayerCupertinoVideoProgressBar extends StatefulWidget {
  BetterPlayerCupertinoVideoProgressBar(
    this.controller,
    this.betterPlayerController, {
    BetterPlayerProgressColors? colors,
    this.onDragEnd,
    this.onDragStart,
    this.onDragUpdate,
    this.onTapDown,
    super.key,
  }) : colors = colors ?? BetterPlayerProgressColors();

  final VideoPlayerController? controller;
  final BetterPlayerController? betterPlayerController;
  final BetterPlayerProgressColors colors;
  final void Function()? onDragStart;
  final void Function()? onDragEnd;
  final void Function()? onDragUpdate;
  final void Function()? onTapDown;

  @override
  State<BetterPlayerCupertinoVideoProgressBar> createState() => _VideoProgressBarState();
}

class _VideoProgressBarState extends State<BetterPlayerCupertinoVideoProgressBar> {
  _VideoProgressBarState() {
    listener = () {
      if (mounted) {
        setState(() {});
      }
    };
  }

  late VoidCallback listener;
  bool _controllerWasPlaying = false;

  VideoPlayerController? get controller => widget.controller;

  BetterPlayerController? get betterPlayerController => widget.betterPlayerController;

  bool shouldPlayAfterDragEnd = false;
  Duration? lastSeek;
  Timer? _updateBlockTimer;

  @override
  void initState() {
    super.initState();
    controller!.addListener(listener);
  }

  @override
  void deactivate() {
    controller!.removeListener(listener);
    _cancelUpdateBlockTimer();
    super.deactivate();
  }

  @override
  Widget build(BuildContext context) {
    final bool enableProgressBarDrag = betterPlayerController!.betterPlayerControlsConfiguration.enableProgressBarDrag;
    return GestureDetector(
      onHorizontalDragStart: (DragStartDetails details) {
        if (!controller!.value.initialized || !enableProgressBarDrag) {
          return;
        }
        _controllerWasPlaying = controller!.value.isPlaying;
        if (_controllerWasPlaying) {
          controller!.pause();
        }

        if (widget.onDragStart != null) {
          widget.onDragStart!.call();
        }
      },
      onHorizontalDragUpdate: (DragUpdateDetails details) async {
        if (!controller!.value.initialized || !enableProgressBarDrag) {
          return;
        }
        await seekToRelativePosition(details.globalPosition);

        if (widget.onDragUpdate != null) {
          widget.onDragUpdate!.call();
        }
      },
      onHorizontalDragEnd: (DragEndDetails details) {
        if (!enableProgressBarDrag) {
          return;
        }
        if (_controllerWasPlaying) {
          betterPlayerController?.play();
          shouldPlayAfterDragEnd = true;
        }
        _setupUpdateBlockTimer();

        if (widget.onDragEnd != null) {
          widget.onDragEnd!.call();
        }
      },
      onTapDown: (TapDownDetails details) {
        if (!controller!.value.initialized || !enableProgressBarDrag) {
          return;
        }

        unawaited(seekToRelativePosition(details.globalPosition));
        _setupUpdateBlockTimer();
        if (widget.onTapDown != null) {
          widget.onTapDown!.call();
        }
      },
      child: Center(
        child: Container(
          width: MediaQuery.sizeOf(context).width,
          height: MediaQuery.sizeOf(context).height,
          color: Colors.transparent,
          child: CustomPaint(painter: _ProgressBarPainter(_getValue(), widget.colors)),
        ),
      ),
    );
  }

  void _setupUpdateBlockTimer() {
    _updateBlockTimer = Timer(const Duration(milliseconds: 1000), () {
      lastSeek = null;
      _cancelUpdateBlockTimer();
    });
  }

  void _cancelUpdateBlockTimer() {
    _updateBlockTimer?.cancel();
    _updateBlockTimer = null;
  }

  VideoPlayerValue _getValue() {
    if (lastSeek != null) {
      return controller!.value.copyWith(position: lastSeek);
    } else {
      return controller!.value;
    }
  }

  Future<void> seekToRelativePosition(Offset globalPosition) async {
    final RenderObject? renderObject = context.findRenderObject();
    if (renderObject != null) {
      final box = renderObject as RenderBox;
      final duration = controller!.value.duration;
      if (duration == null || duration.inMilliseconds <= 0 || box.size.width <= 0) {
        return;
      }
      final Offset tapPos = box.globalToLocal(globalPosition);
      final double relative = (tapPos.dx / box.size.width).clamp(0.0, 1.0);
      if (relative > 0) {
        final Duration position = duration * relative;
        lastSeek = position;
        await betterPlayerController!.seekTo(position);
        onFinishedLastSeek();
        if (relative >= 1) {
          lastSeek = duration;
          await betterPlayerController!.seekTo(duration);
          onFinishedLastSeek();
        }
      }
    }
  }

  void onFinishedLastSeek() {
    if (shouldPlayAfterDragEnd) {
      shouldPlayAfterDragEnd = false;
      betterPlayerController?.play();
    }
  }
}

class _ProgressBarPainter extends CustomPainter {
  _ProgressBarPainter(this.value, this.colors);

  VideoPlayerValue value;
  BetterPlayerProgressColors colors;

  @override
  bool shouldRepaint(CustomPainter painter) => true;

  @override
  void paint(Canvas canvas, Size size) {
    const barHeight = 5.0;
    const handleHeight = 6.0;
    final baseOffset = size.height / 2 - barHeight / 2.0;

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromPoints(Offset(0, baseOffset), Offset(size.width, baseOffset + barHeight)),
        const Radius.circular(4),
      ),
      colors.backgroundPaint,
    );
    final duration = value.duration;
    if (!value.initialized || duration == null || duration.inMilliseconds <= 0 || !size.width.isFinite || size.width <= 0) {
      return;
    }
    final double playedPartPercent = _safeFraction(value.position, duration);
    final double playedPart = (playedPartPercent * size.width).clamp(0.0, size.width);
    for (final DurationRange range in value.buffered) {
      final double startFraction = _safeFractionValue(range.startFraction(duration));
      final double endFraction = _safeFractionValue(range.endFraction(duration));
      if (endFraction <= startFraction) {
        continue;
      }
      final double start = (startFraction * size.width).clamp(0.0, size.width);
      final double end = (endFraction * size.width).clamp(0.0, size.width);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromPoints(Offset(start, baseOffset), Offset(end, baseOffset + barHeight)),
          const Radius.circular(4),
        ),
        colors.bufferedPaint,
      );
    }
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromPoints(Offset(0, baseOffset), Offset(playedPart, baseOffset + barHeight)),
        const Radius.circular(4),
      ),
      colors.playedPaint,
    );

    final shadowPath = Path()
      ..addOval(Rect.fromCircle(center: Offset(playedPart, baseOffset + barHeight / 2), radius: handleHeight));

    canvas.drawShadow(shadowPath, Colors.black, 0.2, false);
    canvas.drawCircle(Offset(playedPart, baseOffset + barHeight / 2), handleHeight, colors.handlePaint);
  }

  double _safeFraction(Duration part, Duration total) {
    final totalMs = total.inMilliseconds;
    if (totalMs <= 0) {
      return 0;
    }
    return _safeFractionValue(part.inMilliseconds / totalMs);
  }

  double _safeFractionValue(double fraction) {
    if (!fraction.isFinite || fraction.isNaN) {
      return 0;
    }
    return fraction.clamp(0.0, 1.0);
  }
}
