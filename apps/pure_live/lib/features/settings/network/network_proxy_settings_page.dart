import 'dart:async' show unawaited;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show FilteringTextInputFormatter, LengthLimitingTextInputFormatter;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pure_live/app/preferences/app_preferences_providers.dart';
import 'package:pure_live/l10n/generated/strings.g.dart';
import 'package:pure_live/shared/widgets/settings_chrome.dart';
import 'package:pure_settings_ui/pure_settings_ui.dart';
import 'package:pure_uikit/pure_uikit.dart';

/// The network proxy settings page (the reference's two halves): the app
/// proxy every HTTP request consults per call (reroutes new connections
/// immediately, no restart), and the player proxy mpv pulls live streams
/// through — stored separately because the two often want different doors,
/// and read at each stream open (a running stream keeps the proxy it
/// started with, like every other next-open option).
final class NetworkProxySettingsPage extends ConsumerStatefulWidget {
  /// The network proxy settings page.
  const new({super.key});

  @override
  ConsumerState<NetworkProxySettingsPage> createState() => _NetworkProxySettingsPageState();
}

final class _NetworkProxySettingsPageState extends ConsumerState<NetworkProxySettingsPage> {
  late final TextEditingController _host;
  late final TextEditingController _port;
  late final TextEditingController _playerHost;
  late final TextEditingController _playerPort;
  bool _portInvalid = false;
  bool _playerPortInvalid = false;

  @override
  void initState() {
    super.initState();
    final preferences = ref.read(appPreferencesProvider);
    _host = TextEditingController(text: preferences.proxyHost);
    _port = TextEditingController(text: preferences.proxyPort.toString());
    _portInvalid = _parsePort(_port.text) == null;
    _playerHost = TextEditingController(text: preferences.playerProxyHost);
    _playerPort = TextEditingController(text: preferences.playerProxyPort.toString());
    _playerPortInvalid = _parsePort(_playerPort.text) == null;
  }

  @override
  void dispose() {
    _host.dispose();
    _port.dispose();
    _playerHost.dispose();
    _playerPort.dispose();
    super.dispose();
  }

  static int? _parsePort(String raw) {
    final port = int.tryParse(raw.trim());
    return port == null || port <= 0 || port > 65535 ? null : port;
  }

  void _updateHost(String raw) {
    final normalized = raw.trim();
    unawaited(
      ref
          .read(appPreferencesProvider.notifier)
          .update((p) => p.copyWith(proxyHost: normalized.isEmpty ? '127.0.0.1' : normalized)),
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

  void _updatePlayerHost(String raw) {
    final normalized = raw.trim();
    unawaited(
      ref
          .read(appPreferencesProvider.notifier)
          .update((p) => p.copyWith(playerProxyHost: normalized.isEmpty ? '127.0.0.1' : normalized)),
    );
  }

  void _updatePlayerPort(String raw) {
    final port = _parsePort(raw);
    final invalid = port == null;
    if (_playerPortInvalid != invalid) {
      setState(() => _playerPortInvalid = invalid);
    }
    if (port != null) {
      unawaited(ref.read(appPreferencesProvider.notifier).update((p) => p.copyWith(playerProxyPort: port)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final theme = PureTheme.of(context);
    final preferences = ref.watch(appPreferencesProvider);
    return SettingsChrome(
      title: t.settings.proxySettings,
      body: SettingsList(
        sections: [
          SettingsSection(
            title: Text(t.settings.proxyGroup),
            tiles: [
              SettingsTile.switchTile(
                leading: const Icon(Icons.vpn_key_outlined),
                title: Text(t.settings.proxyEnable),
                description: Text(t.settings.proxyEnableSubtitle),
                initialValue: preferences.proxyEnabled,
                onToggle: (value) =>
                    unawaited(ref.read(appPreferencesProvider.notifier).update((p) => p.copyWith(proxyEnabled: value))),
              ),
            ],
          ),
          // The endpoint fields exist only for a proxy that is on; a row the
          // switch hides is the reference's own gate, kept here.
          if (preferences.proxyEnabled)
            SettingsSection(
              title: Text(t.settings.proxyEndpoint),
              tiles: [
                CustomSettingsTile(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _proxyField(
                          context,
                          label: t.settings.proxyHost,
                          field: PureTextField(
                            controller: _host,
                            placeholder: '127.0.0.1',
                            keyboardType: TextInputType.url,
                            autocorrect: false,
                            enableSuggestions: false,
                            onChanged: _updateHost,
                          ),
                        ),
                        const SizedBox(height: 12),
                        _proxyField(
                          context,
                          label: t.settings.proxyPort,
                          field: PureTextField(
                            controller: _port,
                            placeholder: '7890',
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                              LengthLimitingTextInputFormatter(5),
                            ],
                            errorText: _portInvalid ? t.settings.proxyPortInvalid : null,
                            onChanged: _updatePort,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          t.settings.proxyHint,
                          style: theme.text.caption.copyWith(color: theme.colors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          SettingsSection(
            title: Text(t.settings.playerProxyGroup),
            tiles: [
              SettingsTile.switchTile(
                key: const ValueKey('player-proxy-enable'),
                leading: const Icon(Icons.play_circle_outlined),
                title: Text(t.settings.playerProxyEnable),
                description: Text(t.settings.playerProxyEnableDesc),
                initialValue: preferences.playerProxyEnabled,
                onToggle: (value) => unawaited(
                  ref.read(appPreferencesProvider.notifier).update((p) => p.copyWith(playerProxyEnabled: value)),
                ),
              ),
            ],
          ),
          if (preferences.playerProxyEnabled)
            SettingsSection(
              title: Text(t.settings.proxyEndpoint),
              tiles: [
                CustomSettingsTile(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _proxyField(
                          context,
                          label: t.settings.proxyHost,
                          field: PureTextField(
                            key: const ValueKey('player-proxy-host'),
                            controller: _playerHost,
                            placeholder: '127.0.0.1',
                            keyboardType: TextInputType.url,
                            autocorrect: false,
                            enableSuggestions: false,
                            onChanged: _updatePlayerHost,
                          ),
                        ),
                        const SizedBox(height: 12),
                        _proxyField(
                          context,
                          label: t.settings.proxyPort,
                          field: PureTextField(
                            key: const ValueKey('player-proxy-port'),
                            controller: _playerPort,
                            placeholder: '7890',
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                              LengthLimitingTextInputFormatter(5),
                            ],
                            errorText: _playerPortInvalid ? t.settings.proxyPortInvalid : null,
                            onChanged: _updatePlayerPort,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          t.settings.playerProxyHint,
                          style: theme.text.caption.copyWith(color: theme.colors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

/// A field with the name the Material `labelText` used to float inside it. The
/// dispatching field has no label slot in most of the nine libraries, so the
/// caption sits above it — the same line every other settings page uses.
Widget _proxyField(BuildContext context, {required String label, required Widget field}) {
  final theme = PureTheme.of(context);
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    mainAxisSize: MainAxisSize.min,
    children: [
      Padding(
        padding: const EdgeInsets.only(bottom: 4, left: 2),
        child: Text(label, style: theme.text.caption.copyWith(color: theme.colors.textSecondary)),
      ),
      field,
    ],
  );
}
