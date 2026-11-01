import 'package:desen_ui/desen_ui.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_lan_sync/live_lan_sync.dart';
import 'package:pure_live/features/lan_sync/application/lan_sync_providers.dart';
import 'package:pure_live/features/lan_sync/data/secure_credential_store.dart';
import 'package:pure_live/features/lan_sync/presentation/pairing_dialog.dart';
import 'package:pure_live/features/settings/surface/settings_widgets.dart' show SettingsConfigRow;
import 'package:pure_live/l10n/translations.dart';

/// The LAN sync pane: the switch, this device's facts, the nearby and
/// paired devices, and the recent tasks (spec §22.3's UI surface).
final class LanSyncPane extends ConsumerWidget {
  /// The pane.
  const LanSyncPane({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    final settings = ref.watch(lanSyncSettingsProvider);
    final runtime = switch (ref.watch(lanSyncRuntimeProvider)) {
      AsyncData(:final value) => value,
      _ => null,
    };
    final identity = switch (ref.watch(tlsIdentityProvider)) {
      AsyncData(:final value) => value,
      _ => null,
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: DsSpace.s16,
      children: [
        DsListSection(
          header: Text(t.settings.lanSync),
          children: [
            SettingsConfigRow(
              leading: const DsIcon(DsIcons.refreshCw),
              title: t.settings.lanSyncEnable,
              description: t.settings.lanSyncEnableDesc,
              control: DsSwitch(
                value: settings.enabled,
                onChanged: (value) => ref.read(lanSyncSettingsProvider.notifier).setEnabled(value: value),
              ),
            ),
            DsListRow(
              leading: const DsIcon(DsIcons.info),
              title: Text(t.settings.lanSyncDeviceName),
              description: Text(t.settings.lanSyncDeviceNameDesc),
              detail: Text(settings.deviceName),
              trailing: DsButton(
                variant: DsButtonVariant.ghost,
                size: DsSize.sm,
                onPressed: () => unawaited(_renameDialog(context, ref, settings.deviceName)),
                child: Text(t.common.rename),
              ),
            ),
            if (identity != null)
              DsListRow(
                leading: const DsIcon(DsIcons.shield),
                title: Text(t.settings.lanSyncFingerprint),
                description: Text(LanSyncLog.shortFingerprint(identity.fingerprint)),
                trailing: DsButton.icon(
                  variant: DsButtonVariant.ghost,
                  size: DsSize.sm,
                  semanticLabel: t.settings.lanSyncFingerprintCopied,
                  onPressed: () {
                    unawaited(Clipboard.setData(ClipboardData(text: identity.fingerprint)));
                    showDsToast(context: context, title: t.settings.lanSyncFingerprintCopied);
                  },
                  icon: const DsIcon(DsIcons.copy, size: 16),
                ),
              ),
          ],
        ),
        if (settings.enabled) ...[
          _PairedSection(runtime: runtime),
          _NearbySection(runtime: runtime),
          _TasksSection(runtime: runtime),
        ],
      ],
    );
  }

  Future<void> _renameDialog(BuildContext context, WidgetRef ref, String current) async {
    final controller = TextEditingController(text: current);
    final saved = await showDsDialog<String>(
      context: context,
      builder: (context) => DsDialog(
        title: Text(context.t.settings.lanSyncDeviceName),
        description: DsTextField(controller: controller, autofocus: true),
        actions: [
          DsButton(
            variant: DsButtonVariant.ghost,
            onPressed: () => Navigator.of(context).pop(),
            child: Text(context.t.common.cancel),
          ),
          DsButton(
            variant: DsButtonVariant.primary,
            onPressed: () => Navigator.of(context).pop(controller.text),
            child: Text(context.t.common.confirm),
          ),
        ],
      ),
    );
    if (saved == null || context.mounted) return;
    await ref.read(lanSyncSettingsProvider.notifier).setDeviceName(saved);
    if (context.mounted) {
      showDsToast(context: context, title: context.t.settings.lanSyncDeviceNameSaved);
    }
  }
}

final class _PairedSection extends ConsumerWidget {
  const _PairedSection({required this.runtime});

  final LanSyncRuntime? runtime;

  /// The address this device last saw [deviceId] on, from discovery.
  String? _lastAddressOf(LanSyncRuntime runtime, String deviceId) => runtime.directory.devices
      .where((device) => device.deviceId == deviceId)
      .expand((device) => device.addresses)
      .firstOrNull;

  int? _lastPortOf(LanSyncRuntime runtime, String deviceId) =>
      runtime.directory.devices.where((device) => device.deviceId == deviceId).map((device) => device.port).firstOrNull;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    final current = runtime;
    if (current == null) return const SizedBox.shrink();
    final store = current.store;
    return FutureBuilder<List<DeviceTrust>>(
      future: store.loadDeviceTrusts(),
      builder: (context, snapshot) {
        final active = current;
        final trusts = (snapshot.data ?? const <DeviceTrust>[]).where((trust) => !trust.revoked).toList();
        return DsListSection(
          header: Text(t.settings.lanSyncPaired),
          children: [
            if (trusts.isEmpty)
              DsListRow(title: Text(t.settings.lanSyncPairedEmpty))
            else
              for (final trust in trusts)
                DsListRow(
                  leading: const DsIcon(DsIcons.monitorSmartphone),
                  title: Text(trust.displayName),
                  description: Text(LanSyncLog.shortFingerprint(trust.keyFingerprint)),
                  detail: Text(
                    [
                      if (trust.allowsRead('favorites')) t.settings.lanSyncReadAllowed,
                      if (trust.allowsWrite('favorites')) t.settings.lanSyncWriteAllowed,
                    ].join(' · '),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    spacing: DsSpace.s8,
                    children: [
                      DsButton(
                        variant: DsButtonVariant.secondary,
                        size: DsSize.sm,
                        onPressed: () {
                          final address = _lastAddressOf(active, trust.deviceId);
                          final port = _lastPortOf(active, trust.deviceId);
                          if (address == null || port == null) return;
                          active.rememberAddress(trust.deviceId, host: address, port: port);
                          unawaited(
                            active.synchronizeWith(trust.deviceId).then((task) {
                              if (task == null || !context.mounted) return;
                              showDsToast(
                                context: context,
                                title: switch (task.status) {
                                  SyncTaskStatus.completed => t.settings.lanSyncSyncDone,
                                  SyncTaskStatus.partiallyCompleted => t.settings.lanSyncSyncPartial,
                                  _ => t.settings.lanSyncSyncFailed,
                                },
                                status: task.status == SyncTaskStatus.completed ? DsStatus.success : DsStatus.danger,
                              );
                            }),
                          );
                        },
                        child: Text(t.settings.lanSyncSyncNow),
                      ),
                      DsButton(
                        variant: DsButtonVariant.dangerSoft,
                        size: DsSize.sm,
                        onPressed: () => unawaited(
                          ref
                              .read(lanSyncRuntimeProvider.future)
                              .then(
                                (runtime) => runtime == null
                                    ? null
                                    : DeviceTrustService(
                                        store: runtime.store,
                                        credentials: const SecureVaultCredentialStore(),
                                      ).revokeDevice(trust.deviceId),
                              ),
                        ),
                        child: Text(t.settings.lanSyncForget),
                      ),
                    ],
                  ),
                ),
          ],
        );
      },
    );
  }
}

final class _NearbySection extends ConsumerWidget {
  const _NearbySection({required this.runtime});

  final LanSyncRuntime? runtime;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    final current = runtime;
    if (current == null) return const SizedBox.shrink();
    final directory = current.directory;
    final localId = current.deviceId;
    return StreamBuilder<SyncDevice>(
      stream: directory.changes,
      builder: (context, snapshot) {
        final devices = directory.devices.where((device) => device.deviceId != localId).toList(growable: false);
        return DsListSection(
          header: Text(t.settings.lanSyncNearby),
          children: [
            if (devices.isEmpty)
              DsListRow(title: Text(t.settings.lanSyncNearbyEmpty))
            else
              for (final device in devices)
                DsListRow(
                  leading: const DsIcon(DsIcons.monitorSmartphone),
                  title: Text(device.deviceName),
                  description: Text(device.addresses.firstOrNull ?? ''),
                  detail: Text(device.platform),
                  trailing: DsButton(
                    variant: DsButtonVariant.primary,
                    size: DsSize.sm,
                    onPressed: device.addresses.isEmpty || device.port == null
                        ? null
                        : () => unawaited(
                            showPairingDialog(
                              context,
                              runtime: current,
                              peer: device,
                              address: device.addresses.first,
                              port: device.port!,
                            ),
                          ),
                    child: Text(t.settings.lanSyncPair),
                  ),
                ),
          ],
        );
      },
    );
  }
}

/// Runs [future] in the background; dialog-level failures surface where
/// they happened.
void unawaited(Future<void> future) {}

final class _TasksSection extends StatelessWidget {
  const _TasksSection({required this.runtime});

  final LanSyncRuntime? runtime;

  @override
  Widget build(BuildContext context) {
    final current = runtime;
    if (current == null) return const SizedBox.shrink();
    return FutureBuilder<List<SyncTask>>(
      future: current.store.tasks(limit: 5),
      builder: (context, snapshot) {
        final tasks = snapshot.data ?? const <SyncTask>[];
        if (tasks.isEmpty) return const SizedBox.shrink();
        final t = context.t;
        return DsListSection(
          header: Text(t.settings.lanSyncSyncNow),
          children: [
            for (final task in tasks)
              DsListRow(
                leading: DsIcon(switch (task.status) {
                  SyncTaskStatus.completed => DsIcons.check,
                  SyncTaskStatus.failed || SyncTaskStatus.partiallyCompleted => DsIcons.triangleAlert,
                  _ => DsIcons.refreshCw,
                }),
                title: Text(task.peerDeviceId),
                description: Text(
                  '${task.completedChanges}/${task.totalChanges}'
                  '${task.error == null ? '' : ' — ${task.error}'}',
                ),
              ),
          ],
        );
      },
    );
  }
}
