import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_iptv/live_iptv.dart' show IptvLibrary;
import 'package:live_library/live_library.dart' show FollowRepository, HistoryRepository;
import 'package:live_net/live_net.dart' show LiveHttp;
import 'package:live_platform/live_platform.dart' show PlatformEnvironment;
import 'package:live_sites/live_sites.dart'
    show LiveAreaProvider, LiveDiscoveryProvider, LivePlaybackProvider, LiveRoomProvider, LiveSearchProvider;
import 'package:live_storage/live_storage.dart' show StorageBootstrap;
import 'package:live_uikit/styling.dart';
import 'package:pure_live/app/composition/sites.dart';
import 'package:pure_live/app/environment/app_paths.dart';
import 'package:pure_live/app/fonts/font_library.dart';
import 'package:pure_live/app/theme/appearance_preferences/appearance_preferences.dart';
import 'package:pure_live/app/theme/appearance_store.dart';
import 'package:pure_live/app/theme/ui_configuration_mapper.dart';
import 'package:pure_live/features/about/update_feed.dart';
import 'package:pure_live/platforms/desktop/shell/shell_preferences.dart' show ShellPreferencesStore, ShellWindowChrome;

/// The booted [AppearanceStore], overridden in the `ProviderScope` at
/// start-up — the store owns an open box, so nothing here can invent one.
final appearanceStoreProvider = Provider<AppearanceStore>(
  (ref) => throw UnimplementedError('overridden by the composition root'),
);

/// The booted platform facts, overridden at start-up — the snapshot exists
/// before the first frame and nothing below the scope re-probes the system.
final environmentProvider = Provider<PlatformEnvironment>(
  (ref) => throw UnimplementedError('overridden by the composition root'),
);

/// The booted directory layout, overridden at start-up. Every area the app
/// resolves goes through it, user-moved directories included; nothing
/// assembles a storage path of its own.
final pathsProvider = Provider<AppPaths>((ref) => throw UnimplementedError('overridden by the composition root'));

/// The booted shell preferences (title-bar mode, remembered close action),
/// overridden at start-up; null off the desktop, where no shell exists.
final shellPreferencesProvider = Provider<ShellPreferencesStore?>((ref) => null);

/// The title-bar mode this start was launched with.
///
/// Read from the store once: the native frame helper behind the self-drawn
/// strip is configured before the window exists and has no runtime toggle,
/// so a settings change lands on the next start instead of re-dressing a
/// live window whose frame says something else.
final windowChromeProvider = Provider<ShellWindowChrome>(
  (ref) => ref.watch(shellPreferencesProvider)?.value.windowChrome ?? ShellWindowChrome.app,
);

/// The opened storage layer, overridden at start-up. Boxes open through it,
/// never through a fresh bootstrap — a second open of the same box would
/// fight the first over the file lock.
final storageProvider = Provider<StorageBootstrap>(
  (ref) => throw UnimplementedError('overridden by the composition root'),
);

/// The network and site graph, overridden at start-up — the sites are
/// initialized before the first frame and never re-created.
final sitesProvider = Provider<AppSites>((ref) => throw UnimplementedError('overridden by the composition root'));

/// The discovery capability of a site id, null when the site does not
/// expose one. The registry is static after boot, so a family entry never
/// changes.
// riverpod's family type (ProviderFamily) is not exported by
// flutter_riverpod, so the variable annotation the lint asks for cannot
// be written.
// ignore: specify_nonobvious_property_types
final discoveryProvider = Provider.family<LiveDiscoveryProvider?, String>(_discoveryOf);

LiveDiscoveryProvider? _discoveryOf(Ref ref, String siteId) =>
    ref.watch(sitesProvider).registry.getById(siteId)?.capability<LiveDiscoveryProvider>();

/// The area capability of a site id, null when the site does not expose
/// one. The registry is static after boot, so a family entry never
/// changes.
// ignore: specify_nonobvious_property_types
final areaProvider = Provider.family<LiveAreaProvider?, String>(_areasOf);

LiveAreaProvider? _areasOf(Ref ref, String siteId) =>
    ref.watch(sitesProvider).registry.getById(siteId)?.capability<LiveAreaProvider>();

/// The search capability of a site id, null when the site does not expose
/// one. The registry is static after boot, so a family entry never changes.
// ignore: specify_nonobvious_property_types
final searchProvider = Provider.family<LiveSearchProvider?, String>(_searchOf);

LiveSearchProvider? _searchOf(Ref ref, String siteId) =>
    ref.watch(sitesProvider).registry.getById(siteId)?.capability<LiveSearchProvider>();

/// The room lookup capability of a site id, null when the site does not
/// expose one.
// ignore: specify_nonobvious_property_types
final roomProvider = Provider.family<LiveRoomProvider?, String>(_roomsOf);

LiveRoomProvider? _roomsOf(Ref ref, String siteId) =>
    ref.watch(sitesProvider).registry.getById(siteId)?.capability<LiveRoomProvider>();

/// The playback capability of a site id, null when the site does not
/// expose one.
// ignore: specify_nonobvious_property_types
final playbackProvider = Provider.family<LivePlaybackProvider?, String>(_playbackOf);

LivePlaybackProvider? _playbackOf(Ref ref, String siteId) =>
    ref.watch(sitesProvider).registry.getById(siteId)?.capability<LivePlaybackProvider>();

/// The app's shared HTTP client (the site graph's own transport).
final httpProvider = Provider<LiveHttp>((ref) => ref.watch(sitesProvider).http);

/// The update feed over the shared client.
final updateFeedProvider = Provider<UpdateFeed>((ref) => UpdateFeed(http: ref.watch(httpProvider)));

/// The user's followed rooms and groups, overridden at start-up.
final followRepositoryProvider = Provider<FollowRepository>(
  (ref) => throw UnimplementedError('overridden by the composition root'),
);

/// The user's watch history, overridden at start-up.
final historyRepositoryProvider = Provider<HistoryRepository>(
  (ref) => throw UnimplementedError('overridden by the composition root'),
);

/// The IPTV library (imported playlists and channels), overridden at
/// start-up.
final iptvLibraryProvider = Provider<IptvLibrary>(
  (ref) => throw UnimplementedError('overridden by the composition root'),
);

/// The cloud font library, overridden at start-up.
final fontLibraryProvider = Provider<FontLibrary>(
  (ref) => throw UnimplementedError('overridden by the composition root'),
);

/// The persisted appearance, the single source the theme is derived from.
///
/// The store applies a change to its in-memory value before it is durable, so
/// this provider re-skins immediately; the write that follows never comes back
/// as a second change.
final appearancePreferencesProvider = NotifierProvider<AppearancePreferencesNotifier, AppearancePreferences>(
  AppearancePreferencesNotifier.new,
);

/// The [UiConfig] the app renders with.
///
/// Derived from [appearancePreferencesProvider] alone: a preference change
/// rebuilds the theme and the widgets under it, and nothing that watches this
/// instead of the appearance — no playback session, no danmaku connection — is
/// rebuilt with it.
final uiConfigProvider = Provider<UiConfig>((ref) => uiConfigFromAppearance(ref.watch(appearancePreferencesProvider)));

/// Reads the persisted appearance and writes every change back through the
/// store.
final class AppearancePreferencesNotifier extends Notifier<AppearancePreferences> {
  @override
  AppearancePreferences build() {
    final store = ref.watch(appearanceStoreProvider);
    final subscription = store.changes.listen((appearance) => state = appearance);
    ref.onDispose(subscription.cancel);
    return store.value;
  }

  /// Applies [transform] to the appearance; the returned future completes once
  /// the change is durable.
  Future<void> update(AppearancePreferences Function(AppearancePreferences appearance) transform) =>
      ref.read(appearanceStoreProvider).update(transform);

  /// Restores the shipping appearance and removes the stored document.
  Future<void> reset() => ref.read(appearanceStoreProvider).reset();
}
