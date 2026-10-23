import 'dart:async' show StreamSubscription, unawaited;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_shell/live_shell.dart' show WindowEvent, WindowHost;

export 'environment/app_environment.dart' show platformKindProvider, platformRuntimeProvider;

/// The main window's host, or null where the form factor has no window
/// (a phone, a tablet, a TV). The desktop caption controls and the title
/// bar route every window verb through this; only the bootstrap can build
/// one, so `main` overrides this.
final windowHostProvider = Provider<WindowHost?>((_) => null);

/// The host, non-null: only the desktop shell reads this, and a desktop run
/// always boots with one.
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
/// The initial answer comes from the host; the stream keeps it true without
/// rebuilding anything beneath the caption, which is the whole reason this
/// is a notifier over events rather than a query.
final maximizedProvider = NotifierProvider<MaximizedController, bool>(MaximizedController.new);

/// Tracks the window's maximised state so the caption can swap its glyph.
final class MaximizedController extends Notifier<bool> {
  @override
  bool build() {
    final host = ref.watch(desktopWindowHostProvider);
    StreamSubscription<WindowEvent>? subscription;
    ref.onDispose(() => subscription?.cancel());
    unawaited(
      host.isMaximized().then((value) {
        if (ref.mounted) {
          state = value;
        }
      }),
    );
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
}
