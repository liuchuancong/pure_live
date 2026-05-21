enum AppTier { free, pro }

class FeatureGate {
  static AppTier _currentTier = AppTier.pro;

  static AppTier get currentTier => _currentTier;
  static bool get isPro => _currentTier == AppTier.pro;
  static bool get isFree => _currentTier == AppTier.free;

  static void setTier(AppTier tier) => _currentTier = tier;

  // ── Per-feature limits ──

  /// Max providers allowed.
  static int get maxProviders => isPro ? 999 : 2;

  /// Max EPG sources allowed.
  static int get maxEpgSources => isPro ? 20 : 2;

  /// Whether warm failover (background probing) is available.
  static bool get warmFailover => isPro;

  /// Whether multi-view (multi-stream grid) is available.
  static bool get multiView => true; // Free feature

  /// Whether recording to NAS/local is available.
  static bool get recording => isPro;

  /// Whether EPG mapping import/export is available.
  static bool get epgMappingExport => isPro;

  /// Whether community EPG profiles are available.
  static bool get communityProfiles => isPro;

  /// Whether the web companion remote is available.
  static bool get webRemote => isPro;

  /// Whether multi-device sync is available.
  static bool get multiDeviceSync => isPro;

  /// Whether custom channel sort ordering is available.
  static bool get customChannelOrder => isPro;

  /// Check a generic feature by name (for future flexibility).
  static bool isEnabled(String feature) {
    if (isPro) return true;
    // Free-tier features always enabled
    const freeFeatures = {
      'live_playback',
      'cold_failover',
      'multi_view',
      'epg_basic',
      'epg_automapper',
      'm3u_import',
      'xtream_codes',
      'favorites',
      'channel_groups',
      'remote_basic',
    };
    return freeFeatures.contains(feature);
  }
}
