import 'dart:async' show unawaited;

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The favorites page's own refresh, offered to the shell's top bar: the page
/// hands its visible-slice refresh in, the bar presses it on the viewer's
/// behalf. Null while the page is away, and the button using it then has
/// nothing to press.
final followsPageRefreshProvider = NotifierProvider<FavoritesPageRefresh, void Function()?>(FavoritesPageRefresh.new);

/// The handoff's state holder.
final class FavoritesPageRefresh extends Notifier<void Function()?> {
  @override
  void Function()? build() => null;

  /// The page publishes itself after the first frame; a stale closure is
  /// harmless — it checks its own mounted state first. The clear comes from
  /// the page's dispose, inside the tree's finalization where a provider
  /// may not be written: the write waits for the frame's end, and runs
  /// before any post-frame publish, so a page arriving as one leaves cannot
  /// have its hook cleared by the page that left.
  void Function()? get handler => state;
  set handler(void Function()? value) => unawaited(
    Future<void>.microtask(() {
      // The clear is asked from the page's dispose and the publish from a
      // post frame; a window closing in between has torn the provider down
      // before either lands, and a disposed notifier takes no state.
      if (!ref.mounted) return;
      state = value;
    }),
  );

  /// Runs the page's refresh when there is one.
  void run() => state?.call();
}
