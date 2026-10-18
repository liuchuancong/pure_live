import 'dart:async' show unawaited;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pretty_qr_code/pretty_qr_code.dart';

import 'package:pure_live/features/remote_receiver/remote_sync_device.dart';
import 'package:pure_live/features/remote_receiver/remote_sync_payload.dart';
import 'package:pure_live/features/remote_receiver/remote_sync_protocol.dart';
import 'package:pure_live/features/remote_receiver/remote_sync_providers.dart';
import 'package:pure_live/features/remote_receiver/remote_sync_service.dart';
import 'package:pure_live/l10n/generated/strings.g.dart';
import 'package:pure_live/shared/widgets/settings_entry_button.dart';
import 'package:pure_uikit/pure_uikit.dart';

/// The width from which the page lays its two halves side by side (the
/// reference's `remoteSyncTwoColumns`, A12.6 S2).
const double remoteSyncTwoColumns = 840;

/// Device sync, in the reference's v5 form (A12.6): while the page is open
/// this device serves its payload to a peer the user lets in; it can also
/// send to, or take from, a device found on the network or typed in.
///
/// The reference's pairing-code gate has no backing in this build's wire
/// (the 3.x-compatible protocol answers with the on-screen allow/reject
/// dialog instead), and the accounts switch ships nothing here to carry
/// accounts — both stay out rather than being faked.
final class RemoteSyncPage extends ConsumerStatefulWidget {
  /// The LAN sync page.
  const new({super.key});

  @override
  ConsumerState<RemoteSyncPage> createState() => _RemoteSyncPageState();
}

final class _RemoteSyncPageState extends ConsumerState<RemoteSyncPage> {
  late final RemoteSyncService _service;
  final _address = TextEditingController();

  @override
  void initState() {
    super.initState();
    _service = ref.read(remoteSyncServiceProvider);
    _service.confirmRequest = _confirmIncoming;
    // The page serves while it is open (the reference starts on entry).
    unawaited(_service.start());
  }

  @override
  void dispose() {
    if (identical(_service.confirmRequest, _confirmIncoming)) {
      _service.confirmRequest = null;
    }
    _address.dispose();
    super.dispose();
  }

  void _toast(String message, {PureToastType type = PureToastType.error}) {
    if (mounted) {
      PureToast.show(context, message, type: type);
    }
  }

  /// Another device asks to read or overwrite this device's payload; the
  /// page cannot be left until the user answers, and the buttons say what
  /// they do ("拒绝" / "允许").
  Future<bool> _confirmIncoming(String action, String remoteAddress) async {
    if (!mounted) {
      return false;
    }
    final t = context.t;
    final name = _service.nameOf(remoteAddress);
    final (address, _) = _splitAddress(remoteAddress);
    final allowed = await showPureDialog<bool>(
      context: context,
      dismissible: false,
      child: Text(
        switch ((action == 'import', name == null)) {
          (true, true) => t.remoteSync.incomingImport(address: address),
          (true, false) => t.remoteSync.incomingImportNamed(address: address, name: name!),
          (false, true) => t.remoteSync.incomingExport(address: address),
          (false, false) => t.remoteSync.incomingExportNamed(address: address, name: name!),
        },
      ),
      actions: (dialogContext) => [
        PureButton(
          key: const ValueKey('remote-sync-reject'),
          label: dialogContext.t.remoteSync.reject,
          variant: ButtonVariant.ghost,
          onPressed: () => Navigator.of(dialogContext).pop(false),
        ),
        PureButton(
          key: const ValueKey('remote-sync-allow'),
          label: dialogContext.t.remoteSync.allow,
          onPressed: () => Navigator.of(dialogContext).pop(true),
        ),
      ],
    );
    return allowed == true;
  }

  static (String, int) _splitAddress(String address) {
    final at = address.lastIndexOf(':');
    if (at <= 0) {
      return (address, 0);
    }
    return (address.substring(0, at), int.tryParse(address.substring(at + 1)) ?? 0);
  }

  /// One peer of the list, the typed address, or the raw remote address as
  /// shown by the connection info.
  ({String name, String detail}) _peerOf(RemoteSyncDevice device) {
    final t = context.t;
    final detail = [
      device.address,
      // 3.x announces the fixed "1.0.0"; say which app it is instead.
      if (device.version == '1.0.0' || device.version.isEmpty) t.remoteSync.legacyDevice else 'v${device.version}',
    ].join(' · ');
    return (name: device.name, detail: detail);
  }

  /// The module picker: the payload's sections as checkboxes; null means
  /// cancelled.
  Future<List<String>?> _pickSections(List<String> available, {required bool exporting}) {
    if (available.isEmpty) {
      return Future<List<String>?>.value(const <String>[]);
    }
    final selected = {...available};
    String label(String section) => switch (section) {
      'favorite' => context.t.remoteSync.sectionFavorite,
      'history' => context.t.remoteSync.sectionHistory,
      'tags' => context.t.remoteSync.sectionGroups,
      'roomCard' => context.t.settings.roomCardSettings,
      'refresh' => context.t.settings.refreshSettings,
      'page' => context.t.settings.pageSettings,
      'proxy' => context.t.settings.proxySettings,
      'loading' => context.t.settings.loadingStyle,
      _ => section,
    };
    return showPureDialog<List<String>>(
      context: context,
      title: exporting ? context.t.remoteSync.send : context.t.remoteSync.receive,
      child: StatefulBuilder(
        builder: (dialogContext, setDialogState) => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final section in available)
              PureCheckbox(
                key: ValueKey('remote-sync-part-$section'),
                value: selected.contains(section),
                label: label(section),
                onChanged: (value) => setDialogState(() {
                  if (value) {
                    selected.add(section);
                  } else {
                    selected.remove(section);
                  }
                }),
              ),
          ],
        ),
      ),
      actions: (dialogContext) => [
        PureButton(
          label: dialogContext.t.common.cancel,
          variant: ButtonVariant.ghost,
          onPressed: () => Navigator.of(dialogContext).pop(),
        ),
        PureButton(
          key: const ValueKey('remote-sync-confirm'),
          label: dialogContext.t.common.confirm,
          onPressed: () => Navigator.of(dialogContext).pop(selected.toList()),
        ),
      ],
    );
  }

  Future<void> _sendTo(String ip, int port) async {
    final sections = await _pickSections(_service.exportSectionNames(), exporting: true);
    if (sections == null || !mounted) {
      return;
    }
    final success = await _service.syncToAddress(ip, port, sections: sections);
    if (!mounted) {
      return;
    }
    _toast(
      success ? context.t.remoteSync.sendSuccess : context.t.remoteSync.sendFailed,
      type: success ? PureToastType.success : PureToastType.error,
    );
  }

  Future<void> _receiveFrom(String ip, int port) async {
    final settings = await _service.getRemoteSettings(ip, port);
    if (!mounted) {
      return;
    }
    if (settings == null) {
      _toast(context.t.remoteSync.receiveFailed);
      return;
    }
    final available = RemoteSyncPayload.presentSections(settings);
    final sections = await _pickSections(available, exporting: false);
    if (sections == null || !mounted) {
      return;
    }
    final success = await _service.applyRemoteSettings(settings, sections: sections);
    if (!mounted) {
      return;
    }
    _toast(
      success ? context.t.remoteSync.receiveSuccess : context.t.remoteSync.receiveFailed,
      type: success ? PureToastType.success : PureToastType.error,
    );
  }

  ({String ip, int port})? _typed() {
    final value = _address.text.trim();
    if (value.isEmpty) {
      _toast(context.t.remoteSync.enterAddress);
      return null;
    }
    final parsed = RemoteSyncProtocol.parseHttpAddress(value);
    if (parsed == null) {
      _toast(context.t.remoteSync.invalidAddress);
    }
    return parsed;
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    return PureScaffold(
      appBar: PureAppBar(
        title: t.remoteSync.title,
        actions: [
          ListenableBuilder(
            listenable: _service,
            builder: (context, _) => PureIconButton(
              key: const ValueKey('remote-sync-toggle'),
              tooltip: _service.isServerRunning ? t.remoteSync.stop : t.remoteSync.start,
              icon: _service.isServerRunning ? Icons.stop_circle_outlined : Icons.play_circle_outline,
              onPressed: () => unawaited(_service.isServerRunning ? _service.stop() : _service.start()),
            ),
          ),
          const SettingsEntryButton(),
        ],
        // The one request line while a payload is on the wire (the
        // reference's app-bar bottom progress).
        bottom: _service.isSyncing || _service.isApplying
            ? const PreferredSize(preferredSize: Size.fromHeight(2), child: LinearProgressIndicator(minHeight: 2))
            : null,
      ),
      body: ListenableBuilder(
        listenable: _service,
        builder: (context, _) => LayoutBuilder(
          builder: (context, constraints) {
            // Two columns on wide windows; a phone held sideways (short)
            // keeps one (docs/specs/UI.md §5.1).
            final two = constraints.maxWidth >= remoteSyncTwoColumns && constraints.maxHeight >= 480;
            final theme = PureTheme.of(context);
            final local = _group(context, t.remoteSync.myDevice, _localDevice(theme), first: true);
            final others = [
              _group(
                context,
                t.remoteSync.devices,
                _discovered(theme),
                first: two,
                trailing: _service.isServerRunning ? _searching(context) : null,
              ),
              _group(context, t.remoteSync.manual, _manual(theme)),
            ];
            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
              child: Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: two ? 1120 : 640),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(4, 8, 4, 0),
                        child: Text(
                          t.remoteSync.description,
                          style: theme.text.bodySmall.copyWith(color: theme.colors.textSecondary),
                        ),
                      ),
                      if (two)
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(child: local),
                            const SizedBox(width: 32),
                            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: others)),
                          ],
                        )
                      else ...[local, ...others],
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  /// A titled card (the settings groups' look: title outside, card below).
  Widget _group(BuildContext context, String title, Widget child, {bool first = false, Widget? trailing}) {
    final theme = PureTheme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(16, first ? 12 : 18, 8, 8),
          child: Row(
            children: [
              Expanded(
                child: Semantics(
                  header: true,
                  child: Text(
                    title,
                    style: theme.text.bodySmall.copyWith(color: theme.colors.primary, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              ?trailing,
            ],
          ),
        ),
        PureCard(padding: EdgeInsets.zero, child: child),
      ],
    );
  }

  Widget _searching(BuildContext context) {
    final theme = PureTheme.of(context);
    return Row(
      key: const ValueKey('remote-sync-searching'),
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox.square(dimension: 14, child: PureSpinner(size: 14)),
        const SizedBox(width: 6),
        Text(
          context.t.remoteSync.searchingShort,
          style: theme.text.bodySmall.copyWith(color: theme.colors.textSecondary),
        ),
      ],
    );
  }

  Widget _localDevice(PureTheme theme) {
    final t = context.t;
    final service = _service;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
      child: Column(
        children: [
          if (service.address.isEmpty) ...[
            Container(
              key: const ValueKey('remote-sync-no-address'),
              width: 96,
              height: 96,
              decoration: BoxDecoration(color: theme.colors.fillSecondary, shape: BoxShape.circle),
              child: Icon(Icons.wifi_off, size: 48, color: theme.colors.textSecondary),
            ),
            const SizedBox(height: 12),
            Text(t.remoteSync.noAddress, style: theme.text.title),
            const SizedBox(height: 4),
            Text(
              t.remoteSync.noAddressHint,
              textAlign: TextAlign.center,
              style: theme.text.bodySmall.copyWith(color: theme.colors.textSecondary),
            ),
          ] else ...[
            if (service.qrData.isNotEmpty)
              Container(
                key: const ValueKey('remote-sync-qr'),
                padding: const EdgeInsets.all(12),
                color: Colors.white,
                child: SizedBox(width: 180, height: 180, child: PrettyQrView.data(data: service.qrData)),
              ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // One line: an address split mid-number misleads (A04.1);
                // large text shrinks it to fit instead.
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: SelectableText(
                      service.address,
                      key: const ValueKey('remote-sync-address'),
                      maxLines: 1,
                      style: theme.text.subtitle.copyWith(fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
                PureIconButton(
                  key: const ValueKey('remote-sync-copy'),
                  tooltip: t.remoteSync.copyAddress,
                  icon: Icons.copy_rounded,
                  size: ControlSize.sm,
                  onPressed: () async {
                    await Clipboard.setData(ClipboardData(text: service.address));
                    if (mounted) {
                      _toast(t.remoteSync.addressCopied, type: PureToastType.success);
                    }
                  },
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              t.remoteSync.scanHint,
              textAlign: TextAlign.center,
              style: theme.text.bodySmall.copyWith(color: theme.colors.textSecondary),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            key: const ValueKey('remote-sync-status'),
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                service.isServerRunning ? Icons.check_circle : Icons.error_outline,
                size: 18,
                color: service.isServerRunning ? theme.colors.success : theme.colors.error,
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  service.isServerRunning ? t.remoteSync.running : t.remoteSync.notRunning,
                  style: theme.text.body.copyWith(
                    color: service.isServerRunning ? theme.colors.text : theme.colors.error,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _discovered(PureTheme theme) {
    final devices = _service.devices;
    if (devices.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
        child: Center(
          child: Text(
            _service.isServerRunning ? context.t.remoteSync.searching : context.t.remoteSync.noDevices,
            key: const ValueKey('remote-sync-no-devices'),
            style: theme.text.body.copyWith(color: theme.colors.textSecondary),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    return Column(
      children: [
        for (final (index, device) in devices.indexed) ...[
          if (index > 0) Divider(height: 1, indent: 16, endIndent: 16, color: theme.colors.border),
          _device(theme, device),
        ],
      ],
    );
  }

  Widget _device(PureTheme theme, RemoteSyncDevice device) {
    final peer = _peerOf(device);
    final icon = switch (device.platform) {
      'android' || 'ios' => Icons.smartphone,
      'windows' || 'macos' || 'linux' => Icons.desktop_windows,
      _ => Icons.devices_other,
    };
    final busy = _service.isSyncing;
    return Padding(
      key: ValueKey('remote-sync-device-${device.id}'),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(icon, size: 24, color: theme.colors.textSecondary),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(device.name, style: theme.text.body.copyWith(fontWeight: FontWeight.w600)),
                    Text(
                      peer.detail,
                      key: ValueKey('remote-sync-device-detail-${device.id}'),
                      style: theme.text.bodySmall.copyWith(color: theme.colors.textSecondary),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _buttons(
            busy: busy,
            onReceive: () => unawaited(_receiveFrom(device.ip, device.port)),
            onSend: () => unawaited(_sendTo(device.ip, device.port)),
          ),
        ],
      ),
    );
  }

  Widget _manual(PureTheme theme) {
    final t = context.t;
    final busy = _service.isSyncing;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            t.remoteSync.manualHint,
            style: theme.text.bodySmall.copyWith(color: theme.colors.textSecondary),
          ),
          const SizedBox(height: 12),
          PureTextField(
            key: const ValueKey('remote-sync-target'),
            controller: _address,
            placeholder: '192.168.1.100:39888',
            keyboardType: TextInputType.url,
            prefix: const Icon(Icons.lan_outlined),
          ),
          const SizedBox(height: 12),
          _buttons(
            busy: busy,
            onReceive: () {
              if (_typed() case final target?) unawaited(_receiveFrom(target.ip, target.port));
            },
            onSend: () {
              if (_typed() case final target?) unawaited(_sendTo(target.ip, target.port));
            },
          ),
        ],
      ),
    );
  }

  /// "接收配置" (secondary) then "发送配置" (primary), everywhere (A12.6 c4).
  Widget _buttons({required bool busy, required VoidCallback onReceive, required VoidCallback onSend}) {
    final t = context.t;
    return Row(
      children: [
        Expanded(
          child: PureButton(
            key: const ValueKey('remote-sync-receive'),
            label: t.remoteSync.receive,
            icon: Icons.download_outlined,
            variant: ButtonVariant.secondary,
            expand: true,
            onPressed: busy ? null : onReceive,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: PureButton(
            key: const ValueKey('remote-sync-send'),
            label: t.remoteSync.send,
            icon: Icons.upload_outlined,
            expand: true,
            onPressed: busy ? null : onSend,
          ),
        ),
      ],
    );
  }
}
