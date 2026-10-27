import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show ProviderOrFamily;
import 'package:pure_live/app/background/settings/background_settings.dart' show backgroundSettingsProvider;
import 'package:pure_live/app/providers/browse/browse_settings_providers.dart'
    show browseLayoutProvider, browseSettingsProvider;
import 'package:pure_live/app/providers/browse/refresh_settings_providers.dart'
    show followsAutoRefreshProvider, historyLimitProvider, maxConcurrentRefreshProvider;
import 'package:pure_live/app/providers/browse/thumbnail_refresh_provider.dart' show thumbnailRefreshProvider;
import 'package:pure_live/app/providers/device/auto_shutdown_provider.dart' show autoShutdownProvider;
import 'package:pure_live/app/providers/device/display_refresh_rate_provider.dart'
    show displayRefreshRateProvider, matchVideoFrameRateProvider;
import 'package:pure_live/app/providers/device/keep_screen_on_provider.dart' show keepScreenOnProvider;
import 'package:pure_live/app/providers/navigation/nav_visibility_providers.dart'
    show navMenuProvider, showMultiviewProvider;
import 'package:pure_live/app/providers/network/network_providers.dart' show proxySettingsProvider;
import 'package:pure_live/app/providers/player/player_backend_providers.dart' show playerKernelBackendProvider;
import 'package:pure_live/app/providers/settings/download_directory_provider.dart' show downloadDirectoryProvider;
import 'package:pure_live/app/providers/settings/settings_sync.dart' show settingsRevisionProvider;
import 'package:pure_live/app/providers/settings/shell_settings_provider.dart'
    show roomWindowsProvider, shellWindowSettingsProvider;
import 'package:pure_live/app/providers/settings/splash_settings_provider.dart' show splashSettingsProvider;
import 'package:pure_live/app/providers/settings/update_settings_provider.dart' show updateSettingsProvider;
import 'package:pure_live/app/providers/theme/dynamic_color_provider.dart'
    show dynamicColorProvider, dynamicColorSeedProvider;
import 'package:pure_live/app/providers/theme/font_face_provider.dart'
    show appFontFaceProvider, danmakuFontFaceProvider;
import 'package:pure_live/app/providers/theme/liquid_glass_provider.dart' show liquidGlassProvider;
import 'package:pure_live/app/providers/theme/text_scale_provider.dart' show textScaleFactorProvider;
import 'package:pure_live/features/account/douyu_cookie_saved_at.dart' show douyuCookieSavedAtProvider;
import 'package:pure_live/features/backup/backup.dart';
import 'package:pure_live/features/favorites/favorites.dart';
import 'package:pure_live/features/iptv/iptv.dart';

import 'package:pure_live/features/recorder/recorder.dart';
import 'package:pure_live/features/room/room.dart';
import 'package:pure_live/features/search/search.dart';
import 'package:pure_live/features/settings/settings.dart';
import 'package:pure_live/features/shield/shield.dart';
import 'package:pure_live/features/vod/vod.dart';
import 'package:pure_live/shared/shared.dart';

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
  chatGiftsAboveTierProvider,
  chatGiftValueInYuanProvider,
  superChatIncludesMembershipProvider,
  danmakuShowGiftsProvider,
  detectClipboardRoomsProvider,
  chatListStyleProvider,
  chatListFontSizeProvider,
  chatListLineSpacingProvider,
  danmakuPausedBehaviorProvider,
  pipDanmakuScaleProvider,
  floatingWindowSettingsProvider,
  shieldRulesProvider,
  danmakuFilterProvider,
  roomOrientationChoicesProvider,
  browseLayoutProvider,
  browseSettingsProvider,
  roomCardSettingsProvider,
  roomSwitcherLayoutProvider,
  portraitSwipeSwitchProvider,
  showUnplayableProvider,
  audienceMetricProvider,
  audiencePolicyProvider,
  toolOrderProvider,
  backgroundSettingsProvider,
  proxySettingsProvider,
  followsAutoRefreshProvider,
  liveAlertSettingsProvider,
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
  webdavAccountsProvider,
  autoShutdownProvider,
  showMultiviewProvider,
  navMenuProvider,
  sitesDisplayProvider,
  sitesOrderProvider,
  twitchLanguagesProvider,
  tvMenuExpandedProvider,
  tvFocusZoomProvider,
  youtubeAllChatProvider,
  preferH264Provider,
  douyuForceRenewProvider,
  douyuCookieSavedAtProvider,
  shellWindowSettingsProvider,
  roomWindowsProvider,
  keepScreenOnProvider,
  displayRefreshRateProvider,
  matchVideoFrameRateProvider,
  dynamicColorProvider,
  dynamicColorSeedProvider,
  liquidGlassProvider,
  splashSettingsProvider,
  textScaleFactorProvider,
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
