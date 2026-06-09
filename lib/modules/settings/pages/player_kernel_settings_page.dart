import 'dart:io';
import 'package:remixicon/remixicon.dart';
import 'package:pure_live/common/index.dart';
import 'package:url_launcher/url_launcher_string.dart';
import 'package:pure_live/player/utils/player_consts.dart';
import 'package:pure_live/player/models/player_engine.dart';
import 'package:pure_live/common/global/platform_utils.dart';

class PlayerKernelSettingsPage extends GetView<SettingsService> {
  const PlayerKernelSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(i18n("player_kernel_settings"))),
      body: ListView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        children: [
          context.buildGroupTitle(i18n("core_kernel_settings")),
          context.buildModernCard([
            Obx(() {
              String activeKey = SettingsService.to.player.videoPlayerKey.v;
              String activeI18nKey = PlayerConsts.names[activeKey] ?? PlayerConsts.names[PlayerConsts.defaultKey]!;

              return context.buildTile(
                icon: Remix.toggle_line,
                title: i18n("kernel_switch"),
                subtitle: i18n("kernel_switch_subtitle"),
                onTap: showVideoSetDialog,
                trailing: Text(
                  i18n(activeI18nKey),
                  style: TextStyle(color: theme.colorScheme.primary, fontWeight: FontWeight.w600),
                ),
              );
            }),
            Obx(() {
              String activeKey = SettingsService.to.player.videoPlayerKey.v;
              if (PlayerConsts.engines[activeKey] == PlayerEngine.exo) {
                return const SizedBox.shrink();
              }

              return context.buildTile(
                icon: Remix.global_line,
                title: i18n("network_proxy"),
                subtitle: i18n("network_proxy_subtitle"),
                onTap: showProxySettingsDialog,
                trailing: Text(
                  SettingsService.to.proxy.enableProxy.v ? i18n("enabled") : i18n("disabled"),
                  style: AppTextStyles.t13.copyWith(
                    color: SettingsService.to.proxy.enableProxy.v ? theme.colorScheme.primary : theme.hintColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              );
            }),
            context.buildSwitchTile(
              icon: Remix.music_2_line,
              title: i18n('audio_only_mode'),
              subtitle: i18n("audio_only_mode_subtitle"),
              value: SettingsService.to.player.audioOnly,
            ),
            context.buildSwitchTile(
              icon: Remix.speed_up_line,
              title: i18n('enable_codec'),
              subtitle: i18n("gpu_decode"),
              value: SettingsService.to.player.enableCodec,
            ),
            context.buildSwitchTile(
              icon: Remix.shut_down_line,
              title: i18n('force_destroy_player'),
              subtitle: i18n('force_destroy_player_subtitle'),
              value: SettingsService.to.player.useHardStopOnExit,
            ),
          ]),
          Obx(() {
            String activeKey = SettingsService.to.player.videoPlayerKey.v;
            if (PlayerConsts.engines[activeKey] != PlayerEngine.mediaKit) {
              return const SizedBox.shrink();
            }
            return _buildMpvSettings(context);
          }),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildMpvSettings(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(padding: EdgeInsets.only(left: 16, right: 16, bottom: 0, top: 12), child: Divider()),
        if (Platform.isAndroid)
          context.buildSwitchTile(
            icon: Remix.shield_check_line,
            title: i18n('compat_mode'),
            subtitle: i18n('compat_mode_subtitle'),
            value: SettingsService.to.player.playerCompatMode,
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 5, 12, 4),
          child: Row(
            children: [
              Icon(Remix.equalizer_line, size: 18, color: theme.colorScheme.primary),
              const SizedBox(width: 8),
              Text(
                i18n("mpv_advanced_settings"),
                style: AppTextStyles.t16Bold.copyWith(color: theme.colorScheme.primary),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              Expanded(
                child: Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 4,
                  children: [
                    Text(
                      i18n("mpv_warning_text"),
                      style: AppTextStyles.t12.copyWith(color: theme.hintColor.withValues(alpha: 0.65)),
                    ),
                    InkWell(
                      borderRadius: BorderRadius.circular(4),
                      onTap: () => launchUrlString("https://mpv.io"),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                        child: Text(
                          i18n("mpv_official_docs"),
                          style: AppTextStyles.t12.copyWith(
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.w600,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () => SettingsService.to.player.resetMpvPlayerSettings(),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Remix.refresh_line, size: 14, color: Colors.red),
                      const SizedBox(width: 4),
                      Text(
                        i18n("reset"),
                        style: const TextStyle(color: Colors.red, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        context.buildModernCard([
          context.buildSwitchTile(
            icon: Remix.code_box_line,
            title: i18n("custom_output_hwdec"),
            value: SettingsService.to.player.customPlayerOutput,
          ),
          Obx(
            () => context.buildMenuTile<String>(
              title: i18n("video_output_driver"),
              icon: Remix.movie_line,
              value: SettingsService.to.player.videoOutputDriver.v,
              valueMap: PlayerConsts.videoOutputDrivers,
              onChanged: (e) => SettingsService.to.player.videoOutputDriver.v = e,
            ),
          ),
          Obx(
            () => context.buildMenuTile<String>(
              title: i18n("audio_output_driver"),
              icon: Remix.volume_up_line,
              value: SettingsService.to.player.audioOutputDriver.v,
              valueMap: PlayerConsts.audioOutputDrivers,
              onChanged: (e) => SettingsService.to.player.audioOutputDriver.v = e,
            ),
          ),
          Obx(
            () => context.buildMenuTile<String>(
              title: i18n("hardware_decoder"),
              icon: Remix.cpu_line,
              value: SettingsService.to.player.videoHardwareDecoder.v,
              valueMap: PlayerConsts.hardwareDecoder,
              onChanged: (e) => SettingsService.to.player.videoHardwareDecoder.v = e,
            ),
          ),
        ]),
      ],
    );
  }

  // 播放器选择弹窗
  void showVideoSetDialog() {
    List<String> playerList = PlatformUtils.isMobile
        ? PlayerConsts.names.values.toList()
        : [PlayerConsts.names['mpv']!];

    showDialog(
      context: Get.context!,
      builder: (BuildContext context) {
        return SimpleDialog(
          title: Text(i18n("change_player")),
          children: [
            Obx(() {
              String activeKey = SettingsService.to.player.videoPlayerKey.v;
              String activeI18nKey = PlayerConsts.names[activeKey] ?? playerList.first;

              if (!playerList.contains(activeI18nKey)) {
                activeKey = PlayerConsts.getKeyByI18nKey(playerList.first);
              }

              return RadioGroup<String>(
                groupValue: activeKey,
                onChanged: (String? key) {
                  if (key != null && PlayerConsts.engines.containsKey(key)) {
                    SettingsService.to.player.videoPlayerKey.v = key;
                    GlobalPlayerService.instance.playerManager.switchEngine(PlayerConsts.engines[key]!, isManual: true);
                    Navigator.of(context).pop();
                  }
                },
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: playerList.map<Widget>((i18nKey) {
                    final String itemKey = PlayerConsts.getKeyByI18nKey(i18nKey);
                    return ListTile(
                      leading: Radio<String>(value: itemKey, activeColor: Theme.of(context).colorScheme.primary),
                      title: Text(i18n(i18nKey), style: AppTextStyles.t15),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                      onTap: () {
                        if (PlayerConsts.engines.containsKey(itemKey)) {
                          SettingsService.to.player.videoPlayerKey.v = itemKey;
                          GlobalPlayerService.instance.playerManager.switchEngine(
                            PlayerConsts.engines[itemKey]!,
                            isManual: true,
                          );
                          Navigator.of(context).pop();
                        }
                      },
                    );
                  }).toList(),
                ),
              );
            }),
          ],
        );
      },
    );
  }

  // 代理设置弹窗（替换为统一SwitchTile）
  void showProxySettingsDialog() {
    final hostController = TextEditingController(text: SettingsService.to.proxy.proxyHost.v);
    final portController = TextEditingController(text: SettingsService.to.proxy.proxyPort.v.toString());

    showDialog(
      context: Get.context!,
      builder: (context) => AlertDialog(
        title: Text(i18n("proxy_settings")),
        content: Obx(
          () => SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                context.buildSwitchTile(
                  icon: Remix.shield_keyhole_line,
                  title: i18n("enable_player_proxy"),
                  value: SettingsService.to.proxy.enableProxy,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: hostController,
                  enabled: SettingsService.to.proxy.enableProxy.v,
                  decoration: InputDecoration(
                    labelText: i18n("proxy_host"),
                    prefixIcon: const Icon(Remix.global_line, size: 20),
                    border: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
                  ),
                  onChanged: (value) => SettingsService.to.proxy.proxyHost.v = value,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: portController,
                  enabled: SettingsService.to.proxy.enableProxy.v,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: i18n("proxy_port"),
                    prefixIcon: const Icon(Remix.links_line, size: 20),
                    border: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
                  ),
                  onChanged: (value) {
                    int? port = int.tryParse(value);
                    if (port != null) SettingsService.to.proxy.proxyPort.v = port;
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
