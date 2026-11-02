import 'dart:async' show unawaited;

import 'package:cloud_firestore/cloud_firestore.dart' show DocumentSnapshot;
import 'package:desen_ui/desen_ui.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pure_live/features/backup/cloud/cloud_backup_pane.dart' show cloudFailureMessage;
import 'package:pure_live/features/backup/cloud/cloud_controller.dart';
import 'package:pure_live/features/backup/cloud/cloud_models.dart';
import 'package:pure_live/features/backup/cloud/cloud_service.dart';
import 'package:pure_live/l10n/translations.dart';

/// The accounts page for managers and admins: every account by email
/// (prefix search), its role and upload switch, and the actions the
/// reference app offered — allow or refuse uploads, make or unmake a
/// manager, delete. Pages of thirty, "more" at the bottom.
///
/// An account without management power sees why it cannot act, and a
/// signed-out one is sent to the cloud page.
final class CloudAdminPane extends ConsumerStatefulWidget {
  /// The pane.
  const CloudAdminPane({super.key});

  @override
  ConsumerState<CloudAdminPane> createState() => _CloudAdminPaneState();
}

final class _CloudAdminPaneState extends ConsumerState<CloudAdminPane> {
  final CloudService _service = const CloudService();
  final TextEditingController _search = TextEditingController();
  final List<CloudUserItem> _items = [];
  DocumentSnapshot<Map<String, Object?>>? _last;
  bool _loading = false;
  bool _exhausted = false;
  String? _busyUid;

  @override
  void initState() {
    super.initState();
    // After the first frame: a provider write inside initState is a
    // modification during build.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(ref.read(cloudControllerProvider.notifier).ensureStarted());
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => unawaited(_reload()));
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _toast(String message, {DsStatus status = DsStatus.neutral}) =>
      showDsToast(context: context, title: message, status: status);

  Future<void> _reload() async {
    _items.clear();
    _last = null;
    _exhausted = false;
    await _loadMore();
  }

  Future<void> _loadMore() async {
    final state = ref.read(cloudControllerProvider);
    final user = state.user;
    if (user == null || !state.permissions.hasManagementPower || _loading || _exhausted) return;
    setState(() => _loading = true);
    try {
      final page = await _service.listUsers(
        selfUid: user.uid,
        visibleRoles: state.permissions.visibleRoles,
        keyword: _search.text,
        after: _last,
      );
      if (!mounted) return;
      setState(() {
        _items.addAll(page.items);
        _last = page.last;
        _exhausted = page.last == null || page.items.isEmpty;
      });
    } on CloudFailure catch (failure) {
      if (mounted) _toast(cloudFailureMessage(context.t, failure.code), status: DsStatus.danger);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _act(CloudUserItem item, Future<void> Function() work, {String? done}) async {
    setState(() => _busyUid = item.uid);
    try {
      await work();
      if (mounted && done != null) _toast(done, status: DsStatus.success);
      await _reload();
    } on CloudFailure catch (failure) {
      if (mounted) _toast(cloudFailureMessage(context.t, failure.code), status: DsStatus.danger);
    } finally {
      if (mounted) setState(() => _busyUid = null);
    }
  }

  Future<void> _delete(CloudUserItem item) async {
    final t = context.t.backup.cloud;
    final confirmed = await showDsConfirm(
      context: context,
      title: t.adminDeleteTitle(email: item.email),
      description: t.adminDeleteDesc,
      confirmLabel: context.t.common.confirm,
      cancelLabel: context.t.common.cancel,
      destructive: true,
    );
    if (!confirmed || !mounted) return;
    await _act(item, () => _service.deleteUser(item.uid), done: t.adminDeleted);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final c = t.backup.cloud;
    final state = ref.watch(cloudControllerProvider);
    final colors = DsTheme.colorsOf(context);
    if (state.phase != CloudPhase.signedIn) {
      return DsListSection(
        header: Text(c.adminTitle),
        children: [DsListRow(leading: const DsIcon(DsIcons.cloudOff), title: Text(c.adminSignedOut))],
      );
    }
    if (!state.permissions.hasManagementPower) {
      return DsListSection(
        header: Text(c.adminTitle),
        children: [
          DsListRow(
            leading: const DsIcon(DsIcons.lock),
            title: Text(c.adminNoPower),
            description: Text(c.adminNoPowerDesc),
          ),
        ],
      );
    }
    final isAdmin = state.permissions.isAdmin;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: DsSpace.s16,
      children: [
        DsListSection(
          header: Text(c.adminTitle),
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: DsSpace.s16, vertical: DsSpace.s12),
              child: DsTextField(
                controller: _search,
                placeholder: c.adminSearchHint,
                clearable: true,
                leading: const DsIcon(DsIcons.search, size: 16),
                onSubmitted: (_) => unawaited(_reload()),
              ),
            ),
          ],
        ),
        DsListSection(
          header: Text(_items.isEmpty ? c.adminUsers : c.adminUsersCount(count: _items.length)),
          children: [
            if (_items.isEmpty && !_loading) DsListRow(title: Text(c.adminEmpty)),
            for (final item in _items)
              DsListRow(
                key: ValueKey(item.uid),
                leading: DsIcon(switch (item.role) {
                  'admin' => DsIcons.shieldCheck,
                  'manager' => DsIcons.userCog,
                  _ => DsIcons.user,
                }),
                title: Text(item.email.isEmpty ? item.uid : item.email),
                description: Text(
                  '${c.roleLabel(role: item.role)} · ${item.canUpload ? c.uploadAllowed : c.uploadRefused}',
                ),
                trailing: _busyUid == item.uid
                    ? const DsSpinner()
                    : DsMenuAnchor(
                        semanticLabel: t.common.more,
                        align: DsAlign.end,
                        items: [
                          DsMenuItem(
                            label: Text(item.canUpload ? c.adminRefuseUpload : c.adminAllowUpload),
                            leading: DsIcon(item.canUpload ? DsIcons.cloudOff : DsIcons.cloudUpload),
                            onPressed: () => unawaited(
                              _act(item, () => _service.setUploadAllowed(item.uid, allowed: !item.canUpload)),
                            ),
                          ),
                          if (isAdmin && item.role != 'admin')
                            DsMenuItem(
                              label: Text(item.role == 'manager' ? c.adminDemote : c.adminPromote),
                              leading: const DsIcon(DsIcons.userCog),
                              onPressed: () => unawaited(
                                _act(
                                  item,
                                  () => item.role == 'manager'
                                      ? _service.demote(item.uid)
                                      : _service.promote(item.uid, email: item.email),
                                ),
                              ),
                            ),
                          if (isAdmin && item.role != 'admin') ...[
                            const DsMenuDivider(),
                            DsMenuItem(
                              label: Text(c.adminDelete),
                              leading: DsIcon(DsIcons.trash2, color: colors.danger.text),
                              onPressed: () => unawaited(_delete(item)),
                            ),
                          ],
                        ],
                        builder: (context, controller, _) => DsButton.icon(
                          variant: DsButtonVariant.ghost,
                          size: DsSize.sm,
                          semanticLabel: t.common.more,
                          onPressed: controller.toggle,
                          icon: const DsIcon(DsIcons.ellipsisVertical, size: 18),
                        ),
                      ),
              ),
            if (_loading)
              DsListRow(leading: const DsSpinner(), title: Text(c.adminLoading))
            else if (!_exhausted && _items.isNotEmpty)
              DsListRow(
                leading: const DsIcon(DsIcons.chevronDown),
                title: Text(c.adminMore),
                onPressed: () => unawaited(_loadMore()),
              ),
          ],
        ),
      ],
    );
  }
}
