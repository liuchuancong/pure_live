import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_shell/live_shell.dart' show CloseAction;
import 'package:live_storage/live_storage.dart';

/// The window's own choices (the reference's general settings): what the
/// close button means. The tray is wired at the bootstrap, so every choice
/// here is live; the shell re-reads the stored value on each close press.
typedef ShellWindowSettings = ({CloseAction closeAction, bool dontAskExit});

const ShellWindowSettings _defaults = (closeAction: CloseAction.quit, dontAskExit: false);

/// Owns the window settings, persisted under `shell.*`; the bootstrap's
/// close handler reads the choice fresh on every press.
final class ShellWindowSettingsController extends Notifier<ShellWindowSettings> {
  @override
  ShellWindowSettings build() {
    try {
      return (
        closeAction: switch (StoragePrefs.getString('shell.closeAction')) {
          'minimise' => CloseAction.minimise,
          'hideToTray' => CloseAction.hideToTray,
          'quit' => CloseAction.quit,
          _ => _defaults.closeAction,
        },
        dontAskExit: StoragePrefs.getBool('shell.dontAskExit') ?? _defaults.dontAskExit,
      );
    } on Object {
      return _defaults;
    }
  }

  /// Moves the close behaviour, writing through.
  Future<void> setCloseAction(CloseAction action) async {
    state = (closeAction: action, dontAskExit: state.dontAskExit);
    try {
      await StoragePrefs.setString('shell.closeAction', action.name);
    } on Object {
      // The choice is a preference; a closed store loses it.
    }
  }

  /// Moves the confirmation behaviour, writing through.
  Future<void> setDontAskExit({required bool value}) async {
    state = (closeAction: state.closeAction, dontAskExit: value);
    try {
      await StoragePrefs.setBool('shell.dontAskExit', value);
    } on Object {
      // The choice is a preference; a closed store loses it.
    }
  }

  /// Stores the close dialog's answer: the action it picked and whether the
  /// viewer asked not to see it again.
  Future<void> rememberCloseChoice({required CloseAction action, required bool dontAskAgain}) async {
    state = (closeAction: action, dontAskExit: dontAskAgain);
    try {
      await StoragePrefs.setString('shell.closeAction', action.name);
      await StoragePrefs.setBool('shell.dontAskExit', dontAskAgain);
    } on Object {
      // The choice is a preference; a closed store loses it.
    }
  }
}

/// The window's own choices.
final shellWindowSettingsProvider = NotifierProvider<ShellWindowSettingsController, ShellWindowSettings>(
  ShellWindowSettingsController.new,
);

/// Whether opening a room puts it in its own window (the desktop's
/// QQ-style rooms) or pushes it in-app. A room window is a second engine
/// with its own player, so the choice stays with the viewer.
final class RoomWindowsController extends Notifier<bool> {
  @override
  bool build() {
    try {
      return StoragePrefs.getBool('shell.roomWindows') ?? true;
    } on Object {
      return true;
    }
  }

  /// Moves the choice, writing through.
  Future<void> setEnabled({required bool value}) async {
    state = value;
    try {
      await StoragePrefs.setBool('shell.roomWindows', value);
    } on Object {
      // The choice is a preference; a closed store loses it.
    }
  }
}

/// Whether rooms open in their own windows.
final roomWindowsProvider = NotifierProvider<RoomWindowsController, bool>(RoomWindowsController.new);
