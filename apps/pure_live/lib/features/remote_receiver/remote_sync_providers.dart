import 'dart:async' show unawaited;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:pure_live/app/providers/app_providers.dart';
import 'package:pure_live/features/remote_receiver/remote_sync_service.dart';

/// The LAN sync service, created on first entry to the sync page and kept
/// for the rest of the process (the 3.x binding was a lazy singleton the
/// same way): the server and discovery keep running after the page closes,
/// so another device's request still reaches the confirm gate.
final remoteSyncServiceProvider = Provider<RemoteSyncService>((ref) {
  final service = RemoteSyncService(
    follows: ref.watch(followRepositoryProvider),
    history: ref.watch(historyRepositoryProvider),
  );
  ref.onDispose(service.dispose);
  unawaited(service.start());
  return service;
});
