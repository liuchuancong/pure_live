import 'dart:io';
import 'package:get/get.dart';
import 'package:pure_live/common/index.dart';
import 'package:pure_live/player/player_consts.dart';
import 'package:url_launcher/url_launcher_string.dart';
import 'package:pure_live/common/consts/app_consts.dart';
import 'package:flex_color_picker/flex_color_picker.dart';
import 'package:pure_live/modules/backup/backup_page.dart';
import 'package:pure_live/modules/settings/settings_card.dart';
import 'package:pure_live/modules/settings/settings_menu.dart';
import 'package:pure_live/player/switchable_global_player.dart';
import 'package:pure_live/modules/settings/settings_switch.dart';
import 'package:pure_live/common/global/platform/background_server.dart';

class SettingsPage extends GetView<SettingsService> {
  const SettingsPage({super.key});

  BuildContext get context => Get.context!;

  @override
  Widget build(BuildContext context) {
    double screenWidth = MediaQuery.of(context).size.width;
    return Scaffold(
      appBar: AppBar(scrolledUnderElevation: screenWidth > 640 ? 0 : null, title: Text(S.of(context).settings_title)),
      body: ListView(
        physics: const BouncingScrollPhysics(),
        children: <Widget>[
          SectionTitle(title: S.of(context).general),
          if (Platform.isWindows)
            Obx(
              () => SwitchListTile(
                title: Text('开机启动'),
                subtitle: Text('应用将在每次开机时自动启动'),
                value: controller.enableStartUp.value,
                activeThumbColor: Theme.of(context).colorScheme.primary,
                onChanged: (bool value) => controller.enableStartUp.value = value,
              ),
            ),
          if (Platform.isWindows)
            Obx(
              () => SwitchListTile(
                title: Text('退出每次询问'),
                subtitle: Text('应用将在每次退出时不再询问是否退出'),
                value: controller.dontAskExit.value,
                activeThumbColor: Theme.of(context).colorScheme.primary,
                onChanged: (bool value) => controller.dontAskExit.value = value,
              ),
            ),
          Obx(
            () => SwitchListTile(
              title: Text('展示启动页'),
              subtitle: Text("应用启动后是否显示启动页"),
              value: controller.showSplashPage.value,
              activeThumbColor: Theme.of(context).colorScheme.primary,
              onChanged: (bool value) => controller.showSplashPage.value = value,
            ),
          ),
          ListTile(
            leading: const Icon(Icons.dark_mode_rounded, size: 32),
            title: Text(S.of(context).change_theme_mode),
            subtitle: Text(S.of(context).change_theme_mode_subtitle),
            onTap: showThemeModeSelectorDialog,
          ),
          ListTile(
            leading: const Icon(Icons.color_lens, size: 32),
            title: Text(S.of(context).change_theme_color),
            subtitle: Text(S.of(context).change_theme_color_subtitle),
            trailing: ColorIndicator(
              width: 44,
              height: 44,
              borderRadius: 4,
              color: HexColor(controller.themeColorSwitch.value),
              onSelectFocus: false,
            ),
            onTap: colorPickerDialog,
          ),
          ListTile(
            leading: const Icon(Icons.translate_rounded, size: 32),
            title: Text(S.of(context).change_language),
            subtitle: Text(S.of(context).change_language_subtitle),
            onTap: showLanguageSelecterDialog,
          ),
          StreamBuilder<double>(
            stream: CustomCacheManager.cacheSizeStream,
            builder: (context, snapshot) {
              final size = snapshot.data ?? 0.0;
              return ListTile(
                leading: const Icon(Icons.download_for_offline_rounded, size: 32),
                title: Text("当前缓存大小: ${size.toStringAsFixed(2)} MB"),
                onTap: CustomCacheManager.clearCache,
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.backup_rounded, size: 32),
            title: Text(S.of(context).backup_recover),
            subtitle: Text(S.of(context).backup_recover_subtitle),
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const BackupPage())),
          ),
          SectionTitle(title: S.of(context).video),
          Obx(
            () => SwitchListTile(
              title: Text('退出小窗播放'),
              subtitle: Text("应用退出时是否关闭小窗播放"),
              value: controller.floatPlay.value,
              activeThumbColor: Theme.of(context).colorScheme.primary,
              onChanged: (bool value) => controller.floatPlay.value = value,
            ),
          ),
          if (Platform.isAndroid)
            Obx(
              () => ListTile(
                title: Text('视频播放器'),
                subtitle: Text('选择视频播放器'),
                onTap: showVideoSetDialog,
                trailing: Text(controller.videoPlayerIndex.value == 0 ? 'Mpv播放器' : 'IJK播放器'),
              ),
            ),
          Obx(
            () => SwitchListTile(
              title: Text(S.of(context).enable_codec),
              value: controller.enableCodec.value,
              activeThumbColor: Theme.of(context).colorScheme.primary,
              onChanged: (bool value) => controller.enableCodec.value = value,
            ),
          ),
          if (Platform.isAndroid && controller.videoPlayerIndex.value == 0)
            Obx(
              () => SwitchListTile(
                title: Text('兼容模式'),
                subtitle: Text('若播放卡顿可尝试打开此选项'),
                value: controller.playerCompatMode.value,
                activeThumbColor: Theme.of(context).colorScheme.primary,
                onChanged: (bool value) => controller.playerCompatMode.value = value,
              ),
            ),
          if (Platform.isAndroid)
            Obx(
              () => SwitchListTile(
                title: Text(S.of(context).enable_background_play),
                subtitle: Text(S.of(context).enable_background_play_subtitle),
                value: controller.enableBackgroundPlay.value,
                activeThumbColor: Theme.of(context).colorScheme.primary,
                onChanged: (bool value) async {
                  controller.enableBackgroundPlay.value = value;
                  if (Platform.isAndroid && value) {
                    bool hasPermission = await BackgroundService.requestPlatformPermissions();
                    if (!hasPermission) {
                      SmartDialog.showToast("如果需要后台播放，建议开启此权限");
                    }
                    controller.enableBackgroundPlay.value = hasPermission;
                  }
                },
              ),
            ),
          if (Platform.isAndroid)
            Obx(
              () => SwitchListTile(
                title: Text(S.of(context).enable_screen_keep_on),
                subtitle: Text(S.of(context).enable_screen_keep_on_subtitle),
                value: controller.enableScreenKeepOn.value,
                activeThumbColor: Theme.of(context).colorScheme.primary,
                onChanged: (bool value) => controller.enableScreenKeepOn.value = value,
              ),
            ),

          Obx(
            () => SwitchListTile(
              title: Text(S.of(context).enable_fullscreen_default),
              subtitle: Text(S.of(context).enable_fullscreen_default_subtitle),
              value: controller.enableFullScreenDefault.value,
              activeThumbColor: Theme.of(context).colorScheme.primary,
              onChanged: (bool value) => controller.enableFullScreenDefault.value = value,
            ),
          ),

          Obx(
            () => ListTile(
              title: Text(S.of(context).prefer_resolution),
              subtitle: Text(S.of(context).prefer_resolution_subtitle),
              trailing: Text(controller.preferResolution.value),
              onTap: showPreferResolutionSelectorDialog,
            ),
          ),
          if (Platform.isAndroid && controller.videoPlayerIndex.value == 0)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Text("播放器高级设置", style: Get.textTheme.titleMedium),
            ),
          if (Platform.isAndroid && controller.videoPlayerIndex.value == 0)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Text.rich(
                TextSpan(
                  text: "请勿随意修改以下设置，除非你知道自己在做什么。\n在修改以下设置前，你应该先查阅",
                  children: [
                    WidgetSpan(
                      child: GestureDetector(
                        onTap: () {
                          launchUrlString("https://mpv.io/manual/stable/#video-output-drivers");
                        },
                        child: const Text(
                          "MPV的文档",
                          style: TextStyle(color: Colors.blue, fontSize: 12, decoration: TextDecoration.underline),
                        ),
                      ),
                    ),
                  ],
                ),
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ),
          SettingsCard(
            child: Column(
              children: [
                Obx(
                  () => SettingsSwitch(
                    value: controller.customPlayerOutput.value,
                    title: "自定义输出驱动与硬件加速",
                    onChanged: (e) {
                      controller.customPlayerOutput.value = e;
                    },
                  ),
                ),
                Obx(
                  () => SettingsMenu(
                    title: "视频输出驱动(--vo)",
                    value: controller.videoOutputDriver.value,
                    valueMap: PlayerConsts.videoOutputDrivers,
                    onChanged: (e) {
                      controller.videoOutputDriver.value = e;
                    },
                  ),
                ),
                Obx(
                  () => SettingsMenu(
                    title: "音频输出驱动(--ao)",
                    value: controller.audioOutputDriver.value,
                    valueMap: PlayerConsts.audioOutputDrivers,
                    onChanged: (e) {
                      controller.audioOutputDriver.value = e;
                    },
                  ),
                ),
                Obx(
                  () => SettingsMenu(
                    title: "硬件解码器(--hwdec)",
                    value: controller.videoHardwareDecoder.value,
                    valueMap: PlayerConsts.hardwareDecoder,
                    onChanged: (e) {
                      controller.videoHardwareDecoder.value = e;
                    },
                  ),
                ),
              ],
            ),
          ),

          SectionTitle(title: S.of(context).custom),
          Obx(
            () => SwitchListTile(
              title: Text(S.of(context).enable_dynamic_color),
              subtitle: Text(S.of(context).enable_dynamic_color_subtitle),
              value: controller.enableDynamicTheme.value,
              activeThumbColor: Theme.of(context).colorScheme.primary,
              onChanged: (bool value) => controller.enableDynamicTheme.value = value,
            ),
          ),
          Obx(
            () => SwitchListTile(
              title: Text(S.of(context).enable_dense_favorites_mode),
              subtitle: Text(S.of(context).enable_dense_favorites_mode_subtitle),
              value: controller.enableDenseFavorites.value,
              activeThumbColor: Theme.of(context).colorScheme.primary,
              onChanged: (bool value) => controller.enableDenseFavorites.value = value,
            ),
          ),
          Obx(
            () => SwitchListTile(
              title: Text(S.of(context).enable_auto_check_update),
              subtitle: Text(S.of(context).enable_auto_check_update_subtitle),
              value: controller.enableAutoCheckUpdate.value,
              activeThumbColor: Theme.of(context).colorScheme.primary,
              onChanged: (bool value) => controller.enableAutoCheckUpdate.value = value,
            ),
          ),
          ListTile(
            title: Text(S.of(context).prefer_platform),
            subtitle: Text(S.of(context).prefer_platform_subtitle),
            onTap: showPreferPlatformSelectorDialog,
          ),
          ListTile(
            title: Text(S.of(context).auto_refresh_time),
            subtitle: Text(S.of(context).auto_refresh_time_subtitle),
            trailing: Obx(() => Text('${controller.autoRefreshTime}分钟')),
            onTap: showAutoRefreshTimeSetDialog,
          ),
          ListTile(
            title: const Text("弹幕过滤"),
            subtitle: const Text("自定义关键词过滤弹幕"),
            onTap: () => Get.toNamed(RoutePath.kSettingsDanmuShield),
          ),
          ListTile(
            title: const Text("平台设置"),
            subtitle: const Text("自定义观看喜爱的平台"),
            onTap: () => Get.toNamed(RoutePath.kSettingsHotAreas),
          ),
          if (Platform.isAndroid)
            ListTile(
              title: Text(S.of(context).auto_shutdown_time),
              subtitle: Text(S.of(context).auto_shutdown_time_subtitle),
              trailing: Obx(() => Text('${controller.autoShutDownTime} minute')),
              onTap: showAutoShutDownTimeSetDialog,
            ),
        ],
      ),
    );
  }

  void showThemeModeSelectorDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return SimpleDialog(
          title: Text(S.of(Get.context!).change_theme_mode),
          children: [
            RadioGroup<String>(
              groupValue: controller.themeModeName.value,
              onChanged: (String? value) {
                controller.changeThemeMode(value!);
                Navigator.of(context).pop();
              },
              child: Padding(
                padding: const EdgeInsets.only(top: 0, bottom: 10, left: 16, right: 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: AppConsts.themeModes.keys.map<Widget>((name) {
                    return Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Radio(value: name, activeColor: Theme.of(Get.context!).colorScheme.primary),
                        GestureDetector(
                          onTap: () {
                            controller.changeThemeMode(name);
                            Navigator.of(context).pop();
                          },
                          child: Text(name, style: Theme.of(context).textTheme.bodyLarge),
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

  Future<bool> colorPickerDialog() async {
    return ColorPicker(
      color: HexColor(controller.themeColorSwitch.value),
      onColorChanged: (Color color) {
        controller.themeColorSwitch.value = color.hex;
        var themeColor = color;
        var lightTheme = MyTheme(primaryColor: themeColor).lightThemeData;
        var darkTheme = MyTheme(primaryColor: themeColor).darkThemeData;
        Get.changeTheme(lightTheme);
        Get.changeTheme(darkTheme);
      },
      width: 40,
      height: 40,
      borderRadius: 4,
      spacing: 5,
      runSpacing: 5,
      wheelDiameter: 155,
      heading: Text('主题颜色', style: Theme.of(context).textTheme.titleMedium),
      subheading: Text('选择透明度', style: Theme.of(context).textTheme.titleMedium),
      wheelSubheading: Text('主题颜色及透明度', style: Theme.of(context).textTheme.titleMedium),
      showMaterialName: false,
      showColorName: false,
      showColorCode: true,
      copyPasteBehavior: const ColorPickerCopyPasteBehavior(longPressMenu: true),
      materialNameTextStyle: Theme.of(context).textTheme.bodySmall,
      colorNameTextStyle: Theme.of(context).textTheme.bodySmall,
      colorCodeTextStyle: Theme.of(context).textTheme.bodyMedium,
      colorCodePrefixStyle: Theme.of(context).textTheme.bodySmall,
      selectedPickerTypeColor: Theme.of(context).colorScheme.primary,
      customColorSwatchesAndNames: controller.colorsNameMap,
      pickersEnabled: const <ColorPickerType, bool>{
        ColorPickerType.both: false,
        ColorPickerType.primary: true,
        ColorPickerType.accent: true,
        ColorPickerType.bw: false,
        ColorPickerType.custom: true,
        ColorPickerType.wheel: true,
      },
      // customColorSwatchesAndNames: colorsNameMap,
    ).showPickerDialog(
      context,
      actionsPadding: const EdgeInsets.all(16),
      constraints: const BoxConstraints(minHeight: 480, minWidth: 375, maxWidth: 420),
    );
  }

  void showLanguageSelecterDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return SimpleDialog(
          title: Text(S.of(context).change_language),
          children: [
            RadioGroup<String>(
              groupValue: controller.languageName.value,
              onChanged: (String? value) {
                if (value != null) {
                  controller.changeLanguage(value);
                  Navigator.of(context).pop();
                }
              },
              child: Padding(
                padding: const EdgeInsets.only(top: 0, bottom: 10, left: 16, right: 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: AppConsts.languages.keys.map<Widget>((name) {
                    return Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Radio<String>(value: name, activeColor: Theme.of(context).colorScheme.primary),
                        GestureDetector(
                          onTap: () {
                            controller.changeLanguage(name);
                            Navigator.of(context).pop();
                          },
                          child: Text(name, style: Theme.of(context).textTheme.bodyLarge),
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

  void showVideoSetDialog() {
    List<String> playerList = controller.playerlist;
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return SimpleDialog(
          title: Text(S.of(context).change_player),
          children: [
            RadioGroup<String>(
              groupValue: playerList[controller.videoPlayerIndex.value],
              onChanged: (String? value) {
                if (value != null) {
                  controller.changePlayer(playerList.indexOf(value));
                  SwitchableGlobalPlayer().switchEngine(PlayerEngine.values[controller.videoPlayerIndex.value]);
                  Navigator.of(context).pop();
                }
              },
              child: Padding(
                padding: const EdgeInsets.only(top: 0, bottom: 10, left: 16, right: 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: playerList.map<Widget>((name) {
                    return Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Radio<String>(value: name, activeColor: Theme.of(context).colorScheme.primary),
                        GestureDetector(
                          onTap: () {
                            controller.changePlayer(playerList.indexOf(name));
                            SwitchableGlobalPlayer().switchEngine(
                              PlayerEngine.values[controller.videoPlayerIndex.value],
                            );
                            Navigator.of(context).pop();
                          },
                          child: Text(name, style: Theme.of(context).textTheme.bodyLarge),
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

  void showPreferResolutionSelectorDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return SimpleDialog(
          title: Text(S.of(context).prefer_resolution),
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
                          child: Text(name, style: Theme.of(context).textTheme.bodyLarge),
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

  void showPreferPlatformSelectorDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return SimpleDialog(
          title: Text(S.of(context).prefer_platform),
          children: [
            RadioGroup<String>(
              groupValue: controller.preferPlatform.value,
              onChanged: (String? value) {
                if (value != null) {
                  controller.changePreferPlatform(value);
                  Navigator.of(context).pop();
                }
              },
              child: Padding(
                padding: const EdgeInsets.only(top: 0, bottom: 10, left: 16, right: 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: AppConsts.platforms.map<Widget>((name) {
                    return Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Radio<String>(value: name, activeColor: Theme.of(context).colorScheme.primary),
                        GestureDetector(
                          onTap: () {
                            controller.changePreferPlatform(name);
                            Navigator.of(context).pop();
                          },
                          child: Text(name.toUpperCase(), style: Theme.of(context).textTheme.bodyLarge),
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

  void showAutoRefreshTimeSetDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        // title: Text(S.of(context).auto_refresh_time),
        content: Obx(
          () => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Slider(
                min: 0,
                max: 120,
                label: S.of(context).auto_refresh_time,
                value: controller.autoRefreshTime.toDouble(),
                onChanged: (value) => controller.autoRefreshTime.value = value.toInt(),
              ),
              Text(
                '${S.of(context).auto_refresh_time}:'
                ' ${controller.autoRefreshTime}分钟',
              ),
            ],
          ),
        ),
      ),
    );
  }

  void showAutoShutDownTimeSetDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        // title: Text(S.of(context).auto_refresh_time),
        content: Obx(
          () => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SwitchListTile(
                title: Text(S.of(context).auto_shutdown_time_subtitle),
                value: controller.enableAutoShutDownTime.value,
                activeThumbColor: Theme.of(context).colorScheme.primary,
                onChanged: (bool value) => controller.enableAutoShutDownTime.value = value,
              ),
              Slider(
                min: 1,
                max: 1200,
                label: S.of(context).auto_refresh_time,
                value: controller.autoShutDownTime.toDouble(),
                onChanged: (value) {
                  controller.autoShutDownTime.value = value.toInt();
                },
              ),
              Text(
                '${S.of(context).auto_shutdown_time}:'
                ' ${controller.autoShutDownTime} minute',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
