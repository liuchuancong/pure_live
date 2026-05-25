import 'dart:io';
import 'package:remixicon/remixicon.dart';
import 'package:pure_live/common/index.dart';
import 'package:pure_live/player/utils/player_consts.dart';
import 'package:pure_live/player/models/player_engine.dart';

class PlayerKernelSettingsPage extends GetView<SettingsService> {
  const PlayerKernelSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(i18n("player_kernel"))),
      body: ListView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        children: [
          context.buildGroupTitle(i18n("kernel_switch")),
          context.buildModernCard([
            if (Platform.isAndroid)
              Obx(
                () => context.buildTile(
                  icon: Remix.cpu_line,
                  title: i18n("kernel_switch"),
                  subtitle: i18n("kernel_switch_subtitle"),
                  onTap: showVideoSetDialog,
                  trailing: Text(
                    PlayerConsts.players[controller.videoPlayerIndex.value],
                    style: TextStyle(color: theme.colorScheme.primary, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            Obx(() {
              if (PlayerEngine.values[controller.videoPlayerIndex.value] == PlayerEngine.exo) {
                return const SizedBox.shrink();
              }

              return context.buildTile(
                icon: Remix.shield_keyhole_line,
                title: i18n("network_proxy"),
                subtitle: i18n("network_proxy_subtitle"),
                onTap: showProxySettingsDialog,
                trailing: Text(
                  controller.enableProxy.value ? i18n("enabled") : i18n("disabled"),
                  style: AppTextStyles.t13.copyWith(
                    color: controller.enableProxy.value ? theme.colorScheme.primary : theme.hintColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              );
            }),
            context.buildSwitchTile(
              title: i18n('enable_codec'),
              subtitle: i18n("gpu_decode"),
              value: controller.enableCodec,
              icon: Remix.flashlight_line,
            ),
            context.buildSwitchTile(
              title: i18n('force_destroy_player'),
              subtitle: i18n('force_destroy_player_subtitle'),
              value: controller.useHardStopOnExit,
              icon: Remix.p2p_line,
            ),
          ]),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  void showVideoSetDialog() {
    List<String> playerList = controller.playerlist;
    showDialog(
      context: Get.context!,
      builder: (BuildContext context) {
        return SimpleDialog(
          title: Text(i18n("change_player")),
          children: [
            Obx(
              () => RadioGroup<String>(
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
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: playerList.map<Widget>((name) {
                    return ListTile(
                      leading: Radio<String>(value: name, activeColor: Theme.of(context).colorScheme.primary),
                      title: Text(name, style: AppTextStyles.t15),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                      onTap: () {
                        controller.changePlayer(playerList.indexOf(name));
                        GlobalPlayerService.instance.playerManager.switchEngine(
                          PlayerEngine.values[controller.videoPlayerIndex.value],
                          isManual: true,
                        );
                        Navigator.of(context).pop();
                      },
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

  void showProxySettingsDialog() {
    final hostController = TextEditingController(text: controller.proxyHost.value);
    final portController = TextEditingController(text: controller.proxyPort.value.toString());

    showDialog(
      context: Get.context!,
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
                const SizedBox(height: 12),
                TextField(
                  controller: hostController,
                  enabled: controller.enableProxy.value,
                  decoration: InputDecoration(
                    labelText: i18n("proxy_host"),
                    prefixIcon: const Icon(Remix.global_line, size: 20),
                    border: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
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
                    prefixIcon: const Icon(Remix.links_line, size: 20),
                    border: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
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
