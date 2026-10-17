import 'dart:async' show unawaited;

import 'package:flutter/material.dart';
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

/// LAN sync (3.x `RemoteSyncPage`): this device shows its address and QR,
/// lists the peers discovered on the network, and sends or receives a
/// payload against any of them or a typed address. Every incoming read or
/// overwrite of this device's data lands on the confirm dialog below, the
/// 3.x pairing gate.
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

  /// Another device asks to read or overwrite this device's payload.
  Future<bool> _confirmIncoming(String action, String remoteAddress) async {
    if (!mounted) {
      return false;
    }
    final confirmed = await showPureDialog<bool>(
      context: context,
      title: context.t.remoteSync.title,
      dismissible: false,
      child: Text(
        action == 'import'
            ? context.t.remoteSync.incomingImport(address: remoteAddress)
            : context.t.remoteSync.incomingExport(address: remoteAddress),
      ),
      actions: (dialogContext) => [
        PureButton(
          label: dialogContext.t.common.cancel,
          variant: ButtonVariant.ghost,
          onPressed: () => Navigator.of(dialogContext).pop(false),
        ),
        PureButton(label: dialogContext.t.common.confirm, onPressed: () => Navigator.of(dialogContext).pop(true)),
      ],
    );
    return confirmed == true;
  }

  /// The module picker (3.x `pickBackupSections`): the payload's sections as
  /// checkboxes; null means cancelled, empty never happens while any section
  /// is offered.
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
          label: dialogContext.t.common.confirm,
          onPressed: () => Navigator.of(dialogContext).pop(selected.toList()),
        ),
      ],
    );
  }

  Future<void> _sendToDevice(String ip, int port) async {
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

  Future<void> _receiveFromDevice(String ip, int port) async {
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

  ({String ip, int port})? _manualAddress() {
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
    final theme = PureTheme.of(context);
    return PureScaffold(
      appBar: PureAppBar(
        title: context.t.remoteSync.title,
        actions: [
          ListenableBuilder(
            listenable: _service,
            builder: (context, _) => PureIconButton(
              tooltip: _service.isDiscovering ? context.t.remoteSync.stop : context.t.remoteSync.start,
              icon: _service.isDiscovering ? Icons.stop_circle_outlined : Icons.play_circle_outline,
              onPressed: () => unawaited(_service.isDiscovering ? _service.stop() : _service.start()),
            ),
          ),
          const SettingsEntryButton(),
        ],
      ),
      body: ListenableBuilder(
        listenable: _service,
        builder: (context, _) => ListView(
          padding: const EdgeInsets.all(12),
          children: [
            _localDeviceCard(theme),
            const SizedBox(height: 16),
            _discoveredDevicesCard(theme),
            const SizedBox(height: 16),
            _manualAddressCard(theme),
          ],
        ),
      ),
    );
  }

  Widget _localDeviceCard(PureTheme theme) {
    return PureCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Text(context.t.remoteSync.myDevice, style: theme.text.title),
          const SizedBox(height: 16),
          if (_service.qrData.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(12),
              color: Colors.white,
              child: SizedBox(width: 180, height: 180, child: PrettyQrView.data(data: _service.qrData)),
            ),
          const SizedBox(height: 12),
          SelectableText(
            _service.address.isEmpty ? context.t.remoteSync.noAddress : _service.address,
            style: theme.text.subtitle.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Text(
            context.t.remoteSync.scanHint,
            textAlign: TextAlign.center,
            style: theme.text.caption.copyWith(color: theme.colors.textSecondary),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                _service.isServerRunning ? Icons.check_circle : Icons.error_outline,
                size: 18,
                color: _service.isServerRunning ? theme.colors.success : theme.colors.error,
              ),
              const SizedBox(width: 6),
              Text(_service.isServerRunning ? context.t.remoteSync.running : context.t.remoteSync.notRunning),
            ],
          ),
          if (_service.isSyncing || _service.isApplying) ...[const SizedBox(height: 12), const LinearIndeterminate()],
        ],
      ),
    );
  }

  Widget _discoveredDevicesCard(PureTheme theme) {
    return PureCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(context.t.remoteSync.devices, style: theme.text.title)),
              if (_service.isDiscovering) const SizedBox(width: 18, height: 18, child: PureSpinner()),
            ],
          ),
          const SizedBox(height: 12),
          if (_service.devices.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Center(child: Text(context.t.remoteSync.noDevices)),
            )
          else
            for (final device in _service.devices) _deviceTile(theme, device),
        ],
      ),
    );
  }

  Widget _deviceTile(PureTheme theme, RemoteSyncDevice device) {
    final busy = _service.isSyncing;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.devices),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(device.name, style: theme.text.body.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text(device.address, style: theme.text.caption.copyWith(color: theme.colors.textSecondary)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: PureButton(
                  label: context.t.remoteSync.receive,
                  icon: Icons.download_outlined,
                  variant: ButtonVariant.secondary,
                  onPressed: busy ? null : () => unawaited(_receiveFromDevice(device.ip, device.port)),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: PureButton(
                  label: context.t.remoteSync.send,
                  icon: Icons.upload_outlined,
                  onPressed: busy ? null : () => unawaited(_sendToDevice(device.ip, device.port)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _manualAddressCard(PureTheme theme) {
    final busy = _service.isSyncing;
    return PureCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(context.t.remoteSync.manual, style: theme.text.title),
          const SizedBox(height: 12),
          PureTextField(
            controller: _address,
            placeholder: '192.168.1.100:39888',
            keyboardType: TextInputType.url,
            prefix: const Icon(Icons.lan),
          ),
          const SizedBox(height: 12),
          PureButton(
            label: context.t.remoteSync.send,
            icon: Icons.upload_outlined,
            expand: true,
            onPressed: busy
                ? null
                : () {
                    final parsed = _manualAddress();
                    if (parsed != null) {
                      unawaited(_sendToDevice(parsed.ip, parsed.port));
                    }
                  },
          ),
          const SizedBox(height: 8),
          PureButton(
            label: context.t.remoteSync.receive,
            icon: Icons.download_outlined,
            variant: ButtonVariant.secondary,
            expand: true,
            onPressed: busy
                ? null
                : () {
                    final parsed = _manualAddress();
                    if (parsed != null) {
                      unawaited(_receiveFromDevice(parsed.ip, parsed.port));
                    }
                  },
          ),
        ],
      ),
    );
  }
}
