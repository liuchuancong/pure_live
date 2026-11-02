import 'package:pure_live/features/backup/document/backup_settings.dart' show kBackedUpPrefs;

/// One thing the LAN sync can carry: a box of user data, one group of the
/// settings, or the vault. The user picks which of these this device
/// shares, and grants each paired device read and write per scope.
///
/// The ids are the wire names the engine, the change log and the peers'
/// trust records speak; `favorites` keeps the name the first release used.
enum LanSyncScope {
  /// The followed rooms.
  favorites('favorites'),

  /// The followed areas.
  areaFollows('areaFollows'),

  /// The watch history.
  history('history'),

  /// The recording tasks (their setup; a running take syncs as waiting).
  recordings('recordings'),

  /// Theme, background, window and the other appearance prefs.
  settingsAppearance('settings.appearance'),

  /// Playback and player prefs.
  settingsPlayback('settings.playback'),

  /// Danmaku display prefs.
  settingsDanmaku('settings.danmaku'),

  /// Music player prefs.
  settingsMusic('settings.music'),

  /// Recorder prefs.
  settingsRecorder('settings.recorder'),

  /// The modules' prefs: IPTV, Hongguo, VOD, sites, browsing.
  settingsModules('settings.modules'),

  /// The vault: platform cookies, WebDAV passwords. Only offered while the
  /// user's `backup.includeSecrets` switch is on.
  secrets('secrets');

  LanSyncScope(this.id);

  /// The wire id.
  final String id;

  /// Whether this scope is one group of the settings prefs.
  bool get isSettings => id.startsWith('settings.');

  /// Whether this scope is a box of keyed user data.
  bool get isStore => switch (this) {
    favorites || areaFollows || history || recordings => true,
    _ => false,
  };

  /// What this device shares until the user says otherwise: everything
  /// but the vault.
  static const Set<LanSyncScope> defaults = {
    favorites,
    areaFollows,
    history,
    recordings,
    settingsAppearance,
    settingsPlayback,
    settingsDanmaku,
    settingsMusic,
    settingsRecorder,
    settingsModules,
  };

  /// The scope with wire id [id], or null for one this build does not know.
  static LanSyncScope? byId(String id) {
    for (final scope in values) {
      if (scope.id == id) return scope;
    }
    return null;
  }

  /// The pref-key prefixes each settings scope carries. A pref whose prefix
  /// is in none of these — the backup folder, the logs, the proxy, the LAN
  /// sync's own keys — is this device's business and never syncs.
  static const Map<LanSyncScope, Set<String>> _prefixes = {
    settingsAppearance: {
      'theme',
      'background',
      'interface',
      'display',
      'ui',
      'shell',
      'sides',
      'window',
      'nav',
      'app',
      'exit',
      'tools',
      'search',
      'updates',
    },
    settingsPlayback: {'playback', 'player', 'room', 'refresh'},
    settingsDanmaku: {'danmaku'},
    settingsMusic: {'music'},
    settingsRecorder: {'recorder'},
    settingsModules: {'iptv', 'hongguo', 'vod', 'sites', 'browse', 'areas', 'follow', 'history', 'cache'},
  };

  /// The settings scope a pref [key] belongs to, or null when it is this
  /// device's own.
  static LanSyncScope? ofPrefKey(String key) {
    final prefix = key.split('.').first;
    for (final entry in _prefixes.entries) {
      if (entry.value.contains(prefix)) return entry.key;
    }
    return null;
  }

  /// The backed-up pref keys this settings scope carries, in manifest
  /// order; empty for a non-settings scope.
  List<String> get prefKeys => [
    for (final (key, _) in kBackedUpPrefs)
      if (ofPrefKey(key) == this) key,
  ];
}

/// Parses the stored scope ids, dropping the unknown; an absent list means
/// the defaults.
Set<LanSyncScope> lanSyncScopesFrom(List<String>? ids) {
  if (ids == null) return LanSyncScope.defaults;
  return {for (final id in ids) ?LanSyncScope.byId(id)};
}
