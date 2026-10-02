import 'package:flutter/material.dart';
import 'package:pure_live/core/models/live_room.dart';
import 'package:pure_live/core/widgets/common_avatar.dart';
import 'package:pure_live/core/utils/i18n.dart';

class ShareCommandImportDialog extends StatelessWidget {
  const ShareCommandImportDialog({super.key, required this.room});

  final LiveRoom room;

  static Future<bool?> show({required BuildContext context, required LiveRoom liveroom}) {
    return showDialog<bool>(
      context: context,
      builder: (_) => ShareCommandImportDialog(room: liveroom),
    );
  }

  @override
  Widget build(BuildContext context) {
    final textScale = MediaQuery.textScalerOf(context).scale(1);
    final stacked = MediaQuery.sizeOf(context).width < 350 || textScale >= 1.6;

    return AlertDialog(
      scrollable: true,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(16))),
      title: Text(i18n('share')),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (stacked) _StackedRoomIdentity(room: room) else _InlineRoomIdentity(room: room),
            const SizedBox(height: 16),
            DecoratedBox(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Theme.of(context).dividerColor.withValues(alpha: 0.35)),
              ),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _MetadataRow(label: i18n('platform'), value: room.platform ?? '', stacked: stacked),
                    const SizedBox(height: 10),
                    _MetadataRow(label: i18n('room_id'), value: room.roomId ?? '', stacked: stacked),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(i18n('cancel')),
        ),
        FilledButton(
          style: FilledButton.styleFrom(minimumSize: const Size(48, 48)),
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(i18n('enter_room')),
        ),
      ],
    );
  }
}

class _InlineRoomIdentity extends StatelessWidget {
  const _InlineRoomIdentity({required this.room});

  final LiveRoom room;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CommonAvatar(avatarUrl: room.avatar, fallbackName: room.nick, radius: 24),
        const SizedBox(width: 12),
        Expanded(child: _RoomIdentityText(room: room, compact: true)),
      ],
    );
  }
}

class _StackedRoomIdentity extends StatelessWidget {
  const _StackedRoomIdentity({required this.room});

  final LiveRoom room;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CommonAvatar(avatarUrl: room.avatar, fallbackName: room.nick, radius: 24),
        const SizedBox(height: 12),
        _RoomIdentityText(room: room, compact: false),
      ],
    );
  }
}

class _RoomIdentityText extends StatelessWidget {
  const _RoomIdentityText({required this.room, required this.compact});

  final LiveRoom room;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          room.title?.trim() ?? '',
          maxLines: compact ? 2 : null,
          overflow: compact ? TextOverflow.ellipsis : TextOverflow.visible,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 4),
        Text(
          room.nick?.trim() ?? '',
          maxLines: compact ? 1 : null,
          overflow: compact ? TextOverflow.ellipsis : TextOverflow.visible,
          style: Theme.of(context).textTheme.bodyMedium
              ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
      ],
    );
  }
}

class _MetadataRow extends StatelessWidget {
  const _MetadataRow({required this.label, required this.value, required this.stacked});

  final String label;
  final String value;
  final bool stacked;

  @override
  Widget build(BuildContext context) {
    final labelWidget = Text(label, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant));
    final valueWidget = Text(value, softWrap: true, style: const TextStyle(fontWeight: FontWeight.w600));

    if (stacked) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [labelWidget, const SizedBox(height: 4), valueWidget],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        labelWidget,
        const SizedBox(width: 8),
        Expanded(child: valueWidget),
      ],
    );
  }
}
