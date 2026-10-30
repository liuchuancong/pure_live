import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_storage/live_storage.dart' show StoragePrefs;

/// How the room page lays out a portrait stream (the reference's
/// `portraitLayoutMode`). [compatibility] keeps the regular 16:9 room page;
/// the other two give the picture a taller share, and [immersive] the
/// tallest.
enum PortraitLayoutMode {
  /// The picture and the chat share the page (the reference's balance).
  balanced,

  /// The picture keeps the larger share (the reference's panel starts at
  /// its lowest stop).
  immersive,

  /// The regular 16:9 room page.
  compatibility;

  /// The setting's value [name], else [balanced].
  static PortraitLayoutMode of(String? name) => values.asNameMap()[name] ?? balanced;
}

const String _layoutModeKey = 'playback.portraitLayoutMode';
const PortraitLayoutMode _defaultLayoutMode = PortraitLayoutMode.balanced;

/// Owns the narrow room's layout mode for portrait streams. The engine
/// reports the source's own ratio, so this is the only portrait preference:
/// the room page reads it when it lays a narrow room out.
final class PortraitLayoutModeController extends Notifier<PortraitLayoutMode> {
  @override
  PortraitLayoutMode build() {
    try {
      return PortraitLayoutMode.of(StoragePrefs.getString(_layoutModeKey));
    } on Object {
      return _defaultLayoutMode;
    }
  }

  /// Stores the layout mode; a stored value the choices do not know falls
  /// back to [PortraitLayoutMode.balanced].
  Future<void> set(PortraitLayoutMode mode) async {
    state = mode;
    try {
      await StoragePrefs.setString(_layoutModeKey, mode.name);
    } on Object {
      // The choice is a preference; a closed store loses it.
    }
  }

  /// Restores the balanced layout.
  Future<void> reset() => set(_defaultLayoutMode);
}

/// The narrow room's layout mode for portrait streams.
final portraitLayoutModeProvider = NotifierProvider<PortraitLayoutModeController, PortraitLayoutMode>(
  PortraitLayoutModeController.new,
);
