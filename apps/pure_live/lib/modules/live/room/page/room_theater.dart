import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Whether the wide room gives its picture the whole stage and floats the
/// chat over it as a glass column.
///
/// A view preference, not a saved setting: the theatre belongs to the window
/// the viewer is in, so the next room in the same session opens in the ordinary
/// split again. The player bar's window cluster toggles it, and `T` does the
/// same from the keyboard.
final roomTheaterProvider = NotifierProvider<RoomTheaterController, bool>(RoomTheaterController.new);

/// Owns [roomTheaterProvider].
final class RoomTheaterController extends Notifier<bool> {
  @override
  bool build() => false;

  /// Shows or hides the theatre; answers the state it settled on.
  bool set({required bool value}) => state = value;

  /// Flips the theatre; answers the new state.
  bool toggle() => state = !state;
}
