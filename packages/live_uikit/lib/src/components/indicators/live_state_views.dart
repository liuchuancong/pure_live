import 'package:flutter/material.dart';

import 'package:live_uikit/src/components/contracts/live_component_specs.dart';
import 'package:live_uikit/src/theme/live_theme.dart';

/// The progress indicator every page uses.
class LiveProgressIndicator extends StatelessWidget {
  /// A progress indicator.
  const new({this.value, this.size = LiveControlSize.medium, this.semanticLabel, super.key});

  /// The progress in 0..1, or null for an indeterminate spinner.
  final double? value;

  /// How large the indicator is.
  final LiveControlSize size;

  /// An accessibility label.
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) => LiveTheme.of(context).components
      .progressIndicator(context, LiveProgressIndicatorSpec(value: value, size: size, semanticLabel: semanticLabel));
}

/// The loading view every page uses, for a whole view or a card's worth of
/// content.
class LiveLoadingView extends StatelessWidget {
  /// A loading view.
  const new({this.message, this.value, this.compact = false, super.key});

  /// What is being loaded.
  final String? message;

  /// The progress in 0..1, or null for an indeterminate spinner.
  final double? value;

  /// Whether the view lays out tightly for embedding.
  final bool compact;

  @override
  Widget build(BuildContext context) =>
      LiveTheme.of(context).components
          .loadingView(context, LiveLoadingViewSpec(message: message, value: value, compact: compact));
}

/// The error view every page uses.
///
/// It never shows a raw exception to the user: [message] is the sentence a
/// person can act on, and [details] stays collapsed behind a disclosure for
/// whoever is debugging. A [onRetry] callback adds the retry button.
class LiveErrorView extends StatelessWidget {
  /// An error view.
  const new({
    required this.message,
    this.details,
    this.icon,
    this.retryLabel,
    this.onRetry,
    this.compact = false,
    super.key,
  });

  /// What went wrong, in the user's language.
  final String message;

  /// Technical detail for a diagnostics expander.
  final String? details;

  /// Overrides the error icon.
  final IconData? icon;

  /// The retry button's label.
  final String? retryLabel;

  /// Retries the failed work.
  final VoidCallback? onRetry;

  /// Whether the view lays out tightly for embedding.
  final bool compact;

  @override
  Widget build(BuildContext context) => LiveTheme.of(context).components.errorView(
    context,
    LiveErrorViewSpec(
      message: message,
      details: details,
      icon: icon,
      retryLabel: retryLabel,
      onRetry: onRetry,
      compact: compact,
    ),
  );
}

/// The empty state every page uses.
class LiveEmptyView extends StatelessWidget {
  /// An empty view.
  const new({required this.title, this.message, this.icon, this.action, this.compact = false, super.key});

  /// The headline.
  final String title;

  /// A sentence explaining what would fill the view.
  final String? message;

  /// Overrides the empty-state icon.
  final IconData? icon;

  /// The primary action offered with the empty state.
  final Widget? action;

  /// Whether the view lays out tightly for embedding.
  final bool compact;

  @override
  Widget build(BuildContext context) => LiveTheme.of(context).components.emptyView(
    context,
    LiveEmptyViewSpec(title: title, message: message, icon: icon, action: action, compact: compact),
  );
}
