// Module: test/capability_resolver_timeout_test.dart
// Purpose: Verify the resolve budget exists and produces the classified, retryable failure.
// Author: liuchuancong
// Created: 2026-10-10
//
// `ResolverException.timedOut` was defined from the first commit and nothing ever threw it: the adapter
// awaited a provider's network call with no bound, so one hung source stalled playback start forever and
// the recovery ladder - whose whole purpose is to move off a dead source - never ran.

import 'package:pure_live_capability/pure_live_capability.dart';
import 'package:pure_live_platform/pure_live_platform.dart';
import 'package:pure_live_resolver/pure_live_resolver.dart';
import 'package:test/test.dart';

final DateTime _t0 = DateTime.utc(2026, 10, 10, 12);

ContentRef _ref({String id = 'cctv-1'}) => ContentRef(sourceId: 'src-a', contentId: id, kind: ContentKind.liveChannel);

MediaTicket _ticket(String id) => MediaTicket(
  id: id,
  uri: Uri.parse('https://example.test/$id.m3u8'),
  kind: MediaKind.live,
  protocol: MediaProtocol.hls,
  createdAt: _t0,
);

/// A provider that never answers within the budget.
final class _HangingCapability implements ResolveCapability {
  _HangingCapability({this.hangFor = const Duration(seconds: 5)});

  final Duration hangFor;
  int resolveCalls = 0;
  int refreshCalls = 0;

  @override
  Future<MediaTicket> resolve(ContentRef ref, {SelectionRef? quality, SelectionRef? line}) async {
    resolveCalls++;
    return Future<MediaTicket>.delayed(hangFor, () => _ticket('late-${ref.contentId}'));
  }

  @override
  Future<MediaTicket> refresh(MediaTicket expired, RefreshReason reason) async {
    refreshCalls++;
    return Future<MediaTicket>.delayed(hangFor, () => _ticket('late-refresh'));
  }
}

ResolverDescriptor _descriptor() =>
    const ResolverDescriptor(id: 'src-a.live', name: 'src-a.live', kind: ResolverKind.live);

const Duration _budget = Duration(milliseconds: 40);

void main() {
  group('test_capabilityResolver_timeout', () {
    test('test_resolve_hungSource_failsWithTheTimeoutCodeNotAGenericFailure', () async {
      final resolver = CapabilityResolver(
        descriptor: _descriptor(),
        capability: _HangingCapability(),
        clock: () => _t0,
        timeout: _budget,
      );

      await expectLater(
        resolver.resolve(ResolveRequest(ref: _ref())),
        throwsA(
          isA<ResolverException>()
              .having((error) => error.code, 'code', PlatformErrorCodes.resolverTimeout)
              .having((error) => error.error.retryable, 'retryable', isTrue)
              .having((error) => error.error.category, 'category', PlatformErrorCategory.timeout),
        ),
      );
    });

    test('test_resolve_aReplyWithinTheBudget_isUnaffected', () async {
      final resolver = CapabilityResolver(
        descriptor: _descriptor(),
        capability: _HangingCapability(hangFor: Duration.zero),
        clock: () => _t0,
        timeout: _budget,
      );

      final result = await resolver.resolve(ResolveRequest(ref: _ref()));

      expect(result.tickets.single.id, 'late-cctv-1');
    });

    test('test_resolve_zeroTimeout_disablesTheBudget', () async {
      final resolver = CapabilityResolver(
        descriptor: _descriptor(),
        capability: _HangingCapability(hangFor: const Duration(milliseconds: 30)),
        clock: () => _t0,
        timeout: Duration.zero,
      );

      expect(await resolver.resolve(ResolveRequest(ref: _ref())), isA<ResolveResult>());
    });

    test('test_refresh_hungSourceAlsoHitsTheBudget', () async {
      final refresher = CapabilityTicketRefresher(_HangingCapability(), timeout: _budget);

      await expectLater(
        refresher.refresh(_ticket('t-1'), RefreshReason.expiring),
        throwsA(
          isA<ResolverException>()
              .having((error) => error.code, 'code', PlatformErrorCodes.resolverTimeout)
              .having((error) => error.error.retryable, 'retryable', isTrue),
        ),
      );
    });

    test('test_resolve_defaultBudgetIsStatedNotInfinite', () {
      // The default is what protects a caller that forgot to think about it, so it must not be "no limit".
      final resolver = CapabilityResolver(descriptor: _descriptor(), capability: _HangingCapability());

      expect(resolver.timeout, CapabilityResolver.kDefaultResolveTimeout);
      expect(CapabilityResolver.kDefaultResolveTimeout, isNot(Duration.zero));
    });
  });
}
