import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_sites/live_sites.dart';
import 'package:pure_live/shared/shared.dart' show kAllPlatforms;

/// The follows page's own choices: the group tab and the platform tab.
///
/// They live above the page because the phone's top bar offers the platform
/// menu and the refresh; the bar has to know which platform the page is on
/// and which one a pick should show.
typedef FavoritesView = ({LiveFollowGroup? group, String platform});

/// The follows view, shared by the page and the phone's top bar.
final class FavoritesViewController extends Notifier<FavoritesView> {
  @override
  FavoritesView build() => (group: null, platform: kAllPlatforms);

  /// Shows [group]; a new group is a new slice of the follows.
  void selectGroup(LiveFollowGroup? group) {
    if (state.group == group) return;
    state = (group: group, platform: state.platform);
  }

  /// Shows [platform]; a new platform is a new slice of the follows.
  void selectPlatform(String platform) {
    if (state.platform == platform) return;
    state = (group: state.group, platform: platform);
  }
}

/// The follows page's group and platform, as the page and the bar read them.
final favoritesViewProvider = NotifierProvider<FavoritesViewController, FavoritesView>(
  FavoritesViewController.new,
);
