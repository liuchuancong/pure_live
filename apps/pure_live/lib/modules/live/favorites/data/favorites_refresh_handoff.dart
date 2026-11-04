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
  /// harmless — it checks its own mounted state first.
  void Function()? get handler => state;
  set handler(void Function()? value) => state = value;

  /// Runs the page's refresh when there is one.
  void run() => state?.call();
}
