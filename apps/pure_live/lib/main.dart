// Module: lib/main.dart
// Purpose: The entry point: initialise the binding, boot the runtime, start the app.
// Author: liuchuancong
// Created: 2026-10-09
//
// Boot order note: the binding comes first because path_provider is a platform channel, and the runtime is
// assembled before the first frame so nothing below the widget tree has to handle a null service.
//
// The store writes through on every change, so a process exit that never calls dispose loses nothing;
// dispose exists for tests and for a later lifecycle host that tears the runtime down between sessions.

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pure_live_media/pure_live_media.dart';
import 'package:pure_live_platform/pure_live_platform.dart' as platform;

import 'app/app.dart';
import 'app/di.dart';

import 'dart:convert';

import 'app/appearance.dart';
import 'app/plugin_hosting.dart';
import 'app/runtime.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // The engine needs the binding ready before its first surface; doing it here keeps every widget below
  // free of engine start-up concerns.
  MediaKernelHost.ensureInitialized();
  // System media surfaces are opt-in and app-level (manifest/notification
  // requirements). Enable before the runtime so the first kernel takes the
  // driver; a refusing platform only costs the surfaces, not the app.
  Object? mediaSessionError;
  try {
    await MediaSessionBootstrap.enable();
  } catch (error) {
    mediaSessionError = error;
  }
  final runtime = await PureLiveRuntime.boot();
  if (mediaSessionError != null) {
    runtime.diagnostics.emit(
      'media.sessionUnavailable',
      level: platform.DiagnosticLevel.warning,
      metadata: <String, Object?>{'error': '$mediaSessionError'},
    );
  }
  // Installed-and-enabled plugins join the registry before the first frame, so
  // the home feed opens with them already present. A broken script is recorded
  // and skipped; it never fails the boot.
  final pluginReport = await loadEnabledPlugins(runtime, runtime.pluginStore);
  for (final entry in pluginReport.failed.entries) {
    runtime.diagnostics.emit(
      'plugin.loadFailed',
      extensionId: entry.key,
      level: platform.DiagnosticLevel.error,
      metadata: <String, Object?>{'error': entry.value},
    );
  }
  final savedAppearance = await runtime.keyValueStore.read('appearance');
  final appearance = savedAppearance is String
      ? AppearanceConfig.fromJson(jsonDecode(savedAppearance) as Map<String, Object?>)
      : const AppearanceConfig();
  runApp(
    // Riverpod 3 no longer exports the Override type name; pass the override as-is.
    ProviderScope(
      overrides: [runtimeProvider.overrideWithValue(runtime), loadedAppearanceProvider.overrideWithValue(appearance)],
      child: const PureLiveApp(),
    ),
  );
}
