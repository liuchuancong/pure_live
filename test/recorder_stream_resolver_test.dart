import 'package:flutter_test/flutter_test.dart';
import 'package:pure_live/common/models/live_room.dart';
import 'package:pure_live/core/interface/live_site.dart';
import 'package:pure_live/model/live_play_quality.dart';
import 'package:pure_live/recorder/services/stream_resolver_service.dart';

void main() {
  test('quality order uses platform rank instead of incomparable identifiers', () {
    final qualities = <LivePlayQuality>[
      LivePlayQuality(quality: '流畅', id: 'sdk-low', sort: 100),
      LivePlayQuality(quality: '原画', id: 'sdk-high', sort: 1000),
      LivePlayQuality(quality: '超清', id: 'sdk-mid', sort: 500),
    ];

    expect(StreamResolverService.orderQualities(qualities, '原画').first.selectionId, 'sdk-high');
    expect(StreamResolverService.orderQualities(qualities, '流畅').first.selectionId, 'sdk-low');
  });

  test('recorder removes duplicate platform quality identifiers before retrying', () {
    final qualities = <LivePlayQuality>[
      LivePlayQuality(quality: '原画', id: 'source', sort: 1000),
      LivePlayQuality(quality: '重复原画', id: 'source', sort: 900),
      LivePlayQuality(quality: '高清', id: 'hd', sort: 500),
    ];

    expect(StreamResolverService.orderQualities(qualities, '原画').map((quality) => quality.selectionId), [
      'source',
      'hd',
    ]);
  });

  test('resolver reports applied quality and rotates away from a failed CDN', () async {
    final qualities = <LivePlayQuality>[
      LivePlayQuality(quality: '原画', id: 10000, sort: 10000),
      LivePlayQuality(quality: '超清', id: 400, sort: 400),
    ];
    final site = _FakeSite(
      qualities: qualities,
      urls: const <String>['https://cdn-a.example/live.flv', 'https://cdn-b.example/live.flv'],
      appliedQuality: 400,
    );
    final resolver = StreamResolverService(siteResolver: (_) => site);

    final first = await resolver.resolveStream(roomId: '1', platform: 'bilibili', preferredQuality: '原画');
    final second = await resolver.resolveStream(
      roomId: '1',
      platform: 'bilibili',
      preferredQuality: '原画',
      previousUrl: first.url,
    );

    expect(first.url, 'https://cdn-a.example/live.flv');
    expect(first.quality.selectionId, 400);
    expect(first.lineLabel, '线路1');
    expect(second.url, 'https://cdn-b.example/live.flv');
    expect(second.candidateUrls, <String>['https://cdn-b.example/live.flv', 'https://cdn-a.example/live.flv']);
  });

  test('temporary quality failure stays retryable and invalid URLs are rejected', () async {
    final failingResolver = StreamResolverService(
      siteResolver: (_) => _FakeSite(qualityError: StateError('temporary response')),
    );
    await expectLater(
      failingResolver.resolveStream(roomId: '1', platform: 'douyin', preferredQuality: '原画'),
      throwsA(
        isA<StreamException>()
            .having((error) => error.type, 'type', StreamErrorType.networkError)
            .having((error) => error.retryable, 'retryable', isTrue),
      ),
    );

    final invalidResolver = StreamResolverService(
      siteResolver: (_) => _FakeSite(
        qualities: <LivePlayQuality>[LivePlayQuality(quality: '原画')],
        urls: const <String>['javascript:alert(1)', 'not-a-url'],
      ),
    );
    await expectLater(
      invalidResolver.resolveStream(roomId: '1', platform: 'huya', preferredQuality: '原画'),
      throwsA(isA<StreamException>().having((error) => error.type, 'type', StreamErrorType.cdnFailed)),
    );
  });

  test('offline rooms and unknown platforms stop before FFmpeg', () async {
    final offline = StreamResolverService(siteResolver: (_) => _FakeSite(live: false));
    await expectLater(
      offline.resolveStream(roomId: '1', platform: 'cc', preferredQuality: '原画'),
      throwsA(
        isA<StreamException>()
            .having((error) => error.type, 'type', StreamErrorType.notLive)
            .having((error) => error.retryable, 'retryable', isFalse),
      ),
    );
    await expectLater(
      offline.resolveStream(roomId: '1', platform: 'unknown', preferredQuality: '原画'),
      throwsA(isA<StreamException>().having((error) => error.retryable, 'retryable', isFalse)),
    );
  });
}

class _FakeSite extends LiveSite implements LivePlayUrlResolver {
  _FakeSite({
    this.live = true,
    this.qualities = const <LivePlayQuality>[],
    this.urls = const <String>[],
    this.appliedQuality,
    this.qualityError,
  });

  final bool live;
  final List<LivePlayQuality> qualities;
  final List<String> urls;
  final Object? appliedQuality;
  final Object? qualityError;

  @override
  Future<LiveRoom> getRoomDetail({required String roomId, required String platform}) async {
    return LiveRoom(
      roomId: roomId,
      platform: platform,
      liveStatus: live ? LiveStatus.live : LiveStatus.offline,
      isRecord: false,
    );
  }

  @override
  Future<List<LivePlayQuality>> getPlayQualites({required LiveRoom detail}) async {
    if (qualityError != null) throw qualityError!;
    return qualities;
  }

  @override
  Future<LivePlayUrlResolution> resolvePlayUrlsRaw({required LiveRoom detail, required LivePlayQuality quality}) async {
    return LivePlayUrlResolution(urls: urls, appliedQualityData: appliedQuality ?? quality.selectionId);
  }
}
