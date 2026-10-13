/// Typed user preferences for Pure Live: playback, danmaku, library, TV
/// navigation, floating window, appearance and IPTV groups, persisted as one
/// versioned JSON document per group through `live_storage`.
library;

export 'src/model/appearance_preferences.dart';
export 'src/model/danmaku_preferences.dart';
export 'src/model/desktop_preferences.dart';
export 'src/model/desktop_shell_mapping.dart';
export 'src/model/iptv_preferences.dart';
export 'src/model/library_preferences.dart';
export 'src/model/playback_preferences.dart';
export 'src/model/preferences.dart';
export 'src/model/tv_preferences.dart';
export 'src/model/window_preferences.dart';
export 'src/service/preferences_service.dart';
