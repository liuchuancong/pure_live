import 'dart:async' show Timer, unawaited;
import 'dart:io' show Platform;

import 'package:desen_ui/desen_ui.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_lan_sync/live_lan_sync.dart';
import 'package:pure_live/features/lan_sync/application/lan_sync_providers.dart';
import 'package:pure_live/features/lan_sync/data/secure_credential_store.dart';
import 'package:pure_live/features/lan_sync/data/tls_identity_provider.dart';
import 'package:pure_live/l10n/translations.dart';

/// The pairing flow, both sides in one dialog (spec §9.2's user step):
///
/// **Initiating** (the nearby device's 配对 button): runs the ceremony up
/// to the code, shows it, and waits for the other user's decision.
///
/// **Answering** (the responder's [IncomingPairing]): shows the same code
/// and waits for this device's user.
///
/// Both users compare the six digits; the pairing completes only when both
/// confirmed and the key confirmations verified.
Future<void> showPairingDialog(
  BuildContext context, {
  required LanSyncRuntime runtime,
  required SyncDevice peer,
  required String address,
  required int port,
}) async {
  final t = context.t;
  try {
    final identity = await DeviceTlsIdentity.ensure(
      credentials: const SecureVaultCredentialStore(),
      deviceName: runtime.engine.localDeviceId,
    );
    final initiator = PairingInitiator(
      store: runtime.store,
      credentials: const SecureVaultCredentialStore(),
      deviceConfig: LanSyncDeviceConfig(
        deviceId: runtime.deviceId,
        deviceName: runtime.engine.localDeviceId,
        platform: Platform.operatingSystem,
        appVersion: '4',
      ),
      tlsIdentity: identity,
      pollInterval: const Duration(milliseconds: 300),
    );
    final outgoing = await initiator.begin(host: address, port: port);
    if (!context.mounted) {
      unawaited(outgoing.reject());
      return;
    }
    await showDsDialog<void>(
      context: context,
      builder: (dialogContext) => _PairingDialog(
        outgoing: outgoing,
        incoming: null,
        peerName: outgoing.responder.deviceName,
        code: outgoing.sas,
        expiresAt: outgoing.expiresAt,
        peerAddress: address,
        peerPort: port,
      ),
    );
  } on LanSyncError catch (error) {
    if (!context.mounted) return;
    final message = error.code == 'pairing_window_closed' ? t.settings.lanSyncPairExpired : error.message;
    showDsToast(context: context, title: message, status: DsStatus.danger);
  }
}

/// Opens the answer side: the responder's UI calls this for every
/// [IncomingPairing] the requests stream emits.
Future<void> showIncomingPairingDialog(BuildContext context, IncomingPairing incoming) async {
  await showDsDialog<void>(
    context: context,
    builder: (context) => _PairingDialog(
      outgoing: null,
      incoming: incoming,
      peerName: incoming.initiator.deviceName,
      code: incoming.sas,
      expiresAt: incoming.expiresAt,
    ),
  );
}

final class _PairingDialog extends ConsumerStatefulWidget {
  const _PairingDialog({
    required this.outgoing,
    required this.incoming,
    required this.peerName,
    required this.code,
    required this.expiresAt,
    this.peerAddress,
    this.peerPort,
  });

  final OutgoingPairing? outgoing;
  final IncomingPairing? incoming;
  final String peerName;
  final String code;
  final DateTime expiresAt;

  /// Where the peer answers; remembered with the trust on completion so
  /// sync-now works right after pairing.
  final String? peerAddress;
  final int? peerPort;

  @override
  ConsumerState<_PairingDialog> createState() => _PairingDialogState();
}

final class _PairingDialogState extends ConsumerState<_PairingDialog> {
  _Phase _phase = _Phase.comparing;
  String? _error;
  Timer? _ticker;
  int _secondsLeft = 0;

  @override
  void initState() {
    super.initState();
    _tick();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  void _tick() {
    final left = widget.expiresAt.difference(DateTime.now()).inSeconds;
    if (left <= 0 && _phase == _Phase.comparing) {
      setState(() {
        _phase = _Phase.failed;
        _error = context.t.settings.lanSyncPairExpired;
      });
      _ticker?.cancel();
      return;
    }
    setState(() => _secondsLeft = left);
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  Future<void> _confirm() async {
    setState(() => _phase = _Phase.waiting);
    try {
      final outcome = widget.outgoing != null ? await widget.outgoing!.confirm() : await _acceptIncoming();
      if (!mounted) return;
      switch (outcome) {
        case PairingCompleted():
          final runtime = await ref.read(lanSyncRuntimeProvider.future);
          if (!mounted) return;
          if (widget.peerAddress != null && widget.peerPort != null) {
            runtime?.rememberAddress(
              widget.outgoing!.responder.deviceId,
              host: widget.peerAddress!,
              port: widget.peerPort!,
            );
          }
          setState(() => _phase = _Phase.done);
          showDsToast(context: context, title: context.t.settings.lanSyncPairAccepted);
          Navigator.of(context).pop();
        case PairingFailed(:final reason, :final message):
          setState(() {
            _phase = _Phase.failed;
            _error = switch (reason) {
              PairingFailureReason.keyConfirmationFailed => context.t.settings.lanSyncPairMismatch,
              PairingFailureReason.sessionExpired => context.t.settings.lanSyncPairExpired,
              PairingFailureReason.rejectedByPeer => context.t.settings.lanSyncPairRejected,
              _ => message,
            };
          });
      }
    } on LanSyncError catch (error) {
      if (!mounted) return;
      setState(() {
        _phase = _Phase.failed;
        _error = error.message;
      });
    }
  }

  Future<PairingOutcome> _acceptIncoming() async {
    final incoming = widget.incoming!;
    final runtime = await ref.read(lanSyncRuntimeProvider.future);
    if (runtime == null) {
      return const PairingFailed(PairingFailureReason.unknownSession, 'Sync is off.');
    }
    return await runtime.responder.accept(
      incoming.sessionId,
      // A fresh pairing gets every scope this device shares, both ways; the
      // paired list's grants panel narrows it afterwards.
      grants: PairingGrants(readScopes: runtime.scopeIds, writeScopes: runtime.scopeIds),
    );
  }

  Future<void> _reject() async {
    final incoming = widget.incoming;
    final outgoing = widget.outgoing;
    if (incoming != null) {
      unawaited(
        ref.read(lanSyncRuntimeProvider.future).then((runtime) => runtime?.responder.reject(incoming.sessionId)),
      );
    } else if (outgoing != null) {
      unawaited(outgoing.reject());
    }
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    return DsDialog(
      title: Text(t.settings.lanSyncPairTitle),
      description: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: DsSpace.s12,
        children: [
          Text(switch (_phase) {
            _ => t.settings.lanSyncPairFrom(name: widget.peerName),
          }),
          Text(t.settings.lanSyncPairIntro),
          if (_phase == _Phase.comparing || _phase == _Phase.waiting) ...[
            Text(
              widget.code,
              textAlign: TextAlign.center,
              style: DsTheme.of(context).typography.title
                  .copyWith(fontSize: 40, letterSpacing: 8, fontWeight: FontWeight.w700),
            ),
            Text(
              t.settings.lanSyncPairCountdown(seconds: _secondsLeft),
              textAlign: TextAlign.center,
              style: DsTheme.of(context).typography.small.copyWith(color: DsTheme.colorsOf(context).textMuted),
            ),
            if (_phase == _Phase.waiting) Text(t.settings.lanSyncStateWaiting, textAlign: TextAlign.center),
          ],
          if (_phase == _Phase.failed && _error != null)
            Text(_error!, style: TextStyle(color: DsTheme.colorsOf(context).danger.text)),
        ],
      ),
      actions: switch (_phase) {
        _Phase.comparing => [
          DsButton(variant: DsButtonVariant.ghost, onPressed: _reject, child: Text(t.settings.lanSyncPairReject)),
          DsButton(variant: DsButtonVariant.primary, onPressed: _confirm, child: Text(t.settings.lanSyncPairConfirm)),
        ],
        _Phase.waiting => [const Center(child: DsProgressRing())],
        _ => [
          DsButton(
            variant: DsButtonVariant.primary,
            onPressed: () => Navigator.of(context).pop(),
            child: Text(t.common.confirm),
          ),
        ],
      },
    );
  }
}

enum _Phase { comparing, waiting, done, failed }
