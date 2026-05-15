import 'dart:async';
import 'package:flutter/material.dart';
import 'package:pure_live/plugins/locale_helper.dart';
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

  // 用于连接图标和弹出面板的轴心
  final LayerLink _layerLink = LayerLink();

  // 鼠标追踪标志位
  bool _isMouseInIcon = false;
  bool _isMouseInBar = false;
  Timer? _hideTimer;

  static const double _barHeight = 150.0;
  static const double _barWidth = 44.0;

  VideoController get controller => widget.controller;

  @override
  void initState() {
    super.initState();
    initVolume();
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
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
    if (_overlayEntry != null || !mounted) return;

    _overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        width: _barWidth,
        height: _barHeight + 20, // 增加额外高度作为无缝缓冲区
        child: CompositedTransformFollower(
          link: _layerLink,
          showWhenUnlinked: false,
          // 将面板的底部中心，对齐到图标的顶部中心
          followerAnchor: Alignment.bottomCenter,
          targetAnchor: Alignment.topCenter,
          offset: const Offset(0, 5), // 微调向下偏移，覆盖两组件之间的空隙
          child: MouseRegion(
            onEnter: (_) => _isMouseInBar = true,
            onExit: (_) {
              _isMouseInBar = false;
              _startHideTimer();
            },
            child: _buildVolumeBarUI(),
          ),
        ),
      ),
    );

    Overlay.of(context).insert(_overlayEntry!);
  }

  // 延时关闭定时器（防闪烁防抖）
  void _startHideTimer() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(milliseconds: 150), () {
      if (!_isMouseInIcon && !_isMouseInBar) {
        _removeOverlay();
      }
    });
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  Widget _buildVolumeBarUI() {
    return Material(
      color: Colors.transparent,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 12), // 底部的 Padding 可以充当鼠标滑过的桥梁，防止断连
        child: Container(
          decoration: BoxDecoration(
            color: Colors.black.withAlpha(220),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: Colors.white10),
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              // 实际可滑动区域的高度（扣除上下 Padding）
              final double trackHeight = constraints.maxHeight - 40;
              return GestureDetector(
                onVerticalDragUpdate: (details) => _handleVolumeDrag(details, trackHeight),
                child: Stack(
                  alignment: Alignment.bottomCenter,
                  children: [
                    // 背景音量槽
                    Container(
                      width: 4,
                      margin: const EdgeInsets.symmetric(vertical: 20),
                      decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
                    ),
                    // 进度条填充
                    Positioned(
                      bottom: 20,
                      child: Container(
                        width: 4,
                        height: _volume * trackHeight,
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(2)),
                      ),
                    ),
                    // 顶端滑块圆点
                    Positioned(
                      bottom: 20 + (_volume * trackHeight) - 6,
                      child: Container(
                        width: 12,
                        height: 12,
                        decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  void _handleVolumeDrag(DragUpdateDetails details, double trackHeight) {
    if (trackHeight <= 0) return;
    // 根据实际高度精准计算灵敏度
    final deltaRatio = -details.delta.dy / trackHeight;
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

  @override
  Widget build(BuildContext context) {
    IconData icon = _volume == 0 ? Icons.volume_off : (_volume < 0.5 ? Icons.volume_down : Icons.volume_up);

    // 将原生的图标组件包裹在联动 Target 中
    return CompositedTransformTarget(
      link: _layerLink,
      child: MouseRegion(
        onEnter: (_) {
          _isMouseInIcon = true;
          _showVolumeBar();
        },
        onExit: (_) {
          _isMouseInIcon = false;
          _startHideTimer();
        },
        child: IconButton(
          onPressed: _handleToggleMute,
          icon: Icon(icon, color: Colors.white, size: 24),
          tooltip: _volume == 0 ? i18n('cancel_mute') : i18n('mute'),
        ),
      ),
    );
  }
}
