import 'dart:async' show unawaited;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_sites/live_sites.dart';
import 'package:live_storage/live_storage.dart';
import 'package:pure_live/app/app.dart';
import 'package:pure_live/features/settings/settings.dart';

/// What one platform's areas catalogue holds: the areas and their load.
typedef PlatformAreasState = ({List<LiveArea> areas, bool loading, LiveSiteError? error});

PlatformAreasState _initial() => (areas: const [], loading: false, error: null);

/// The areas page's catalogues: one per platform (the reference's
/// `AreaCatalog`), each loaded when its tab is first shown and kept while
/// the app runs — switching tabs never refetches.
///
/// The page asks; a notifier never loads from inside its own build.
final class AreasCatalogController extends Notifier<Map<String, PlatformAreasState>> {
  @override
  Map<String, PlatformAreasState> build() => const {};

  /// The ids of the platforms that have areas, in registry order.
  List<String> platformIds() {
    final display = ref.read(sitesDisplayProvider.notifier);
    // The viewer's order is the menu's order: a drag in the settings
    // reorders these tabs too.
    final order = ref.read(sitesOrderProvider).order;
    final sites = {for (final site in ref.read(sitesProvider).all) site.manifest.id: site};
    return [
      for (final id in order)
        if (sites[id] case final site? when site.capability<LiveAreaProvider>() != null && display.shown(id)) id,
    ];
  }

  /// The catalogue of [platform], made on first ask.
  PlatformAreasState catalogOf(String platform) => state[platform] ?? _initial();

  /// Loads [platform]'s areas when its catalogue is still empty and idle.
  /// A site with no areas of its own keeps an honest empty catalogue.
  Future<void> open(String platform) async {
    final catalog = catalogOf(platform);
    if (catalog.areas.isNotEmpty || catalog.loading) return;
    await _load(platform);
  }

  /// Loads [platform]'s areas again (a retry from its error state).
  Future<void> refresh(String platform) => _load(platform);

  /// Loads [platform]'s catalogue in the background while the viewer is
  /// still on another tab, so switching arrives to a ready grid.
  Future<void> warm(String platform) async {
    final catalog = catalogOf(platform);
    if (catalog.areas.isEmpty && !catalog.loading) await _load(platform);
  }

  Future<void> _load(String platform) async {
    final current = catalogOf(platform);
    if (current.loading) return;
    state = {...state, platform: (areas: current.areas, loading: true, error: null)};
    final capability = ref.read(sitesProvider).getById(platform)?.capability<LiveAreaProvider>();
    if (capability == null) {
      state = {...state, platform: (areas: const [], loading: false, error: null)};
      return;
    }
    final answer = await capability.getAreas();
    final open = state[platform];
    if (open == null) return;
    answer.match(
      (error) => state = {...state, platform: (areas: open.areas, loading: false, error: error)},
      (areas) => state = {...state, platform: (areas: areas.toList(), loading: false, error: null)},
    );
  }
}

/// The areas page's per-platform catalogues.
final areasCatalogProvider = NotifierProvider<AreasCatalogController, Map<String, PlatformAreasState>>(
  AreasCatalogController.new,
);

/// The areas page's shown platform, remembered under `browse.areas.site`.
final class AreasSiteController extends Notifier<String> {
  @override
  String build() {
    final stored = _readStored();
    final ids = ref.read(areasCatalogProvider.notifier).platformIds();
    if (stored != null && ids.contains(stored)) return stored;
    // No local choice yet: the settings' preferred platform opens first.
    final preferred = ref.read(sitesOrderProvider).preferred;
    if (preferred.isNotEmpty && ids.contains(preferred)) return preferred;
    return ids.isEmpty ? '' : ids.first;
  }

  static String? _readStored() {
    try {
      return StoragePrefs.getString('browse.areas.site');
    } on Object {
      return null;
    }
  }

  /// The shown platform.
  String get selected => state;

  /// Moves the shown platform, writing the choice through.
  set selected(String id) {
    state = id;
    unawaited(StoragePrefs.setString('browse.areas.site', id));
  }
}

/// The areas page's shown platform.
final areasSiteProvider = NotifierProvider<AreasSiteController, String>(AreasSiteController.new);
