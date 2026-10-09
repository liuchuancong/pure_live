// Module: test/playback_trace_test.dart
// Purpose: Verify the playback evidence chain, its fault ownership and that a report carries no credentials.
// Author: liuchuancong
// Created: 2026-10-09
import 'package:flutter_test/flutter_test.dart';
import 'package:pure_live_media/pure_live_media.dart';
import 'package:pure_live_platform/pure_live_platform.dart';

final DateTime _t0 = DateTime.utc(2026, 10, 9, 12);

MediaTicket _ticket({String id = 't-1', String uri = 'https://cdn.example.test/v1/index.m3u8?sign=abc123&token=xyz'}) {
  return MediaTicket(
    id: id,
    uri: Uri.parse(uri),
    kind: MediaKind.vod,
    protocol: MediaProtocol.hls,
    createdAt: _t0,
    expiresAt: _t0.add(const Duration(minutes: 10)),
    metadata: const MediaPlaybackMetadata(
      extra: <String, Object?>{'platform.quality': '1080p', 'platform.line': 'line-2'},
    ),
  );
}

PlaybackTrace _trace() => PlaybackTrace(
  traceId: 'trace-1',
  content: const ContentRef(sourceId: 'com.example.bili', contentId: 'c-1', kind: ContentKind.vod),
  extensionId: 'com.example.bili',
  sourceId: 'source-1',
);

void main() {
  group('recording', () {
    test('test_mark_keepsTheChainInOrderAndBoundsIt', () {
      final trace = _trace();

      for (var index = 0; index < 200; index++) {
        trace.mark(PlaybackStage.buffering, _t0.add(Duration(seconds: index)));
      }

      expect(trace.marks, hasLength(128));
      // The newest events are the ones a diagnosis needs, so the oldest are the ones that go.
      expect(trace.marks.last.at, _t0.add(const Duration(seconds: 199)));
      expect(trace.marks.first.at, _t0.add(const Duration(seconds: 72)));
    });

    test('test_recordTicket_countsARepeatIdAsARefreshInsteadOfANewTicket', () {
      final trace = _trace();
      final ticket = _ticket();

      trace.recordTicket(ticket);
      trace.recordTicket(ticket);
      trace.recordTicket(_ticket(id: 't-2', uri: 'https://other.test/x.m3u8'));

      expect(trace.tickets, hasLength(2));
      expect(trace.tickets.first.refreshCount, 1);
      expect(trace.tickets.last.refreshCount, 0);
    });

    test('test_recordTicket_keepsQualityAndLineAcrossTheRefresh', () {
      final trace = _trace();
      trace.recordTicket(_ticket());
      trace.recordTicket(_ticket());

      final record = trace.tickets.single;

      expect(record.quality, '1080p');
      expect(record.line, 'line-2');
      expect(record.protocol, 'hls');
      expect(record.host, 'cdn.example.test');
    });
  });

  group('report redaction', () {
    test('test_report_neverPrintsATicketQuery', () {
      final trace = _trace()..recordTicket(_ticket());

      final json = trace.report();

      final rendered = '$json';
      expect(rendered, isNot(contains('abc123')));
      expect(rendered, isNot(contains('xyz')));
      // The host and the path survive, because those are what makes the report debuggable.
      expect(rendered, contains('cdn.example.test'));
    });

    test('test_report_scrubsCredentialLookingTextAndEnvironment', () {
      final trace = _trace()
        ..mark(PlaybackStage.failed, _t0, detail: 'request had Authorization: Bearer super-secret')
        ..noteNetwork('cookie: sid=deadbeef rejected');

      final rendered =
          '${trace.report(environment: <String, Object?>{'account': 'token=personal-token', 'engine': 'media_kit'})}';

      expect(rendered, isNot(contains('super-secret')));
      expect(rendered, isNot(contains('deadbeef')));
      expect(rendered, isNot(contains('personal-token')));
      expect(rendered, contains('media_kit'), reason: 'non-secret environment stays readable');
    });

    test('test_redactText_dropsEveryQueryParameterNotJustTheFirst', () {
      final text = 'https://host/p?a=1&b=2&c=3';

      final redacted = redactText(text);

      expect(redacted, isNot(contains('a=1')));
      expect(redacted, isNot(contains('b=2')));
      expect(redacted, isNot(contains('c=3')));
      expect(redacted, contains('https://host/p?***'));
    });

    test('test_redactText_leavesPlainTextAlone', () {
      expect(redactText('engine reported a decoder error'), 'engine reported a decoder error');
    });

    test('test_redactText_consumesAWholeHeaderValueNotItsFirstWord', () {
      // The tail of a multi-word credential is the secret: "Authorization: Bearer <token>" leaks the token
      // if the value class stops at the first space.
      expect(redactText('Authorization: Bearer abc.def.ghi'), 'Authorization: ***');
      expect(redactText('Cookie: sid=1; role=admin'), 'Cookie: ***; role=admin');
    });
  });

  group('fault ownership', () {
    test('test_classifyFault_mapsCodesToTheComponentThatFixesThem', () {
      const cases = <(String, PlaybackFaultOwner)>[
        ('resolver.failed', PlaybackFaultOwner.source),
        ('source.parse_failed', PlaybackFaultOwner.source),
        ('repository.unavailable', PlaybackFaultOwner.source),
        ('network.timeout', PlaybackFaultOwner.network),
        ('media.unavailable', PlaybackFaultOwner.media),
        ('media.expired', PlaybackFaultOwner.media),
        ('extension.load_failed', PlaybackFaultOwner.unknown),
      ];

      for (final (code, owner) in cases) {
        final trace = _trace()
          ..fail(PlatformErrorInfo(code: code, message: 'boom', category: PlatformErrorCategory.unknown));

        expect(trace.classifyFault(), owner, reason: code);
      }
    });

    test('test_classifyFault_usesCategoryWhenTheCodeIsForeign', () {
      // A plugin namespace the platform cannot prefix-match still has to land on an owner.
      final trace = _trace()
        ..fail(
          const PlatformErrorInfo(
            code: 'tvbox.script_failed',
            message: 'spider threw',
            category: PlatformErrorCategory.network,
          ),
        );

      expect(trace.classifyFault(), PlaybackFaultOwner.network);
    });

    test('test_report_leadsWithTheFaultAndNamesItsOwner', () {
      final trace = _trace()
        ..mark(PlaybackStage.request, _t0)
        ..mark(PlaybackStage.resolve, _t0.add(const Duration(milliseconds: 40)))
        ..fail(
          const PlatformErrorInfo(
            code: PlatformErrorCodes.resolverFailed,
            message: 'no line answered',
            category: PlatformErrorCategory.resolver,
          ),
          at: _t0.add(const Duration(seconds: 1)),
        );

      final report = trace.report();
      final fault = report['fault']! as Map<String, Object?>;

      expect(report['traceId'], 'trace-1');
      expect(fault['code'], 'resolver.failed');
      expect(fault['owner'], 'source');
      expect((report['stages']! as List<Object?>), hasLength(3));
      expect(trace.hasFailed, isTrue);
    });

    test('test_report_withoutAFault_reportsNoFaultKey', () {
      final trace = _trace()..mark(PlaybackStage.started, _t0);

      expect(trace.report().containsKey('fault'), isFalse);
      expect(trace.hasFailed, isFalse);
    });
  });
}
