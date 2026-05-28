import 'dart:io';
import 'package:remixicon/remixicon.dart';
import 'package:pure_live/common/index.dart';
import 'package:pure_live/player/utils/player_consts.dart';
import 'package:pure_live/common/global/platform_utils.dart';
import 'package:pure_live/player/core/live_audio_service.dart';
import 'package:pure_live/modules/settings/pages/font_family_manager_page.dart';

class VideoSettingsPage extends GetView<SettingsService> {
  const VideoSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(i18n("video"))),
      body: ListView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        children: [
          // 📦 分组一：音频控制 (Audio Settings)
          context.buildGroupTitle(i18n("global_mute")),
          context.buildModernCard([
            Obx(
              () => context.buildSwitchTile(
                title: i18n("global_mute"),
                subtitle: i18n("global_mute_subtitle"),
                value: controller.globalVolumeMute,
                icon: controller.globalVolumeMute.value ? Remix.volume_mute_line : Remix.volume_up_line,
              ),
            ),
            if (PlatformUtils.isMobile)
              Obx(
                () => _buildSliderTile(
                  context,
                  icon: Remix.phone_line,
                  title: i18n("mobile_default_volume"),
                  value: controller.defaultMobileVolume.value,
                  onChanged: (val) => controller.defaultMobileVolume.value = val,
                ),
              ),
            if (PlatformUtils.isDesktop)
              Obx(
                () => _buildSliderTile(
                  context,
                  icon: Remix.computer_line,
                  title: i18n("desktop_default_volume"),
                  value: controller.defaultDesktopVolume.value,
                  onChanged: (val) => controller.defaultDesktopVolume.value = val,
                ),
              ),
          ]),

          const SizedBox(height: 20),

          // 📦 分组二：清晰度与画质 (Resolution & Quality)
          context.buildGroupTitle(i18n("prefer_resolution")),
          context.buildModernCard([
            Obx(
              () => context.buildTile(
                icon: Remix.hd_line,
                title: i18n("prefer_resolution"),
                subtitle: i18n("prefer_resolution_subtitle"),
                onTap: showPreferResolutionSelectorDialog,
                trailing: Text(
                  controller.preferResolution.value,
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
                  controller.preferResolutionCellular.value,
                  style: AppTextStyles.t13.copyWith(color: theme.colorScheme.primary, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ]),

          const SizedBox(height: 20),

          // 📦 分组三：播放行为 (Playback Behaviors)
          context.buildGroupTitle(i18n("exit_float_window")),
          context.buildModernCard([
            if (Platform.isAndroid) _buildBackgroundPlayTile(context),
            context.buildSwitchTile(
              title: i18n("exit_float_window"),
              subtitle: i18n("exit_float_window_subtitle"),
              value: controller.floatPlay,
              icon: Remix.picture_in_picture_2_line,
            ),
            context.buildSwitchTile(
              title: i18n('enable_fullscreen_default'),
              subtitle: i18n('enable_fullscreen_default_subtitle'),
              value: controller.enableFullScreenDefault,
              icon: Remix.fullscreen_line,
            ),
            if (Platform.isAndroid)
              context.buildSwitchTile(
                title: i18n('enable_screen_keep_on'),
                subtitle: i18n('enable_screen_keep_on_subtitle'),
                value: controller.enableScreenKeepOn,
                icon: Remix.lightbulb_line,
              ),
          ]),

          const SizedBox(height: 20),

          // 📦 分组四：弹幕设置 (Danmaku Settings)
          context.buildGroupTitle(i18n("show_danmaku")),
          context.buildModernCard([
            context.buildSwitchTile(
              title: i18n('show_danmaku'),
              subtitle: i18n('show_danmaku_subtitle'),
              value: controller.enableDanmakuDisplay,
              icon: Remix.chat_smile_2_line,
            ),
            Obx(
              () => context.buildTile(
                icon: Remix.font_size,
                title: i18n("change_danmaku_font_family"),
                subtitle: "${i18n("current_font_prefix")}: ${controller.danmakuFontFamilyName.value}",
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

  Widget _buildSliderTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required double value,
    required ValueChanged<double> onChanged,
  }) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Icon(icon, color: theme.colorScheme.primary, size: 22),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTextStyles.t15.copyWith(fontWeight: FontWeight.w600)),
                Row(
                  children: [
                    Expanded(
                      child: SliderTheme(
                        data: SliderTheme.of(context).copyWith(trackHeight: 3),
                        child: Slider(value: value.clamp(0.0, 1.0), min: 0.0, max: 1.0, onChanged: onChanged),
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 36,
                      child: Text(
                        "${(value * 100).toInt()}%",
                        style: AppTextStyles.t12.copyWith(color: theme.hintColor, fontWeight: FontWeight.w500),
                        textAlign: TextAlign.end,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBackgroundPlayTile(BuildContext context) {
    return Obx(
      () => SwitchListTile(
        secondary: const Icon(Remix.music_2_line, size: 24),
        title: Text(i18n("enable_background_play")),
        subtitle: Text(i18n("enable_background_play_subtitle")),
        value: controller.enableBackgroundPlay.value,
        onChanged: (value) async {
          controller.enableBackgroundPlay.value = value;
          if (value && Platform.isAndroid) {
            bool hasPermission = await LiveAudioService.requestPlatformPermissions();
            controller.enableBackgroundPlay.value = hasPermission;
          }
        },
      ),
    );
  }

  void showPreferResolutionSelectorDialog() {
    showDialog(
      context: Get.context!,
      builder: (BuildContext context) {
        return SimpleDialog(
          title: Text(i18n("prefer_resolution")),
          children: [
            RadioGroup<String>(
              groupValue: controller.preferResolution.value,
              onChanged: (String? value) {
                if (value != null) {
                  controller.changePreferResolution(value);
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
                            controller.changePreferResolution(name);
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
              groupValue: controller.preferResolutionCellular.value,
              onChanged: (String? value) {
                if (value != null) {
                  controller.changePreferResolutionCellular(value);
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
                            controller.changePreferResolutionCellular(name);
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
