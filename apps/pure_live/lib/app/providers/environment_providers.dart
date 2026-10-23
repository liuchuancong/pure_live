import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_platform/live_platform.dart' show PlatformKind, PlatformRuntime;

/// The boot's platform snapshot; only the bootstrap can produce it, so
/// `main` overrides this and everything downstream reads it as a fact.
final platformRuntimeProvider = Provider<PlatformRuntime>(
  (ref) => throw UnimplementedError('platformRuntimeProvider must be overridden at boot'),
);

/// The OS family this process runs on, read through the boot snapshot.
final platformKindProvider = Provider<PlatformKind>(
  (ref) => ref.watch(platformRuntimeProvider).environment.runtime.kind,
);
