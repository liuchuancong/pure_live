import 'package:live_sites/live_sites.dart';

/// The user's platform order laid over the registry's roster — the stored ids
/// first, in the stored order, then any site the order does not name in
/// registry order.
///
/// Every surface that lists platforms (popular, areas, search and the
/// settings page that edits the order itself) shows the same sequence, so
/// the one answer lives here rather than on any one page.
List<LiveSite> orderedSites(List<LiveSite> sites, List<String> order) {
  if (order.isEmpty) return sites;
  final remaining = {for (final site in sites) site.manifest.id: site};
  final result = <LiveSite>[];
  for (final id in order) {
    final site = remaining.remove(id);
    if (site != null) result.add(site);
  }
  result.addAll(remaining.values);
  return result;
}
