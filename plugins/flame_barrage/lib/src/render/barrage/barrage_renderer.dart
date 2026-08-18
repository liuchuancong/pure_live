import 'dart:ui';
import 'package:flame_barrage/flame_barrage.dart';

class BarrageRenderer {
  BarrageRenderer({required this.parser, required this.layout, required this.mixedRenderer});

  final RichParser parser;
  final MixedLayout layout;
  final MixedRenderer mixedRenderer;

  Picture render(BarrageItem item, BarrageConfig config) {
    final fragments = parser.parse(item.content);
    final layoutResult = layout.layout(fragments, item: item, config: config);

    switch (item.type) {
      case BarrageType.scroll:
      case BarrageType.topFixed:
      case BarrageType.bottomFixed:
        return mixedRenderer.buildPicture(layoutResult);
    }
  }

  List<Picture> renderBatch(List<BarrageItem> items, BarrageConfig config) {
    return items.map((e) => render(e, config)).toList();
  }

  String buildCacheKey(BarrageItem item, BarrageConfig config) {
    return [
      item.content,
      item.type.name,
      config.fontSize,
      config.fontWeight.toString(),
      config.textColor.toARGB32(),
      config.emojiSize,
    ].join('_');
  }
}
