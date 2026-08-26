import 'package:pure_live/common/index.dart';
import 'package:pure_live/player/core/portrait_stream_support.dart';
import 'package:pure_live/common/services/settings/player_settings_controller.dart';

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
                onTap: () => _selectLayoutMode(context, settings),
              ),
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
                onTap: () => _selectDanmakuMode(context, settings),
              ),
            ),
          ]),

          const SizedBox(height: 20),

          // ─────────────────────────────────────────────
          // 恢复默认设置
          // ─────────────────────────────────────────────
          context.buildGroupTitle(i18n('portrait_presentation_group')),
          context.buildModernCard([
            context.buildTile(
              icon: Icons.restart_alt_rounded,
              title: i18n('portrait_reset_settings'),
              subtitle: i18n('portrait_reset_settings_desc'),
              isLong: true,
              onTap: () {
                settings.resetPortraitLayoutMode();
                settings.resetPortraitDanmakuMode();

                ToastUtil.show(i18n('settings_reset_done'));
              },
            ),
          ]),

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════
  // PortraitLayoutMode
  // ═══════════════════════════════════════════════════

  Future<void> _selectLayoutMode(BuildContext context, PlayerSettingsController settings) async {
    final value = await showDialog<PortraitLayoutMode>(
      context: context,
      builder: (dialogContext) {
        return SimpleDialog(
          title: Text(i18n('portrait_layout_mode')),
          children: PortraitLayoutMode.values
              .map(
                (item) => SimpleDialogOption(
                  onPressed: () {
                    Navigator.of(dialogContext).pop(item);
                  },
                  child: Row(
                    children: [
                      Icon(
                        item == settings.portraitLayoutMode
                            ? Icons.radio_button_checked_rounded
                            : Icons.radio_button_off_rounded,
                        color: item == settings.portraitLayoutMode ? Theme.of(dialogContext).colorScheme.primary : null,
                      ),
                      const SizedBox(width: 12),
                      Expanded(child: Text(_layoutModeLabel(item))),
                    ],
                  ),
                ),
              )
              .toList(),
        );
      },
    );

    if (value != null) {
      settings.changePortraitLayoutMode(value);
    }
  }

  String _layoutModeLabel(PortraitLayoutMode value) {
    return switch (value) {
      PortraitLayoutMode.balanced => i18n('portrait_layout_balanced'),
      PortraitLayoutMode.immersive => i18n('portrait_layout_immersive'),
      PortraitLayoutMode.compatibility => i18n('portrait_layout_compatibility'),
    };
  }

  // ═══════════════════════════════════════════════════
  // PortraitDanmakuMode
  // ═══════════════════════════════════════════════════

  Future<void> _selectDanmakuMode(BuildContext context, PlayerSettingsController settings) async {
    final value = await showDialog<PortraitDanmakuMode>(
      context: context,
      builder: (dialogContext) {
        return SimpleDialog(
          title: Text(i18n('portrait_danmaku_mode')),
          children: PortraitDanmakuMode.values
              .map(
                (item) => SimpleDialogOption(
                  onPressed: () {
                    Navigator.of(dialogContext).pop(item);
                  },
                  child: Row(
                    children: [
                      Icon(
                        item == settings.portraitDanmakuMode
                            ? Icons.radio_button_checked_rounded
                            : Icons.radio_button_off_rounded,
                        color: item == settings.portraitDanmakuMode
                            ? Theme.of(dialogContext).colorScheme.primary
                            : null,
                      ),
                      const SizedBox(width: 12),
                      Expanded(child: Text(_danmakuModeLabel(item))),
                    ],
                  ),
                ),
              )
              .toList(),
        );
      },
    );

    if (value != null) {
      settings.changePortraitDanmakuMode(value);
    }
  }

  String _danmakuModeLabel(PortraitDanmakuMode value) {
    return switch (value) {
      PortraitDanmakuMode.followGlobal => i18n('portrait_danmaku_follow_global'),
      PortraitDanmakuMode.upperQuarter => i18n('portrait_danmaku_upper_quarter'),
      PortraitDanmakuMode.reduced => i18n('portrait_danmaku_reduced'),
      PortraitDanmakuMode.hidden => i18n('portrait_danmaku_hidden'),
    };
  }
}
