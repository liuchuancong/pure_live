import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_iptv/live_iptv.dart' show IptvLibrary;
import 'package:live_library/live_library.dart' show FollowRepository, HistoryRepository;
import 'package:live_net/live_net.dart' show LiveHttp;
import 'package:live_platform/live_platform.dart' show PlatformEnvironment;
import 'package:live_shell/live_shell.dart' show InstanceChannel;
import 'package:live_sites/live_sites.dart';
import 'package:live_storage/live_storage.dart' show StorageBootstrap;
import 'package:pure_live/app/composition/sites.dart';
import 'package:pure_live/app/environment/app_paths.dart';
import 'package:pure_live/app/fonts/font_library.dart';
import 'package:pure_live/app/logging/app_log.dart';
import 'package:pure_live/app/theme/appearance_preferences/appearance_preferences.dart';
import 'package:pure_live/app/theme/appearance_store.dart';
import 'package:pure_live/app/theme/ui_configuration_mapper.dart';
import 'package:pure_live/features/about/update_feed.dart';
import 'package:pure_live/features/iptv/iptv_preferences.dart';
import 'package:pure_live/features/multiview/multiview_preferences.dart';
import 'package:pure_live/platforms/desktop/shell/shell_preferences.dart' show ShellPreferencesStore, ShellWindowChrome;
import 'package:pure_uikit/pure_uikit.dart';

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

/// The desktop single-instance channel this process took at start-up — the
/// door every second launch's request arrives through — and null off the
/// desktop, where there is no instance logic. Overridden in the composition
/// root; the router subscribes to its forwarded requests (deep_link).
final desktopInstanceChannelProvider = Provider<InstanceChannel?>((ref) => null);

/// Brings the desktop window to the front, before a launch request acts on
/// it — a room opened into a hidden window is a taskbar icon that appears
/// to do nothing. The composition root overrides this with the desktop
/// entry's own show-and-focus; the default no-op covers every platform
/// without a window to raise.
final revealMainWindowProvider = Provider<Future<void> Function()>((ref) => () async {});

/// The desktop tray's receiving end: what the rest of the app tells the
/// notification-area icon when it has no other way to know. The recorder
/// reports how many rooms it still works for here, and the tray says it in
/// its menu's first row and its tooltip (the reference's A16.1 T4).
abstract interface class DesktopTrayPort {
  /// How many rooms are recording right now.
  void reportRecordingCount(int count);
}

/// The port that keeps no tray: every platform without a notification area,
/// every test, and the run where the tray refused to be created.
final class NoopDesktopTrayPort implements DesktopTrayPort {
  /// A port that drops the counts.
  const new();

  @override
  void reportRecordingCount(int count) {}
}

/// The [DesktopTrayPort]; the composition root overrides it with the desktop
/// entry, which forwards to the live tray.
final desktopTrayPortProvider = Provider<DesktopTrayPort>((ref) => const NoopDesktopTrayPort());

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

/// The process log, overridden at start-up. The log page reads the in-memory
/// ring through it and re-tunes the live tree's minimum level; nothing else
/// should hold the AppLog below the composition root.
final appLogProvider = Provider<AppLog>((ref) => throw UnimplementedError('overridden by the composition root'));

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

/// The IPTV viewer's persisted choices, overridden at start-up.
final iptvPreferencesStoreProvider = Provider<IptvPreferencesStore>(
  (ref) => throw UnimplementedError('overridden by the composition root'),
);

/// The multi-view wall's persisted layout, overridden at start-up.
final multiviewPreferencesStoreProvider = Provider<MultiviewPreferencesStore>(
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

/// The design language this process started with, plus why.
///
/// Resolved by the composition root before the first frame and overridden here
/// like every other booted fact — the store, the paths, the site registry —
/// because the value is a start-up decision and a provider that could re-derive
/// it would be a provider that could change it (§6.1 of the v4 spec).
///
/// Editing the language in settings writes the store and leaves this alone.
/// [pendingDesignLanguageProvider] is how the UI knows to ask for a restart.
final uiStartupConfigProvider = Provider<PureUiStartupConfig>(
  (ref) => throw UnimplementedError('overridden by the composition root'),
);

/// The language the store asks for that this process is not drawing with, null
/// when the two agree.
///
/// The restart-pending marker: it compares the live preference against the
/// frozen startup language rather than tracking the edit, so it survives a
/// rebuild and reads the same truth after a navigate-away and back.
final pendingDesignLanguageProvider = Provider<PureDesignLanguage?>((ref) {
  final startup = ref.watch(uiStartupConfigProvider);
  final stored = designLanguageByStoredId(ref.watch(appearancePreferencesProvider).designLanguageId);
  return stored == null || stored == startup.language ? null : stored;
});

/// The [UiConfig] the app renders with.
///
/// Derived from [appearancePreferencesProvider] for every field the user can
/// change live — brightness, accent, density, font, transparency — and from
/// [uiStartupConfigProvider] for the one they cannot: the design language picks
/// the app host, and a host is not swapped inside a running process. A
/// preference change therefore re-skins the tree without re-hosting it, and
/// nothing that watches this instead of the appearance — no playback session,
/// no danmaku connection — is rebuilt with it.
final uiConfigProvider = Provider<UiConfig>((ref) {
  final config = uiConfigFromAppearance(ref.watch(appearancePreferencesProvider));
  return config.copyWith(language: ref.watch(uiStartupConfigProvider).language);
});

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

/// The persisted IPTV viewer state (last channel, group, favourites filter),
/// the single source the IPTV pages derive their resting state from.
///
/// The store applies a change to its in-memory value before it is durable, so
/// this provider updates immediately; the write that follows never comes back
/// as a second change.
final iptvPreferencesProvider = NotifierProvider<IptvPreferencesNotifier, IptvPreferences>(IptvPreferencesNotifier.new);

/// Reads the persisted IPTV viewer state and writes every change back through
/// the store.
final class IptvPreferencesNotifier extends Notifier<IptvPreferences> {
  @override
  IptvPreferences build() {
    final store = ref.watch(iptvPreferencesStoreProvider);
    final subscription = store.changes.listen((preferences) => state = preferences);
    ref.onDispose(subscription.cancel);
    return store.value;
  }

  /// Applies [transform] to the choices; the returned future completes once
  /// the change is durable.
  Future<void> update(IptvPreferences Function(IptvPreferences preferences) transform) =>
      ref.read(iptvPreferencesStoreProvider).update(transform);
}

/// The persisted multi-view layout, the single source the wall derives its
/// grid from.
final multiviewPreferencesProvider = NotifierProvider<MultiviewPreferencesNotifier, MultiviewPreferences>(
  MultiviewPreferencesNotifier.new,
);

/// Reads the persisted multi-view layout and writes every change back through
/// the store.
final class MultiviewPreferencesNotifier extends Notifier<MultiviewPreferences> {
  @override
  MultiviewPreferences build() {
    final store = ref.watch(multiviewPreferencesStoreProvider);
    final subscription = store.changes.listen((preferences) => state = preferences);
    ref.onDispose(subscription.cancel);
    return store.value;
  }

  /// Applies [transform] to the choices; the returned future completes once
  /// the change is durable.
  Future<void> update(MultiviewPreferences Function(MultiviewPreferences preferences) transform) =>
      ref.read(multiviewPreferencesStoreProvider).update(transform);
}
