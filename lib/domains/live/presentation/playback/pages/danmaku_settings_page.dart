/// Moved to Core so the recording player can open the same danmaku panel.
///
/// Kept as a forwarding export because the room's danmaku tab, the multiview
/// page and the player panel import this path; a re-export is a move, not a copy,
/// so there is exactly one settings surface for every player in the app.
library;

export 'package:pure_live/core/player/presentation/danmaku/danmaku_settings_content.dart'
    show DanmakuSettingsContent, DanmakuSettingsPage;
