import 'package:flutter/foundation.dart' show immutable;
import 'package:media_core/media_core.dart';
import 'package:pure_live/core/stream/hls_source_query_policy.dart';
import 'package:pure_live/shared/platforms/live_site.dart';

/// 一次取流接线拿到的全部输入：内核即将打开的候选源，加上平台为这些源声明的事实。
@immutable
class PlaybackSourceInterception {
  const PlaybackSourceInterception({
    required this.sources,
    this.streamFacts = const <String, LiveStreamFacts>{},
    this.sourceQueryPolicies = const <String, HlsSourceQueryPolicy>{},
  });

  /// 候选源，第一条是选中的线路（内核按顺序打开，第一条失败才落到后面）。
  final List<PlayerSource> sources;

  /// 平台按 URL 声明的容器/编码事实，来自 `LivePlayUrlResolution.streamFacts`。
  final Map<String, LiveStreamFacts> streamFacts;

  /// 需要把签名 query 透传到每个子请求的源（HLS 令牌）。
  final Map<String, HlsSourceQueryPolicy> sourceQueryPolicies;
}

/// 把平台给出的直连源换成播放器读得懂的本地源。
///
/// domain 只依赖这个形状：中继怎么起（FFmpeg 转封装、manifest 重写）、租约怎么
/// 释放都在 data 层，装配点在 app 启动。没有实现时就按直连播放。
abstract interface class PlaybackSourceInterceptor {
  /// 返回改写后的源列表；接不了（不需要中继、中继起不来）就原样返回入参，
  /// 播放不会因为接线而变差。
  Future<List<PlayerSource>> intercept(PlaybackSourceInterception request);

  /// 释放已经交给播放器的中继，但保留继续接线的能力（停止播放、离开房间）。
  Future<void> release();

  /// 永久关闭（播放器销毁）。
  Future<void> close();
}
