// Module: lib/app/di.dart
// Purpose: Riverpod wiring for the assembled runtime and the application router.
// Author: liuchuancong
// Created: 2026-10-09
//
// The runtime is assembled once in main() and injected as an override, so nothing below the
// ProviderScope can construct a second composition root (AGENTS.md I9). Any read before the
// override is in place is a programming error, hence the throw instead of a nullable.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'runtime.dart';
import 'router.dart';

/// The one [PureLiveRuntime] this process assembled. Overridden in [ProviderScope] at boot.
final runtimeProvider = Provider<PureLiveRuntime>((ref) {
  throw UnimplementedError('runtimeProvider must be overridden with the booted runtime');
});

/// The application router. Reads nothing from [runtimeProvider] today; routes that need
/// runtime data watch it directly in their widgets.
final routerProvider = Provider<GoRouter>((ref) => buildGoRouter());
