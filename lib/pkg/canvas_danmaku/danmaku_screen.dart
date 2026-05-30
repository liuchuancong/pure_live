import 'dart:math';
import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:pure_live/plugins/locale_helper.dart';
import 'package:pure_live/pkg/canvas_danmaku/utils/utils.dart';
import 'package:pure_live/pkg/canvas_danmaku/danmaku_controller.dart';
import 'package:pure_live/pkg/canvas_danmaku/models/danmaku_item.dart';
import 'package:pure_live/pkg/canvas_danmaku/models/danmaku_option.dart';
import 'package:pure_live/pkg/canvas_danmaku/scroll_danmaku_painter.dart';
import 'package:pure_live/pkg/canvas_danmaku/static_danmaku_painter.dart';
import 'package:pure_live/pkg/canvas_danmaku/special_danmaku_painter.dart';
import 'package:pure_live/pkg/canvas_danmaku/models/danmaku_content_item.dart';

class DanmakuScreen extends StatefulWidget {
  final DanmakuController controller;
  final DanmakuOption option;

  const DanmakuScreen({required this.controller, required this.option, super.key});

  @override
  State<DanmakuScreen> createState() => _DanmakuScreenState();
}

class _DanmakuScreenState extends State<DanmakuScreen> with TickerProviderStateMixin, WidgetsBindingObserver {
  double _viewWidth = 0;
  double _viewHeight = 0;
  late DanmakuController _controller;
  late AnimationController _animationController;
  late AnimationController _staticAnimationController;
  DanmakuOption _option = DanmakuOption();

  final Map<double, List<DanmakuItem>> _scrollDanmakuByTrack = {};
  final List<DanmakuItem> _topDanmakuItems = [];
  final List<DanmakuItem> _bottomDanmakuItems = [];
  final List<DanmakuItem> _specialDanmakuItems = [];
  final List<DanmakuItem> _flattenedScrollDanmakus = [];

  late double _danmakuHeight;
  late int _trackCount;
  final List<double> _trackYPositions = [];
  final _random = Random();
  final _stopwatch = Stopwatch();
  bool _running = true;

  int get _tick => _stopwatch.elapsedMilliseconds;

  @override
  void initState() {
    super.initState();
    _controller = widget.controller;
    _option = widget.option;
    _controller.option = _option;
    _bindControllerCallbacks();
    _startTick();

    _animationController = AnimationController(
      vsync: this,
      duration: Duration(seconds: _option.duration),
    )..repeat();

    _staticAnimationController = AnimationController(
      vsync: this,
      duration: Duration(seconds: _option.duration),
    )..repeat();

    WidgetsBinding.instance.addObserver(this);
    _calculateTracksGeometry();
  }

  void _bindControllerCallbacks() {
    _controller.onAddDanmaku = addDanmaku;
    _controller.onUpdateOption = updateOption;
    _controller.onPause = pause;
    _controller.onResume = resume;
    _controller.onClear = clearDanmakus;
  }

  void _calculateTracksGeometry() {
    final textPainter = TextPainter(
      text: TextSpan(
        text: i18n("danmaku"),
        style: TextStyle(fontSize: _option.fontSize),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    _danmakuHeight = textPainter.height;

    if (_viewWidth <= 0 || _viewHeight <= 0) return;

    final topOffset = _option.topAreaDistance;
    final bottomOffset = _option.bottomAreaDistance;
    double displayHeight = (_viewHeight - topOffset - bottomOffset) * _option.area;

    _trackCount = (displayHeight / _danmakuHeight).floor().clamp(0, 999);
    _trackYPositions.clear();
    for (int i = 0; i < _trackCount; i++) {
      _trackYPositions.add(topOffset + (i * _danmakuHeight));
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      pause();
    } else if (state == AppLifecycleState.resumed) {
      resume();
    }
  }

  @override
  void dispose() {
    _running = false;
    WidgetsBinding.instance.removeObserver(this);
    _animationController.dispose();
    _staticAnimationController.dispose();
    _stopwatch.stop();
    _flattenedScrollDanmakus.clear();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant DanmakuScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.controller != _controller) {
      _controller = widget.controller;
    }
    _bindControllerCallbacks();
  }

  void addDanmaku(DanmakuContentItem content) {
    if (!_running || !mounted || _trackYPositions.isEmpty) return;

    if (content.type == DanmakuItemType.special) {
      if (!_option.hideSpecial) {
        final special = content as SpecialDanmakuContentItem;
        special.painterCache = TextPainter(
          text: TextSpan(
            text: content.text,
            style: TextStyle(
              color: content.color,
              fontSize: content.fontSize,
              fontWeight: FontWeight.values[_option.fontWeight],
              shadows: content.hasStroke
                  ? [
                      Shadow(
                        color: Colors.black.withAlpha((255 * (special.alphaTween?.begin ?? content.color.a)).toInt()),
                        blurRadius: 2,
                      ),
                    ]
                  : null,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();

        _specialDanmakuItems.add(
          DanmakuItem(
            width: 0,
            height: 0,
            creationTime: _tick,
            content: content,
            paragraph: null,
            strokeParagraph: null,
          ),
        );
      }
      return;
    }

    final textPainter = TextPainter(
      text: TextSpan(
        text: content.text,
        style: TextStyle(fontSize: _option.fontSize, fontWeight: FontWeight.values[_option.fontWeight]),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    final danmakuWidth = textPainter.width;
    final danmakuHeight = textPainter.height;

    final ui.Paragraph paragraph = Utils.generateParagraph(content, danmakuWidth, _option.fontSize, _option.fontWeight);
    final ui.Paragraph? strokeParagraph = _option.showStroke
        ? Utils.generateStrokeParagraph(content, danmakuWidth, _option.fontSize, _option.fontWeight)
        : null;

    int idx = 1;
    for (double yPosition in _trackYPositions) {
      if (content.type == DanmakuItemType.scroll && !_option.hideScroll) {
        if (_scrollCanAddToTrack(yPosition, danmakuWidth)) {
          _scrollDanmakuByTrack
              .putIfAbsent(yPosition, () => [])
              .add(
                DanmakuItem(
                  yPosition: yPosition,
                  xPosition: _viewWidth,
                  width: danmakuWidth,
                  height: danmakuHeight,
                  creationTime: _tick,
                  content: content,
                  paragraph: paragraph,
                  strokeParagraph: strokeParagraph,
                  cachedWidth: danmakuWidth,
                ),
              );
          break;
        }
        if (content.selfSend && idx == _trackCount) {
          final targetY = _trackYPositions.isNotEmpty ? _trackYPositions[0] : 0.0;
          _scrollDanmakuByTrack
              .putIfAbsent(targetY, () => [])
              .add(
                DanmakuItem(
                  yPosition: targetY,
                  xPosition: _viewWidth,
                  width: danmakuWidth,
                  height: danmakuHeight,
                  creationTime: _tick,
                  content: content,
                  paragraph: paragraph,
                  strokeParagraph: strokeParagraph,
                  cachedWidth: danmakuWidth,
                ),
              );
          break;
        }
        if (_option.massiveMode && idx == _trackCount) {
          final randomY = _trackYPositions[_random.nextInt(_trackYPositions.length)];
          _scrollDanmakuByTrack
              .putIfAbsent(randomY, () => [])
              .add(
                DanmakuItem(
                  yPosition: randomY,
                  xPosition: _viewWidth,
                  width: danmakuWidth,
                  height: danmakuHeight,
                  creationTime: _tick,
                  content: content,
                  paragraph: paragraph,
                  strokeParagraph: strokeParagraph,
                  cachedWidth: danmakuWidth,
                ),
              );
          break;
        }
      }

      if (content.type == DanmakuItemType.top && !_option.hideTop) {
        if (_topCanAddToTrack(yPosition)) {
          _topDanmakuItems.add(
            DanmakuItem(
              yPosition: yPosition,
              xPosition: _viewWidth,
              width: danmakuWidth,
              height: danmakuHeight,
              creationTime: _tick,
              content: content,
              paragraph: paragraph,
              strokeParagraph: strokeParagraph,
            ),
          );
          break;
        }
      }

      if (content.type == DanmakuItemType.bottom && !_option.hideBottom) {
        if (_bottomCanAddToTrack(yPosition)) {
          _bottomDanmakuItems.add(
            DanmakuItem(
              yPosition: yPosition,
              xPosition: _viewWidth,
              width: danmakuWidth,
              height: danmakuHeight,
              creationTime: _tick,
              content: content,
              paragraph: paragraph,
              strokeParagraph: strokeParagraph,
            ),
          );
          break;
        }
      }
      idx++;
    }

    if (!_animationController.isAnimating && (_scrollDanmakuByTrack.isNotEmpty || _specialDanmakuItems.isNotEmpty)) {
      _animationController.repeat();
    }
  }

  void pause() {
    if (!mounted) return;
    if (_running) {
      setState(() {
        _running = false;
      });
      if (_animationController.isAnimating) _animationController.stop();
      if (_staticAnimationController.isAnimating) _staticAnimationController.stop();
      if (_stopwatch.isRunning) _stopwatch.stop();
    }
  }

  void resume() {
    if (!mounted) return;
    if (!_running) {
      setState(() {
        _running = true;
      });
      if (!_animationController.isAnimating) {
        _animationController.repeat();
        _staticAnimationController.repeat();
        _startTick();
      }
    }
  }

  void updateOption(DanmakuOption option) {
    bool needRestart = false;
    bool needClearParagraph = option.fontSize != _option.fontSize;

    if (_animationController.isAnimating) {
      _animationController.stop();
      _staticAnimationController.stop();
      needRestart = true;
    }

    if (option.hideScroll && !_option.hideScroll) _scrollDanmakuByTrack.clear();
    if (option.hideTop && !_option.hideTop) _topDanmakuItems.clear();
    if (option.hideBottom && !_option.hideBottom) _bottomDanmakuItems.clear();

    _option = option;
    _controller.option = _option;
    _calculateTracksGeometry();

    if (needClearParagraph) {
      _scrollDanmakuByTrack.forEach((trackY, items) {
        for (var item in items) {
          item.paragraph = null;
          item.strokeParagraph = null;
        }
      });
      for (var item in _topDanmakuItems) {
        item.paragraph = null;
        item.strokeParagraph = null;
      }
      // 🚀 补全被截断的底部弹幕缓存清理逻辑
      for (var item in _bottomDanmakuItems) {
        item.paragraph = null;
        item.strokeParagraph = null;
      }
    }

    if (needRestart) {
      _animationController.repeat();
      _staticAnimationController.repeat();
    }
    if (mounted) setState(() {});
  }

  void clearDanmakus() {
    if (!mounted) return;
    setState(() {
      _scrollDanmakuByTrack.clear();
      _topDanmakuItems.clear();
      _bottomDanmakuItems.clear();
      _specialDanmakuItems.clear();
    });
    _animationController.stop();
    _staticAnimationController.stop();
  }

  bool _scrollCanAddToTrack(double yPosition, double newDanmakuWidth) {
    final trackItems = _scrollDanmakuByTrack[yPosition];
    if (trackItems == null || trackItems.isEmpty) return true;

    final item = trackItems.last;
    final existingEndPosition = item.xPosition + item.width;
    if (_viewWidth - existingEndPosition < 0) return false;

    if (item.width < newDanmakuWidth) {
      if ((1 - ((_viewWidth - item.xPosition) / (item.width + _viewWidth))) >
          (_viewWidth / (_viewWidth + newDanmakuWidth))) {
        return false;
      }
    }
    return true;
  }

  bool _topCanAddToTrack(double yPosition) {
    for (var item in _topDanmakuItems) {
      if (item.yPosition == yPosition) return false;
    }
    return true;
  }

  bool _bottomCanAddToTrack(double yPosition) {
    for (var item in _bottomDanmakuItems) {
      if (item.yPosition == yPosition) return false;
    }
    return true;
  }

  void _startTick() async {
    _stopwatch.start();
    final staticDuration = _option.duration * 1000;

    while (_running && mounted) {
      await Future.delayed(const Duration(milliseconds: 16));

      final List<double> tracksToRemove = [];
      _scrollDanmakuByTrack.forEach((trackY, items) {
        items.removeWhere((item) => item.xPosition + item.width < 0);
        if (items.isEmpty) tracksToRemove.add(trackY);
      });

      for (final trackY in tracksToRemove) {
        _scrollDanmakuByTrack.remove(trackY);
      }

      _topDanmakuItems.removeWhere((item) => (_tick - item.creationTime) >= staticDuration);
      _bottomDanmakuItems.removeWhere((item) => (_tick - item.creationTime) >= staticDuration);
      _specialDanmakuItems.removeWhere(
        (item) => (_tick - item.creationTime) >= (item.content as SpecialDanmakuContentItem).duration,
      );
    }
    _stopwatch.stop();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth != _viewWidth || constraints.maxHeight != _viewHeight) {
          _viewWidth = constraints.maxWidth;
          _viewHeight = constraints.maxHeight;
          _calculateTracksGeometry();
        }

        return Stack(
          children: [
            Positioned.fill(
              child: ClipRect(
                child: IgnorePointer(
                  child: Opacity(
                    opacity: _option.opacity,
                    child: Stack(
                      children: [
                        RepaintBoundary(
                          child: AnimatedBuilder(
                            animation: _animationController,
                            builder: (context, child) {
                              _flattenedScrollDanmakus.clear();
                              _scrollDanmakuByTrack.forEach((_, items) {
                                _flattenedScrollDanmakus.addAll(items);
                              });
                              return CustomPaint(
                                size: Size(_viewWidth, _viewHeight),
                                painter: ScrollDanmakuPainter(
                                  _animationController.value,
                                  _flattenedScrollDanmakus,
                                  _option.duration,
                                  _option.fontSize,
                                  _option.fontWeight,
                                  _option.showStroke,
                                  _danmakuHeight,
                                  _running,
                                  _tick,
                                ),
                              );
                            },
                          ),
                        ),
                        RepaintBoundary(
                          child: AnimatedBuilder(
                            animation: _staticAnimationController,
                            builder: (context, child) {
                              return CustomPaint(
                                size: Size(_viewWidth, _viewHeight),
                                painter: StaticDanmakuPainter(
                                  _staticAnimationController.value,
                                  _topDanmakuItems,
                                  _bottomDanmakuItems,
                                  _option.duration,
                                  _option.fontSize,
                                  _option.fontWeight,
                                  _option.showStroke,
                                  _danmakuHeight,
                                  _running,
                                  _tick,
                                ),
                              );
                            },
                          ),
                        ),
                        RepaintBoundary(
                          child: AnimatedBuilder(
                            animation: _animationController,
                            builder: (context, child) {
                              return CustomPaint(
                                size: Size(_viewWidth, _viewHeight),
                                painter: SpecialDanmakuPainter(
                                  _animationController.value,
                                  _specialDanmakuItems,
                                  _option.fontSize,
                                  _option.fontWeight,
                                  _running,
                                  _tick,
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
