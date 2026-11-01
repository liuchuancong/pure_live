import 'dart:convert' show jsonDecode, jsonEncode;

import 'package:desen_ui/desen_ui.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_sites/live_sites.dart';
import 'package:live_storage/live_storage.dart' show StoragePrefs;

import 'package:pure_live/l10n/translations.dart';

/// How one room's picture is framed, regardless of the stream's own shape.
enum RoomOrientation {
  /// Follow the picture's own aspect ratio, capped at [kRoomFrameRatioMax].
  automatic,

  /// Treat the picture as portrait (a tall frame, letterboxed if needed).
  portrait,

  /// Treat the picture as landscape (a wide frame, pillarboxed if needed).
  landscape,

  /// The picture's own ratio without the cap: an ultra-wide source fills the
  /// stage's width. Offered only to sources wider than [kRoomFrameRatioMax];
  /// a narrower picture frames exactly as [automatic] does.
  fillWidth,
}

/// The widest frame the page draws by default.
///
/// A very wide picture is framed at 2.4:1 so the control bars keep a share of
/// the stage; the source's own ratio takes over only when the viewer picks
/// [RoomOrientation.fillWidth].
const double kRoomFrameRatioMax = 2.4;

/// The narrowest frame the page draws (a tall portrait source).
const double kRoomFrameRatioMin = 0.5;

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
/// ratio when automatic or filling the width, else the canonical shape of
/// the chosen one.
double roomFrameRatio(RoomOrientation orientation, {required double detected}) => switch (orientation) {
  RoomOrientation.automatic || RoomOrientation.fillWidth => detected,
  RoomOrientation.portrait => 9 / 16,
  RoomOrientation.landscape => 16 / 9,
};

/// The frame ratio [orientation] asks for, kept inside the page's bounds.
///
/// The default cap holds every source to [kRoomFrameRatioMax]; only
/// [RoomOrientation.fillWidth] lifts it, which is the whole point of that
/// choice for a picture wider than the cap.
double roomFramedRatio(RoomOrientation orientation, {required double detected}) => roomFrameRatio(
  orientation,
  detected: detected,
).clamp(kRoomFrameRatioMin, orientation == RoomOrientation.fillWidth ? double.infinity : kRoomFrameRatioMax);

/// Whether [detected] is wider than the default cap: the only shape that
/// gains anything from [RoomOrientation.fillWidth].
bool roomFillsWidth(double detected) => detected.isFinite && detected > kRoomFrameRatioMax;

/// Opens the room's framing choice: follow the stream, force a portrait or
/// landscape frame, or — for a picture wider than the cap — fill the width at
/// its own ratio. The choice is stored for the room itself.
Future<void> showRoomOrientationDialog(BuildContext context, LiveRoom room, {double detected = 0}) =>
    showDsDialog<void>(
      context: context,
      builder: (_) => _RoomOrientationDialog(room: room, detected: detected),
    );

final class _RoomOrientationDialog extends ConsumerStatefulWidget {
  const _RoomOrientationDialog({required this.room, required this.detected});

  final LiveRoom room;

  /// The picture's own ratio as the engine reports it; 0 before it reports.
  final double detected;

  @override
  ConsumerState<_RoomOrientationDialog> createState() => _RoomOrientationDialogState();
}

final class _RoomOrientationDialogState extends ConsumerState<_RoomOrientationDialog> {
  /// Whether the stream is wide enough to offer [RoomOrientation.fillWidth].
  late final bool _wideOffered = roomFillsWidth(widget.detected);

  late RoomOrientation _choice;

  @override
  void initState() {
    super.initState();
    final stored = ref.read(roomOrientationProvider(widget.room.ref.identityKey));
    // A stored fill-width choice whose stream stopped being ultra-wide (or
    // has not reported yet) reads as automatic here; the frame treats it the
    // same way, so the dialog never shows a choice it cannot offer.
    _choice = stored == RoomOrientation.fillWidth && !_wideOffered ? RoomOrientation.automatic : stored;
  }

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
          Text(_wideOffered ? t.room.orientationHintWide : t.room.orientationHint),
          DsSegmentedControl<RoomOrientation>(
            value: _choice,
            onChanged: (value) => setState(() => _choice = value),
            segments: [
              DsSegment(value: RoomOrientation.automatic, label: Text(t.room.orientationAutomatic)),
              DsSegment(value: RoomOrientation.portrait, label: Text(t.room.orientationPortrait)),
              DsSegment(value: RoomOrientation.landscape, label: Text(t.room.orientationLandscape)),
              if (_wideOffered) DsSegment(value: RoomOrientation.fillWidth, label: Text(t.room.orientationFillWidth)),
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
