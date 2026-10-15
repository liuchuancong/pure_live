import 'dart:convert';

import 'package:live_sites/src/platforms/xiaohongshu/api/xiaohongshu_endpoints.dart';
import 'package:live_sites/src/platforms/xiaohongshu/parsers/xiaohongshu_failure.dart';
import 'package:live_sites/src/platforms/xiaohongshu/parsers/xiaohongshu_json.dart';

/// The hydration state of a Xiaohongshu share page (3.x's page reader):
/// the one `<script>` whose text starts with the marker, its `undefined`
/// tokens made JSON, and the `liveStream` slice the room lives in.
abstract final class XiaohongshuHtml {
  /// `liveStream` of the one `<script>` whose text starts with
  /// `window.__INITIAL_STATE__=`, as 3.x found it; bare `undefined` outside
  /// strings becomes `null` and nothing else of JavaScript is accepted.
  static Map<String, dynamic> liveStream(String page) {
    const limit = XiaohongshuEndpoints.responseLimit;
    if (page.length > limit || (page.length > limit ~/ 3 && utf8.encode(page).length > limit)) {
      throw const XiaohongshuFailure(XiaohongshuFailureKind.apiChanged, 'share page: over $limit bytes');
    }
    const marker = 'window.__INITIAL_STATE__=';
    // A script's content is raw text closed by the first `</script`, so a
    // non-greedy scan reads it as the browser does.
    final scripts = [
      for (final match in _script.allMatches(page))
        if ((match.group(2) ?? '').trimLeft().startsWith(marker)) match.group(2) ?? '',
    ];
    if (scripts.length != 1) {
      throw XiaohongshuFailure(XiaohongshuFailureKind.apiChanged, 'share page: ${scripts.length} hydration scripts');
    }
    var source = scripts.single.trim().substring(marker.length).trim();
    if (source.endsWith(';')) source = source.substring(0, source.length - 1).trimRight();
    final Object? decoded;
    try {
      decoded = jsonDecode(hydrationJson(source));
    } on FormatException {
      throw const XiaohongshuFailure(XiaohongshuFailureKind.apiChanged, 'share page: hydration state is not JSON');
    }
    return XiaohongshuJson.object(XiaohongshuJson.object(decoded, 'hydration state')['liveStream'], 'liveStream');
  }

  /// [source] with every bare `undefined` token outside strings written as
  /// `null` (3.x's scanner): a global replace would corrupt titles and URLs
  /// holding the word, and `jsonDecode` still rejects anything else.
  static String hydrationJson(String source) {
    final result = StringBuffer();
    var quoted = false;
    var escaped = false;
    for (var i = 0; i < source.length; i++) {
      final char = source[i];
      if (quoted) {
        result.write(char);
        if (escaped) {
          escaped = false;
        } else if (char == r'\') {
          escaped = true;
        } else if (char == '"') {
          quoted = false;
        }
      } else if (char == '"') {
        quoted = true;
        result.write(char);
      } else if (source.startsWith('undefined', i)) {
        result.write('null');
        i += 'undefined'.length - 1;
      } else {
        result.write(char);
      }
    }
    return result.toString();
  }

  static final RegExp _script = RegExp(r'(<script\b[^>]*>)([\s\S]*?)</script\s*>', caseSensitive: false);
}
