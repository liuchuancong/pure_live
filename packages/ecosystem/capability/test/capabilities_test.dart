// Module: test/capabilities_test.dart
// Purpose: Verify the capability vocabulary and the declaration set a source reports at registration.
// Author: liuchuancong
// Created: 2026-10-08
import 'package:pure_live_capability/pure_live_capability.dart';
import 'package:test/test.dart';

void main() {
  test('test_capabilityKind_names_coverEveryDocumentedCapability', () {
    // docs/contracts/capability-contract.md section 1 names these; docs/architecture/evolution.md forbids
    // renaming or reordering an enum once it ships, so the list is asserted as a set.
    expect(CapabilityKind.values.map((kind) => kind.name).toSet(), <String>{
      'live',
      'vod',
      'music',
      'iptv',
      'search',
      'feed',
      'danmaku',
      'subtitle',
      'lyric',
      'comment',
      'chapter',
      'quality',
      'line',
      'history',
      'favorite',
      'playlist',
      'metadata',
      'recommendation',
      'auth',
      'account',
      'epg',
      'repository',
    });
  });

  test('test_capabilitySet_supports_undeclaredKind_returnsFalse', () {
    const set = CapabilitySet(<CapabilityKind>{CapabilityKind.live});
    expect(set.supports(CapabilityKind.live), isTrue);
    expect(set.supports(CapabilityKind.music), isFalse);
  });

  test('test_capabilitySet_empty_supportsNothing', () {
    expect(const CapabilitySet.empty().kinds, isEmpty);
  });

  test('test_capabilitySet_withKind_leavesTheOriginalUntouched', () {
    const original = CapabilitySet(<CapabilityKind>{CapabilityKind.live});
    final widened = original.withKind(CapabilityKind.search);

    expect(original.kinds, <CapabilityKind>{CapabilityKind.live});
    expect(widened.kinds, <CapabilityKind>{CapabilityKind.live, CapabilityKind.search});
  });

  test('test_capabilitySet_jsonRoundTrip_preservesKinds', () {
    const set = CapabilitySet(<CapabilityKind>{CapabilityKind.vod, CapabilityKind.feed});

    final decoded = CapabilitySet.fromJson(set.toJson());

    expect(decoded.kinds, set.kinds);
    expect((set.toJson()['kinds']! as List).toSet(), <String>{'vod', 'feed'});
  });

  test('test_capabilitySet_fromJson_ignoresUnknownAndMissingNames', () {
    // A newer plugin may name a kind this build does not have yet; that must not fail registration.
    final set = CapabilitySet.fromJson(<String, Object?>{
      'kinds': <Object?>['live', 'hologram', 42],
    });

    expect(set.kinds, <CapabilityKind>{CapabilityKind.live});
    expect(const CapabilitySet.empty().toJson(), <String, Object?>{'kinds': <String>[]});
  });

  test('test_capabilitySet_fromJson_missingKey_returnsEmptySet', () {
    expect(CapabilitySet.fromJson(<String, Object?>{}).kinds, isEmpty);
  });

  test('test_capabilitySet_toString_listsKindsForLogs', () {
    const set = CapabilitySet(<CapabilityKind>{CapabilityKind.live, CapabilityKind.search});
    expect('$set', contains('live'));
    expect('$set', contains('search'));
  });
}
