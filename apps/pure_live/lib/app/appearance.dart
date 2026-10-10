// Module: lib/app/appearance.dart
// Purpose: The app's appearance document: the design package's settings plus the two things only this shell
// owns (seed colour, and how a saved brightness becomes a ThemeMode).
// Author: liuchuancong
// Created: 2026-10-10
//
// The token inputs themselves are `AppearanceSettings` from pure_live_design - it already carries style,
// density, text scale, motion, input mode and background, and it is the type the token resolver reads. This
// file deliberately does not re-declare those fields: a second copy of the same setting is how a stored value
// and a rendered theme start disagreeing.
//
// The document is versioned. v0 (the first v2 builds) wrote the fields flat with a `themeMode`; v1 writes
// `{v:1, seed, settings:{...}}`. fromJson migrates v0 rather than resetting it, because a user who set a seed
// should not lose it to a refactor they never opted into.

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pure_live_adaptive/pure_live_adaptive.dart';
import 'package:pure_live_design/pure_live_design.dart';

import 'di.dart';

/// Everything the app's look depends on, as one persistable value.
final class AppearanceConfig {
  const AppearanceConfig({this.settings = const AppearanceSettings(), this.seed = defaultSeed});

  /// The seed this app ships with. Named so the settings page and the document agree on one number.
  static const Color defaultSeed = Color(0xFF6A5AE0);

  static const int _documentVersion = 1;

  factory AppearanceConfig.fromJson(Map<String, Object?> json) {
    final version = (json['v'] as num?)?.toInt() ?? 0;
    final seed = (json['seed'] as num?)?.toInt();
    if (version == 0) {
      // v0 wrote the settings flat, with `themeMode` where the design model says `brightness`.
      return AppearanceConfig(
        seed: seed == null ? defaultSeed : Color(seed),
        settings: AppearanceSettings.fromJson(<String, Object?>{
          ...json,
          'brightness': _brightnessOf(json['themeMode']),
        }),
      );
    }
    final settings = json['settings'];
    return AppearanceConfig(
      seed: seed == null ? defaultSeed : Color(seed),
      settings: settings is Map
          ? AppearanceSettings.fromJson(Map<String, Object?>.from(settings))
          : const AppearanceSettings(),
    );
  }

  final AppearanceSettings settings;
  final Color seed;

  /// The style the registry was registered under; the document stores the name so a style added later stays
  /// loadable by an older settings screen.
  AdaptiveUiStyle get style => AdaptiveUiStyle.byName(settings.styleName);

  BackgroundConfig get background => settings.background;

  /// `ThemeMode` is a Flutter concept and the document is not, so the mapping lives here rather than in the
  /// design package.
  ThemeMode get themeMode => switch (settings.brightness) {
    'light' => ThemeMode.light,
    'dark' => ThemeMode.dark,
    _ => ThemeMode.system,
  };

  AppearanceConfig copyWith({
    AppearanceSettings? settings,
    AdaptiveUiStyle? style,
    Color? seed,
    ThemeMode? themeMode,
    BackgroundConfig? background,
    bool? reduceMotion,
    double? textScale,
  }) {
    var next = settings ?? this.settings;
    if (style != null) {
      next = next.copyWith(styleName: style.name);
    }
    if (themeMode != null) {
      next = next.copyWith(brightness: _brightnessName(themeMode));
    }
    if (background != null) {
      next = next.copyWith(background: background);
    }
    if (reduceMotion != null) {
      next = next.copyWith(reduceMotion: reduceMotion);
    }
    if (textScale != null) {
      next = next.copyWith(textScale: textScale);
    }
    return AppearanceConfig(settings: next, seed: seed ?? this.seed);
  }

  /// The density choice, or null for "whatever the platform resolves to" - which `copyWith` cannot express,
  /// because an absent argument there means "unchanged".
  AppearanceConfig withDensity(Density? value) => AppearanceConfig(settings: settings.withDensity(value), seed: seed);

  /// The input mode choice, or null for "read it from the platform".
  AppearanceConfig withInput(InputMode? value) => AppearanceConfig(settings: settings.withInput(value), seed: seed);

  Map<String, Object?> toJson() => <String, Object?>{
    'v': _documentVersion,
    'seed': seed.toARGB32(),
    'settings': settings.toJson(),
  };

  static String _brightnessName(ThemeMode mode) => switch (mode) {
    ThemeMode.light => 'light',
    ThemeMode.dark => 'dark',
    ThemeMode.system => 'system',
  };

  static String _brightnessOf(Object? themeMode) => switch ('${themeMode ?? 'system'}') {
    'light' => 'light',
    'dark' => 'dark',
    _ => 'system',
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
