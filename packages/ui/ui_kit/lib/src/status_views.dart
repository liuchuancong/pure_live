// Module: lib/src/status_views.dart
// Purpose: The shared status surfaces: empty state, error-with-retry and the section header every list reuses.
// Author: liuchuancong
// Created: 2026-10-10
//
// These three views are the reason the token set exists as a ThemeExtension: a status page is drawn in every
// feature, and before the tokens each one picked its own icon size, gap and label text. Sizes now come from
// the resolved tokens, and the readable-size floor is applied here rather than trusting whichever
// TextTheme.textTheme the active style happens to build - on a TV, `bodySmall` at 12 logical pixels is a
// wall of grey, and the floor is exactly the kind of rule that cannot be left to a style's defaults.
//
// The Chinese strings stayed as *defaults*, not as the only option: a base component that cannot be
// re-labelled is a base component the app has to copy in order to translate it.

import 'package:flutter/material.dart';

import 'package:pure_live_design/pure_live_design.dart';

import 'tokens_theme.dart';

/// The icon + title + hint column used for empty and informational states.
final class EmptyStateView extends StatelessWidget {
  const EmptyStateView({
    required this.icon,
    required this.title,
    this.hint,
    this.titleRole = TypeRole.titleMedium,
    super.key,
  });

  final IconData icon;
  final String title;
  final String? hint;

  /// Which type role the heading is drawn at; a full-page empty state wants a larger one than a row-level
  /// placeholder.
  final TypeRole titleRole;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = context.designTokens;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        spacing: SpaceToken.space12.px * tokens.density.scale,
        children: <Widget>[
          Icon(icon, size: _glyphSize(tokens), color: theme.colorScheme.outline),
          Text(title, style: theme.textTheme.titleMedium?.copyWith(fontSize: tokens.typeSize(titleRole))),
          if (hint != null && hint!.isNotEmpty)
            Padding(
              padding: EdgeInsets.symmetric(horizontal: PureLiveSpacing.xl * tokens.density.scale),
              child: Text(
                hint!,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(
                  // The floor matters most here: hint text is the smallest role in the app, and it is also
                  // the text that explains what to do next.
                  fontSize: tokens.typeSize(TypeRole.bodySmall),
                  color: theme.colorScheme.outline,
                ),
              ),
            ),
        ],
      ),
    );
  }

  static double _glyphSize(DesignTokens tokens) => switch (tokens.input) {
    InputMode.remote => 88,
    InputMode.touch => 64,
    InputMode.pointer => 56,
  };
}

/// The error surface with a retry callback.
///
/// [retryLabel] exists because a retry button is the single most translated word in the app, and a base
/// component that hardcodes it forces every feature to copy the view instead of using it.
final class ErrorRetryView extends StatelessWidget {
  const ErrorRetryView({
    required this.error,
    required this.onRetry,
    this.title = '加载失败',
    this.retryLabel = '重试',
    super.key,
  });

  final String error;
  final VoidCallback onRetry;
  final String title;
  final String retryLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = context.designTokens;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        spacing: SpaceToken.space12.px * tokens.density.scale,
        children: <Widget>[
          Icon(Icons.error_outline, size: EmptyStateView._glyphSize(tokens), color: theme.colorScheme.error),
          Text(title, style: theme.textTheme.titleMedium?.copyWith(fontSize: tokens.typeSize(TypeRole.titleMedium))),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: PureLiveSpacing.xl * tokens.density.scale),
            child: Text(
              error,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(fontSize: tokens.typeSize(TypeRole.bodySmall)),
            ),
          ),
          SizedBox(height: SpaceToken.space8.px * tokens.density.scale),
          // The button carries its own minimum height: a retry you cannot hit with a remote is not a retry.
          FilledButton.tonal(
            onPressed: onRetry,
            style: FilledButton.styleFrom(minimumSize: Size(0, tokens.height(ControlKind.button))),
            child: Text(retryLabel, style: TextStyle(fontSize: tokens.typeSize(TypeRole.bodyLarge))),
          ),
        ],
      ),
    );
  }
}

/// The list section header: a bold label with consistent spacing.
final class SectionHeader extends StatelessWidget {
  const SectionHeader({required this.title, this.color, super.key});

  final String title;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = context.designTokens;
    final horizontal = tokens.gapBetween(ControlKind.listItem);
    return Padding(
      padding: EdgeInsets.fromLTRB(
        horizontal,
        PureLiveSpacing.md * tokens.density.scale,
        horizontal,
        tokens.gapBetween(ControlKind.chip),
      ),
      child: Text(
        title,
        style: theme.textTheme.titleMedium?.copyWith(color: color, fontSize: tokens.typeSize(TypeRole.titleMedium)),
      ),
    );
  }
}
