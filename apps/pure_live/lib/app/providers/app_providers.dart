import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_platform/live_platform.dart' show PlatformEnvironment;
import 'package:live_sites/live_sites.dart' show LiveDiscoveryProvider;
import 'package:live_storage/live_storage.dart' show StorageBootstrap;
import 'package:live_uikit/styling.dart';

import 'package:pure_live/app/composition/sites.dart';
import 'package:pure_live/app/environment/app_paths.dart';
import 'package:pure_live/app/theme/appearance_preferences/appearance_preferences.dart';
import 'package:pure_live/app/theme/appearance_store.dart';
import 'package:pure_live/app/theme/ui_configuration_mapper.dart';

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
// The riverpod family type has no exported name to annotate with.
// ignore: specify_nonobvious_property_types
final discoveryProvider = Provider.family<LiveDiscoveryProvider?, String>(
  // The family's raw create signature loses the argument type.
  // ignore: avoid_types_on_closure_parameters
  (ref, String siteId) => ref.watch(sitesProvider).registry.getById(siteId)?.capability<LiveDiscoveryProvider>(),
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
