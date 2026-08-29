import 'dart:io';

import 'package:pure_live/common/index.dart';
import 'package:pure_live/player/core/portrait_stream_support.dart';

class PortraitLiveSettingsPage extends StatelessWidget {
  const PortraitLiveSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = SettingsService.to.player;
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(i18n('portrait_live_settings'))),
      body: ListView(
        physics: const PureLiveScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        children: [
          context.buildGroupTitle(i18n('portrait_detection_group')),
          context.buildModernCard([
            context.buildSwitchTile(
              icon: Icons.aspect_ratio_rounded,
              title: i18n('portrait_smart_detection'),
              subtitle: i18n('portrait_smart_detection_desc'),
              isLong: true,
              value: settings.enablePortraitStreamAdaptation,
              onChanged: (_) => _refreshPresentation(),
            ),
            context.buildSwitchTile(
              icon: Icons.view_agenda_outlined,
              title: i18n('portrait_adaptive_height'),
              subtitle: i18n('portrait_adaptive_height_desc'),
              isLong: true,
              value: settings.portraitAdaptiveHeight,
            ),
            Obx(
              () => context.buildTile(
                icon: Icons.dashboard_customize_outlined,
                title: i18n('portrait_layout_mode'),
                subtitle: i18n('portrait_layout_mode_desc'),
                isLong: true,
                trailing: Text(
                  _layoutModeLabel(settings.portraitLayoutMode),
                  style: TextStyle(color: theme.colorScheme.primary, fontWeight: FontWeight.w600),
                ),
                onTap: () => _selectEnum<PortraitLayoutMode>(
                  context,
                  title: i18n('portrait_layout_mode'),
                  values: PortraitLayoutMode.values,
                  selected: settings.portraitLayoutMode,
                  label: _layoutModeLabel,
                  onSelected: (value) => settings.portraitLayoutModeName.v = value.name,
                ),
              ),
            ),
          ]),
          const SizedBox(height: 20),
          context.buildGroupTitle(i18n('portrait_presentation_group')),
          context.buildModernCard([
            Obx(
              () => context.buildTile(
                icon: Icons.fullscreen_rounded,
                title: i18n('portrait_fullscreen_policy'),
                subtitle: i18n('portrait_fullscreen_policy_desc'),
                isLong: true,
                trailing: Text(
                  _fullscreenPolicyLabel(settings.portraitFullscreenPolicy),
                  style: TextStyle(color: theme.colorScheme.primary, fontWeight: FontWeight.w600),
                ),
                onTap: () => _selectEnum<PortraitFullscreenPolicy>(
                  context,
                  title: i18n('portrait_fullscreen_policy'),
                  values: PortraitFullscreenPolicy.values,
                  selected: settings.portraitFullscreenPolicy,
                  label: _fullscreenPolicyLabel,
                  onSelected: (value) {
                    settings.portraitFullscreenPolicyName.v = value.name;
                    _refreshPresentation();
                  },
                ),
              ),
            ),
            Obx(
              () => context.buildTile(
                icon: Icons.fit_screen_rounded,
                title: i18n('portrait_fullscreen_display_mode'),
                subtitle: i18n('portrait_fullscreen_display_mode_desc'),
                isLong: true,
                trailing: Text(
                  portraitFullscreenDisplayModeLabel(settings.portraitFullscreenDisplayMode),
                  style: TextStyle(color: theme.colorScheme.primary, fontWeight: FontWeight.w600),
                ),
                onTap: () => _selectEnum<PortraitFullscreenDisplayMode>(
                  context,
                  title: i18n('portrait_fullscreen_display_mode'),
                  values: PortraitFullscreenDisplayMode.values,
                  selected: settings.portraitFullscreenDisplayMode,
                  label: portraitFullscreenDisplayModeLabel,
                  onSelected: (value) => settings.portraitFullscreenDisplayModeName.v = value.name,
                ),
              ),
            ),
            if (Platform.isAndroid)
              context.buildSwitchTile(
                icon: Icons.picture_in_picture_alt_rounded,
                title: i18n('portrait_pip_follow_source'),
                subtitle: i18n('portrait_pip_follow_source_desc'),
                isLong: true,
                value: settings.portraitPipFollowSource,
              ),
            Obx(
              () => context.buildTile(
                icon: Icons.subtitles_outlined,
                title: i18n('portrait_danmaku_mode'),
                subtitle: i18n('portrait_danmaku_mode_desc'),
                isLong: true,
                trailing: Text(
                  _danmakuModeLabel(settings.portraitDanmakuMode),
                  style: TextStyle(color: theme.colorScheme.primary, fontWeight: FontWeight.w600),
                ),
                onTap: () => _selectEnum<PortraitDanmakuMode>(
                  context,
                  title: i18n('portrait_danmaku_mode'),
                  values: PortraitDanmakuMode.values,
                  selected: settings.portraitDanmakuMode,
                  label: _danmakuModeLabel,
                  onSelected: (value) => settings.portraitDanmakuModeName.v = value.name,
                ),
              ),
            ),
            context.buildSwitchTile(
              icon: Icons.bookmark_added_outlined,
              title: i18n('portrait_remember_room_override'),
              subtitle: i18n('portrait_remember_room_override_desc'),
              isLong: true,
              value: settings.rememberPortraitRoomOverride,
            ),
          ]),
          const SizedBox(height: 20),
          context.buildGroupTitle(i18n('portrait_diagnostics_group')),
          context.buildModernCard([
            context.buildSwitchTile(
              icon: Icons.monitor_heart_outlined,
              title: i18n('portrait_show_diagnostics'),
              subtitle: i18n('portrait_show_diagnostics_desc'),
              isLong: true,
              value: settings.showPortraitDiagnostics,
            ),
            context.buildTile(
              icon: Icons.restart_alt_rounded,
              title: i18n('portrait_reset_settings'),
              subtitle: i18n('portrait_reset_settings_desc'),
              isLong: true,
              onTap: () {
                settings.resetPortraitStreamSettings();
                _refreshPresentation();
                ToastUtil.show(i18n('settings_reset_done'));
              },
            ),
          ]),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  void _refreshPresentation() {
    GlobalPlayerService.instance.player.refreshPortraitPresentationPolicy();
  }

  Future<void> _selectEnum<T extends Enum>(
    BuildContext context, {
    required String title,
    required List<T> values,
    required T selected,
    required String Function(T) label,
    required ValueChanged<T> onSelected,
  }) async {
    final value = await showDialog<T>(
      context: context,
      builder: (dialogContext) => SimpleDialog(
        title: Text(title),
        children: values
            .map(
              (item) => SimpleDialogOption(
                onPressed: () => Navigator.of(dialogContext).pop(item),
                child: Row(
                  children: [
                    Icon(
                      item == selected ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
                      color: item == selected ? Theme.of(dialogContext).colorScheme.primary : null,
                    ),
                    const SizedBox(width: 12),
                    Expanded(child: Text(label(item))),
                  ],
                ),
              ),
            )
            .toList(),
      ),
    );
    if (value != null) onSelected(value);
  }

  String _layoutModeLabel(PortraitLayoutMode value) => switch (value) {
    PortraitLayoutMode.balanced => i18n('portrait_layout_balanced'),
    PortraitLayoutMode.immersive => i18n('portrait_layout_immersive'),
    PortraitLayoutMode.compatibility => i18n('portrait_layout_compatibility'),
  };

  String _fullscreenPolicyLabel(PortraitFullscreenPolicy value) => switch (value) {
    PortraitFullscreenPolicy.followSource => i18n('portrait_fullscreen_follow_source'),
    PortraitFullscreenPolicy.followSystem => i18n('portrait_fullscreen_follow_system'),
    PortraitFullscreenPolicy.landscape => i18n('portrait_fullscreen_landscape'),
  };

  String _danmakuModeLabel(PortraitDanmakuMode value) => switch (value) {
    PortraitDanmakuMode.followGlobal => i18n('portrait_danmaku_follow_global'),
    PortraitDanmakuMode.upperQuarter => i18n('portrait_danmaku_upper_quarter'),
    PortraitDanmakuMode.reduced => i18n('portrait_danmaku_reduced'),
    PortraitDanmakuMode.hidden => i18n('portrait_danmaku_hidden'),
  };
}

String portraitFullscreenDisplayModeLabel(PortraitFullscreenDisplayMode value) => switch (value) {
  PortraitFullscreenDisplayMode.complete => i18n('portrait_fullscreen_display_complete'),
  PortraitFullscreenDisplayMode.ambient => i18n('portrait_fullscreen_display_ambient'),
  PortraitFullscreenDisplayMode.balanced => i18n('portrait_fullscreen_display_balanced'),
  PortraitFullscreenDisplayMode.cover => i18n('portrait_fullscreen_display_cover'),
};
