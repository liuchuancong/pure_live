import 'dart:convert';

import 'package:pure_live/domains/iptv/domain/channel.dart';
import 'package:pure_live/domains/iptv/domain/playlist_parse_result.dart';
import 'package:pure_live/core/network/http_header_policy.dart';

/// Parses M3U and M3U Plus playlist formats.
///
/// Supports:
/// - Standard M3U (#EXTM3U / #EXTINF)
/// - M3U Plus extended attributes (tvg-id, tvg-name, tvg-logo, group-title, etc.)
/// - Channel numbering through tvg-chno
/// - Multiple URL formats (HTTP, HTTPS, RTMP, RTSP, UDP)
/// - EXTGRP inheritance and explicit group-title reset
class M3uParser {
  static const String _extInf = '#EXTINF:';
  static const String _extGrp = '#EXTGRP:';
  static const String _extVlcOpt = '#EXTVLCOPT:';
  static const String _extHttp = '#EXTHTTP:';
  static const String _kodiProp = '#KODIPROP:';
  static const Set<String> _nonHttpUrlOptions = {
    'seekable',
    'reconnect_at_eof',
    'reconnect_streamed',
    'reconnect_delay_max',
    'icy',
    'icy_metadata_headers',
    'icy_metadata_packet',
  };

  static String? lastEpgUrl;

  static final _header = RegExp(r'^#EXTM3U(?:\s|$)');

  PlaylistParseResult parse(String content, {required String providerId}) {
    final lines = content.split(RegExp(r'\r\n?|\n'));
    final channels = <Channel>[];
    final errors = <String>[];
    bool sawContent = false;
    _M3uMetadata? pending;
    int pendingLine = 0;
    String? directiveGroup;
    var headerAttributes = const <String, String>{};
    var pendingHeaders = <String, String>{};
    var nextEntryHeaders = <String, String>{};

    for (var i = 0; i < lines.length; i++) {
      final line = lines[i].trim();
      if (line.isEmpty) continue;
      if (!sawContent) {
        sawContent = true;
        if (!_header.hasMatch(line)) errors.add('Line ${i + 1}: Missing #EXTM3U header');
      }
      if (_header.hasMatch(line)) {
        final headerMetadata = line.substring('#EXTM3U'.length).trim();
        if (headerMetadata.isNotEmpty) {
          try {
            headerAttributes = _parseMetadata(headerMetadata).attributes;
          } on FormatException catch (e) {
            errors.add('Line ${i + 1}: ${e.message}');
          }
        }
        continue;
      }
      if (line.startsWith(_extInf)) {
        if (pending != null) errors.add('Line $pendingLine: Missing stream URL');
        pending = null;
        pendingHeaders = nextEntryHeaders;
        nextEntryHeaders = <String, String>{};
        pendingLine = i + 1;
        try {
          pending = _parseMetadata(line.substring(_extInf.length));
          // A group-title belongs to this entry and ends EXTGRP inheritance.
          if (pending.attributes.containsKey('group-title')) directiveGroup = null;
        } on FormatException catch (e) {
          errors.add('Line $pendingLine: ${e.message}');
        }
        continue;
      }
      if (line.startsWith(_extGrp)) {
        directiveGroup = _emptyToNull(line.substring(_extGrp.length).trim());
        continue;
      }
      if (line.startsWith(_extVlcOpt) || line.startsWith(_extHttp) || line.startsWith(_kodiProp)) {
        final target = pending == null ? nextEntryHeaders : pendingHeaders;
        try {
          if (line.startsWith(_extVlcOpt)) {
            _applyHttpProperty(target, line.substring(_extVlcOpt.length));
          } else if (line.startsWith(_extHttp)) {
            _applyExtHttp(target, line.substring(_extHttp.length));
          } else {
            _applyKodiProperty(target, line.substring(_kodiProp.length));
          }
        } on FormatException catch (e) {
          errors.add('Line ${i + 1}: ${e.message}');
        }
        continue;
      }
      // Unknown extension directives are not stream URLs.
      if (line.startsWith('#')) continue;
      if (pending != null) {
        try {
          channels.add(_parseEntry(pending, line, providerId, directiveGroup, headerAttributes, pendingHeaders));
        } on FormatException catch (e) {
          errors.add('Line ${i + 1}: ${e.message}');
        }
        pending = null;
        pendingHeaders = <String, String>{};
      }
    }
    if (pending != null) errors.add('Line $pendingLine: Missing stream URL');
    if (!sawContent) errors.add('Playlist content is empty');
    return PlaylistParseResult(channels: channels, errors: errors);
  }

  Channel _parseEntry(
    _M3uMetadata metadata,
    String url,
    String providerId,
    String? directiveGroup,
    Map<String, String> headerAttributes,
    Map<String, String> directiveHeaders,
  ) {
    final parsedStream = _parseStreamUrl(url);
    if (!_isValidStreamUrl(parsedStream.url)) throw const FormatException('Invalid or unsupported stream URL');
    final attrs = {...metadata.attributes};
    if (!attrs.containsKey('group-title') && directiveGroup != null) attrs['group-title'] = directiveGroup;
    final name = metadata.displayName.isNotEmpty ? metadata.displayName : attrs['tvg-name'];
    if (name == null || name.isEmpty) throw const FormatException('Missing channel name');

    // 生成唯一频道ID
    final tvgId = attrs['tvg-id'];
    final String uniqueKey;

    // 智能生成唯一键：优先 tvg-id → 其次频道名 → 最后链接
    if (tvgId != null && tvgId.isNotEmpty) {
      uniqueKey = tvgId;
    } else if (name.isNotEmpty) {
      uniqueKey = name;
    } else {
      uniqueKey = parsedStream.url;
    }
    final channelId = '${providerId}_${uniqueKey.hashCode}';

    // 解析频道序号
    int? channelNumber;
    final chnoStr = attrs['tvg-chno'];
    if (chnoStr != null) channelNumber = int.tryParse(chnoStr);

    final catchupSource = _emptyToNull(attrs['catchup-source']) ?? _emptyToNull(headerAttributes['catchup-source']);
    final legacyDays = _finiteDouble(attrs['timeshift']) ?? _finiteDouble(attrs['tvg-rec']);
    final catchupDays =
        _finiteDouble(attrs['catchup-days']) ?? _finiteDouble(headerAttributes['catchup-days']) ?? legacyDays;
    var catchupMode =
        (_emptyToNull(attrs['catchup']) ??
                _emptyToNull(attrs['catchup-type']) ??
                _emptyToNull(headerAttributes['catchup']) ??
                _emptyToNull(headerAttributes['catchup-type']))
            ?.toLowerCase();
    if (const {'0', 'false', 'off', 'none', 'disabled'}.contains(catchupMode) || catchupDays == 0) {
      catchupMode = 'disabled';
    } else if (catchupMode == null && legacyDays != null && legacyDays > 0) {
      catchupMode = 'shift';
    } else if (catchupMode == null && catchupSource != null) {
      catchupMode = 'default';
    }
    final catchupCorrectionHours =
        _finiteDouble(attrs['catchup-correction']) ?? _finiteDouble(headerAttributes['catchup-correction']);
    final httpHeaders = HttpHeaderPolicy.normalize({
      ..._metadataHttpHeaders(headerAttributes),
      ..._metadataHttpHeaders(attrs),
      ...directiveHeaders,
      ...parsedStream.headers,
    });

    return Channel(
      id: channelId,
      providerId: providerId,
      name: name,
      tvgId: _emptyToNull(attrs['tvg-id']),
      tvgName: _emptyToNull(attrs['tvg-name']),
      tvgLogo: _emptyToNull(attrs['tvg-logo']),
      groupTitle: _emptyToNull(attrs['group-title']),
      channelNumber: channelNumber,
      streamUrl: parsedStream.url,
      streamType: _inferStreamType(attrs, parsedStream.url),
      catchupMode: catchupMode,
      catchupSource: catchupSource,
      catchupDays: catchupDays,
      catchupCorrectionHours: catchupCorrectionHours,
      httpHeaders: httpHeaders,
    );
  }

  static Map<String, String> _metadataHttpHeaders(Map<String, String> attributes) {
    final result = <String, String>{};
    for (final key in const <String>[
      'user-agent',
      'http-user-agent',
      'referer',
      'referrer',
      'http-referer',
      'http-referrer',
      'origin',
      'authorization',
      'cookie',
      'cookies',
    ]) {
      final value = attributes[key];
      if (value != null && value.trim().isNotEmpty) result[key] = value;
    }
    return result;
  }

  static void _applyHttpProperty(Map<String, String> target, String content) {
    final separator = content.indexOf('=');
    final rawName = separator < 0 ? content.trim() : content.substring(0, separator).trim();
    final canonical = HttpHeaderPolicy.canonicalName(rawName);
    if (!const {'user-agent', 'referer'}.contains(canonical)) return;
    if (separator <= 0 || separator == content.length - 1) {
      throw const FormatException('Invalid stream header directive');
    }
    final value = content.substring(separator + 1).trim();
    final normalized = HttpHeaderPolicy.normalize({canonical!: value});
    if (normalized.isEmpty) throw const FormatException('Invalid stream header directive');
    target.addAll(normalized);
  }

  static void _applyKodiProperty(Map<String, String> target, String content) {
    final separator = content.indexOf('=');
    final name = separator < 0 ? content.trim().toLowerCase() : content.substring(0, separator).trim().toLowerCase();
    if (name.endsWith('.stream_headers') || name.endsWith('.manifest_headers')) {
      if (separator <= 0 || separator == content.length - 1) {
        throw const FormatException('Invalid stream header directive');
      }
      target.addAll(_parseHeaderOptions(content.substring(separator + 1)));
      return;
    }
    _applyHttpProperty(target, content);
  }

  static void _applyExtHttp(Map<String, String> target, String content) {
    final value = content.trim();
    if (value.isEmpty) throw const FormatException('Invalid EXTHTTP header');
    if (value.startsWith('{')) {
      try {
        final decoded = jsonDecode(value);
        if (decoded is! Map) throw const FormatException('Invalid EXTHTTP header');
        for (final entry in decoded.entries) {
          if (entry.key is! String ||
              entry.value is! String ||
              HttpHeaderPolicy.normalize({entry.key: entry.value}).isEmpty) {
            throw const FormatException('Invalid EXTHTTP header');
          }
        }
        final normalized = HttpHeaderPolicy.normalize(decoded);
        target.addAll(normalized);
      } on FormatException {
        throw const FormatException('Invalid EXTHTTP header');
      }
      return;
    }
    target.addAll(_parseHeaderOptions(value));
  }

  static _ParsedStream _parseStreamUrl(String raw) {
    final separator = raw.indexOf('|');
    if (separator < 0) return _ParsedStream(raw.trim(), const <String, String>{});
    final url = raw.substring(0, separator).trim();
    final options = raw.substring(separator + 1);
    if (url.isEmpty || options.trim().isEmpty) {
      throw const FormatException('Invalid stream header option');
    }
    return _ParsedStream(url, _parseHeaderOptions(options, ignoreTransportOptions: true));
  }

  static Map<String, String> _parseHeaderOptions(String options, {bool ignoreTransportOptions = false}) {
    final headers = <String, String>{};
    for (final option in options.split('&')) {
      final equals = option.indexOf('=');
      if (equals <= 0 || equals == option.length - 1) {
        throw const FormatException('Invalid stream header option');
      }
      try {
        final rawName = Uri.decodeQueryComponent(option.substring(0, equals).trim());
        final value = Uri.decodeQueryComponent(option.substring(equals + 1).trim());
        if (ignoreTransportOptions && !rawName.startsWith('!') && _nonHttpUrlOptions.contains(rawName.toLowerCase())) {
          continue;
        }
        final normalized = HttpHeaderPolicy.normalize({rawName: value});
        if (normalized.isEmpty) throw const FormatException('Invalid stream header option');
        headers.addAll(normalized);
      } on FormatException {
        throw const FormatException('Invalid stream header option');
      }
    }
    return HttpHeaderPolicy.normalize(headers);
  }

  /// Read one attribute at a time, stopping at the first comma outside a
  /// quoted value. Display text is never scanned as metadata. Quoted values
  /// may contain commas and the opposite quote; unquoted values end at space.
  static _M3uMetadata _parseMetadata(String content) {
    final attributes = <String, String>{};
    int i = 0;
    while (i < content.length) {
      while (i < content.length && _space(content.codeUnitAt(i))) {
        i++;
      }
      if (i == content.length) break;
      if (content[i] == ',') return _M3uMetadata(attributes, content.substring(i + 1).trim());
      final keyStart = i;
      while (i < content.length && !_space(content.codeUnitAt(i)) && content[i] != '=' && content[i] != ',') {
        i++;
      }
      final key = content.substring(keyStart, i).toLowerCase();
      while (i < content.length && _space(content.codeUnitAt(i))) {
        i++;
      }
      // Skip duration and unknown bare tokens without losing the next key.
      if (i == content.length || content[i] != '=') continue;
      if (key.isEmpty) throw const FormatException('Missing attribute key');
      i++;
      while (i < content.length && _space(content.codeUnitAt(i))) {
        i++;
      }
      String value;
      if (i < content.length && (content[i] == '"' || content[i] == "'")) {
        final quote = content[i++];
        final start = i;
        while (i < content.length && content[i] != quote) {
          i++;
        }
        if (i == content.length) throw const FormatException('Unclosed attribute quote');
        value = content.substring(start, i++);
        if (i < content.length && !_space(content.codeUnitAt(i)) && content[i] != ',') {
          throw const FormatException('Missing separator after quoted attribute');
        }
      } else {
        final start = i;
        while (i < content.length && !_space(content.codeUnitAt(i)) && content[i] != ',') {
          i++;
        }
        value = content.substring(start, i);
      }
      attributes[key] = value.trim();
    }
    // Retain the existing tvg-name fallback for a missing display delimiter.
    return _M3uMetadata(attributes, '');
  }

  static bool _space(int c) => c == 32 || (c >= 9 && c <= 13);

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

  static double? _finiteDouble(String? value) {
    final parsed = double.tryParse(value?.trim() ?? '');
    return parsed != null && parsed.isFinite ? parsed : null;
  }
}

class _M3uMetadata {
  const _M3uMetadata(this.attributes, this.displayName);
  final Map<String, String> attributes;
  final String displayName;
}

class _ParsedStream {
  const _ParsedStream(this.url, this.headers);
  final String url;
  final Map<String, String> headers;
}

/// 解析结果实体
class M3uResult {
  final List<Channel> channels;
  final List<String> errors;

  const M3uResult({required this.channels, this.errors = const []});

  bool get hasErrors => errors.isNotEmpty;
  int get channelCount => channels.length;
}
