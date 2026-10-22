import 'package:flutter_test/flutter_test.dart';
import 'package:pure_live/system/configuration/preferences/shell_preferences.dart';

/// The shell's own answers travel in the same flat document as every other
/// domain: a field missing from the round trip or from `props` silently
/// returns to its default.
void main() {
  test('the wide bottom bar survives the document', () {
    final stored = const ShellPreferences(homeBottomBarOnWide: true).toJson();
    expect(ShellPreferences.fromJson(stored).homeBottomBarOnWide, isTrue);
    expect(ShellPreferences.fromJson(const {}).homeBottomBarOnWide, isFalse);
  });

  test('copyWith keeps the fields it does not touch', () {
    const before = ShellPreferences(
      restoreLastTab: true,
      shellNavExpanded: false,
      sidebarWidth: 220,
      shellBranches: ['follow', 'popular'],
    );
    final after = before.copyWith(homeBottomBarOnWide: true);
    expect(after.homeBottomBarOnWide, isTrue);
    expect(after.restoreLastTab, isTrue);
    expect(after.shellNavExpanded, isFalse);
    expect(after.sidebarWidth, 220);
    expect(after.shellBranches, ['follow', 'popular']);
  });

  test('props carries the switch, so a write reaches the store', () {
    expect(const ShellPreferences(homeBottomBarOnWide: true), isNot(equals(const ShellPreferences())));
  });
}
