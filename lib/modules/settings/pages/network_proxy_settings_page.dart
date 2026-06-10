import 'package:flutter/services.dart';
import 'package:remixicon/remixicon.dart';
import 'package:pure_live/common/index.dart';

class NetworkProxySettingsPage extends StatefulWidget {
  const NetworkProxySettingsPage({super.key});

  @override
  State<NetworkProxySettingsPage> createState() => _NetworkProxySettingsPageState();
}

class _NetworkProxySettingsPageState extends State<NetworkProxySettingsPage> {
  final proxyCtrl = SettingsService.to.proxy;

  late final TextEditingController _appHostController;
  late final TextEditingController _appPortController;
  late final TextEditingController _playerHostController;
  late final TextEditingController _playerPortController;

  @override
  void initState() {
    super.initState();
    _appHostController = TextEditingController(text: proxyCtrl.appProxyHost.v);
    _appPortController = TextEditingController(text: proxyCtrl.appProxyPort.v.toString());
    _playerHostController = TextEditingController(text: proxyCtrl.proxyHost.v);
    _playerPortController = TextEditingController(text: proxyCtrl.proxyPort.v.toString());
  }

  @override
  void dispose() {
    _appHostController.dispose();
    _appPortController.dispose();
    _playerHostController.dispose();
    _playerPortController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(i18n("network_proxy_settings"))),
      body: Obx(() {
        return ListView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          children: [
            context.buildGroupTitle(i18n("app_proxy_group_title")),
            context.buildModernCard([
              SwitchListTile(
                secondary: Icon(Remix.apps_line, color: theme.colorScheme.primary),
                title: Text(i18n("enable_app_proxy")),
                subtitle: Text(i18n("enable_app_proxy_desc")),
                value: proxyCtrl.enableAppProxy.v,
                onChanged: (val) => proxyCtrl.enableAppProxy.v = val,
              ),
              if (proxyCtrl.enableAppProxy.v) ...[
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: TextField(
                          controller: _appHostController,
                          decoration: InputDecoration(
                            labelText: i18n("proxy_address_label"),
                            hintText: "127.0.0.1",
                            border: const OutlineInputBorder(),
                            isDense: true,
                          ),
                          onChanged: (val) => proxyCtrl.appProxyHost.v = val.trim(),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: TextField(
                          controller: _appPortController,
                          keyboardType: TextInputType.number,
                          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                          decoration: InputDecoration(
                            labelText: i18n("proxy_port_label"),
                            hintText: "7890",
                            border: const OutlineInputBorder(),
                            isDense: true,
                          ),
                          onChanged: (val) {
                            final intPort = int.tryParse(val) ?? 1080;
                            proxyCtrl.appProxyPort.v = intPort;
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ]),

            const SizedBox(height: 24),
            context.buildGroupTitle(i18n("player_proxy_group_title")),
            context.buildModernCard([
              SwitchListTile(
                secondary: Icon(Remix.video_line, color: theme.colorScheme.primary),
                title: Text(i18n("enable_player_proxy")),
                subtitle: Text(i18n("enable_player_proxy_desc")),
                value: proxyCtrl.enableProxy.v,
                onChanged: (val) => proxyCtrl.enableProxy.v = val,
              ),
              if (proxyCtrl.enableProxy.v) ...[
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: TextField(
                          controller: _playerHostController,
                          decoration: InputDecoration(
                            labelText: i18n("proxy_address_label"),
                            hintText: "127.0.0.1",
                            border: const OutlineInputBorder(),
                            isDense: true,
                          ),
                          onChanged: (val) => proxyCtrl.proxyHost.v = val.trim(),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: TextField(
                          controller: _playerPortController,
                          keyboardType: TextInputType.number,
                          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                          decoration: InputDecoration(
                            labelText: i18n("proxy_port_label"),
                            hintText: "1080",
                            border: const OutlineInputBorder(),
                            isDense: true,
                          ),
                          onChanged: (val) {
                            final intPort = int.tryParse(val) ?? 1080;
                            proxyCtrl.proxyPort.v = intPort;
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ]),
            const SizedBox(height: 32),
          ],
        );
      }),
    );
  }
}
