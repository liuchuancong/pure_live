import 'package:flutter/cupertino.dart';

import 'package:live_uikit/src/components/contracts/live_component_specs.dart';
import 'package:live_uikit/src/components/contracts/live_design_language_components.dart';
import 'package:live_uikit/src/focus/live_focus_highlight.dart';
import 'package:live_uikit/src/theme/live_component_theme.dart';
import 'package:live_uikit/src/theme/live_theme.dart';
import 'package:live_uikit/src/tokens/radii.dart';

/// The Cupertino implementation of the component contract.
///
/// Where iOS has a native control the contract maps onto it: buttons to
/// [CupertinoButton], fields to [CupertinoTextField] and
/// [CupertinoSearchTextField], dialogs to [CupertinoAlertDialog], menus to
/// the [CupertinoActionSheet] iOS uses for a list of actions, loading to
/// [CupertinoActivityIndicator]. Where iOS has no control at all — the
/// determinate progress bar, the empty and error states, the card surface —
/// this file draws one in the theme's tokens instead of importing another
/// language's widget, so the result still looks like iOS and no Material
/// control leaks into the screen.
///
/// One behaviour differs by design and is worth stating: iOS menus are
/// action sheets rising from the bottom, not popups. The contract keeps the
/// same entries, disabled and destructive semantics; only the presentation
/// follows the platform's convention.
class CupertinoComponents implements LiveDesignLanguageComponents {
  /// The Cupertino component set.
  const new();

  @override
  Widget button(BuildContext context, LiveButtonSpec spec) {
    final theme = LiveTheme.of(context);
    final geometry = theme.componentTheme;
    final interactive = spec.isInteractive;
    final onPressed = interactive ? spec.onPressed : null;
    return LiveFocusHighlight(
      focusNode: spec.focusNode,
      radius: geometry.controlRadius,
      enabled: interactive,
      scale: 1,
      childBuilder: (context, node) =>
          _CupertinoButtonBody(spec: spec, theme: theme, geometry: geometry, onPressed: onPressed, focusNode: node),
    );
  }

  @override
  Widget iconButton(BuildContext context, LiveIconButtonSpec spec) {
    final theme = LiveTheme.of(context);
    final geometry = theme.componentTheme;
    final interactive = spec.isInteractive;
    final color = switch (spec.variant) {
      LiveButtonVariant.primary => theme.colors.primary,
      LiveButtonVariant.danger => theme.colors.error,
      _ => spec.selected ? theme.colors.primary : theme.colors.textSecondary,
    };
    return LiveFocusHighlight(
      focusNode: spec.focusNode,
      radius: LiveRadii.pill,
      enabled: interactive,
      scale: 1,
      // iOS has no tooltip affordance for a pointer: the tooltip string
      // becomes the accessibility label instead of a hover bubble.
      childBuilder: (context, node) => Semantics(
        button: true,
        label: spec.tooltip,
        enabled: interactive,
        child: CupertinoButton(
          padding: EdgeInsets.zero,
          minimumSize: Size.square(geometry.heightFor(spec.size)),
          focusNode: node,
          autofocus: spec.autofocus,
          onPressed: interactive ? spec.onPressed : null,
          child: Icon(spec.icon, size: geometry.iconSize, color: interactive ? color : theme.colors.textDisabled),
        ),
      ),
    );
  }

  @override
  Widget textField(BuildContext context, LiveTextFieldSpec spec) {
    final theme = LiveTheme.of(context);
    final geometry = theme.componentTheme;
    return CupertinoTextField(
      controller: spec.controller,
      focusNode: spec.focusNode,
      enabled: spec.enabled,
      readOnly: spec.readOnly,
      autofocus: spec.autofocus,
      obscureText: spec.obscure,
      maxLines: spec.obscure ? 1 : spec.maxLines,
      keyboardType: spec.keyboardType,
      textInputAction: spec.textInputAction,
      onChanged: spec.onChanged,
      onSubmitted: spec.onSubmitted,
      style: theme.typography.body.copyWith(color: theme.colors.textPrimary),
      placeholder: spec.hint,
      placeholderStyle: theme.typography.body.copyWith(color: theme.colors.textDisabled),
      cursorColor: theme.colors.primary,
      padding: EdgeInsets.symmetric(horizontal: geometry.controlPadding, vertical: geometry.iconGap),
      decoration: BoxDecoration(
        color: theme.colors.surfaceVariant,
        borderRadius: BorderRadius.circular(geometry.inputRadius),
        border: Border.all(
          color: spec.errorText == null ? theme.colors.outline.withValues(alpha: 0.5) : theme.colors.error,
          width: geometry.inputBorderWidth,
        ),
      ),
      prefix: spec.prefixIcon == null
          ? null
          : Padding(
              padding: EdgeInsets.only(left: geometry.controlPadding),
              child: Icon(spec.prefixIcon, size: geometry.iconSize, color: theme.colors.textSecondary),
            ),
      suffix: spec.suffix,
    );
  }

  @override
  Widget searchField(BuildContext context, LiveSearchFieldSpec spec) {
    final theme = LiveTheme.of(context);
    final geometry = theme.componentTheme;
    return CupertinoSearchTextField(
      controller: spec.controller,
      focusNode: spec.focusNode,
      enabled: spec.enabled,
      autofocus: spec.autofocus,
      placeholder: spec.hint,
      onChanged: spec.onChanged,
      onSubmitted: spec.onSubmitted,
      onSuffixTap: spec.onClear,
      style: theme.typography.body.copyWith(color: theme.colors.textPrimary),
      placeholderStyle: theme.typography.body.copyWith(color: theme.colors.textDisabled),
      itemColor: theme.colors.textSecondary,
      backgroundColor: theme.colors.surfaceVariant,
      borderRadius: BorderRadius.circular(geometry.inputRadius),
      padding: EdgeInsets.symmetric(horizontal: geometry.controlPadding, vertical: geometry.iconGap),
    );
  }

  @override
  Widget card(BuildContext context, LiveCardSpec spec) {
    final theme = LiveTheme.of(context);
    final geometry = theme.componentTheme;
    final padding = spec.padding ?? (spec.dense ? geometry.cardPaddingDense : geometry.cardPadding);
    final body = Padding(padding: padding, child: spec.child);
    final surface = DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colors.surfaceElevated,
        borderRadius: BorderRadius.circular(geometry.cardRadius),
      ),
      child: body,
    );
    if (spec.onTap == null && spec.onLongPress == null) {
      return surface;
    }
    return LiveFocusHighlight(
      focusNode: spec.focusNode,
      radius: geometry.cardRadius,
      scale: 1,
      childBuilder: (context, node) => _CupertinoCardTap(
        focusNode: node,
        autofocus: spec.autofocus,
        onTap: spec.onTap,
        onLongPress: spec.onLongPress,
        radius: geometry.cardRadius,
        child: surface,
      ),
    );
  }

  /// An action sheet, iOS's convention for a menu of actions; see the class
  /// documentation for why it is not an anchored popup.
  @override
  Widget menu(BuildContext context, LiveMenuSpec spec) {
    final theme = LiveTheme.of(context);
    return _CupertinoMenuAnchor(spec: spec, theme: theme, child: spec.child);
  }

  @override
  Future<T?> dialog<T>(BuildContext context, LiveDialogSpec<T> spec) {
    final theme = LiveTheme.of(context);
    final dismissible = spec.barrierDismissible ?? spec.dismissible;
    return showCupertinoDialog<T>(
      context: context,
      barrierDismissible: dismissible,
      builder: (context) => CupertinoAlertDialog(
        title: spec.title == null ? null : Text(spec.title!, style: theme.typography.title),
        content: spec.content == null
            ? (spec.message == null
                  ? null
                  : Text(spec.message!, style: theme.typography.body.copyWith(color: theme.colors.textSecondary)))
            : DefaultTextStyle(
                style: theme.typography.body.copyWith(color: theme.colors.textSecondary),
                child: spec.content!,
              ),
        actions: [
          for (final LiveDialogAction<T> action in spec.actions)
            CupertinoDialogAction(
              onPressed: action.enabled ? () => Navigator.of(context).pop(action.result) : null,
              isDestructiveAction: action.variant == LiveButtonVariant.danger,
              child: Text(
                action.label,
                style: theme.typography.label.copyWith(
                  color: action.variant == LiveButtonVariant.danger
                      ? theme.colors.error
                      : action.enabled
                      ? theme.colors.primary
                      : theme.colors.textDisabled,
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// A [CupertinoActivityIndicator] when indeterminate, and a custom bar
  /// when a value is known — iOS ships no determinate progress control, so
  /// this draws one in the theme's colours rather than borrowing Material's.
  @override
  Widget progressIndicator(BuildContext context, LiveProgressIndicatorSpec spec) {
    final theme = LiveTheme.of(context);
    final value = spec.value;
    if (value == null) {
      final radius = switch (spec.size) {
        LiveControlSize.small => 8.0,
        LiveControlSize.medium => 11.0,
        LiveControlSize.large => 16.0,
      };
      return CupertinoActivityIndicator(radius: radius);
    }
    return Semantics(
      label: spec.semanticLabel,
      value: '${(value.clamp(0, 1) * 100).round()}%',
      child: _CupertinoProgressBar(value: value.clamp(0, 1), theme: theme, size: spec.size),
    );
  }

  @override
  Widget loadingView(BuildContext context, LiveLoadingViewSpec spec) {
    final theme = LiveTheme.of(context);
    final geometry = theme.componentTheme;
    final content = Column(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        progressIndicator(context, LiveProgressIndicatorSpec(value: spec.value)),
        if (spec.message case final message?) ...[
          SizedBox(height: geometry.sectionGap),
          Text(message, style: theme.typography.bodySmall.copyWith(color: theme.colors.textSecondary)),
        ],
      ],
    );
    return spec.compact ? Padding(padding: geometry.cardPadding, child: content) : Center(child: content);
  }

  /// A native-looking iOS error state; the retry button is a
  /// [CupertinoButton] rather than a Material one.
  @override
  Widget errorView(BuildContext context, LiveErrorViewSpec spec) {
    final theme = LiveTheme.of(context);
    final geometry = theme.componentTheme;
    final content = Column(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          spec.icon ?? CupertinoIcons.exclamationmark_circle,
          size: geometry.iconSize * 2,
          color: theme.colors.error,
        ),
        SizedBox(height: geometry.sectionGap),
        Text(
          spec.message,
          textAlign: TextAlign.center,
          style: theme.typography.body.copyWith(color: theme.colors.textPrimary),
        ),
        if (spec.canRetry) ...[
          SizedBox(height: geometry.sectionGap),
          CupertinoButton(
            padding: EdgeInsets.symmetric(horizontal: geometry.controlPadding),
            color: theme.colors.primary,
            onPressed: spec.onRetry,
            child: Text(
              spec.retryLabel ?? 'Retry',
              style: theme.typography.label.copyWith(color: theme.colors.onPrimary),
            ),
          ),
        ],
        if (spec.details case final details?) ...[
          SizedBox(height: geometry.sectionGap),
          Text(
            details,
            textAlign: TextAlign.center,
            style: theme.typography.caption.copyWith(color: theme.colors.textSecondary),
          ),
        ],
      ],
    );
    return spec.compact ? Padding(padding: geometry.cardPadding, child: content) : Center(child: content);
  }

  @override
  Widget emptyView(BuildContext context, LiveEmptyViewSpec spec) {
    final theme = LiveTheme.of(context);
    final geometry = theme.componentTheme;
    final content = Column(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(spec.icon ?? CupertinoIcons.tray, size: geometry.iconSize * 2, color: theme.colors.textDisabled),
        SizedBox(height: geometry.sectionGap),
        Text(
          spec.title,
          textAlign: TextAlign.center,
          style: theme.typography.title.copyWith(color: theme.colors.textPrimary),
        ),
        if (spec.message case final message?) ...[
          SizedBox(height: geometry.iconGap),
          Text(
            message,
            textAlign: TextAlign.center,
            style: theme.typography.bodySmall.copyWith(color: theme.colors.textSecondary),
          ),
        ],
        if (spec.action case final action?) ...[SizedBox(height: geometry.sectionGap), action],
      ],
    );
    return spec.compact ? Padding(padding: geometry.cardPadding, child: content) : Center(child: content);
  }
}

/// The button body: a [CupertinoButton] for the text and outline variants
/// and a filled capsule for the emphasised ones, matching iOS's filled and
/// plain button styles.
class _CupertinoButtonBody extends StatelessWidget {
  const new({
    required this.spec,
    required this.theme,
    required this.geometry,
    required this.onPressed,
    required this.focusNode,
  });

  final LiveButtonSpec spec;
  final LiveTheme theme;
  final LiveComponentTheme geometry;
  final VoidCallback? onPressed;
  final FocusNode focusNode;

  @override
  Widget build(BuildContext context) {
    final colors = theme.colors;
    final (color, foreground, filled) = switch (spec.variant) {
      LiveButtonVariant.primary => (colors.primary, colors.onPrimary, true),
      LiveButtonVariant.secondary => (colors.surfaceVariant, colors.textPrimary, true),
      LiveButtonVariant.danger => (colors.error, colors.onError, true),
      LiveButtonVariant.outline => (colors.outline, colors.textPrimary, false),
      LiveButtonVariant.text => (null, colors.primary, false),
    };
    final label = spec.loading
        ? SizedBox.square(
            dimension: geometry.iconSize,
            child: CupertinoActivityIndicator(radius: geometry.iconSize / 2.4, color: foreground),
          )
        : _content(foreground);
    final fill = color;
    final button = CupertinoButton(
      minimumSize: Size(0, geometry.heightFor(spec.size)),
      padding: EdgeInsets.symmetric(horizontal: geometry.controlPadding),
      borderRadius: BorderRadius.circular(geometry.controlRadius),
      color: filled && fill != null ? fill : const Color(0x00000000),
      disabledColor: fill?.withValues(alpha: 0.4) ?? const Color(0x00000000),
      focusNode: focusNode,
      autofocus: spec.autofocus,
      onPressed: onPressed,
      child: DefaultTextStyle(
        style: theme.typography.label.copyWith(color: foreground),
        child: Semantics(label: spec.semanticLabel, button: true, enabled: spec.isInteractive, child: label),
      ),
    );
    final bordered = filled
        ? button
        : DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(LiveRadii.sm),
              border: spec.variant == LiveButtonVariant.outline ? Border.all(color: colors.outline) : null,
            ),
            child: button,
          );
    return spec.expand ? SizedBox(width: double.infinity, child: bordered) : bordered;
  }

  Widget _content(Color foreground) {
    final label = Text(
      spec.label,
      style: theme.typography.label.copyWith(color: foreground),
      overflow: TextOverflow.ellipsis,
    );
    if (spec.icon == null) {
      return label;
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(spec.icon, size: geometry.iconSize, color: foreground),
        SizedBox(width: geometry.iconGap),
        Flexible(child: label),
      ],
    );
  }
}

/// A tappable card surface with iOS's press feedback.
class _CupertinoCardTap extends StatefulWidget {
  const new({
    required this.child,
    required this.focusNode,
    required this.radius,
    this.onTap,
    this.onLongPress,
    this.autofocus = false,
  });

  final Widget child;
  final FocusNode focusNode;
  final double radius;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final bool autofocus;

  @override
  State<_CupertinoCardTap> createState() => _CupertinoCardTapState();
}

class _CupertinoCardTapState extends State<_CupertinoCardTap> {
  bool _pressed = false;

  void _setPressed(bool pressed) {
    if (_pressed != pressed) {
      setState(() => _pressed = pressed);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 100),
      opacity: _pressed ? 0.7 : 1,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        onTapDown: widget.onTap == null ? null : (_) => _setPressed(true),
        onTapUp: widget.onTap == null ? null : (_) => _setPressed(false),
        onTapCancel: widget.onTap == null ? null : () => _setPressed(false),
        onLongPress: widget.onLongPress,
        child: ClipRRect(borderRadius: BorderRadius.circular(widget.radius), child: widget.child),
      ),
    );
  }
}

/// The action-sheet menu anchor.
class _CupertinoMenuAnchor extends StatelessWidget {
  const new({required this.spec, required this.theme, required this.child});

  final LiveMenuSpec spec;
  final LiveTheme theme;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LiveFocusHighlight(
      focusNode: spec.focusNode,
      radius: LiveRadii.md,
      scale: 1,
      enabled: spec.enabled,
      childBuilder: (context, node) => CupertinoButton(
        padding: EdgeInsets.zero,
        minimumSize: Size.zero,
        focusNode: node,
        onPressed: spec.enabled ? () => _show(context) : null,
        child: child,
      ),
    );
  }

  Future<void> _show(BuildContext context) async {
    final chosen = await showCupertinoModalPopup<String>(
      context: context,
      builder: (context) => CupertinoActionSheet(
        title: spec.tooltip == null ? null : Text(spec.tooltip!, style: theme.typography.bodySmall),
        actions: [
          for (final entry in spec.entries)
            // iOS action sheets have no disabled action, so a disabled entry
            // keeps its place, is dimmed and does nothing when chosen.
            CupertinoActionSheetAction(
              isDestructiveAction: entry.danger,
              onPressed: entry.enabled ? () => Navigator.of(context).pop(entry.id) : () {},
              child: Semantics(
                enabled: entry.enabled,
                child: Text(
                  entry.label,
                  style: theme.typography.body.copyWith(
                    color: entry.danger
                        ? theme.colors.error
                        : entry.enabled
                        ? theme.colors.primary
                        : theme.colors.textDisabled,
                  ),
                ),
              ),
            ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.of(context).pop(),
          child: Text('Cancel', style: theme.typography.body),
        ),
      ),
    );
    if (chosen != null) {
      spec.onSelected(chosen);
    }
  }
}

/// A determinate progress bar in the theme's colours.
class _CupertinoProgressBar extends StatelessWidget {
  const new({required this.value, required this.theme, required this.size});

  final double value;
  final LiveTheme theme;
  final LiveControlSize size;

  @override
  Widget build(BuildContext context) {
    final height = switch (size) {
      LiveControlSize.small => 3.0,
      LiveControlSize.medium => 4.0,
      LiveControlSize.large => 6.0,
    };
    return SizedBox(
      width: theme.componentTheme.dialogMaxWidth * 0.5,
      height: height,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: theme.colors.surfaceVariant,
          borderRadius: BorderRadius.circular(LiveRadii.pill),
        ),
        child: FractionallySizedBox(
          alignment: Alignment.centerLeft,
          widthFactor: value,
          child: DecoratedBox(
            decoration: BoxDecoration(color: theme.colors.primary, borderRadius: BorderRadius.circular(LiveRadii.pill)),
          ),
        ),
      ),
    );
  }
}
