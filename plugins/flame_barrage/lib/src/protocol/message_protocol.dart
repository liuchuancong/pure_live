import '../model/barrage/barrage_item.dart';
import '../model/barrage/barrage_type.dart';

class MessageProtocol {
  const MessageProtocol();

  BarrageItem? fromWebSocketJson(Map<String, dynamic> json) {
    final typeStr = json['type'] as String? ?? 'scroll';
    BarrageType type;

    if (typeStr == 'topFixed') {
      type = BarrageType.topFixed;
    } else if (typeStr == 'bottomFixed') {
      type = BarrageType.bottomFixed;
    } else {
      type = BarrageType.scroll;
    }

    final content = json['content'] as String?;
    if (content == null || content.isEmpty) {
      return null;
    }

    return BarrageItem(content: content, type: type, priority: (json['vip'] as bool? ?? false) ? 1 : 0);
  }
}
