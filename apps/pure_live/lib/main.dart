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

import 'app/app.dart';
import 'app/di.dart';
import 'app/runtime.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // The engine needs the binding ready before its first surface; doing it here keeps every widget below
  // free of engine start-up concerns.
  MediaKernelHost.ensureInitialized();
  final runtime = registerBuiltInSources(await PureLiveRuntime.boot());
  runApp(
    // Riverpod 3 no longer exports the Override type name; pass the override as-is.
    ProviderScope(overrides: [runtimeProvider.overrideWithValue(runtime)], child: const PureLiveApp()),
  );
}
