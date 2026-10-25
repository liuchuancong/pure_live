import 'dart:async' show StreamSubscription, unawaited;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_shell/live_shell.dart' show SecondaryWindows, WindowEvent, WindowHost;

/// The windows this window opened (room/whole-app clones). Only the
/// bootstrap builds the primary's set; every clone boot builds its own.
final secondaryWindowsProvider = Provider<SecondaryWindows?>((ref) => null);

/// Whether this engine is the primary window. The primary owns SQLite,
/// the tray and the quit path; a clone only projects the data.
final isPrimaryWindowProvider = Provider<bool>((ref) => true);

/// Closes this engine's window when the shell asks it to go away. Null in
/// the primary, where the shell's own window host owns the verb.
final windowCloseProvider = Provider<Future<void> Function()?>((ref) => null);

/// The clone's own top-level native window handle, where the platform has
/// one (Windows); null in the primary and on window systems without handles.
///
/// The fullscreen and PiP backends pin this handle: their process-wide
/// lookup finds the runner's first window, so without it a clone would take
/// the primary fullscreen or shrink the primary into the corner.
final presentationWindowHandleProvider = Provider<int?>((ref) => null);

/// The clone → primary call, armed by the clone boot. Null in the primary,
/// where the data is local and there is no other engine to ask.
final windowInvokePrimaryProvider = Provider<Future<Object?> Function(String method, [Object? arguments])?>(
  (ref) => null,
);

/// This engine's window id, armed by the clone boot. Null in the primary,
/// which is identified by its role instead.
final windowIdProvider = Provider<String?>((ref) => null);

/// The main window's host, or null where the form factor has no window
/// (a phone, a tablet, a TV). The desktop caption and every window verb
/// route through this; only the bootstrap can build one, so `main`
/// overrides this.
final windowHostProvider = Provider<WindowHost?>((_) => null);

/// The host, non-null: only the desktop shell reads this, and a desktop
/// run always boots with one.
final desktopWindowHostProvider = Provider<WindowHost>((ref) {
  final host = ref.watch(windowHostProvider);
  if (host == null) {
    throw StateError('the desktop shell needs a window host');
  }
  return host;
});

/// Whether the window is currently maximised — the caption's glyph and the
/// title bar's double-tap read this.
///
/// The initial answer comes from the host; the event stream keeps it true
/// without rebuilding anything beneath the caption.
final maximizedProvider = NotifierProvider<MaximizedController, bool>(MaximizedController.new);

/// Tracks the window's maximised state so the caption can swap its glyph.
final class MaximizedController extends Notifier<bool> {
  @override
  bool build() {
    final host = ref.watch(desktopWindowHostProvider);
    StreamSubscription<WindowEvent>? subscription;
    ref.onDispose(() => subscription?.cancel());
    // The native window registers itself shortly after Dart starts, so the
    // first read can land in the registration gap and answer the default.
    // A short poll re-asks until the answer is the window's own; the event
    // stream keeps it true from there.
    unawaited(_settle(host));
    subscription = host.events.listen((event) {
      if (!ref.mounted) {
        return;
      }
      if (event == WindowEvent.maximised) {
        state = true;
      } else if (event == WindowEvent.restored || event == WindowEvent.unmaximised) {
        state = false;
      }
    });
    return false;
  }

  Future<void> _settle(WindowHost host) async {
    for (var attempt = 0; attempt < 10; attempt++) {
      await Future<void>.delayed(const Duration(milliseconds: 100));
      if (!ref.mounted) {
        return;
      }
      state = await host.isMaximized();
    }
  }
}
