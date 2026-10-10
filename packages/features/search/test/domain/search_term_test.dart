// Module: test/domain/search_term_test.dart
// Purpose: Pins the fold rule and the refusal of a keyword that carries nothing.
// Author: liuchuancong
// Created: 2026-10-10

import 'package:pure_live_search_feature/pure_live_search_feature.dart';
import 'package:test/test.dart';

void main() {
  test('test_searchTerm_tryParse_foldsCaseAndPaddingForComparison', () {
    final first = SearchTerm.tryParse('  Hello  World ');
    final second = SearchTerm.tryParse('hello    world');
    expect(first, isNotNull);
    expect(first!.sameQuery(second!), isTrue);
    // The display form is what the user wrote, minus outer whitespace only.
    expect(first.display, 'Hello  World');
    expect(first.matchKey, 'hello world');
  });

  test('test_searchTerm_tryParse_refusesBlankWithoutALetter', () {
    expect(SearchTerm.tryParse(''), isNull);
    expect(SearchTerm.tryParse('   '), isNull);
    expect(SearchTerm.tryParse('\t\n'), isNull);
  });

  test('test_searchTerm_foldKeepsNonAsciiIntact', () {
    // Folding is trim + case + whitespace only. A CJK keyword is compared as written, and a full-width Latin
    // letter stays distinct from its half-width twin - width folding would need a normaliser this package
    // refuses to depend on, so the boundary is asserted instead of papered over.
    expect(SearchTerm.tryParse('范  伟')!.matchKey, '范 伟');
    expect(SearchTerm.tryParse('ＡＢ')!.matchKey, isNot(SearchTerm.tryParse('ab')!.matchKey));
  });

  test('test_searchTerm_equalityIsByFoldedKeyNotByDisplay', () {
    expect(SearchTerm.tryParse('abc'), SearchTerm.tryParse('ABC'));
    expect(SearchTerm.tryParse('abc').hashCode, SearchTerm.tryParse('ABC').hashCode);
  });
}
