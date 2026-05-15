import 'dart:math';
import 'dart:ui' as ui;
import 'danmaku_controller.dart';
import 'models/danmaku_item.dart';
import 'models/danmaku_option.dart';
import 'scroll_danmaku_painter.dart';
import 'static_danmaku_painter.dart';
import 'special_danmaku_painter.dart';
import 'package:flutter/material.dart';
import 'package:pure_live/plugins/locale_helper.dart';
import 'package:pure_live/pkg/canvas_danmaku/utils/utils.dart';
import 'package:pure_live/pkg/canvas_danmaku/models/danmaku_content_item.dart';

class DanmakuScreen extends StatefulWidget {
  // 创建Screen后返回控制器
  final DanmakuController controller;
  final DanmakuOption option;

  const DanmakuScreen({required this.controller, required this.option, super.key}); // 添加断言确保控制器不为null

  @override
  State<DanmakuScreen> createState() => _DanmakuScreenState();
}

class _DanmakuScreenState extends State<DanmakuScreen> with TickerProviderStateMixin, WidgetsBindingObserver {
  /// 视图宽度
  double _viewWidth = 0;

  /// 弹幕控制器
  late DanmakuController _controller;

  /// 弹幕动画控制器
  late AnimationController _animationController;

  /// 静态弹幕动画控制器
  late AnimationController _staticAnimationController;

  /// 弹幕配置
  DanmakuOption _option = DanmakuOption();

  /// 滚动弹幕（按轨道的 yPosition 分组存储，key 是轨道的 y 坐标，value 是该轨道的弹幕列表）
  final Map<double, List<DanmakuItem>> _scrollDanmakuByTrack = {};

  /// 顶部弹幕
  final List<DanmakuItem> _topDanmakuItems = [];

  /// 底部弹幕
  final List<DanmakuItem> _bottomDanmakuItems = [];

  /// 高级弹幕
  final List<DanmakuItem> _specialDanmakuItems = [];

  /// 弹幕高度
  late double _danmakuHeight;

  /// 弹幕轨道数
  late int _trackCount;

  /// 弹幕轨道位置
  final List<double> _trackYPositions = [];

  late final _random = Random();

  /// 内部计时器
  int get _tick => _stopwatch.elapsedMilliseconds;

  final _stopwatch = Stopwatch();

  /// 运行状态
  bool _running = true;

  @override
  void initState() {
    super.initState();
    // 计时器初始化
    _controller = widget.controller;
    _startTick();
    _option = widget.option;
    _controller.option = _option;
    _bindControllerCallbacks();
    _animationController = AnimationController(
      vsync: this,
      duration: Duration(seconds: _option.duration),
    )..repeat();

    _staticAnimationController = AnimationController(
      vsync: this,
      duration: Duration(seconds: _option.duration),
    );

    WidgetsBinding.instance.addObserver(this);
  }

  // 绑定回调的方法
  void _bindControllerCallbacks() {
    _controller.onAddDanmaku = addDanmaku;
    _controller.onUpdateOption = updateOption;
    _controller.onPause = pause;
    _controller.onResume = resume;
    _controller.onClear = clearDanmakus;
  }

  /// 处理 Android/iOS 应用后台或熄屏导致的动画问题
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
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant DanmakuScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.controller == _controller) {
      _bindControllerCallbacks();
    } else {
      _controller = widget.controller;
      _bindControllerCallbacks();
    }
  }

  /// 添加弹幕
  void addDanmaku(DanmakuContentItem content) {
    if (!_running || !mounted) {
      return;
    }
    if (content.type == DanmakuItemType.special) {
      if (!_option.hideSpecial) {
        (content as SpecialDanmakuContentItem).painterCache = TextPainter(
          text: TextSpan(
            text: content.text,
            style: TextStyle(
              color: content.color,
              fontSize: content.fontSize,
              fontWeight: FontWeight.values[_option.fontWeight],
              shadows: content.hasStroke
                  ? [
                      Shadow(
                        color: Colors.black.withAlpha((255 * (content.alphaTween?.begin ?? content.color.a)).toInt()),
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
      } else {
        return;
      }
    } else {
      // 在这里提前创建 Paragraph 缓存防止卡顿
      final textPainter = TextPainter(
        text: TextSpan(
          text: content.text,
          style: TextStyle(fontSize: _option.fontSize, fontWeight: FontWeight.values[_option.fontWeight]),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      final danmakuWidth = textPainter.width;
      final danmakuHeight = textPainter.height;

      final ui.Paragraph paragraph = Utils.generateParagraph(
        content,
        danmakuWidth,
        _option.fontSize,
        _option.fontWeight,
      );

      ui.Paragraph? strokeParagraph;
      if (_option.showStroke) {
        strokeParagraph = Utils.generateStrokeParagraph(content, danmakuWidth, _option.fontSize, _option.fontWeight);
      }

      int idx = 1;
      for (double yPosition in _trackYPositions) {
        if (content.type == DanmakuItemType.scroll && !_option.hideScroll) {
          bool scrollCanAddToTrack = _scrollCanAddToTrack(yPosition, danmakuWidth);

          if (scrollCanAddToTrack) {
            if (!_scrollDanmakuByTrack.containsKey(yPosition)) {
              _scrollDanmakuByTrack[yPosition] = [];
            }
            _scrollDanmakuByTrack[yPosition]!.add(
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

          /// 无法填充自己发送的弹幕时强制添加
          if (content.selfSend && idx == _trackCount) {
            if (!_scrollDanmakuByTrack.containsKey(yPosition)) {
              _scrollDanmakuByTrack[yPosition] = [];
            }
            _scrollDanmakuByTrack[yPosition]!.add(
              DanmakuItem(
                yPosition: _trackYPositions[0],
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

          /// 海量弹幕启用时进行随机添加
          if (_option.massiveMode && idx == _trackCount) {
            var randomYPosition = _trackYPositions[_random.nextInt(_trackYPositions.length)];
            if (!_scrollDanmakuByTrack.containsKey(yPosition)) {
              _scrollDanmakuByTrack[yPosition] = [];
            }
            _scrollDanmakuByTrack[yPosition]!.add(
              DanmakuItem(
                yPosition: randomYPosition,
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
          bool topCanAddToTrack = _topCanAddToTrack(yPosition);

          if (topCanAddToTrack) {
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
          bool bottomCanAddToTrack = _bottomCanAddToTrack(yPosition);

          if (bottomCanAddToTrack) {
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
    }

    switch (content.type) {
      case DanmakuItemType.top:
      case DanmakuItemType.bottom:
        // 重绘静态弹幕
        if (mounted) {
          setState(() {
            _staticAnimationController.value = 0;
          });
        }
        break;
      case DanmakuItemType.scroll:
      case DanmakuItemType.special:
        if (!_animationController.isAnimating &&
            (_scrollDanmakuByTrack.isNotEmpty || _specialDanmakuItems.isNotEmpty)) {
          _animationController.repeat();
        }
        break;
    }
  }

  /// 暂停
  void pause() {
    if (!mounted) return;
    if (_running) {
      setState(() {
        _running = false;
      });
      if (_animationController.isAnimating) {
        _animationController.stop();
      }
      if (_stopwatch.isRunning) {
        _stopwatch.stop();
      }
    }
  }

  /// 恢复
  void resume() {
    if (!mounted) return;
    if (!_running) {
      setState(() {
        _running = true;
      });
      if (!_animationController.isAnimating) {
        _animationController.repeat();
        // 重启计时器
        _startTick();
      }
    }
  }

  /// 更新弹幕设置
  void updateOption(DanmakuOption option) {
    bool needRestart = false;
    bool needClearParagraph = false;
    if (_animationController.isAnimating) {
      _animationController.stop();
      needRestart = true;
    }

    if (option.fontSize != _option.fontSize) {
      needClearParagraph = true;
    }

    /// 需要隐藏弹幕时清理已有弹幕
    if (option.hideScroll && !_option.hideScroll) {
      _scrollDanmakuByTrack.clear();
    }
    if (option.hideTop && !_option.hideTop) {
      _topDanmakuItems.clear();
    }
    if (option.hideBottom && !_option.hideBottom) {
      _bottomDanmakuItems.clear();
    }
    _option = option;
    _controller.option = _option;

    /// 清理已经存在的 Paragraph 缓存
    if (needClearParagraph) {
      _scrollDanmakuByTrack.forEach((trackY, items) {
        for (DanmakuItem item in items) {
          if (item.paragraph != null) {
            item.paragraph = null;
          }
          if (item.strokeParagraph != null) {
            item.strokeParagraph = null;
          }
        }
      });
      for (DanmakuItem item in _topDanmakuItems) {
        if (item.paragraph != null) {
          item.paragraph = null;
        }
        if (item.strokeParagraph != null) {
          item.strokeParagraph = null;
        }
      }
      for (DanmakuItem item in _bottomDanmakuItems) {
        if (item.paragraph != null) {
          item.paragraph = null;
        }
        if (item.strokeParagraph != null) {
          item.strokeParagraph = null;
        }
      }
    }
    if (needRestart) {
      _animationController.repeat();
    }
    if (!mounted) return;
    setState(() {});
  }

  /// 清空弹幕
  void clearDanmakus() {
    if (!mounted) return;
    setState(() {
      _scrollDanmakuByTrack.clear();
      _topDanmakuItems.clear();
      _bottomDanmakuItems.clear();
      _specialDanmakuItems.clear();
    });
    _animationController.stop();
  }

  /// 确定滚动弹幕是否可以添加
  bool _scrollCanAddToTrack(double yPosition, double newDanmakuWidth) {
    // 直接获取当前轨道的弹幕列表（若轨道不存在则为空）
    final trackItems = _scrollDanmakuByTrack[yPosition] ?? [];

    // 仅遍历当前轨道的弹幕，判断是否可以添加新弹幕
    for (var item in trackItems) {
      final existingEndPosition = item.xPosition + item.width;
      // 原有判断逻辑不变（确保不重叠）
      if (_viewWidth - existingEndPosition < 0) {
        return false;
      }
      if (item.width < newDanmakuWidth) {
        if ((1 - ((_viewWidth - item.xPosition) / (item.width + _viewWidth))) >
            ((_viewWidth) / (_viewWidth + newDanmakuWidth))) {
          return false;
        }
      }
    }
    return true;
  }

  /// 确定顶部弹幕是否可以添加
  bool _topCanAddToTrack(double yPosition) {
    for (var item in _topDanmakuItems) {
      if (item.yPosition == yPosition) {
        return false;
      }
    }
    return true;
  }

  /// 确定底部弹幕是否可以添加
  bool _bottomCanAddToTrack(double yPosition) {
    for (var item in _bottomDanmakuItems) {
      if (item.yPosition == yPosition) {
        return false;
      }
    }
    return true;
  }

  // 基于Stopwatch的计时器同步
  // 基于Stopwatch的计时器同步
  void _startTick() async {
    _stopwatch.start();
    final staticDuration = _option.duration * 1000;

    while (_running && mounted) {
      await Future.delayed(const Duration(milliseconds: 16));
      final List<double> tracksToRemove = [];
      // 移除屏幕外滚动弹幕（遍历所有轨道）
      _scrollDanmakuByTrack.forEach((trackY, items) {
        items.removeWhere((item) => item.xPosition + item.width < 0);
        // 清理空轨道
        if (items.isEmpty) {
          tracksToRemove.add(trackY);
        }
      });
      for (final trackY in tracksToRemove) {
        _scrollDanmakuByTrack.remove(trackY);
      }
      // 移除顶部弹幕
      _topDanmakuItems.removeWhere((item) => (_tick - item.creationTime) >= staticDuration);
      // 移除底部弹幕
      _bottomDanmakuItems.removeWhere((item) => (_tick - item.creationTime) >= staticDuration);
      // 移除高级弹幕
      _specialDanmakuItems.removeWhere(
        (item) => (_tick - item.creationTime) >= (item.content as SpecialDanmakuContentItem).duration,
      );

      // 若存在滚动或高级弹幕，触发重绘
      if (_scrollDanmakuByTrack.isNotEmpty || _specialDanmakuItems.isNotEmpty) {
        if (mounted) setState(() {});
      }

      /// 重绘静态弹幕
      if (mounted) {
        setState(() {
          _staticAnimationController.value = 0;
        });
      }
    }

    _stopwatch.stop();
  }

  @override
  Widget build(BuildContext context) {
    /// 计算弹幕轨道
    final textPainter = TextPainter(
      text: TextSpan(
        text: i18n("danmaku"),
        style: TextStyle(fontSize: _option.fontSize),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    _danmakuHeight = textPainter.height;
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth != _viewWidth) {
          _viewWidth = constraints.maxWidth;
        }
        final screenHeight = constraints.maxHeight;
        final topOffset = _option.topAreaDistance;
        final bottomOffset = _option.bottomAreaDistance;
        double displayHeight = (screenHeight - topOffset - bottomOffset) * _option.area;
        _trackCount = (displayHeight / _danmakuHeight).floor();
        _trackCount.clamp(0, (displayHeight / _danmakuHeight).floor());
        _trackYPositions.clear();
        for (int i = 0; i < _trackCount; i++) {
          double trackY = topOffset + (i * _danmakuHeight);
          _trackYPositions.add(trackY);
        }

        return Stack(
          children: [
            Positioned(
              top: 0, // 上接顶部预留区
              bottom: 0, // 下接底部预留区
              left: 0,
              right: 0,
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
                              List<DanmakuItem> allScrollDanmakus = [];
                              _scrollDanmakuByTrack.forEach((trackY, items) => allScrollDanmakus.addAll(items));
                              return CustomPaint(
                                painter: ScrollDanmakuPainter(
                                  _animationController.value,
                                  allScrollDanmakus,
                                  _option.duration,
                                  _option.fontSize,
                                  _option.fontWeight,
                                  _option.showStroke,
                                  _danmakuHeight,
                                  _running,
                                  _tick,
                                ),
                                child: Container(),
                              );
                            },
                          ),
                        ),
                        RepaintBoundary(
                          child: AnimatedBuilder(
                            animation: _staticAnimationController,
                            builder: (context, child) {
                              return CustomPaint(
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
                                child: Container(),
                              );
                            },
                          ),
                        ),
                        RepaintBoundary(
                          child: AnimatedBuilder(
                            animation: _animationController, // 与滚动弹幕共用控制器
                            builder: (context, child) {
                              return CustomPaint(
                                painter: SpecialDanmakuPainter(
                                  _animationController.value,
                                  _specialDanmakuItems,
                                  _option.fontSize,
                                  _option.fontWeight,
                                  _running,
                                  _tick,
                                ),
                                child: Container(),
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
