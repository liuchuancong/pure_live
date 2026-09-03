import 'package:pure_live/common/index.dart';
import 'package:pure_live/common/global/platform_utils.dart';
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
            // 竖屏视频高度设置
            if (PlatformUtils.isMobile) ...[
              Obx(
                () => context.buildTile(
                  icon: Icons.crop_rotate_rounded,
                  title: i18n('portrait_video_height_mode'),
                  subtitle: _videoHeightModeLabel(settings.portraitVideoHeightMode),
                  isLong: true,
                  onTap: () => _selectVideoHeightMode(context, settings),
                ),
              ),
              Obx(() {
                if (settings.portraitVideoHeightMode != PortraitVideoHeightMode.custom) {
                  return const SizedBox.shrink();
                }
                return context.buildTile(
                  icon: Icons.height_rounded,
                  title: i18n('portrait_custom_height'),
                  subtitle: i18n('portrait_custom_height_setting'),
                  isLong: true,
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${settings.portraitCustomHeight.v.toStringAsFixed(0)}px',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  onTap: () => _showCustomHeightDialog(context, settings),
                );
              }),
            ],
          ]),

          const SizedBox(height: 20),
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
                settings.resetPortraitVideoHeight();
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
                        color: item == settings.portraitLayoutMode
                            ? Theme.of(dialogContext).colorScheme.primary
                            : null,
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

  Future<void> _selectVideoHeightMode(
    BuildContext context,
    PlayerSettingsController settings,
  ) async {
    final value = await showDialog<PortraitVideoHeightMode>(
      context: context,
      builder: (dialogContext) {
        return SimpleDialog(
          title: Text(i18n('portrait_video_height_mode')),
          children: PortraitVideoHeightMode.values
              .map(
                (item) => SimpleDialogOption(
                  onPressed: () {
                    Navigator.of(dialogContext).pop(item);
                  },
                  child: Row(
                    children: [
                      Icon(
                        item == settings.portraitVideoHeightMode
                            ? Icons.radio_button_checked_rounded
                            : Icons.radio_button_off_rounded,
                        color: item == settings.portraitVideoHeightMode
                            ? Theme.of(dialogContext).colorScheme.primary
                            : null,
                      ),
                      const SizedBox(width: 12),
                      Expanded(child: Text(_videoHeightModeLabel(item))),
                    ],
                  ),
                ),
              )
              .toList(),
        );
      },
    );

    if (value != null) {
      settings.changePortraitVideoHeightMode(value);
    }
  }

  String _videoHeightModeLabel(PortraitVideoHeightMode value) {
    return switch (value) {
      PortraitVideoHeightMode.adaptive => i18n('portrait_video_height_adaptive'),
      PortraitVideoHeightMode.custom => i18n('portrait_video_height_custom'),
      PortraitVideoHeightMode.full => i18n('portrait_video_height_full'),
    };
  }

  void _showCustomHeightDialog(BuildContext context, PlayerSettingsController settings) {
    double draftHeight = settings.portraitCustomHeight.v;
    final customController = TextEditingController(text: draftHeight.toStringAsFixed(0));

    const presetHeights = <double>[0, 10, 20, 30, 40, 50, 60];

    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(i18n('portrait_custom_height'), style: AppTextStyles.t16Bold),
          content: SizedBox(
            width: 320,
            child: StatefulBuilder(
              builder: (context, setDialogState) {
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(i18n('portrait_custom_height_desc'), style: AppTextStyles.t12Muted),
                    const SizedBox(height: 16),
                    Text(i18n('portrait_height_presets'), style: AppTextStyles.t13Medium),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        ...presetHeights.map(
                          (height) => ChoiceChip(
                            label: Text('${height.toInt()} px', style: AppTextStyles.t12),
                            selected: draftHeight == height,
                            onSelected: (_) {
                              setDialogState(() {
                                draftHeight = height;
                                customController.text = height.toInt().toString();
                              });
                            },
                          ),
                        ),
                        if (!presetHeights.contains(draftHeight))
                          ChoiceChip(
                            label: Text('${draftHeight.toInt()} px', style: AppTextStyles.t12),
                            selected: true,
                            onSelected: (_) {},
                          ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Text(i18n('custom_input'), style: AppTextStyles.t13Medium),
                    const SizedBox(height: 12),
                    TextField(
                      controller: customController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      style: AppTextStyles.t14,
                      decoration: InputDecoration(
                        hintText: '30',
                        suffixText: 'px',
                        suffixStyle: AppTextStyles.t12Muted,
                        border: const OutlineInputBorder(),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                      onChanged: (value) {
                        final height = double.tryParse(value.trim());

                        if (height != null && height >= 0) {
                          setDialogState(() {
                            draftHeight = height;
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 16),
                    Text(
                      '${i18n("current_value")}: ${draftHeight.toStringAsFixed(0)} px',
                      style: AppTextStyles.t12Muted,
                    ),
                  ],
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(i18n('cancel'), style: AppTextStyles.t14Muted),
            ),
            TextButton(
              onPressed: () {
                final value = double.tryParse(customController.text.trim());

                if (value == null || value < 0) {
                  ToastUtil.show(i18n('portrait_custom_height_invalid'));
                  return;
                }

                settings.changePortraitCustomHeight(value);

                if (dialogContext.mounted) {
                  Navigator.of(dialogContext).pop();
                }
              },
              child: Text(i18n('confirm'), style: AppTextStyles.t14Primary),
            ),
          ],
        );
      },
    ).whenComplete(customController.dispose);
  }
}
