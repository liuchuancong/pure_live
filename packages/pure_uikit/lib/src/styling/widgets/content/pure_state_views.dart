import 'package:flutter/material.dart';
import 'package:pure_uikit/src/styling/provider/pure_config_provider.dart';
import 'package:pure_uikit/src/styling/style/recipe.dart';
import 'package:pure_uikit/src/styling/widgets/controls/pure_button.dart';
import 'package:pure_uikit/src/styling/widgets/layout/pure_environment.dart';

/// The mark of [role]: the Material status glyph the fluent view draws.
IconData _glyph(_GlyphRole role) => switch (role) {
  _GlyphRole.error => Icons.error_outline,
  _GlyphRole.empty => Icons.inbox_outlined,
  _GlyphRole.retry => Icons.refresh,
};

/// The three glyphs a full-view state asks the language for.
enum _GlyphRole { error, empty, retry }

/// The responsive geometry if a [PureLayoutBuilder] is above, else a desktop
/// default — so the state views work standalone in a preview too.
Geometry _geometry(BuildContext context, PureTheme theme) =>
    PureEnvironmentScope.maybeOf(context)?.geometry ?? Geometry.forTokens(theme.token, PureLayoutMode.desktop);

/// The shared column layout for the three full-view states.
Widget _stateColumn(BuildContext context, PureTheme theme, List<Widget> children, bool compact) {
  final geometry = _geometry(context, theme);
  final content = Column(
    mainAxisAlignment: MainAxisAlignment.center,
    mainAxisSize: MainAxisSize.min,
    children: children,
  );
  if (compact) {
    return Padding(padding: EdgeInsets.all(geometry.pagePadding), child: content);
  }
  return Center(child: content);
}

/// A full-view loading state — Ant's `Spin` counterpart. Shows a token-coloured
/// spinner and an optional [message].
class PureLoading extends StatelessWidget {
  /// A loading view.
  const new({this.message, this.compact = false, super.key});

  /// A status line under the spinner.
  final String? message;

  /// Whether to inset rather than centre the content.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = PureTheme.of(context);
    final geometry = _geometry(context, theme);
    return _stateColumn(context, theme, [
      const PureSpinner(size: 32),
      if (message case final m?) ...[
        SizedBox(height: geometry.sectionGap),
        Text(m, style: theme.text.bodySmall.copyWith(color: theme.colors.textSecondary)),
      ],
    ], compact);
  }
}

/// A full-view error state with an optional retry action.
class PureError extends StatelessWidget {
  /// An error view.
  const new({required this.message, this.onRetry, this.retryLabel = 'Retry', this.icon, super.key});

  /// The headline shown to the user.
  final String message;

  /// Called when the user asks to try again; null hides the button.
  final VoidCallback? onRetry;

  /// The retry button's label.
  final String retryLabel;

  /// The status icon, or null for the state view's own error mark.
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final theme = PureTheme.of(context);
    final geometry = _geometry(context, theme);
    return _stateColumn(context, theme, [
      Icon(icon ?? _glyph(_GlyphRole.error), size: geometry.iconSize * 2, color: theme.colors.error),
      SizedBox(height: geometry.sectionGap),
      Text(
        message,
        textAlign: TextAlign.center,
        style: theme.text.body.copyWith(color: theme.colors.text),
      ),
      if (onRetry case final retry?) ...[
        SizedBox(height: geometry.sectionGap),
        PureButton(
          label: retryLabel,
          icon: _glyph(_GlyphRole.retry),
          variant: ButtonVariant.secondary,
          onPressed: retry,
        ),
      ],
    ], false);
  }
}

/// A full-view empty state: an icon, a title and an optional message or action.
class PureEmpty extends StatelessWidget {
  /// An empty view.
  const new({required this.title, this.message, this.action, this.icon, super.key});

  /// The primary line.
  final String title;

  /// A secondary line.
  final String? message;

  /// An optional call-to-action widget.
  final Widget? action;

  /// The status icon, or null for the state view's own empty mark.
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final theme = PureTheme.of(context);
    final geometry = _geometry(context, theme);
    return _stateColumn(context, theme, [
      Icon(icon ?? _glyph(_GlyphRole.empty), size: geometry.iconSize * 2, color: theme.colors.textDisabled),
      SizedBox(height: geometry.sectionGap),
      Text(
        title,
        textAlign: TextAlign.center,
        style: theme.text.title.copyWith(color: theme.colors.text),
      ),
      if (message case final m?) ...[
        SizedBox(height: theme.token.scale.sizes.xs),
        Text(
          m,
          textAlign: TextAlign.center,
          style: theme.text.bodySmall.copyWith(color: theme.colors.textSecondary),
        ),
      ],
      if (action case final a?) ...[SizedBox(height: geometry.sectionGap), a],
    ], false);
  }
}
