/// Multiview's danmaku configuration is the global one.
///
/// The four cells have no room of their own to override a font or a stroke, so
/// this is the Core settings source rather than a second forwarding copy of it.
/// The alias keeps the multiview-specific name the page and its tests use.
library;

import 'package:pure_live/core/player/presentation/danmaku/danmaku_surface_settings.dart';

export 'package:pure_live/core/player/presentation/danmaku/danmaku_surface_settings.dart'
    show SettingsDanmakuSource;

typedef MultiviewDanmakuSettingsSource = SettingsDanmakuSource;
