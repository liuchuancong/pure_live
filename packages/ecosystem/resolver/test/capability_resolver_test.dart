// Module: test/capability_resolver_test.dart
// Purpose: Verify the lift from a source's ResolveCapability into a platform Resolver, and the refresh gate.
// Author: liuchuancong
// Created: 2026-10-09
import 'package:pure_live_capability/pure_live_capability.dart';
import 'package:pure_live_platform/pure_live_platform.dart';
import 'package:pure_live_resolver/pure_live_resolver.dart';
import 'package:test/test.dart';

final DateTime _t0 = DateTime.utc(2026, 10, 9, 12);

ContentRef _ref({ContentKind kind = ContentKind.liveChannel, String id = 'cctv-1'}) =>
    ContentRef(sourceId: 'src-a', contentId: id, kind: kind);

MediaTicket _ticket(
  String id, {
  DateTime? expiresAt,
  bool allowRefresh = true,
  bool? refreshSupported,
  MediaProtocol protocol = MediaProtocol.hls,
}) {
  return MediaTicket(
    id: id,
    uri: Uri.parse('https://example.test/$id.m3u8'),
    kind: MediaKind.live,
    protocol: protocol,
    createdAt: _t0,
    expiresAt: expiresAt,
    policy: MediaTicketPolicy(allowRefresh: allowRefresh),
    refresh: refreshSupported == null ? null : MediaTicketRefreshInfo(supported: refreshSupported),
  );
}

/// The source side of the boundary: it answers with whatever ticket the test hands it, and records the ask.
final class _FakeCapability implements ResolveCapability {
  _FakeCapability({this.reply, this.failure});

  final MediaTicket? reply;
  final Object? failure;

  int resolveCalls = 0;
  int refreshCalls = 0;
  SelectionRef? lastQuality;
  RefreshReason? lastReason;
  MediaTicket? lastExpired;

  @override
  Future<MediaTicket> resolve(ContentRef ref, {SelectionRef? quality, SelectionRef? line}) async {
    resolveCalls++;
    lastQuality = quality;
    final failure = this.failure;
    if (failure != null) {
      throw failure;
    }
    return reply ?? _ticket('ticket-${ref.contentId}');
  }

  @override
  Future<MediaTicket> refresh(MediaTicket expired, RefreshReason reason) async {
    refreshCalls++;
    lastExpired = expired;
    lastReason = reason;
    final failure = this.failure;
    if (failure != null) {
      throw failure;
    }
    return _ticket('fresh-${expired.id}');
  }
}

ResolverDescriptor _descriptor({ResolverKind kind = ResolverKind.live, String id = 'src-a.live'}) =>
    ResolverDescriptor(id: id, name: id, kind: kind);

void main() {
  group('test_capabilityResolver_canResolve', () {
    test('test_canResolve_kindTheDescriptorServes_returnsTrue', () {
      final resolver = CapabilityResolver(descriptor: _descriptor(), capability: _FakeCapability());

      expect(resolver.canResolve(_ref(kind: ContentKind.liveChannel)), isTrue);
      expect(resolver.canResolve(_ref(kind: ContentKind.movie)), isFalse);
    });

    test('test_canResolve_allowedKinds_narrowsTheDescriptorWithoutWideningIt', () {
      // allowedKinds is a filter, not a grant: naming a kind the descriptor does not serve still refuses.
      final resolver = CapabilityResolver(
        descriptor: _descriptor(),
        capability: _FakeCapability(),
        allowedKinds: const <ContentKind>{ContentKind.liveRoom, ContentKind.movie},
      );

      expect(resolver.canResolve(_ref(kind: ContentKind.liveChannel)), isFalse);
      expect(resolver.canResolve(_ref(kind: ContentKind.liveRoom)), isTrue);
      expect(resolver.canResolve(_ref(kind: ContentKind.movie)), isFalse);
    });
  });

  group('test_capabilityResolver_resolve', () {
    test('test_resolve_carriesTheTicketAndNamesTheResolver', () async {
      final capability = _FakeCapability(reply: _ticket('t-1'));
      final resolver = CapabilityResolver(descriptor: _descriptor(), capability: capability, clock: () => _t0);

      final result = await resolver.resolve(ResolveRequest(ref: _ref()));

      expect(result.tickets.map((ticket) => ticket.id), <String>['t-1']);
      expect(result.source, _ref());
      expect(result.createdAt, _t0);
      expect(result.metadata['platform.resolver'], 'src-a.live');
    });

    test('test_resolve_preferredQuality_becomesASelectionRefForTheSource', () async {
      final capability = _FakeCapability();
      final resolver = CapabilityResolver(descriptor: _descriptor(), capability: capability, clock: () => _t0);

      await resolver.resolve(
        ResolveRequest(
          ref: _ref(),
          context: const ResolveContext(preferredQuality: '1080p'),
        ),
      );
      expect(capability.lastQuality, const SelectionRef('1080p'));

      await resolver.resolve(ResolveRequest(ref: _ref()));
      expect(capability.lastQuality, isNull);
    });

    test('test_resolve_selectionFollowsTheTicketProtocol', () async {
      final capability = _FakeCapability(reply: _ticket('t-1', protocol: MediaProtocol.dash));
      final resolver = CapabilityResolver(descriptor: _descriptor(), capability: capability, clock: () => _t0);

      final result = await resolver.resolve(
        ResolveRequest(
          ref: _ref(),
          context: const ResolveContext(preferredQuality: '720p'),
        ),
      );

      expect(result.selection.preferredProtocol, MediaProtocol.dash);
      expect(result.selection.preferredQuality, '720p');
    });

    test('test_resolve_unservedKind_refusesBeforeAskingTheSource', () async {
      final capability = _FakeCapability();
      final resolver = CapabilityResolver(descriptor: _descriptor(), capability: capability, clock: () => _t0);

      await expectLater(
        resolver.resolve(ResolveRequest(ref: _ref(kind: ContentKind.movie))),
        throwsA(isA<ResolverException>().having((e) => e.code, 'code', PlatformErrorCodes.resolverUnsupported)),
      );
      expect(capability.resolveCalls, 0);
    });

    test('test_resolve_ticketAlreadyExpired_isRefusedRatherThanHandedOver', () async {
      // Dead-ticket handling: passing it along would look like success here and fail inside the player, where
      // the recovery ladder has no way back to a different source.
      final capability = _FakeCapability(reply: _ticket('t-1', expiresAt: _t0.subtract(const Duration(seconds: 1))));
      final resolver = CapabilityResolver(descriptor: _descriptor(), capability: capability, clock: () => _t0);

      await expectLater(
        resolver.resolve(ResolveRequest(ref: _ref())),
        throwsA(isA<ResolverException>().having((e) => e.code, 'code', PlatformErrorCodes.mediaExpired)),
      );
      expect(capability.resolveCalls, 1);
    });

    test('test_resolve_ticketExpiringLater_isAccepted', () async {
      final capability = _FakeCapability(reply: _ticket('t-1', expiresAt: _t0.add(const Duration(minutes: 5))));
      final resolver = CapabilityResolver(descriptor: _descriptor(), capability: capability, clock: () => _t0);

      final result = await resolver.resolve(ResolveRequest(ref: _ref()));

      expect(result.tickets.single.id, 't-1');
    });

    test('test_resolve_sourceFailure_isClassifiedAsResolverFailedAndRetryable', () async {
      final capability = _FakeCapability(failure: Exception('js bridge returned null'));
      final resolver = CapabilityResolver(descriptor: _descriptor(), capability: capability, clock: () => _t0);

      await expectLater(
        resolver.resolve(ResolveRequest(ref: _ref())),
        throwsA(
          isA<ResolverException>()
              .having((e) => e.code, 'code', PlatformErrorCodes.resolverFailed)
              .having((e) => e.error.retryable, 'retryable', isTrue),
        ),
      );
    });

    test('test_resolve_classifiedFailureFromTheSource_isNotDoubleWrapped', () async {
      final capability = _FakeCapability(failure: ResolverException.cancelled('cctv-1'));
      final resolver = CapabilityResolver(descriptor: _descriptor(), capability: capability, clock: () => _t0);

      await expectLater(
        resolver.resolve(ResolveRequest(ref: _ref())),
        throwsA(isA<ResolverException>().having((e) => e.code, 'code', PlatformErrorCodes.taskCancelled)),
      );
    });
  });

  group('test_capabilityTicketRefresher', () {
    test('test_canRefresh_matrix_ofPolicyAndSourceAdvice', () {
      const both = MediaTicketRefreshInfo(supported: true);

      expect(CapabilityTicketRefresher(_FakeCapability()).canRefresh(_ticket('a')), isTrue);
      expect(CapabilityTicketRefresher(_FakeCapability()).canRefresh(_ticket('b', refreshSupported: false)), isFalse);
      expect(
        CapabilityTicketRefresher(_FakeCapability()).canRefresh(_ticket('c', allowRefresh: false)),
        isFalse,
        reason: 'the platform policy is a ceiling, source advice cannot lift it',
      );
      expect(
        CapabilityTicketRefresher(_FakeCapability())
            .canRefresh(_ticket('d', allowRefresh: false, refreshSupported: false)),
        isFalse,
      );
      expect(
        CapabilityTicketRefresher(_FakeCapability()).canRefresh(
          MediaTicket(
            id: 'e',
            uri: Uri.parse('https://example.test/e.m3u8'),
            kind: MediaKind.live,
            protocol: MediaProtocol.hls,
            createdAt: _t0,
            refresh: both,
          ),
        ),
        isTrue,
      );
    });

    test('test_canRefresh_nullAdvice_meansNoAdviceNotImpossible', () {
      // A source that never answered must not be treated as one that refused; the scheduler still prefetches.
      expect(CapabilityTicketRefresher(_FakeCapability()).canRefresh(_ticket('a', refreshSupported: null)), isTrue);
    });

    test('test_refresh_replacesTheTicketAndCarriesTheReason', () async {
      final capability = _FakeCapability();
      final expired = _ticket('t-1', expiresAt: _t0);

      final fresh = await CapabilityTicketRefresher(capability).refresh(expired, RefreshReason.expired);

      expect(fresh.id, 'fresh-t-1');
      expect(capability.lastExpired?.id, 't-1');
      expect(capability.lastReason, RefreshReason.expired);
    });

    test('test_refresh_platformRefused_isAPermissionFailure', () async {
      // Distinct from a source failure: retrying a refused refresh would loop forever.
      final capability = _FakeCapability();
      final refresher = CapabilityTicketRefresher(capability);

      await expectLater(
        refresher.refresh(_ticket('t-1', allowRefresh: false), RefreshReason.manual),
        throwsA(isA<ResolverException>().having((e) => e.code, 'code', PlatformErrorCodes.permissionRestricted)),
      );
      expect(capability.refreshCalls, 0);
    });

    test('test_refresh_sourceRefused_isAPermissionFailure', () async {
      final capability = _FakeCapability();

      await expectLater(
        CapabilityTicketRefresher(capability).refresh(_ticket('t-1', refreshSupported: false), RefreshReason.expiring),
        throwsA(isA<ResolverException>().having((e) => e.code, 'code', PlatformErrorCodes.permissionRestricted)),
      );
      expect(capability.refreshCalls, 0);
    });

    test('test_refresh_sourceFailure_isClassifiedAsResolverFailed', () async {
      final capability = _FakeCapability(failure: Exception('js bridge returned null'));

      await expectLater(
        CapabilityTicketRefresher(capability).refresh(_ticket('t-1'), RefreshReason.networkError),
        throwsA(isA<ResolverException>().having((e) => e.code, 'code', PlatformErrorCodes.resolverFailed)),
      );
    });
  });
}
