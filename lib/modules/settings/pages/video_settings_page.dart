import 'dart:io';

import 'package:remixicon/remixicon.dart';
import 'package:pure_live/common/index.dart';
import 'package:pure_live/player/utils/player_consts.dart';
import 'package:pure_live/player/utils/window_helper.dart';
import 'package:pure_live/common/global/platform_utils.dart';
import 'package:pure_live/player/core/live_audio_service.dart';
import 'package:pure_live/modules/settings/pages/font_family_manager_page.dart';
import 'package:pure_live/common/services/settings/app_settings_controller.dart';
import 'package:pure_live/modules/settings/pages/pip_danmaku_settings_page.dart';

class VideoSettingsPage extends GetView<SettingsService> {
  const VideoSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(i18n("video_settings"))),
      body: ListView(
        physics: const PureLiveScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        children: [
          // 音频设置
          context.buildGroupTitle(i18n("audio_settings")),
          context.buildModernCard([
            context.buildSwitchTile(
              title: i18n("global_mute"),
              subtitle: i18n("global_mute_subtitle"),
              value: SettingsService.to.vol.globalVolumeMute,
              icon: SettingsService.to.vol.globalVolumeMute.v ? Remix.volume_mute_line : Remix.volume_up_line,
            ),
            if (PlatformUtils.isMobile)
              Obx(
                () => context.buildSliderTile(
                  context,
                  icon: Remix.phone_line,
                  title: i18n("mobile_default_volume"),
                  value: SettingsService.to.vol.defaultMobileVolume.v * 100,
                  min: 0.0,
                  max: 100.0,
                  displayValue: "${(SettingsService.to.vol.defaultMobileVolume.v * 100).toStringAsFixed(0)}%",
                  onChanged: (val) =>
                      SettingsService.to.vol.defaultMobileVolume.v = double.parse((val / 100).toStringAsFixed(2)),
                ),
              ),
            if (PlatformUtils.isDesktop)
              Obx(
                () => context.buildSliderTile(
                  context,
                  icon: Remix.computer_line,
                  title: i18n("desktop_default_volume"),
                  value: SettingsService.to.vol.defaultDesktopVolume.v * 100,
                  min: 0.0,
                  max: 100.0,
                  displayValue: "${(SettingsService.to.vol.defaultDesktopVolume.v * 100).toStringAsFixed(0)}%",
                  onChanged: (val) {
                    SettingsService.to.vol.defaultDesktopVolume.v = double.parse((val / 100).toStringAsFixed(2));
                  },
                ),
              ),
          ]),

          const SizedBox(height: 20),

          // 画质设置
          context.buildGroupTitle(i18n("video_quality_settings")),
          context.buildModernCard([
            Obx(
              () => context.buildTile(
                icon: Remix.hd_line,
                title: i18n("prefer_resolution"),
                subtitle: i18n("prefer_resolution_subtitle"),
                onTap: showPreferResolutionSelectorDialog,
                trailing: Text(
                  SettingsService.to.player.preferResolution.v,
                  style: TextStyle(color: theme.colorScheme.primary, fontWeight: FontWeight.w600),
                ),
              ),
            ),
            Obx(
              () => context.buildTile(
                icon: Remix.signal_tower_line,
                title: i18n("mobile_quality"),
                subtitle: i18n("mobile_quality_subtitle"),
                onTap: showpreferResolutionCellularSelectorDialog,
                trailing: Text(
                  SettingsService.to.player.preferResolutionCellular.v,
                  style: AppTextStyles.t13.copyWith(color: theme.colorScheme.primary, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ]),

          const SizedBox(height: 20),

          // 播放行为设置
          context.buildGroupTitle(i18n("playback_behavior_settings")),
          context.buildModernCard([
            if (Platform.isAndroid)
              context.buildSwitchTile(
                icon: Remix.music_2_line,
                title: i18n("enable_background_play"),
                subtitle: i18n("enable_background_play_subtitle"),
                value: SettingsService.to.app.enableBackgroundPlay,
                onChanged: (val) async {
                  SettingsService.to.app.enableBackgroundPlay.v = val;
                  if (val && Platform.isAndroid) {
                    bool hasPermission = await LiveAudioService.requestPlatformPermissions();
                    SettingsService.to.app.enableBackgroundPlay.v = hasPermission;
                    await LiveAudioService.syncKeepAlive();
                  } else if (!val) {
                    if (!LiveAudioService.isSleepSessionActive) {
                      await LiveAudioService.releaseKeepAlive();
                    }
                  }
                },
              ),
            if (Platform.isAndroid)
              context.buildSwitchTile(
                icon: Remix.moon_clear_line,
                title: i18n('asmr_sleep_mode'),
                subtitle: i18n('asmr_sleep_mode_desc'),
                value: SettingsService.to.app.enableAsmrSleepMode,
                onChanged: (val) async {
                  if (val) {
                    final hasPermission = await LiveAudioService.requestPlatformPermissions();
                    SettingsService.to.app.enableAsmrSleepMode.v = hasPermission;
                  } else {
                    SettingsService.to.app.enableAsmrSleepMode.v = false;
                    await LiveAudioService.configureSleepTimer(
                      enabled: false,
                      minutes: SettingsService.to.app.asmrSleepMinutes.v,
                    );
                  }
                },
              ),
            if (Platform.isAndroid)
              Obx(
                () => context.buildTile(
                  icon: Remix.timer_2_line,
                  title: i18n('asmr_sleep_timer'),
                  subtitle: i18n('asmr_sleep_timer_desc'),
                  trailing: Text(
                    _formatDuration(SettingsService.to.app.asmrSleepMinutes.v),
                    style: TextStyle(color: theme.colorScheme.primary, fontWeight: FontWeight.w600),
                  ),
                  onTap: () => _showAsmrSleepTimerDialog(context),
                ),
              ),
            context.buildSwitchTile(
              title: i18n("exit_float_window"),
              subtitle: i18n("exit_float_window_subtitle"),
              value: SettingsService.to.player.floatPlay,
              icon: Remix.picture_in_picture_2_line,
            ),
            if (Platform.isWindows)
              context.buildSwitchTile(
                title: i18n('windows_pip_always_on_top'),
                subtitle: i18n('windows_pip_always_on_top_subtitle'),
                value: SettingsService.to.player.windowsPipAlwaysOnTop,
                icon: Remix.pushpin_line,
                onChanged: WindowHelper.instance.setPiPAlwaysOnTop,
              ),
            if (Platform.isWindows)
              context.buildSwitchTile(
                title: i18n('windows_pip_remember_position'),
                subtitle: i18n('windows_pip_remember_position_subtitle'),
                value: SettingsService.to.window.rememberPipPosition,
                icon: Remix.terminal_window_fill,
                onChanged: (value) {
                  SettingsService.to.window.rememberPipPosition.v = value;
                },
              ),
            if (Platform.isWindows)
              context.buildTile(
                icon: Remix.reserved_line,
                title: i18n('windows_pip_reset_position'),
                subtitle: i18n('windows_pip_reset_position_subtitle'),
                onTap: () async {
                  final result = await showDialog<bool>(
                    context: context,
                    builder: (context) {
                      return AlertDialog(
                        title: Text(i18n('windows_pip_reset_position')),
                        content: Text(i18n('windows_pip_reset_position_confirm')),
                        actions: [
                          TextButton(onPressed: () => Navigator.of(context).pop(false), child: Text(i18n('cancel'))),
                          FilledButton(onPressed: () => Navigator.of(context).pop(true), child: Text(i18n('confirm'))),
                        ],
                      );
                    },
                  );

                  if (result == true) {
                    SettingsService.to.window.clearWindowsPipGeometry();
                  }
                },
              ),

            context.buildSwitchTile(
              title: i18n('enable_fullscreen_default'),
              subtitle: i18n('enable_fullscreen_default_subtitle'),
              value: SettingsService.to.app.enableFullScreenDefault,
              icon: Remix.fullscreen_line,
            ),
            if (Platform.isAndroid)
              context.buildSwitchTile(
                title: i18n('enable_screen_keep_on'),
                subtitle: i18n('enable_screen_keep_on_subtitle'),
                value: SettingsService.to.app.enableScreenKeepOn,
                icon: Remix.lightbulb_line,
              ),
          ]),

          const SizedBox(height: 20),

          // 弹幕设置
          context.buildGroupTitle(i18n("danmaku_settings")),
          context.buildModernCard([
            context.buildSwitchTile(
              title: i18n('show_danmaku'),
              subtitle: i18n('show_danmaku_subtitle'),
              value: SettingsService.to.danmaku.enableDanmakuDisplay,
              icon: Remix.chat_smile_2_line,
            ),
            context.buildTile(
              icon: Remix.picture_in_picture_2_line,
              title: i18n('pip_danmaku'),
              subtitle: i18n('pip_danmaku_desc'),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => Get.to(() => const PipDanmakuSettingsPage()),
            ),
            Obx(
              () => context.buildTile(
                icon: Remix.font_size,
                title: i18n("change_danmaku_font_family"),
                subtitle: "${i18n("current_font_prefix")}: ${SettingsService.to.danmaku.danmakuFontFamilyName.v}",
                onTap: () => Get.to(() => const FontFamilyManagerPage(isDanmakuSettings: true)),
              ),
            ),

            context.buildTile(
              icon: Remix.filter_2_line,
              title: i18n("danmaku_filter"),
              subtitle: "",
              onTap: () => Get.toNamed(RoutePath.kSettingsDanmuShield),
            ),
          ]),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  void _showAsmrSleepTimerDialog(BuildContext context) {
    const options = [15, 30, 45, 60, 90, 120, 240, 480, 720, 1440];
    final customController = TextEditingController(text: SettingsService.to.app.asmrSleepMinutes.v.toString());
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(i18n('asmr_sleep_timer')),
        content: SizedBox(
          width: 360,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(i18n('asmr_sleep_timer_explain'), style: Theme.of(dialogContext).textTheme.bodySmall),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: options
                      .map(
                        (minutes) => ActionChip(
                          label: Text(_formatDuration(minutes)),
                          onPressed: () => customController.text = minutes.toString(),
                        ),
                      )
                      .toList(),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: customController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: i18n('custom_sleep_minutes'),
                    helperText: i18n('custom_sleep_minutes_range'),
                    suffixText: i18n('minutes'),
                    border: const OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(), child: Text(i18n('cancel'))),
          FilledButton(
            onPressed: () async {
              final minutes = int.tryParse(customController.text.trim());
              if (minutes == null || minutes < 1 || minutes > AppSettingsController.maxSleepMinutes) {
                ToastUtil.show(i18n('custom_sleep_minutes_range'));
                return;
              }
              SettingsService.to.app.asmrSleepMinutes.v = minutes;
              await LiveAudioService.configureSleepTimer(
                enabled: LiveAudioService.isSleepSessionActive,
                minutes: minutes,
              );
              if (dialogContext.mounted) Navigator.of(dialogContext).pop();
            },
            child: Text(i18n('save')),
          ),
        ],
      ),
    ).whenComplete(customController.dispose);
  }

  String _formatDuration(int minutes) {
    if (minutes % 1440 == 0) return '${minutes ~/ 1440} ${i18n('days')}';
    if (minutes % 60 == 0) return '${minutes ~/ 60} ${i18n('hours')}';
    return '$minutes ${i18n('minutes')}';
  }

  void showPreferResolutionSelectorDialog() {
    showDialog(
      context: Get.context!,
      builder: (BuildContext context) {
        return SimpleDialog(
          title: Text(i18n("prefer_resolution")),
          children: [
            RadioGroup<String>(
              groupValue: SettingsService.to.player.preferResolution.v,
              onChanged: (String? value) {
                if (value != null) {
                  SettingsService.to.player.changePreferResolution(value);
                  Navigator.of(context).pop();
                }
              },
              child: Padding(
                padding: const EdgeInsets.only(top: 0, bottom: 10, left: 16, right: 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: PlayerConsts.resolutions.map<Widget>((name) {
                    return Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Radio<String>(value: name, activeColor: Theme.of(context).colorScheme.primary),
                        GestureDetector(
                          onTap: () {
                            SettingsService.to.player.changePreferResolution(name);
                            Navigator.of(context).pop();
                          },
                          child: Text(name),
                        ),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void showpreferResolutionCellularSelectorDialog() {
    showDialog(
      context: Get.context!,
      builder: (BuildContext context) {
        return SimpleDialog(
          title: Text(i18n("prefer_resolution_cellular")),
          children: [
            RadioGroup<String>(
              groupValue: SettingsService.to.player.preferResolutionCellular.v,
              onChanged: (String? value) {
                if (value != null) {
                  SettingsService.to.player.changePreferResolutionCellular(value);
                  Navigator.of(context).pop();
                }
              },
              child: Padding(
                padding: const EdgeInsets.only(top: 0, bottom: 10, left: 16, right: 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: PlayerConsts.resolutions.map<Widget>((name) {
                    return Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Radio<String>(value: name, activeColor: Theme.of(context).colorScheme.primary),
                        GestureDetector(
                          onTap: () {
                            SettingsService.to.player.changePreferResolutionCellular(name);
                            Navigator.of(context).pop();
                          },
                          child: Text(name),
                        ),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
