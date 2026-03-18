import 'dart:async';
import 'package:get/utils.dart';
import 'package:flutter/material.dart';
import 'package:pure_live/modules/live_play/widgets/video_player/video_controller.dart';

class OverlayVolumeControl extends StatefulWidget {
  final VideoController controller;
  const OverlayVolumeControl({super.key, required this.controller});

  @override
  State<OverlayVolumeControl> createState() => _OverlayVolumeControlState();
}

class _OverlayVolumeControlState extends State<OverlayVolumeControl> {
  double _volume = 0.5;
  double _lastVolume = 0.5;
  OverlayEntry? _overlayEntry;
  bool _isVolumeBarVisible = false;

  // 鼠标追踪标志位，防止 Hover 闪烁
  bool _isMouseInIcon = false;
  bool _isMouseInBar = false;

  static const double _barHeight = 160; // 稍微增加高度以容纳填充
  VideoController get controller => widget.controller;

  @override
  void initState() {
    super.initState();
    initVolume();
  }

  @override
  void dispose() {
    _removeOverlay();
    super.dispose();
  }

  Future<void> initVolume() async {
    final volume = await controller.volume();
    if (!context.mounted) return;
    setState(() {
      _volume = volume ?? 0.5;
      if (_volume > 0) _lastVolume = _volume;
    });
  }

  // 静音/还原逻辑
  void _handleToggleMute() {
    setState(() {
      if (_volume > 0) {
        _lastVolume = _volume;
        _volume = 0;
      } else {
        _volume = _lastVolume > 0 ? _lastVolume : 0.5;
      }
    });
    controller.setVolume(_volume);
    _overlayEntry?.markNeedsBuild();
  }

  // 显示音量条
  void _showVolumeBar() {
    if (_isVolumeBarVisible || !mounted) return;

    final renderBox = context.findRenderObject() as RenderBox;
    final position = renderBox.localToGlobal(Offset.zero);

    _overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        // 居中对齐图标
        left: position.dx + (renderBox.size.width - 40) / 2,
        // 在图标上方显示，留出小空隙
        top: position.dy - _barHeight - 20,
        width: 40,
        height: _barHeight,
        child: MouseRegion(
          onEnter: (_) => _isMouseInBar = true,
          onExit: (_) {
            _isMouseInBar = false;
            _checkAndHide();
          },
          child: _buildVolumeBarUI(),
        ),
      ),
    );

    Overlay.of(context).insert(_overlayEntry!);
    setState(() => _isVolumeBarVisible = true);
  }

  // 检查并隐藏（核心修复：延时判断）
  void _checkAndHide() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (!_isMouseInIcon && !_isMouseInBar && _isVolumeBarVisible) {
        _removeOverlay();
      }
    });
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
    if (mounted) {
      setState(() => _isVolumeBarVisible = false);
    }
  }

  void _handleVolumeDrag(DragUpdateDetails details) {
    // 允许更细腻的滑动控制
    final deltaRatio = -details.delta.dy / (_barHeight - 40);
    final newVolume = (_volume + deltaRatio).clamp(0.0, 1.0);

    if (newVolume != _volume) {
      setState(() {
        _volume = newVolume;
        if (_volume > 0) _lastVolume = _volume;
      });
      _overlayEntry?.markNeedsBuild();
      controller.setVolume(_volume);
    }
  }

  Widget _buildVolumeBarUI() {
    return Material(
      color: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.only(bottom: 10), // 底部留白，方便鼠标滑向图标
        child: Container(
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.85),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white10),
          ),
          child: GestureDetector(
            onVerticalDragUpdate: _handleVolumeDrag,
            child: Stack(
              alignment: Alignment.bottomCenter,
              children: [
                // 背景背景槽
                Container(
                  width: 4,
                  margin: const EdgeInsets.symmetric(vertical: 20),
                  decoration: BoxDecoration(color: Colors.white12, borderRadius: BorderRadius.circular(2)),
                ),
                // 音量填充
                Positioned(
                  bottom: 20,
                  child: Container(
                    width: 4,
                    height: _volume * (_barHeight - 50),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(2)),
                  ),
                ),
                // 滑块
                Positioned(
                  bottom: 20 + (_volume * (_barHeight - 50)) - 6,
                  child: Container(
                    width: 12,
                    height: 12,
                    decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    IconData icon = _volume == 0 ? Icons.volume_off : (_volume < 0.5 ? Icons.volume_down : Icons.volume_up);

    return MouseRegion(
      onEnter: (_) {
        _isMouseInIcon = true;
        Duration(milliseconds: 300).delay(() {
          _showVolumeBar();
        });
      },
      onExit: (_) {
        _isMouseInIcon = false;
        _checkAndHide();
      },
      child: IconButton(
        onPressed: _handleToggleMute,
        icon: Icon(icon, color: Colors.white, size: 24),
        tooltip: _volume == 0 ? "取消静音" : "静音",
      ),
    );
  }
}
