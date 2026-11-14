import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_sites/live_sites.dart';
import 'package:pure_live/l10n/translations.dart';

import 'package:pure_live/modules/live/favorites/data/follow_repository.dart' show followsProvider;
import 'package:pure_live/modules/live/room/controller/room_controller.dart';
import 'package:pure_live/shared/widgets/app_dialog.dart';

/// Toggles the room's follow, asking first when it would undo one.
///
/// The follow faces — the header's pill, the details' row, the picture's
/// chip, the fullscreen menu's row — share this one door, so undoing a
/// follow is confirmed the same way no matter which of them was pressed,
/// and following asks nothing.
Future<void> toggleRoomFollow(BuildContext context, WidgetRef ref) async {
  final detail = ref.read(roomProvider).room;
  if (detail == null) return;
  final key = detail.ref.identityKey;
  final followed = ref.read(followsProvider).rooms.any((entry) => entry.ref.identityKey == key);
  if (followed) {
    final t = context.t;
    final name = (detail.anchor?.name ?? '').trim();
    final confirmed = await showAppConfirm(
      context: context,
      title: t.room.unfollowAction,
      description: t.room.unfollowConfirm(name: name.isEmpty ? detail.content.title : name),
      confirmLabel: t.room.unfollowAction,
      destructive: true,
    );
    if (!confirmed) return;
  }
  await ref.read(roomProvider.notifier).toggleFollow();
}
