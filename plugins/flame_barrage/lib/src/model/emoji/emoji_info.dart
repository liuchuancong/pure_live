import 'package:flame_barrage/src/model/emoji/emogi_source_type.dart';

class EmojiInfo {
  const EmojiInfo({
    required this.id,
    required this.asset,
    required this.keys,
    this.sourceType = EmojiSourceType.asset,
    this.width = 24,
    this.height = 24,
  });

  final String id;
  final String asset;
  final List<String> keys;
  final EmojiSourceType sourceType;
  final double width;
  final double height;
}
