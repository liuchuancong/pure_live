import 'package:flutter/foundation.dart' show TargetPlatform, defaultTargetPlatform, kIsWeb;
import 'package:pip_kit/pip_kit.dart' show PipController;

/// The phone picture-in-picture the system owns (iOS), as opposed to the
/// compact window this app lays out on a desktop.
///
/// The distinction matters to every surface that reacts to
/// `PresentationMode.pip`: the desktop compact window *is* the app's window,
/// so the page lays out the bare picture there; on a phone the system window
/// floats above an app that keeps the page it had.
bool get isSystemPipHost => !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

/// Closes the system's picture-in-picture window.
///
/// media_core_pip treats an exit request on a phone as a no-op — it cannot
/// claim a window the app does not size — but the app still needs the verb:
/// its own button, and returning to the foreground, both mean "bring the
/// picture back into the app". The window is the media_core_pip iOS path's
/// own (pip_kit), so waking it up here is the same window the driver opened;
/// the driver learns about the close through pip_kit's status stream.
Future<void> exitSystemPip() async {
  if (!isSystemPipHost) return;
  try {
    await PipController.instance.exit();
  } on Object {
    // Not armed, already closed, or the engine is going away: nothing left
    // to close.
  }
}
