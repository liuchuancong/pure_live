// Module: test/identity_test.dart
// Purpose: Verify identity merges only on evidence, never guesses, and can be confirmed once and remembered.
// Author: liuchuancong
// Created: 2026-10-09
//
// Spec: docs/content/content-identity.md - priority is the authoritative number, then the fuzzy match with a
// configurable threshold; "置信度不足时不强并"; "历史/收藏以用户首次使用的 ContentRef 为主键,identity 作为换源索引".
import 'dart:io';

import 'package:pure_live_identity/pure_live_identity.dart';
import 'package:pure_live_platform/pure_live_platform.dart';
import 'package:pure_live_storage/pure_live_storage.dart';
import 'package:test/test.dart';

ContentRef _ref(String sourceId, String contentId, {ContentKind kind = ContentKind.music}) =>
    ContentRef(sourceId: sourceId, contentId: contentId, kind: kind);

IdentityFacts _facts(
  String title, {
  String? creator,
  String? collection,
  Duration? duration,
  Map<String, String> ids = const <String, String>{},
}) {
  return IdentityFacts(title: title, creator: creator, collection: collection, duration: duration, authoritative: ids);
}

ContentSummary _summary(String title, {Map<String, Object?> extra = const <String, Object?>{}}) => ContentSummary(
  ref: _ref('s', 'c'),
  title: title,
  metadata: ContentMetadata(extra: extra),
);

final IdentityMatcher _matcher = const IdentityMatcher();

void main() {
  group('test_matcher_authoritative', () {
    test('test_compare_sameIsrc_isSameEvenIfEverythingElseDisagrees', () {
      final match = _matcher.compare(
        _facts('First Take', ids: const <String, String>{'isrc': 'USMT12345678'}),
        _facts(
          '第一take!!',
          creator: 'Someone Else',
          duration: const Duration(minutes: 9),
          ids: const <String, String>{'isrc': 'USMT12345678'},
        ),
      );

      expect(match.isSame, isTrue);
      expect(match.confidence, 1);
    });

    test('test_compare_differentIsrc_isDifferentEvenForAnIdenticalTitle', () {
      // This is the outranking rule: two recordings of the same composition carry the same title and
      // different numbers, and a fuzzy match must not merge them.
      final match = _matcher.compare(
        _facts('Same Song', ids: const <String, String>{'isrc': 'AAA111'}),
        _facts('Same Song', ids: const <String, String>{'isrc': 'BBB222'}),
      );

      expect(match.decision, IdentityDecision.different);
      expect(match.reason, contains('isrc differs'));
    });

    test('test_compare_idsFromDifferentSchemesSayNothing', () {
      final match = _matcher.compare(
        _facts('Song', ids: const <String, String>{'isrc': 'AAA111'}),
        _facts('Song', creator: 'X', ids: const <String, String>{'tmdb': '42'}),
      );

      // No shared scheme means no number-based answer, and one agreed field is not an identity.
      expect(match.decision, isNot(IdentityDecision.same));
      expect(match.reason, isNot(contains('differs')));
    });
  });

  group('test_matcher_fuzzy', () {
    test('test_compare_titleCreatorDurationAgree_isSame', () {
      final match = _matcher.compare(
        _facts('Never Gonna Give You Up (Live)', creator: 'Rick Astley', duration: const Duration(seconds: 213)),
        _facts('never gonna give you up - live', creator: 'rick astley', duration: const Duration(seconds: 213)),
      );

      expect(match.isSame, isTrue, reason: match.reason);
    });

    test('test_normalize_dropsPunctuationAndCaseButKeepsCjkAndDigits', () {
      expect(IdentityMatcher.normalize('A-B c!! 123'), 'abc123');
      expect(IdentityMatcher.normalize('  周杰伦 Jay '), '周杰伦jay');
      expect(IdentityMatcher.normalize('歌手《歌曲》'), '歌手歌曲');
    });

    test('test_compare_titleAlone_canNeverMerge', () {
      // The rule this whole layer exists for: two sources that both say "Call Me" and nothing else are two
      // candidate rows for the user, never one automatic identity.
      final match = _matcher.compare(_facts('Call Me'), _facts('Call Me'));

      expect(match.decision, IdentityDecision.candidate);
      expect(match.reason, contains('only one field was comparable'));
    });

    test('test_compare_differentTitles_areDifferent', () {
      expect(
        _matcher.compare(_facts('Alpha', creator: 'X'), _facts('Beta', creator: 'X')).decision,
        IdentityDecision.different,
      );
    });

    test('test_compare_creatorDisagreement_isACandidateNotAMerge', () {
      final match = _matcher.compare(_facts('Song', creator: 'A'), _facts('Song', creator: 'B'));

      expect(match.decision, IdentityDecision.candidate);
      expect(match.confidence, lessThan(const IdentityPolicy().autoMergeConfidence));
    });

    test('test_compare_durationOutsideTolerance_canNeverAutoMerge', () {
      // Length disagreement is what an edit, a live version or a different cut looks like; averaging it away
      // would merge two different recordings that share a title and an artist.
      final match = _matcher.compare(
        _facts('Song', creator: 'X', collection: 'Album', duration: const Duration(minutes: 3)),
        _facts('Song', creator: 'X', collection: 'Album', duration: const Duration(minutes: 5)),
      );

      expect(match.decision, isNot(IdentityDecision.same));
      expect(match.reason, contains('duration disagrees'));
    });

    test('test_policyThresholds_areTheOnlyVariables', () {
      const loose = IdentityPolicy(autoMergeConfidence: 0.5, candidateConfidence: 0.2);
      final facts = <IdentityFacts>[_facts('Song', creator: 'A'), _facts('Song', creator: 'B')];

      expect(const IdentityMatcher().compare(facts[0], facts[1]).decision, IdentityDecision.candidate);
      expect(const IdentityMatcher(loose).compare(facts[0], facts[1]).decision, IdentityDecision.same);
    });
  });

  group('test_facts_serialisation', () {
    test('test_from_readsTheAuthoritativeNumbersOutOfMetadata', () {
      final facts = IdentityFacts.from(_summary('Song', extra: const <String, Object?>{'isrc': ' USX99 '}));

      expect(facts.authoritative, <String, String>{'isrc': 'USX99'});
    });

    test('test_jsonRoundTrip_isExact', () {
      final original = _facts(
        'Song',
        creator: 'X',
        collection: 'Album',
        duration: const Duration(seconds: 30),
        ids: const <String, String>{'bvid': 'BV1'},
      );

      final decoded = IdentityFacts.fromJson(original.toJson());

      expect(decoded.title, 'Song');
      expect(decoded.creator, 'X');
      expect(decoded.collection, 'Album');
      expect(decoded.duration, const Duration(seconds: 30));
      expect(decoded.authoritative, <String, String>{'bvid': 'BV1'});
    });
  });

  group('test_index', () {
    late MemoryKeyValueStore store;
    late IdentityIndex index;

    setUp(() {
      store = MemoryKeyValueStore();
      index = IdentityIndex(store: KeyValueIdentityStore(store));
    });

    test('test_register_sameIsrcFromTwoSources_indexesThemTogether', () async {
      final a = _facts('Song', ids: const <String, String>{'isrc': 'S1'});
      final b = _facts('另一版本', ids: const <String, String>{'isrc': 'S1'});

      final first = await index.register(_ref('bili', '1'), a);
      final second = await index.register(_ref('netease', '99'), b);

      expect(first.merged, isTrue);
      expect(second.identityId, first.identityId);
      expect((await index.alternatives(_ref('bili', '1'))).single.sourceId, 'netease');
    });

    test('test_register_certainFuzzyMatch_mergesWithoutAsking', () async {
      await index.register(_ref('bili', '1'), _facts('Song', creator: 'X', duration: const Duration(seconds: 200)));

      final second = await index.register(
        _ref('qq', '2'),
        _facts('SONG!', creator: 'x', duration: const Duration(seconds: 200)),
      );

      expect(second.merged, isTrue);
      expect(second.candidates, isEmpty);
    });

    test('test_register_uncertainMatch_keepsItsOwnIdentityAndOffersCandidates', () async {
      final lead = _ref('bili', '1');
      await index.register(lead, _facts('Song', creator: 'X'));

      final second = await index.register(_ref('qq', '2'), _facts('Song', creator: 'Y'));

      expect(second.merged, isFalse);
      expect(second.needsConfirmation, isTrue);
      expect(second.candidates.single.representative, lead);
      // Rule 3: the identity of something with no number is the first reference the user used.
      expect(second.identityId, IdentityIndex.refKey(_ref('qq', '2')));
      expect(await index.alternatives(_ref('qq', '2')), isEmpty);
    });

    test('test_confirm_mergesOnceAndTheAnswerIsRemembered', () async {
      final first = _ref('bili', '1');
      final second = _ref('qq', '2');
      await index.register(first, _facts('Song', creator: 'X'));
      final registered = await index.register(second, _facts('Song', creator: 'Y'));
      expect(registered.merged, isFalse, reason: 'two artists, one title: ask, do not merge');

      await index.confirm(first, second);

      expect((await index.alternatives(first)).single, second);
      expect((await index.alternatives(second)).single, first);

      // A third record that agrees with neither artist is still its own question: the confirmation merged
      // two references, it did not certify a title as an identity.
      final third = await index.register(_ref('netease', '3'), _facts('Song', creator: 'Z'));
      expect(third.merged, isFalse);
      expect(third.candidates.map((c) => c.identityId), contains(IdentityIndex.refKey(first)));
    });

    test('test_alternatives_neverReturnTheAskedRefAndKeepExactRefs', () async {
      final a = _ref('bili', '1', kind: ContentKind.music);
      final b = _ref('qq', '2', kind: ContentKind.album);
      await index.register(a, _facts('Song', ids: const <String, String>{'isrc': 'S'}));
      await index.register(b, _facts('Song', ids: const <String, String>{'isrc': 'S'}));

      final others = await index.alternatives(a);

      // The stored ref comes back whole: kind and source id are not reconstructed from a string key.
      expect(others, <ContentRef>[b]);
      expect(others.single.kind, ContentKind.album);
    });

    test('test_register_theSameRefTwice_doesNotDuplicateMembership', () async {
      final ref = _ref('bili', '1');
      await index.register(ref, _facts('Song'));
      await index.register(ref, _facts('Song'));

      expect(await index.membersOf(IdentityIndex.refKey(ref)), hasLength(1));
    });

    test('test_identity_survivesAStoreReopen', () async {
      final path = '${Directory.systemTemp.createTempSync('identity').path}${Platform.pathSeparator}identity.json';
      final first = IdentityIndex(store: KeyValueIdentityStore(FileKeyValueStore(filePath: path)));
      await first.register(_ref('bili', '1'), _facts('Song', ids: const <String, String>{'isrc': 'S9'}));

      final reopened = IdentityIndex(store: KeyValueIdentityStore(FileKeyValueStore(filePath: path)));
      final second = await reopened.register(
        _ref('qq', '2'),
        _facts('Whatever', ids: const <String, String>{'isrc': 'S9'}),
      );

      expect(second.merged, isTrue);
      expect(await reopened.alternatives(_ref('bili', '1')), hasLength(1));
    });
  });
}
