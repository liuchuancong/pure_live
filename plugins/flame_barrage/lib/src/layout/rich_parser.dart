import 'dart:collection';

import 'package:flame_barrage/flame_barrage.dart';

class RichParser {
  RichParser({required this.atlas, int maxCacheSize = 1000}) : _maxCacheSize = maxCacheSize.clamp(1, 10000).toInt();

  final EmojiAtlas atlas;
  final LinkedHashMap<String, List<Fragment>> _cache = LinkedHashMap<String, List<Fragment>>();
  int _maxCacheSize;

  int get cacheCount => _cache.length;

  bool containsCache(String content) {
    return _cache.containsKey(content);
  }

  void clearCache() {
    _cache.clear();
  }

  void updateMaxCacheSize(int value) {
    _maxCacheSize = value.clamp(1, 10000).toInt();
    while (_cache.length > _maxCacheSize) {
      _cache.remove(_cache.keys.first);
    }
  }

  void removeCache(String content) {
    _cache.remove(content);
  }

  List<Fragment> parse(String content) {
    if (content.isEmpty) {
      return const [];
    }

    final cached = _cache[content];
    if (cached != null) {
      _cache.remove(content);
      _cache[content] = cached;
      return List<Fragment>.from(cached);
    }

    final fragments = _parseInternal(content);

    if (_cache.length >= _maxCacheSize) {
      _cache.remove(_cache.keys.first);
    }

    _cache[content] = fragments;

    return List<Fragment>.from(fragments);
  }

  List<Fragment> _parseInternal(String content) {
    final regex = atlas.regex;

    if (regex == null || !regex.hasMatch(content)) {
      return [TextFragment(content)];
    }

    final result = <Fragment>[];
    int lastIndex = 0;

    for (final match in regex.allMatches(content)) {
      if (match.start > lastIndex) {
        result.add(TextFragment(content.substring(lastIndex, match.start)));
      }

      final key = match.group(0);
      if (key != null) {
        final emojiInfo = atlas.find(key);
        if (emojiInfo != null) {
          if (emojiInfo.sourceType == EmojiSourceType.atlas) {
            result.add(SpriteFragment(key));
          } else {
            result.add(EmojiFragment(emojiInfo));
          }
        } else {
          result.add(TextFragment(key));
        }
      }

      lastIndex = match.end;
    }

    if (lastIndex < content.length) {
      result.add(TextFragment(content.substring(lastIndex)));
    }

    return result;
  }

  void warmUp(Iterable<String> contents) {
    for (final content in contents) {
      parse(content);
    }
  }

  Map<String, dynamic> debugInfo() {
    return {'cacheCount': _cache.length};
  }
}
