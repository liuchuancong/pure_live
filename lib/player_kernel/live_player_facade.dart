import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:media_core/media_core.dart';
import 'package:pure_live/common/models/live_room.dart';
import 'package:pure_live/player_kernel/live_playback_session.dart';

/// 直播播放的宿主门面：一房一会话，页面只跟它说话。
///
/// 站点解析（画质/线路/请求头）由调用方完成并注入 [LiveStreamSource]；
/// 播放内核、恢复、呈现全部是 media_core 的。功能按需补：
/// 音量记忆、弹幕挂载、PiP/悬浮交给各能力包。
class LivePlayerFacade {
  LivePlayerFacade({LivePlaybackSession? session}) : _session = session ?? LivePlaybackSession();

  final LivePlaybackSession _session;
  LiveRoom? _room;

  LiveRoom? get room => _room;
  bool get isPlaying => _session.isPlaying;
  PlayerId? get playerId => _session.playerId;
  Stream<PlaybackState> get playback => _session.playback;

  Widget videoView({BoxFit fit = BoxFit.contain}) {
    final handle = _session.handle;
    if (handle == null) return const SizedBox.expand();
    return MediaPlayerView(handle: handle, fit: fit);
  }

  Future<void> openRoom(LiveRoom room, LiveStreamSource source) async {
    _room = room;
    await _session.open(source.toPlayerSource(room), alternates: source.alternates(room));
  }

  Future<void> switchLine(LiveRoom room, LiveStreamSource source) => openRoom(room, source);

  Future<void> play() => _session.play();
  Future<void> pause() => _session.pause();
  Future<void> setVolume(double volume) => _session.setVolume(volume);

  Future<void> dispose() async {
    _room = null;
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
