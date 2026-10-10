// Module: lib/src/status_views.dart
// Purpose: The shared status surfaces: empty state, error-with-retry and the
// section header every list reuses.
// Author: liuchuancong
// Created: 2026-10-10

import 'package:flutter/material.dart';

import 'package:pure_live_design/pure_live_design.dart';

/// The icon + title + hint column used for empty and informational states.
final class EmptyStateView extends StatelessWidget {
  const EmptyStateView({required this.icon, required this.title, this.hint, super.key});

  final IconData icon;
  final String title;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        spacing: PureLiveSpacing.sm + 4,
        children: <Widget>[
          Icon(icon, size: 64, color: theme.colorScheme.outline),
          Text(title, style: theme.textTheme.titleMedium),
          if (hint != null && hint!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: PureLiveSpacing.xl),
              child: Text(
                hint!,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline),
              ),
            ),
        ],
      ),
    );
  }
}

/// The error surface with a retry callback.
final class ErrorRetryView extends StatelessWidget {
  const ErrorRetryView({required this.error, required this.onRetry, super.key});

  final String error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        spacing: PureLiveSpacing.sm + 4,
        children: <Widget>[
          Icon(Icons.error_outline, size: 64, color: theme.colorScheme.error),
          Text('加载失败', style: theme.textTheme.titleMedium),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: PureLiveSpacing.xl),
            child: Text(error, textAlign: TextAlign.center, style: theme.textTheme.bodySmall),
          ),
          const SizedBox(height: PureLiveSpacing.xs),
          FilledButton.tonal(onPressed: onRetry, child: const Text('重试')),
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
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(color: color)),
    );
  }
}
