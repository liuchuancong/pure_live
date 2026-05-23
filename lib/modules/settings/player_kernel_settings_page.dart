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
      appBar: AppBar(
        title: Text(i18n("player_kernel"), style: const TextStyle(fontWeight: FontWeight.w600)),
      ),
      body: ListView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        children: [
          _buildGroupTitle(theme, i18n("kernel_switch")),
          _buildModernCard(theme, [
            if (Platform.isAndroid)
              Obx(
                () => _buildTile(
                  context,
                  icon: Remix.cpu_line,
                  title: i18n("kernel_switch"),
                  subtitle: i18n("kernel_switch_subtitle"),
                  onTap: showVideoSetDialog,
                  trailing: Text(
                    PlayerConsts.players[controller.videoPlayerIndex.value],
                    style: TextStyle(color: theme.colorScheme.primary, fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                ),
              ),
            Obx(() {
              if (PlayerEngine.values[controller.videoPlayerIndex.value] == PlayerEngine.exo) {
                return const SizedBox.shrink();
              }

              return _buildTile(
                context,
                icon: Remix.shield_keyhole_line,
                title: i18n("network_proxy"),
                subtitle: i18n("network_proxy_subtitle"),
                onTap: showProxySettingsDialog,
                trailing: Text(
                  controller.enableProxy.value ? i18n("enabled") : i18n("disabled"),
                  style: TextStyle(
                    color: controller.enableProxy.value ? theme.colorScheme.primary : theme.hintColor,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              );
            }),
            _buildSwitchTile(
              context,
              title: i18n('enable_codec'),
              subtitle: i18n("gpu_decode"),
              value: controller.enableCodec,
              icon: Remix.flashlight_line,
            ),
            _buildSwitchTile(
              context,
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

  Widget _buildModernCard(ThemeData theme, List<Widget> children) {
    return Material(
      clipBehavior: Clip.antiAlias,
      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.15),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: theme.dividerColor.withValues(alpha: 0.05), width: 0.5),
      ),
      child: Column(children: children),
    );
  }

  Widget _buildTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    Widget? trailing,
  }) {
    final theme = Theme.of(context);
    return ListTile(
      leading: Icon(icon, color: theme.colorScheme.primary, size: 22),
      title: Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 2),
        child: Text(
          subtitle,
          style: TextStyle(fontSize: 12, color: theme.hintColor.withValues(alpha: 0.75)),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      trailing: trailing ?? Icon(Icons.chevron_right_rounded, color: theme.hintColor.withValues(alpha: 0.4), size: 20),
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
    );
  }

  Widget _buildSwitchTile(
    BuildContext context, {
    required String title,
    required String subtitle,
    required RxBool value,
    required IconData icon,
  }) {
    final theme = Theme.of(context);
    return Obx(
      () => SwitchListTile(
        secondary: Icon(icon, size: 22, color: theme.colorScheme.primary),
        title: Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Text(
            subtitle,
            style: TextStyle(fontSize: 12, color: theme.hintColor.withValues(alpha: 0.75)),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        value: value.value,
        activeThumbColor: theme.colorScheme.primary,
        onChanged: (val) => value.value = val,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      ),
    );
  }

  Widget _buildGroupTitle(ThemeData theme, String text) {
    return Padding(
      padding: const EdgeInsets.only(left: 8, bottom: 8),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: theme.colorScheme.primary.withValues(alpha: 0.65),
          letterSpacing: 0.5,
        ),
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
                      title: Text(name, style: const TextStyle(fontSize: 15)),
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
