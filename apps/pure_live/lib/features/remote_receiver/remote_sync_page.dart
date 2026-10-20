import 'dart:async' show unawaited;
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData, FilteringTextInputFormatter;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pretty_qr_code/pretty_qr_code.dart';

import 'package:pure_live/features/remote_receiver/remote_sync_device.dart';
import 'package:pure_live/features/remote_receiver/remote_sync_parts.dart';
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

/// Who another device is: its name and the line under it.
typedef SyncPeer = ({String name, String ip, int port, String detail});

/// One box of the parts dialog: the part and its words.
typedef SyncPartRow = ({RemoteSyncPart part, String text});

/// Device sync, in the reference's v5 form (A12.6): while the page is open
/// this device serves its payload to peers that carry the six-digit pairing
/// code shown here AND that the user lets in; it can also send to, or take
/// from, a device found on the network or typed in (a bare address, or the
/// text of a sync QR code — which carries the pairing code, so scanning and
/// retyping collapse into pasting). Every send and receive goes through the
/// pick-list first: what travels is ticked part by part (J05.1), a taking
/// device previews what it changes, and a 3.x peer that cannot hold parts
/// apart gets everything — the boxes stay ticked and say why.
///
/// The reference's camera QR *scan* has no backing in this build (no
/// scanner package, desktop-first); the same QR text pastes into the manual
/// field, address and pairing code together.
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
    _service = ref.read(remoteSyncServiceProvider)
      ..confirmRequest = _confirmIncoming
      ..chooseImport = _chooseIncoming;
    // The page serves while it is open (the reference starts on entry).
    unawaited(_service.start());
  }

  @override
  void dispose() {
    if (identical(_service.confirmRequest, _confirmIncoming)) {
      _service
        ..confirmRequest = null
        ..chooseImport = null;
    }
    _address.dispose();
    super.dispose();
  }

  void _toast(String message, {PureToastType type = PureToastType.error}) {
    if (mounted) {
      PureToast.show(context, message, type: type);
    }
  }

  /// Another device asks to read this device's payload; the page cannot be
  /// left until the user answers. Imports answer through [_chooseIncoming]
  /// instead, where the parts are ticked on the preview.
  Future<bool> _confirmIncoming(String action, String remoteAddress) async {
    if (!mounted) {
      return false;
    }
    final t = context.t;
    final name = _service.nameOf(remoteAddress);
    final allowed = await showPureDialog<bool>(
      context: context,
      dismissible: false,
      child: Text(switch ((action == 'import', name == null)) {
        (true, true) => t.remoteSync.incomingImport(address: remoteAddress),
        (true, false) => t.remoteSync.incomingImportNamed(address: remoteAddress, name: name!),
        (false, true) => t.remoteSync.incomingExport(address: remoteAddress),
        (false, false) => t.remoteSync.incomingExportNamed(address: remoteAddress, name: name!),
      }),
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

  /// Another device sends its payload: who, what it changes, each part
  /// ticked; "拒绝" / "允许" with no closing outside. Null refuses them all.
  Future<Set<RemoteSyncPart>?> _chooseIncoming(String remoteAddress, Map<String, dynamic> settings) async {
    if (!mounted) {
      return null;
    }
    final t = context.t;
    final name = _service.nameOf(remoteAddress);
    return await showPureDialog<Set<RemoteSyncPart>>(
      context: context,
      dismissible: false,
      child: _previewDialog(
        settings,
        title: t.remoteSync.title,
        message: name == null
            ? t.remoteSync.incomingImport(address: remoteAddress)
            : t.remoteSync.incomingImportNamed(address: remoteAddress, name: name),
        cancelLabel: t.remoteSync.reject,
        cancelKey: const ValueKey('remote-sync-reject'),
        confirmLabel: t.remoteSync.allow,
        confirmKey: const ValueKey('remote-sync-allow'),
        contentKey: const ValueKey('remote-sync-incoming'),
      ),
    );
  }

  /// Send: what goes, ticked (J05.1), the pairing code, then send. A device
  /// that cannot take parts on their own (3.x) gets everything: the boxes
  /// stay ticked and say why.
  Future<void> _send(SyncPeer peer, {String? code}) async {
    final t = context.t;
    final partial = await _service.takesParts(peer.ip, peer.port);
    if (!mounted) {
      return;
    }
    final settings = await _service.outgoing();
    if (!mounted) {
      return;
    }
    final held = syncPartsIn(settings).toSet();
    final rows = _countRows(settings);
    final parts = await showPureDialog<Set<RemoteSyncPart>>(
      context: context,
      child: _PartsDialogBody(
        title: t.remoteSync.send,
        message: partial
            ? t.remoteSync.partsSendNamed(name: peer.name)
            : t.remoteSync.confirmSendNamed(name: peer.name),
        rows: rows,
        // Parts the data holds without a box of their own go with the
        // result when every box is ticked, so a whole send stays whole.
        always: held.difference({for (final row in rows) row.part}),
        locked: !partial,
        note: partial ? null : t.remoteSync.partsLegacy,
        confirmLabel: t.remoteSync.sendAction,
        confirmKey: const ValueKey('remote-sync-confirm'),
      ),
    );
    if (parts == null || parts.isEmpty || !mounted) {
      return;
    }
    final pairing = code ?? await _askPairingCode(peer, action: t.remoteSync.sendAction);
    if (pairing == null) {
      return;
    }
    final ok = await _service.send(peer.ip, peer.port, pairing, parts: partial ? parts : null);
    _toast(
      ok ? t.remoteSync.sendSuccess : t.remoteSync.sendFailed,
      type: ok ? PureToastType.success : PureToastType.error,
    );
  }

  /// Receive: the pairing code, then what the other device's payload
  /// changes, each part ticked, then apply the ticked ones (J05.1).
  Future<void> _receive(SyncPeer peer, {String? code}) async {
    final t = context.t;
    final pairing = code ?? await _askPairingCode(peer, action: t.remoteSync.receiveAction);
    if (pairing == null || !mounted) {
      return;
    }
    final settings = await _service.fetch(peer.ip, peer.port, pairing);
    if (settings == null) {
      _toast(t.remoteSync.receiveFailed);
      return;
    }
    if (!mounted) {
      return;
    }
    final theme = PureTheme.of(context);
    final parts = await showPureDialog<Set<RemoteSyncPart>>(
      context: context,
      child: _previewDialog(
        settings,
        title: t.remoteSync.receive,
        header: [
          Text(
            t.remoteSync.fromName(name: peer.name),
            style: theme.text.body.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 2),
          Text(peer.detail, style: theme.text.bodySmall.copyWith(color: theme.colors.textSecondary)),
          const SizedBox(height: 12),
        ],
        confirmLabel: t.remoteSync.receiveAction,
        confirmKey: const ValueKey('remote-sync-receive-confirm'),
      ),
    );
    if (parts == null || parts.isEmpty || !mounted) {
      return;
    }
    final ok = await _service.apply(settings, parts: parts);
    _toast(
      ok ? t.remoteSync.receiveSuccess : t.remoteSync.receiveFailed,
      type: ok ? PureToastType.success : PureToastType.error,
    );
  }

  /// What [settings] changes, one ticked box per part they hold (the
  /// receive and the incoming send share it); the old flat document has no
  /// parts to pick and goes whole.
  Widget _previewDialog(
    Map<String, dynamic> settings, {
    required String title,
    required String confirmLabel,
    required Key confirmKey,
    String? message,
    List<Widget> header = const [],
    String? cancelLabel,
    Key? cancelKey,
    Key? contentKey,
  }) {
    final t = context.t;
    final splittable = syncPartsSplittable(settings);
    final held = syncPartsIn(settings).toSet();
    final rows = _countRows(settings);
    return _PartsDialogBody(
      key: contentKey,
      title: title,
      message: message,
      header: header,
      rows: rows,
      always: held.difference({for (final row in rows) row.part}),
      // The sender kept its accounts off: this device's sign-ins stay.
      lines: [if (!held.contains(RemoteSyncPart.accounts)) t.remoteSync.previewNoAccounts],
      locked: !splittable,
      note: t.remoteSync.previewWarning,
      previewHeader: t.remoteSync.previewTitle,
      cancelLabel: cancelLabel,
      cancelKey: cancelKey,
      confirmLabel: confirmLabel,
      confirmKey: confirmKey,
    );
  }

  /// The parts [settings] holds, each with its entry count, in
  /// [RemoteSyncPart] order; the settings part speaks in "对方 N 项，其中
  /// M 项与本机不同" (the M comes from comparing against this device's own
  /// answer for the same keys).
  List<SyncPartRow> _countRows(Map<String, dynamic> settings) {
    final t = context.t;
    final counts = syncPartCounts(settings);
    final own = _service.localSettingsSections();
    var changed = 0;
    for (final section in RemoteSyncPayload.preferenceSectionNames) {
      final remote = settings[section];
      if (remote is! Map) {
        continue;
      }
      final mine = own[section];
      for (final entry in remote.entries) {
        final value = mine is Map ? mine[entry.key] : null;
        if (entry.value != value && !_jsonEquals(entry.value, value)) {
          changed++;
        }
      }
    }
    return [
      for (final part in syncPartsIn(settings))
        if (counts[part] case final count?)
          (
            part: part,
            text: switch ((part, count)) {
              (RemoteSyncPart.settings, _) => t.remoteSync.previewSettings(count: count, changed: changed),
              (RemoteSyncPart.accounts, 0) => t.remoteSync.previewAccountsEmpty,
              _ => t.remoteSync.partCount(part: _partLabel(t, part), count: count),
            },
          ),
    ];
  }

  static bool _jsonEquals(Object? a, Object? b) {
    try {
      return jsonEncode(a) == jsonEncode(b);
    } on Object {
      return false;
    }
  }

  String _partLabel(Translations t, RemoteSyncPart part) => switch (part) {
    RemoteSyncPart.settings => t.remoteSync.partSettings,
    RemoteSyncPart.follows => t.remoteSync.partFollows,
    RemoteSyncPart.history => t.remoteSync.partHistory,
    RemoteSyncPart.groups => t.remoteSync.partGroups,
    RemoteSyncPart.keywords => t.remoteSync.partKeywords,
    RemoteSyncPart.users => t.remoteSync.partUsers,
    RemoteSyncPart.webdav => t.remoteSync.partWebdav,
    RemoteSyncPart.accounts => t.remoteSync.partAccounts,
  };

  /// The pairing code of [peer]: six boxes over one field (U.11c c3). The
  /// typed or pasted code is validated before it is returned.
  Future<String?> _askPairingCode(SyncPeer peer, {required String action}) async {
    final t = context.t;
    final code = await showPureDialog<String>(
      context: context,
      child: _PairingCodeBody(name: peer.name, action: action),
    );
    if (code == null) {
      return null;
    }
    final normalized = RemoteSyncProtocol.normalizePairingCode(code);
    if (normalized.length != RemoteSyncProtocol.pairingCodeLength || int.tryParse(normalized) == null) {
      _toast(t.remoteSync.pairingCodeInvalid);
      return null;
    }
    return normalized;
  }

  /// One peer of the list, with its version line.
  SyncPeer _peerOf(RemoteSyncDevice device) => (
    name: device.name,
    ip: device.ip,
    port: device.port,
    detail: [
      device.address,
      // 3.x announces the fixed "1.0.0"; say which app it is instead.
      if (device.version == '1.0.0' || device.version.isEmpty)
        context.t.remoteSync.legacyDevice
      else
        'v${device.version}',
    ].join(' · '),
  );

  /// A typed or pasted target: the device's name when it was heard.
  SyncPeer _peerAt(String ip, int port) {
    for (final device in _service.devices) {
      if (device.ip == ip && device.port == port) {
        return _peerOf(device);
      }
    }
    return (name: '$ip:$port', ip: ip, port: port, detail: '$ip:$port');
  }

  /// The typed target: an address, or the text of a sync QR code (which
  /// carries the pairing code).
  ({String ip, int port, String? code})? _typed() {
    final t = context.t;
    final text = _address.text.trim();
    if (text.isEmpty) {
      _toast(t.remoteSync.enterAddress);
      return null;
    }
    final parsed = RemoteSyncProtocol.parseQr(text);
    if (parsed == null) {
      _toast(text.contains('purelive:') ? t.remoteSync.invalidQr : t.remoteSync.invalidAddress);
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
        bottom: _service.isSyncing
            ? const PreferredSize(
                preferredSize: Size.fromHeight(2),
                child: LinearProgressIndicator(key: ValueKey('remote-sync-progress'), minHeight: 2),
              )
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
                            Expanded(
                              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: others),
                            ),
                          ],
                        )
                      else ...[
                        local,
                        ...others,
                      ],
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

  Widget? _searching(BuildContext context) {
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
            if (service.pairingCode.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(t.remoteSync.pairingCode, style: theme.text.bodySmall.copyWith(color: theme.colors.textSecondary)),
              SelectableText(
                service.pairingCode,
                key: const ValueKey('remote-sync-code'),
                // The reference draws it at 28/20 of the title size with
                // wide spacing: a code read across a room (A04.1).
                style: theme.text.subtitle.copyWith(fontSize: 28, letterSpacing: 6, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 4),
            ],
            Text(
              t.remoteSync.scanHint,
              textAlign: TextAlign.center,
              style: theme.text.bodySmall.copyWith(color: theme.colors.textSecondary),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(t.remoteSync.includeAccounts, style: theme.text.body),
                    Text(
                      t.remoteSync.includeAccountsHint,
                      style: theme.text.bodySmall.copyWith(color: theme.colors.textSecondary),
                    ),
                  ],
                ),
              ),
              PureSwitch(
                key: const ValueKey('remote-sync-accounts'),
                value: service.includeAccounts,
                onChanged: service.includeAccounts ? (value) => service.includeAccounts = value : null,
              ),
            ],
          ),
          const SizedBox(height: 8),
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
              // Wraps instead of running off the card (A04.1: large text).
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
          if (index > 0) PureDivider(indent: 16, endIndent: 16, color: theme.colors.border),
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
          _buttons(busy: busy, onReceive: () => unawaited(_receive(peer)), onSend: () => unawaited(_send(peer))),
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
          Text(t.remoteSync.manualHint, style: theme.text.bodySmall.copyWith(color: theme.colors.textSecondary)),
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
              if (_typed() case final target?) unawaited(_receive(_peerAt(target.ip, target.port), code: target.code));
            },
            onSend: () {
              if (_typed() case final target?) unawaited(_send(_peerAt(target.ip, target.port), code: target.code));
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

/// The parts of a sync, one tick box each, all ticked to start with (the
/// whole sync, as before; J05.1): "全选" above them when there are several;
/// the main button needs one ticked. [locked] keeps every box ticked (a 3.x
/// device takes everything). Closes with the ticked parts — plus the parts
/// without a box of their own when every box is ticked — or nothing.
final class _PartsDialogBody extends StatefulWidget {
  const new({
    required this.title,
    required this.rows,
    required this.confirmLabel,
    required this.confirmKey,
    this.message,
    this.header = const [],
    this.lines = const [],
    this.always = const {},
    this.locked = false,
    this.note,
    this.previewHeader,
    this.cancelLabel,
    this.cancelKey,
    super.key,
  });

  final String title;
  final String? message;
  final List<Widget> header;
  final List<SyncPartRow> rows;
  final List<String> lines;

  /// Parts the data holds without a box of their own: they go with the
  /// result when every box is ticked, so whole sends stay whole.
  final Set<RemoteSyncPart> always;

  final bool locked;
  final String? note;

  /// A small line above the boxes ("接收后会这样变化：").
  final String? previewHeader;

  final String confirmLabel;
  final Key confirmKey;
  final String? cancelLabel;
  final Key? cancelKey;

  @override
  State<_PartsDialogBody> createState() => _PartsDialogBodyState();
}

final class _PartsDialogBodyState extends State<_PartsDialogBody> {
  late final Set<RemoteSyncPart> _chosen = {for (final row in widget.rows) row.part};

  bool get _all => widget.rows.isEmpty || _chosen.length == widget.rows.length;

  bool get _none => _chosen.isEmpty;

  void _done() => Navigator.of(context).pop(<RemoteSyncPart>{..._chosen, if (_all) ...widget.always});

  @override
  Widget build(BuildContext context) {
    final theme = PureTheme.of(context);
    final t = context.t;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(widget.title, style: theme.text.title),
        if (widget.message case final message?) ...[const SizedBox(height: 6), Text(message, style: theme.text.body)],
        const SizedBox(height: 10),
        ...widget.header,
        if (widget.previewHeader case final previewHeader?) ...[
          Text(previewHeader, style: theme.text.body.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
        ],
        if (widget.rows.length > 1 && !widget.locked)
          PureCheckbox(
            key: const ValueKey('remote-sync-part-all'),
            value: _all,
            label: t.remoteSync.partsAll,
            onChanged: (_) => setState(() {
              if (_all) {
                _chosen.clear();
              } else {
                _chosen.addAll([for (final row in widget.rows) row.part]);
              }
            }),
          ),
        for (final row in widget.rows)
          PureCheckbox(
            key: ValueKey('remote-sync-part-${row.part.wireName}'),
            value: widget.locked || _chosen.contains(row.part),
            label: row.text,
            onChanged: widget.locked
                ? null
                : (_) => setState(() {
                    if (!_chosen.remove(row.part)) {
                      _chosen.add(row.part);
                    }
                  }),
          ),
        for (final line in widget.lines)
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 6, 0, 6),
            child: Text(line, style: theme.text.body.copyWith(color: theme.colors.textSecondary)),
          ),
        if (widget.note case final note?) ...[
          const SizedBox(height: 8),
          Text(
            note,
            key: const ValueKey('remote-sync-parts-note'),
            style: theme.text.bodySmall.copyWith(color: theme.colors.textSecondary),
          ),
        ],
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: PureButton(
                key: widget.cancelKey,
                label: widget.cancelLabel ?? t.common.cancel,
                variant: ButtonVariant.ghost,
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: PureButton(key: widget.confirmKey, label: widget.confirmLabel, onPressed: _none ? null : _done),
            ),
          ],
        ),
      ],
    );
  }
}

/// The pairing code of [name]: six boxes over one invisible field (U.11c
/// c3) — the field takes the typing, the paste and the taps, the boxes show
/// it. The main button says what the code is for (U.1d).
final class _PairingCodeBody extends StatefulWidget {
  const new({required this.name, required this.action});

  final String name;

  /// The main button: what the code is for.
  final String action;

  @override
  State<_PairingCodeBody> createState() => _PairingCodeBodyState();
}

final class _PairingCodeBodyState extends State<_PairingCodeBody> {
  final _code = TextEditingController();

  static const int _length = RemoteSyncProtocol.pairingCodeLength;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = PureTheme.of(context);
    final t = context.t;
    return Column(
      key: const ValueKey('remote-sync-pairing'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(t.remoteSync.pairingCode, style: theme.text.title),
        const SizedBox(height: 6),
        Text(t.remoteSync.pairingCodeFor(name: widget.name), style: theme.text.body),
        const SizedBox(height: 12),
        Stack(
          children: [
            // Six boxes up to 44 wide, narrower on a narrow dialog.
            ValueListenableBuilder(
              valueListenable: _code,
              builder: (context, value, _) => Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var i = 0; i < _length; i++)
                    Flexible(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 44),
                          child: Container(
                            height: 52,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: i == value.text.length ? theme.colors.primary : theme.colors.border,
                                width: i == value.text.length ? 2 : 1,
                              ),
                            ),
                            child: Text(
                              i < value.text.length ? value.text[i] : '',
                              style: theme.text.subtitle.copyWith(fontWeight: FontWeight.w600),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            // The field takes the typing and the paste; the boxes show it.
            // A plain TextField needs a Material host under the non-material
            // design languages.
            Positioned.fill(
              child: Material(
                type: MaterialType.transparency,
                child: Opacity(
                  opacity: 0,
                  child: TextField(
                    key: const ValueKey('remote-sync-code-field'),
                    controller: _code,
                    autofocus: true,
                    showCursor: false,
                    keyboardType: TextInputType.number,
                    maxLength: _length,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: const InputDecoration(counterText: '', border: InputBorder.none),
                    onSubmitted: (value) => Navigator.of(context).pop(value),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: PureButton(
                label: t.common.cancel,
                variant: ButtonVariant.ghost,
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: PureButton(
                key: const ValueKey('remote-sync-code-ok'),
                label: widget.action,
                onPressed: () => Navigator.of(context).pop(_code.text),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
