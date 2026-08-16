import 'dart:ui' as ui;
import '../layout/layout_span.dart';
import '../core/barrage_config.dart';
import '../model/barrage/barrage_item.dart';

abstract class BarrageEffectInterceptor {
  const BarrageEffectInterceptor();

  bool shouldIntercept(BarrageItem item, BarrageConfig config);

  LayoutSpan createCustomSpan({
    required BarrageItem item,
    required String text,
    required ui.Paragraph paragraph,
    required double x,
    required double y,
    required double width,
    required double height,
    required BarrageConfig config,
  });
}
