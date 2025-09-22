import 'dart:io';

import 'package:flex_color_picker/flex_color_picker.dart';
import 'package:get/get.dart';
import 'package:pure_live/common/index.dart';
import 'package:pure_live/common/widgets/settings/settings_card_v2.dart';
import 'package:pure_live/common/widgets/settings/settings_list_item.dart';
import 'package:pure_live/common/widgets/utils.dart';
import 'package:pure_live/modules/auth/utils/constants.dart';
import 'package:pure_live/modules/backup/backup_page.dart';
import 'package:pure_live/modules/settings/danmuset.dart';
import 'package:pure_live/modules/util/rx_util.dart';
import 'package:pure_live/modules/util/site_logo_widget.dart';
import 'package:pure_live/modules/util/time_util.dart';
import 'package:pure_live/plugins/cache_to_file.dart';
import 'package:pure_live/plugins/file_recover_utils.dart';

class SettingsPage extends GetView<SettingsService> {
  const SettingsPage({super.key});

  BuildContext get context => Get.context!;

  @override
  Widget build(BuildContext context) {
    double screenWidth = MediaQuery.of(context).size.width;
    return Scaffold(
      appBar: AppBar(
        scrolledUnderElevation: screenWidth > 640 ? 0 : null,
        title: Text(S.current.settings_title),
      ),
      body: ListView(
        physics: const BouncingScrollPhysics(),
        children: <Widget>[
          SectionTitle(title: S.current.general),
          SettingsListItem(
            leading: const Icon(Icons.dark_mode_rounded, size: 32),
            title: Text(S.current.change_theme_mode),
            subtitle: Text(S.current.change_theme_mode_subtitle),
            onTap: showThemeModeSelectorDialog,
          ),
          SettingsListItem(
            leading: const Icon(Icons.color_lens, size: 32),
            title: Text(S.current.change_theme_color),
            subtitle: Text(S.current.change_theme_color_subtitle),
            trailing: ColorIndicator(
              width: 44,
              height: 44,
              borderRadius: 4,
              color: HexColor(controller.themeColorSwitch.value),
              onSelectFocus: false,
            ),
            onTap: colorPickerDialog,
          ),
          SettingsListItem(
            leading: const Icon(Icons.translate_rounded, size: 32),
            title: Text(S.current.change_language),
            subtitle: Text(S.current.change_language_subtitle),
            onTap: showLanguageSelecterDialog,
          ),
          SettingsListItem(
            leading: const Icon(Icons.backup_rounded, size: 32),
            title: Text(S.current.backup_recover),
            subtitle: Text(S.current.backup_recover_subtitle),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const BackupPage()),
            ),
          ),
          SectionTitle(title: S.current.video),
          Obx(() => SwitchListTile(
                title: Text(S.current.enable_background_play),
                subtitle: Text(S.current.enable_background_play_subtitle),
                value: controller.enableBackgroundPlay.value,
                activeThumbColor: Theme.of(context).colorScheme.primary,
                onChanged: (bool value) => controller.enableBackgroundPlay.value = value,
              )),
          if (Platform.isAndroid)
            Obx(() => SwitchListTile(
                  title: Text(S.current.auto_rotate_screen),
                  subtitle: Text(S.current.auto_rotate_screen_info),
                  value: controller.enableRotateScreenWithSystem.value,
                  activeThumbColor: Theme.of(context).colorScheme.primary,
                  onChanged: (bool value) => controller.enableRotateScreenWithSystem.value = value,
                )),
          Obx(() => SwitchListTile(
                title: Text(S.current.enable_screen_keep_on),
                subtitle: Text(S.current.enable_screen_keep_on_subtitle),
                value: controller.enableScreenKeepOn.value,
                activeThumbColor: Theme.of(context).colorScheme.primary,
                onChanged: (bool value) => controller.enableScreenKeepOn.value = value,
              )),
          Obx(() => SwitchListTile(
                title: Text(S.current.enable_fullscreen_default),
                subtitle: Text(S.current.enable_fullscreen_default_subtitle),
                value: controller.enableFullScreenDefault.value,
                activeThumbColor: Theme.of(context).colorScheme.primary,
                onChanged: (bool value) => controller.enableFullScreenDefault.value = value,
              )),
          SettingsListItem(
            title: Text(S.current.prefer_resolution),
            subtitle: Text(S.current.prefer_resolution_subtitle),
            onTap: showPreferResolutionSelectorDialog,
          ),
          SectionTitle(title: S.current.custom),
          Obx(() => SwitchListTile(
                title: Text(S.current.enable_dynamic_color),
                subtitle: Text(S.current.enable_dynamic_color_subtitle),
                value: controller.enableDynamicTheme.value,
                activeThumbColor: Theme.of(context).colorScheme.primary,
                onChanged: (bool value) => controller.enableDynamicTheme.value = value,
              )),
          Obx(() => SwitchListTile(
                title: Text(S.current.enable_dense_favorites_mode),
                subtitle: Text(S.current.enable_dense_favorites_mode_subtitle),
                value: controller.enableDenseFavorites.value,
                activeThumbColor: Theme.of(context).colorScheme.primary,
                onChanged: (bool value) => controller.enableDenseFavorites.value = value,
              )),
          Obx(() => SwitchListTile(
                title: Text(S.current.enable_auto_check_update),
                subtitle: Text(S.current.enable_auto_check_update_subtitle),
                value: controller.enableAutoCheckUpdate.value,
                activeThumbColor: Theme.of(context).colorScheme.primary,
                onChanged: (bool value) => controller.enableAutoCheckUpdate.value = value,
              )),
          SettingsListItem(
            title: Text(S.current.prefer_platform),
            subtitle: Text(S.current.prefer_platform_subtitle),
            onTap: showPreferPlatformSelectorDialog,
          ),
          SettingsListItem(
            title: Text(S.current.auto_refresh_time),
            subtitle: Text(S.current.auto_refresh_time_subtitle),
            trailing: Obx(() => Text(TimeUtil.minuteValueToStr(controller.autoRefreshTime.value))),
            onTap: showAutoRefreshTimeSetDialog,
          ),
          SettingsListItem(
            title: Text(S.current.settings_danmaku_title),
            onTap: showDanmuSetDialog,
          ),
          SettingsListItem(
            title: Text(S.current.danmu_filter),
            subtitle: Text(S.current.danmu_filter_info),
            onTap: () => Get.toNamed(RoutePath.kSettingsDanmuShield),
          ),
          SettingsListItem(
            title: Text(S.current.platform_settings),
            subtitle: Text(S.current.platform_settings_info),
            onTap: () => Get.toNamed(RoutePath.kSettingsHotAreas),
          ),
          if (Platform.isAndroid)
            Obx(() => SwitchListTile(
                  title: Text(S.current.double_click_to_exit),
                  value: controller.doubleExit.value,
                  activeThumbColor: Theme.of(context).colorScheme.primary,
                  onChanged: (bool value) => controller.doubleExit.value = value,
                )),
          // if (Platform.isAndroid)
          SettingsListItem(
            title: Text(S.current.change_player),
            subtitle: Text(S.current.change_player_subtitle),
            trailing: Obx(() => Text(controller.playerlist[controller.videoPlayerIndex.value])),
            onTap: showVideoSetDialog,
          ),
          if (Platform.isAndroid)
            Obx(() => SwitchListTile(
                  title: Text(S.current.enable_codec),
                  value: controller.enableCodec.value,
                  activeThumbColor: Theme.of(context).colorScheme.primary,
                  onChanged: (bool value) => controller.enableCodec.value = value,
                )),
          if (Platform.isAndroid)
            SettingsListItem(
              title: Text(S.current.auto_shutdown_time),
              subtitle: Text(S.current.auto_shutdown_time_subtitle),
              trailing: Obx(() => Text(TimeUtil.minuteValueToStr(controller.autoShutDownTime.value))),
              onTap: showAutoShutDownTimeSetDialog,
            ),
          SettingsListItem(
            title: Text(S.current.cache_manage),
            subtitle: Text(S.current.cache_manage),
            onTap: showCacheManageSetDialog,
          ),
        ],
      ),
    );
  }

  /// 主题模式
  static void showThemeModeSelectorDialog() {
    var controller = Get.find<SettingsService>();
    var context = Get.context!;
    Utils.showRightOrBottomSheet(
        title: S.current.change_theme_mode,
        child: ListView(children: [
          SettingsCardV2(
            children: SettingsService.themeModes.keys.map<Widget>((name) {
              return RadioListTile<String>(
                activeColor: Theme.of(context).colorScheme.primary,
                groupValue: controller.themeModeName.value,
                value: name,
                title: Text(SettingsService.getThemeTitle(name)),
                onChanged: (value) {
                  controller.changeThemeMode(value!);
                  Navigator.of(context).pop();
                },
              );
            }).toList(),
          )
        ]));
  }

  /// 主题颜色
  static Future<bool> colorPickerDialog() async {
    var controller = Get.find<SettingsService>();
    var context = Get.context!;
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
      heading: Text(
        S.current.change_theme_color,
        style: Theme.of(context).textTheme.titleMedium,
      ),
      subheading: Text(
        S.current.select_transparency,
        style: Theme.of(context).textTheme.titleMedium,
      ),
      wheelSubheading: Text(
        S.current.theme_color_and_transparency,
        style: Theme.of(context).textTheme.titleMedium,
      ),
      showMaterialName: false,
      showColorName: false,
      showColorCode: true,
      copyPasteBehavior: const ColorPickerCopyPasteBehavior(
        longPressMenu: true,
      ),
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

  /// 语言选择
  static void showLanguageSelecterDialog() {
    var controller = Get.find<SettingsService>();
    var context = Get.context!;
    Utils.showRightOrBottomSheet(
      title: S.current.change_language,
      child: ListView(
        children: [
          SettingsCardV2(
              children: SettingsService.languages.keys.map<Widget>((name) {
            return RadioListTile<String>(
              activeColor: Theme.of(context).colorScheme.primary,
              groupValue: controller.languageName.value,
              value: name,
              title: Text(name),
              onChanged: (value) {
                controller.changeLanguage(value!);
                Navigator.of(context).pop();
              },
            );
          }).toList())
        ],
      ),
    );
  }

  /// 视频播放器
  static void showVideoSetDialog() {
    var controller = Get.find<SettingsService>();
    var context = Get.context!;
    List<String> playerList = controller.playerlist;
    Utils.showRightOrBottomSheet(
      title: S.current.change_player,
      child: ListView(
        children: [
          SettingsCardV2(
              children: playerList.map<Widget>((name) {
            return RadioListTile<String>(
              activeColor: Theme.of(context).colorScheme.primary,
              groupValue: playerList[controller.videoPlayerIndex.value],
              value: name,
              title: Text(name),
              onChanged: (value) {
                controller.changePlayer(playerList.indexOf(name));
                Navigator.of(context).pop();
              },
            );
          }).toList())
        ],
      ),
    );
  }

  /// 直播 清晰度
  static void showPreferResolutionSelectorDialog() {
    var controller = Get.find<SettingsService>();
    var context = Get.context!;
    Utils.showRightOrBottomSheet(
      title: S.current.prefer_resolution,
      child: ListView(
        children: [
          SettingsCardV2(
              children: SettingsService.resolutions.map<Widget>((name) {
            return RadioListTile<String>(
              activeColor: Theme.of(context).colorScheme.primary,
              groupValue: controller.preferResolution.value,
              value: name,
              title: Text(name),
              onChanged: (value) {
                controller.changePreferResolution(value!);
                Navigator.of(context).pop();
              },
            );
          }).toList())
        ],
      ),
    );
  }

  /// 平台选择
  static void showPreferPlatformSelectorDialog() {
    var controller = Get.find<SettingsService>();
    var context = Get.context!;
    Utils.showRightOrBottomSheet(
      title: S.current.prefer_platform,
      child: ListView(
        children: [
          SettingsCardV2(
              children: Sites.supportSites.map<Widget>((site) {
            return RadioListTile<String>(
              activeColor: Theme.of(context).colorScheme.primary,
              groupValue: controller.preferPlatform.value,
              value: site.id,
              title: Row(
                children: <Widget>[
                  Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: SiteWidget.getSiteLogeImage(site.id), // 替换为你的图片路径
                  ),
                  Expanded(
                    child: Text(
                      Sites.getSiteName(site.id), // 替换为你的文本
                    ),
                  ),
                ],
              ),
              onChanged: (value) {
                controller.changePreferPlatform(value!);
                Navigator.of(context).pop();
              },
            );
          }).toList())
        ],
      ),
    );
  }

  /// 定时更新关注
  static void showAutoRefreshTimeSetDialog() {
    var controller = Get.find<SettingsService>();
    // var context = Get.context!;
    Utils.showRightOrBottomSheet(
      title: S.current.auto_refresh_time,
      child: Obx(() => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Slider(
                min: 0,
                max: 120,
                label: S.current.auto_refresh_time,
                value: controller.autoRefreshTime.toDouble(),
                onChanged: (value) => controller.autoRefreshTime.value = value.toInt(),
              ),
              Text('${S.current.auto_refresh_time}:'
                  ' ${TimeUtil.minuteValueToStr(controller.autoRefreshTime.value)}'),
            ],
          )),
    );
  }

  /// 弹幕设置
  static void showDanmuSetDialog({bool isFull = true}) {
    var controller = Get.find<SettingsService>();
    // var context = Get.context!;
    Utils.showRightOrBottomSheet(
      isFull: isFull,
      title: S.current.settings_danmaku_title,
      child: ListView(
        // shrinkWrap: true,
        padding: const EdgeInsets.all(8),
        children: [
          VideoFitSetting(
            controller: controller,
          ),
          const SizedBox(
            height: 10,
          ),
          DanmakuSetting(
            controller: controller,
          ),
          const SizedBox(
            height: 20,
          ),
        ],
      ),
    );
  }

  /// 定时关闭 app
  static void showAutoShutDownTimeSetDialog() {
    var controller = Get.find<SettingsService>();
    var context = Get.context!;
    Utils.showRightOrBottomSheet(
      title: S.current.auto_shutdown_time,
      child: Obx(() => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SwitchListTile(
                title: Text(S.current.auto_shutdown_time_subtitle),
                value: controller.enableAutoShutDownTime.value,
                activeColor: Theme.of(context).colorScheme.primary,
                onChanged: (bool value) => controller.enableAutoShutDownTime.value = value,
              ),
              Slider(
                min: 1,
                max: 1200,
                label: S.current.auto_shutdown_time,
                value: controller.autoShutDownTime.toDouble(),
                onChanged: (value) {
                  controller.autoShutDownTime.value = value.toInt();
                },
              ),
              Text('${S.current.auto_shutdown_time}:'
                  ' ${TimeUtil.minuteValueToStr(controller.autoShutDownTime.value)}'),
            ],
          )),
    );
  }

  /// Web 端口
  static Future<String?> showWebPortDialog() async {
    var controller = Get.find<SettingsService>();
    var context = Get.context!;
    final TextEditingController textEditingController = TextEditingController();
    textEditingController.text = controller.webPort.value;
    var result = await Get.dialog(
        AlertDialog(
          title: const Text('请输入端口号'),
          content: SizedBox(
            width: 400.0,
            height: 140.0,
            child: Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Column(
                children: [
                  TextField(
                    controller: textEditingController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.all(12),
                      hintText: '端口地址(1-65535)',
                    ),
                  ),
                  spacer(20.0),
                  Obx(() => SwitchListTile(
                        title: const Text('是否开启web服务'),
                        value: controller.webPortEnable.value,
                        activeColor: Theme.of(context).colorScheme.primary,
                        onChanged: (bool value) {
                          controller.webPortEnable.value = value;
                        },
                      )),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () async {
                if (controller.webPortEnable.value) {
                  SmartDialog.showToast('请先关闭web服务');
                  return;
                }
                if (textEditingController.text.isEmpty) {
                  SmartDialog.showToast('请输入端口号');
                  return;
                }
                bool validate = FileRecoverUtils.isPort(textEditingController.text);
                if (!validate) {
                  SmartDialog.showToast('请输入正确的端口号');
                  return;
                }
                if (int.parse(textEditingController.text) < 1 || int.parse(textEditingController.text) > 65535) {
                  SmartDialog.showToast('请输入正确的端口号');
                  return;
                }
                controller.webPort.value = textEditingController.text;
                SmartDialog.showToast('设置成功');
              },
              child: const Text("确定"),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(Get.context!).pop();
              },
              child: const Text("关闭弹窗"),
            ),
          ],
        ),
        barrierDismissible: false);
    return result;
  }

  /// 缓存管理
  static Future<void> showCacheManageSetDialog() async {
    // var controller = Get.find<SettingsService>();
    var cacheDirectorySize = "0 B".obs;
    void getCacheDirectorySize() {
      Future.delayed(const Duration(seconds: 1)).then((value) {
        CustomCache.instance.getCacheDirectorySize().then((value) => cacheDirectorySize.updateValueNotEquate(value));
      });
    }

    getCacheDirectorySize();

    var imageCacheDirectorySize = "0 B".obs;
    void getImageCacheDirectorySize() {
      Future.delayed(const Duration(seconds: 1)).then((value) {
        CustomCache.instance.getImageCacheDirectorySize().then((value) => imageCacheDirectorySize.updateValueNotEquate(value));
      });
    }

    getImageCacheDirectorySize();

    var areaCacheDirectorySize = "0 B".obs;
    void getAreaCacheDirectorySize() {
      Future.delayed(const Duration(seconds: 1)).then((value) {
        CustomCache.instance.getAreaCacheDirectorySize().then((value) => areaCacheDirectorySize.updateValueNotEquate(value));
      });
    }

    getAreaCacheDirectorySize();

    Utils.showRightOrBottomSheet(
        title: S.current.cache_manage,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          SettingsCardV2(
            children: [
              SettingsListItem(
                leading: const Icon(Icons.cleaning_services_outlined),
                title: Text(S.current.cache_manage_clear_all),
                subtitle: Obx(() => Text(cacheDirectorySize.value)),
                onTap: () async {
                  var result = await Utils.showAlertDialog(S.current.cache_manage_clear_prompt, title: S.current.cache_manage_clear_all);
                  if (result) {
                    CustomCache.instance.deleteCacheDirectory();
                    getCacheDirectorySize();
                    getImageCacheDirectorySize();
                    getAreaCacheDirectorySize();
                  }
                },
              ),
              SettingsListItem(
                leading: const Icon(Icons.cleaning_services_outlined),
                title: Text(S.current.cache_manage_clear_image),
                subtitle: Obx(() => Text(imageCacheDirectorySize.value)),
                onTap: () async {
                  var result = await Utils.showAlertDialog(S.current.cache_manage_clear_prompt, title: S.current.cache_manage_clear_image);
                  if (result) {
                    CustomCache.instance.deleteImageCacheDirectory();
                    getCacheDirectorySize();
                    getImageCacheDirectorySize();
                  }
                },
              ),
              SettingsListItem(
                leading: const Icon(Icons.cleaning_services_outlined),
                title: Text(S.current.cache_manage_clear_area),
                // subtitle: Text(areaCacheDirectorySize),
                subtitle: Obx(() => Text(areaCacheDirectorySize.value)),
                onTap: () async {
                  var result = await Utils.showAlertDialog(S.current.cache_manage_clear_prompt, title: S.current.cache_manage_clear_area);
                  if (result) {
                    CustomCache.instance.deleteAreaCacheDirectory();
                    getCacheDirectorySize();
                    getAreaCacheDirectorySize();
                  }
                },
              ),
            ],
          ),
        ]));
  }
}
