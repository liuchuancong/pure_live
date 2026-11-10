import 'package:desen_ui/desen_ui.dart';
import 'package:flutter/services.dart' show LogicalKeyboardKey;
import 'package:flutter/widgets.dart';
import 'package:pure_live/l10n/translations.dart';

/// What a room key does. The page maps each one to its own controllers; the
/// table below only names the verb.
enum RoomShortcutAction {
  playPause,
  fullscreen,
  leave,
  volumeUp,
  volumeDown,
  chatColumn,
  stats,
  screenshot,
  retry,
  help,
}

/// One key the room answers to: the verb, the activators that fire it, and the
/// line the help sheet shows for it.
@immutable
final class RoomShortcutBinding {
  const RoomShortcutBinding({required this.action, required this.keys, required this.label});

  /// What the keys do.
  final RoomShortcutAction action;

  /// The keys that fire the action; several where a layout spells the same
  /// key differently (`?`).
  final List<SingleActivator> keys;

  /// The localized line beside the key caps.
  final String label;
}

/// The room's keys and its help sheet read this one table, so a line the
/// sheet shows is a key the page answers. The conditions are the ones the
/// actions run under: a TV remote keeps the arrows on focus, a narrow window
/// has no chat column to fold, and a backend without a capture route has no
/// frame to save.
List<RoomShortcutBinding> roomShortcutBindings(
  Translations t, {
  required bool tv,
  required bool chatColumn,
  required bool canCaptureScreenshot,
}) => [
  RoomShortcutBinding(
    action: RoomShortcutAction.playPause,
    keys: const [SingleActivator(LogicalKeyboardKey.space)],
    label: t.room.shortcutPlayPause,
  ),
  RoomShortcutBinding(
    action: RoomShortcutAction.fullscreen,
    keys: const [SingleActivator(LogicalKeyboardKey.keyF)],
    label: t.room.shortcutFullscreen,
  ),
  RoomShortcutBinding(
    action: RoomShortcutAction.leave,
    keys: const [SingleActivator(LogicalKeyboardKey.escape)],
    label: t.room.shortcutLeave,
  ),
  if (!tv) ...[
    RoomShortcutBinding(
      action: RoomShortcutAction.volumeUp,
      keys: const [SingleActivator(LogicalKeyboardKey.arrowUp)],
      label: t.room.shortcutVolumeUp,
    ),
    RoomShortcutBinding(
      action: RoomShortcutAction.volumeDown,
      keys: const [SingleActivator(LogicalKeyboardKey.arrowDown)],
      label: t.room.shortcutVolumeDown,
    ),
  ],
  if (chatColumn)
    RoomShortcutBinding(
      action: RoomShortcutAction.chatColumn,
      keys: const [SingleActivator(LogicalKeyboardKey.keyT)],
      label: t.room.shortcutChatColumn,
    ),
  RoomShortcutBinding(
    action: RoomShortcutAction.stats,
    keys: const [SingleActivator(LogicalKeyboardKey.keyI)],
    label: t.room.statsToggle,
  ),
  if (!tv && canCaptureScreenshot)
    RoomShortcutBinding(
      action: RoomShortcutAction.screenshot,
      keys: const [SingleActivator(LogicalKeyboardKey.keyS)],
      label: t.room.screenshot,
    ),
  RoomShortcutBinding(
    action: RoomShortcutAction.retry,
    keys: const [SingleActivator(LogicalKeyboardKey.keyR)],
    label: t.common.retry,
  ),
  if (!tv)
    RoomShortcutBinding(
      action: RoomShortcutAction.help,
      keys: const [
        // `?` is Shift+slash on the common layouts; a layout with its own
        // question key reports that one instead.
        SingleActivator(LogicalKeyboardKey.question),
        SingleActivator(LogicalKeyboardKey.slash, shift: true),
      ],
      label: t.room.shortcutsHelp,
    ),
];

/// The legend on a key cap: the key's own letter or glyph, with the two keys
/// whose default legends are blank or a word named in the viewer's language.
String roomShortcutKeyLabel(SingleActivator activator, Translations t) {
  final key = activator.trigger;
  if (key == LogicalKeyboardKey.space) return t.room.keySpace;
  if (key == LogicalKeyboardKey.escape) return t.room.keyEscape;
  if (key == LogicalKeyboardKey.arrowUp) return '↑';
  if (key == LogicalKeyboardKey.arrowDown) return '↓';
  if (key == LogicalKeyboardKey.question || key == LogicalKeyboardKey.slash) return '?';
  return key.keyLabel;
}

/// The keyboard cheat sheet: the keys this room answers to right now, one row
/// each. Opened by `?` and by the room menu.
Future<void> showRoomShortcuts(BuildContext context, List<RoomShortcutBinding> bindings) => showDsDialog<void>(
  context: context,
  builder: (_) => _RoomShortcutsDialog(bindings: bindings),
);

final class _RoomShortcutsDialog extends StatelessWidget {
  const _RoomShortcutsDialog({required this.bindings});

  final List<RoomShortcutBinding> bindings;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    void close() => Navigator.of(context).pop();
    return CallbackShortcuts(
      // The route handles Escape; the key that opened the sheet closes it too.
      bindings: {
        const SingleActivator(LogicalKeyboardKey.question): close,
        const SingleActivator(LogicalKeyboardKey.slash, shift: true): close,
      },
      child: DsDialog(
        title: Text(t.room.shortcutsHelp),
        icon: const DsIcon(DsIcons.keyboard),
        description: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: DsSpace.s8,
          children: [
            Text(t.room.shortcutsHint),
            for (final binding in bindings) _RoomShortcutRow(binding: binding),
          ],
        ),
        actions: [DsButton(onPressed: close, child: Text(t.common.close))],
      ),
    );
  }
}

final class _RoomShortcutRow extends StatelessWidget {
  const _RoomShortcutRow({required this.binding});

  final RoomShortcutBinding binding;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    return Row(
      children: [
        _KeyCap(label: roomShortcutKeyLabel(binding.keys.first, t)),
        const SizedBox(width: DsSpace.s12),
        Expanded(child: Text(binding.label)),
      ],
    );
  }
}

final class _KeyCap extends StatelessWidget {
  const _KeyCap({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = DsTheme.of(context);
    final colors = DsTheme.colorsOf(context);
    return Container(
      height: theme.sizes.xs,
      constraints: BoxConstraints(minWidth: theme.sizes.xs),
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: DsSpace.s6),
      decoration: BoxDecoration(
        color: colors.control,
        borderRadius: BorderRadius.circular(theme.radii.control(theme.sizes.xs)),
        border: Border.all(color: colors.borderControl),
      ),
      child: Text(label, style: theme.typography.numeric(theme.typography.caption.copyWith(color: colors.text))),
    );
  }
}
