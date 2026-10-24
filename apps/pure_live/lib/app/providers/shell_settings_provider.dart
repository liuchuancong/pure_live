import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_shell/live_shell.dart' show CloseAction;
import 'package:live_storage/live_storage.dart';

/// The window's own choices (the reference's general settings): what the
/// close button means. The tray itself is not wired yet, so the tray
/// choice is not offered — the honest two stand here.
typedef ShellWindowSettings = ({CloseAction closeAction});

const ShellWindowSettings _defaults = (closeAction: CloseAction.quit);

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
      );
    } on Object {
      return _defaults;
    }
  }

  /// Moves the close behaviour, writing through.
  Future<void> setCloseAction(CloseAction action) async {
    state = (closeAction: action);
    try {
      await StoragePrefs.setString('shell.closeAction', action.name);
    } on Object {
      // The choice is a preference; a closed store loses it.
    }
  }
}

/// The window's own choices.
final shellWindowSettingsProvider = NotifierProvider<ShellWindowSettingsController, ShellWindowSettings>(
  ShellWindowSettingsController.new,
);
