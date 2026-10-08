import 'package:flutter/services.dart';
import 'package:remixicon/remixicon.dart';
import 'package:pure_live/core/index.dart';
import 'package:pure_live/core/network/proxy_routing.dart';

final TextInputFormatter _proxyHostInputFormatter = TextInputFormatter.withFunction((oldValue, newValue) {
  final normalized = normalizeProxyHost(newValue.text);
  if (normalized == newValue.text) return newValue;
  return TextEditingValue(
    text: normalized,
    selection: TextSelection.collapsed(offset: normalized.length),
    composing: TextRange.empty,
  );
});

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
  bool _appPortInvalid = false;
  bool _playerPortInvalid = false;

  @override
  void initState() {
    super.initState();
    _appHostController = TextEditingController(text: proxyCtrl.appProxyHost.v);
    _appPortController = TextEditingController(text: proxyCtrl.appProxyPort.v.toString());
    _playerHostController = TextEditingController(text: proxyCtrl.proxyHost.v);
    _playerPortController = TextEditingController(text: proxyCtrl.proxyPort.v.toString());
    _appPortInvalid = parseProxyPortInput(_appPortController.text) == null;
    _playerPortInvalid = parseProxyPortInput(_playerPortController.text) == null;
  }

  @override
  void dispose() {
    _appHostController.dispose();
    _appPortController.dispose();
    _playerHostController.dispose();
    _playerPortController.dispose();
    super.dispose();
  }

  void _updatePort(String rawValue, {required bool isAppProxy}) {
    final port = parseProxyPortInput(rawValue);
    final invalid = port == null;
    if (isAppProxy) {
      if (_appPortInvalid != invalid) setState(() => _appPortInvalid = invalid);
      if (port != null) proxyCtrl.appProxyPort.v = port;
      return;
    }
    if (_playerPortInvalid != invalid) setState(() => _playerPortInvalid = invalid);
    if (port != null) proxyCtrl.proxyPort.v = port;
  }

  Widget _buildEndpointFields({
    required String keyPrefix,
    required TextEditingController hostController,
    required TextEditingController portController,
    required bool portInvalid,
    required ValueChanged<String> onHostChanged,
    required ValueChanged<String> onPortChanged,
    required String portHint,
  }) {
    final hostField = TextField(
      key: ValueKey('$keyPrefix-host'),
      controller: hostController,
      keyboardType: TextInputType.url,
      autocorrect: false,
      enableSuggestions: false,
      inputFormatters: [_proxyHostInputFormatter],
      decoration: InputDecoration(
        labelText: i18n('proxy_address_label'),
        hintText: '127.0.0.1',
        border: const OutlineInputBorder(),
        isDense: true,
      ),
      onChanged: onHostChanged,
    );
    final portField = TextField(
      key: ValueKey('$keyPrefix-port'),
      controller: portController,
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      decoration: InputDecoration(
        labelText: i18n('proxy_port_label'),
        hintText: portHint,
        errorText: portInvalid ? i18n('proxy_port_invalid') : null,
        errorMaxLines: 3,
        border: const OutlineInputBorder(),
        isDense: true,
      ),
      onChanged: onPortChanged,
    );

    return Padding(
      padding: const EdgeInsets.all(16),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final mediaQuery = MediaQuery.of(context);
          final stackFields = constraints.maxWidth < 420 || mediaQuery.textScaler.scale(13) > 18;
          if (stackFields) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [hostField, const SizedBox(height: 12), portField],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 3, child: hostField),
              const SizedBox(width: 12),
              Expanded(flex: 2, child: portField),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(i18n("network_proxy_settings"))),
      body: Obx(() {
        return ListView(
          physics: const PureLiveScrollPhysics(),
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
                _buildEndpointFields(
                  keyPrefix: 'app-proxy',
                  hostController: _appHostController,
                  portController: _appPortController,
                  portInvalid: _appPortInvalid,
                  onHostChanged: (value) => proxyCtrl.appProxyHost.v = normalizeProxyHost(value),
                  onPortChanged: (value) => _updatePort(value, isAppProxy: true),
                  portHint: '7890',
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
                _buildEndpointFields(
                  keyPrefix: 'player-proxy',
                  hostController: _playerHostController,
                  portController: _playerPortController,
                  portInvalid: _playerPortInvalid,
                  onHostChanged: (value) => proxyCtrl.proxyHost.v = normalizeProxyHost(value),
                  onPortChanged: (value) => _updatePort(value, isAppProxy: false),
                  portHint: '1080',
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
