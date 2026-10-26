import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show ProviderOrFamily;

import 'package:pure_live/app/background/background_settings.dart' show backgroundSettingsProvider;
import 'package:pure_live/app/providers/auto_shutdown_provider.dart' show autoShutdownProvider;
import 'package:pure_live/app/providers/browse_settings_providers.dart'
    show
        browseLayoutProvider,
        browseSettingsProvider,
        favoritesDensityProvider,
        showGotoButtonProvider,
        showPageSizeSelectorProvider,
        showScrollToTopProvider;
import 'package:pure_live/app/providers/display_refresh_rate_provider.dart' show displayRefreshRateProvider;
import 'package:pure_live/app/providers/download_directory_provider.dart' show downloadDirectoryProvider;
import 'package:pure_live/app/providers/dynamic_color_provider.dart'
    show dynamicColorProvider, dynamicColorSeedProvider;
import 'package:pure_live/app/providers/font_face_provider.dart'
    show appFontFaceProvider, danmakuFontFaceProvider;
import 'package:pure_live/app/providers/font_size_provider.dart' show appFontSizesProvider;
import 'package:pure_live/app/providers/keep_screen_on_provider.dart' show keepScreenOnProvider;
import 'package:pure_live/app/providers/loading_style_provider.dart' show loadingColorProvider, loadingStyleProvider;
import 'package:pure_live/app/providers/nav_visibility_providers.dart' show navMenuProvider, showMultiviewProvider;
import 'package:pure_live/app/providers/network_providers.dart' show proxySettingsProvider;
import 'package:pure_live/app/providers/page_size_options_provider.dart' show pageSizeOptionsProvider;
import 'package:pure_live/app/providers/player_backend_providers.dart' show playerKernelBackendProvider;
import 'package:pure_live/app/providers/pure_black_theme_provider.dart' show pureBlackThemeProvider;
import 'package:pure_live/app/providers/refresh_settings_providers.dart'
    show followsAutoRefreshProvider, historyLimitProvider, maxConcurrentRefreshProvider;
import 'package:pure_live/app/providers/settings_sync.dart' show settingsRevisionProvider;
import 'package:pure_live/app/providers/shell_settings_provider.dart'
    show roomWindowsProvider, shellWindowSettingsProvider;
import 'package:pure_live/app/providers/splash_settings_provider.dart' show splashSettingsProvider;
import 'package:pure_live/app/providers/text_scale_provider.dart' show textScaleFactorProvider;
import 'package:pure_live/app/providers/thumbnail_refresh_provider.dart' show thumbnailRefreshProvider;
import 'package:pure_live/app/providers/update_settings_provider.dart' show updateSettingsProvider;
import 'package:pure_live/features/backup/webdav_settings.dart' show webdavSettingsProvider;
import 'package:pure_live/features/favorites/follow_tags.dart' show followTagsProvider;
import 'package:pure_live/features/iptv/iptv_auto_update.dart'
    show iptvAutoSyncProvider, iptvUpdateIntervalProvider;
import 'package:pure_live/features/iptv/iptv_epg_controller.dart' show iptvEpgProvider;
import 'package:pure_live/features/iptv/iptv_user_agent.dart' show iptvUserAgentProvider;
import 'package:pure_live/features/recorder/recording_settings.dart' show recordingSettingsProvider;
import 'package:pure_live/features/room/room_orientation.dart' show roomOrientationChoicesProvider;
import 'package:pure_live/features/search/search_controller.dart' show searchHistoryProvider;
import 'package:pure_live/features/settings/audience_metric_provider.dart'
    show audienceMetricProvider, audiencePolicyProvider;
import 'package:pure_live/features/settings/chat_display_settings.dart'
    show
        chatListFontSizeProvider,
        chatListLineSpacingProvider,
        chatListStyleProvider,
        chatNamesProvider,
        chatShowGiftsProvider;
import 'package:pure_live/features/settings/clipboard_rooms.dart' show detectClipboardRoomsProvider;
import 'package:pure_live/features/settings/danmaku_hold_provider.dart' show danmakuHoldProvider;
import 'package:pure_live/features/settings/danmaku_repeat_provider.dart' show danmakuRepeatProvider;
import 'package:pure_live/features/settings/danmaku_show_gifts_provider.dart' show danmakuShowGiftsProvider;
import 'package:pure_live/features/settings/danmaku_style_providers.dart'
    show
        danmakuFrameRateProvider,
        danmakuLongPressInteractionProvider,
        danmakuPausedBehaviorProvider,
        danmakuStyleProvider,
        danmakuTapInteractionProvider;
import 'package:pure_live/features/settings/floating_window_settings.dart' show floatingWindowSettingsProvider;
import 'package:pure_live/features/settings/local_interaction_settings.dart'
    show localInteractionProvider;
import 'package:pure_live/features/settings/pip_danmaku_scale_provider.dart' show pipDanmakuScaleProvider;
import 'package:pure_live/features/settings/platform_preferences_provider.dart'
    show douyuForceRenewProvider, preferH264Provider, youtubeAllChatProvider;
import 'package:pure_live/features/settings/playback_settings_providers.dart' show playbackSettingsProvider;
import 'package:pure_live/features/settings/player_tuning.dart' show playerProxyProvider, playerTuningProvider;
import 'package:pure_live/features/settings/portrait_fullscreen_settings.dart' show portraitFullscreenProvider;
import 'package:pure_live/features/settings/portrait_settings_providers.dart' show portraitSettingsProvider;
import 'package:pure_live/features/settings/room_card_settings.dart' show roomCardSettingsProvider;
import 'package:pure_live/features/settings/sites_display_provider.dart' show sitesDisplayProvider, sitesOrderProvider;
import 'package:pure_live/features/settings/tv_preferences.dart' show tvMenuExpandedProvider;
import 'package:pure_live/features/settings/twitch_languages_provider.dart' show twitchLanguagesProvider;
import 'package:pure_live/features/shield/danmaku_filter_settings.dart' show danmakuFilterProvider;
import 'package:pure_live/features/shield/shield_repository.dart' show shieldRulesProvider;
import 'package:pure_live/features/vod/vod_settings.dart' show vodQualityProvider;
import 'package:pure_live/shared/enums/tool_order.dart' show toolOrderProvider;
import 'package:pure_live/shared/player/super_resolution.dart' show superResolutionModeProvider;
import 'package:pure_live/shared/rooms/room_visibility.dart' show showUnplayableProvider;

/// Settings providers a window rebuilds after the values changed underneath
/// its controllers. Navigation state (selected module/site/branch) is
/// deliberately absent: windows are independent there.
///
/// Also absent is `windowSizeProvider` — its controller is the window's own
/// size tracker, started once at boot, so a restored `window.width`/
/// `window.height` lands on the next start rather than resizing mid-session.
final List<ProviderOrFamily> kSettingsProviders = [
  playbackSettingsProvider,
  portraitSettingsProvider,
  portraitFullscreenProvider,
  danmakuStyleProvider,
  danmakuFrameRateProvider,
  danmakuTapInteractionProvider,
  danmakuLongPressInteractionProvider,
  danmakuHoldProvider,
  danmakuRepeatProvider,
  chatNamesProvider,
  chatShowGiftsProvider,
  danmakuShowGiftsProvider,
  detectClipboardRoomsProvider,
  chatListStyleProvider,
  chatListFontSizeProvider,
  chatListLineSpacingProvider,
  danmakuPausedBehaviorProvider,
  pipDanmakuScaleProvider,
  floatingWindowSettingsProvider,
  localInteractionProvider,
  shieldRulesProvider,
  danmakuFilterProvider,
  roomOrientationChoicesProvider,
  browseLayoutProvider,
  browseSettingsProvider,
  roomCardSettingsProvider,
  favoritesDensityProvider,
  showUnplayableProvider,
  showPageSizeSelectorProvider,
  showGotoButtonProvider,
  showScrollToTopProvider,
  pageSizeOptionsProvider,
  audienceMetricProvider,
  audiencePolicyProvider,
  toolOrderProvider,
  backgroundSettingsProvider,
  proxySettingsProvider,
  followsAutoRefreshProvider,
  maxConcurrentRefreshProvider,
  thumbnailRefreshProvider,
  downloadDirectoryProvider,
  historyLimitProvider,
  playerKernelBackendProvider,
  playerTuningProvider,
  playerProxyProvider,
  superResolutionModeProvider,
  recordingSettingsProvider,
  followTagsProvider,
  iptvUpdateIntervalProvider,
  iptvAutoSyncProvider,
  iptvUserAgentProvider,
  iptvEpgProvider,
  vodQualityProvider,
  searchHistoryProvider,
  webdavSettingsProvider,
  autoShutdownProvider,
  showMultiviewProvider,
  navMenuProvider,
  sitesDisplayProvider,
  sitesOrderProvider,
  twitchLanguagesProvider,
  tvMenuExpandedProvider,
  youtubeAllChatProvider,
  preferH264Provider,
  douyuForceRenewProvider,
  shellWindowSettingsProvider,
  roomWindowsProvider,
  keepScreenOnProvider,
  displayRefreshRateProvider,
  dynamicColorProvider,
  dynamicColorSeedProvider,
  pureBlackThemeProvider,
  loadingStyleProvider,
  loadingColorProvider,
  splashSettingsProvider,
  textScaleFactorProvider,
  appFontSizesProvider,
  appFontFaceProvider,
  danmakuFontFaceProvider,
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
