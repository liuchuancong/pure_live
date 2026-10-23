import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_sites/live_sites.dart';

/// The registry of every built-in site, built once per process.
///
/// The sites own no credentials or settings yet; the composition root of
/// `live_sites` (its `createBuiltInLiveSites`) wires what it can by itself
/// and its seams (douyu login renewal, the twitch language filter, huya's
/// H.264 preference) are handed in when the settings store learns to keep
/// them.
final sitesProvider = Provider<LiveSiteRegistry>((ref) {
  return LiveSiteRegistry(createBuiltInLiveSites());
});

/// The site the browsing surfaces (the home feed, the areas, the search)
/// read; one at a time, switched from the home page's site picker.
///
/// The default is douyu — the biggest catalog that needs no login. The id
/// persists with the settings store once the app wires it.
final class SelectedSiteController extends Notifier<String> {
  @override
  String build() => 'douyu';

  /// The site the browsing surfaces read.
  String get selected => state;

  /// Moves the selection; a switch keeps each surface's pages fresh.
  set selected(String siteId) => state = siteId;
}

/// The selected site's id.
final selectedSiteIdProvider = NotifierProvider<SelectedSiteController, String>(SelectedSiteController.new);

/// The selected site itself.
final selectedSiteProvider = Provider<LiveSite>((ref) {
  final id = ref.watch(selectedSiteIdProvider);
  return ref.watch(sitesProvider).getById(id) ?? ref.watch(sitesProvider).all.first;
});
