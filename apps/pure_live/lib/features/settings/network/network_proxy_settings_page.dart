import 'dart:async' show unawaited;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show FilteringTextInputFormatter, LengthLimitingTextInputFormatter;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pure_live/app/preferences/app_preferences_providers.dart';
import 'package:pure_live/features/settings/widgets/settings_sections.dart';
import 'package:pure_live/l10n/generated/strings.g.dart';
import 'package:pure_uikit/pure_uikit.dart';

/// The network proxy settings page (3.x `NetworkProxySettingsPage`, the app
/// proxy half): route outgoing requests through a user HTTP proxy.
///
/// The policy the network stack consults per request reads the persisted
/// preferences' in-memory value, so flipping the switch or editing the
/// endpoint reroutes new connections immediately — no restart. The player
/// proxy of the reference has no separate backing in this build and stays
/// out.
final class NetworkProxySettingsPage extends ConsumerStatefulWidget {
  /// The network proxy settings page.
  const new({super.key});

  @override
  ConsumerState<NetworkProxySettingsPage> createState() => _NetworkProxySettingsPageState();
}

final class _NetworkProxySettingsPageState extends ConsumerState<NetworkProxySettingsPage> {
  late final TextEditingController _host;
  late final TextEditingController _port;
  bool _portInvalid = false;

  @override
  void initState() {
    super.initState();
    final preferences = ref.read(appPreferencesProvider);
    _host = TextEditingController(text: preferences.proxyHost);
    _port = TextEditingController(text: preferences.proxyPort.toString());
    _portInvalid = _parsePort(_port.text) == null;
  }

  @override
  void dispose() {
    _host.dispose();
    _port.dispose();
    super.dispose();
  }

  static int? _parsePort(String raw) {
    final port = int.tryParse(raw.trim());
    return port == null || port <= 0 || port > 65535 ? null : port;
  }

  void _updateHost(String raw) {
    final normalized = raw.trim();
    unawaited(
      ref.read(appPreferencesProvider.notifier).update((p) => p.copyWith(proxyHost: normalized.isEmpty ? '127.0.0.1' : normalized)),
    );
  }

  void _updatePort(String raw) {
    final port = _parsePort(raw);
    final invalid = port == null;
    if (_portInvalid != invalid) {
      setState(() => _portInvalid = invalid);
    }
    if (port != null) {
      unawaited(ref.read(appPreferencesProvider.notifier).update((p) => p.copyWith(proxyPort: port)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final theme = PureTheme.of(context);
    final preferences = ref.watch(appPreferencesProvider);
    return PureScaffold(
      appBar: PureAppBar(title: t.settings.proxySettings),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          SettingsSection.card(
            label: t.settings.proxyGroup,
            tiles: [
              SettingsSwitchTile(
                icon: Icons.vpn_key_outlined,
                title: t.settings.proxyEnable,
                subtitle: t.settings.proxyEnableSubtitle,
                value: preferences.proxyEnabled,
                onChanged: (value) {
                  unawaited(ref.read(appPreferencesProvider.notifier).update((p) => p.copyWith(proxyEnabled: value)));
                },
              ),
            ],
          ),
          if (preferences.proxyEnabled) ...[
            const SettingsSectionGap(),
            SettingsSection(
              label: t.settings.proxyEndpoint,
              children: [
                PureCard(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: _host,
                        keyboardType: TextInputType.url,
                        autocorrect: false,
                        enableSuggestions: false,
                        decoration: InputDecoration(
                          labelText: t.settings.proxyHost,
                          hintText: '127.0.0.1',
                          border: const OutlineInputBorder(),
                          isDense: true,
                        ),
                        onChanged: _updateHost,
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _port,
                        keyboardType: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(5)],
                        decoration: InputDecoration(
                          labelText: t.settings.proxyPort,
                          hintText: '7890',
                          errorText: _portInvalid ? t.settings.proxyPortInvalid : null,
                          border: const OutlineInputBorder(),
                          isDense: true,
                        ),
                        onChanged: _updatePort,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        t.settings.proxyHint,
                        style: theme.text.caption.copyWith(color: theme.colors.textSecondary),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}
