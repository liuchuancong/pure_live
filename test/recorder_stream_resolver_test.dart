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
      previousQualityId: first.qualityCursorId,
      previousLineIndex: first.lineIndex,
    );

    expect(first.url, 'https://cdn-a.example/live.flv');
    expect(first.quality.selectionId, 400);
    expect(first.lineLabel, '线路1');
    expect(second.url, 'https://cdn-b.example/live.flv');
    expect(second.candidateUrls, <String>['https://cdn-b.example/live.flv', 'https://cdn-a.example/live.flv']);
    expect(site.resolveCalls, <String>['10000', '10000']);
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

  test('fresh signed URLs still rotate from a failed quality to the next candidate', () async {
    final site = _RotatingSignedSite();
    final resolver = StreamResolverService(siteResolver: (_) => site);

    final first = await resolver.resolveStream(roomId: '1', platform: 'douyu', preferredQuality: '原画');
    final second = await resolver.resolveStream(
      roomId: '1',
      platform: 'douyu',
      preferredQuality: '原画',
      previousQualityId: first.qualityCursorId,
      previousLineIndex: first.lineIndex,
    );

    expect(first.quality.selectionId, 'source');
    expect(first.url, contains('/source.flv?token='));
    expect(second.quality.selectionId, 'hd');
    expect(second.url, contains('/hd.flv?token='));
    expect(site.calls, 2);
  });

  test('initial resolve requests only the selected quality instead of aging every candidate URL', () async {
    final site = _FakeSite(
      qualities: <LivePlayQuality>[
        LivePlayQuality(quality: '原画', id: 'source', sort: 1000),
        LivePlayQuality(quality: '高清', id: 'hd', sort: 500),
        LivePlayQuality(quality: '流畅', id: 'sd', sort: 100),
      ],
      urls: const <String>['https://cdn.example/live.flv'],
    );
    final resolver = StreamResolverService(siteResolver: (_) => site);

    final resolved = await resolver.resolveStream(roomId: '1', platform: 'douyu', preferredQuality: '原画');

    expect(resolved.qualityCursorId, 'source');
    expect(site.resolveCalls, <String>['source']);
  });

  test('cursor-capable adapters request only one CDN line per attempt', () async {
    final site = _CursorSite();
    final resolver = StreamResolverService(siteResolver: (_) => site);

    final first = await resolver.resolveStream(roomId: '1', platform: 'douyu', preferredQuality: '原画');
    final second = await resolver.resolveStream(
      roomId: '1',
      platform: 'douyu',
      preferredQuality: '原画',
      previousQualityId: first.qualityCursorId,
      previousLineIndex: first.lineIndex,
    );

    expect(first.url, 'https://cdn-0.example/live.flv');
    expect(second.url, 'https://cdn-1.example/live.flv');
    expect(first.candidateUrls, <String>['https://cdn-0.example/live.flv']);
    expect(site.cursorCalls, <String>['source:0', 'source:1']);
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

  test('recording uses strict room metadata instead of an offline UI fallback', () async {
    final site = _StrictFakeSite(
      live: false,
      strictLive: true,
      qualities: <LivePlayQuality>[LivePlayQuality(quality: '原画', id: 'source')],
      urls: const <String>['https://cdn.example/live.flv'],
    );
    final resolver = StreamResolverService(siteResolver: (_) => site);

    final resolved = await resolver.resolveStream(roomId: '1', platform: 'douyu', preferredQuality: '原画');

    expect(resolved.url, 'https://cdn.example/live.flv');
    expect(site.genericCalls, 0);
    expect(site.strictCalls, 1);
  });

  test('strict room transport failures stay retryable instead of becoming offline', () async {
    final resolver = StreamResolverService(
      siteResolver: (_) => _StrictFakeSite(strictError: StateError('temporary metadata error')),
    );

    await expectLater(
      resolver.resolveStream(roomId: '1', platform: 'huya', preferredQuality: '原画'),
      throwsA(
        isA<StreamException>()
            .having((error) => error.type, 'type', StreamErrorType.networkError)
            .having((error) => error.retryable, 'retryable', isTrue),
      ),
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
  final List<String> resolveCalls = <String>[];

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
    resolveCalls.add(quality.selectionId.toString());
    return LivePlayUrlResolution(urls: urls, appliedQualityData: appliedQuality ?? quality.selectionId);
  }
}

class _StrictFakeSite extends _FakeSite implements LiveSiteRecordRoomResolver {
  _StrictFakeSite({super.live, super.qualities, super.urls, this.strictLive = true, this.strictError});

  final bool strictLive;
  final Object? strictError;
  int strictCalls = 0;
  int genericCalls = 0;

  @override
  Future<LiveRoom> getRoomDetail({required String roomId, required String platform}) async {
    genericCalls++;
    return super.getRoomDetail(roomId: roomId, platform: platform);
  }

  @override
  Future<LiveRoom> getRoomDetailForRecording({required String roomId, required String platform}) async {
    strictCalls++;
    if (strictError != null) throw strictError!;
    return LiveRoom(
      roomId: roomId,
      platform: platform,
      liveStatus: strictLive ? LiveStatus.live : LiveStatus.offline,
      status: strictLive,
      isRecord: false,
    );
  }
}

class _RotatingSignedSite extends LiveSite implements LivePlayUrlResolver, LivePlayUrlCursorResolver {
  int calls = 0;

  @override
  Future<LiveRoom> getRoomDetail({required String roomId, required String platform}) async {
    return LiveRoom(roomId: roomId, platform: platform, liveStatus: LiveStatus.live, status: true);
  }

  @override
  Future<List<LivePlayQuality>> getPlayQualites({required LiveRoom detail}) async {
    return <LivePlayQuality>[
      LivePlayQuality(quality: '原画', id: 'source', sort: 1000),
      LivePlayQuality(quality: '高清', id: 'hd', sort: 500),
    ];
  }

  @override
  Future<LivePlayUrlResolution> resolvePlayUrlsRaw({required LiveRoom detail, required LivePlayQuality quality}) async {
    calls++;
    return LivePlayUrlResolution(
      urls: <String>['https://cdn.example/${quality.selectionId}.flv?token=$calls'],
      appliedQualityData: quality.selectionId,
    );
  }

  @override
  Future<LivePlayUrlResolution> resolvePlayUrlAtRaw({
    required LiveRoom detail,
    required LivePlayQuality quality,
    required int lineIndex,
  }) async {
    if (lineIndex != 0) {
      return LivePlayUrlResolution(urls: const <String>[], appliedQualityData: quality.selectionId);
    }
    return resolvePlayUrlsRaw(detail: detail, quality: quality);
  }
}

class _CursorSite extends LiveSite implements LivePlayUrlCursorResolver {
  final List<String> cursorCalls = <String>[];

  @override
  Future<LiveRoom> getRoomDetail({required String roomId, required String platform}) async {
    return LiveRoom(roomId: roomId, platform: platform, liveStatus: LiveStatus.live, status: true);
  }

  @override
  Future<List<LivePlayQuality>> getPlayQualites({required LiveRoom detail}) async {
    return <LivePlayQuality>[LivePlayQuality(quality: '原画', id: 'source', sort: 1000)];
  }

  @override
  Future<LivePlayUrlResolution> resolvePlayUrlAtRaw({
    required LiveRoom detail,
    required LivePlayQuality quality,
    required int lineIndex,
  }) async {
    cursorCalls.add('${quality.selectionId}:$lineIndex');
    if (lineIndex >= 3) {
      return LivePlayUrlResolution(urls: const <String>[], appliedQualityData: quality.selectionId);
    }
    return LivePlayUrlResolution(
      urls: <String>['https://cdn-$lineIndex.example/live.flv'],
      appliedQualityData: quality.selectionId,
    );
  }
}
