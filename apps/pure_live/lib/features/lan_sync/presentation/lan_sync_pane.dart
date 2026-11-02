import 'package:desen_ui/desen_ui.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_lan_sync/live_lan_sync.dart';
import 'package:pure_live/features/backup/panes/backup_actions.dart' show includeSecretsAllowed;
import 'package:pure_live/features/lan_sync/application/lan_sync_providers.dart';
import 'package:pure_live/features/lan_sync/data/sync_scopes.dart';
import 'package:pure_live/features/lan_sync/presentation/lan_sync_grants.dart';
import 'package:pure_live/features/lan_sync/presentation/pairing_dialog.dart';
import 'package:pure_live/features/settings/surface/settings_widgets.dart' show SettingsConfigRow, SettingsSegmentedRow;
import 'package:pure_live/l10n/translations.dart';

/// The LAN sync pane: the switch, this device's facts, what it shares and
/// how conflicts settle, the nearby and paired devices (each with its
/// grants), the open conflicts and the recent tasks (spec §22.3's UI
/// surface).
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
        _ScopesSection(settings: settings),
        if (settings.enabled) ...[
          _PairedSection(runtime: runtime),
          _NearbySection(runtime: runtime),
          _ConflictsSection(runtime: runtime),
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

/// The paired devices: read once per runtime and re-read after a grant
/// or a revoke — never by restarting the runtime, which would drop the
/// server and the discovery just to refresh a list.
final class _PairedSection extends ConsumerStatefulWidget {
  const _PairedSection({required this.runtime});

  final LanSyncRuntime? runtime;

  @override
  ConsumerState<_PairedSection> createState() => _PairedSectionState();
}

final class _PairedSectionState extends ConsumerState<_PairedSection> {
  Future<List<DeviceTrust>>? _trusts;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  @override
  void didUpdateWidget(_PairedSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.runtime != widget.runtime) _reload();
  }

  void _reload() {
    final future = widget.runtime?.store.loadDeviceTrusts();
    if (future == null) return;
    setState(() {
      _trusts = future;
    });
  }

  /// The address this device last saw [deviceId] on, from discovery.
  String? _lastAddressOf(LanSyncRuntime runtime, String deviceId) => runtime.directory.devices
      .where((device) => device.deviceId == deviceId)
      .expand((device) => device.addresses)
      .firstOrNull;

  int? _lastPortOf(LanSyncRuntime runtime, String deviceId) =>
      runtime.directory.devices.where((device) => device.deviceId == deviceId).map((device) => device.port).firstOrNull;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final current = widget.runtime;
    if (current == null) return const SizedBox.shrink();
    return FutureBuilder<List<DeviceTrust>>(
      future: _trusts,
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
                    t.settings.lanSyncGrantsSummary(
                      read: trust.readScopes.where((id) => active.scopeIds.contains(id)).length,
                      write: trust.writeScopes.where((id) => active.scopeIds.contains(id)).length,
                      total: active.scopes.length,
                    ),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    spacing: DsSpace.s8,
                    children: [
                      DsButton(
                        variant: DsButtonVariant.ghost,
                        size: DsSize.sm,
                        onPressed: () => unawaited(
                          showLanSyncGrantsPanel(context, runtime: active, trust: trust).then((saved) {
                            if (saved && context.mounted) {
                              showDsToast(context: context, title: t.settings.lanSyncGrantsSaved);
                              _reload();
                            }
                          }),
                        ),
                        child: Text(t.settings.lanSyncGrants),
                      ),
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
                          active.trustService.revokeDevice(trust.deviceId).then((_) {
                            if (context.mounted) _reload();
                          }),
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

/// What this device shares, one check per scope, and the conflict policy.
/// The vault's row appears only while the backup page's secrets switch is
/// on; otherwise a hint says where the switch is.
final class _ScopesSection extends ConsumerWidget {
  const _ScopesSection({required this.settings});

  final LanSyncSettings settings;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    final theme = DsTheme.of(context);
    final colors = DsTheme.colorsOf(context);
    final secretsAllowed = includeSecretsAllowed();
    final controller = ref.read(lanSyncSettingsProvider.notifier);
    return DsListSection(
      header: Text(t.settings.lanSyncScopes),
      children: [
        DsListRow(
          leading: const DsIcon(DsIcons.listChecks),
          title: Text(t.settings.lanSyncScopesTitle),
          description: Text(t.settings.lanSyncScopesDesc),
        ),
        for (final scope in LanSyncScope.values)
          if (scope != LanSyncScope.secrets || secretsAllowed)
            SettingsConfigRow(
              leading: DsIcon(lanSyncScopeIcon(scope)),
              title: lanSyncScopeLabel(t, scope),
              description: lanSyncScopeDescription(t, scope),
              control: DsCheckbox(
                value: settings.scopes.contains(scope),
                onChanged: (value) => unawaited(controller.setScope(scope, shared: value ?? false)),
              ),
            )
          else
            DsListRow(
              leading: DsIcon(lanSyncScopeIcon(scope), color: colors.textSubtle),
              title: Text(lanSyncScopeLabel(t, scope), style: theme.typography.body.copyWith(color: colors.textMuted)),
              description: Text(t.settings.lanSyncScopeSecretsOff),
            ),
        SettingsSegmentedRow<ConflictPolicy>(
          leading: const DsIcon(DsIcons.gitMerge),
          title: t.settings.lanSyncConflictPolicy,
          description: t.settings.lanSyncConflictPolicyDesc,
          value: settings.conflictPolicy,
          options: [
            (value: ConflictPolicy.preferRemote, label: t.settings.lanSyncPolicyRemote),
            (value: ConflictPolicy.preferLocal, label: t.settings.lanSyncPolicyLocal),
          ],
          onChanged: (policy) => unawaited(controller.setConflictPolicy(policy)),
        ),
      ],
    );
  }
}

/// The conflicts the engine could not settle by policy: one row each, the
/// user keeps this device's version or takes the peer's.
final class _ConflictsSection extends ConsumerWidget {
  const _ConflictsSection({required this.runtime});

  final LanSyncRuntime? runtime;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = runtime;
    if (current == null) return const SizedBox.shrink();
    final t = context.t;
    final conflicts = ref.watch(lanSyncConflictsProvider).value ?? const <SyncConflict>[];
    if (conflicts.isEmpty) return const SizedBox.shrink();
    Future<void> settle(SyncConflict conflict, {required bool keepLocal}) async {
      try {
        await current.resolveConflict(conflict.key, keepLocal: keepLocal);
        if (context.mounted) showDsToast(context: context, title: t.settings.lanSyncConflictResolved);
      } on LanSyncError catch (error) {
        if (!context.mounted) return;
        showDsToast(
          context: context,
          title: error.code == 'conflict_outdated' ? t.settings.lanSyncConflictOutdated : t.settings.lanSyncSyncFailed,
          status: DsStatus.danger,
        );
      }
      ref.invalidate(lanSyncConflictsProvider);
    }

    return DsListSection(
      header: Text(t.settings.lanSyncConflicts(count: conflicts.length)),
      children: [
        for (final conflict in conflicts)
          DsListRow(
            leading: const DsIcon(DsIcons.triangleAlert),
            title: Text(switch (LanSyncScope.byId(conflict.scope)) {
              final scope? => lanSyncScopeLabel(t, scope),
              null => conflict.scope,
            }),
            description: Text(conflict.entityId),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              spacing: DsSpace.s8,
              children: [
                DsButton(
                  variant: DsButtonVariant.secondary,
                  size: DsSize.sm,
                  onPressed: () => unawaited(settle(conflict, keepLocal: true)),
                  child: Text(t.settings.lanSyncKeepLocal),
                ),
                DsButton(
                  variant: DsButtonVariant.secondary,
                  size: DsSize.sm,
                  onPressed: () => unawaited(settle(conflict, keepLocal: false)),
                  child: Text(t.settings.lanSyncKeepRemote),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

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
