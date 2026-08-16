import '../model/emoji/emoji_info.dart';
import '../model/emoji/emogi_source_type.dart';

class EmojiProtocol {
  const EmojiProtocol();

  List<EmojiInfo> parseRegistryJson(List<dynamic> jsonList) {
    final result = <EmojiInfo>[];
    final len = jsonList.length;
    for (int i = 0; i < len; i++) {
      final item = jsonList[i] as Map<String, dynamic>;
      final keysList = (item['keys'] as List<dynamic>).map((e) => e.toString()).toList();

      result.add(
        EmojiInfo(
          id: item['id'] as String,
          keys: keysList,
          asset: item['asset'] as String,
          width: (item['width'] ?? 24.0).toDouble(),
          height: (item['height'] ?? 24.0).toDouble(),
          sourceType: EmojiSourceType.asset,
        ),
      );
    }
    return result;
  }
}
