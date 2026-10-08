// Module: test/ticket_mapping_test.dart
// Purpose: Verify that a platform MediaTicket arrives in the kernel with its essences, headers and policy intact.
// Author: liuchuancong
// Created: 2026-10-09
import 'package:flutter_test/flutter_test.dart';
import 'package:media_core/media_core.dart' as core;
import 'package:pure_live_media/pure_live_media.dart';
import 'package:pure_live_platform/pure_live_platform.dart' as platform;

platform.MediaTicket _ticket({
  platform.MediaKind kind = platform.MediaKind.vod,
  List<platform.MediaTrack> tracks = const <platform.MediaTrack>[],
  Map<String, String> headers = const <String, String>{},
  bool isLive = false,
  platform.MediaTicketPolicy policy = const platform.MediaTicketPolicy(),
}) {
  return platform.MediaTicket(
    id: 'ticket-1',
    uri: Uri.parse('https://example.test/master.m3u8'),
    kind: kind,
    protocol: platform.MediaProtocol.hls,
    createdAt: DateTime.utc(2026, 10, 9),
    headers: headers,
    tracks: tracks,
    policy: policy,
    metadata: platform.MediaPlaybackMetadata(isLive: isLive),
  );
}

platform.MediaTrack _track(
  String url, {
  platform.MediaTrackType kind = platform.MediaTrackType.video,
  Map<String, String> headers = const <String, String>{},
  String? language,
}) {
  return platform.MediaTrack(uri: Uri.parse(url), kind: kind, headers: headers, language: language);
}

void main() {
  group('track mapping', () {
    test('test_toCoreTrack_keepsEveryField', () {
      final track = platform.MediaTrack(
        uri: Uri.parse('https://example.test/video.mpd'),
        kind: platform.MediaTrackType.video,
        headers: const <String, String>{'Referer': 'https://example.test/'},
        mimeType: 'video/mp4',
        codec: 'avc1.640028',
        bitrate: 4800000,
        language: 'zh',
        startOffset: const Duration(seconds: 3),
        metadata: const <String, Object?>{'role': 'main'},
      );

      final mapped = toCoreTrack(track);

      expect(mapped.uri, track.uri);
      expect(mapped.kind, core.MediaTrackType.video);
      expect(mapped.headers?.values, track.headers);
      expect(mapped.mimeType, 'video/mp4');
      expect(mapped.codec, 'avc1.640028');
      expect(mapped.bitrate, 4800000);
      expect(mapped.language, 'zh');
      expect(mapped.startOffset, const Duration(seconds: 3));
      expect(mapped.metadata['role'], 'main');
    });

    test('test_toCoreTrack_absentHeadersStayAbsent', () {
      // An empty map must not become "send no headers": absent means inherit.
      final mapped = toCoreTrack(_track('https://example.test/a.m3u8'));
      expect(mapped.headers, isNull);
    });

    test('test_trackRoundTrip_essenceAndHeadersSurvive', () {
      final original = _track(
        'https://example.test/audio.mpd',
        kind: platform.MediaTrackType.audio,
        headers: const <String, String>{'Cookie': 'sid=1'},
        language: 'en',
      );

      final back = toPlatformTrack(toCoreTrack(original));

      expect(back.kind, platform.MediaTrackType.audio);
      expect(back.headers, original.headers);
      expect(back.language, 'en');
      expect(back.uri, original.uri);
    });

    test('test_toPlatformTrack_nullHeadersBecomeAnEmptyMap', () {
      final track = core.MediaTrack(uri: Uri.parse('https://example.test/v.mp4'), kind: core.MediaTrackType.video);

      expect(toPlatformTrack(track).headers, isEmpty);
    });
  });

  group('ticket to source', () {
    test('test_toCoreSource_ticketWithoutTracks_becomesProgressiveVideo', () {
      final source = toCoreSource(_ticket(headers: const <String, String>{'Referer': 'https://example.test/'}));

      expect(source, isA<core.ProgressiveMediaSource>());
      final progressive = source as core.ProgressiveMediaSource;
      expect(progressive.track.uri, Uri.parse('https://example.test/master.m3u8'));
      expect(progressive.track.kind, core.MediaTrackType.video);
      expect(progressive.track.headers?.values, {'Referer': 'https://example.test/'});
      expect(progressive.live, isFalse);
      expect(progressive.track.metadata['platform.media_kind'], 'vod');
      expect(progressive.track.metadata['platform.protocol'], 'hls');
    });

    test('test_toCoreSource_musicTicketWithoutTracks_becomesAudio', () {
      final source = toCoreSource(_ticket(kind: platform.MediaKind.music));

      expect((source as core.ProgressiveMediaSource).track.kind, core.MediaTrackType.audio);
    });

    test('test_toCoreSource_liveFlagComesFromKindOrMetadata', () {
      expect((toCoreSource(_ticket(kind: platform.MediaKind.live)) as core.ProgressiveMediaSource).live, isTrue);
      expect((toCoreSource(_ticket(isLive: true)) as core.ProgressiveMediaSource).live, isTrue);
      expect((toCoreSource(_ticket()) as core.ProgressiveMediaSource).live, isFalse);
    });

    test('test_toCoreSource_singleTrack_isProgressiveWithThatTrack', () {
      final track = _track('https://example.test/only.m3u8', headers: const <String, String>{'X': '1'});

      final source = toCoreSource(_ticket(tracks: <platform.MediaTrack>[track]));

      expect(source, isA<core.ProgressiveMediaSource>());
      expect((source as core.ProgressiveMediaSource).track.uri, track.uri);
      expect(source.tracks, hasLength(1));
    });

    test('test_toCoreSource_severalEssences_becomeCompositeGroups', () {
      final tracks = <platform.MediaTrack>[
        _track('https://example.test/v1080.mpd', kind: platform.MediaTrackType.video),
        _track('https://example.test/v720.mpd', kind: platform.MediaTrackType.video),
        _track('https://example.test/a1.mpd', kind: platform.MediaTrackType.audio, language: 'zh'),
        _track('https://example.test/a2.mpd', kind: platform.MediaTrackType.audio, language: 'en'),
        _track('https://example.test/s.vtt', kind: platform.MediaTrackType.subtitle, language: 'zh'),
      ];

      final source = toCoreSource(_ticket(tracks: tracks));

      expect(source, isA<core.CompositeMediaSource>());
      final composite = source as core.CompositeMediaSource;
      // Preference order is the ticket's order: the kernel picks the first candidate it can play.
      expect(composite.videoTracks.map((t) => t.uri.toString()), <String>[
        'https://example.test/v1080.mpd',
        'https://example.test/v720.mpd',
      ]);
      expect(composite.audioTracks.map((t) => t.language), <String>['zh', 'en']);
      expect(composite.subtitleTracks, hasLength(1));
    });

    test('test_toCoreSource_subtitleOnlyTracks_fallBackToTheTicketUrl', () {
      // CompositeMediaSource asserts a video or audio track, so captions alone cannot form one.
      final source = toCoreSource(
        _ticket(
          tracks: <platform.MediaTrack>[
            _track('https://example.test/s1.vtt', kind: platform.MediaTrackType.subtitle),
            _track('https://example.test/s2.vtt', kind: platform.MediaTrackType.subtitle),
          ],
        ),
      );

      expect(source, isA<core.ProgressiveMediaSource>());
      expect((source as core.ProgressiveMediaSource).track.uri, Uri.parse('https://example.test/master.m3u8'));
    });

    test('test_toCoreSource_perTrackHeadersSurviveTheComposite', () {
      final source = toCoreSource(
        _ticket(
          tracks: <platform.MediaTrack>[
            _track('https://example.test/v.mpd', headers: const <String, String>{'Referer': 'https://v.test/'}),
            _track(
              'https://example.test/a.mpd',
              kind: platform.MediaTrackType.audio,
              headers: const <String, String>{'Referer': 'https://a.test/'},
            ),
          ],
        ),
      ) as core.CompositeMediaSource;

      expect(source.videoTracks.single.headers?.values, {'Referer': 'https://v.test/'});
      expect(source.audioTracks.single.headers?.values, {'Referer': 'https://a.test/'});
    });
  });

  group('policy mapping', () {
    test('test_toRecoveryPolicy_defaultsKeepTheKernelInCharge', () {
      final policy = toRecoveryPolicy(const platform.MediaTicketPolicy());

      expect(policy.enabled, isTrue);
      expect(policy.retryDelay, const Duration(seconds: 2));
      expect(policy.allowSourceFallback, isTrue);
      expect(policy.allowBackendFallback, isFalse);
      // The ticket states intent, not attempts: counts stay at the kernel's own defaults.
      expect(policy.maxRetryCount, 3);
      expect(policy.exponentialBackoff, isTrue);
    });

    test('test_toRecoveryPolicy_retryForbiddenDisablesRecovery', () {
      const policy = platform.MediaTicketPolicy(
        allowRetry: false,
        allowRefresh: false,
        retryDelay: Duration(seconds: 9),
      );

      final mapped = toRecoveryPolicy(policy);

      expect(mapped.enabled, isFalse);
      expect(mapped.retryDelay, const Duration(seconds: 9));
      expect(mapped.allowSourceFallback, isFalse);
    });

    test('test_toFallbackPolicy_engineFallbackMapsToBackend', () {
      const policy = platform.MediaTicketPolicy(allowLineFallback: false, allowEngineFallback: true);

      final mapped = toFallbackPolicy(policy);

      expect(mapped.enabled, isTrue);
      expect(mapped.allowLineFallback, isFalse);
      expect(mapped.allowBackendFallback, isTrue);
      // Quality changes are a re-resolve with another SelectionRef, not a mid-playback downgrade.
      expect(mapped.downgradeQualityOnFailure, isFalse);
    });

    test('test_toFallbackPolicy_noFallbackAtAllDisablesIt', () {
      const policy = platform.MediaTicketPolicy(allowLineFallback: false, allowEngineFallback: false);

      final mapped = toFallbackPolicy(policy);

      expect(mapped.enabled, isFalse);
      expect(mapped.allowLineFallback, isFalse);
      expect(mapped.allowBackendFallback, isFalse);
    });
  });
}
