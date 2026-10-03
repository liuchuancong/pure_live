import 'dart:developer' as developer;

import 'package:media_core/media_core.dart';
import 'package:pure_live/core/player/core/playback_input_lease.dart';
import 'package:pure_live/domains/live/domain/playback_source_interceptor.dart';

import 'playback_source_transport.dart';

/// 取流接线的实现：把选中的那条线路交给 [PlaybackSourceTransport] 决定要不要本地
/// 中继（FFmpeg 转封装 / manifest 重写），能中继就用回环 URI 换掉原 URI，
/// 不能就原样直连——最坏情况等于没有接线时的行为。
class IngestSourceInterceptor implements PlaybackSourceInterceptor {
  IngestSourceInterceptor({PlaybackSourceTransport? transport}) : _transport = transport ?? PlaybackSourceTransport();

  final PlaybackSourceTransport _transport;

  @override
  Future<List<PlayerSource>> intercept(PlaybackSourceInterception request) async {
    final List<PlayerSource> sources = request.sources;
    if (sources.isEmpty) return sources;
    // 只接第一条：内核按顺序打开，第一条就是选中的线路，后面几条只是失败兜底。
    // 每条都起中继等于 N 个 FFmpeg 进程和 N 个端口。
    final PlayerSource primary = sources.first;
    // 自有输入（`owned:` 配方）和本地文件本来就是本地产物，没有可中继的上游。
    if (!const <String>{'http', 'https'}.contains(primary.uri.scheme.toLowerCase())) return sources;
    final String url = primary.uri.toString();
    final PlaybackInputLease? lease;
    try {
      lease = await _transport.prepare(
        url: url,
        headers: primary.headers?.values ?? const <String, String>{},
        facts: request.streamFacts[url],
        policy: request.sourceQueryPolicies[url],
      );
    } catch (error) {
      // 接线是中继，不是播放的前提：起不来就直连，等于没有接线时的行为。
      developer.log('relay unavailable, playing the upstream directly: $error', name: 'PlaybackIngest');
      return sources;
    }
    if (lease == null || !lease.isUsable) return sources;
    // Host only: a signed live URL carries its token in the query.
    developer.log('relay ${primary.uri.host} -> ${lease.uri}', name: 'PlaybackIngest');
    // 回环服务在本机，鉴权头只属于上游：换源时一并丢掉。
    return <PlayerSource>[primary.copyWith(uri: lease.uri, headers: SourceHeaders.empty), ...sources.skip(1)];
  }

  @override
  Future<void> release() => _transport.release();

  @override
  Future<void> close() => _transport.close();
}
