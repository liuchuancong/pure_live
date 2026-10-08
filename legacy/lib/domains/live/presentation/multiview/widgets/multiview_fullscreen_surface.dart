import 'package:flutter/material.dart';
import 'package:remixicon/remixicon.dart';

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
                        dimension: kMinInteractiveDimension,
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
