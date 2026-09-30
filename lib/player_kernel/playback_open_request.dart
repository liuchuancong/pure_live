import 'package:flutter/foundation.dart';
import 'package:pure_live/common/models/live_room.dart';

/// 一次源打开的权威回执：页面据此渲染画质/线路状态。
@immutable
class KernelPlaybackCommit {
  const KernelPlaybackCommit({
    required this.revision,
    required this.sessionId,
    required this.room,
    required this.urls,
    required this.currentUrl,
    required this.currentLineIndex,
    required this.headers,
  });

  final int revision;
  final int sessionId;
  final LiveRoom room;
  final List<String> urls;
  final String currentUrl;
  final int currentLineIndex;
  final Map<String, String> headers;

  int get lineCount => urls.length;
  bool get isCurrent => currentUrl == urls[currentLineIndex];
}
