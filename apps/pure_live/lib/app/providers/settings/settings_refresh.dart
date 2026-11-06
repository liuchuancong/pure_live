import 'package:flutter/scheduler.dart' show SchedulerBinding, SchedulerPhase;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show ProviderOrFamily;
import 'package:pure_live/app/background/library/wallpaper_download_queue.dart' show wallpaperDownloadsProvider;
import 'package:pure_live/app/background/settings/background_settings.dart' show backgroundSettingsProvider;
import 'package:pure_live/app/providers/boot/storage_providers.dart' show storageFolderOverridesProvider;
import 'package:pure_live/app/providers/browse/browse_settings_providers.dart'
    show browseLayoutProvider, browseSettingsProvider;
import 'package:pure_live/app/providers/browse/refresh_settings_providers.dart'
    show followsAutoRefreshProvider, historyLimitProvider, maxConcurrentRefreshProvider;
import 'package:pure_live/app/providers/browse/thumbnail_refresh_provider.dart' show thumbnailRefreshProvider;
import 'package:pure_live/app/providers/cache/cache.dart' show liveCacheSettingsProvider;
import 'package:pure_live/app/providers/device/auto_shutdown_provider.dart' show autoShutdownProvider;
import 'package:pure_live/app/providers/device/display_refresh_rate_provider.dart'
    show displayRefreshRateProvider, matchVideoFrameRateProvider;
import 'package:pure_live/app/providers/device/keep_screen_on_provider.dart' show keepScreenOnProvider;
import 'package:pure_live/app/providers/navigation/nav_visibility_providers.dart' show navMenuProvider;
import 'package:pure_live/app/providers/network/github_mirror_provider.dart' show githubMirrorProvider;
import 'package:pure_live/app/providers/network/network_providers.dart' show proxySettingsProvider;
import 'package:pure_live/app/providers/player/player_backend_providers.dart' show playerKernelBackendProvider;
import 'package:pure_live/app/providers/settings/log_settings_provider.dart' show logSettingsProvider;
import 'package:pure_live/app/providers/settings/settings_sync.dart' show settingsRevisionProvider;
import 'package:pure_live/app/providers/settings/shell_settings_provider.dart'
    show roomWindowsProvider, shellWindowSettingsProvider;
import 'package:pure_live/app/providers/settings/splash_settings_provider.dart' show splashSettingsProvider;
import 'package:pure_live/app/providers/settings/update_settings_provider.dart' show updateSettingsProvider;
import 'package:pure_live/app/providers/theme/dynamic_color_provider.dart'
    show dynamicColorProvider, dynamicColorSeedProvider;
import 'package:pure_live/app/providers/theme/text_scale_provider.dart' show textScaleFactorProvider;
import 'package:pure_live/features/account/douyu_cookie_saved_at.dart' show douyuCookieSavedAtProvider;
import 'package:pure_live/features/backup/backup.dart';
import 'package:pure_live/features/settings/settings.dart';
import 'package:pure_live/modules/hongguo/controller/hongguo_card_settings.dart' show hongguoCardSettingsProvider;
import 'package:pure_live/modules/hongguo/hongguo.dart';
import 'package:pure_live/modules/iptv/iptv.dart';
import 'package:pure_live/modules/live/areas/controllers/areas_controller.dart' show areaLayoutProvider;
import 'package:pure_live/modules/live/favorites/favorites.dart';
import 'package:pure_live/modules/live/recorder/recorder.dart';
import 'package:pure_live/modules/live/room/room.dart';
import 'package:pure_live/modules/live/search/search.dart';
import 'package:pure_live/modules/live/search/search_scope.dart' show searchExcludedProvider;
import 'package:pure_live/modules/live/shield/shield.dart';
import 'package:pure_live/modules/music/controller/eq/music_eq_config.dart' show musicEqProvider;
import 'package:pure_live/modules/music/controller/eq/music_eq_custom_presets.dart' show musicCustomPresetsProvider;
import 'package:pure_live/modules/music/controller/music_open_api.dart'
    show musicOpenApiGateProvider, musicOpenApiLanProvider, musicOpenApiPortProvider;
import 'package:pure_live/modules/music/controller/music_source_swaps.dart' show musicSourceSwapsProvider;
import 'package:pure_live/modules/music/controller/music_sync_server.dart'
    show
        musicSyncServerAuthCodeProvider,
        musicSyncServerGateProvider,
        musicSyncServerLanProvider,
        musicSyncServerPortProvider,
        musicSyncServerStatusProvider;
import 'package:pure_live/modules/music/controller/music_ui_settings.dart'
    show musicPlayerModeProvider, musicUiSettingsProvider;
import 'package:pure_live/modules/music/music.dart';
import 'package:pure_live/modules/vod/vod.dart';
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
  portraitLayoutModeProvider,
  danmakuStyleProvider,
  danmakuFrameRateProvider,
  danmakuFixedTopProvider,
  danmakuFixedBottomProvider,
  danmakuFixedDurationProvider,
  danmakuTapInteractionProvider,
  danmakuLongPressInteractionProvider,
  danmakuHoldProvider,
  danmakuRepeatProvider,
  chatNamesProvider,
  chatAvatarsProvider,
  chatShowGiftsProvider,
  chatGiftsAboveTierProvider,
  chatGiftValueInYuanProvider,
  superChatIncludesMembershipProvider,
  danmakuShowGiftsProvider,
  detectClipboardRoomsProvider,
  chatListFontSizeProvider,
  chatListLineSpacingProvider,
  chatCollapsedProvider,
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
  githubMirrorProvider,
  followsAutoRefreshProvider,
  liveAlertSettingsProvider,
  maxConcurrentRefreshProvider,
  thumbnailRefreshProvider,
  liveCacheSettingsProvider,
  storageFolderOverridesProvider,
  logSettingsProvider,
  historyLimitProvider,
  playerKernelBackendProvider,
  playerTuningProvider,
  recordingSettingsProvider,
  followTagsProvider,
  iptvUpdateIntervalProvider,
  iptvBrowseSettingsProvider,
  iptvRecentProvider,
  iptvRemindersProvider,
  iptvAutoSyncProvider,
  iptvUserAgentProvider,
  iptvEpgProvider,
  vodQualityProvider,
  vodPlaybackSettingsProvider,
  vodFavouritesProvider,
  vodHistoryProvider,
  hongguoAccountProvider,
  hongguoLibraryProvider,
  hongguoSearchProvider,
  hongguoSettingsProvider,
  hongguoHomeBannerProvider,
  hongguoDanmakuSettingsProvider,
  hongguoDecoderLessonsProvider,
  musicPlaybackSettingsProvider,
  musicLyricsSettingsProvider,
  musicDesktopLyricsSettingsProvider,
  musicDownloadSettingsProvider,
  musicSourcesProvider,
  musicFavouritesProvider,
  musicRecentProvider,
  musicPlaylistsProvider,
  musicDislikesProvider,
  musicLyricOverridesProvider,
  musicSearchHistoryProvider,
  musicLocalProvider,
  searchHistoryProvider,
  searchExcludedProvider,
  webdavAccountsProvider,
  autoShutdownProvider,
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
  splashSettingsProvider,
  textScaleFactorProvider,
  updateSettingsProvider,
  // The controllers this pass had left out: the music module's own (its
  // sources' swaps, the equaliser and its presets, the player's mode and
  // surface choices, the open API and the sync server), the danmaku save
  // formats, the areas page's layout and the two stations' card designs and
  // download queue. Each reads a pref once and has to rebuild when a restore
  // or another window writes it.
  musicSourceSwapsProvider,
  musicDownloadsProvider,
  musicEqProvider,
  musicCustomPresetsProvider,
  musicUiSettingsProvider,
  musicPlayerModeProvider,
  musicOpenApiGateProvider,
  musicOpenApiLanProvider,
  musicOpenApiPortProvider,
  musicSyncProvider,
  musicSyncServerAuthCodeProvider,
  musicSyncServerGateProvider,
  musicSyncServerLanProvider,
  musicSyncServerPortProvider,
  musicSyncServerStatusProvider,
  danmakuSaveFormatsProvider,
  areaLayoutProvider,
  hongguoCardSettingsProvider,
  vodCardSettingsProvider,
  wallpaperDownloadsProvider,
  vodDownloadSettingsProvider,
  vodDownloadsProvider,
  hongguoDownloadQualityProvider,
  hongguoDownloadRetryProvider,
  hongguoDownloadRetryDelayProvider,
  hongguoDownloadSettingsProvider,
  hongguoDownloadsProvider,
  vodDownloadQualityProvider,
  vodDownloadRetryProvider,
  vodDownloadRetryDelayProvider,
  vodDownloadDanmakuProvider,
];

/// Marks the settings revision and rebuilds every cached settings provider.
///
/// Call after a change made by another window, or by a writer that bypasses
/// the controllers (a backup restore): the controllers must read the new
/// values. A controller that just wrote its own change does not need this.
void refreshSettings(Ref ref) {
  void apply() {
    try {
      ref.read(settingsRevisionProvider.notifier).bump();
      for (final provider in kSettingsProviders) {
        try {
          ref.invalidate(provider);
        } on Object {
          // A provider that is not alive has nothing to rebuild.
        }
      }
    } on Object {
      // The caller's provider was disposed before the deferred pass ran.
    }
  }

  _afterBuild(apply);
}

/// [refreshSettings] from a widget, for actions whose writes bypass the
/// settings controllers — a restored backup, above all.
void refreshSettingsFromWidget(WidgetRef ref) {
  void apply() {
    try {
      ref.read(settingsRevisionProvider.notifier).bump();
      for (final provider in kSettingsProviders) {
        try {
          ref.invalidate(provider);
        } on Object {
          // A provider that is not alive has nothing to rebuild.
        }
      }
    } on Object {
      // The widget was disposed before the deferred pass ran.
    }
  }

  _afterBuild(apply);
}

/// Runs [apply] outside the frame's build/finalize phases: invalidating a
/// provider there is what Riverpod refuses as "tried to modify a provider
/// while the widget tree was building".
void _afterBuild(void Function() apply) {
  if (SchedulerBinding.instance.schedulerPhase == SchedulerPhase.persistentCallbacks) {
    SchedulerBinding.instance.addPostFrameCallback((_) => apply());
  } else {
    apply();
  }
}
