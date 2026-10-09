// Module: lib/app/app.dart
// Purpose: The application widget: themed by the chosen style, layered over
// the configured background, routed everywhere.
// Author: liuchuancong
// Created: 2026-10-09
//
// Spec: docs/architecture/system-overview.md section 1 ("App 只是 Runtime 的一个宿主").
// The widget tree only ever reads the runtime and appearance through their
// providers; it never reaches into package internals, so the experience layer
// can be extracted into packages later without touching the composition root.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pure_live_adaptive/pure_live_adaptive.dart';
import 'package:pure_live_media/pure_live_media.dart';
import 'package:pure_live_platform/pure_live_platform.dart';

import 'appearance.dart';
import 'di.dart';

final class PureLiveApp extends ConsumerWidget {
  const PureLiveApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final GoRouter router = ref.watch(routerProvider);
    final appearance = ref.watch(appearanceProvider);
    final registry = AdaptiveStyleRegistry.withAllVariants();
    return MaterialApp.router(
      title: '纯粹直播',
      theme: registry.themeFor(appearance.style, Brightness.light, appearance.seed),
      darkTheme: registry.themeFor(appearance.style, Brightness.dark, appearance.seed),
      themeMode: appearance.themeMode,
      routerConfig: router,
      builder: (context, child) {
        if (!appearance.background.isActive || child == null) {
          return child ?? const SizedBox.shrink();
        }
        return Stack(
          children: <Widget>[
            AppBackground(
              config: appearance.background,
              videoBuilder: (source, _) => _BackgroundVideo(source: source),
            ),
            child,
          ],
        );
      },
    );
  }
}

/// The video background layer: one muted, looping, engine-backed player per
/// source, owned by this widget's lifetime. Page scaffolds draw opaque
/// backgrounds today, so this layer shows through wherever a surface opts
/// into transparency - the background wave decides which pages do.
final class _BackgroundVideo extends ConsumerStatefulWidget {
  const _BackgroundVideo({required this.source});

  final String source;

  @override
  ConsumerState<_BackgroundVideo> createState() => _BackgroundVideoState();
}

final class _BackgroundVideoState extends ConsumerState<_BackgroundVideo> {
  PlayerHandle? _handle;

  @override
  void initState() {
    super.initState();
    _open();
  }

  Future<void> _open() async {
    final runtime = ref.read(runtimeProvider);
    final uri = Uri.tryParse(widget.source);
    if (uri == null) {
      return;
    }
    try {
      final handle = await runtime.media.open(
        MediaTicket(
          id: 'app.background',
          uri: uri,
          kind: MediaKind.vod,
          protocol: uri.path.endsWith('.m3u8') ? MediaProtocol.hls : MediaProtocol.http,
          createdAt: DateTime.now().toUtc(),
          refresh: const MediaTicketRefreshInfo(supported: false),
        ),
        config: const PlayerConfig(muted: true, loop: true, autoPlay: true, enableAudio: false),
      );
      if (!mounted) {
        await handle.dispose();
        return;
      }
      setState(() => _handle = handle);
    } catch (_) {
      // A background that cannot open stays empty; there is nothing to show
      // an error against.
    }
  }

  @override
  void dispose() {
    _handle?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final handle = _handle;
    return handle == null ? const SizedBox.shrink() : MediaSurface(handle: handle);
  }
}
