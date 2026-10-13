import 'package:live_sites/src/core/live_site.dart';

/// A simple in-process collection of built-in site instances, keyed by their
/// stable [LiveSite.manifest] id.
///
/// It is not a plugin manager: it does not discover Dart files, load code from
/// the network, or install platforms. The application composition root builds
/// the instances and hands them here; this owns only identity indexing and
/// bulk lifecycle forwarding.
final class LiveSiteRegistry {
  /// Indexes [sites] by id, rejecting duplicate ids.
  new(Iterable<LiveSite> sites) {
    for (final site in sites) {
      final id = site.manifest.id;
      if (_sites.containsKey(id)) {
        throw ArgumentError.value(id, 'sites', 'Duplicate live site ID.');
      }
      _sites[id] = site;
    }
  }

  final Map<String, LiveSite> _sites = {};

  /// The site registered under [id], or null when none is.
  LiveSite? getById(String id) => _sites[id];

  /// Every registered site, in insertion order.
  List<LiveSite> get all => List.unmodifiable(_sites.values);

  /// Disposes every registered site, forwarding the first failure to the
  /// caller after all have been asked. Ownership of the instances stays with
  /// the composition root that constructed them.
  Future<void> disposeAll() async {
    Object? failure;
    for (final site in _sites.values) {
      try {
        await site.dispose();
      } on Object catch (error) {
        failure ??= error;
      }
    }
    if (failure != null) {
      throw StateError('A live site failed to dispose: $failure');
    }
  }
}
