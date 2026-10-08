import 'package:flutter_test/flutter_test.dart';
import 'package:media_core/media_core.dart';
import 'package:pure_live/core/player/core/playback_input_lease.dart';
import 'package:pure_live/core/stream/hls_source_query_policy.dart';
import 'package:pure_live/domains/live/data/stream/ingest_source_interceptor.dart';
import 'package:pure_live/domains/live/data/stream/playback_source_transport.dart';
import 'package:pure_live/domains/live/domain/playback_source_interceptor.dart';
import 'package:pure_live/shared/platforms/live_site.dart';

/// 只记录接线请求的中继替身：真正的中继要起 FFmpeg 进程和回环端口，
/// 那是 `tool/probes` 的事，这里只验证换源与兜底逻辑。
class _ScriptedTransport extends PlaybackSourceTransport {
  _ScriptedTransport({this.lease, this.error});

  final PlaybackInputLease? lease;
  final Object? error;

  int prepareCalls = 0;
  int releaseCalls = 0;
  int closeCalls = 0;
  String? requestedUrl;
  Map<String, String>? requestedHeaders;
  LiveStreamFacts? requestedFacts;
  HlsSourceQueryPolicy? requestedPolicy;

  @override
  Future<PlaybackInputLease?> prepare({
    required String url,
    required Map<String, String> headers,
    LiveStreamFacts? facts,
    HlsSourceQueryPolicy? policy,
  }) async {
    prepareCalls++;
    requestedUrl = url;
    requestedHeaders = headers;
    requestedFacts = facts;
    requestedPolicy = policy;
    final failure = error;
    if (failure != null) throw failure;
    return lease;
  }

  @override
  Future<void> release() async => releaseCalls++;

  @override
  Future<void> close() async => closeCalls++;
}

PlayerSource _source(String url, {Map<String, String> headers = const {}}) => PlayerSource(
  id: SourceId('live-$url'),
  uri: Uri.parse(url),
  type: SourceType.live,
  headers: headers.isEmpty ? null : SourceHeaders(headers),
);

void main() {
  const loopback = 'http://127.0.0.1:4321/ingest/index.m3u8';
  const primary = 'https://cdn.example.com/live/index.m3u8?token=abc';
  const backup = 'https://cdn2.example.com/live/index.m3u8';

  group('取流接线', () {
    test('中继起来时只换第一条线路，并丢掉只属于上游的鉴权头', () async {
      final transport = _ScriptedTransport(lease: PlaybackInputLease(Uri.parse(loopback), () async {}));
      final interceptor = IngestSourceInterceptor(transport: transport);

      final intercepted = await interceptor.intercept(
        PlaybackSourceInterception(
          sources: [
            _source(primary, headers: {'Cookie': 'a=b'}),
            _source(backup),
          ],
          streamFacts: const {
            primary: (format: LiveStreamFormat.hls, codec: null, unresolvedChildren: true),
            backup: (format: LiveStreamFormat.hls, codec: null, unresolvedChildren: false),
          },
          sourceQueryPolicies: {primary: HlsSourceQueryPolicy.fromSource(Uri.parse(primary))},
        ),
      );

      expect(intercepted, hasLength(2));
      expect(intercepted[0].uri.toString(), loopback);
      expect(intercepted[0].headers?.values ?? const {}, isEmpty);
      // 兜底线路保持直连：给每条都起中继等于 N 个 FFmpeg 进程和 N 个端口。
      expect(intercepted[1].uri.toString(), backup);
      expect(transport.prepareCalls, 1);
      expect(transport.requestedUrl, primary);
      expect(transport.requestedHeaders, {'Cookie': 'a=b'});
      expect(transport.requestedFacts?.unresolvedChildren, isTrue);
      expect(transport.requestedPolicy, isNotNull);
    });

    test('不需要中继时原样直连', () async {
      final transport = _ScriptedTransport();
      final interceptor = IngestSourceInterceptor(transport: transport);

      final sources = [_source(primary), _source(backup)];
      expect(await interceptor.intercept(PlaybackSourceInterception(sources: sources)), sources);
      expect(transport.prepareCalls, 1);
    });

    test('中继起不来时退回直连，不让播放失败', () async {
      final interceptor = IngestSourceInterceptor(
        transport: _ScriptedTransport(error: StateError('ffmpeg runtime missing')),
      );

      final sources = [_source(primary)];
      expect(await interceptor.intercept(PlaybackSourceInterception(sources: sources)), sources);
    });

    test('自有输入配方不接线', () async {
      final transport = _ScriptedTransport(lease: PlaybackInputLease(Uri.parse(loopback), () async {}));
      final interceptor = IngestSourceInterceptor(transport: transport);
      final owned = PlayerSource(
        id: SourceId('owned-room'),
        uri: Uri(scheme: 'owned', path: 'room'),
        type: SourceType.live,
        protocol: SourceProtocol.custom,
      );

      expect(await interceptor.intercept(PlaybackSourceInterception(sources: [owned])), [owned]);
      expect(transport.prepareCalls, 0);
    });

    test('停止与销毁分别释放和关闭中继', () async {
      final transport = _ScriptedTransport();
      final interceptor = IngestSourceInterceptor(transport: transport);

      await interceptor.release();
      await interceptor.close();
      expect(transport.releaseCalls, 1);
      expect(transport.closeCalls, 1);
    });
  });
}
