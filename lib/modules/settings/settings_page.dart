import 'dart:io';
import 'package:get/get.dart';
import 'package:remixicon/remixicon.dart';
import 'package:pure_live/common/index.dart';
import 'package:pure_live/common/consts/app_consts.dart';
import 'package:flex_color_picker/flex_color_picker.dart';
import 'package:pure_live/player/utils/player_consts.dart';
import 'package:pure_live/modules/backup/backup_page.dart';
import 'package:pure_live/player/models/player_engine.dart';
import 'package:pure_live/player/core/live_audio_service.dart';

class SettingsPage extends GetView<SettingsService> {
  const SettingsPage({super.key});

  BuildContext get context => Get.context!;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    double screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      appBar: AppBar(
        scrolledUnderElevation: screenWidth > 640 ? 0 : null,
        title: Text(i18n("settings_title"), style: const TextStyle(fontWeight: FontWeight.w600)),
      ),
      body: ListView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: <Widget>[
          SectionTitle(title: i18n("theme_customization")),

          ListTile(
            leading: Icon(Remix.moon_clear_line, color: theme.colorScheme.primary, size: 24),
            title: Text(i18n("change_theme_mode")),
            subtitle: Text(i18n("change_theme_mode_subtitle")),
            onTap: showThemeModeSelectorDialog,
          ),

          ListTile(
            leading: Icon(Remix.palette_line, color: theme.colorScheme.primary, size: 24),
            title: Text(i18n("change_theme_color")),
            subtitle: Text(i18n("change_theme_color_subtitle")),
            trailing: Obx(
              () => ColorIndicator(
                width: 32,
                height: 32,
                borderRadius: 8,
                color: HexColor(controller.themeColorSwitch.value),
                onSelectFocus: false,
              ),
            ),
            onTap: colorPickerDialog,
          ),

          _buildSwitchTile(
            title: i18n("enable_dynamic_color"),
            subtitle: i18n("enable_dynamic_color_subtitle"),
            value: controller.enableDynamicTheme,
            icon: Remix.magic_line,
          ),

          SectionTitle(title: i18n("video")),

          Obx(
            () => ListTile(
              leading: const Icon(Remix.hd_line, size: 24),
              title: Text(i18n("prefer_resolution")),
              subtitle: Text(i18n("prefer_resolution_subtitle")),
              trailing: Text(
                controller.preferResolution.value,
                style: TextStyle(color: theme.colorScheme.primary, fontWeight: FontWeight.bold),
              ),
              onTap: showPreferResolutionSelectorDialog,
            ),
          ),

          Obx(
            () => ListTile(
              leading: const Icon(Remix.signal_tower_line, size: 24),
              title: Text(i18n("mobile_quality")),
              subtitle: Text(i18n("mobile_quality_subtitle")),
              trailing: Text(
                controller.preferResolutionCellular.value,
                style: TextStyle(color: theme.colorScheme.primary, fontWeight: FontWeight.bold),
              ),
              onTap: showpreferResolutionCellularSelectorDialog,
            ),
          ),

          if (Platform.isAndroid) _buildBackgroundPlayTile(context),

          _buildSwitchTile(
            title: i18n("exit_float_window"),
            subtitle: i18n("exit_float_window_subtitle"),
            value: controller.floatPlay,
            icon: Remix.picture_in_picture_2_line,
          ),

          _buildSwitchTile(
            title: i18n('enable_fullscreen_default'),
            subtitle: i18n('enable_fullscreen_default_subtitle'),
            value: controller.enableFullScreenDefault,
            icon: Remix.fullscreen_line,
          ),
          _buildSwitchTile(
            title: i18n('show_danmaku'),
            subtitle: i18n('show_danmaku_subtitle'),
            value: controller.enableDanmakuDisplay,
            icon: Remix.chat_smile_2_line,
          ),
          if (Platform.isAndroid)
            _buildSwitchTile(
              title: i18n('enable_screen_keep_on'),
              subtitle: i18n('enable_screen_keep_on_subtitle'),
              value: controller.enableScreenKeepOn,
              icon: Remix.lightbulb_line,
            ),

          SectionTitle(title: i18n("player_kernel")),

          if (Platform.isAndroid)
            Obx(
              () => ListTile(
                leading: const Icon(Icons.settings_input_component_outlined, size: 24),
                title: Text(i18n("kernel_switch")),
                subtitle: Text(i18n("kernel_switch_subtitle")),
                trailing: Text(
                  PlayerConsts.players[controller.videoPlayerIndex.value],
                  style: TextStyle(color: theme.colorScheme.primary, fontWeight: FontWeight.bold),
                ),
                onTap: showVideoSetDialog,
              ),
            ),

          Obx(() {
            if (controller.videoPlayerIndex.value == 2) return const SizedBox.shrink();
            return ListTile(
              leading: const Icon(Remix.shield_keyhole_line, size: 24),
              title: Text(i18n("network_proxy")),
              subtitle: Text(i18n("network_proxy_subtitle")),
              trailing: Obx(() => Text(controller.enableProxy.value ? i18n("enabled") : i18n("disabled"))),
              onTap: showProxySettingsDialog,
            );
          }),

          _buildSwitchTile(
            title: i18n('enable_codec'),
            subtitle: i18n("gpu_decode"),
            value: controller.enableCodec,
            icon: Remix.flashlight_line,
          ),

          _buildSwitchTile(
            title: i18n('force_destroy_player'),
            subtitle: i18n('force_destroy_player_subtitle'),
            value: controller.useHardStopOnExit,
            icon: Remix.p2p_line,
          ),
          SectionTitle(title: i18n("general")),

          ListTile(
            leading: const Icon(Remix.cloud_windy_line, size: 24),
            title: Text(i18n("platform_display")),
            subtitle: Text(i18n("platform_display_subtitle")),
            onTap: () => Get.toNamed(RoutePath.kSettingsHotAreas),
          ),

          ListTile(
            leading: const Icon(Remix.filter_2_line, size: 24),
            title: Text(i18n("danmaku_filter")),
            onTap: () => Get.toNamed(RoutePath.kSettingsDanmuShield),
          ),
          SectionTitle(title: i18n("set")),
          ListTile(
            leading: const Icon(Remix.global_line, size: 24),
            title: Text(i18n("change_language")),
            onTap: showLanguageSelecterDialog,
          ),
          ListTile(
            leading: const Icon(Remix.save_3_line, size: 24),
            title: Text(i18n("backup_recover")),
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const BackupPage())),
          ),

          Obx(() {
            final size = controller.cacheSizeMB.value;
            final turns = controller.refreshTurns.value;
            return ListTile(
              leading: const Icon(Icons.sd_storage_rounded),
              title: Text(i18n("current_cache_size")),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text("${size.toStringAsFixed(2)} MB", style: const TextStyle(color: Colors.grey)),
                  const SizedBox(width: 4),
                  AnimatedRotation(
                    turns: turns,
                    duration: const Duration(milliseconds: 600),
                    curve: Curves.easeInOutCubic,
                    child: Icon(Remix.refresh_line, size: 16, color: theme.colorScheme.primary),
                  ),
                ],
              ),
              onTap: () {
                controller.handleManualRefresh();
              },
              shape: const RoundedRectangleBorder(borderRadius: BorderRadius.horizontal(left: Radius.circular(12))),
            );
          }),

          ListTile(
            leading: const Icon(Icons.cleaning_services_rounded),
            title: Text(i18n("clear_all_cache")),
            subtitle: Text(i18n("clear_all_cache_meida_desc")),
            trailing: const Icon(Icons.chevron_right_rounded),
            shape: const RoundedRectangleBorder(borderRadius: BorderRadius.horizontal(left: Radius.circular(12))),
            onTap: () async {
              final ok = await Get.dialog<bool>(
                AlertDialog(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                  title: Text(i18n("confirm_clear_cache"), style: const TextStyle(fontWeight: FontWeight.bold)),
                  content: Text(i18n("confirm_clear_meida_desc")),
                  actions: [
                    TextButton(onPressed: () => Navigator.of(Get.context!).pop(false), child: Text(i18n("cancel"))),
                    ElevatedButton(onPressed: () => Navigator.of(Get.context!).pop(true), child: Text(i18n("clear"))),
                  ],
                ),
              );

              if (ok == true) {
                await controller.clearCache();

                Get.snackbar(i18n("done"), i18n("cache_cleared"), snackPosition: SnackPosition.bottom);
              }
            },
          ),

          _buildSwitchTile(
            title: i18n('splash_animation'),
            subtitle: i18n("splash_animation_subtitle"),
            value: controller.showSplashPage,
            icon: Remix.rocket_2_line,
          ),

          _buildSwitchTile(
            title: i18n('enable_auto_check_update'),
            value: controller.enableAutoCheckUpdate,
            icon: Remix.refresh_line,
          ),

          if (Platform.isWindows) ...[
            _buildSwitchTile(title: i18n("startup"), value: controller.enableStartUp, icon: Remix.windows_line),
            _buildSwitchTile(
              title: i18n("no_exit_confirm"),
              value: controller.dontAskExit,
              icon: Remix.error_warning_line,
            ),
          ],

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  // --- 辅助构建方法 ---

  Widget _buildSwitchTile({required String title, String? subtitle, required RxBool value, required IconData icon}) {
    return Obx(
      () => SwitchListTile(
        secondary: Icon(icon, size: 24),
        title: Text(title),
        subtitle: subtitle != null ? Text(subtitle) : null,
        value: value.value,
        activeThumbColor: Get.theme.colorScheme.primary,
        onChanged: (val) => value.value = val,
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

  void showThemeModeSelectorDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return SimpleDialog(
          title: Text(i18n('change_theme_mode')),
          children: [
            Obx(
              () => RadioGroup<String>(
                groupValue: controller.themeModeName.value,
                onChanged: (String? value) {
                  if (value != null) {
                    controller.changeThemeMode(value);
                    Navigator.of(context).pop();
                  }
                },
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: AppConsts.themeModes.keys.map<Widget>((name) {
                    return RadioListTile<String>(
                      title: Text(i18n(AppConsts.themeModeI18n[name]!)),
                      value: name,
                      activeColor: Theme.of(context).colorScheme.primary,
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
      heading: Text(i18n("theme_color"), style: Theme.of(context).textTheme.titleMedium),
      subheading: Text(i18n("select_opacity"), style: Theme.of(context).textTheme.titleMedium),
      wheelSubheading: Text(i18n("theme_color_opacity"), style: Theme.of(context).textTheme.titleMedium),
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
          title: Text(i18n("change_language")),
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
          title: Text(i18n("change_player")),
          children: [
            RadioGroup<String>(
              groupValue: playerList[controller.videoPlayerIndex.value],
              onChanged: (String? value) {
                if (value != null) {
                  controller.changePlayer(playerList.indexOf(value));
                  GlobalPlayerService.instance.playerManager.switchEngine(
                    PlayerEngine.values[controller.videoPlayerIndex.value],
                    isManual: true,
                  );
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
                            GlobalPlayerService.instance.playerManager.switchEngine(
                              PlayerEngine.values[controller.videoPlayerIndex.value],
                              isManual: true,
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

  void showpreferResolutionCellularSelectorDialog() {
    showDialog(
      context: context,
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
          title: Text(i18n("prefer_platform")),
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
                  children: Sites.supportSites.map<Widget>((Site site) {
                    return Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Radio<String>(value: site.name, activeColor: Theme.of(context).colorScheme.primary),
                        GestureDetector(
                          onTap: () {
                            controller.changePreferPlatform(site.id);
                            Navigator.of(context).pop();
                          },
                          child: Text(site.name, style: Theme.of(context).textTheme.bodyLarge),
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
        content: Obx(
          () => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Slider(
                min: 0,
                max: 120,
                label: i18n("auto_refresh_time"),
                value: controller.autoRefreshTime.toDouble(),
                onChanged: (value) => controller.autoRefreshTime.value = value.toInt(),
              ),
              Text(i18n("auto_refresh_time_with_value", args: {'time': '${controller.autoRefreshTime}'})),
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
        content: Obx(
          () => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SwitchListTile(
                title: Text(i18n("auto_shutdown_time_subtitle")),
                value: controller.enableAutoShutDownTime.value,
                activeThumbColor: Theme.of(context).colorScheme.primary,
                onChanged: (bool value) => controller.enableAutoShutDownTime.value = value,
              ),
              Slider(
                min: 1,
                max: 1200,
                label: i18n("auto_shutdown_time"),
                value: controller.autoShutDownTime.toDouble(),
                onChanged: (value) {
                  controller.autoShutDownTime.value = value.toInt();
                },
              ),
              Text(i18n("auto_shutdown_time_with_value", args: {'time': '${controller.autoShutDownTime}'})),
            ],
          ),
        ),
      ),
    );
  }

  void showProxySettingsDialog() {
    final hostController = TextEditingController(text: controller.proxyHost.value);
    final portController = TextEditingController(text: controller.proxyPort.value.toString());

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(i18n("proxy_settings")),
        content: Obx(
          () => SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SwitchListTile(
                  title: Text(i18n("enable_player_proxy")),
                  value: controller.enableProxy.value,
                  activeThumbColor: Theme.of(context).colorScheme.primary,
                  onChanged: (bool value) {
                    controller.enableProxy.value = value;
                  },
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: hostController,
                  enabled: controller.enableProxy.value,
                  decoration: InputDecoration(
                    labelText: i18n("proxy_host"),
                    hintText: i18n("proxy_host_hint"),
                    prefixIcon: const Icon(Icons.lan),
                    border: const OutlineInputBorder(),
                  ),
                  onChanged: (value) {
                    controller.proxyHost.value = value;
                  },
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: portController,
                  enabled: controller.enableProxy.value,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: i18n("proxy_port"),
                    hintText: i18n("proxy_port_hint"),
                    prefixIcon: const Icon(Icons.numbers),
                    border: const OutlineInputBorder(),
                  ),
                  onChanged: (value) {
                    int? port = int.tryParse(value);
                    if (port != null) {
                      controller.proxyPort.value = port;
                    }
                  },
                ),
              ],
            ),
          ),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: Text(i18n("confirm")))],
      ),
    );
  }
}
