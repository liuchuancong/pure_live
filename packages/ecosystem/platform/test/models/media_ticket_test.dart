// Module: test/models/media_ticket_test.dart
// Purpose: Verify MediaTicket and resolver boundary rules from docs/contracts/platform-models.md sections 10 and 11.
// Author: liuchuancong
// Created: 2026-10-08
import 'package:pure_live_platform/pure_live_platform.dart';
import 'package:test/test.dart';

MediaTicket _ticket({String id = 'ticket-1', DateTime? expiresAt, String uri = 'https://example.com/index.m3u8'}) {
  return MediaTicket(
    id: id,
    uri: Uri.parse(uri),
    kind: MediaKind.live,
    protocol: MediaProtocol.hls,
    createdAt: DateTime.utc(2026, 10, 8, 12),
    expiresAt: expiresAt,
  );
}

void main() {
  test('test_mediaTicket_jsonRoundTrip_preservesFields', () {
    final ticket = MediaTicket(
      id: 't1',
      uri: Uri.parse('https://example.com/v.mpd'),
      kind: MediaKind.vod,
      protocol: MediaProtocol.dash,
      createdAt: DateTime.utc(2026, 10, 8, 12),
      expiresAt: DateTime.utc(2026, 10, 8, 13),
      headers: const <String, String>{'Referer': 'https://example.com/'},
      tracks: <MediaTrack>[MediaTrack(uri: Uri.parse('https://example.com/v.mpd'), kind: MediaKind.vod, codec: 'avc1')],
      source: const ContentRef(sourceId: 's', contentId: 'c', kind: ContentKind.movie),
    );

    final decoded = MediaTicket.fromJson(ticket.toJson());
    expect(decoded.id, 't1');
    expect(decoded.uri, ticket.uri);
    expect(decoded.protocol, MediaProtocol.dash);
    expect(decoded.headers['Referer'], 'https://example.com/');
    expect(decoded.tracks.single.codec, 'avc1');
    expect(decoded.source, ticket.source);
    expect(decoded.expiresAt, ticket.expiresAt);
  });

  test('test_mediaTicket_equal_byIdOnly', () {
    // Section 16: ticket identity is its id; a refreshed url for the same ticket stays equal.
    expect(_ticket(), _ticket(uri: 'https://example.com/other.m3u8'));
    expect(_ticket(id: 'a'), isNot(equals(_ticket(id: 'b'))));
  });

  test('test_mediaTicketPolicy_defaults_matchTheSpec', () {
    const policy = MediaTicketPolicy();

    expect(policy.allowRedirect, isTrue);
    expect(policy.allowRefresh, isTrue);
    expect(policy.allowRetry, isTrue);
    expect(policy.allowLineFallback, isTrue);
    // Engine fallback stays opt-in: a source that only works in one engine must not be retried elsewhere.
    expect(policy.allowEngineFallback, isFalse);
    expect(policy.retryDelay, const Duration(seconds: 2));
  });

  test('test_mediaTicket_isExpiredAt_boundaryInstantCountsAsExpired', () {
    final expiry = DateTime.utc(2026, 10, 8, 13);
    final ticket = _ticket(expiresAt: expiry);

    expect(ticket.isExpiredAt(expiry.add(const Duration(seconds: 1))), isTrue);
    expect(ticket.isExpiredAt(expiry), isTrue);
    expect(ticket.isExpiredAt(expiry.subtract(const Duration(milliseconds: 1))), isFalse);
  });

  test('test_mediaTicket_isExpiredAt_localNowIsComparedAsUtc', () {
    final ticket = _ticket(expiresAt: DateTime.utc(2026, 10, 8, 13));
    final localEquivalent = ticket.expiresAt!.toLocal();

    expect(ticket.isExpiredAt(localEquivalent), isTrue);
  });

  test('test_mediaTicket_json_persistsDurationsAsMilliseconds', () {
    const policy = MediaTicketPolicy(retryDelay: Duration(milliseconds: 1500));

    expect(policy.toJson()['retryDelayMs'], 1500);
    expect(MediaTicketPolicy.fromJson(policy.toJson()).retryDelay, const Duration(milliseconds: 1500));
  });

  test('test_mediaTicket_json_keepsKindAndProtocolSeparate', () {
    // Section 11 forbids merging the semantic kind with the transport protocol.
    final json = _ticket().toJson();

    expect(json['kind'], 'live');
    expect(json['protocol'], 'hls');
  });

  test('test_resolveRequest_defaults_allowFallbackAndNormalIntent', () {
    const request = ResolveRequest(
      ref: ContentRef(sourceId: 's', contentId: 'c', kind: ContentKind.vod),
    );

    expect(request.allowFallback, isTrue);
    expect(request.context.intent, PlaybackIntent.normal);
    expect(request.context.networkMetered, isFalse);
  });

  test('test_resolveResult_jsonRoundTrip_keepsTicketOrder', () {
    final result = ResolveResult(
      source: const ContentRef(sourceId: 's', contentId: 'c', kind: ContentKind.vod),
      tickets: <MediaTicket>[
        _ticket(id: 'first'),
        _ticket(id: 'second'),
      ],
      createdAt: DateTime.utc(2026, 10, 8, 12),
      selection: const MediaSelectionPolicy(preferredQuality: '1080p', preferLowLatency: true),
    );

    final decoded = ResolveResult.fromJson(result.toJson());
    expect(decoded.tickets.map((ticket) => ticket.id), <String>['first', 'second']);
    expect(decoded.selection.preferredQuality, '1080p');
    expect(decoded.selection.preferLowLatency, isTrue);
    expect(decoded.selection.preferStable, isTrue);
    expect(decoded.isEmpty, isFalse);
  });

  test('test_resolveResult_fromJson_skipsUnreadableTickets', () {
    final resultJson = <String, Object?>{
      'source': <String, Object?>{'sourceId': 's', 'contentId': 'c', 'kind': 'vod'},
      'createdAt': '2026-10-08T12:00:00.000Z',
      'tickets': <Object?>[
        <String, Object?>{'id': 'ok', 'uri': 'https://example.com/a', 'kind': 'live', 'protocol': 'hls'},
        <String, Object?>{'uri': 'missing id'},
      ],
    };

    // A ticket without its id is corrupt, not merely unknown: the reader says which model failed.
    expect(
      () => ResolveResult.fromJson(resultJson),
      throwsA(
        isA<FormatException>().having(
          (e) => e.message,
          'message',
          contains('media_ticket is missing required field "id"'),
        ),
      ),
    );
  });
}
