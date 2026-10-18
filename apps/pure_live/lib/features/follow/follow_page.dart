import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_library/live_library.dart' show FollowGroup, FollowRepository, LibraryRoom;
import 'package:pure_live/app/preferences/app_preferences_providers.dart';
import 'package:pure_live/app/providers/app_providers.dart';
import 'package:pure_live/app/routing/routes/room/room_routes.dart';
import 'package:pure_live/app/shell/main_layout.dart';
import 'package:pure_live/app/shell/main_page_frame.dart';
import 'package:pure_live/app/shell/shell_destinations.dart' show ShellBranch;
import 'package:pure_live/features/follow/follow_group_sheet.dart';
import 'package:pure_live/features/popular/room_card.dart';
import 'package:pure_live/l10n/generated/strings.g.dart';
import 'package:pure_live/shared/widgets/list_loading.dart';
import 'package:pure_live/shared/widgets/settings_entry_button.dart';
import 'package:pure_uikit/pure_uikit.dart';

/// The follow domain's shell page (3.x `FavoritePage`, trimmed): every
/// followed room as a card, filtered by group, with unfollow on long
/// press. The grid updates from the repository's own change stream, so a
/// second window's follows appear here too.
final class FollowPage extends ConsumerStatefulWidget {
  /// The follow page.
  const new({super.key});

  @override
  ConsumerState<FollowPage> createState() => _FollowPageState();
}

final class _FollowPageState extends ConsumerState<FollowPage> with FeedAutoRefresh<FollowPage> {
  StreamSubscription<void>? _changes;
  StreamSubscription<String>? _reTaps;
  String? _selectedGroup;

  FollowRepository get _repository => ref.read(followRepositoryProvider);

  @override
  bool get feedVisible => true;

  @override
  Future<void> feedRefresh() async {
    // The grid reads the repository's own store, so a refresh is a re-read:
    // it picks up what other windows wrote since, and the change stream
    // repaints the grid.
    await _repository.load();
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void initState() {
    super.initState();
    unawaited(_repository.load());
    _changes = _repository.changes.listen((_) {
      if (mounted) {
        setState(() {});
      }
    });
    // Re-tapping the tab already on screen refreshes the grid — the
    // reference's `onDestinationSelected` favorites special case.
    _reTaps = ref
        .read(shellReTapSignalsProvider)
        .reTaps
        .where((branchId) => branchId == ShellBranch.follow.name)
        .listen((_) => unawaited(feedRefresh()));
  }

  @override
  void dispose() {
    unawaited(_changes?.cancel());
    unawaited(_reTaps?.cancel());
    super.dispose();
  }

  /// The group management sheet: create, rename, delete — deletions leave
  /// the followed rooms untouched (only their membership goes).
  Future<void> _manageGroups() async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Consumer(
          builder: (context, ref, _) {
            final groups = ref.watch(followRepositoryProvider).groups;
            return Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(context.t.follow.manageGroups, style: PureTheme.of(context).text.title),
                  const SizedBox(height: 12),
                  for (final group in groups)
                    PureListRow(
                      leading: const Icon(Icons.folder_outlined),
                      title: group.name,
                      divided: false,
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          PureIconButton(
                            tooltip: context.t.follow.renameGroup,
                            icon: Icons.edit_outlined,
                            onPressed: () => unawaited(_renameGroupFromSheet(context, group.id, group.name)),
                          ),
                          PureIconButton(
                            tooltip: context.t.follow.deleteGroup,
                            icon: Icons.delete_outline,
                            onPressed: () => unawaited(_deleteGroupFromSheet(context, group.id)),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 8),
                  PureButton(
                    label: context.t.follow.newGroup,
                    icon: Icons.add,
                    onPressed: () => unawaited(_createGroupFromSheet(context)),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Future<void> _renameGroupFromSheet(BuildContext sheetContext, String id, String current) async {
    final name = await showFollowGroupNameDialog(sheetContext, initial: current, title: context.t.follow.renameGroup);
    if (name != null && name.isNotEmpty && name != current) {
      await _repository.renameGroup(id, name);
    }
  }

  Future<void> _deleteGroupFromSheet(BuildContext sheetContext, String id) async {
    await _repository.deleteGroup(id);
  }

  Future<void> _createGroupFromSheet(BuildContext sheetContext) async {
    final name = await showFollowGroupNameDialog(sheetContext, title: context.t.follow.newGroup);
    if (name != null && name.isNotEmpty) {
      await _repository.createGroup(name);
    }
  }

  /// Long-press on a followed room: move it between groups (the checkbox
  /// set writes through setGroups, creating a group on the fly via the
  /// manage sheet).
  Future<void> _assignGroups(LibraryRoom record) async {
    final selected = {...record.groupIds};
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(context.t.follow.assign, style: PureTheme.of(context).text.title),
                const SizedBox(height: 8),
                for (final group in _repository.groups)
                  PureCheckbox(
                    label: group.name,
                    value: selected.contains(group.id),
                    onChanged: (checked) => setSheetState(() {
                      checked ? selected.add(group.id) : selected.remove(group.id);
                    }),
                  ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: PureButton(
                        label: context.t.common.confirm,
                        icon: Icons.check,
                        onPressed: () => Navigator.of(sheetContext).pop(true),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: PureButton(
                        label: context.t.follow.unfollow,
                        icon: Icons.heart_broken_outlined,
                        onPressed: () {
                          unawaited(_repository.unfollow(record.room));
                          Navigator.of(sheetContext).pop(true);
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (confirmed == true) {
      await _repository.setGroups(record.room, selected.toList());
    }
  }

  @override
  Widget build(BuildContext context) {
    final records = _repository.rooms;
    final groups = _repository.groups;
    final visible = _selectedGroup == null
        ? records
        : records.where((record) => record.groupIds.contains(_selectedGroup)).toList();
    final groupPosition = groups.indexWhere((group) => group.id == _selectedGroup);
    return MainPageFrame(
      title: context.t.tabs.follow,
      actions: [
        PureIconButton(
          tooltip: context.t.follow.manageGroups,
          icon: Icons.folder_copy_outlined,
          onPressed: _manageGroups,
        ),
        const SettingsEntryButton(),
      ],
      // The group filter travels two ways: a horizontal tab strip on phones
      // and tablets, and a context column beside the grid from the expanded
      // class up — the desktop grammar of filter-left, content-right. The
      // frame picks; the page supplies both forms from one state.
      tabs: [
        PureTab(label: context.t.follow.all),
        for (final group in groups) PureTab(label: group.name),
      ],
      tabIndex: _selectedGroup == null || groupPosition < 0 ? 0 : groupPosition + 1,
      onTabChanged: (index) => setState(() => _selectedGroup = index == 0 ? null : groups[index - 1].id),
      pane: _GroupPane(
        allLabel: context.t.follow.all,
        groups: groups,
        selectedId: _selectedGroup,
        onSelected: (id) => setState(() => _selectedGroup = id),
        onManage: _manageGroups,
      ),
      body: visible.isEmpty
          ? PureEmpty(title: context.t.follow.empty, icon: Icons.favorite_border)
          : LayoutBuilder(
              builder: (context, constraints) {
                // The reference favourite grid: one wide card on a phone,
                // more columns as the window grows. The cover reserves the
                // room-card aspect preference's shape.
                final width = constraints.maxWidth;
                final coverAspect = ref.watch(roomCardStyleProvider).aspect.ratio;
                // The gutter is both the grid's own padding and the amount
                // `delegateFor` takes back out of `width`; sharing the value
                // keeps the two from drifting and overflowing the row.
                final gutter = MainLayout.gutterOf(context);
                return GridView.builder(
                  padding: EdgeInsets.fromLTRB(gutter, PureSpacing.sm, gutter, PureSpacing.xxl),
                  gridDelegate: RoomGridMetrics.delegateFor(
                    context,
                    width,
                    coverAspect: coverAspect,
                    columns: RoomGridMetrics.favouriteColumnsFor(width),
                    gutter: gutter,
                  ),
                  itemCount: visible.length,
                  itemBuilder: (context, index) {
                    final record = visible[index];
                    return RoomCard(
                      room: record.room,
                      onOpen: () => RoomRoute(
                        siteId: record.room.ref.platform,
                        roomId: record.room.ref.roomId,
                        roomName: record.room.content.title,
                      ).push<void>(context),
                      // Long press moves the room between groups.
                      onLongPress: () => unawaited(_assignGroups(record)),
                    );
                  },
                );
              },
            ),
    );
  }
}

/// The follow page's desktop context column: every group as a navigation tile,
/// with the manage action pinned at the foot.
///
/// It renders from the same state the tab strip does — selecting here is
/// selecting there — so the group list is a re-embodiment of the filter, not a
/// second one.
final class _GroupPane extends StatelessWidget {
  const new({
    required this.allLabel,
    required this.groups,
    required this.selectedId,
    required this.onSelected,
    required this.onManage,
  });

  final String allLabel;
  final List<FollowGroup> groups;
  final String? selectedId;
  final ValueChanged<String?> onSelected;
  final VoidCallback onManage;

  @override
  Widget build(BuildContext context) {
    final destinations = [
      PureNavDestination(id: _allId, label: allLabel, icon: Icons.favorite),
      for (final group in groups)
        PureNavDestination(id: group.id, label: group.name, icon: Icons.folder_outlined),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(vertical: PureSpacing.xs),
            children: [
              for (final destination in destinations)
                PureNavigationTile(
                  destination: destination,
                  selected: destination.id == (selectedId ?? _allId),
                  onTap: () => onSelected(destination.id == _allId ? null : destination.id),
                ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(top: PureSpacing.sm),
          child: PureButton(
            label: context.t.follow.manageGroups,
            icon: Icons.folder_copy_outlined,
            variant: ButtonVariant.secondary,
            onPressed: onManage,
          ),
        ),
      ],
    );
  }
}

/// The pseudo id the "all" tile answers to; no group may use it.
const _allId = '__all__';
