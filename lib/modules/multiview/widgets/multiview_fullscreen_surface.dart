import 'package:flutter/material.dart';
import 'package:remixicon/remixicon.dart';

/// 多画面真全屏的公共画布。
///
/// 视频网格继续铺满系统全屏；退出按钮单独避让刘海/挖孔，始终保留一条
/// 可发现、可点击的退出路径。按钮之外的透明区域不拦截格子点击，因此
/// 原有的音源焦点切换手势保持不变。
class MultiviewFullscreenSurface extends StatelessWidget {
  const MultiviewFullscreenSurface({super.key, required this.child, required this.onExit, required this.exitTooltip});

  static const exitButtonKey = ValueKey<String>('multiview-fullscreen-exit');

  final Widget child;
  final VoidCallback onExit;
  final String exitTooltip;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        MediaQuery.removePadding(context: context, removeTop: true, removeBottom: true, child: child),
        Positioned(
          left: 0,
          top: 0,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Semantics(
                button: true,
                label: exitTooltip,
                child: Tooltip(
                  message: exitTooltip,
                  child: Material(
                    color: Colors.black.withValues(alpha: 0.68),
                    shape: const CircleBorder(),
                    elevation: 2,
                    shadowColor: Colors.black54,
                    child: InkWell(
                      key: exitButtonKey,
                      customBorder: const CircleBorder(),
                      onTap: onExit,
                      child: const SizedBox.square(
                        dimension: 44,
                        child: Icon(Remix.fullscreen_exit_line, size: 22, color: Colors.white),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
