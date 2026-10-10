// Module: lib/src/facade_material.dart
// Purpose: The Material implementations of the notice, dialog and loading facades.
// Author: liuchuancong
// Created: 2026-10-11
//
// These are the half of the "统一门面" that the interfaces alone never delivered: a feature that called
// AppNotice previously had nothing to bind, so it went back to ScaffoldMessenger and every page grew its own
// snackbar. Severity colours are read from ColorScheme's container pairs rather than from ColorRole, because
// the role vocabulary has one destructive slot and no success/warning; a container is designed to be paired
// with its onContainer, so re-expressing that as four extra roles would duplicate the scheme and get the
// contrast wrong. Severity timing is the exception - that is a design rule (how long a d-pad viewer needs to
// read a line), so it comes from the tokens' input mode.

import 'dart:async';

import 'package:flutter/material.dart';

import 'package:pure_live_design/pure_live_design.dart';

import 'app_facade.dart';
import 'tokens_theme.dart';

/// A notice shown through the nearest [ScaffoldMessenger].
final class SnackbarNotice implements AppNotice {
  const SnackbarNotice();

  @override
  void show(BuildContext context, String message, {NoticeSeverity severity = NoticeSeverity.info}) {
    if (message.trim().isEmpty) {
      return;
    }
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) {
      // No Scaffold above this widget means there is nowhere to anchor a notice, and a throw on the way to
      // reporting a failure would hide the failure it was reporting.
      return;
    }
    final scheme = Theme.of(context).colorScheme;
    final tokens = context.designTokens;
    messenger
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: Row(
            children: <Widget>[
              Icon(_iconOf(severity), color: _foreground(scheme, severity), size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  message,
                  style: TextStyle(color: _foreground(scheme, severity), fontSize: tokens.typeSize(TypeRole.bodyLarge)),
                ),
              ),
            ],
          ),
          backgroundColor: _background(scheme, severity),
          // A remote viewer reads at ten feet and cannot dismiss a bar by flicking it away, so the same
          // sentence gets longer on a TV than on a phone.
          duration: tokens.input == InputMode.remote
              ? const Duration(milliseconds: 4500)
              : const Duration(milliseconds: 2700),
        ),
      );
  }

  @override
  void dismiss(BuildContext context) => ScaffoldMessenger.maybeOf(context)?.clearSnackBars();

  static IconData _iconOf(NoticeSeverity severity) => switch (severity) {
    NoticeSeverity.info => Icons.info_outline,
    NoticeSeverity.success => Icons.check_circle_outline,
    NoticeSeverity.warning => Icons.warning_amber_rounded,
    NoticeSeverity.error => Icons.error_outline,
  };

  static Color _background(ColorScheme scheme, NoticeSeverity severity) => switch (severity) {
    NoticeSeverity.info => scheme.surfaceContainerHighest,
    NoticeSeverity.success => scheme.secondaryContainer,
    NoticeSeverity.warning => scheme.tertiaryContainer,
    NoticeSeverity.error => scheme.errorContainer,
  };

  static Color _foreground(ColorScheme scheme, NoticeSeverity severity) => switch (severity) {
    NoticeSeverity.info => scheme.onSurface,
    NoticeSeverity.success => scheme.onSecondaryContainer,
    NoticeSeverity.warning => scheme.onTertiaryContainer,
    NoticeSeverity.error => scheme.onErrorContainer,
  };
}

/// Dialogs and blocking loading surfaces on the nearest [Navigator].
///
/// One class implements both because both are "push a route and await it", and a host that wants its own
/// dialog chrome (a TV overlay, a toastification notice) overrides the pair together rather than half-binding
/// the facade.
final class MaterialFacades implements AppDialog, AppLoading {
  const MaterialFacades();

  @override
  Future<T?> show<T>(BuildContext context, {required WidgetBuilder builder, bool barrierDismissible = true}) {
    // No chrome is imposed here: the caller builds an AlertDialog or a Dialog and gets the theme the style
    // registered. What the facade owns is the barrier rule and the one place a host swaps in TV overlay
    // behaviour, so the swap does not need every feature's call sites rewritten.
    return showDialog<T>(context: context, barrierDismissible: barrierDismissible, builder: builder);
  }

  @override
  Future<T> during<T>(BuildContext context, Future<T> Function() task, {String? message}) async {
    // The route's own context, captured from the dialog's Builder: popping the *dialog* is what closes it.
    // Closing through the caller's context would pop whatever route the caller itself is on when the caller
    // has already been navigated away from.
    BuildContext? dialogContext;
    var closed = false;

    Future<void> close() async {
      if (closed) {
        return;
      }
      closed = true;
      final navigator = dialogContext == null ? null : Navigator.maybeOf(dialogContext!);
      if (navigator != null && navigator.canPop()) {
        navigator.pop();
      }
    }

    unawaited(
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (inner) {
          dialogContext = inner;
          return PopScope(
            canPop: false,
            child: AlertDialog(
              content: Row(
                children: <Widget>[
                  const SizedBox(width: 26, height: 26, child: CircularProgressIndicator(strokeWidth: 2.6)),
                  const SizedBox(width: 14),
                  Expanded(child: Text(message ?? '处理中…', style: Theme.of(inner).textTheme.bodyMedium)),
                ],
              ),
            ),
          );
        },
      ),
    );

    try {
      return await task();
    } finally {
      await close();
    }
  }
}

/// The bundle a Flutter host binds: notices as snackbars, dialogs and loading on the navigator.
///
/// One constant instead of three providers, because a half-bound set is the bug: a host that overrides the
/// notice but leaves [AppFacades.none]'s [NoDialog] in place gets confirmations that silently answer "no".
const AppFacades materialFacades = AppFacades(
  notice: SnackbarNotice(),
  dialog: MaterialFacades(),
  loading: MaterialFacades(),
);
