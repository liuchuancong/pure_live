// Module: lib/main.dart
// Purpose: The entry point: initialise the binding, boot the runtime, hand it to its host.
// Author: liuchuancong
// Created: 2026-10-09
//
// Boot order note: the binding comes first because path_provider is a platform channel, and the runtime is
// assembled before the first frame so nothing below the widget tree has to handle a null service.
//
// The store writes through on every change, so a process exit that never calls dispose loses nothing;
// dispose exists for tests and for a later lifecycle host that tears the runtime down between sessions.

import 'package:flutter/widgets.dart';

import 'app/host.dart';
import 'app/runtime.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(PureLiveApp(runtime: await PureLiveRuntime.boot()));
}
