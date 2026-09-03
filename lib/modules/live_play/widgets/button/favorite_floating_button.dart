import 'dart:io';

import 'package:remixicon/remixicon.dart';
import 'package:pure_live/common/index.dart';
import 'package:pure_live/plugins/event_bus.dart';

class FavoriteFloatingButton extends StatelessWidget {
  const FavoriteFloatingButton({super.key, required this.room, this.compact = false});

  final LiveRoom room;
  final bool compact;

  Future<void> _toggleFavorite(bool isFavorite) async {
    if (!isFavorite) {
      if (SettingsService.to.fav.addRoom(room)) {
        EventBus.instance.emit('changeFavorite', true);
      }
      return;
    }
    // Bind the actions to the dialog route itself. A global Get context may
    // point at the page navigator while routes are transitioning.
    final confirmed = await Get.dialog<bool>(
      Builder(
        builder: (dialogContext) => AlertDialog(
          title: Text(i18n('unfollow')),
          content: Text(i18n('unfollow_message', args: {'name': room.nick ?? ''})),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(i18n('cancel')),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(i18n('confirm')),
            ),
          ],
        ),
      ),
    );
    if (confirmed == true && SettingsService.to.fav.removeRoom(room)) {
      EventBus.instance.emit('changeFavorite', true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      // Explicitly observe the persisted list. The former EventBus + local
      // setState path missed canonical room-id changes and external updates.
      final favoriteRooms = SettingsService.to.fav.favoriteRooms.value;
      final isFavorite = favoriteRooms.any((candidate) => candidate.hasSameIdentity(room));
      final label = i18n(isFavorite ? 'followed' : 'follow');

      if (compact) {
        return Tooltip(
          message: label,
          child: IconButton.filledTonal(
            visualDensity: VisualDensity.compact,
            constraints: const BoxConstraints.tightFor(width: 40, height: 38),
            padding: EdgeInsets.zero,
            onPressed: () => _toggleFavorite(isFavorite),
            icon: Icon(isFavorite ? Remix.heart_3_fill : Remix.heart_3_line, size: 19),
          ),
        );
      }
      return FilledButton(
        style: ButtonStyle(
          padding: WidgetStateProperty.all(
            Platform.isWindows ? const EdgeInsets.all(12) : const EdgeInsets.all(5),
          ),
          backgroundColor: WidgetStateProperty.all(
            isFavorite
                ? Get.theme.colorScheme.primary.withAlpha(125)
                : Get.theme.colorScheme.primary,
          ),
          shape: WidgetStateProperty.all(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
          ),
          textStyle: WidgetStateProperty.all(AppTextStyles.t12),
          minimumSize: WidgetStateProperty.all(Size.zero),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        onPressed: () => _toggleFavorite(isFavorite),
        child: Text(label),
      );
    });
  }
}
