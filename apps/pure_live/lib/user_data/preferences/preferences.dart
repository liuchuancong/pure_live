/// The user's typed preferences, owned by the app: playback, danmaku,
/// library, TV navigation, floating window, appearance and IPTV groups,
/// persisted as one versioned JSON document per group through
/// `live_storage`.
library;

export 'model/appearance_preferences.dart';
export 'model/danmaku_preferences.dart';
export 'model/desktop_preferences.dart';
export 'model/desktop_shell_mapping.dart';
export 'model/iptv_preferences.dart';
export 'model/library_preferences.dart';
export 'model/playback_preferences.dart';
export 'model/preferences.dart';
export 'model/tv_preferences.dart';
export 'model/window_preferences.dart';
export 'preferences_service.dart';
