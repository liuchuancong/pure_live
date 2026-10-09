// Module: test/models/resolver_descriptor_test.dart
// Purpose: Verify the resolver vocabulary and which content kinds each resolver kind is asked about.
// Author: liuchuancong
// Created: 2026-10-09
//
// Spec: docs/contracts/platform-models.md section 10 (ResolveRequest / ResolveResult) and
// docs/contracts/platform-contracts.md section 12 (Resolver). docs/architecture/evolution.md forbids renaming
// or reordering an enum once it ships, so the name list is pinned as a set.
import 'package:pure_live_platform/pure_live_platform.dart';
import 'package:test/test.dart';

ResolverDescriptor _descriptor({String id = 'r1', ResolverKind kind = ResolverKind.live, int priority = 0}) =>
    ResolverDescriptor(id: id, name: 'Display $id', kind: kind, priority: priority);

void main() {
  test('test_resolverKind_names_coverEveryDocumentedResolver', () {
    expect(ResolverKind.values.map((kind) => kind.name).toSet(), <String>{
      'live',
      'vod',
      'music',
      'iptv',
      'local',
      'download',
    });
  });

  group('test_resolverDescriptor_serves', () {
    test('test_serves_live_acceptsEveryLiveShapedKind', () {
      final descriptor = _descriptor(kind: ResolverKind.live);
      for (final kind in <ContentKind>[ContentKind.liveChannel, ContentKind.liveRoom, ContentKind.stream]) {
        expect(descriptor.serves(kind), isTrue, reason: kind.name);
      }
      expect(descriptor.serves(ContentKind.vod), isFalse);
    });

    test('test_serves_vod_coversTheSeriesTree', () {
      final descriptor = _descriptor(kind: ResolverKind.vod);
      for (final kind in <ContentKind>[ContentKind.vod, ContentKind.movie, ContentKind.series, ContentKind.episode]) {
        expect(descriptor.serves(kind), isTrue, reason: kind.name);
      }
      expect(descriptor.serves(ContentKind.liveChannel), isFalse);
    });

    test('test_serves_music_coversAlbumAndArtist', () {
      final descriptor = _descriptor(kind: ResolverKind.music);
      for (final kind in <ContentKind>[ContentKind.music, ContentKind.album, ContentKind.artist]) {
        expect(descriptor.serves(kind), isTrue, reason: kind.name);
      }
      expect(descriptor.serves(ContentKind.playlist), isFalse);
    });

    test('test_serves_iptv_isTheOnlyKindThatGetsEpgProgram', () {
      final epg = ContentRef(sourceId: 's', contentId: 'p', kind: ContentKind.epgProgram);
      expect(_descriptor(kind: ResolverKind.iptv).serves(epg.kind), isTrue);
      expect(_descriptor(kind: ResolverKind.live).serves(epg.kind), isFalse);
      // An EPG row is a schedule entry, not a channel: a live resolver is asked about the channel instead.
      expect(_descriptor(kind: ResolverKind.iptv).serves(ContentKind.liveRoom), isFalse);
    });

    test('test_serves_local_and_download_areTheNarrowOnes', () {
      expect(_descriptor(kind: ResolverKind.local).serves(ContentKind.localMedia), isTrue);
      expect(_descriptor(kind: ResolverKind.local).serves(ContentKind.vod), isFalse);
      expect(_descriptor(kind: ResolverKind.download).serves(ContentKind.vod), isTrue);
      expect(_descriptor(kind: ResolverKind.download).serves(ContentKind.stream), isTrue);
      expect(_descriptor(kind: ResolverKind.download).serves(ContentKind.liveChannel), isFalse);
    });

    test('test_serves_playlist_isClaimedByNobody', () {
      // A playlist is a container the source browses, so no resolver kind may claim it implicitly; a host
      // that resolves one has to say which family its items belong to.
      for (final kind in ResolverKind.values) {
        expect(_descriptor(kind: kind).serves(ContentKind.playlist), isFalse, reason: kind.name);
      }
    });
  });

  group('test_resolverDescriptor_jsonAndEquality', () {
    test('test_jsonRoundTrip_preservesIdentityAndPriority', () {
      final descriptor = ResolverDescriptor(
        id: 'huya.live',
        name: 'Huya live',
        kind: ResolverKind.live,
        providerId: 'p1',
        priority: 7,
      );

      final decoded = ResolverDescriptor.fromJson(descriptor.toJson());
      expect(decoded, descriptor);
      expect(decoded.providerId, 'p1');
      expect(decoded.priority, 7);
    });

    test('test_json_omitsDefaults', () {
      expect(_descriptor().toJson(), isNot(contains('priority')));
      expect(_descriptor().toJson(), isNot(contains('providerId')));
    });

    test('test_fromJson_unknownKind_fallsBackToVod', () {
      // A descriptor read from a manifest the model does not know must still parse; silently becoming `vod` is
      // what keeps a renamed provider from taking the whole app down.
      final decoded = ResolverDescriptor.fromJson(<String, Object?>{'id': 'x', 'name': 'X', 'kind': 'karaoke'});
      expect(decoded.kind, ResolverKind.vod);
    });

    test('test_equality_ignoresNameAndProvider', () {
      const full = ResolverDescriptor(id: 'r', name: 'One', kind: ResolverKind.live, providerId: 'a', priority: 3);
      const other = ResolverDescriptor(id: 'r', name: 'Two', kind: ResolverKind.live, providerId: 'b', priority: 3);
      expect(full, other);
      expect(full, isNot(const ResolverDescriptor(id: 'r', name: 'One', kind: ResolverKind.live, priority: 4)));
    });
  });
}
