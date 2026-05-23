import 'dart:convert';
import 'package:pure_live/model/live_category.dart';
import 'package:string_similarity/string_similarity.dart';
import 'package:pure_live/common/utils/hive_pref_util.dart';

class AreaPicMapper {
  static final Map<String, String> _picMap = {};
  static bool _isLoaded = false;

  static final Map<String, String> _hardcodedAliases = {
    '射击游戏': '穿越火线',
    'fps': '穿越火线',
    'cs2': '穿越火线',
    'csgo': '穿越火线',
    'cf': '穿越火线',

    '网游竞技': '英雄联盟',
    '竞技游戏': '英雄联盟',
    'moba': '英雄联盟',
    'dota2': '英雄联盟',

    '休闲益智': '互动组队',
    '文化': '成年教育',

    '娱乐生活': '户外',
    '交友娱乐': '户外',
    '吃喝玩乐': '户外',

    '角色扮演': '原神',
    'rpg': '原神',
    'mmo': '原神',

    '策略卡牌': '金铲铲之战',
    '棋牌策略': '金铲铲之战',
  };

  static void _ensureLoaded() {
    if (_isLoaded) return;
    try {
      final String? jsonStr = HivePrefUtil.getString('cached_area_pics');
      if (jsonStr != null && jsonStr.isNotEmpty) {
        final Map<String, dynamic> decoded = jsonDecode(jsonStr);
        decoded.forEach((key, value) {
          _picMap[key] = value.toString();
        });
      }
    } catch (_) {}
    _isLoaded = true;
  }

  static void updateAreaListMaps(List<LiveCategory> categories) {
    _ensureLoaded();
    bool hasChanged = false;
    for (var cat in categories) {
      if (cat.children.isNotEmpty) {
        for (var area in cat.children) {
          if (area.areaName != null && area.areaPic != null && area.areaPic!.isNotEmpty) {
            if (_picMap[area.areaName!] != area.areaPic!) {
              _picMap[area.areaName!] = area.areaPic!;
              hasChanged = true;
            }
          }
        }
      }
    }
    if (hasChanged) {
      HivePrefUtil.setString('cached_area_pics', jsonEncode(_picMap));
    }
  }

  static String getPic(String? areaName) {
    if (areaName == null || areaName.isEmpty) return '';
    _ensureLoaded();

    final cleanLowerName = areaName.trim().toLowerCase();

    for (final cachedKey in _picMap.keys) {
      if (cachedKey.trim().toLowerCase() == cleanLowerName) {
        return _picMap[cachedKey]!;
      }
    }

    if (_hardcodedAliases.containsKey(cleanLowerName)) {
      final standardLowerName = _hardcodedAliases[cleanLowerName]!.trim().toLowerCase();
      for (final cachedKey in _picMap.keys) {
        if (cachedKey.trim().toLowerCase() == standardLowerName) {
          return _picMap[cachedKey]!;
        }
      }
    }

    for (final cachedKey in _picMap.keys) {
      final cachedLowerKey = cachedKey.trim().toLowerCase();
      if (cleanLowerName.contains(cachedLowerKey) || cachedLowerKey.contains(cleanLowerName)) {
        if (_picMap[cachedKey]!.isNotEmpty) {
          return _picMap[cachedKey]!;
        }
      }
    }

    String bestMatchKey = '';
    double bestScore = 0.0;

    for (final cachedName in _picMap.keys) {
      final score = _fuzzyMatchScoreAnd(cleanLowerName, [cachedName]);
      if (score > bestScore) {
        bestScore = score;
        bestMatchKey = cachedName;
      }
    }

    if (bestScore > 0.0 && bestMatchKey.isNotEmpty) {
      return _picMap[bestMatchKey]!;
    }

    for (final alias in _hardcodedAliases.keys) {
      if (cleanLowerName.contains(alias)) {
        final standardLowerName = _hardcodedAliases[alias]!.trim().toLowerCase();
        for (final cachedKey in _picMap.keys) {
          if (cachedKey.trim().toLowerCase() == standardLowerName) {
            return _picMap[cachedKey]!;
          }
        }
      }
    }

    String fallbackMatchKey = '';
    double fallbackBestScore = 0.0;

    for (final cachedName in _picMap.keys) {
      final score = _fuzzyMatchScoreOr(cleanLowerName, [cachedName]);
      if (score > fallbackBestScore) {
        fallbackBestScore = score;
        fallbackMatchKey = cachedName;
      }
    }

    if (fallbackBestScore > 0.0 && fallbackMatchKey.isNotEmpty) {
      return _picMap[fallbackMatchKey]!;
    }

    return '';
  }

  static List<String> _tokenizeQuery(String query) {
    return query.toLowerCase().split(RegExp(r'[\s,;|：:_—\-]+')).where((t) => t.isNotEmpty && t.length > 1).toList();
  }

  static String _buildSearchBlob(List<String?> fields) {
    return fields.where((f) => f != null).join(' ').toLowerCase();
  }

  static double _fuzzyMatchScoreAnd(String query, List<String?> fields) {
    final tokens = _tokenizeQuery(query);
    if (tokens.isEmpty) return 0.0;

    final blob = _buildSearchBlob(fields);
    final blobWords = blob.split(RegExp(r'[\s,;|：:_—\-]+')).where((w) => w.isNotEmpty).toList();

    var score = 0.0;
    for (final token in tokens) {
      if (blob.contains(token)) {
        score += 1.0;
      } else {
        var bestSim = 0.0;
        for (final word in blobWords) {
          final sim = StringSimilarity.compareTwoStrings(token, word);
          if (sim > bestSim) bestSim = sim;
        }
        if (bestSim > 0.6) {
          score += 0.5;
        } else {
          return 0.0;
        }
      }
    }
    return score;
  }

  static double _fuzzyMatchScoreOr(String query, List<String?> fields) {
    final tokens = _tokenizeQuery(query);
    if (tokens.isEmpty) return 0.0;

    final blob = _buildSearchBlob(fields);
    final blobWords = blob.split(RegExp(r'[\s,;|：:_—\-]+')).where((w) => w.isNotEmpty).toList();

    var totalScore = 0.0;
    bool hasAnyMatch = false;

    for (final token in tokens) {
      if (blob.contains(token)) {
        totalScore += 1.0;
        hasAnyMatch = true;
      } else {
        var bestSim = 0.0;
        for (final word in blobWords) {
          final sim = StringSimilarity.compareTwoStrings(token, word);
          if (sim > bestSim) bestSim = sim;
        }
        if (bestSim > 0.6) {
          totalScore += 0.5;
          hasAnyMatch = true;
        }
      }
    }
    return hasAnyMatch ? totalScore : 0.0;
  }
}
