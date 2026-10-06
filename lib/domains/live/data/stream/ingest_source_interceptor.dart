import 'dart:developer' as developer;

import 'package:media_core/media_core.dart';
import 'package:pure_live/core/player/core/playback_input_lease.dart';
import 'package:pure_live/domains/live/domain/playback_source_interceptor.dart';

import 'playback_source_transport.dart';

class IngestSourceInterceptor implements PlaybackSourceInterceptor {
  IngestSourceInterceptor({PlaybackSourceTransport? transport}) : _transport = transport ?? PlaybackSourceTransport();

  final PlaybackSourceTransport _transport;

  @override
  Future<List<PlayerSource>> intercept(PlaybackSourceInterception request) async {
    final List<PlayerSource> sources = request.sources;
    if (sources.isEmpty) return sources;
    final PlayerSource primary = sources.first;
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
      developer.log('relay unavailable, playing the upstream directly: $error', name: 'PlaybackIngest');
      return sources;
    }
    if (lease == null || !lease.isUsable) return sources;
    // Host only: a signed live URL carries its token in the query.
    developer.log('relay ${primary.uri.host} -> ${lease.uri}', name: 'PlaybackIngest');
    return <PlayerSource>[primary.copyWith(uri: lease.uri, headers: SourceHeaders.empty), ...sources.skip(1)];
  }

  @override
  Future<void> release() => _transport.release();

  @override
  Future<void> close() => _transport.close();
}
