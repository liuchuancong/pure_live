import 'package:flutter/material.dart';

import 'package:live_uikit/src/components/contracts/live_component_specs.dart';
import 'package:live_uikit/src/theme/live_theme.dart';

/// The button every page uses.
///
/// One widget, six design languages: the semantics (label, variant, size,
/// enabled, loading, focus) are fixed here, and which widgets get drawn is
/// the active language's business. A page must never branch on the design
/// language to get a button — this class is the whole reason it does not
/// have to.
class LiveButton extends StatelessWidget {
  /// A text button.
  const new({
    required this.label,
    this.onPressed,
    this.icon,
    this.variant = LiveButtonVariant.primary,
    this.size = LiveControlSize.medium,
    this.enabled = true,
    this.loading = false,
    this.expand = false,
    this.autofocus = false,
    this.focusNode,
    this.tooltip,
    this.semanticLabel,
    super.key,
  });

  /// The button's text.
  final String label;

  /// The callback; null disables the button.
  final VoidCallback? onPressed;

  /// An optional leading icon.
  final IconData? icon;

  /// What the button means.
  final LiveButtonVariant variant;

  /// How large it is.
  final LiveControlSize size;

  /// Whether the button accepts input.
  final bool enabled;

  /// Whether it shows a spinner and rejects input while work runs.
  final bool loading;

  /// Whether it fills its parent's width.
  final bool expand;

  /// Whether it takes focus when the view opens.
  final bool autofocus;

  /// The focus node, for pages that manage focus themselves.
  final FocusNode? focusNode;

  /// A tooltip, also the accessibility label on desktop.
  final String? tooltip;

  /// An accessibility label when [label] alone is not enough.
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final theme = LiveTheme.of(context);
    final button = theme.components.button(context, spec);
    final tooltip = this.tooltip;
    return tooltip == null ? button : Tooltip(message: tooltip, child: button);
  }

  /// The normalized spec this widget renders.
  LiveButtonSpec get spec => LiveButtonSpec(
    label: label,
    icon: icon,
    variant: variant,
    size: size,
    onPressed: onPressed,
    enabled: enabled,
    loading: loading,
    expand: expand,
    autofocus: autofocus,
    focusNode: focusNode,
    tooltip: tooltip,
    semanticLabel: semanticLabel,
  );
}

/// The icon-only button every page uses.
///
/// §7.1 of the architecture: an icon button always carries a tooltip,
/// because an icon alone is not a label anyone can read out or understand
/// on first sight.
class LiveIconButton extends StatelessWidget {
  /// An icon button.
  const new({
    required this.icon,
    required this.tooltip,
    this.onPressed,
    this.variant = LiveButtonVariant.text,
    this.size = LiveControlSize.medium,
    this.enabled = true,
    this.selected = false,
    this.autofocus = false,
    this.focusNode,
    super.key,
  });

  /// The icon to draw.
  final IconData icon;

  /// The tooltip and accessibility label.
  final String tooltip;

  /// The callback; null disables the button.
  final VoidCallback? onPressed;

  /// What the button means.
  final LiveButtonVariant variant;

  /// How large it is.
  final LiveControlSize size;

  /// Whether the button accepts input.
  final bool enabled;

  /// Whether it renders as toggled on.
  final bool selected;

  /// Whether it takes focus when the view opens.
  final bool autofocus;

  /// The focus node, for pages that manage focus themselves.
  final FocusNode? focusNode;

  @override
  Widget build(BuildContext context) => LiveTheme.of(context).components.iconButton(context, spec);

  /// The normalized spec this widget renders.
  LiveIconButtonSpec get spec => LiveIconButtonSpec(
    icon: icon,
    tooltip: tooltip,
    variant: variant,
    size: size,
    onPressed: onPressed,
    enabled: enabled,
    selected: selected,
    autofocus: autofocus,
    focusNode: focusNode,
  );
}
