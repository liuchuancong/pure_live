import '../core/barrage_engine.dart';
import 'package:flutter/material.dart';
import '../components/barrage_component.dart';

typedef OnBarrageTap = void Function(BarrageComponent component);

class BarrageOverlay extends StatelessWidget {
  const BarrageOverlay({super.key, required this.engine, required this.child, this.onBarrageTap});

  final BarrageEngine engine;
  final Widget child;
  final OnBarrageTap? onBarrageTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTapDown: (TapDownDetails details) {
        if (onBarrageTap == null) return;

        final RenderBox? renderBox = context.findRenderObject() as RenderBox?;
        if (renderBox == null || !renderBox.hasSize) return;

        final localPosition = renderBox.globalToLocal(details.globalPosition);
        final activeComponents = engine.children.whereType<BarrageComponent>();

        for (final comp in activeComponents) {
          if (comp.isRemoving || !comp.isMounted) continue;

          final double left = comp.position.x;
          final double top = comp.position.y;
          final double right = left + comp.size.x;
          final double bottom = top + comp.size.y;

          if (localPosition.dx >= left &&
              localPosition.dx <= right &&
              localPosition.dy >= top &&
              localPosition.dy <= bottom) {
            onBarrageTap?.call(comp);
            break;
          }
        }
      },
      child: child,
    );
  }
}
