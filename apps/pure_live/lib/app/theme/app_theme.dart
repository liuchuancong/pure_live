import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pure_live/app/environment/env.dart';
import 'package:pure_live/app/providers/app_providers.dart';
import 'package:pure_uikit/pure_uikit.dart';

/// The Material surface the chosen appearance resolves to.
///
/// The app no longer hosts itself in Material — the root widget asks the active
/// language for its host — so this is left for the one thing that has to paint
/// before any widget exists: the desktop window's clear colour, which would
/// otherwise flash a colour the first frame then covers.
ThemeData materialThemeSeed(UiConfig config, Brightness brightness) => ThemeData(
  useMaterial3: true,
  colorScheme: ColorScheme.fromSeed(seedColor: config.accent ?? const Color(0xFF6750A4), brightness: brightness),
);

/// The root of the themed tree: it turns the persisted appearance into the
/// `PureTheme` every widget below reads, including the host the root widget asks
/// the language for.
///
/// It sits above the host, not inside it, so a pushed route is themed by the
/// same decision as the page it came from, and a preference change re-skins
/// every route at once without resetting the navigation stack.
///
/// `systemTextScale` is deliberately not folded in here: the device's text
/// scale arrives through `MediaQuery` inside the app, and reading it at this
/// level would apply it twice. The composition root passes the platform's own
/// value once the shell can measure it.
class AppTheme extends ConsumerWidget {
  /// Themes [child]; [hardwareBlur] says whether the device can afford a
  /// backdrop filter, and belongs to the platform facts of this build (a TV
  /// build declares false because it cannot).
  const new({required this.child, this.hardwareBlur = true, super.key});

  /// The themed subtree.
  final Widget child;

  /// Whether this device can draw a backdrop filter.
  final bool hardwareBlur;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PureConfigProvider(
      config: ref.watch(uiConfigProvider),
      hardwareBlur: hardwareBlur,
      child: PureLayoutBuilder(isTv: Env.isTv, builder: (context, environment) => child),
    );
  }
}
