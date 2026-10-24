import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:pure_live/features/settings/settings_sections.dart' show SettingsSection;

/// The settings section on screen: the shell's sidebar shows the sections
/// as its own menu while the settings destination is selected, and the
/// settings page renders this one beside it.
///
/// One provider rather than the page's own state, because the menu and the
/// pane live on opposite sides of the shell now — the sidebar picks, the
/// page follows.
final class SettingsSectionController extends Notifier<SettingsSection> {
  @override
  SettingsSection build() => SettingsSection.general;

  /// The section the shell is showing.
  SettingsSection get section => state;

  /// Moves the selection; the settings page rebuilds its pane.
  set section(SettingsSection value) => state = value;

  /// Keeps the selection inside [sections]: a module switch may leave the
  /// surface on a section that module's settings does not carry (IPTV has
  /// no 站点, for one), and the pane must never point at a menu row that
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
