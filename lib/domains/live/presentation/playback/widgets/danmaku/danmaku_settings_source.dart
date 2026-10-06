/// Moved to Core so the shared renderer and the recording player can use it.
///
/// Kept as a forwarding export because the room's settings page, multiview and
/// player widgets still import this path; a re-export is a move, not a copy.
library;

export 'package:pure_live/core/player/presentation/danmaku/danmaku_surface_settings.dart'
    show DanmakuSettingsSource, PortraitDanmakuPolicy;
