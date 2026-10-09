// Module: lib/app/appearance.dart
// Purpose: The user's appearance configuration: style, seed, theme mode and
// the decorative background - loaded once, watched everywhere, persisted.
// Author: liuchuancong
// Created: 2026-10-10
//
// The values are pure data (pure_live_adaptive / pure_live_design models);
// this file only owns loading, saving and the Riverpod surface. The settings
// page writes through the controller, the app widget reads the state.

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pure_live_adaptive/pure_live_adaptive.dart';
import 'package:pure_live_design/pure_live_design.dart';

import 'di.dart';

/// Everything the app's look depends on, as one persistable value.
final class AppearanceConfig {
  const AppearanceConfig({
    this.style = AdaptiveUiStyle.material,
    this.seed = const Color(0xFF6A5AE0),
    this.themeMode = ThemeMode.system,
    this.background = const BackgroundConfig(),
  });

  factory AppearanceConfig.fromJson(Map<String, Object?> json) => AppearanceConfig(
    style: AdaptiveUiStyle.byName(json['style'] as String?),
    seed: Color((json['seed'] as num?)?.toInt() ?? 0xFF6A5AE0),
    themeMode: ThemeMode.values.where((mode) => mode.name == json['themeMode']).firstOrNull ?? ThemeMode.system,
    background: json['background'] is Map
        ? BackgroundConfig.fromJson(Map<String, Object?>.from(json['background'] as Map))
        : const BackgroundConfig(),
  );

  final AdaptiveUiStyle style;
  final Color seed;
  final ThemeMode themeMode;
  final BackgroundConfig background;

  AppearanceConfig copyWith({
    AdaptiveUiStyle? style,
    Color? seed,
    ThemeMode? themeMode,
    BackgroundConfig? background,
  }) => AppearanceConfig(
    style: style ?? this.style,
    seed: seed ?? this.seed,
    themeMode: themeMode ?? this.themeMode,
    background: background ?? this.background,
  );

  Map<String, Object?> toJson() => <String, Object?>{
    'style': style.name,
    'seed': seed.toARGB32(),
    'themeMode': themeMode.name,
    'background': background.toJson(),
  };
}

/// The controller the settings page writes through. Persistence rides along:
/// every update rewrites the single appearance document.
final class AppearanceController extends Notifier<AppearanceConfig> {
  static const _storageKey = 'appearance';

  @override
  AppearanceConfig build() => ref.watch(loadedAppearanceProvider);

  Future<void> update(AppearanceConfig next) async {
    final runtime = ref.read(runtimeProvider);
    state = next;
    await runtime.keyValueStore.write(_storageKey, jsonEncode(next.toJson()));
  }
}

/// The saved appearance, resolved once at boot inside the ProviderScope
/// override. Riverpod needs a synchronous first value, so the override
/// carries the decoded config, never a future.
final loadedAppearanceProvider = Provider<AppearanceConfig>((ref) => const AppearanceConfig());

/// The appearance controller.
final appearanceProvider = NotifierProvider<AppearanceController, AppearanceConfig>(AppearanceController.new);
