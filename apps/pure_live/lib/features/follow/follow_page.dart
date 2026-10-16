import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_library/live_library.dart' show FollowRepository, LibraryRoom;
import 'package:live_sites/live_sites.dart' show LiveRoom;
import 'package:live_uikit/live_uikit.dart';
import 'package:pure_live/app/providers/app_providers.dart';
import 'package:pure_live/app/routing/routes/room/room_routes.dart';
import 'package:pure_live/features/follow/follow_group_sheet.dart';
import 'package:pure_live/features/popular/room_card.dart';
import 'package:pure_live/l10n/generated/strings.g.dart';
import 'package:pure_live/shared/widgets/settings_entry_button.dart';

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

final class _FollowPageState extends ConsumerState<FollowPage> {
  StreamSubscription<void>? _changes;
  String? _selectedGroup;

  FollowRepository get _repository => ref.read(followRepositoryProvider);

  @override
  void initState() {
    super.initState();
    unawaited(_repository.load());
    _changes = _repository.changes.listen((_) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    unawaited(_changes?.cancel());
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
                  Text(context.t.follow.manageGroups, style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 12),
                  for (final group in groups)
                    LiveListRow(
                      leading: const Icon(Icons.folder_outlined),
                      title: group.name,
                      divided: false,
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            tooltip: context.t.follow.renameGroup,
                            icon: const Icon(Icons.edit_outlined),
                            onPressed: () => unawaited(_renameGroupFromSheet(context, group.id, group.name)),
                          ),
                          IconButton(
                            tooltip: context.t.follow.deleteGroup,
                            icon: const Icon(Icons.delete_outline),
                            onPressed: () => unawaited(_deleteGroupFromSheet(context, group.id)),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 8),
                  LiveButton(
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
                Text(context.t.follow.assign, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                for (final group in _repository.groups)
                  CheckboxListTile(
                    title: Text(group.name),
                    value: selected.contains(group.id),
                    onChanged: (checked) => setSheetState(() {
                      checked == true ? selected.add(group.id) : selected.remove(group.id);
                    }),
                  ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: LiveButton(
                        label: context.t.common.confirm,
                        icon: Icons.check,
                        onPressed: () => Navigator.of(sheetContext).pop(true),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: LiveButton(
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
    return DefaultTabController(
      length: groups.length + 1,
      child: LiveScaffold(
        appBar: LiveAppBar(
          title: context.t.tabs.follow,
          actions: [
            IconButton(
              tooltip: context.t.follow.manageGroups,
              icon: const Icon(Icons.folder_copy_outlined),
              onPressed: _manageGroups,
            ),
            const SettingsEntryButton(),
          ],
          // A Material strip for now: `LiveTabs` has no TabController, so this
          // bar and the group grid it selects into have to move to an index
          // plus a filtered view together, not one at a time.
          bottom: TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            onTap: (index) => setState(() => _selectedGroup = index == 0 ? null : groups[index - 1].id),
            tabs: [
              Tab(text: context.t.follow.all),
              for (final group in groups) Tab(text: group.name),
            ],
          ),
        ),
        body: visible.isEmpty
            ? LiveEmpty(title: context.t.follow.empty)
            : GridView.builder(
                padding: const EdgeInsets.all(12),
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 340,
                  childAspectRatio: 0.82,
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                ),
                itemCount: visible.length,
                itemBuilder: (context, index) => GestureDetector(
                  onLongPress: () => unawaited(_assignGroups(visible[index])),
                  child: _tile(context, visible[index].room),
                ),
              ),
      ),
    );
  }

  Widget _tile(BuildContext context, LiveRoom room) => RoomCard(
    room: room,
    onOpen: () =>
        RoomRoute(siteId: room.ref.platform, roomId: room.ref.roomId, roomName: room.content.title).push<void>(context),
  );
}
