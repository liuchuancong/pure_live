import 'dart:async' show unawaited;
import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart' show DocumentSnapshot;
import 'package:desen_ui/desen_ui.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pure_live/features/backup/cloud/cloud_backup_pane.dart' show cloudFailureMessage;
import 'package:pure_live/features/backup/cloud/cloud_controller.dart';
import 'package:pure_live/features/backup/cloud/cloud_models.dart';
import 'package:pure_live/features/backup/cloud/cloud_service.dart';
import 'package:pure_live/l10n/translations.dart';

/// The accounts page for managers and admins: the figures up top (every
/// account, by role, how many may upload), a search by email prefix, the
/// accounts as a table — email, role, upload, actions — and real pages
/// underneath. The table folds into cards on a narrow window.
///
/// Paging is by cursor, as Firestore pages: the page count comes from the
/// count aggregation (no documents read), each page's start is the last
/// document of the one before, and jumping ahead walks the pages between.
/// An account without management power sees why it cannot act; a
/// signed-out one is sent to the cloud page.
final class CloudAdminPane extends ConsumerStatefulWidget {
  /// The pane.
  const CloudAdminPane({super.key});

  @override
  ConsumerState<CloudAdminPane> createState() => _CloudAdminPaneState();
}

final class _CloudAdminPaneState extends ConsumerState<CloudAdminPane> {
  static const int _pageSize = 20;

  final CloudService _service = const CloudService();
  final TextEditingController _search = TextEditingController();

  CloudUserStats? _stats;
  List<CloudUserItem> _rows = const [];
  int _page = 1;
  int _pageCount = 1;
  String _keyword = '';

  /// The document each loaded page ended on; `_cursors[n]` starts page
  /// n + 2. Page 1 starts from nothing.
  final List<DocumentSnapshot<Map<String, Object?>>?> _cursors = [];
  bool _loading = false;
  String? _busyUid;
  int _epoch = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(ref.read(cloudControllerProvider.notifier).ensureStarted());
      unawaited(_reload());
    });
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _toast(String message, {DsStatus status = DsStatus.neutral}) =>
      showDsToast(context: context, title: message, status: status);

  CloudState get _cloud => ref.read(cloudControllerProvider);

  bool get _mayManage => _cloud.phase == CloudPhase.signedIn && _cloud.permissions.hasManagementPower;

  /// Starts over: the figures, the page count for the keyword, page 1.
  Future<void> _reload() async {
    if (!_mayManage) return;
    final epoch = ++_epoch;
    _keyword = _search.text.trim();
    _cursors.clear();
    setState(() {
      _loading = true;
      _page = 1;
    });
    try {
      final results = await Future.wait([_service.loadStats(), _service.countUsers(keyword: _keyword)]);
      if (!mounted || epoch != _epoch) return;
      final stats = results[0] as CloudUserStats;
      // The signed-in account is left out of the rows, so the total the
      // pages are cut from leaves it out too.
      final count = math.max(0, (results[1] as int) - 1);
      setState(() {
        _stats = stats;
        _pageCount = math.max(1, (count / _pageSize).ceil());
      });
      await _goTo(1, epoch);
    } on CloudFailure catch (failure) {
      if (mounted) _toast(cloudFailureMessage(context.t, failure.code), status: DsStatus.danger);
      if (mounted) setState(() => _loading = false);
    }
  }

  /// Loads page [target]: forward from the last cursor known, one page at
  /// a time until it is reached; back to a known page straight away.
  Future<void> _goTo(int target, int epoch) async {
    final user = _cloud.user;
    if (user == null) return;
    setState(() => _loading = true);
    try {
      // The cursor page `target` starts from is the one before it; load
      // forward until that cursor is known.
      while (_cursors.length < target - 1) {
        final page = await _service.listUsers(
          selfUid: user.uid,
          visibleRoles: _cloud.permissions.visibleRoles,
          keyword: _keyword,
          pageSize: _pageSize,
          after: _cursors.isEmpty ? null : _cursors.last,
        );
        if (!mounted || epoch != _epoch) return;
        if (page.last == null) break;
        _cursors.add(page.last);
      }
      final page = await _service.listUsers(
        selfUid: user.uid,
        visibleRoles: _cloud.permissions.visibleRoles,
        keyword: _keyword,
        pageSize: _pageSize,
        after: target <= 1 ? null : (_cursors.length >= target - 1 ? _cursors[target - 2] : null),
      );
      if (!mounted || epoch != _epoch) return;
      if (_cursors.length < target && page.last != null) _cursors.add(page.last);
      setState(() {
        _rows = page.items;
        _page = target;
      });
    } on CloudFailure catch (failure) {
      if (mounted) _toast(cloudFailureMessage(context.t, failure.code), status: DsStatus.danger);
    } finally {
      if (mounted && epoch == _epoch) setState(() => _loading = false);
    }
  }

  Future<void> _act(CloudUserItem item, Future<void> Function() work, {String? done}) async {
    setState(() => _busyUid = item.uid);
    try {
      await work();
      if (mounted && done != null) _toast(done, status: DsStatus.success);
      if (mounted) await _reload();
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

  /// The row's actions: the upload switch for anyone with power, the role
  /// and the deletion for an admin, never against another admin.
  List<Widget> _menu(BuildContext context, CloudUserItem item) {
    final c = context.t.backup.cloud;
    final isAdmin = _cloud.permissions.isAdmin;
    final colors = DsTheme.colorsOf(context);
    return [
      DsMenuItem(
        label: Text(item.canUpload ? c.adminRefuseUpload : c.adminAllowUpload),
        leading: DsIcon(item.canUpload ? DsIcons.cloudOff : DsIcons.cloudUpload),
        onPressed: () => unawaited(_act(item, () => _service.setUploadAllowed(item.uid, allowed: !item.canUpload))),
      ),
      if (isAdmin && item.role != 'admin') ...[
        DsMenuItem(
          label: Text(item.role == 'manager' ? c.adminDemote : c.adminPromote),
          leading: const DsIcon(DsIcons.userCog),
          onPressed: () => unawaited(
            _act(
              item,
              () => item.role == 'manager' ? _service.demote(item.uid) : _service.promote(item.uid, email: item.email),
            ),
          ),
        ),
        const DsMenuDivider(),
        DsMenuItem(
          label: Text(c.adminDelete),
          leading: DsIcon(DsIcons.trash2, color: colors.danger.text),
          onPressed: () => unawaited(_delete(item)),
        ),
      ],
    ];
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final c = t.backup.cloud;
    final state = ref.watch(cloudControllerProvider);
    // Signing in or gaining power after the page opened loads the list.
    ref.listen(cloudControllerProvider.select((s) => (s.phase, s.permissions.hasManagementPower)), (previous, next) {
      if (next.$1 == CloudPhase.signedIn && next.$2 && _stats == null) unawaited(_reload());
    });
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
    // The page owns its height (the settings surface does not scroll it):
    // the figures and the search stay put, the table takes what is left
    // and scrolls by itself, and the pages stay in view underneath.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: DsSpace.s12,
      children: [
        _StatsSection(stats: _stats),
        DsTextField(
          controller: _search,
          placeholder: c.adminSearchHint,
          clearable: true,
          leading: const DsIcon(DsIcons.search, size: 16),
          onSubmitted: (_) => unawaited(_reload()),
        ),
        Expanded(child: _table(context)),
        if (_pageCount > 1)
          Center(
            child: DsPagination(
              page: _page,
              pageCount: _pageCount,
              semanticLabel: c.adminPageLabel,
              onChanged: (next) {
                if (next == _page || _loading) return;
                unawaited(_goTo(next, _epoch));
              },
            ),
          ),
      ],
    );
  }

  Widget _table(BuildContext context) {
    final t = context.t;
    final c = t.backup.cloud;
    final theme = DsTheme.of(context);
    final colors = DsTheme.colorsOf(context);
    return DsTable<CloudUserItem>(
      semanticLabel: c.adminTitle,
      rows: _rows,
      rowKey: (item) => item.uid,
      rowsVersion: Object.hash(_page, _keyword, _rows.length),
      layout: const DsTableLayout.auto(breakpoint: 560),
      loading: _loading,
      emptyView: Padding(
        padding: const EdgeInsets.all(DsSpace.s24),
        child: Text(c.adminEmpty, style: theme.typography.body.copyWith(color: colors.textMuted)),
      ),
      columns: [
        DsTableColumn(
          id: 'email',
          label: c.colEmail,
          value: (item) => item.email,
          width: const DsTableColumnWidth.flex(3, 200),
          cell: (context, item) =>
              Text(item.email.isEmpty ? item.uid : item.email, maxLines: 1, overflow: TextOverflow.ellipsis),
        ),
        DsTableColumn(
          id: 'role',
          label: c.colRole,
          value: (item) => item.role,
          width: const DsTableColumnWidth.fixed(120),
          cell: (context, item) => DsBadge(
            status: switch (item.role) {
              'admin' => DsStatus.danger,
              'manager' => DsStatus.warning,
              _ => DsStatus.neutral,
            },
            label: Text(_roleName(c, item.role)),
          ),
        ),
        DsTableColumn(
          id: 'upload',
          label: c.colUpload,
          value: (item) => item.canUpload ? '1' : '0',
          width: const DsTableColumnWidth.fixed(110),
          cell: (context, item) => DsBadge(
            status: item.canUpload ? DsStatus.success : DsStatus.neutral,
            label: Text(item.canUpload ? c.uploadAllowed : c.uploadRefused),
          ),
        ),
        DsTableColumn(
          id: 'actions',
          label: c.colActions,
          width: const DsTableColumnWidth.fixed(64),
          alignment: DsTableCellAlignment.center,
          cell: (context, item) => _busyUid == item.uid
              ? const DsSpinner(style: DsSpinnerStyle(size: 16))
              : DsMenuAnchor(
                  semanticLabel: t.common.more,
                  align: DsAlign.end,
                  items: _menu(context, item),
                  builder: (context, controller, _) => DsButton.icon(
                    variant: DsButtonVariant.ghost,
                    size: DsSize.sm,
                    semanticLabel: t.common.more,
                    onPressed: controller.toggle,
                    icon: const DsIcon(DsIcons.ellipsisVertical, size: 18),
                  ),
                ),
        ),
      ],
      rowMenuBuilder: _menu,
    );
  }
}

/// The role's name in the user's language; an unknown role shows as-is.
String _roleName(Translations$backup$cloud$zh_CN c, String role) => switch (role) {
  'admin' => c.roleAdmin,
  'manager' => c.roleManager,
  'user' => c.roleUser,
  _ => role,
};

/// The five figures as tiles that wrap to the width: a number over its
/// name, the kit's surface and border, nothing else.
final class _StatsSection extends StatelessWidget {
  const _StatsSection({required this.stats});

  final CloudUserStats? stats;

  @override
  Widget build(BuildContext context) {
    final c = context.t.backup.cloud;
    final theme = DsTheme.of(context);
    final colors = DsTheme.colorsOf(context);
    final figures = stats;
    final tiles = <(String, int?)>[
      (c.statTotal, figures?.total),
      (c.statAdmins, figures?.admins),
      (c.statManagers, figures?.managers),
      (c.statUsers, figures?.users),
      (c.statUploaders, figures?.uploaders),
    ];
    return Wrap(
      spacing: DsSpace.s12,
      runSpacing: DsSpace.s12,
      children: [
        for (final (label, value) in tiles)
          ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 132),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: colors.surface,
                borderRadius: BorderRadius.circular(theme.radii.card),
                border: Border.all(color: colors.border),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: DsSpace.s16, vertical: DsSpace.s12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: DsSpace.s4,
                  children: [
                    if (value == null)
                      const DsSpinner(style: DsSpinnerStyle(size: 16))
                    else
                      Text('$value', style: theme.typography.title),
                    Text(label, style: theme.typography.caption.copyWith(color: colors.textMuted)),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}
