/// The settings surface and everything it configures: the page itself, the
/// panes, the dialogs they open, and the stored choices behind browsing,
/// danmaku, playback and the room. Import this one file instead of the
/// settings modules it happens to use.
library;

export 'browse/audience_metric_provider.dart';
export 'browse/live_alert_settings.dart';
export 'browse/platform_preferences_provider.dart';
export 'browse/sites_display_provider.dart';
export 'browse/twitch_languages_provider.dart';
export 'danmaku/chat_display_settings.dart';
export 'danmaku/danmaku_fixed_providers.dart';
export 'danmaku/danmaku_hold_provider.dart';
export 'danmaku/danmaku_repeat_provider.dart';
export 'danmaku/danmaku_show_gifts_provider.dart';
export 'danmaku/danmaku_style_providers.dart';
export 'danmaku/super_chat_settings.dart';
export 'dialogs/asmr_sleep_dialog.dart';
export 'dialogs/config_preview_dialog.dart';
export 'dialogs/live_alert_tags_dialog.dart';
export 'dialogs/player_guide_dialog.dart';
export 'dialogs/prefer_platform_dialog.dart';
export 'dialogs/theme_color_dialog.dart';
export 'dialogs/twitch_languages_dialog.dart';
export 'general/auto_shutdown_section.dart';
export 'general/refresh_rate_section.dart';
export 'general/settings_order_list.dart';
export 'general/tv_preferences.dart';
export 'general/window_size_row.dart';
export 'pages/font_manager_page.dart';
export 'pages/wallpaper_preview_page.dart';
export 'panes/audience_settings_pane.dart';
export 'panes/background_panes.dart';
export 'panes/player_kernel_pane.dart';
export 'panes/room_card_pane.dart';
export 'playback/floating_window_settings.dart';
export 'playback/pip_danmaku_scale_provider.dart';
export 'playback/playback_settings_providers.dart';
export 'playback/player_tuning.dart';
export 'playback/portrait_fullscreen_settings.dart';
export 'playback/portrait_settings_providers.dart';
export 'room/clipboard_rooms.dart';
export 'room/room_card_settings.dart';
export 'room/room_switcher_settings.dart';
export 'surface/settings_navigation.dart';
export 'surface/settings_page.dart';
export 'surface/settings_preview.dart';
export 'surface/settings_search.dart';
export 'surface/settings_sections.dart';
export 'surface/settings_widgets.dart';
