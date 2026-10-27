import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pure_live/features/settings/settings.dart';

/// The settings section on screen: the shell's sidebar shows the sections
/// as its own menu while the settings destination is selected, and the
/// settings page renders this one beside it.
///
/// One provider rather than the page's own state, because the menu and the
/// pane live on opposite sides of the shell now — the sidebar picks, the
/// page follows.
final class SettingsSectionController extends Notifier<SettingsSection> {
  @override
  SettingsSection build() => SettingsSection.theme;

  /// The section the shell is showing.
  SettingsSection get section => state;

  /// Moves the selection; the settings page rebuilds its pane.
  set section(SettingsSection value) => state = value;

  /// Keeps the selection inside [sections]: a module switch may leave the
  /// surface on a section that module's settings does not carry (IPTV has
  /// no Sites section, for one), and the pane must never point at a menu row that
  /// is not there.
  void ensureWithin(Iterable<SettingsSection> sections) {
    if (!sections.contains(state)) {
      state = sections.first;
    }
  }
}

/// The selected settings section.
final settingsSectionProvider = NotifierProvider<SettingsSectionController, SettingsSection>(
  SettingsSectionController.new,
);

/// The settings category on screen: the desktop sidebar and the phone's
/// settings page list these first, and a category's page lists its sections.
final class SettingsCategoryController extends Notifier<String> {
  @override
  String build() => kSettingsDefaultGroupKey;

  /// The group key the surface is on.
  String get categoryKey => state;

  /// Selects a category; the surface shows its page.
  set categoryKey(String value) => state = value;

  /// Keeps the category inside [groups]: a module switch may not carry the
  /// last one. IPTV has no live group, for one.
  void ensureWithin(Iterable<SettingsGroup> groups) {
    final keys = [for (final group in groups) group.labelKey];
    if (keys.contains(state)) return;
    state = keys.isEmpty ? kSettingsDefaultGroupKey : keys.first;
  }
}

/// The selected settings category.
final settingsCategoryProvider = NotifierProvider<SettingsCategoryController, String>(SettingsCategoryController.new);

/// Whether the settings surface is showing a section below its category:
/// false means the category's own page, true one of its section pages.
final class SettingsSectionOpenController extends Notifier<bool> {
  @override
  bool build() => false;

  /// Whether a section page is open below the category.
  bool get open => state;

  set open(bool value) => state = value;
}

/// Whether a settings section page is open.
final settingsSectionOpenProvider = NotifierProvider<SettingsSectionOpenController, bool>(
  SettingsSectionOpenController.new,
);
