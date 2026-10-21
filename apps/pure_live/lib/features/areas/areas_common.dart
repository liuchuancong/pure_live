import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_library/live_library.dart' show FollowArea, FollowAreaRepository;
import 'package:live_sites/live_sites.dart' show LiveArea, LiveAreaIdentity;
import 'package:pure_live/app/providers/app_providers.dart' show followAreaRepositoryProvider;
import 'package:pure_live/l10n/generated/strings.g.dart';
import 'package:pure_live/shared/widgets/settings_surface.dart' show SettingsSurfaceRef, showSettingsSurface;
import 'package:pure_uikit/pure_uikit.dart';

/// The followed partitions, in the user's order, re-read on every change —
/// including another window's, which is what the repository's own signal is
/// for.
final followedAreasProvider = StreamProvider<List<FollowArea>>((ref) {
  // Read here, not inside the generator: an async* body runs once the stream
  // is listened to, and a `ref` used after its provider was created no longer
  // records the dependency.
  final repository = ref.watch(followAreaRepositoryProvider);
  return _areasOf(repository);
});

Stream<List<FollowArea>> _areasOf(FollowAreaRepository repository) async* {
  yield repository.areas;
  await for (final _ in repository.changes) {
    yield repository.areas;
  }
}

/// Whether [area] is among [areas].
bool isAreaFollowed(Iterable<FollowArea> areas, LiveArea area) =>
    areas.any((followed) => followed.identityKey == area.identityKey);

/// Follows [area], or unfollows it after asking — the room pill's rule, which
/// the reference applies to partitions too: following is reversible from the
/// same place, so it happens at once, while dropping a follow that took a
/// decision to add would be lost to a mis-tap.
///
/// The repository is the source of truth for the pill's state, so nothing here
/// returns it; the failure path says the change did not land rather than
/// pretending it did.
Future<void> toggleAreaFollow(BuildContext context, WidgetRef ref, LiveArea area) async {
  final t = context.t;
  final repository = ref.read(followAreaRepositoryProvider);
  final name = area.areaName.isEmpty ? area.areaId : area.areaName;
  try {
    if (!repository.isFollowing(area)) {
      await repository.follow(area);
      if (context.mounted) {
        PureToast.show(context, t.areas.followDone(name: name), type: PureToastType.success);
      }
      return;
    }
    if (!context.mounted) {
      return;
    }
    final confirmed = await showSettingsSurface<bool>(
      context,
      ref.settingsFormFactor,
      title: t.follow.unfollow,
      body: (surfaceContext) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text(surfaceContext.t.follow.unfollowConfirm(name: name)),
      ),
      actions: (surfaceContext) => [
        PureButton(
          label: surfaceContext.t.common.cancel,
          variant: ButtonVariant.ghost,
          onPressed: () => Navigator.of(surfaceContext).pop(false),
        ),
        PureButton(label: surfaceContext.t.common.confirm, onPressed: () => Navigator.of(surfaceContext).pop(true)),
      ],
    );
    if (confirmed != true) {
      return;
    }
    await repository.unfollow(area);
    if (context.mounted) {
      PureToast.show(context, t.areas.unfollowDone(name: name), type: PureToastType.success);
    }
  } on Object {
    if (context.mounted) {
      PureToast.show(context, t.errors.network, type: PureToastType.error);
    }
  }
}
