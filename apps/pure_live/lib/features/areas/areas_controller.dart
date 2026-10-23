import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_sites/live_sites.dart';
import 'package:pure_live/app/providers/browse_settings_providers.dart';
import 'package:pure_live/app/providers/sites_providers.dart' show selectedSiteIdProvider, selectedSiteProvider;

/// What the areas page holds: the selected site's areas, which one is open,
/// and the rooms shown under it so far with where the next page asks.
typedef AreasState = ({
  List<LiveArea> areas,
  bool areasLoading,
  LiveSiteError? areasError,
  LiveArea? selectedArea,
  List<LiveRoom> rooms,
  int nextPage,
  bool hasMore,
  bool roomsLoading,
  LiveSiteError? roomsError,
});

AreasState _initial() => (
  areas: const [],
  areasLoading: false,
  areasError: null,
  selectedArea: null,
  rooms: const [],
  nextPage: 1,
  hasMore: true,
  roomsLoading: false,
  roomsError: null,
);

/// The areas page's state: the selected site's areas as a grid, and one
/// open area's rooms as a paged feed.
///
/// [build] watches the selected site, so switching sites drops the old
/// site's areas and rooms at once: they never linger under the new site's
/// pages. The page asks for the first areas (and every rooms page) — a
/// notifier never loads from inside its own build.
final class AreasController extends Notifier<AreasState> {
  @override
  AreasState build() {
    ref.watch(selectedSiteIdProvider);
    return _initial();
  }

  /// Loads the site's areas (the first show and every retry). A site
  /// without the area capability is no failure: the page says it has no
  /// areas.
  Future<void> loadAreas() async {
    if (state.areasLoading) return;
    state = (
      areas: state.areas,
      areasLoading: true,
      areasError: null,
      selectedArea: state.selectedArea,
      rooms: state.rooms,
      nextPage: state.nextPage,
      hasMore: state.hasMore,
      roomsLoading: state.roomsLoading,
      roomsError: state.roomsError,
    );
    final site = ref.read(selectedSiteProvider);
    final capability = site.capability<LiveAreaProvider>();
    if (capability == null) {
      state = (
        areas: const [],
        areasLoading: false,
        areasError: null,
        selectedArea: null,
        rooms: const [],
        nextPage: 1,
        hasMore: true,
        roomsLoading: false,
        roomsError: null,
      );
      return;
    }
    final answer = await capability.getAreas();
    answer.match(
      (error) => state = (
        areas: state.areas,
        areasLoading: false,
        areasError: error,
        selectedArea: state.selectedArea,
        rooms: state.rooms,
        nextPage: state.nextPage,
        hasMore: state.hasMore,
        roomsLoading: state.roomsLoading,
        roomsError: state.roomsError,
      ),
      (areas) => state = (
        areas: areas.toList(),
        areasLoading: false,
        areasError: null,
        selectedArea: state.selectedArea,
        rooms: state.rooms,
        nextPage: state.nextPage,
        hasMore: state.hasMore,
        roomsLoading: state.roomsLoading,
        roomsError: state.roomsError,
      ),
    );
  }

  /// Opens [area]: its rooms feed starts over at the first page. The rooms
  /// load is kicked from this user action, not from build.
  Future<void> selectArea(LiveArea area) async {
    state = (
      areas: state.areas,
      areasLoading: state.areasLoading,
      areasError: state.areasError,
      selectedArea: area,
      rooms: const [],
      nextPage: 1,
      hasMore: true,
      roomsLoading: false,
      roomsError: null,
    );
    await _loadRooms(area: area, page: 1);
  }

  /// Closes the open area and returns to the areas grid; the feed it held
  /// is dropped with it.
  void backToAllAreas() {
    state = (
      areas: state.areas,
      areasLoading: state.areasLoading,
      areasError: state.areasError,
      selectedArea: null,
      rooms: const [],
      nextPage: 1,
      hasMore: true,
      roomsLoading: false,
      roomsError: null,
    );
  }

  /// Loads the open area's rooms again (a retry from its error state).
  Future<void> reloadRooms() => _loadRooms(area: state.selectedArea!, page: state.rooms.isEmpty ? 1 : state.nextPage);

  /// Loads the next page of the open area's rooms when one is left.
  Future<void> loadMoreRooms() {
    if (!state.roomsLoading && state.hasMore) {
      return _loadRooms(area: state.selectedArea!, page: state.nextPage);
    }
    return Future.value();
  }

  Future<void> _loadRooms({required LiveArea area, required int page}) async {
    if (state.selectedArea != area || state.roomsLoading) return;
    state = (
      areas: state.areas,
      areasLoading: state.areasLoading,
      areasError: state.areasError,
      selectedArea: state.selectedArea,
      rooms: state.rooms,
      nextPage: state.nextPage,
      hasMore: state.hasMore,
      roomsLoading: true,
      roomsError: null,
    );
    final site = ref.read(selectedSiteProvider);
    final capability = site.capability<LiveAreaProvider>();
    if (capability == null) {
      state = (
        areas: state.areas,
        areasLoading: state.areasLoading,
        areasError: state.areasError,
        selectedArea: state.selectedArea,
        rooms: state.rooms,
        nextPage: state.nextPage,
        hasMore: false,
        roomsLoading: false,
        roomsError: LiveSiteError.unsupported(siteId: site.manifest.id, message: 'no area capability'),
      );
      return;
    }
    final answer = await capability.getAreaRooms(
      area: area,
      request: LivePageRequest.of(page: page, pageSize: ref.read(browseSettingsProvider).homePageSize),
    );
    // The open area may have changed (or closed) while the page was in
    // flight; a stale answer would splice the old area's rooms under the
    // new one's breadcrumb.
    if (state.selectedArea != area) return;
    answer.match(
      (error) => state = (
        areas: state.areas,
        areasLoading: state.areasLoading,
        areasError: state.areasError,
        selectedArea: state.selectedArea,
        rooms: state.rooms,
        nextPage: state.nextPage,
        hasMore: false,
        roomsLoading: false,
        roomsError: error,
      ),
      (pageAnswer) => state = (
        areas: state.areas,
        areasLoading: state.areasLoading,
        areasError: state.areasError,
        selectedArea: state.selectedArea,
        rooms: page == 1 ? pageAnswer.items.toList() : [...state.rooms, ...pageAnswer.items],
        nextPage: page + 1,
        hasMore: pageAnswer.hasMore ?? pageAnswer.items.isNotEmpty,
        roomsLoading: false,
        roomsError: null,
      ),
    );
  }
}

/// The areas page's state.
final areasProvider = NotifierProvider<AreasController, AreasState>(AreasController.new);
