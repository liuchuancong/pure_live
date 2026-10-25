import 'dart:async' show unawaited;

import 'package:flutter/widgets.dart' show Color;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:pure_live/app/theme/theme_persistence.dart';

/// The loading animations this build offers, in gallery order.
///
/// The reference ships 85 animations through three animation packages; this
/// project does not depend on them, so the list holds only the styles drawn
/// with Flutter primitives in `app_loading_indicator.dart`. The keys keep the
/// reference's names so a later addition reads the same.
const List<String> kLoadingStyleKeys = [
  'default',
  'pulse',
  'doubleBounce',
  'threeBounce',
  'wave',
  'fadingCircle',
  'cubeGrid',
  'ripple',
  'orbit',
  'lineScale',
];

/// [key] when this build can draw it, otherwise the default ring.
String normalizeLoadingStyle(String? key) {
  final trimmed = key?.trim();
  return trimmed != null && kLoadingStyleKeys.contains(trimmed) ? trimmed : 'default';
}

/// The loading animation used by pages, lists and players.
final class LoadingStyleController extends Notifier<String> {
  @override
  String build() => normalizeLoadingStyle(ThemePersistence.readLoadingStyle());

  /// The style's key.
  String get style => state;

  /// Stores the choice; every live loading indicator follows.
  set style(String value) {
    final normalized = normalizeLoadingStyle(value);
    if (state == normalized) return;
    state = normalized;
    unawaited(ThemePersistence.storeLoadingStyle(normalized));
  }
}

/// The loading-style preference.
final loadingStyleProvider = NotifierProvider<LoadingStyleController, String>(LoadingStyleController.new);

/// The loading animations' ink; null follows the theme's accent.
final class LoadingColorController extends Notifier<Color?> {
  @override
  Color? build() => ThemePersistence.readLoadingColor();

  /// The chosen colour; null follows the accent.
  Color? get color => state;

  /// Stores the choice; null clears it back to the accent.
  set color(Color? value) {
    if (state == value) return;
    state = value;
    unawaited(ThemePersistence.storeLoadingColor(value));
  }
}

/// The loading-colour preference.
final loadingColorProvider = NotifierProvider<LoadingColorController, Color?>(LoadingColorController.new);
