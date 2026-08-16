import 'package:flame/game.dart';
import '../atlas/emoji_atlas.dart';
import '../core/barrage_config.dart';
import '../core/barrage_engine.dart';
import 'package:flutter/material.dart';
import '../core/barrage_controller.dart';

class FlameBarrageWidget extends StatefulWidget {
  const FlameBarrageWidget({
    super.key,
    required this.config,
    required this.emojiAtlas,
    required this.controller,
    this.enablePointerEvents = false,
  });

  final BarrageConfig config;
  final EmojiAtlas emojiAtlas;
  final BarrageController controller;
  final bool enablePointerEvents;
  @override
  State<FlameBarrageWidget> createState() => _FlameBarrageWidgetState();
}

class _FlameBarrageWidgetState extends State<FlameBarrageWidget> {
  late final BarrageEngine _engine;

  @override
  void initState() {
    super.initState();
    _engine = BarrageEngine(config: widget.config, emojiAtlas: widget.emojiAtlas);
    _initControllerCallbacks();
  }

  @override
  void didUpdateWidget(covariant FlameBarrageWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.config != widget.config) {
      _engine.updateConfig(widget.config);
    }
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.detach();
      _initControllerCallbacks();
    }
  }

  void _initControllerCallbacks() {
    widget.controller.attach(_engine);

    widget.controller.onAddDanmaku = (item) {
      if (mounted) {
        _engine.pushMessage(item);
      }
    };

    widget.controller.onUpdateOption = (newConfig) {
      if (mounted) {
        _engine.updateConfig(newConfig);
      }
    };

    widget.controller.onPause = () {
      if (mounted) {
        _engine.pause();
      }
    };

    widget.controller.onResume = () {
      if (mounted) {
        _engine.resume();
      }
    };

    widget.controller.onClear = () {
      if (mounted) {
        _engine.clear();
      }
    };
  }

  @override
  void dispose() {
    widget.controller.detach();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Widget child = ClipRect(
      clipBehavior: Clip.hardEdge,
      child: GameWidget(game: _engine),
    );

    if (!widget.enablePointerEvents) {
      child = IgnorePointer(child: child);
    }

    return child;
  }
}
