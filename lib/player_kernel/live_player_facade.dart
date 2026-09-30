import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:media_core/media_core.dart';
import 'package:pure_live/common/models/live_room.dart';
import 'package:pure_live/player_kernel/live_playback_session.dart';
import 'package:pure_live/player_kernel/playback_open_request.dart';

/// 直播播放的宿主门面：一房一会话，页面只跟它说话。
///
/// 播放内核、恢复、呈现全部是 media_core 的；本门面只做 pure_live 业务
/// 编排：源提交回执（画质/线路的权威状态）、房间音量、owned 私有源
/// recipe 注入。
class LivePlayerFacade {
  LivePlayerFacade({LivePlaybackSession? session}) : _session = session ?? LivePlaybackSession();

  final LivePlaybackSession _session;
  int _commitRevision = 0;

  LiveRoom? _room;
  KernelPlaybackCommit? _commit;

  LiveRoom? get room => _room;
  KernelPlaybackCommit? get commit => _commit;
  bool get isPlaying => _session.isPlaying;
  PlayerId? get playerId => _session.playerId;
  Stream<PlaybackState> get playback => _session.playback;

  Widget videoView({BoxFit fit = BoxFit.contain}) {
    final handle = _session.handle;
    if (handle == null) return const SizedBox.expand();
    return MediaPlayerView(handle: handle, fit: fit);
  }

  /// 打开一个房间源并发布提交回执（当前线路/画质表的权威快照）。
  Future<KernelPlaybackCommit> openRoom(LiveRoom room, LiveStreamSource source) async {
    _room = room;
    await _session.open(source.toPlayerSource(room), alternates: source.alternates(room));
    return _publishCommit(room, source);
  }

  /// 换线/换画质后的重开：同会话热切换。
  Future<KernelPlaybackCommit> switchSource(LiveRoom room, LiveStreamSource source) async {
    _room = room;
    await _session.reopen(source.toPlayerSource(room));
    return _publishCommit(room, source);
  }

  KernelPlaybackCommit _publishCommit(LiveRoom room, LiveStreamSource source) {
    final lineIndex = source.lines.isEmpty ? 0 : source.lines.indexOf(source.url).clamp(0, source.lines.length - 1);
    _commit = KernelPlaybackCommit(
      revision: ++_commitRevision,
      sessionId: _sessionIdNow,
      room: room,
      urls: List<String>.unmodifiable(source.lines.isEmpty ? [source.url] : source.lines),
      currentUrl: source.url,
      currentLineIndex: lineIndex,
      headers: Map<String, String>.unmodifiable(source.headers),
    );
    return _commit!;
  }

  int get _sessionIdNow => _session.playerId?.hashCode ?? 0;

  Future<void> play() => _session.play();
  Future<void> pause() => _session.pause();
  Future<void> setVolume(double volume) => _session.setVolume(volume);

  Future<void> dispose() async {
    _room = null;
    _commit = null;
    await _session.dispose();
  }
}

/// 站点解析结果：当前 URL/headers + 备选线路。
class LiveStreamSource {
  const LiveStreamSource({required this.url, this.headers = const {}, this.lines = const []});

  final String url;
  final Map<String, String> headers;
  final List<String> lines;

  PlayerSource toPlayerSource(LiveRoom room) {
    final uri = Uri.parse(url);
    return PlayerSource(
      id: SourceId('live-${room.identityKey}-${DateTime.now().microsecondsSinceEpoch}'),
      uri: uri,
      type: SourceType.live,
      protocol: uri.scheme == 'https' ? SourceProtocol.https : SourceProtocol.http,
      headers: SourceHeaders(headers),
    );
  }

  List<PlayerSource> alternates(LiveRoom room) {
    return [
      for (final line in lines)
        if (line != url) LiveStreamSource(url: line, headers: headers).toPlayerSource(room),
    ];
  }
}
