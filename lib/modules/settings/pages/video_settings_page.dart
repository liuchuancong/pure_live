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
      appBar: AppBar(title: Text(i18n("video_settings"))),
      body: ListView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        children: [
          // 音频设置
          context.buildGroupTitle(i18n("audio_settings")),
          context.buildModernCard([
            Obx(
              () => context.buildSwitchTile(
                title: i18n("global_mute"),
                subtitle: i18n("global_mute_subtitle"),
                value: SettingsService.to.vol.globalVolumeMute,
                icon: SettingsService.to.vol.globalVolumeMute.v ? Remix.volume_mute_line : Remix.volume_up_line,
              ),
            ),
            if (PlatformUtils.isMobile)
              Obx(
                () => context.buildSliderTile(
                  context,
                  icon: Remix.phone_line,
                  title: i18n("mobile_default_volume"),
                  value: SettingsService.to.vol.defaultMobileVolume.v,
                  min: 0.0,
                  max: 100.0,
                  displayValue: "${(SettingsService.to.vol.defaultMobileVolume.v * 100).toStringAsFixed(0)}%",
                  onChanged: (val) => SettingsService.to.vol.defaultMobileVolume.v = val,
                ),
              ),
            if (PlatformUtils.isDesktop)
              Obx(
                () => context.buildSliderTile(
                  context,
                  icon: Remix.computer_line,
                  title: i18n("desktop_default_volume"),
                  value: SettingsService.to.vol.defaultDesktopVolume.v,
                  min: 0.0,
                  max: 100.0,
                  displayValue: "${(SettingsService.to.vol.defaultDesktopVolume.v * 100).toStringAsFixed(0)}%",
                  onChanged: (val) => SettingsService.to.vol.defaultDesktopVolume.v = val,
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
              Obx(
                () => context.buildSwitchTile(
                  icon: Remix.music_2_line,
                  title: i18n("enable_background_play"),
                  subtitle: i18n("enable_background_play_subtitle"),
                  value: SettingsService.to.app.enableBackgroundPlay,
                  onChanged: (val) async {
                    SettingsService.to.app.enableBackgroundPlay.v = val;
                    if (val && Platform.isAndroid) {
                      bool hasPermission = await LiveAudioService.requestPlatformPermissions();
                      SettingsService.to.app.enableBackgroundPlay.v = hasPermission;
                    }
                  },
                ),
              ),
            context.buildSwitchTile(
              title: i18n("exit_float_window"),
              subtitle: i18n("exit_float_window_subtitle"),
              value: SettingsService.to.player.floatPlay,
              icon: Remix.picture_in_picture_2_line,
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
