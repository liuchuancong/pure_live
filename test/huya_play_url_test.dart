import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pure_live/common/models/live_room.dart';
import 'package:pure_live/core/site/huya/huya_site.dart';
import 'package:pure_live/core/tars/get_cdn_token_ex_resp.dart';
import 'package:pure_live/model/live_play_quality.dart';

void main() {
  test('Huya treats only explicit inactive states as authoritative offline', () {
    expect(HuyaSite.isExplicitOfflineState('OFF'), isTrue);
    expect(HuyaSite.isExplicitOfflineState(' offline '), isTrue);
    expect(HuyaSite.isExplicitOfflineState('CLOSED'), isTrue);
    expect(HuyaSite.isExplicitOfflineState('ON'), isFalse);
    expect(HuyaSite.isExplicitOfflineState(null), isFalse);
  });

  test('Huya canonical status distinguishes live, replay and unknown', () {
    expect(HuyaSite.parseHuyaLiveStatus('ON'), LiveStatus.live);
    expect(HuyaSite.parseHuyaLiveStatus('REPLAY'), LiveStatus.replay);
    expect(HuyaSite.parseHuyaLiveStatus('OFF'), LiveStatus.offline);
    expect(HuyaSite.parseHuyaLiveStatus('unexpected'), LiveStatus.unknown);
    expect(HuyaSite.parseHuyaLiveStatus(null), LiveStatus.unknown);
  });

  HuyaLineModel line(
    HuyaLineType type,
    String base, {
    String flvAntiCode = 'wsSecret=flv-token&wsTime=6a87f351',
    String hlsAntiCode = 'wsSecret=hls-token&wsTime=6a87f351',
  }) {
    return HuyaLineModel(
      line: base,
      lineType: type,
      flvAntiCode: flvAntiCode,
      hlsAntiCode: hlsAntiCode,
      streamName: 'stream-name',
      cdnType: 'AL',
      presenterUid: 123,
    );
  }

  test('Huya FLV URL uses the FLV token and extension', () async {
    final url = await HuyaSite().getPlayUrl(line(HuyaLineType.flv, 'http://al.flv.huya.com/src'), 8000);

    expect(url, startsWith('https://al.flv.huya.com/src/stream-name.flv?'));
    expect(url, contains('wsSecret=flv-token'));
    expect(url, isNot(contains('wsSecret=hls-token')));
    expect(url, contains('&codec=264'));
    expect(url, contains('&ratio=8000'));
  });

  test('Huya HLS URL uses the HLS token and extension', () async {
    final url = await HuyaSite().getPlayUrl(line(HuyaLineType.hls, 'http://al.hls.huya.com/src'), 2000);

    expect(url, startsWith('https://al.hls.huya.com/src/stream-name.m3u8?'));
    expect(url, contains('wsSecret=hls-token'));
    expect(url, isNot(contains('wsSecret=flv-token')));
    expect(url, contains('&codec=264'));
    expect(url, contains('&ratio=2000'));
  });

  test('Huya CDN bases use HTTPS without rewriting unrelated hosts', () {
    expect(HuyaSite.secureHuyaCdnBase('http://tx.flv.huya.com/src'), 'https://tx.flv.huya.com/src');
    expect(HuyaSite.secureHuyaCdnBase('http://example.com/src'), 'http://example.com/src');
  });

  test('Huya quality selection replaces a captured ratio instead of keeping stale quality', () async {
    final url = await HuyaSite().getPlayUrl(
      line(
        HuyaLineType.hls,
        'https://al.hls.huya.com/src',
        hlsAntiCode: 'wsSecret=hls-token&wsTime=6a87f351&codec=265&ratio=4000',
      ),
      2000,
    );

    expect(RegExp(r'(^|&)codec=').allMatches(Uri.parse(url).query).length, 1);
    expect(RegExp(r'(^|&)ratio=').allMatches(Uri.parse(url).query).length, 1);
    expect(url, contains('&codec=265'));
    expect(url, contains('&ratio=2000'));
    expect(url, isNot(contains('&ratio=4000')));
  });

  test('Huya source quality removes a captured transcode ratio', () async {
    final url = await HuyaSite().getPlayUrl(
      line(
        HuyaLineType.flv,
        'https://tx.flv.huya.com/src',
        flvAntiCode: 'wsSecret=flv-token&wsTime=6a87f351&ratio=500',
      ),
      0,
    );

    expect(Uri.parse(url).queryParameters.containsKey('ratio'), isFalse);
  });

  test('Huya rebuilds signatures with viewer identity without extending server expiry', () {
    final fm = Uri.encodeComponent(base64Encode(utf8.encode(r'prefix_$0_$1_$2_$3')));
    final site = HuyaSite();
    final firstTime = DateTime.fromMillisecondsSinceEpoch(1_800_000_000_000);
    final secondTime = firstTime.add(const Duration(milliseconds: 1));
    final serverExpiry = (firstTime.millisecondsSinceEpoch ~/ 1000 + 120).toRadixString(16);
    final captured = 'wsSecret=stale&wsTime=$serverExpiry&fm=$fm&ctype=huya_live&fs=bgct&t=100&codec=264';
    const viewerUid = 1_400_123_456_789;

    final first = Uri.splitQueryString(site.buildAntiCode('stream-name', viewerUid, captured, now: firstTime));
    final second = Uri.splitQueryString(site.buildAntiCode('stream-name', viewerUid, captured, now: secondTime));

    expect(first['wsTime'], serverExpiry);
    expect(first['wsSecret'], isNot('stale'));
    expect(first['seqid'], isNot(second['seqid']));
    expect(first['wsSecret'], isNot(second['wsSecret']));
    expect(first['u'], HuyaSite.rotateViewerUid32(viewerUid).toString());
    expect(first['codec'], '264');
    expect(first.containsKey('fm'), isFalse);
  });

  test('Huya signs the complete server fm template instead of assuming underscore layout', () {
    final template = r'prefix-v2|$1|viewer=$0|hash=$2|lease=$3|tail';
    final fm = Uri.encodeComponent(base64Encode(utf8.encode(template)));
    final now = DateTime.fromMillisecondsSinceEpoch(1_800_000_000_000);
    final wsTime = (now.millisecondsSinceEpoch ~/ 1000 + 120).toRadixString(16);
    const viewerUid = 1_400_123_456_789;
    const stream = 'stream-name';

    final signed = Uri.splitQueryString(
      HuyaSite().buildAntiCode(stream, viewerUid, 'wsTime=$wsTime&fm=$fm&ctype=huya_live&t=100&codec=264', now: now),
    );
    final seqId = signed['seqid']!;
    final secretHash = md5.convert(utf8.encode('$seqId|huya_live|100')).toString();
    final expectedInput = template
        .replaceFirst(r'$0', HuyaSite.rotateViewerUid32(viewerUid).toString())
        .replaceFirst(r'$1', stream)
        .replaceFirst(r'$2', secretHash)
        .replaceFirst(r'$3', wsTime);

    expect(signed['wsSecret'], md5.convert(utf8.encode(expectedInput)).toString());
    expect(signed.containsKey('fm'), isFalse);
  });

  test('Huya rejects a malformed server fm template before opening the CDN', () {
    final fm = Uri.encodeComponent(base64Encode(utf8.encode(r'prefix_$0_$1')));
    final now = DateTime.fromMillisecondsSinceEpoch(1_800_000_000_000);
    final wsTime = (now.millisecondsSinceEpoch ~/ 1000 + 120).toRadixString(16);

    expect(
      () => HuyaSite().buildAntiCode('stream-name', 123, 'wsTime=$wsTime&fm=$fm&t=100', now: now),
      throwsFormatException,
    );
  });

  test('Huya isolates a malformed CDN token and keeps healthy protocol alternatives', () async {
    final now = DateTime.now();
    final wsTime = (now.millisecondsSinceEpoch ~/ 1000 + 120).toRadixString(16);
    final malformedFm = Uri.encodeComponent(base64Encode(utf8.encode(r'broken_$0_$1')));
    final healthyFm = Uri.encodeComponent(base64Encode(utf8.encode(r'healthy|$0|$1|$2|$3')));
    final lines = <HuyaLineModel>[
      line(
        HuyaLineType.flv,
        'https://bad.flv.huya.com/src',
        flvAntiCode: 'wsTime=$wsTime&fm=$malformedFm&ctype=huya_webh5&t=100',
      ),
      line(
        HuyaLineType.hls,
        'https://good.hls.huya.com/src',
        hlsAntiCode: 'wsTime=$wsTime&fm=$healthyFm&ctype=huya_webh5&t=100',
      ),
    ];
    final quality = LivePlayQuality(quality: '原画', id: 0, data: <String, Object>{'urls': lines, 'bitRate': 0});

    final urls = await _FakeHuyaSessionSite().getPlayUrls(
      detail: LiveRoom(roomId: 'fixture'),
      quality: quality,
    );

    expect(urls, hasLength(1));
    expect(Uri.parse(urls.single).host, 'good.hls.huya.com');
    expect(Uri.parse(urls.single).path, endsWith('.m3u8'));
  });

  test('Huya preserves the upper UID lane when rotating a real anonymous viewer identity', () {
    const viewerUid = 1_471_259_343_403;
    final rotated = HuyaSite.rotateViewerUid32(viewerUid);

    expect(rotated, 1_472_703_638_413);
    expect(rotated, greaterThan(0xffffffff));
    expect(HuyaSite.unrotateViewerUid32(rotated), viewerUid);
  });

  test('Huya uses the current web ctype when a token omits ctype', () {
    final fm = Uri.encodeComponent(base64Encode(utf8.encode(r'prefix_$0_$1_$2_$3')));
    final now = DateTime.fromMillisecondsSinceEpoch(1_800_000_000_000);
    final serverExpiry = (now.millisecondsSinceEpoch ~/ 1000 + 120).toRadixString(16);
    final signed = Uri.splitQueryString(
      HuyaSite().buildAntiCode('stream-name', 1_400_123_456_789, 'wsTime=$serverExpiry&fm=$fm&t=100', now: now),
    );

    expect(signed['ctype'], 'huya_webh5');
  });

  test('Huya rejects an expired server lease instead of extending it locally', () {
    final fm = Uri.encodeComponent(base64Encode(utf8.encode(r'prefix_$0_$1_$2_$3')));
    final now = DateTime.fromMillisecondsSinceEpoch(1_800_000_000_000);
    final expired = (now.millisecondsSinceEpoch ~/ 1000 - 301).toRadixString(16);

    expect(
      () => HuyaSite().buildAntiCode(
        'stream-name',
        123,
        'wsSecret=stale&wsTime=$expired&fm=$fm&ctype=huya_live&t=100',
        now: now,
      ),
      throwsStateError,
    );
  });

  test('Huya viewer identity reads yyuid only from an exact cookie field', () {
    expect(HuyaSite.parseViewerUidFromCookie('foo=1; yyuid=1400123456789; bar=2'), 1_400_123_456_789);
    expect(HuyaSite.parseViewerUidFromCookie('foo=yyuid=12; bar=2'), isNull);
    expect(HuyaSite.parseViewerUidFromCookie('yyuid=0'), isNull);
  });

  test('Huya retries anonymous login after a synthetic fallback instead of caching 403 state', () async {
    final site = _RetryingHuyaIdentitySite();

    final fallback = await site.resolveViewerIdentity(cookie: '');
    final official = await site.resolveViewerIdentity(cookie: '');
    final cached = await site.resolveViewerIdentity(cookie: '');

    expect(fallback.uid, isNot(official.uid));
    expect(official.uid, _RetryingHuyaIdentitySite.officialUid);
    expect(cached.uid, _RetryingHuyaIdentitySite.officialUid);
    expect(site.requests, 2);
  });

  test('Huya CDN refresh uses the official web playback identity', () {
    const viewer = HuyaViewerIdentity(uid: 1_400_123_456_789, guid: 'fixture-guid', isAnonymous: true);

    final tid = HuyaSite.buildPlaybackTokenUserId(viewer, cookie: 'yyuid=1400123456789; foo=bar');

    expect(tid.lUid, viewer.uid);
    expect(tid.sGuid, viewer.guid);
    expect(tid.sToken, isEmpty);
    expect(tid.sHuYaUA, HuyaSite.webPlaybackTarsUserAgent);
    expect(tid.sHuYaUA, 'webh5&0.1.0&websocket');
    expect(tid.sCookie, 'yyuid=1400123456789; foo=bar');
    expect(tid.iTokenType, 0);
    expect(tid.sHuYaUA, isNot(contains('pc_exe')));
  });

  test('Huya CDN token request matches the current official web player contract', () {
    const viewer = HuyaViewerIdentity(uid: 1_400_123_456_789, guid: 'fixture-guid', isAnonymous: true);
    final request = HuyaSite.buildPlaybackTokenRequest(
      line(HuyaLineType.flv, 'http://tx.flv.huya.com/src'),
      viewer,
      cookie: 'yyuid=1400123456789',
    );

    expect(request.sFlvUrl, 'https://tx.flv.huya.com/src');
    expect(request.sStreamName, 'stream-name');
    expect(request.iLoopTime, 0);
    expect(request.iAppId, 66);
    expect(request.tId.lUid, viewer.uid);
    expect(request.tId.sHuYaUA, 'webh5&0.1.0&websocket');
    expect(request.tId.sCookie, 'yyuid=1400123456789');
  });

  test('Huya keeps a valid room FLV template instead of forcing a WUP refresh', () async {
    final now = DateTime.now();
    final wsTime = (now.millisecondsSinceEpoch ~/ 1000 + 120).toRadixString(16);
    final fm = Uri.encodeComponent(base64Encode(utf8.encode(r'prefix_$0_$1_$2_$3')));
    final site = _FakeHuyaSessionSite();

    final url = await site.getPlayUrl(
      line(
        HuyaLineType.flv,
        'https://tx.flv.huya.com/src',
        flvAntiCode: 'wsTime=$wsTime&fm=$fm&ctype=huya_webh5&t=100',
      ),
      0,
    );

    expect(site.tokenRefreshes, 0);
    expect(Uri.parse(url).queryParameters['ctype'], 'huya_webh5');
    expect(Uri.parse(url).queryParameters['u'], HuyaSite.rotateViewerUid32(site.viewer.uid).toString());
  });

  test('Huya WUP lease refreshes before the official wsTime allowance expires', () {
    final now = DateTime.utc(2026, 8, 29, 12);
    final wsTime = now.add(const Duration(minutes: 1)).millisecondsSinceEpoch ~/ 1000;
    final response = GetCdnTokenExResp()
      ..sFlvToken = 'wsSecret=fresh&wsTime=${wsTime.toRadixString(16)}'
      ..iExpireTime = 0;

    final lease = HuyaCdnTokenLease.fromResponse(response, now: now);

    expect(lease.invalidAt, now.add(const Duration(minutes: 6)));
    expect(lease.refreshAt, now.add(const Duration(minutes: 5, seconds: 30)));
    expect(lease.needsRefresh(lease.refreshAt), isTrue);
  });

  test('Huya WUP lease honors an earlier server expiry bound', () {
    final now = DateTime.utc(2026, 8, 29, 12);
    final wsTime = now.add(const Duration(hours: 1)).millisecondsSinceEpoch ~/ 1000;
    final response = GetCdnTokenExResp()
      ..sFlvToken = 'wsSecret=fresh&wsTime=${wsTime.toRadixString(16)}'
      ..iExpireTime = 90;

    final lease = HuyaCdnTokenLease.fromResponse(response, now: now);

    expect(lease.invalidAt, now.add(const Duration(seconds: 90)));
    expect(lease.refreshAt, now.add(const Duration(seconds: 60)));
    expect(lease.serverExpireValue, 90);
  });

  test('Huya playback metadata preserves the WUP server lease for the final URL', () async {
    final now = DateTime.now().toUtc();
    final fm = Uri.encodeComponent(base64Encode(utf8.encode(r'prefix_$0_$1_$2_$3')));
    final expiredWsTime = now.subtract(const Duration(minutes: 6)).millisecondsSinceEpoch ~/ 1000;
    final freshWsTime = now.add(const Duration(hours: 1)).millisecondsSinceEpoch ~/ 1000;
    final lease = HuyaCdnTokenLease(
      antiCode: 'wsSecret=fresh&wsTime=${freshWsTime.toRadixString(16)}',
      invalidAt: now.add(const Duration(seconds: 50)),
      refreshAt: now.add(const Duration(seconds: 20)),
      serverExpireValue: 50,
    );
    final site = _FakeHuyaLeaseSite(lease);

    final url = await site.getPlayUrl(
      line(
        HuyaLineType.flv,
        'https://tx.flv.huya.com/src',
        flvAntiCode: 'wsTime=${expiredWsTime.toRadixString(16)}&fm=$fm&ctype=huya_webh5&t=100',
      ),
      0,
    );

    expect(site.tokenRefreshes, 1);
    expect(site.getPlayUrlInvalidAt(url, now: now), lease.invalidAt);
    expect(site.getPlayUrlRefreshAt(url, now: now), lease.refreshAt);
    final afterServerExpiry = now.add(const Duration(seconds: 60));
    expect(site.getPlayUrlInvalidAt(url, now: afterServerExpiry), lease.invalidAt);
    expect(site.getPlayUrlRefreshAt(url, now: afterServerExpiry), afterServerExpiry);
  });

  test('Huya playback URL exposes the proactive refresh deadline', () {
    final now = DateTime.utc(2026, 8, 29, 12);
    final wsTime = now.add(const Duration(minutes: 1)).millisecondsSinceEpoch ~/ 1000;
    final refreshAt = HuyaSite().getPlayUrlRefreshAt(
      'https://cdn.example/live.flv?wsTime=${wsTime.toRadixString(16)}&wsSecret=value',
      now: now,
    );

    expect(refreshAt, now.add(const Duration(minutes: 5, seconds: 30)));
    expect(
      HuyaSite().getPlayUrlInvalidAt('https://cdn.example/live.flv?wsTime=${wsTime.toRadixString(16)}', now: now),
      now.add(const Duration(minutes: 6)),
    );
    expect(HuyaSite().getPlayUrlRefreshAt('https://cdn.example/live.flv', now: now), isNull);
  });

  test('Huya derives a stable transport lease from the signed sequence issue time', () {
    const url =
        'https://al-game.flv.huya.com/live.flv?wsTime=6a94f03e&t=102&seqid=3259308803203&u=1470177679757&wsSecret=value';
    final issuedAt = DateTime.fromMillisecondsSinceEpoch(1_788_059_326_826, isUtc: true);
    final firstMetadataRead = issuedAt.add(const Duration(seconds: 10));
    final laterMetadataRead = issuedAt.add(const Duration(seconds: 90));

    expect(HuyaSite.getSignedSequenceIssuedAt(url), issuedAt);
    expect(HuyaSite().getPlayUrlRefreshAt(url, now: firstMetadataRead), issuedAt.add(const Duration(seconds: 100)));
    expect(HuyaSite().getPlayUrlRefreshAt(url, now: laterMetadataRead), issuedAt.add(const Duration(seconds: 100)));
    expect(HuyaSite().getPlayUrlInvalidAt(url), issuedAt.add(const Duration(seconds: 125)));
  });

  test('Huya remembers a short transport lease for legacy URLs without seqid', () async {
    final site = HuyaSite();
    final before = DateTime.now().toUtc();
    final url = await site.getPlayUrl(
      line(
        HuyaLineType.flv,
        'https://al-game.flv.huya.com/src',
        flvAntiCode: 'wsSecret=legacy&wsTime=7fffffff&ctype=tars_mp&t=102',
      ),
      0,
    );
    final after = DateTime.now().toUtc();

    expect(HuyaSite.getSignedSequenceIssuedAt(url), isNull);
    final refreshAt = site.getPlayUrlRefreshAt(url, now: before);
    final invalidAt = site.getPlayUrlInvalidAt(url, now: before);
    expect(refreshAt, isNotNull);
    expect(invalidAt, isNotNull);
    expect(refreshAt!.isBefore(before.add(const Duration(seconds: 99))), isFalse);
    expect(refreshAt.isAfter(after.add(const Duration(seconds: 101))), isFalse);
    expect(invalidAt!.isBefore(before.add(const Duration(seconds: 124))), isFalse);
    expect(invalidAt.isAfter(after.add(const Duration(seconds: 126))), isFalse);
  });

  test('Huya line diagnostics redact signed URLs and AntiCode material', () {
    final model = line(
      HuyaLineType.flv,
      'https://al-game.flv.huya.com/src',
      flvAntiCode: 'wsSecret=private-token&wsTime=7fffffff',
    );

    final diagnostic = model.toString();
    expect(diagnostic, contains('al-game.flv.huya.com'));
    expect(diagnostic, contains('cdnType: AL'));
    expect(diagnostic, isNot(contains('private-token')));
    expect(diagnostic, isNot(contains('wsSecret')));
  });

  test('Huya decodes the WAP uid form of the official signed sequence', () {
    const viewerUid = 1_400_123_456_789;
    const issuedMillis = 1_800_000_000_000;
    const seqId = viewerUid + issuedMillis;
    final wsTime =
        DateTime.fromMillisecondsSinceEpoch(
          issuedMillis,
          isUtc: true,
        ).add(const Duration(hours: 1)).millisecondsSinceEpoch ~/
        1000;
    final url =
        'https://al-hls.huya.com/live.m3u8?wsTime=${wsTime.toRadixString(16)}&t=103&seqid=$seqId&uid=$viewerUid';

    expect(HuyaSite.getSignedSequenceIssuedAt(url), DateTime.fromMillisecondsSinceEpoch(issuedMillis, isUtc: true));
  });

  test('Huya exposes only server advertised bitrates and has stable selection ids', () {
    final data = HuyaUrlDataModel(
      url: '',
      uid: '',
      lines: [line(HuyaLineType.flv, 'https://tx.flv.huya.com/src')],
      bitRates: [
        HuyaBitRateModel(name: '蓝光4M', bitRate: 0),
        HuyaBitRateModel(name: '超清', bitRate: 2000),
        HuyaBitRateModel(name: '重复超清', bitRate: 2000),
        HuyaBitRateModel(name: '流畅', bitRate: 500),
      ],
      isXingxiu: false,
    );

    final qualities = HuyaSite.parsePlayQualities(data);

    expect(qualities.map((quality) => quality.quality), ['蓝光4M', '超清', '流畅']);
    expect(qualities.map((quality) => quality.selectionId), [0, 2000, 500]);
  });

  test('Huya does not invent an unsupported transcode when no rate list exists', () {
    final qualities = HuyaSite.parsePlayQualities(
      HuyaUrlDataModel(url: '', uid: '', lines: const [], bitRates: const [], isXingxiu: false),
    );

    expect(qualities, hasLength(1));
    expect(qualities.single.selectionId, 0);
  });

  test('Huya recording cursor signs only the requested line', () async {
    final site = _FakeHuyaCursorSite();
    final lines = <HuyaLineModel>[
      line(HuyaLineType.flv, 'https://first.example/live'),
      line(HuyaLineType.hls, 'https://second.example/live'),
    ];
    final quality = LivePlayQuality(quality: '原画', id: 0, data: <String, Object>{'urls': lines, 'bitRate': 0});

    final resolved = await site.resolvePlayUrlAtRaw(
      detail: LiveRoom(roomId: '123'),
      quality: quality,
      lineIndex: 1,
    );
    final beyond = await site.resolvePlayUrlAtRaw(
      detail: LiveRoom(roomId: '123'),
      quality: quality,
      lineIndex: 2,
    );

    expect(resolved.urls, <String>['https://selected.example/stream.flv']);
    expect(site.lines, <HuyaLineModel>[lines[1]]);
    expect(beyond.urls, isEmpty);
  });
}

class _FakeHuyaCursorSite extends HuyaSite {
  final List<HuyaLineModel> lines = <HuyaLineModel>[];

  @override
  Future<String> getPlayUrl(HuyaLineModel line, int bitRate) async {
    lines.add(line);
    return 'https://selected.example/stream.flv';
  }
}

class _RetryingHuyaIdentitySite extends HuyaSite {
  static const int officialUid = 1_600_000_000_001;
  int requests = 0;

  @override
  Future<String> getAnonymousUid() async {
    requests++;
    if (requests == 1) throw StateError('temporary anonymous login outage');
    return officialUid.toString();
  }
}

class _FakeHuyaSessionSite extends HuyaSite {
  final HuyaViewerIdentity viewer = const HuyaViewerIdentity(
    uid: 1_400_123_456_789,
    guid: 'fixture-guid',
    isAnonymous: true,
  );
  int tokenRefreshes = 0;

  @override
  Future<HuyaViewerIdentity> resolveViewerIdentity({String? cookie}) async => viewer;

  @override
  Future<HuyaCdnTokenLease> getCndTokenInfoEx(HuyaLineModel line, HuyaViewerIdentity viewer) async {
    tokenRefreshes++;
    throw StateError('unexpected WUP refresh');
  }
}

class _FakeHuyaLeaseSite extends HuyaSite {
  _FakeHuyaLeaseSite(this.lease);

  final HuyaCdnTokenLease lease;
  int tokenRefreshes = 0;

  @override
  Future<HuyaViewerIdentity> resolveViewerIdentity({String? cookie}) async {
    return const HuyaViewerIdentity(uid: 1_400_123_456_789, guid: 'fixture-guid', isAnonymous: true);
  }

  @override
  Future<HuyaCdnTokenLease> getCndTokenInfoEx(HuyaLineModel line, HuyaViewerIdentity viewer) async {
    tokenRefreshes++;
    return lease;
  }
}
