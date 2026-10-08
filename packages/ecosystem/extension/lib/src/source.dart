// Module: lib/src/source.dart
// Purpose: The contract for one configured external source: what it is, how it is doing and what refresh means.
// Author: liuchuancong
// Created: 2026-10-08
//
// Spec: docs/contracts/platform-contracts.md section 8 and docs/contracts/platform-models.md section 6.
// A Source is a user-configured or built-in origin (a URL, a file, a script, a built-in catalogue); the
// Repository is what it forms after loading. Keeping them separate is what lets one TVBox source fail
// without taking the runtime down (invariant 6).

import 'package:pure_live_platform/pure_live_platform.dart';

/// One live source the platform manages.
abstract interface class Source {
  SourceDescriptor get descriptor;

  /// Current state; it must come from the source, never from a UI assumption
  /// (docs/contracts/platform-models.md section 6 forbids using a nullable field as state).
  SourceState get state;

  /// Readiness for first use: fetch, detect, validate, parse into a repository.
  Future<void> initialize();

  /// Re-read the origin. A refresh that fails leaves the previous content usable rather than emptying it.
  Future<void> refresh();

  /// Release whatever this source holds. The descriptor and state stay readable for diagnostics.
  Future<void> dispose();
}
