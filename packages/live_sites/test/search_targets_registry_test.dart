import 'package:live_sites/live_sites.dart';
import 'package:test/test.dart';

/// The search page's "all" scope keeps all three targets on its switch
/// whatever the viewer has excluded, which only holds while the registry
/// keeps a declarer for each. A capability that drops its target silently
/// would leave the scope unable to serve a chip the switch still shows.
void main() {
  test('every search target keeps a declarer in the registry', () {
    final sites = createBuiltInLiveSites();
    bool offered(LiveSearchTarget target) => sites
        .where((site) => !SiteFacts.isRetired(site.manifest.id))
        .any((site) => site.capability<LiveSearchProvider>()?.supportedTargets.contains(target) ?? false);
    expect(offered(LiveSearchTarget.rooms), isTrue, reason: 'rooms has no declarer');
    expect(offered(LiveSearchTarget.anchors), isTrue, reason: 'anchors has no declarer');
    expect(offered(LiveSearchTarget.areas), isTrue, reason: 'areas has no declarer');
  });
}
