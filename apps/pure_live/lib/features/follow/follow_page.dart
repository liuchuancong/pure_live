import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_library/live_library.dart' show FollowRepository, LibraryRoom;
import 'package:live_sites/live_sites.dart' show LiveRoom;
import 'package:live_uikit/styling.dart' show LiveButton, LiveEmpty;

import 'package:pure_live/app/providers/app_providers.dart';
import 'package:pure_live/app/routing/routes/room/room_routes.dart';
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

  Future<void> _confirmUnfollow(LibraryRoom record) async {
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(context.t.follow.unfollowConfirm(name: record.room.content.title)),
              const SizedBox(height: 16),
              LiveButton(
                label: context.t.follow.unfollow,
                icon: Icons.heart_broken_outlined,
                onPressed: () => Navigator.of(context).pop(true),
              ),
            ],
          ),
        ),
      ),
    );
    if (confirmed == true) {
      await _repository.unfollow(record.room);
    }
  }

  Future<void> _createGroup() async {
    final name = await showDialog<String>(
      context: context,
      builder: (context) {
        final field = TextEditingController();
        return AlertDialog(
          title: Text(context.t.follow.newGroup),
          content: TextField(
            controller: field,
            autofocus: true,
            decoration: InputDecoration(hintText: context.t.follow.groupName),
            onSubmitted: (value) => Navigator.of(context).pop(value.trim()),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(context.t.common.cancel)),
            TextButton(
              onPressed: () => Navigator.of(context).pop(field.text.trim()),
              child: Text(context.t.common.confirm),
            ),
          ],
        );
      },
    );
    if (name != null && name.isNotEmpty) {
      await _repository.createGroup(name);
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
      child: Scaffold(
        appBar: AppBar(
          title: Text(context.t.tabs.follow),
          actions: [
            IconButton(
              tooltip: context.t.follow.newGroup,
              icon: const Icon(Icons.create_new_folder_outlined),
              onPressed: _createGroup,
            ),
            const SettingsEntryButton(),
          ],
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
                  onLongPress: () => unawaited(_confirmUnfollow(visible[index])),
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
