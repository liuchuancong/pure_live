import 'package:pure_live/core/iptv/models/channel.dart';
import 'package:pure_live/core/iptv/parsers/playlist_parse_result.dart';

/// Parses M3U and M3U Plus playlist formats.
///
/// Supports:
/// - Standard M3U (#EXTM3U / #EXTINF)
/// - M3U Plus extended attributes (tvg-id, tvg-name, tvg-logo, group-title, etc.)
/// - Xtream Codes style attributes (tvg-chno, tvg-shift)
/// - Multiple URL formats (HTTP, HTTPS, RTMP, RTSP, UDP)
/// - Auto extract EPG url from header
class M3uParser {
  static const String _extM3U = '#EXTM3U';
  static const String _extInf = '#EXTINF:';
  static const String _extGrp = '#EXTGRP:';

  static String? lastEpgUrl;

  PlaylistParseResult parse(String content, {required String providerId}) {
    final lines = content.split(RegExp(r'\r?\n'));
    final channels = <Channel>[];
    final errors = <String>[];
    if (lines.isEmpty) {
      errors.add('Playlist content is empty');
    } else {
      final firstLine = lines.first.trim();
      if (!firstLine.startsWith(_extM3U)) {
        errors.add('Missing #EXTM3U header');
      }
    }

    String? currentExtInf;
    int lineIndex = 0;

    for (var line in lines) {
      lineIndex++;
      final trimLine = line.trim();
      if (trimLine.isEmpty || trimLine == _extM3U) continue;
      if (trimLine.startsWith('$_extM3U ')) continue;

      if (trimLine.startsWith(_extInf)) {
        currentExtInf = trimLine;
        continue;
      }
      // 兼容分组标签
      if (trimLine.startsWith(_extGrp)) continue;
      // 跳过其他注释行
      if (trimLine.startsWith('#')) continue;

      // 解析流地址
      if (currentExtInf != null) {
        try {
          final channel = _parseEntry(currentExtInf, trimLine, providerId);
          if (channel != null) channels.add(channel);
        } catch (e) {
          errors.add('Line $lineIndex: ${e.toString()}');
        }
        currentExtInf = null;
      }
    }

    return PlaylistParseResult(channels: channels, errors: errors);
  }

  Channel? _parseEntry(String extInf, String url, String providerId) {
    if (url.isEmpty || !_isValidStreamUrl(url)) return null;

    final attrs = _parseAttributes(extInf);
    final displayName = _parseDisplayName(extInf);
    final name = displayName.isNotEmpty ? displayName : attrs['tvg-name'];
    if (name == null || name.isEmpty) return null;

    // 生成唯一频道ID
    final tvgId = attrs['tvg-id'];
    final String uniqueKey;

    // 智能生成唯一键：优先 tvg-id → 其次频道名 → 最后链接
    if (tvgId != null && tvgId.isNotEmpty) {
      uniqueKey = tvgId;
    } else if (name.isNotEmpty) {
      uniqueKey = name;
    } else {
      uniqueKey = url;
    }
    final channelId = '${providerId}_${uniqueKey.hashCode}';

    // 解析频道序号
    int? channelNumber;
    final chnoStr = attrs['tvg-chno'];
    if (chnoStr != null) channelNumber = int.tryParse(chnoStr);

    return Channel(
      id: channelId,
      providerId: providerId,
      name: name,
      tvgId: _emptyToNull(attrs['tvg-id']),
      tvgName: _emptyToNull(attrs['tvg-name']),
      tvgLogo: _emptyToNull(attrs['tvg-logo']),
      groupTitle: _emptyToNull(attrs['group-title']),
      channelNumber: channelNumber,
      streamUrl: url,
      streamType: _inferStreamType(attrs, url),
    );
  }

  /// 增强属性解析：支持双引号/单引号/无引号
  static Map<String, String> _parseAttributes(String content) {
    final Map<String, String> attributes = {};

    // Regular expression to match key="value" or key=value patterns
    final RegExp attrRegex = RegExp(r'(\S+?)=["\u0027]?([^"\u0027]+)["\u0027]?(?:\s|$)');

    for (final match in attrRegex.allMatches(content)) {
      if (match.groupCount >= 2) {
        final key = match.group(1)?.toLowerCase();
        final value = match.group(2);
        if (key != null && value != null) {
          attributes[key] = value.trim();
        }
      }
    }

    return attributes;
  }

  /// 截取逗号后的频道名称
  String _parseDisplayName(String extInf) {
    final commaIndex = extInf.lastIndexOf(',');
    return commaIndex == -1 ? '' : extInf.substring(commaIndex + 1).trim();
  }

  /// 自动判断流类型：直播/电影/剧集
  StreamType _inferStreamType(Map<String, String> attrs, String url) {
    final group = attrs['group-title']?.toLowerCase() ?? '';
    final lowerUrl = url.toLowerCase();

    if (group.contains('vod') || group.contains('movie') || lowerUrl.contains('/movie/')) {
      return StreamType.vod;
    }
    if (group.contains('series') || lowerUrl.contains('/series/')) {
      return StreamType.series;
    }
    return StreamType.live;
  }

  /// 校验直播地址协议合法性
  bool _isValidStreamUrl(String url) {
    try {
      final uri = Uri.parse(url);
      return uri.hasScheme && const {'http', 'https', 'rtmp', 'rtsp', 'udp', 'mms'}.contains(uri.scheme);
    } catch (_) {
      return false;
    }
  }

  /// 空字符串转为null
  String? _emptyToNull(String? value) {
    return (value == null || value.isEmpty) ? null : value;
  }
}

/// 解析结果实体
class M3uResult {
  final List<Channel> channels;
  final List<String> errors;

  const M3uResult({required this.channels, this.errors = const []});

  bool get hasErrors => errors.isNotEmpty;
  int get channelCount => channels.length;
}
