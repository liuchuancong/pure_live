import 'dart:async';
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
  OverlayEntry? _overlayEntry;
  bool _isVolumeBarVisible = false;
  VideoController get controller => widget.controller;
  Timer? _hideTimer;
  // 音量条高度常量
  static const double _barHeight = 150;

  @override
  void initState() {
    initVolume();
    super.initState();
  }

  @override
  void dispose() {
    _hideVolumeBar();
    super.dispose();
  }

  Future<void> initVolume() async {
    final volume = await controller.getVolume();
    if (!context.mounted) return;
    setState(() {
      _volume = volume ?? 0.5;
    });
  }

  // 创建并显示Overlay中的音量条
  void _showVolumeBar() {
    final renderBox = context.findRenderObject() as RenderBox;
    final position = renderBox.localToGlobal(Offset.zero);

    _overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        left: position.dx + (renderBox.size.width - 40) / 2,
        top: position.dy - _barHeight - 8,
        width: 40,
        height: _barHeight,
        child: _buildVolumeBar(),
      ),
    );

    Overlay.of(context).insert(_overlayEntry!);
    if (mounted) {
      setState(() {
        _isVolumeBarVisible = true;
        controller.enableController();
        _hideTimer?.cancel();
        _hideTimer = Timer(const Duration(seconds: 2), _hideVolumeBar);
      });
    }
  }

  // 移除Overlay中的音量条
  void _hideVolumeBar() {
    _overlayEntry?.remove();
    _overlayEntry = null;
    if (mounted) {
      setState(() => _isVolumeBarVisible = false);
    }
    _hideTimer?.cancel();
    _hideTimer = null;
  }

  // 切换音量条显示状态
  void _toggleVolumeBar() {
    controller.enableController();
    if (_isVolumeBarVisible) {
      _hideVolumeBar();
    } else {
      initVolume();
      Future.delayed(const Duration(milliseconds: 20), _showVolumeBar);
    }
  }

  // 处理音量滑动逻辑
  void _handleVolumeDrag(DragUpdateDetails details) {
    // 计算单次拖动的音量变化比例（限制最大变化量，避免一次滑动超出范围）
    final maxDeltaPerUpdate = _barHeight * 0.1; // 每次更新最大允许10%的变化
    final clampedDelta = details.delta.dy.clamp(-maxDeltaPerUpdate, maxDeltaPerUpdate);

    // 计算新音量值并限制在0-1范围内
    final deltaRatio = -clampedDelta / _barHeight;
    final newVolume = (_volume + deltaRatio).clamp(0.0, 1.0);

    // 只有当音量值确实变化时才更新
    if (newVolume != _volume) {
      setState(() => _volume = newVolume);
      _overlayEntry?.markNeedsBuild();
      controller.setVolume(_volume);
      controller.enableController();
      _hideTimer?.cancel();
      _hideTimer = Timer(const Duration(seconds: 2), _hideVolumeBar);
    }
  }

  // 构建音量条内容
  Widget _buildVolumeBar() {
    final sliderPosition = (_volume * _barHeight).clamp(10, _barHeight - 25).toDouble();
    return GestureDetector(
      onVerticalDragUpdate: _handleVolumeDrag,
      onTap: _hideVolumeBar,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.8),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10, spreadRadius: 2)],
        ),
        child: Stack(
          children: [
            // 刻度线
            const Positioned.fill(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 15),
                child: Center(child: VerticalDivider(color: Colors.white, thickness: 2)),
              ),
            ),
            // 音量填充部分
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              height: _volume * _barHeight,
              child: Container(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Colors.black12, Colors.black12],
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                  ),
                ),
              ),
            ),
            // 滑块（使用安全位置）
            Positioned(
              left: 0,
              right: 0,
              bottom: sliderPosition,
              child: const CircleAvatar(radius: 6, backgroundColor: Colors.white),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _toggleVolumeBar,
      child: Icon(
        _volume == 0
            ? Icons.volume_off
            : _volume < 0.5
            ? Icons.volume_down
            : Icons.volume_up,
        size: 24,
        color: Colors.white,
      ),
    );
  }
}
