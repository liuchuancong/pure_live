import 'dart:async' show StreamSubscription, unawaited;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_sites/live_sites.dart';
import 'package:live_storage/live_storage.dart';

/// The areas the viewer follows, one entry per `platform:areaId`.
///
/// The entry stores the fields the card and the rooms page need — the
/// area's identity, names and icon — as the JSON of a hand-rolled map:
/// `LiveArea` itself has no `toJson`, and the follow outlives any one
/// adapter's exact model shape.
final class AreaFollowRepository {
  /// Serves the [box] (opened as `area_follows`, its values the stored
  /// maps above).
  AreaFollowRepository(this.box);

  /// The follows box: identity key → the area's stored fields.
  final HiveStorageRepository<Object> box;

  /// Emits after every committed change.
  Stream<void> watch() => box.watch();

  /// The followed areas, in storage order (insertion).
  List<LiveArea> list() {
    return [
      for (final value in box.getAll())
        if (value is Map) _areaOf(Map<String, Object?>.from(value)),
    ];
  }

  /// Whether the area behind [identityKey] is followed.
  bool contains(String identityKey) => box.contains(identityKey);

  /// Follows [area]; an existing entry for its identity is replaced whole.
  Future<void> add(LiveArea area) => box.save(area.identityKey, _mapOf(area));

  /// Unfollows the area behind [identityKey]; a never-followed area is a
  /// no-op.
  Future<void> remove(String identityKey) => box.delete(identityKey);

  /// Toggles [area]; answers whether it is followed afterwards.
  Future<bool> toggle(LiveArea area) async {
    if (contains(area.identityKey)) {
      await remove(area.identityKey);
      return false;
    }
    await add(area);
    return true;
  }

  LiveArea _areaOf(Map<String, Object?> json) => LiveArea.normalized(
    platform: json['platform'] as String? ?? '',
    areaId: json['areaId'] as String? ?? '',
    areaName: json['areaName'] as String? ?? '',
    parentAreaName: json['parentAreaName'] as String?,
    iconUrl: json['iconUrl'] as String?,
  );

  Map<String, Object?> _mapOf(LiveArea area) => {
    'platform': area.platform,
    'areaId': area.areaId,
    'areaName': area.areaName,
    if (area.parentAreaName != null) 'parentAreaName': area.parentAreaName,
    if (area.iconUrl != null) 'iconUrl': area.iconUrl,
  };
}

/// The area-follows repository (one box, one process).
final areaFollowRepositoryProvider = FutureProvider<AreaFollowRepository>((ref) async {
  final box = await StorageBoxManager().keyed<Object>('area_follows');
  return AreaFollowRepository(HiveStorageRepository(box: box));
});

/// What the followed-areas view holds: the followed areas and whether the
/// repository has opened yet.
typedef FollowedAreasState = ({bool ready, List<LiveArea> areas});

/// Mirrors the area-follows repository into the widget tree, so a follow
/// made on the areas page or the rooms page lands everywhere at once.
final class FollowedAreasController extends Notifier<FollowedAreasState> {
  StreamSubscription<void>? _subscription;

  @override
  FollowedAreasState build() {
    ref.watch(areaFollowRepositoryProvider).whenData((repository) {
      _subscription ??= repository.watch().listen((_) => _refresh(repository));
      _refresh(repository);
    });
    ref.onDispose(() => unawaited(_subscription?.cancel() ?? Future<void>.value()));
    return (ready: false, areas: const []);
  }

  void _refresh(AreaFollowRepository repository) {
    if (!ref.mounted) return;
    state = (ready: true, areas: repository.list());
  }

  /// Unfollows the area behind [identityKey].
  Future<void> remove(String identityKey) async {
    final repository = ref.read(areaFollowRepositoryProvider).value;
    if (repository != null) await repository.remove(identityKey);
  }
}

/// The followed areas.
final followedAreasProvider = NotifierProvider<FollowedAreasController, FollowedAreasState>(
  FollowedAreasController.new,
);
