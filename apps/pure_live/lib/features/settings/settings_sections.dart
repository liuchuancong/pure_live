import 'package:desen_ui/desen_ui.dart';

import 'package:pure_live/l10n/translations.dart';

/// The settings surface's pages, in ZCode's order: a grouped list on the
/// left (desktop) or a pushed submenu (mobile), one pane of content per
/// entry on the right.
enum SettingsSection {
  general(DsIcons.settings),
  appearance(DsIcons.palette),
  network(DsIcons.globe),
  playback(DsIcons.play),
  shield(DsIcons.shield),
  sites(DsIcons.antenna),
  data(DsIcons.database),
  about(DsIcons.info);

  SettingsSection(this.icon);

  /// The entry's icon.
  final DsIconData icon;

  /// The entry's name.
  String label(Translations t) => switch (this) {
    SettingsSection.general => t.settings.navGeneral,
    SettingsSection.appearance => t.settings.navAppearance,
    SettingsSection.playback => t.settings.navPlayback,
    SettingsSection.shield => t.settings.navShield,
    SettingsSection.network => t.settings.navNetwork,
    SettingsSection.sites => t.settings.navSites,
    SettingsSection.data => t.settings.navData,
    SettingsSection.about => t.settings.navAbout,
  };

  /// One line on what the section manages.
  String description(Translations t) => switch (this) {
    SettingsSection.general => t.settings.generalDescription,
    SettingsSection.appearance => t.settings.appearanceDescription,
    SettingsSection.playback => t.settings.playbackDescription,
    SettingsSection.shield => t.settings.shieldDescription,
    SettingsSection.network => t.settings.networkDescription,
    SettingsSection.sites => t.settings.sitesDescription,
    SettingsSection.data => t.settings.dataDescription,
    SettingsSection.about => t.settings.aboutDescription,
  };

  /// Parses the route's segment; null when it names nothing.
  static SettingsSection? of(String name) {
    for (final section in SettingsSection.values) {
      if (section.name == name) return section;
    }
    return null;
  }
}

/// The navigation's groups, top to bottom: (slang key of the group label,
/// its sections). Group labels resolve through the settings namespace.
const List<(String, List<SettingsSection>)> kSettingsGroups = [
  ('groupBasics', [SettingsSection.general, SettingsSection.appearance, SettingsSection.network, SettingsSection.playback, SettingsSection.shield]),
  ('groupContent', [SettingsSection.sites]),
  ('groupData', [SettingsSection.data]),
  ('groupAbout', [SettingsSection.about]),
];

/// A group label's words.
String settingsGroupLabel(Translations t, String key) => switch (key) {
  'groupBasics' => t.settings.groupBasics,
  'groupContent' => t.settings.groupContent,
  'groupData' => t.settings.groupData,
  'groupAbout' => t.settings.groupAbout,
  _ => key,
};
