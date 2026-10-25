import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show ProviderOrFamily;

import 'package:pure_live/app/background/background_settings.dart' show backgroundSettingsProvider;
import 'package:pure_live/app/providers/browse_settings_providers.dart'
    show browseLayoutProvider, browseSettingsProvider, favoritesDensityProvider;
import 'package:pure_live/app/providers/display_refresh_rate_provider.dart' show displayRefreshRateProvider;
import 'package:pure_live/app/providers/dynamic_color_provider.dart'
    show dynamicColorProvider, dynamicColorSeedProvider;
import 'package:pure_live/app/providers/keep_screen_on_provider.dart' show keepScreenOnProvider;
import 'package:pure_live/app/providers/loading_style_provider.dart' show loadingColorProvider, loadingStyleProvider;
import 'package:pure_live/app/providers/nav_visibility_providers.dart' show showMultiviewProvider;
import 'package:pure_live/app/providers/network_providers.dart' show proxySettingsProvider;
import 'package:pure_live/app/providers/player_backend_providers.dart' show playerKernelBackendProvider;
import 'package:pure_live/app/providers/refresh_settings_providers.dart'
    show followsAutoRefreshProvider, historyLimitProvider, maxConcurrentRefreshProvider;
import 'package:pure_live/app/providers/settings_sync.dart' show settingsRevisionProvider;
import 'package:pure_live/app/providers/shell_settings_provider.dart'
    show roomWindowsProvider, shellWindowSettingsProvider;
import 'package:pure_live/app/providers/splash_settings_provider.dart' show splashSettingsProvider;
import 'package:pure_live/app/providers/text_scale_provider.dart' show textScaleFactorProvider;
import 'package:pure_live/app/providers/thumbnail_refresh_provider.dart' show thumbnailRefreshProvider;
import 'package:pure_live/app/providers/update_settings_provider.dart' show updateSettingsProvider;
import 'package:pure_live/features/favorites/follow_tags.dart' show followTagsProvider;
import 'package:pure_live/features/iptv/iptv_auto_update.dart' show iptvUpdateIntervalProvider;
import 'package:pure_live/features/iptv/iptv_user_agent.dart' show iptvUserAgentProvider;
import 'package:pure_live/features/recorder/recording_settings.dart' show recordingSettingsProvider;
import 'package:pure_live/features/room/room_orientation.dart' show roomOrientationChoicesProvider;
import 'package:pure_live/features/settings/audience_metric_provider.dart' show audienceMetricProvider;
import 'package:pure_live/features/settings/danmaku_style_providers.dart' show danmakuStyleProvider;
import 'package:pure_live/features/settings/playback_settings_providers.dart' show playbackSettingsProvider;
import 'package:pure_live/features/settings/player_tuning.dart' show playerProxyProvider, playerTuningProvider;
import 'package:pure_live/features/settings/sites_display_provider.dart' show sitesDisplayProvider, sitesOrderProvider;
import 'package:pure_live/features/shield/shield_repository.dart' show shieldRulesProvider;
import 'package:pure_live/features/vod/vod_settings.dart' show vodQualityProvider;
import 'package:pure_live/shared/enums/tool_order.dart' show toolOrderProvider;
import 'package:pure_live/shared/player/super_resolution.dart' show superResolutionModeProvider;

/// Settings providers a window rebuilds after the values changed underneath
/// its controllers. Navigation state (selected module/site/branch) is
/// deliberately absent: windows are independent there.
final List<ProviderOrFamily> kSettingsProviders = [
  playbackSettingsProvider,
  danmakuStyleProvider,
  shieldRulesProvider,
  roomOrientationChoicesProvider,
  browseLayoutProvider,
  browseSettingsProvider,
  favoritesDensityProvider,
  audienceMetricProvider,
  toolOrderProvider,
  backgroundSettingsProvider,
  proxySettingsProvider,
  followsAutoRefreshProvider,
  maxConcurrentRefreshProvider,
  thumbnailRefreshProvider,
  historyLimitProvider,
  playerKernelBackendProvider,
  playerTuningProvider,
  playerProxyProvider,
  superResolutionModeProvider,
  recordingSettingsProvider,
  followTagsProvider,
  iptvUpdateIntervalProvider,
  iptvUserAgentProvider,
  vodQualityProvider,
  showMultiviewProvider,
  sitesDisplayProvider,
  sitesOrderProvider,
  shellWindowSettingsProvider,
  roomWindowsProvider,
  keepScreenOnProvider,
  displayRefreshRateProvider,
  dynamicColorProvider,
  dynamicColorSeedProvider,
  loadingStyleProvider,
  loadingColorProvider,
  splashSettingsProvider,
  textScaleFactorProvider,
  updateSettingsProvider,
];

/// Marks the settings revision and rebuilds every cached settings provider.
///
/// Call after a change made by another window, or by a writer that bypasses
/// the controllers (a backup restore): the controllers must read the new
/// values. A controller that just wrote its own change does not need this.
void refreshSettings(Ref ref) {
  ref.read(settingsRevisionProvider.notifier).bump();
  for (final provider in kSettingsProviders) {
    try {
      ref.invalidate(provider);
    } on Object {
      // A provider that is not alive has nothing to rebuild.
    }
  }
}

/// [refreshSettings] from a widget, for actions whose writes bypass the
/// settings controllers — a restored backup, above all.
void refreshSettingsFromWidget(WidgetRef ref) {
  ref.read(settingsRevisionProvider.notifier).bump();
  for (final provider in kSettingsProviders) {
    try {
      ref.invalidate(provider);
    } on Object {
      // A provider that is not alive has nothing to rebuild.
    }
  }
}
