import 'dart:io';

import 'package:flex_color_picker/flex_color_picker.dart';
import 'package:get/get.dart';
import 'package:pure_live/common/index.dart';
import 'package:pure_live/common/widgets/app_style.dart';
import 'package:pure_live/common/widgets/settings/settings_card_v2.dart';
import 'package:pure_live/common/widgets/settings/settings_list_item.dart';
import 'package:pure_live/common/widgets/settings/settings_switch.dart';
import 'package:pure_live/common/widgets/utils.dart';
import 'package:pure_live/modules/backup/backup_page.dart';
import 'package:pure_live/modules/hot_areas/hot_areas_controller.dart';
import 'package:pure_live/modules/live_play/danmaku/danmaku_controller_factory.dart';
import 'package:pure_live/modules/settings/settings_page.dart';
import 'package:pure_live/modules/util/site_logo_widget.dart';
import 'package:pure_live/modules/util/time_util.dart';
import 'package:pure_live/plugins/extension/list_extension.dart';
import 'package:remixicon/remixicon.dart';

class SettingsPageV2 extends GetView<SettingsService> {
  const SettingsPageV2({super.key});

  BuildContext get context => Get.context!;

  @override
  Widget build(BuildContext context) {
    double screenWidth = MediaQuery.of(context).size.width;
    return Scaffold(
      appBar: AppBar(
        scrolledUnderElevation: screenWidth > 640 ? 0 : null,
        title: Text(S.current.settings_title),
      ),
      body: ListView(physics: const BouncingScrollPhysics(), children: [
        SettingsCardV2(children: [
          // 外观设置
          SettingsListItem(
            leading: const Icon(Remix.moon_line),
            title: Text(S.current.settings_app),
            trailing: const Icon(
              Icons.chevron_right,
              color: Colors.grey,
            ),
            onTap: () {
              settingMineInfoSheet();
            },
          ),

          /// 主页设置
          SettingsListItem(
            leading: const Icon(Remix.home_2_line),
            title: Text(S.current.settings_home),
            trailing: const Icon(
              Icons.chevron_right,
              color: Colors.grey,
            ),
            onTap: () {
              settingHomeInfoSheet();
            },
          ),
          SettingsListItem(
            leading: const Icon(Remix.play_circle_line),
            title: Text(S.current.settings_player),
            trailing: const Icon(
              Icons.chevron_right,
              color: Colors.grey,
            ),
            onTap: () {
              settingPlayerInfoSheet();
            },
          ),

          /// 弹幕设置
          SettingsListItem(
            leading: const Icon(Remix.text),
            title: Text(S.current.settings_danmaku_title),
            trailing: const Icon(
              Icons.chevron_right,
              color: Colors.grey,
            ),
            onTap: () async {
              settingDanmakuInfoSheet();
            },
          ),
          SettingsListItem(
            leading: const Icon(Remix.heart_line),
            title: Text(S.current.settings_favorite),
            trailing: const Icon(
              Icons.chevron_right,
              color: Colors.grey,
            ),
            onTap: () {
              settingFavoriteInfoSheet();
            },
          ),
          SettingsListItem(
            leading: const Icon(Remix.timer_2_line),
            title: Text(S.current.settings_time_close),
            trailing: const Icon(
              Icons.chevron_right,
              color: Colors.grey,
            ),
            onTap: () {
              settingTimeCloseInfoSheet();
            },
          ),

          /// 其他设置
          SettingsListItem(
            leading: const Icon(Remix.apps_line),
            title: Text(S.current.settings_other),
            trailing: const Icon(
              Icons.chevron_right,
              color: Colors.grey,
            ),
            onTap: () {
              settingOtherInfoSheet();
            },
          ),

          /// 缓存设置
          SettingsListItem(
            leading: const Icon(Icons.delete_outline),
            title: Text(S.current.cache_manage),
            trailing: const Icon(
              Icons.chevron_right,
              color: Colors.grey,
            ),
            onTap: () {
              SettingsPage.showCacheManageSetDialog();
            },
          ),

          /// 日志设置
          SettingsListItem(
            leading: const Icon(Remix.bug_line),
            title: Text(S.current.settings_log),
            trailing: const Icon(
              Icons.chevron_right,
              color: Colors.grey,
            ),
            onTap: () {
              Get.toNamed(RoutePath.kLog);
            },
          ),
        ]),
      ]),
    );
  }

  /// 设置里的外观设置
  static void settingMineInfoSheet() async {
    var controller = SettingsService.instance;
    await Utils.showRightOrBottomSheet(
      title: S.current.settings_app,
      child: ListView(
          // shrinkWrap: true,
          children: [
            SettingsCardV2(children: [
              /// 外观主题设置
              SettingsListItem(
                leading: const Icon(Icons.dark_mode_rounded),
                title: Text(S.current.change_theme_mode),
                subtitle: Text(S.current.change_theme_mode_subtitle),
                onTap: () {
                  SettingsPage.showThemeModeSelectorDialog();
                },
              ),

              /// 外观主题颜色
              SettingsListItem(
                leading: const Icon(Icons.color_lens),
                title: Text(S.current.change_theme_color),
                subtitle: Text(S.current.change_theme_color_subtitle),
                trailing: ColorIndicator(
                  width: 44,
                  height: 44,
                  borderRadius: 4,
                  color: HexColor(SettingsService.instance.themeColorSwitch.value),
                  onSelectFocus: false,
                ),
                onTap: () {
                  SettingsPage.colorPickerDialog();
                },
              ),

              /// 外观 语言
              SettingsListItem(
                leading: const Icon(Icons.translate_rounded),
                title: Text(S.current.change_language),
                subtitle: Text(S.current.change_language_subtitle),
                onTap: () => SettingsPage.showLanguageSelecterDialog(),
              ),

              ///动态取色
              Obx(() => SettingsSwitch(
                    leading: const Icon(Icons.self_improvement),
                    title: Text(S.current.enable_dynamic_color),
                    subtitle: Text(S.current.enable_dynamic_color_subtitle),
                    value: controller.enableDynamicTheme.value,
                    onChanged: (bool value) => controller.enableDynamicTheme.value = value,
                  )),

              ///
            ])
          ]),
    );
  }

  /// 主页设置
  static void settingHomeInfoSheet() async {
    var controller = SettingsService.instance;
    await Utils.showRightOrBottomSheet(
      title: S.current.settings_home,
      child: ListView(
          // shrinkWrap: true,
          children: [
            SettingsCardV2(children: [
              /// 紧凑模式
              Obx(() => SettingsSwitch(
                    leading: const Icon(Icons.screenshot),
                    title: Text(S.current.enable_dense_favorites_mode),
                    subtitle: Text(S.current.enable_dense_favorites_mode_subtitle),
                    value: controller.enableDenseFavorites.value,
                    onChanged: (bool value) => controller.enableDenseFavorites.value = value,
                  )),

              /// 首选平台
              SettingsListItem(
                leading: const Icon(Icons.favorite),
                title: Text(S.current.prefer_platform),
                subtitle: Text(S.current.prefer_platform_subtitle),
                onTap: () {
                  SettingsPage.showPreferPlatformSelectorDialog();
                },
                trailing: const Icon(
                  Icons.chevron_right,
                  color: Colors.grey,
                ),
              ),

              /// 平台设置 平台显示
              SettingsListItem(
                leading: const Icon(Icons.show_chart_outlined),
                title: Text(S.current.platform_settings),
                subtitle: Text(S.current.platform_settings_info),
                onTap: () {
                  // SettingsPage.showPreferPlatformSelectorDialog();
                  showPlatformDialog();
                },
                trailing: const Icon(
                  Icons.chevron_right,
                  color: Colors.grey,
                ),
              ),

              /////
            ])
          ]),
    );
  }

  static void showPlatformDialog() async {
    await Utils.showRightOrBottomSheet(
        title: S.current.platform_settings_info,
        child: Obx(() => ListView(
                // shrinkWrap: true,
                children: [
                  SettingsCardV2(children: [
                    ///
                    ...Sites.supportSites
                        .map((site) {
                          var show = SettingsService.instance.hotAreasList.value.contains(site.id);
                          var area = HotAreasModel(id: site.id, name: site.name, show: show);
                          return area;
                        })
                        .map((site) {
                          return SettingsSwitch(
                              leading: SiteWidget.getSiteLogeImage(site.id)!,
                              title: Text(Sites.getSiteName(site.id)),
                              value: site.show,
                              onChanged: (bool value) {
                                var data = site.id.toString();
                                if (value) {
                                  if (!SettingsService.instance.hotAreasList.contains(data)) {
                                    SettingsService.instance.hotAreasList.add(data);
                                  }
                                } else {
                                  SettingsService.instance.hotAreasList.remove(data);
                                }
                                SmartDialog.showToast('重启后生效');
                              }) as StatelessWidget;
                        })
                        .toList()
                        .joinItem(AppStyle.divider)
                  ])
                ])));
  }

  /// 弹幕设置
  static void settingDanmakuInfoSheet() async {
    await Utils.showRightOrBottomSheet(
      title: S.current.settings_danmaku_title,
      child: ListView(
          // shrinkWrap: true,
          children: [
            SettingsCardV2(children: [
              /// 弹幕设置
              SettingsListItem(
                  leading: const Icon(Remix.text_wrap),
                  title: Text(S.current.settings_danmaku_title),
                  trailing: const Icon(
                    Icons.chevron_right,
                    color: Colors.grey,
                  ),
                  onTap: () async {
                    SettingsPage.showDanmuSetDialog();
                  }),

              /// 弹幕过滤
              SettingsListItem(
                  leading: const Icon(Remix.filter_off_line),
                  title: Text(S.current.danmu_filter),
                  trailing: const Icon(
                    Icons.chevron_right,
                    color: Colors.grey,
                  ),
                  onTap: () async {
                    Get.toNamed(RoutePath.kSettingsDanmuShield);
                  })
            ])
          ]),
    );
  }

  /// 关注设置
  static void settingFavoriteInfoSheet() async {
    var controller = SettingsService.instance;
    await Utils.showRightOrBottomSheet(
      title: S.current.settings_favorite,
      child: ListView(
          // shrinkWrap: true,
          children: [
            SettingsCardV2(children: [
              // 定时关闭设置
              SettingsListItem(
                leading: const Icon(Remix.timer_2_line),
                title: Text(S.current.auto_refresh_time),
                subtitle: Text(S.current.auto_refresh_time_subtitle),
                trailing: Obx(() => Text(TimeUtil.minuteValueToStr(controller.autoRefreshTime.value))),
                onTap: () {
                  SettingsPage.showAutoRefreshTimeSetDialog();
                },
              ),

              /////
            ])
          ]),
    );
  }

  /// 定时关闭设置
  static void settingTimeCloseInfoSheet() async {
    var controller = SettingsService.instance;
    await Utils.showRightOrBottomSheet(
      title: S.current.settings_time_close,
      child: ListView(
          // shrinkWrap: true,
          children: [
            SettingsCardV2(children: [
              // 定时关闭设置
              if (Platform.isAndroid)
                SettingsListItem(
                  leading: const Icon(Remix.timer_2_line),
                  title: Text(S.current.auto_shutdown_time),
                  subtitle: Text(S.current.auto_shutdown_time_subtitle),
                  trailing: Obx(() => Text(TimeUtil.minuteValueToStr(controller.autoShutDownTime.value))),
                  onTap: () {
                    SettingsPage.showAutoShutDownTimeSetDialog();
                  },
                ),

              /////
            ])
          ]),
    );
  }

  /// 直播设置
  static void settingPlayerInfoSheet() async {
    var controller = SettingsService.instance;
    await Utils.showRightOrBottomSheet(
      title: S.current.settings_player,
      child: ListView(
          // shrinkWrap: true,
          children: [
            SettingsCardV2(children: [
              Obx(() => SettingsSwitch(
                    leading: Icon(Icons.play_circle_outline_sharp),
                    title: Text(S.current.enable_background_play),
                    subtitle: Text(S.current.enable_background_play_subtitle),
                    value: controller.enableBackgroundPlay.value,
                    onChanged: (bool value) => controller.enableBackgroundPlay.value = value,
                  )),
              if (Platform.isAndroid)
                Obx(() => SettingsSwitch(
                      leading: Icon(Icons.currency_exchange_sharp),
                      title: Text(S.current.auto_rotate_screen),
                      subtitle: Text(S.current.auto_rotate_screen_info),
                      value: controller.enableRotateScreenWithSystem.value,
                      onChanged: (bool value) => controller.enableRotateScreenWithSystem.value = value,
                    )),
              Obx(() => SettingsSwitch(
                    leading: Icon(Icons.fiber_smart_record),
                    title: Text(S.current.enable_screen_keep_on),
                    subtitle: Text(S.current.enable_screen_keep_on_subtitle),
                    value: controller.enableScreenKeepOn.value,
                    onChanged: (bool value) => controller.enableScreenKeepOn.value = value,
                  )),
              Obx(() => SettingsSwitch(
                    leading: Icon(Icons.fullscreen),
                    title: Text(S.current.enable_fullscreen_default),
                    subtitle: Text(S.current.enable_fullscreen_default_subtitle),
                    value: controller.enableFullScreenDefault.value,
                    onChanged: (bool value) => controller.enableFullScreenDefault.value = value,
                  )),

              /// 清晰度
              SettingsListItem(
                leading: Icon(Icons.video_camera_back_outlined),
                title: Text(S.current.prefer_resolution),
                subtitle: Text(S.current.prefer_resolution_subtitle),
                onTap: () {
                  // SettingsPage.showPreferResolutionSelectorDialog();
                  showPreferBitRateSelectorDialog();
                },
                // trailing: Obx(() => Text(controller.preferResolution.value)),
                trailing: Obx(() => Text(controller.getBitRateName(controller.bitRate.value))),
              ),

              /// 移动网络清晰度
              SettingsListItem(
                leading: Icon(Icons.video_camera_back_outlined),
                title: Text(S.current.prefer_resolution_mobile),
                subtitle: Text(S.current.prefer_resolution_mobile_subtitle),
                onTap: () {
                  // showPreferResolutionMobileSelectorDialog();
                  showPreferBitRateMobileSelectorDialog();
                },
                // trailing: Obx(() => Text(controller.preferResolutionMobile.value)),
                trailing: Obx(() => Text(controller.getBitRateName(controller.bitRateMobile.value))),
              ),

              if (Platform.isAndroid)
                Obx(() => SettingsSwitch(
                      leading: const Icon(Icons.exit_to_app),
                      title: Text(S.current.double_click_to_exit),
                      value: controller.doubleExit.value,
                      onChanged: (bool value) => controller.doubleExit.value = value,
                    )),
              // if (Platform.isAndroid)
              /// 清晰度
              SettingsListItem(
                leading: const Icon(Icons.play_circle_outline_outlined),
                title: Text(S.current.change_player),
                subtitle: Text(S.current.change_player_subtitle),
                trailing: Obx(() => Text(controller.playerlist[controller.videoPlayerIndex.value])),
                onTap: () {
                  SettingsPage.showVideoSetDialog();
                },
              ),
              if (Platform.isAndroid)
                Obx(() => SettingsSwitch(
                      leading: const Icon(Icons.qr_code),
                      title: Text(S.current.enable_codec),
                      value: controller.enableCodec.value,
                      onChanged: (bool value) => controller.enableCodec.value = value,
                    )),

              /// 弹幕控制器
              SettingsListItem(
                leading: const Icon(CustomIcons.danmaku_open),
                title: Text(S.current.settings_danmuku_controller),
                subtitle: Text(S.current.settings_danmuku_controller_info),
                trailing: Obx(() => Text(controller.danmakuControllerType.value)),
                onTap: () {
                  showDanmakuControllerSelectorDialog();
                },
              ),
              /////
            ])
          ]),
    );
  }

  /// 其他设置
  static void settingOtherInfoSheet() async {
    var controller = SettingsService.instance;
    await Utils.showRightOrBottomSheet(
      title: S.current.settings_other,
      child: ListView(
          // shrinkWrap: true,
          children: [
            SettingsCardV2(children: [
              // 备份与恢复
              SettingsListItem(
                leading: const Icon(Icons.backup_rounded),
                title: Text(S.current.backup_recover),
                subtitle: Text(S.current.backup_recover_subtitle),
                trailing: const Icon(
                  Icons.chevron_right,
                  color: Colors.grey,
                ),
                onTap: () => Navigator.push(
                  Get.context!,
                  MaterialPageRoute(builder: (context) => const BackupPage()),
                ),
              ),

              Obx(() => SettingsSwitch(
                    leading: const Icon(Icons.update),
                    title: Text(S.current.enable_auto_check_update),
                    subtitle: Text(S.current.enable_auto_check_update_subtitle),
                    value: controller.enableAutoCheckUpdate.value,
                    onChanged: (bool value) => controller.enableAutoCheckUpdate.value = value,
                  )),

              /////
            ])
          ]),
    );
  }

  /// 直播 移动网络 清晰度
  static void showPreferResolutionMobileSelectorDialog() {
    var controller = Get.find<SettingsService>();
    var context = Get.context!;
    Utils.showRightOrBottomSheet(
      title: S.current.prefer_resolution_mobile,
      child: ListView(
        children: [
          SettingsCardV2(
              children: SettingsService.resolutions.map<Widget>((name) {
            return RadioListTile<String>(
              activeColor: Theme.of(context).colorScheme.primary,
              groupValue: controller.preferResolutionMobile.value,
              value: name,
              title: Text(name),
              onChanged: (value) {
                controller.changePreferResolutionMobile(value!);
                Navigator.of(context).pop();
              },
            );
          }).toList())
        ],
      ),
    );
  }

  /// 弹幕控制器
  static void showDanmakuControllerSelectorDialog() {
    var controller = Get.find<SettingsService>();
    var context = Get.context!;
    Utils.showRightOrBottomSheet(
      title: S.current.settings_danmuku_controller,
      child: ListView(
        children: [
          SettingsCardV2(
              children: DanmakuControllerfactory.getDanmakuControllerTypeList().map<Widget>((name) {
            return RadioListTile<String>(
              activeColor: Theme.of(context).colorScheme.primary,
              groupValue: controller.danmakuControllerType.value,
              value: name,
              title: Text(name),
              onChanged: (value) {
                controller.changeDanmakuController(value!);
                Navigator.of(context).pop();
              },
            );
          }).toList())
        ],
      ),
    );
  }

  // 码率
  static void showPreferBitRateSelectorDialog() {
    var controller = Get.find<SettingsService>();
    var context = Get.context!;
    Utils.showRightOrBottomSheet(
      title: S.current.prefer_resolution,
      child: ListView(
        children: [
          SettingsCardV2(
              children: controller.bitRateList.map<Widget>((name) {
            return RadioListTile<int>(
              activeColor: Theme.of(context).colorScheme.primary,
              groupValue: controller.bitRate.value,
              value: name,
              title: Text(controller.getBitRateName(name)),
              onChanged: (value) {
                controller.changeBitRate(value!);
                Navigator.of(context).pop();
              },
            );
          }).toList())
        ],
      ),
    );
  }

  // 码率 手机
  static void showPreferBitRateMobileSelectorDialog() {
    var controller = Get.find<SettingsService>();
    var context = Get.context!;
    Utils.showRightOrBottomSheet(
      title: S.current.prefer_resolution_mobile,
      child: ListView(
        children: [
          SettingsCardV2(
              children: controller.bitRateList.map<Widget>((name) {
            return RadioListTile<int>(
              activeColor: Theme.of(context).colorScheme.primary,
              groupValue: controller.bitRateMobile.value,
              value: name,
              title: Text(controller.getBitRateName(name)),
              onChanged: (value) {
                controller.changeBitRateMobile(value!);
                Navigator.of(context).pop();
              },
            );
          }).toList())
        ],
      ),
    );
  }
}
