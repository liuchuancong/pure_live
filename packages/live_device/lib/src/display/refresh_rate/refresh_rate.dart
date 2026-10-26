/// What the display runs at: the rate it reports, the rate the app asks for, the preference in
/// between and the service that applies it.
library;

export 'display_playback_rate.dart' show DisplayPlaybackRefreshMode, normalizePlaybackFrameRate, playbackFrameRateMultiples, playbackRefreshRateForDisplay;
export 'display_refresh_rate.dart' show DisplayRefreshRate, DisplayThermalState;
export 'display_refresh_rate_capabilities.dart' show DisplayRefreshRateCapabilities;
export 'display_refresh_rate_exception.dart' show DisplayRefreshRateException;
export 'display_refresh_rate_preference.dart' show DisplayRefreshRatePreference;
export 'display_refresh_rate_service.dart' show DisplayRefreshRateService;
export 'platform_display_refresh_rate_service.dart' show PlatformDisplayRefreshRateService;
