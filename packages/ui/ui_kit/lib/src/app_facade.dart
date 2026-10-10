// Module: lib/src/app_notice.dart
// Purpose: The unified notification, dialog and loading facades the tech
// stack prescribes: features call these, never the underlying toast/dialog
// packages directly.
// Author: liuchuancong
// Created: 2026-10-10
//
// Spec: docs/architecture/pure_live_v2_flutter_technology_stack.md section 7
// ("统一门面"). Implementations bind a concrete presentation (snackbar,
// toastification, TV overlay); features only ever see these interfaces. This
// keeps stacking order, theme and test behaviour identical across features.

import 'package:flutter/material.dart';

/// User-facing notifications with four severities.
abstract interface class AppNotice {
  void success(String message);
  void info(String message);
  void warning(String message);
  void error(String message);
}

/// Modal dialog entry. Implementations own the dialog styling; callers own
/// the content builder and the returned result.
abstract interface class AppDialog {
  Future<T?> show<T>({required WidgetBuilder builder, bool barrierDismissible = true});
}

/// Runs [task] behind a blocking loading surface; the future's result (or
/// error) is returned to the caller unchanged.
abstract interface class AppLoading {
  Future<T> during<T>(Future<T> Function() task, {String? message});
}

/// A default no-op notice for hosts that have not bound a presentation yet:
/// callers stay wired, nothing shows. Replace with a real implementation at
/// composition time.
final class SilentNotice implements AppNotice {
  const SilentNotice();

  @override
  void success(String message) {}
  @override
  void info(String message) {}
  @override
  void warning(String message) {}
  @override
  void error(String message) {}
}
