/// Moved to Core so the shared renderer and the recording player can use it.
///
/// Kept as a forwarding export because room layouts and multiview still import
/// this path; a re-export is a move, not a copy, so there is exactly one policy.
library;

export 'package:pure_live/core/player/presentation/danmaku/danmaku_surface_settings.dart'
    show PortraitDanmakuPolicy;
