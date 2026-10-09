// Module: lib/src/app_background.dart
// Purpose: The decorative background behind app content, composed from a
// persisted BackgroundConfig.
// Author: liuchuancong
// Created: 2026-10-10
//
// Master's background switch (plain / image / video) is this widget. The video
// case is inverted on purpose: a ui package may not touch the engine
// (dependency-rules L3), so the host injects a builder that turns a url into
// the muted looping player it wants. No builder, no video background - the
// config degrades to the image/color layer instead of half-working.

import 'dart:io';
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import 'package:pure_live_design/pure_live_design.dart';

/// Builds the video layer for a background source. The host supplies it (the
/// app owns the engine facade); returning null from the builder degrades to
/// the fallback.
typedef VideoBackgroundBuilder = Widget? Function(String source, double opacity);

/// The background layer. Put it behind content in a Stack; it sizes itself to
/// the biggest constraint.
final class AppBackground extends StatelessWidget {
  const AppBackground({required this.config, this.videoBuilder, this.fallbackColor, super.key});

  final BackgroundConfig config;
  final VideoBackgroundBuilder? videoBuilder;
  final Color? fallbackColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (!config.isActive) {
      return const SizedBox.shrink();
    }
    Widget? layer;
    switch (config.kind) {
      case BackgroundKind.none:
        layer = null;
      case BackgroundKind.color:
        final value = int.tryParse(config.source ?? '', radix: 16);
        layer = Container(color: value == null ? theme.colorScheme.surfaceContainer : Color(value));
      case BackgroundKind.image:
        final source = config.source ?? '';
        layer = source.startsWith('http')
            ? Image.network(
                source,
                fit: BoxFit.cover,
                width: double.infinity,
                height: double.infinity,
                errorBuilder: (_, _, _) => const SizedBox.shrink(),
              )
            : Image.file(
                File(source),
                fit: BoxFit.cover,
                width: double.infinity,
                height: double.infinity,
                errorBuilder: (_, _, _) => const SizedBox.shrink(),
              );
      case BackgroundKind.video:
        final builder = videoBuilder;
        final source = config.source ?? '';
        layer = builder == null || source.isEmpty ? null : builder(source, config.opacity);
    }
    if (layer == null) {
      return const SizedBox.shrink();
    }
    return Positioned.fill(
      child: Opacity(
        opacity: config.opacity.clamp(0.0, 1.0),
        child: config.blurSigma > 0
            ? ImageFiltered(
                imageFilter: ImageFilter.blur(sigmaX: config.blurSigma, sigmaY: config.blurSigma),
                child: layer,
              )
            : layer,
      ),
    );
  }
}
