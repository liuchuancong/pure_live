import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_interaction/live_interaction.dart';
import 'package:live_sites/live_sites.dart' show LiveDanmakuProvider;
import 'package:pure_live/app/engine/danmaku.dart';
import 'package:pure_live/app/providers/app_providers.dart';
import 'package:pure_live/features/room/local_message_bus.dart';

/// Which room a feature piece serves: the platform id plus the
/// platform-specific room id, exactly what the room route carries.
typedef RoomIdentity = ({String siteId, String roomId});

/// The room's danmaku session, one per room identity (doc §app/engine/danmaku):
/// the site's `LiveDanmakuProvider` wrapped as an interaction source with the
/// shield lists applied as the filter chain.
///
/// Null when the site exposes no danmaku capability — the pane degrades to a
/// "not supported" state instead of erroring. A failed connect surfaces as the
/// provider's error; the pane offers a retry, which re-invalidates this
/// provider. The session is disposed when the room page (its last watcher)
/// goes away.
// riverpod's family type (ProviderFamily) is not exported by
// flutter_riverpod, so the variable annotation the lint asks for cannot
// be written.
// ignore: specify_nonobvious_property_types
final danmakuSessionProvider = FutureProvider.autoDispose.family<InteractionSession?, RoomIdentity>((
  ref,
  identity,
) async {
  final site = ref.watch(sitesProvider).registry.getById(identity.siteId);
  if (site == null) {
    throw StateError('unknown site ${identity.siteId}');
  }
  if (site.capability<LiveDanmakuProvider>() == null) {
    return null;
  }
  final session = await openDanmakuSession(site: site, roomId: identity.roomId, shieldRules: await loadShieldRules());
  ref.onDispose(() => unawaited(session.dispose()));
  return session;
});

/// The room's local-message bus — the reference's local interaction delivery
/// queue. One per room identity, disposed with the room page like the session.
// riverpod's family type cannot be spelled with this lint on; see above.
// ignore: specify_nonobvious_property_types
final roomLocalMessageBusProvider = Provider.autoDispose.family<RoomLocalMessageBus, RoomIdentity>((ref, identity) {
  final bus = RoomLocalMessageBus();
  ref.onDispose(() => unawaited(bus.dispose()));
  return bus;
});
