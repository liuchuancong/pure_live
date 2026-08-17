// GestureDetector callbacks require separate statements rather than cascade chains
// ignore_for_file: cascade_invocations

import 'dart:async';
import 'package:better_player_plus/better_player_plus.dart';
import 'package:better_player_plus/src/video_player/video_player.dart';
import 'package:better_player_plus/src/video_player/video_player_platform_interface.dart';
import 'package:flutter/material.dart';

class BetterPlayerMaterialVideoProgressBar extends StatefulWidget {
  BetterPlayerMaterialVideoProgressBar(
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
  State<BetterPlayerMaterialVideoProgressBar> createState() => _VideoProgressBarState();
}

class _VideoProgressBarState extends State<BetterPlayerMaterialVideoProgressBar> {
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
    final bool enableProgressBarDrag =
        betterPlayerController!.betterPlayerConfiguration.controlsConfiguration.enableProgressBarDrag;

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
      onHorizontalDragUpdate: (DragUpdateDetails details) {
        if (!controller!.value.initialized || !enableProgressBarDrag) {
          return;
        }

        seekToRelativePosition(details.globalPosition);

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
        seekToRelativePosition(details.globalPosition);
        _setupUpdateBlockTimer();
        if (widget.onTapDown != null) {
          widget.onTapDown!.call();
        }
      },
      child: Center(
        child: Container(
          height: MediaQuery.of(context).size.height / 2,
          width: MediaQuery.of(context).size.width,
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
      final Offset tapPos = box.globalToLocal(globalPosition);
      final double relative = tapPos.dx / box.size.width;
      if (relative > 0) {
        final Duration position = controller!.value.duration! * relative;
        lastSeek = position;
        await betterPlayerController!.seekTo(position);
        onFinishedLastSeek();
        if (relative >= 1) {
          lastSeek = controller!.value.duration;
          await betterPlayerController!.seekTo(controller!.value.duration!);
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
    const height = 2.0;

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromPoints(Offset(0, size.height / 2), Offset(size.width, size.height / 2 + height)),
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
          Rect.fromPoints(Offset(start, size.height / 2), Offset(end, size.height / 2 + height)),
          const Radius.circular(4),
        ),
        colors.bufferedPaint,
      );
    }
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromPoints(Offset(0, size.height / 2), Offset(playedPart, size.height / 2 + height)),
        const Radius.circular(4),
      ),
      colors.playedPaint,
    );
    canvas.drawCircle(Offset(playedPart, size.height / 2 + height / 2), height * 3, colors.handlePaint);
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
