import 'package:live_sites/src/core/live_site.dart';

// Constructors spell their class name by convention here; the `.new`
// shorthand hurts readability more than the lint helps.
// ignore_for_file: unnecessary_type_name_in_constructor

/// An in-process collection of the built-in site instances.
///
/// A plain map with a duplicate guard — not a plugin manager: no dynamic
/// loading, no network code, no permission handling, and initialization
/// errors are never swallowed here. The application composition root
/// constructs the sites and hands them in.
final class LiveSiteRegistry {
  /// Registers [sites]; two sites with the same manifest id are a
  /// programmer error and fail fast.
  LiveSiteRegistry(Iterable<LiveSite> sites) {
    for (final site in sites) {
      final id = site.manifest.id;
      if (_sites.containsKey(id)) {
        throw ArgumentError.value(id, 'sites', 'Duplicate live site ID.');
      }
      _sites[id] = site;
    }
  }

  final Map<String, LiveSite> _sites = {};

  /// The site with [id], or null.
  LiveSite? getById(String id) => _sites[id];

  /// Every registered site, in registration order.
  List<LiveSite> get all => List.unmodifiable(_sites.values);
}
