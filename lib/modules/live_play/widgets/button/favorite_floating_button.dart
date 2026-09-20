import 'dart:io';

import 'package:remixicon/remixicon.dart';
import 'package:pure_live/common/index.dart';
import 'package:pure_live/plugins/event_bus.dart';

class FavoriteFloatingButton extends StatefulWidget {
  const FavoriteFloatingButton({super.key, required this.room, this.compact = false});

  final LiveRoom room;
  final bool compact;

  @override
  State<FavoriteFloatingButton> createState() => _FavoriteFloatingButtonState();
}

class _FavoriteFloatingButtonState extends State<FavoriteFloatingButton> {
  bool _pending = false;

  Future<void> _toggleFavorite(BuildContext context, bool isFavorite) async {
    if (_pending) return;
    final targetRoom = widget.room;
    setState(() => _pending = true);
    try {
      if (!isFavorite) {
        if (SettingsService.to.fav.addRoom(targetRoom)) {
          EventBus.instance.emit('changeFavorite', true);
        }
        return;
      }
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(i18n('unfollow')),
          content: Text(i18n('unfollow_message', args: {'name': targetRoom.nick ?? ''})),
          actions: [
            TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: Text(i18n('cancel'))),
            TextButton(onPressed: () => Navigator.of(dialogContext).pop(true), child: Text(i18n('confirm'))),
          ],
        ),
      );
      if (confirmed == true && SettingsService.to.fav.removeRoom(targetRoom)) {
        EventBus.instance.emit('changeFavorite', true);
      }
    } finally {
      if (mounted) setState(() => _pending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      // Explicitly observe the persisted list. The former EventBus + local
      // setState path missed canonical room-id changes and external updates.
      final favoriteRooms = SettingsService.to.fav.favoriteRooms.value;
      final isFavorite = favoriteRooms.any((candidate) => candidate.hasSameIdentity(widget.room));
      final label = i18n(isFavorite ? 'followed' : 'follow');

      if (widget.compact) {
        return Tooltip(
          message: label,
          child: IconButton.filledTonal(
            key: const ValueKey('favorite-action-button-compact'),
            // Compact visual density subtracts eight logical pixels from the
            // supplied constraints, reducing this header action back to 40dp.
            visualDensity: VisualDensity.standard,
            constraints: const BoxConstraints.tightFor(
              width: kMinInteractiveDimension,
              height: kMinInteractiveDimension,
            ),
            padding: EdgeInsets.zero,
            onPressed: _pending ? null : () => _toggleFavorite(context, isFavorite),
            icon: Icon(isFavorite ? Remix.heart_3_fill : Remix.heart_3_line, size: 19),
          ),
        );
      }
      return FilledButton(
        key: const ValueKey('favorite-action-button-expanded'),
        style: ButtonStyle(
          padding: WidgetStateProperty.all(Platform.isWindows ? const EdgeInsets.all(12) : const EdgeInsets.all(5)),
          backgroundColor: WidgetStateProperty.all(
            isFavorite ? Get.theme.colorScheme.primary.withAlpha(125) : Get.theme.colorScheme.primary,
          ),
          shape: WidgetStateProperty.all(RoundedRectangleBorder(borderRadius: BorderRadius.circular(6))),
          textStyle: WidgetStateProperty.all(AppTextStyles.t12),
          minimumSize: WidgetStateProperty.all(const Size(kMinInteractiveDimension, kMinInteractiveDimension)),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        onPressed: _pending ? null : () => _toggleFavorite(context, isFavorite),
        child: Text(label),
      );
    });
  }
}
