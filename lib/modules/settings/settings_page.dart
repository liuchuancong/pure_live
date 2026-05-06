import 'dart:io';
import 'package:get/get.dart';
import 'package:pure_live/common/index.dart';
import 'package:remixicon/remixicon.dart'; // 引入美化图标库
import 'package:url_launcher/url_launcher_string.dart';
import 'package:pure_live/common/consts/app_consts.dart';
import 'package:flex_color_picker/flex_color_picker.dart';
import 'package:pure_live/player/utils/player_consts.dart';
import 'package:pure_live/modules/backup/backup_page.dart';
import 'package:pure_live/player/models/player_engine.dart';
import 'package:pure_live/modules/settings/settings_card.dart';
import 'package:pure_live/modules/settings/settings_menu.dart';
import 'package:pure_live/modules/settings/settings_switch.dart';
import 'package:pure_live/common/global/platform/background_server.dart';

class SettingsPage extends GetView<SettingsService> {
  const SettingsPage({super.key});

  BuildContext get context => Get.context!;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final theme = Theme.of(context);
    double screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      appBar: AppBar(
        scrolledUnderElevation: screenWidth > 640 ? 0 : null,
        title: Text(s.settings_title, style: const TextStyle(fontWeight: FontWeight.w600)),
      ),
      body: ListView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: <Widget>[
          // ================== 1. 主题设置 ==================
          const SectionTitle(title: "主题定制"),
          ListTile(
            leading: Icon(Remix.moon_clear_line, color: theme.colorScheme.primary, size: 24),
            title: Text(s.change_theme_mode),
            subtitle: Text(s.change_theme_mode_subtitle),
            onTap: showThemeModeSelectorDialog,
          ),
          ListTile(
            leading: Icon(Remix.palette_line, color: theme.colorScheme.primary, size: 24),
            title: Text(s.change_theme_color),
            subtitle: Text(s.change_theme_color_subtitle),
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
            title: s.enable_dynamic_color,
            subtitle: s.enable_dynamic_color_subtitle,
            value: controller.enableDynamicTheme,
            icon: Remix.magic_line,
          ),

          // ================== 2. 视频设置 ==================
          SectionTitle(title: s.video),
          Obx(
            () => ListTile(
              leading: const Icon(Remix.hd_line, size: 24),
              title: Text(s.prefer_resolution),
              subtitle: Text(s.prefer_resolution_subtitle),
              trailing: Text(
                controller.preferResolution.value,
                style: TextStyle(color: theme.colorScheme.primary, fontWeight: FontWeight.bold),
              ),
              onTap: showPreferResolutionSelectorDialog,
            ),
          ),
          ListTile(
            leading: const Icon(Remix.shield_keyhole_line, size: 24),
            title: const Text('网络代理设置'),
            subtitle: const Text('配置播放器的网络请求代理'),
            trailing: Obx(() => Text(controller.enableProxy.value ? '已开启' : '未开启')),
            onTap: showProxySettingsDialog,
          ),
          _buildSwitchTile(
            title: '退出小窗播放',
            subtitle: "返回主界面时是否保留悬浮窗",
            value: controller.floatPlay,
            icon: Remix.picture_in_picture_2_line,
          ),
          _buildSwitchTile(
            title: s.enable_fullscreen_default,
            subtitle: s.enable_fullscreen_default_subtitle,
            value: controller.enableFullScreenDefault,
            icon: Remix.fullscreen_line,
          ),
          if (Platform.isAndroid)
            _buildSwitchTile(
              title: s.enable_screen_keep_on,
              subtitle: s.enable_screen_keep_on_subtitle,
              value: controller.enableScreenKeepOn,
              icon: Remix.lightbulb_line,
            ),

          // ================== 3. 播放器设置 ==================
          const SectionTitle(title: "播放器内核"),
          if (Platform.isAndroid)
            Obx(
              () => ListTile(
                leading: const Icon(Icons.settings_input_component_outlined, size: 24),
                title: const Text('内核切换'),
                subtitle: const Text('不同内核影响解码性能与兼容性'),
                trailing: Text(
                  PlayerConsts.players[controller.videoPlayerIndex.value],
                  style: TextStyle(color: theme.colorScheme.primary, fontWeight: FontWeight.bold),
                ),
                onTap: showVideoSetDialog,
              ),
            ),
          _buildSwitchTile(
            title: s.enable_codec,
            subtitle: "优先使用 GPU 进行硬件解码",
            value: controller.enableCodec,
            icon: Remix.flashlight_line,
          ),
          _buildSwitchTile(
            title: '播放器强制销毁',
            subtitle: '彻底关闭播放进程以节省资源',
            value: controller.useHardStopOnExit,
            icon: Remix.p2p_line,
          ),
          if (Platform.isAndroid) _buildBackgroundPlayTile(context),

          // MPV 高级配置联动显示
          Obx(() {
            if (controller.videoPlayerIndex.value != 0) return const SizedBox.shrink();
            return _buildMpvSettings(context);
          }),

          // ================== 4. 通用设置 ==================
          SectionTitle(title: s.general),
          ListTile(
            leading: const Icon(Remix.global_line, size: 24),
            title: Text(s.change_language),
            onTap: showLanguageSelecterDialog,
          ),
          ListTile(
            leading: const Icon(Remix.cloud_windy_line, size: 24),
            title: const Text("平台显示设置"),
            subtitle: const Text("管理并排序首页显示的直播平台"),
            onTap: () => Get.toNamed(RoutePath.kSettingsHotAreas),
          ),
          ListTile(
            leading: const Icon(Remix.filter_2_line, size: 24),
            title: const Text("弹幕关键词过滤"),
            onTap: () => Get.toNamed(RoutePath.kSettingsDanmuShield),
          ),
          ListTile(
            leading: const Icon(Remix.save_3_line, size: 24),
            title: Text(s.backup_recover),
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const BackupPage())),
          ),
          _buildSwitchTile(
            title: '启动页动画',
            subtitle: "应用冷启动时显示动态 Logo",
            value: controller.showSplashPage,
            icon: Remix.rocket_2_line,
          ),
          _buildSwitchTile(
            title: s.enable_auto_check_update,
            value: controller.enableAutoCheckUpdate,
            icon: Remix.refresh_line,
          ),
          if (Platform.isWindows) ...[
            _buildSwitchTile(title: '开机启动', value: controller.enableStartUp, icon: Remix.windows_line),
            _buildSwitchTile(title: '退出不再询问', value: controller.dontAskExit, icon: Remix.error_warning_line),
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
        title: Text(S.of(context).enable_background_play),
        subtitle: Text(S.of(context).enable_background_play_subtitle),
        value: controller.enableBackgroundPlay.value,
        onChanged: (value) async {
          controller.enableBackgroundPlay.value = value;
          if (value && Platform.isAndroid) {
            bool hasPermission = await BackgroundService.requestPlatformPermissions();
            controller.enableBackgroundPlay.value = hasPermission;
          }
        },
      ),
    );
  }

  Widget _buildMpvSettings(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(padding: EdgeInsets.symmetric(horizontal: 16), child: Divider()),
        if (Platform.isAndroid)
          _buildSwitchTile(
            title: '兼容模式',
            subtitle: '旧设备播放卡顿时请尝试开启',
            value: controller.playerCompatMode,
            icon: Remix.shield_flash_line,
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Row(
            children: [
              Icon(Remix.settings_5_line, size: 18, color: theme.colorScheme.primary),
              const SizedBox(width: 8),
              Text(
                "MPV 高级设置",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: theme.colorScheme.primary),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Text.rich(
            TextSpan(
              text: "调整内核参数可能导致播放异常，详情请参考 ",
              style: const TextStyle(fontSize: 12, color: Colors.grey),
              children: [
                WidgetSpan(
                  alignment: PlaceholderAlignment.middle,
                  child: GestureDetector(
                    onTap: () => launchUrlString("https://mpv.io"),
                    child: const Text(
                      "MPV 官方文档",
                      style: TextStyle(color: Colors.blue, fontSize: 12, decoration: TextDecoration.underline),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        SettingsCard(
          child: Column(
            children: [
              Obx(
                () => SettingsSwitch(
                  value: controller.customPlayerOutput.value,
                  title: "自定义驱动与硬件加速",
                  onChanged: (e) => controller.customPlayerOutput.value = e,
                ),
              ),
              Obx(
                () => SettingsMenu(
                  title: "视频输出驱动(--vo)",
                  value: controller.videoOutputDriver.value,
                  valueMap: PlayerConsts.videoOutputDrivers,
                  onChanged: (e) => controller.videoOutputDriver.value = e,
                ),
              ),
              Obx(
                () => SettingsMenu(
                  title: "音频输出驱动(--ao)",
                  value: controller.audioOutputDriver.value,
                  valueMap: PlayerConsts.audioOutputDrivers,
                  onChanged: (e) => controller.audioOutputDriver.value = e,
                ),
              ),
              Obx(
                () => SettingsMenu(
                  title: "硬件解码器(--hwdec)",
                  value: controller.videoHardwareDecoder.value,
                  valueMap: PlayerConsts.hardwareDecoder,
                  onChanged: (e) => controller.videoHardwareDecoder.value = e,
                ),
              ),
            ],
          ),
        ),
      ],
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

  void showProxySettingsDialog() {
    final hostController = TextEditingController(text: controller.proxyHost.value);
    final portController = TextEditingController(text: controller.proxyPort.value.toString());

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("网络代理配置"),
        content: Obx(
          () => SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SwitchListTile(
                  title: Text("启用播放代理"),
                  value: controller.enableProxy.value,
                  activeThumbColor: Theme.of(context).colorScheme.primary,
                  onChanged: (bool value) {
                    controller.enableProxy.value = value;
                  },
                ),
                const SizedBox(height: 10),

                // 2. 代理地址输入框
                TextField(
                  controller: hostController,
                  enabled: controller.enableProxy.value,
                  decoration: InputDecoration(
                    labelText: "代理主机 (Host)",
                    hintText: "例如: 127.0.0.1",
                    prefixIcon: const Icon(Icons.lan),
                    border: const OutlineInputBorder(),
                  ),
                  onChanged: (value) {
                    controller.proxyHost.value = value;
                  },
                ),
                const SizedBox(height: 16),

                // 3. 端口输入框 (限定数字)
                TextField(
                  controller: portController,
                  enabled: controller.enableProxy.value,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: "端口 (Port)",
                    hintText: "例如: 1080",
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
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: Text("完成"))],
      ),
    );
  }
}
