import 'dart:async' show unawaited;

import 'package:desen_ui/desen_ui.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_device/live_device.dart' show SystemProxyEndpoint, SystemProxyStatus;

import 'package:pure_live/app/providers/network/network_providers.dart' show ProxyMode, proxySettingsProvider;
import 'package:pure_live/app/providers/network/system_proxy_provider.dart' show systemProxyProvider;
import 'package:pure_live/features/settings/panes/github_mirror_pane.dart' show GithubMirrorSection;
import 'package:pure_live/features/settings/surface/settings_child_entry.dart' show SettingsChildEntry;
import 'package:pure_live/features/settings/surface/settings_sections.dart' show SettingsSection;
import 'package:pure_live/features/settings/surface/settings_widgets.dart' show SettingsChoiceRow, SettingsConfigRow;
import 'package:pure_live/l10n/translations.dart';

enum NetworkTab {
  /// The proxy the shared transport factory applies to every module's
  /// requests — vod, the IPTV guide, backups.
  app,

  /// The acceleration card and the mirror list GitHub downloads go through.
  github,
}

/// The network pane (the reference's custom network proxy), its two faces on
/// a segmented control: the app proxy and the GitHub acceleration used to be
/// one scroll where the second buried the first. The tools order moved to the
/// navigation pane.
final class NetworkPane extends ConsumerStatefulWidget {
  const NetworkPane({super.key});

  @override
  ConsumerState<NetworkPane> createState() => NetworkPaneState();
}

final class NetworkPaneState extends ConsumerState<NetworkPane> {
  NetworkTab _tab = NetworkTab.app;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: DsSpace.s16,
      children: [
        // Two names fit any pane, but the control keeps the same frame as the
        // longer category controls beside it.
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DsSegmentedControl<NetworkTab>(
              value: _tab,
              semanticLabel: t.settings.navNetwork,
              segments: [
                DsSegment(
                  value: NetworkTab.app,
                  label: Text(t.settings.proxy),
                  icon: const DsIcon(DsIcons.globe, size: 16),
                ),
                DsSegment(
                  value: NetworkTab.github,
                  label: Text(t.settings.githubMirrorTitle),
                  icon: const DsIcon(DsIcons.download, size: 16),
                ),
              ],
              onChanged: (value) => setState(() => _tab = value),
            ),
          ),
        ),
        switch (_tab) {
          NetworkTab.app => _appProxy(context),
          NetworkTab.github => const GithubMirrorSection(),
        },
        // The platform probe is a page of its own, reached from here — the
        // network surface is its parent, whichever tab is open.
        const DsListSection(children: [SettingsChildEntry(child: SettingsSection.nodes)]),
      ],
    );
  }

  /// The app proxy: the mode, the endpoint it types, and the system reading
  /// under it. The segment labels the group, so the section carries no header.
  Widget _appProxy(BuildContext context) {
    final t = context.t;
    final proxy = ref.watch(proxySettingsProvider);
    final controller = ref.read(proxySettingsProvider.notifier);
    final system = ref.watch(systemProxyProvider);
    // Only the manual mode types an endpoint; the other two answer from the
    // platform or from nothing at all.
    final manual = proxy.mode == ProxyMode.manual;
    // What the vault holds, as opposed to what is typed in the field beside it:
    // the secret is read back on its own clock, so a plain text field would
    // claim "nothing saved" for the moment before it lands.
    final passwordSaved = proxy.password.isNotEmpty;
    final muted = DsTheme.of(context).typography.caption.copyWith(color: DsTheme.colorsOf(context).textMuted);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: DsSpace.s16,
      children: [
        DsListSection(
          children: [
            SettingsChoiceRow<ProxyMode>(
              leading: const DsIcon(DsIcons.globe),
              title: t.settings.proxy,
              description: switch (proxy.mode) {
                ProxyMode.off => t.settings.proxyModeOffDesc,
                ProxyMode.system => t.settings.proxyModeSystemDesc,
                ProxyMode.manual => t.settings.proxyModeManualDesc,
              },
              value: proxy.mode,
              options: [
                DsSelectOption(value: ProxyMode.off, label: t.settings.proxyModeOff),
                DsSelectOption(value: ProxyMode.system, label: t.settings.proxyModeSystem),
                DsSelectOption(value: ProxyMode.manual, label: t.settings.proxyModeManual),
              ],
              onChanged: (mode) => unawaited(controller.setMode(mode)),
            ),
            SettingsConfigRow(
              leading: const DsIcon(DsIcons.server),
              title: t.settings.proxyHost,
              description: t.settings.proxyHostDesc,
              controlWidth: 220,
              // The endpoint stays on screen with the proxy off, greyed out:
              // a row that vanishes reads as a setting that went missing.
              control: DsTextField(
                initialValue: proxy.host,
                clearable: true,
                enabled: manual,
                placeholder: t.settings.proxyHost,
                onChanged: (value) => unawaited(controller.setHost(value)),
                semanticLabel: t.settings.proxyHost,
              ),
            ),
            SettingsConfigRow(
              leading: const DsIcon(DsIcons.hash),
              title: t.settings.proxyPort,
              description: t.settings.proxyPortDesc,
              controlWidth: 220,
              control: DsTextField(
                initialValue: '${proxy.port}',
                enabled: manual,
                placeholder: t.settings.proxyPort,
                keyboardType: TextInputType.number,
                onChanged: (value) {
                  final port = int.tryParse(value.trim());
                  if (port != null) unawaited(controller.setPort(port));
                },
                semanticLabel: t.settings.proxyPort,
              ),
            ),
            SettingsConfigRow(
              leading: const DsIcon(DsIcons.user),
              title: t.settings.proxyUsername,
              description: t.settings.proxyUsernameDesc,
              controlWidth: 220,
              control: DsTextField(
                initialValue: proxy.username,
                clearable: true,
                enabled: manual,
                placeholder: t.settings.proxyUsername,
                onChanged: (value) => unawaited(controller.setUsername(value)),
                semanticLabel: t.settings.proxyUsername,
              ),
            ),
            SettingsConfigRow(
              leading: const DsIcon(DsIcons.key),
              title: t.settings.proxyPassword,
              detail: Text(passwordSaved ? t.settings.proxyPasswordSaved : t.settings.proxyPasswordNone),
              description: t.settings.proxyPasswordDesc,
              controlWidth: 220,
              // The stored secret is never put into this field: from here on it
              // is write-only, and typing is what replaces it.
              control: DsTextField(
                obscureText: true,
                revealable: true,
                enabled: manual,
                placeholder: passwordSaved ? t.settings.proxyPasswordReplace : t.settings.proxyPassword,
                onChanged: (value) {
                  if (value.isEmpty) return;
                  unawaited(controller.setPassword(value));
                },
                semanticLabel: t.settings.proxyPassword,
              ),
            ),
            if (passwordSaved)
              DsListRow(
                leading: const DsIcon(DsIcons.trash2),
                title: Text(t.settings.proxyPasswordClear),
                description: Text(t.settings.proxyPasswordClearDesc),
                destructive: true,
                onPressed: () => unawaited(controller.setPassword('')),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(DsSpace.s20, DsSpace.s4, DsSpace.s20, DsSpace.s12),
              child: Text(_systemProxyStatusText(t, system), style: muted),
            ),
            // The recheck belongs with the reading it refreshes; a lone
            // section under it would read as a separate feature.
            DsListRow(
              leading: const DsIcon(DsIcons.refresh),
              title: Text(t.settings.proxySystemRecheck),
              description: Text(t.settings.proxySystemRecheckDesc),
              onPressed: () => unawaited(ref.read(systemProxyProvider.notifier).refresh()),
            ),
          ],
        ),
      ],
    );
  }
}

/// What the system-proxy reading amounts to, in the words the network page
/// prints under the mode row.
///
/// A PAC script or a SOCKS-only setting says so rather than reporting "none":
/// the difference is what tells a viewer to type the endpoint instead.
String _systemProxyStatusText(Translations t, SystemProxyEndpoint endpoint) => switch (endpoint.status) {
  SystemProxyStatus.probing => t.settings.proxySystemProbing,
  SystemProxyStatus.resolved => t.settings.proxySystemResolved(host: endpoint.authority),
  SystemProxyStatus.notConfigured => t.settings.proxySystemNone,
  SystemProxyStatus.notExpressible => t.settings.proxySystemNotExpressible,
  SystemProxyStatus.unsupported => t.settings.proxySystemUnsupported,
  SystemProxyStatus.failed => t.settings.proxySystemFailed,
};
