// Module: test/resolver_registry_test.dart
// Purpose: Verify candidate ordering and the chain's fallback, no-fallback and cancellation rules.
// Author: liuchuancong
// Created: 2026-10-09
import 'package:pure_live_platform/pure_live_platform.dart';
import 'package:pure_live_resolver/pure_live_resolver.dart';
import 'package:test/test.dart';

final DateTime _t0 = DateTime.utc(2026, 10, 9, 12);

ContentRef _ref({ContentKind kind = ContentKind.liveChannel, String id = 'cctv-1'}) =>
    ContentRef(sourceId: 'src-a', contentId: id, kind: kind);

ResolveRequest _request({ContentKind kind = ContentKind.liveChannel, bool allowFallback = true}) => ResolveRequest(
  ref: _ref(kind: kind),
  allowFallback: allowFallback,
);

MediaTicket _ticket(String id) => MediaTicket(
  id: id,
  uri: Uri.parse('https://example.test/$id.m3u8'),
  kind: MediaKind.live,
  protocol: MediaProtocol.hls,
  createdAt: _t0,
);

/// A candidate that records being asked, so a test can tell "tried" from "skipped".
final class _StubResolver implements Resolver {
  _StubResolver(this.descriptor, {this.refuses = false, this.reply, this.failure});

  @override
  final ResolverDescriptor descriptor;

  final bool refuses;
  final ResolveResult? reply;
  final Object? failure;

  int asked = 0;

  @override
  bool canResolve(ContentRef ref) => !refuses && descriptor.serves(ref.kind);

  @override
  Future<ResolveResult> resolve(ResolveRequest request) async {
    asked++;
    final failure = this.failure;
    if (failure != null) {
      throw failure;
    }
    return reply ?? ResolveResult(source: request.ref, tickets: <MediaTicket>[_ticket(descriptor.id)], createdAt: _t0);
  }
}

ResolverDescriptor _descriptor(String id, {ResolverKind kind = ResolverKind.live, int priority = 0}) =>
    ResolverDescriptor(id: id, name: id, kind: kind, priority: priority);

ResolveResult _empty(ContentRef ref) => ResolveResult(source: ref, tickets: const <MediaTicket>[], createdAt: _t0);

void main() {
  group('test_registry', () {
    test('test_registry_candidatesFor_ordersByPriorityDescending', () {
      final registry = ResolverRegistry(<Resolver>[
        _StubResolver(_descriptor('low', priority: 1)),
        _StubResolver(_descriptor('high', priority: 9)),
        _StubResolver(_descriptor('mid', priority: 5)),
      ]);

      expect(registry.candidatesFor(_ref()).map((resolver) => resolver.descriptor.id), <String>['high', 'mid', 'low']);
    });

    test('test_registry_candidatesFor_equalPriority_keepsInsertionOrder', () {
      // List.sort is not stable in Dart, so the index tie-break is what makes "registered first, tried first"
      // hold instead of shuffling equal-priority candidates between runs.
      final registry = ResolverRegistry(<Resolver>[
        _StubResolver(_descriptor('first')),
        _StubResolver(_descriptor('second')),
        _StubResolver(_descriptor('third')),
      ]);

      expect(registry.candidatesFor(_ref()).map((resolver) => resolver.descriptor.id), <String>[
        'first',
        'second',
        'third',
      ]);
    });

    test('test_registry_candidatesFor_omitsResolversThatCannotServe', () {
      final registry = ResolverRegistry(<Resolver>[
        _StubResolver(_descriptor('vod-only', kind: ResolverKind.vod)),
        _StubResolver(_descriptor('live', priority: -1)),
        _StubResolver(_descriptor('declined'), refuses: true),
      ]);

      expect(registry.candidatesFor(_ref()).map((resolver) => resolver.descriptor.id), <String>['live']);
      // The vod resolver serves the movie while the live one does not, and the refusing one serves nothing.
      expect(registry.candidatesFor(_ref(kind: ContentKind.movie)).map((r) => r.descriptor.id), <String>['vod-only']);
    });

    test('test_registry_register_sameId_replacesWithoutDuplicating', () {
      final first = _StubResolver(_descriptor('dup'));
      final second = _StubResolver(_descriptor('dup', priority: 3));
      final registry = ResolverRegistry(<Resolver>[first, _StubResolver(_descriptor('other'))])..register(second);

      expect(registry.all, hasLength(2));
      expect(registry.byId('dup'), same(second));
      expect(registry.candidatesFor(_ref()), contains(second));
      expect(registry.candidatesFor(_ref()), isNot(contains(first)));
    });

    test('test_registry_unregister_byId_removesOnlyThatResolver', () {
      final registry = ResolverRegistry(<Resolver>[_StubResolver(_descriptor('a')), _StubResolver(_descriptor('b'))])
        ..unregister('a');

      expect(registry.byId('a'), isNull);
      expect(registry.all.map((resolver) => resolver.descriptor.id), <String>['b']);
    });
  });

  group('test_chain', () {
    test('test_chain_resolve_returnsTheFirstCandidateThatProducesTickets', () async {
      final preferred = _StubResolver(_descriptor('preferred', priority: 5));
      final backup = _StubResolver(_descriptor('backup'));
      final chain = ResolverChain(registry: ResolverRegistry(<Resolver>[preferred, backup]));

      final result = await chain.resolve(_request());

      expect(result.tickets.single.id, 'preferred');
      expect(preferred.asked, 1);
      expect(backup.asked, 0);
    });

    test('test_chain_resolve_candidateFails_fallsBackToTheNext', () async {
      final failing = _StubResolver(
        _descriptor('failing', priority: 5),
        failure: ResolverException.failed('cctv-1', Exception('http 500')),
      );
      final backup = _StubResolver(_descriptor('backup'));
      final chain = ResolverChain(registry: ResolverRegistry(<Resolver>[failing, backup]));

      final result = await chain.resolve(_request());

      expect(result.tickets.single.id, 'backup');
      expect(backup.asked, 1);
    });

    test('test_chain_resolve_nothingServes_throwsResolverUnsupported', () async {
      final chain = ResolverChain(
        registry: ResolverRegistry(<Resolver>[_StubResolver(_descriptor('vod', kind: ResolverKind.vod))]),
      );

      await expectLater(
        chain.resolve(_request()),
        throwsA(isA<ResolverException>().having((e) => e.code, 'code', PlatformErrorCodes.resolverUnsupported)),
      );
    });

    test('test_chain_resolve_allowFallbackFalse_rethrowsAndNeverTriesTheNext', () async {
      // A mid-stream refresh must not silently change source: the chosen line carried its subtitles and its
      // quality promise, so the refusal has to reach the caller unchanged.
      final failing = _StubResolver(
        _descriptor('failing', priority: 5),
        failure: ResolverException.failed('cctv-1', Exception('http 403')),
      );
      final backup = _StubResolver(_descriptor('backup'));
      final chain = ResolverChain(registry: ResolverRegistry(<Resolver>[failing, backup]));

      await expectLater(
        chain.resolve(_request(allowFallback: false)),
        throwsA(isA<ResolverException>().having((e) => e.error.message, 'message', contains('http 403'))),
      );
      expect(backup.asked, 0);
    });

    test('test_chain_resolve_allowFallbackFalse_emptyResult_stopsAfterTheFirstCandidate', () async {
      final empty = _StubResolver(_descriptor('empty', priority: 5), reply: _empty(_ref()));
      final backup = _StubResolver(_descriptor('backup'));
      final chain = ResolverChain(registry: ResolverRegistry(<Resolver>[empty, backup]));

      await expectLater(chain.resolve(_request(allowFallback: false)), throwsA(isA<ResolverException>()));
      expect(backup.asked, 0);
    });

    test('test_chain_resolve_cancellation_isRethrownInsteadOfFallingBack', () async {
      // platform-models.md section 20 invariant 9: the caller stopped asking, which is not a reason to try
      // another source.
      final cancelled = _StubResolver(
        _descriptor('cancelled', priority: 5),
        failure: ResolverException.cancelled('cctv-1'),
      );
      final backup = _StubResolver(_descriptor('backup'));
      final chain = ResolverChain(registry: ResolverRegistry(<Resolver>[cancelled, backup]));

      await expectLater(
        chain.resolve(_request()),
        throwsA(isA<ResolverException>().having((e) => e.code, 'code', PlatformErrorCodes.taskCancelled)),
      );
      expect(backup.asked, 0);
    });

    test('test_chain_resolve_everyCandidateEmpty_reportsTheFirstRefusal', () async {
      final first = _StubResolver(_descriptor('first', priority: 9), reply: _empty(_ref()));
      final second = _StubResolver(_descriptor('second'), reply: _empty(_ref()));
      final chain = ResolverChain(registry: ResolverRegistry(<Resolver>[first, second]));

      await expectLater(
        chain.resolve(_request()),
        throwsA(
          isA<ResolverException>()
              .having((e) => e.code, 'code', PlatformErrorCodes.resolverFailed)
              .having((e) => e.error.message, 'message', contains('first')),
        ),
      );
      expect(second.asked, 1);
    });

    test('test_chain_resolve_foreignException_isClassifiedAsResolverFailed', () async {
      // The caller must be able to branch on a code, not on which exception a third-party runtime chose.
      final throwing = _StubResolver(_descriptor('throwing', priority: 9), failure: StateError('js bridge died'));
      final backup = _StubResolver(_descriptor('backup'));
      final chain = ResolverChain(registry: ResolverRegistry(<Resolver>[throwing, backup]));

      final result = await chain.resolve(_request());

      expect(result.tickets.single.id, 'backup');
      expect(throwing.asked, 1);
    });

    test('test_chain_resolve_foreignExceptionWithNoFallback_rethrowsTheOriginal', () async {
      final boom = StateError('js bridge died');
      final throwing = _StubResolver(_descriptor('throwing'), failure: boom);
      final chain = ResolverChain(registry: ResolverRegistry(<Resolver>[throwing]));

      await expectLater(chain.resolve(_request(allowFallback: false)), throwsA(same(boom)));
    });
  });
}
