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
import 'package:pure_live/shared/widgets/app_dialog.dart';

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
          header: Text(t.settings.lanSyncThisDevice),
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
        if (settings.enabled) _DevicesSection(runtime: runtime),
        _ScopesSection(settings: settings),
        if (settings.enabled) ...[_ConflictsSection(runtime: runtime), _TasksSection(runtime: runtime)],
      ],
    );
  }

  Future<void> _renameDialog(BuildContext context, WidgetRef ref, String current) async {
    final controller = TextEditingController(text: current);
    final saved = await showAppDialog<String>(
      context: context,
      builder: (context) => AppDialog(
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
    if (saved == null || !context.mounted) return;
    await ref.read(lanSyncSettingsProvider.notifier).setDeviceName(saved);
    if (context.mounted) {
      showDsToast(context: context, title: context.t.settings.lanSyncDeviceNameSaved);
    }
  }
}

/// The paired and nearby devices in one list: the paired first, with the
/// grants summary and a sync action, the rest offering pairing. Trusts are
/// read once per runtime and re-read after a grant, a revoke or a pairing —
/// never by restarting the runtime, which would drop the server and the
/// discovery just to refresh a list.
final class _DevicesSection extends ConsumerStatefulWidget {
  const _DevicesSection({required this.runtime});

  final LanSyncRuntime? runtime;

  @override
  ConsumerState<_DevicesSection> createState() => _DevicesSectionState();
}

final class _DevicesSectionState extends ConsumerState<_DevicesSection> {
  Future<List<DeviceTrust>>? _trusts;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  @override
  void didUpdateWidget(_DevicesSection oldWidget) {
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

  Future<void> _grant(LanSyncRuntime runtime, DeviceTrust trust) async {
    final saved = await showLanSyncGrantsPanel(context, runtime: runtime, trust: trust);
    if (!saved || !mounted) return;
    _reload();
    showDsToast(context: context, title: context.t.settings.lanSyncGrantsSaved);
  }

  Future<void> _sync(LanSyncRuntime runtime, DeviceTrust trust) async {
    final address = _lastAddressOf(runtime, trust.deviceId);
    final port = _lastPortOf(runtime, trust.deviceId);
    if (address == null || port == null) {
      if (mounted) {
        showDsToast(context: context, title: context.t.settings.lanSyncSyncFailed, status: DsStatus.danger);
      }
      return;
    }
    runtime.rememberAddress(trust.deviceId, host: address, port: port);
    final task = await runtime.synchronizeWith(trust.deviceId);
    if (!mounted || task == null) return;
    final t = context.t;
    showDsToast(
      context: context,
      title: switch (task.status) {
        SyncTaskStatus.completed => t.settings.lanSyncSyncDone,
        SyncTaskStatus.partiallyCompleted => t.settings.lanSyncSyncPartial,
        _ => t.settings.lanSyncSyncFailed,
      },
      status: task.status == SyncTaskStatus.completed ? DsStatus.success : DsStatus.danger,
    );
  }

  Future<void> _forget(LanSyncRuntime runtime, DeviceTrust trust) async {
    await runtime.trustService.revokeDevice(trust.deviceId);
    if (!mounted) return;
    _reload();
    showDsToast(context: context, title: context.t.settings.lanSyncRevoked);
  }

  Future<void> _pair(LanSyncRuntime runtime, SyncDevice device) async {
    await showPairingDialog(
      context,
      runtime: runtime,
      peer: device,
      address: device.addresses.first,
      port: device.port!,
    );
    if (mounted) _reload();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final theme = DsTheme.of(context);
    final colors = DsTheme.colorsOf(context);
    final current = widget.runtime;
    if (current == null) return const SizedBox.shrink();
    return FutureBuilder<List<DeviceTrust>>(
      future: _trusts,
      builder: (context, snapshot) {
        final trusts = (snapshot.data ?? const <DeviceTrust>[]).where((trust) => !trust.revoked).toList();
        return StreamBuilder<SyncDevice>(
          stream: current.directory.changes,
          builder: (context, _) {
            final pairedIds = {for (final trust in trusts) trust.deviceId};
            final nearby = current.directory.devices
                .where((device) => device.deviceId != current.deviceId && !pairedIds.contains(device.deviceId))
                .toList(growable: false);
            return DsListSection(
              header: Row(
                children: [
                  Text(t.settings.lanSyncDevices),
                  const Spacer(),
                  if (trusts.isNotEmpty)
                    Text(
                      t.settings.lanSyncPairedCount(count: trusts.length),
                      style: theme.typography.caption.copyWith(color: colors.textSubtle),
                    ),
                ],
              ),
              children: [
                if (trusts.isEmpty && nearby.isEmpty) DsListRow(title: Text(t.settings.lanSyncNearbyEmpty)),
                for (final trust in trusts)
                  DsListRow(
                    leading: const DsIcon(DsIcons.monitorSmartphone),
                    title: Text(trust.displayName),
                    description: Text(LanSyncLog.shortFingerprint(trust.keyFingerprint)),
                    detail: Text(
                      t.settings.lanSyncGrantsSummary(
                        read: trust.readScopes.where((id) => current.scopeIds.contains(id)).length,
                        write: trust.writeScopes.where((id) => current.scopeIds.contains(id)).length,
                        total: current.scopes.length,
                      ),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      spacing: DsSpace.s8,
                      children: [
                        DsButton(
                          variant: DsButtonVariant.primary,
                          size: DsSize.sm,
                          onPressed: () => unawaited(_sync(current, trust)),
                          child: Text(t.settings.lanSyncSyncNow),
                        ),
                        DsMenuAnchor(
                          semanticLabel: t.common.more,
                          align: DsAlign.end,
                          items: [
                            DsMenuItem(
                              label: Text(t.settings.lanSyncGrants),
                              leading: const DsIcon(DsIcons.shield),
                              onPressed: () => unawaited(_grant(current, trust)),
                            ),
                            DsMenuItem(
                              label: Text(t.settings.lanSyncForget),
                              leading: DsIcon(DsIcons.trash2, color: colors.danger.text),
                              destructive: true,
                              onPressed: () => unawaited(_forget(current, trust)),
                            ),
                          ],
                          builder: (context, controller, _) => DsButton.icon(
                            variant: DsButtonVariant.ghost,
                            size: DsSize.sm,
                            semanticLabel: t.common.more,
                            onPressed: controller.toggle,
                            icon: const DsIcon(DsIcons.ellipsisVertical, size: 18),
                          ),
                        ),
                      ],
                    ),
                  ),
                for (final device in nearby)
                  DsListRow(
                    leading: const DsIcon(DsIcons.wifi),
                    title: Text(device.deviceName),
                    description: Text(device.addresses.firstOrNull ?? ''),
                    detail: Text(device.platform),
                    trailing: DsButton(
                      variant: DsButtonVariant.secondary,
                      size: DsSize.sm,
                      onPressed: device.addresses.isEmpty || device.port == null
                          ? null
                          : () => unawaited(_pair(current, device)),
                      child: Text(t.settings.lanSyncPair),
                    ),
                  ),
              ],
            );
          },
        );
      },
    );
  }
}

/// Runs [future] in the background; dialog-level failures surface where
/// they happened.
void unawaited(Future<void> future) {}

/// What this device shares, one check per scope. The vault's row appears
/// only while the backup page's secrets switch is on; otherwise a hint says
/// where the switch is.
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
    final offered = [
      for (final scope in LanSyncScope.values)
        if (scope != LanSyncScope.secrets || secretsAllowed) scope,
    ];
    final shared = offered.where(settings.scopes.contains).length;
    return DsListSection(
      header: Row(
        children: [
          Text(t.settings.lanSyncScopes),
          const Spacer(),
          Text(
            t.settings.lanSyncSharedCount(selected: shared, total: offered.length),
            style: theme.typography.caption.copyWith(color: colors.textSubtle),
          ),
        ],
      ),
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
    final settings = ref.watch(lanSyncSettingsProvider);
    final conflicts = ref.watch(lanSyncConflictsProvider).value ?? const <SyncConflict>[];
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
      header: Text(
        conflicts.isEmpty ? t.settings.lanSyncConflictSection : t.settings.lanSyncConflicts(count: conflicts.length),
      ),
      children: [
        SettingsSegmentedRow<ConflictPolicy>(
          leading: const DsIcon(DsIcons.gitMerge),
          title: t.settings.lanSyncConflictPolicy,
          description: t.settings.lanSyncConflictPolicyDesc,
          value: settings.conflictPolicy,
          options: [
            (value: ConflictPolicy.preferRemote, label: t.settings.lanSyncPolicyRemote),
            (value: ConflictPolicy.preferLocal, label: t.settings.lanSyncPolicyLocal),
          ],
          onChanged: (policy) => unawaited(ref.read(lanSyncSettingsProvider.notifier).setConflictPolicy(policy)),
        ),
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
          header: Text(t.settings.lanSyncHistory),
          children: [
            for (final task in tasks)
              DsListRow(
                leading: DsIcon(switch (task.status) {
                  SyncTaskStatus.completed => DsIcons.check,
                  SyncTaskStatus.failed || SyncTaskStatus.partiallyCompleted => DsIcons.triangleAlert,
                  _ => DsIcons.refreshCw,
                }),
                title: FutureBuilder<DeviceTrust?>(
                  future: current.store.deviceTrust(task.peerDeviceId),
                  builder: (context, peer) => Text(peer.data?.displayName ?? task.peerDeviceId),
                ),
                description: Text(
                  '${task.completedChanges}/${task.totalChanges}'
                  '${task.error == null ? '' : ' — ${task.error}'}',
                ),
                trailing: DsBadge(
                  status: switch (task.status) {
                    SyncTaskStatus.completed => DsStatus.success,
                    SyncTaskStatus.failed => DsStatus.danger,
                    _ => DsStatus.neutral,
                  },
                  label: Text(switch (task.status) {
                    SyncTaskStatus.completed => t.settings.lanSyncSyncDone,
                    SyncTaskStatus.partiallyCompleted => t.settings.lanSyncSyncPartial,
                    SyncTaskStatus.failed => t.settings.lanSyncSyncFailed,
                    SyncTaskStatus.cancelled => t.settings.lanSyncTaskCancelled,
                    SyncTaskStatus.paused => t.settings.lanSyncTaskPaused,
                    _ => t.settings.lanSyncSyncing,
                  }),
                ),
              ),
          ],
        );
      },
    );
  }
}
