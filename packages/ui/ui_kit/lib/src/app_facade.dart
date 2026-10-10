// Module: lib/src/app_facade.dart
// Purpose: The unified notification, dialog and loading surfaces features call instead of the widget layer.
// Author: liuchuancong
// Created: 2026-10-10
//
// Spec: docs/architecture/pure_live_v2_flutter_technology_stack.md section 7 ("统一门面").
//
// These take a BuildContext at the call site. The first version of this file did not - `success(String)` had
// nowhere to find a messenger, so nothing could implement it except by holding a context across an await or a
// global, which is exactly the "context across gaps" bug the framework warns about. An unimplementable
// interface is why every feature kept calling ScaffoldMessenger directly.

import 'package:flutter/material.dart';

/// How loud a notification is, and how long it should stay for the input mode reading it.
enum NoticeSeverity { info, success, warning, error }

/// User-facing notifications.
abstract interface class AppNotice {
  /// Shows [message] and returns immediately: a notice never blocks the action that reported itself.
  void show(BuildContext context, String message, {NoticeSeverity severity = NoticeSeverity.info});

  /// Removes any notice this facade is still showing. Called when a screen goes away, so a notice about an
  /// action the user already left cannot reappear on the next page.
  void dismiss(BuildContext context);
}

/// The four call-site spellings of [AppNotice.show].
///
/// They are an extension rather than interface members because `implements` obliges a class to provide every
/// declared member: sugar in the interface would make each implementation re-write the four one-liners it was
/// there to avoid.
extension AppNoticeSeverity on AppNotice {
  void success(BuildContext context, String message) => show(context, message, severity: NoticeSeverity.success);
  void info(BuildContext context, String message) => show(context, message);
  void warning(BuildContext context, String message) => show(context, message, severity: NoticeSeverity.warning);
  void error(BuildContext context, String message) => show(context, message, severity: NoticeSeverity.error);
}

/// Modal dialog entry. Implementations own the dialog styling; callers own the content and the result.
abstract interface class AppDialog {
  /// Awaits the user. Null means dismissed without choosing.
  Future<T?> show<T>(BuildContext context, {required WidgetBuilder builder, bool barrierDismissible = true});
}

/// Runs work behind a blocking loading surface.
abstract interface class AppLoading {
  /// Runs [task] with a busy indicator up, and returns its result or rethrows its error.
  ///
  /// The surface must come down whether the task completes, fails or the screen goes away: a stuck modal
  /// loader is worse than no loader, because the user cannot tell a slow action from a dead app.
  Future<T> during<T>(BuildContext context, Future<T> Function() task, {String? message});
}

/// A no-op notice for hosts that have not bound a presentation yet.
///
/// Kept because the alternative - a null facade - makes every call site write its own `?.`, and the whole
/// point of the facade is that callers do not think about presentation.
final class SilentNotice implements AppNotice {
  const SilentNotice();

  @override
  void show(BuildContext context, String message, {NoticeSeverity severity = NoticeSeverity.info}) {}

  @override
  void dismiss(BuildContext context) {}
}

/// A dialog that never opens and answers "dismissed".
///
/// For a headless test or a host with no navigator. It is not a default a shipping app should bind: a
/// confirmation returning null reads as "the user said no", which is a real answer these facades must not
/// fabricate silently.
final class NoDialog implements AppDialog {
  const NoDialog();

  @override
  Future<T?> show<T>(BuildContext context, {required WidgetBuilder builder, bool barrierDismissible = true}) async =>
      null;
}

/// Runs the work with nothing drawn.
final class PassthroughLoading implements AppLoading {
  const PassthroughLoading();

  @override
  Future<T> during<T>(BuildContext context, Future<T> Function() task, {String? message}) => task();
}

/// The three presentation surfaces a host binds together.
///
/// The interface file deliberately knows nothing about Material: it must not import its own implementations,
/// or every feature gets a dependency cycle through the kit. The bound set lives in `facade_material.dart`
/// ([materialFacades]); [none] here is the unbound default a test or a headless host uses.
final class AppFacades {
  const AppFacades({required this.notice, required this.dialog, required this.loading});

  /// Nothing is shown and nothing blocks: callers stay wired, the user sees no surface.
  static const AppFacades none = AppFacades(notice: SilentNotice(), dialog: NoDialog(), loading: PassthroughLoading());

  final AppNotice notice;
  final AppDialog dialog;
  final AppLoading loading;
}
