import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Bumped whenever settings changed in another window.
///
/// The root re-reads the theme and the pinned language; setting controllers
/// watch this value so their cached state is rebuilt from the store after
/// the clone's projection applied the change.
final settingsRevisionProvider = NotifierProvider<SettingsRevisionController, int>(SettingsRevisionController.new);

/// The revision a window is on.
final class SettingsRevisionController extends Notifier<int> {
  @override
  int build() => 0;

  /// Marks another window's setting change as applied.
  void bump() => state++;
}
