import 'dart:convert' show jsonDecode, jsonEncode;

import 'package:desen_ui/desen_ui.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_sites/live_sites.dart';
import 'package:live_storage/live_storage.dart' show StoragePrefs;

import 'package:pure_live/l10n/translations.dart';

/// How one room's picture is framed, regardless of the stream's own shape.
enum RoomOrientation {
  /// Follow the picture's own aspect ratio.
  automatic,

  /// Treat the picture as portrait (a tall frame, letterboxed if needed).
  portrait,

  /// Treat the picture as landscape (a wide frame, pillarboxed if needed).
  landscape,
}

/// The settings key the per-room framing choices live under.
const String roomOrientationPrefKey = 'room.orientation';

/// The viewer's per-room framing choices, stored as one JSON object under
/// `room.orientation` (room identity → orientation name).
///
/// The choice belongs to the room, not to the page: coming back to a room
/// keeps the frame the viewer picked, and another room is unaffected.
base class RoomOrientationChoices extends Notifier<Map<String, RoomOrientation>> {
  @override
  Map<String, RoomOrientation> build() {
    try {
      return decode(StoragePrefs.getString(roomOrientationPrefKey));
    } on Object {
      return const {};
    }
  }

  /// Reads the stored JSON into the room → orientation map; malformed
  /// values answer empty, so a broken pref never breaks a room.
  static Map<String, RoomOrientation> decode(String? raw) {
    if (raw == null || raw.trim().isEmpty) return const {};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return const {};
      final choices = <String, RoomOrientation>{};
      for (final entry in decoded.entries) {
        if (entry.key is! String || entry.value is! String) continue;
        final choice = RoomOrientation.values.asNameMap()[entry.value as String];
        if (choice != null) choices[entry.key as String] = choice;
      }
      return choices;
    } on Object {
      return const {};
    }
  }

  /// Encodes [choices] as the stored JSON.
  static String encode(Map<String, RoomOrientation> choices) =>
      jsonEncode({for (final entry in choices.entries) entry.key: entry.value.name});

  /// Applies choices pushed by another window without writing the store.
  void applyRemote(String? raw) {
    state = Map.unmodifiable(decode(raw));
  }

  /// The choice for [identityKey]; automatic when none was made.
  RoomOrientation of(String identityKey) => state[identityKey] ?? RoomOrientation.automatic;

  /// Sets [identityKey]'s framing; automatic removes the stored choice so a
  /// later stream-size change is followed again.
  Future<void> set(String identityKey, RoomOrientation orientation) async {
    final next = Map<String, RoomOrientation>.of(state);
    if (orientation == RoomOrientation.automatic) {
      next.remove(identityKey);
    } else {
      next[identityKey] = orientation;
    }
    state = Map.unmodifiable(next);
    await persist(encode(next));
  }

  /// Forgets every room's framing (the portrait settings' reset flow).
  Future<void> reset() async {
    state = const {};
    await persist(encode(const {}));
  }

  /// Writes the encoded choices. In a clone this goes through the remote
  /// store, so the primary persists it and broadcasts it to every window.
  Future<void> persist(String raw) async {
    try {
      await StoragePrefs.setString(roomOrientationPrefKey, raw);
    } on Object {
      // The choice is a preference; a closed store loses it.
    }
  }
}

/// The per-room orientation choices.
final roomOrientationChoicesProvider = NotifierProvider<RoomOrientationChoices, Map<String, RoomOrientation>>(
  RoomOrientationChoices.new,
);

/// One room's chosen framing.
final Provider<RoomOrientation> Function(String) roomOrientationProvider = Provider.family<RoomOrientation, String>((
  ref,
  identityKey,
) {
  final choices = ref.watch(roomOrientationChoicesProvider);
  return choices[identityKey] ?? RoomOrientation.automatic;
});

/// The ratio a frame follows for [orientation]: the stream's [detected]
/// ratio when automatic, else the canonical shape of the chosen one.
double roomFrameRatio(RoomOrientation orientation, {required double detected}) => switch (orientation) {
  RoomOrientation.automatic => detected,
  RoomOrientation.portrait => 9 / 16,
  RoomOrientation.landscape => 16 / 9,
};

/// Opens the room's framing choice: follow the stream, or force a portrait
/// or landscape frame. The choice is stored for the room itself.
Future<void> showRoomOrientationDialog(BuildContext context, LiveRoom room) => showDsDialog<void>(
  context: context,
  builder: (_) => _RoomOrientationDialog(room: room),
);

final class _RoomOrientationDialog extends ConsumerStatefulWidget {
  const _RoomOrientationDialog({required this.room});

  final LiveRoom room;

  @override
  ConsumerState<_RoomOrientationDialog> createState() => _RoomOrientationDialogState();
}

final class _RoomOrientationDialogState extends ConsumerState<_RoomOrientationDialog> {
  late RoomOrientation _choice = ref.read(roomOrientationProvider(widget.room.ref.identityKey));

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    return DsDialog(
      title: Text(t.room.orientation),
      icon: const DsIcon(DsIcons.rectangleVertical),
      description: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: DsSpace.s12,
        children: [
          Text(t.room.orientationHint),
          DsSegmentedControl<RoomOrientation>(
            value: _choice,
            onChanged: (value) => setState(() => _choice = value),
            segments: [
              DsSegment(value: RoomOrientation.automatic, label: Text(t.room.orientationAutomatic)),
              DsSegment(value: RoomOrientation.portrait, label: Text(t.room.orientationPortrait)),
              DsSegment(value: RoomOrientation.landscape, label: Text(t.room.orientationLandscape)),
            ],
          ),
        ],
      ),
      actions: [
        DsButton(
          variant: DsButtonVariant.secondary,
          onPressed: () => Navigator.of(context).pop(),
          child: Text(t.common.cancel),
        ),
        DsButton(
          onPressed: () async {
            await ref.read(roomOrientationChoicesProvider.notifier).set(widget.room.ref.identityKey, _choice);
            if (!context.mounted) return;
            Navigator.of(context).pop();
            showDsToast(context: context, title: t.room.orientationUpdated);
          },
          child: Text(t.common.confirm),
        ),
      ],
    );
  }
}
