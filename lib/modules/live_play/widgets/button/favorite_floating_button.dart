import 'dart:io';
import 'dart:async';

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
  StreamSubscription<dynamic>? subscription;

  @override
  void initState() {
    super.initState();
    _listenFavorite();
  }

  void _listenFavorite() {
    subscription = EventBus.instance.listen('changeFavorite', (data) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    subscription?.cancel();
    super.dispose();
  }

  Future<void> _toggleFavorite(bool isFavorite) async {
    if (!isFavorite) {
      SettingsService.to.fav.addRoom(widget.room);
      EventBus.instance.emit('changeFavorite', true);
      if (mounted) {
        setState(() {});
      }
      return;
    }

    final confirmed = await Get.dialog<bool>(
      AlertDialog(
        title: Text(i18n('unfollow')),
        content: Text(i18n('unfollow_message', args: {'name': widget.room.nick ?? ''})),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(Get.context!).pop(false);
            },
            child: Text(i18n('cancel')),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(Get.context!).pop(true);
            },
            child: Text(i18n('confirm')),
          ),
        ],
      ),
    );

    if (confirmed != true) {
      return;
    }

    SettingsService.to.fav.removeRoom(widget.room);

    EventBus.instance.emit('changeFavorite', true);

    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final isFavorite = SettingsService.to.fav.isFavorite(widget.room);

      final label = i18n(isFavorite ? 'followed' : 'follow');

      if (widget.compact) {
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
          padding: WidgetStateProperty.all(Platform.isWindows ? const EdgeInsets.all(12) : const EdgeInsets.all(5)),
          backgroundColor: WidgetStateProperty.all(
            isFavorite ? Get.theme.colorScheme.primary.withAlpha(125) : Get.theme.colorScheme.primary,
          ),
          shape: WidgetStateProperty.all(RoundedRectangleBorder(borderRadius: BorderRadius.circular(6))),
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
