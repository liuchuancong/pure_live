// Module: lib/app/app.dart
// Purpose: The application widget: theme and router around the injected runtime.
// Author: liuchuancong
// Created: 2026-10-09
//
// Spec: docs/architecture/system-overview.md section 1 ("App 只是 Runtime 的一个宿主").
// The widget tree only ever reads the runtime through [runtimeProvider]; it never
// reaches into package internals, so the experience layer can be extracted into
// packages later without touching the composition root.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'di.dart';
import 'theme.dart';

final class PureLiveApp extends ConsumerWidget {
  const PureLiveApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final GoRouter router = ref.watch(routerProvider);
    return MaterialApp.router(
      title: '纯粹直播',
      theme: PureLiveTheme.light(),
      darkTheme: PureLiveTheme.dark(),
      themeMode: ThemeMode.system,
      routerConfig: router,
    );
  }
}
