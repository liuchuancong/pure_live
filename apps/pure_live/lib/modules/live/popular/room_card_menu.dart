import 'dart:async' show unawaited;

import 'package:desen_ui/desen_ui.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_sites/live_sites.dart';
import 'package:pure_live/app/app.dart';
import 'package:pure_live/l10n/translations.dart';
import 'package:pure_live/modules/live/favorites/data/follow_repository.dart' show followsProvider;
import 'package:pure_live/modules/live/favorites/widgets/follow_tag_picker.dart' show showFollowTagPicker;
import 'package:pure_live/modules/live/room/page/room_details.dart' show copyRoomLink, roomLinkOf, shareRoom;
import 'package:pure_live/modules/live/toolbox/direct_link_dialog.dart' show showRoomDirectLinks;
import 'package:pure_live/shared/shared.dart';

/// The room card's window furniture, worn by every feed that lists rooms:
/// the hover label that names the room in full — a card truncates its title
/// and leaves the rest to its cover — and the right-click / long-press menu.
///
/// The menu carries what a viewer does about a room: open it, share it,
/// copy its page link or its direct stream links, follow or unfollow it, and
/// give it any number of tags — tags belong to followed rooms, so an
/// unfollowed one is asked to follow first. A page appends its own items
/// after them (the history's removal).
final class RoomCardMenu extends ConsumerWidget {
  /// Wraps [child] — the room card — in the card's label and menu.
  const RoomCardMenu({required this.room, required this.onOpen, required this.child, this.items = const [], super.key});

  /// The room the card shows.
  final LiveRoom room;

  /// Opens the room; the card and the menu's first item both use it.
  final VoidCallback onOpen;

  /// The page's own menu items, after the card's, behind a divider.
  final List<Widget> items;

  /// The card to wrap.
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    final followed = ref.watch(
      followsProvider.select((follows) => follows.rooms.any((entry) => entry.ref.identityKey == room.ref.identityKey)),
    );
    final link = roomLinkOf(room);
    return DsTooltip(
      message: roomCardSummary(ref, room),
      side: DsSide.bottom,
      // The card already speaks its own content; the label is for the
      // pointer, not a second thing to hear.
      excludeFromSemantics: true,
      child: DsContextMenuRegion(
        semanticLabel: t.common.more,
        items: [
          DsMenuItem(leading: const DsIcon(DsIcons.play), label: Text(t.room.openRoom), onPressed: onOpen),
          DsMenuItem(
            leading: const DsIcon(DsIcons.share),
            label: Text(t.room.share),
            onPressed: () => unawaited(shareRoom(context, room)),
          ),
          if (link.isNotEmpty)
            DsMenuItem(
              leading: const DsIcon(DsIcons.link),
              label: Text(t.room.copyLink),
              onPressed: () => unawaited(copyRoomLink(context, room)),
            ),
          DsMenuItem(
            leading: const DsIcon(DsIcons.link2),
            label: Text(t.toolbox.linkDirect),
            onPressed: () => unawaited(showRoomDirectLinks(context, ref, room)),
          ),
          const DsMenuDivider(),
          DsMenuItem(
            leading: DsIcon(followed ? DsIcons.heartCrack : DsIcons.heart),
            label: Text(followed ? t.favorites.unfollow : t.room.follow),
            destructive: followed,
            onPressed: () => unawaited(
              followed
                  ? ref.read(followsProvider.notifier).remove(room.ref.identityKey)
                  : ref.read(followsProvider.notifier).add(room),
            ),
          ),
          DsMenuItem(
            leading: const DsIcon(DsIcons.tag),
            label: Text(t.favorites.setTags),
            onPressed: () => unawaited(_setTags(context, ref, followed)),
          ),
          if (items.isNotEmpty) ...[const DsMenuDivider(), ...items],
        ],
        child: child,
      ),
    );
  }

  /// Opens the room's tags. Tags belong to a followed room, so an
  /// unfollowed one asks whether to follow first — and, once it does, opens
  /// the picker with every tag ready to join or leave.
  Future<void> _setTags(BuildContext context, WidgetRef ref, bool followed) async {
    final t = context.t;
    if (!followed) {
      final follow = await showDsConfirm(
        context: context,
        title: t.favorites.tagFollowTitle,
        description: t.favorites.tagFollowBody,
        confirmLabel: t.room.follow,
        icon: const DsIcon(DsIcons.heart),
      );
      if (!follow) return;
      await ref.read(followsProvider.notifier).add(room);
      if (!context.mounted) return;
    }
    await showFollowTagPicker(context, room);
  }
}

/// What the card's hover label says: the title in full, then the room's
/// other names — the anchor, the area, the platform — on one line, each only
/// when the source gave it.
String roomCardSummary(WidgetRef ref, LiveRoom room) {
  final title = room.content.title;
  final anchor = (room.anchor?.name ?? '').trim();
  final area = (room.area?.areaName ?? '').trim();
  final site = ref.read(sitesProvider).getById(room.ref.platform);
  final platform = site == null ? '' : localizedSiteShortName(site);
  final details = [anchor, area, platform].where((value) => value.isNotEmpty).join(' · ');
  return details.isEmpty ? title : '$title\n$details';
}
