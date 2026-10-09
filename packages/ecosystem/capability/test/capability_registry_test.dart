// Module: test/capability_registry_test.dart
// Purpose: Verify how providers are discovered: by declared capability, by implemented interface, and per extension.
// Author: liuchuancong
// Created: 2026-10-09
//
// Spec: docs/contracts/provider-contract.md section 3 and docs/plugin/plugin-lifecycle.md's Enabled row.
import 'package:pure_live_capability/pure_live_capability.dart';
import 'package:pure_live_platform/pure_live_platform.dart';
import 'package:test/test.dart';

ContentRef _ref(String id) => ContentRef(sourceId: 's', contentId: id, kind: ContentKind.liveRoom);

PageResult<ContentSummary> _page() => PageResult<ContentSummary>(
  items: <ContentSummary>[ContentSummary(ref: _ref('a'), title: 'A')],
  page: 1,
  pageSize: 20,
);

/// Browse + resolve, which is what a content source is.
class _VideoSource implements BrowseCapability, ResolveCapability {
  @override
  Future<List<ContentCategory>> categories() async => const <ContentCategory>[];

  @override
  Future<PageResult<ContentSummary>> browse(ContentQuery query) async => _page();

  @override
  Future<ContentDetail> detail(ContentRef ref) async => ContentDetail(
    summary: ContentSummary(ref: ref, title: 'A'),
  );

  @override
  Future<MediaTicket> resolve(ContentRef ref, {SelectionRef? quality, SelectionRef? line}) async {
    final now = DateTime.now().toUtc();
    return MediaTicket(
      id: 't-1',
      uri: Uri.parse('https://example.test/a.m3u8'),
      kind: MediaKind.live,
      protocol: MediaProtocol.hls,
      createdAt: now,
      expiresAt: now.add(const Duration(minutes: 5)),
      source: ref,
    );
  }

  @override
  Future<MediaTicket> refresh(MediaTicket expired, RefreshReason reason) async =>
      resolve(expired.source ?? _ref(expired.id));
}

class _SearchSource implements SearchCapability {
  @override
  Future<PageResult<ContentSummary>> search(SearchQuery query) async => _page();
}

/// Declares search but does not implement it: the shape the typed view has to survive.
class _OverDeclarer extends _VideoSource {}

/// A capability kind whose method set the contract has not defined yet.
class _DanmakuSource extends _VideoSource {}

ProviderRegistration _registration(
  String sourceId, {
  String extensionId = 'purelive.fake',
  required Object provider,
  CapabilitySet capabilities = const CapabilitySet.empty(),
}) {
  return ProviderRegistration(
    sourceId: sourceId,
    extensionId: extensionId,
    provider: provider,
    capabilities: capabilities,
  );
}

void main() {
  group('test_registry_routingByDeclaration', () {
    test('test_providersFor_listsTheKindsTheSourceDeclared', () {
      final registry = CapabilityRegistry(<ProviderRegistration>[
        _registration(
          'bili.vod',
          provider: _VideoSource(),
          capabilities: const CapabilitySet(<CapabilityKind>{CapabilityKind.vod, CapabilityKind.live}),
        ),
        _registration(
          'bili.search',
          provider: _SearchSource(),
          capabilities: const CapabilitySet(<CapabilityKind>{CapabilityKind.search}),
        ),
      ]);

      expect(registry.providersFor(CapabilityKind.vod).map((e) => e.sourceId), <String>['bili.vod']);
      expect(registry.providersFor(CapabilityKind.search).map((e) => e.sourceId), <String>['bili.search']);
      expect(registry.providersFor(CapabilityKind.music), isEmpty);
    });

    test('test_providersFor_listsAKindWithNoInterfaceYet', () {
      // capability-contract.md section 3 defines method sets only for the content capabilities, so declaring
      // danmaku is legitimate today. Discovery by kind still has to see it, or a plugin's declaration would
      // be silently unrouteable until an interface lands.
      final registry = CapabilityRegistry(<ProviderRegistration>[
        _registration(
          'bili.danmaku',
          provider: _DanmakuSource(),
          capabilities: const CapabilitySet(<CapabilityKind>{CapabilityKind.danmaku}),
        ),
      ]);

      expect(registry.providersFor(CapabilityKind.danmaku).single.sourceId, 'bili.danmaku');
    });

    test('test_declaringNothing_routesToNothing', () {
      final registry = CapabilityRegistry(<ProviderRegistration>[_registration('quiet', provider: _VideoSource())]);

      expect(registry.all, hasLength(1));
      for (final kind in CapabilityKind.values) {
        expect(registry.providersFor(kind), isEmpty, reason: kind.name);
      }
    });
  });

  group('test_registry_typedView', () {
    test('test_implementations_returnsOnlyObjectsThatCanAnswer, in registration order', () {
      final registry = CapabilityRegistry(<ProviderRegistration>[
        _registration('first', provider: _SearchSource()),
        _registration('second', provider: _VideoSource()),
        _registration('third', provider: _SearchSource()),
      ]);

      expect(registry.implementations<SearchCapability>(), hasLength(2));
      expect(registry.implementations<SearchCapability>().first, same(registry.byId('first')!.provider));
      expect(registry.implementations<ResolveCapability>(), hasLength(1));
      expect(registry.implementations<BrowseCapability>(), hasLength(1));
    });

    test('test_overDeclaration_isNotHandedToTheTypedCaller', () {
      // The two views disagree on purpose: routing follows what a source said, while a caller that is about
      // to make a call gets only what can take it.
      final registry = CapabilityRegistry(<ProviderRegistration>[
        _registration(
          'liar',
          provider: _OverDeclarer(),
          capabilities: const CapabilitySet(<CapabilityKind>{CapabilityKind.search}),
        ),
      ]);

      expect(registry.providersFor(CapabilityKind.search), hasLength(1));
      expect(registry.implementations<SearchCapability>(), isEmpty);
    });

    test('test_implementations_isEmptyWhenNobodyServesTheInterface', () {
      final registry = CapabilityRegistry(<ProviderRegistration>[_registration('search', provider: _SearchSource())]);

      expect(registry.implementations<FeedCapability>(), isEmpty);
    });
  });

  group('test_registry_lifetime', () {
    test('test_register_sameSourceId_replacesTheProviderAndKeepsItsSlot', () async {
      final registry = CapabilityRegistry(<ProviderRegistration>[
        _registration('a', provider: _SearchSource()),
        _registration('b', provider: _SearchSource()),
      ]);
      final replacement = _VideoSource();

      registry.register(_registration('a', provider: replacement));

      expect(registry.length, 2);
      expect(registry.all.map((entry) => entry.sourceId), <String>['a', 'b']);
      expect(registry.byId('a')!.provider, same(replacement));
      expect(registry.implementations<SearchCapability>(), hasLength(1));
    });

    test('test_unregister_returnsWhatWentAndNullWhenAbsent', () {
      final registry = CapabilityRegistry(<ProviderRegistration>[_registration('a', provider: _SearchSource())]);

      expect(registry.unregister('a')!.sourceId, 'a');
      expect(registry.unregister('a'), isNull);
      expect(registry.isEmpty, isTrue);
    });

    test('test_unregisterExtension_removesEverySourceTheExtensionOwns', () {
      // plugin-lifecycle.md: Enabled means "visible to the CapabilityRegistry". Disabling names the extension,
      // not its repositories, so the bulk removal is the operation the lifecycle actually needs.
      final registry = CapabilityRegistry(<ProviderRegistration>[
        _registration('bili.vod', extensionId: 'purelive.bilibili', provider: _VideoSource()),
        _registration('bili.live', extensionId: 'purelive.bilibili', provider: _VideoSource()),
        _registration('huya.live', extensionId: 'purelive.huya', provider: _VideoSource()),
      ]);

      final removed = registry.unregisterExtension('purelive.bilibili');

      expect(removed.map((entry) => entry.sourceId), <String>['bili.vod', 'bili.live']);
      expect(registry.all.map((entry) => entry.sourceId), <String>['huya.live']);
      expect(registry.unregisterExtension('purelive.nobody'), isEmpty);
    });

    test('test_all_isUnmodifiable', () {
      final registry = CapabilityRegistry(<ProviderRegistration>[_registration('a', provider: _SearchSource())]);

      expect(() => registry.all.clear(), throwsUnsupportedError);
    });

    test('test_clear_emptiesTheIndex', () {
      final registry = CapabilityRegistry(<ProviderRegistration>[
        _registration('a', provider: _SearchSource()),
        _registration('b', provider: _VideoSource()),
      ])..clear();

      expect(registry.isEmpty, isTrue);
      expect(registry.implementations<BrowseCapability>(), isEmpty);
    });
  });
}
