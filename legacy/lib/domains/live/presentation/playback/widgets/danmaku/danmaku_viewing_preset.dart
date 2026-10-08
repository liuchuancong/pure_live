/// Moved to Core so the shared renderer and the settings surface share it.
///
/// Kept as a forwarding export for the room's own imports; a re-export is a
/// move, not a copy.
library;

export 'package:pure_live/core/player/presentation/danmaku/danmaku_viewing_preset.dart'
    show DanmakuViewingPreset, DanmakuViewingTemplate;
