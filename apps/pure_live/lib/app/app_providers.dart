import 'dart:async' show StreamSubscription, unawaited;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_shell/live_shell.dart' show WindowEvent, WindowHost;

import 'package:pure_live/app/app_services.dart' show AppServices;
import 'package:pure_live/app/composition/app_sites.dart' show AppSites;
import 'package:pure_live/app/configuration/app_preferences.dart' show AppearanceStore;
export 'package:pure_live/app/environment/app_environment.dart' show platformKindProvider, platformRuntimeProvider;

/// The wired service graph; only the bootstrap can produce one, so `main`
/// overrides this.
final appServicesProvider = Provider<AppServices>(
  (ref) => throw UnimplementedError('appServicesProvider must be overridden at boot'),
);

/// The persisted appearance document (theme mode, accent, language).
final appearanceStoreProvider = Provider<AppearanceStore>((ref) => ref.watch(appServicesProvider).appearance);

/// The network and site graph.
final sitesProvider = Provider<AppSites>((ref) => ref.watch(appServicesProvider).sites);

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
