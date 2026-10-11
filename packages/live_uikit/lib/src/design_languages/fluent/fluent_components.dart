import 'package:fluent_ui/fluent_ui.dart' as fluent;
import 'package:flutter/services.dart' show TextInputAction;
import 'package:flutter/widgets.dart';

import 'package:live_uikit/src/components/contracts/live_component_specs.dart';
import 'package:live_uikit/src/components/contracts/live_design_language_components.dart';
import 'package:live_uikit/src/focus/live_focus_highlight.dart';
import 'package:live_uikit/src/theme/live_component_theme.dart';
import 'package:live_uikit/src/theme/live_theme.dart';
import 'package:live_uikit/src/tokens/radii.dart';

/// The Fluent implementation of the component contract.
///
/// Fluent controls assert that a Fluent theme is above them, so every
/// method wraps its result in one built from the active tokens —
/// that is why this file contains no `FluentApp` and the application still
/// installs only one theme scope: the language brings its library theme with
/// its controls, the way the Cupertino language brings its styling with its
/// controls.
///
/// Windows conventions show through deliberately: an accent-filled
/// [fluent.FilledButton] for the primary action, a standard
/// [fluent.Button] for the rest, a [fluent.ContentDialog] for dialogs and a
/// [fluent.MenuFlyout] for menus.
class FluentComponents implements LiveDesignLanguageComponents {
  /// The Fluent component set.
  const new();

  /// The Fluent theme built from [theme]'s tokens.
  ///
  /// Exposed because the composition root needs it around its navigation
  /// shell as well: a `NavigationView` outside a `FluentTheme` asserts.
  static fluent.FluentThemeData themeDataOf(LiveTheme theme) => fluent.FluentThemeData(
    brightness: theme.brightness,
    accentColor: fluent.AccentColor.swatch({
      'darkest': _shift(theme.colors.primary, -0.35),
      'darker': _shift(theme.colors.primary, -0.2),
      'dark': _shift(theme.colors.primary, -0.1),
      'normal': theme.colors.primary,
      'light': _shift(theme.colors.primary, 0.15),
      'lighter': _shift(theme.colors.primary, 0.3),
      'lightest': _shift(theme.colors.primary, 0.45),
    }),
    scaffoldBackgroundColor: theme.colors.surface,
    cardColor: theme.colors.surfaceElevated,
    menuColor: theme.colors.surfaceElevated,
    activeColor: theme.colors.primary,
    inactiveColor: theme.colors.textSecondary,
    shadowColor: theme.colors.shadow,
    fontFamily: theme.typography.fontFamily,
  );

  static Color _shift(Color color, double amount) {
    final target = amount < 0 ? const Color(0xFF000000) : const Color(0xFFFFFFFF);
    return Color.lerp(color, target, amount.abs()) ?? color;
  }

  /// Wraps [child] in the Fluent theme the controls below it require.
  static Widget scoped(LiveTheme theme, Widget child) => fluent.FluentTheme(data: themeDataOf(theme), child: child);

  @override
  Widget button(BuildContext context, LiveButtonSpec spec) {
    final theme = LiveTheme.of(context);
    final geometry = theme.componentTheme;
    final interactive = spec.isInteractive;
    final onPressed = interactive ? spec.onPressed : null;
    final content = _buttonContent(theme, spec);
    return scoped(
      theme,
      LiveFocusHighlight(
        focusNode: spec.focusNode,
        radius: geometry.controlRadius,
        enabled: interactive,
        scale: 1,
        childBuilder: (context, node) {
          final style = fluent.ButtonStyle(
            padding: fluent.WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: geometry.controlPadding)),
            shape: fluent.WidgetStatePropertyAll(
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(geometry.controlRadius)),
            ),
            textStyle: fluent.WidgetStatePropertyAll(theme.typography.label),
          );
          final button = switch (spec.variant) {
            LiveButtonVariant.primary => fluent.FilledButton(
              onPressed: onPressed,
              focusNode: node,
              autofocus: spec.autofocus,
              style: style,
              child: content,
            ),
            LiveButtonVariant.danger => fluent.FilledButton(
              onPressed: onPressed,
              focusNode: node,
              autofocus: spec.autofocus,
              style: style.copyWith(backgroundColor: fluent.WidgetStatePropertyAll(theme.colors.error)),
              child: content,
            ),
            LiveButtonVariant.outline => fluent.OutlinedButton(
              onPressed: onPressed,
              focusNode: node,
              autofocus: spec.autofocus,
              style: style,
              child: content,
            ),
            LiveButtonVariant.secondary => fluent.Button(
              onPressed: onPressed,
              focusNode: node,
              autofocus: spec.autofocus,
              style: style,
              child: content,
            ),
            // Fluent has no bare text button; the standard button with a
            // transparent fill is what Windows uses for a low-emphasis
            // action next to content.
            LiveButtonVariant.text => fluent.Button(
              onPressed: onPressed,
              focusNode: node,
              autofocus: spec.autofocus,
              style: style.copyWith(backgroundColor: const fluent.WidgetStatePropertyAll(Color(0x00000000))),
              child: content,
            ),
          };
          final sized = ConstrainedBox(
            constraints: BoxConstraints(minHeight: geometry.heightFor(spec.size)),
            child: button,
          );
          return spec.expand ? SizedBox(width: double.infinity, child: sized) : sized;
        },
      ),
    );
  }

  @override
  Widget iconButton(BuildContext context, LiveIconButtonSpec spec) {
    final theme = LiveTheme.of(context);
    final geometry = theme.componentTheme;
    final interactive = spec.isInteractive;
    return scoped(
      theme,
      LiveFocusHighlight(
        focusNode: spec.focusNode,
        radius: LiveRadii.pill,
        enabled: interactive,
        scale: 1,
        childBuilder: (context, node) => fluent.IconButton(
          onPressed: interactive ? spec.onPressed : null,
          focusNode: node,
          autofocus: spec.autofocus,
          icon: Icon(
            spec.icon,
            size: geometry.iconSize,
            color: interactive
                ? (spec.selected ? theme.colors.primary : theme.colors.textSecondary)
                : theme.colors.textDisabled,
          ),
        ),
      ),
    );
  }

  @override
  Widget textField(BuildContext context, LiveTextFieldSpec spec) {
    final theme = LiveTheme.of(context);
    final geometry = theme.componentTheme;
    return scoped(
      theme,
      fluent.TextBox(
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
        padding: EdgeInsets.symmetric(horizontal: geometry.controlPadding, vertical: geometry.iconGap),
        foregroundDecoration: spec.errorText == null
            ? null
            : fluent.WidgetStatePropertyAll(
                BoxDecoration(
                  border: Border.all(color: theme.colors.error, width: geometry.inputBorderWidth),
                  borderRadius: BorderRadius.circular(geometry.inputRadius),
                ),
              ),
        prefix: spec.prefixIcon == null
            ? null
            : Icon(spec.prefixIcon, size: geometry.iconSize, color: theme.colors.textSecondary),
        suffix: spec.suffix,
      ),
    );
  }

  @override
  Widget searchField(BuildContext context, LiveSearchFieldSpec spec) {
    final theme = LiveTheme.of(context);
    final geometry = theme.componentTheme;
    return scoped(
      theme,
      fluent.TextBox(
        controller: spec.controller,
        focusNode: spec.focusNode,
        enabled: spec.enabled,
        autofocus: spec.autofocus,
        textInputAction: TextInputAction.search,
        onChanged: spec.onChanged,
        onSubmitted: spec.onSubmitted,
        style: theme.typography.body.copyWith(color: theme.colors.textPrimary),
        placeholder: spec.hint,
        padding: EdgeInsets.symmetric(horizontal: geometry.controlPadding, vertical: geometry.iconGap),
        prefix: Icon(fluent.FluentIcons.search, size: geometry.iconSize, color: theme.colors.textSecondary),
        suffix: spec.onClear == null
            ? null
            : fluent.IconButton(
                onPressed: spec.onClear,
                icon: Icon(fluent.FluentIcons.clear, size: geometry.iconSize, color: theme.colors.textSecondary),
              ),
      ),
    );
  }

  @override
  Widget card(BuildContext context, LiveCardSpec spec) {
    final theme = LiveTheme.of(context);
    final geometry = theme.componentTheme;
    final padding = spec.padding ?? (spec.dense ? geometry.cardPaddingDense : geometry.cardPadding);
    final surface = fluent.Card(
      padding: padding,
      backgroundColor: theme.colors.surfaceElevated,
      borderRadius: BorderRadius.circular(geometry.cardRadius),
      child: spec.child,
    );
    if (spec.onTap == null && spec.onLongPress == null) {
      return scoped(theme, surface);
    }
    return scoped(
      theme,
      LiveFocusHighlight(
        focusNode: spec.focusNode,
        radius: geometry.cardRadius,
        scale: 1,
        childBuilder: (context, node) => fluent.HoverButton(
          focusNode: node,
          autofocus: spec.autofocus,
          onPressed: spec.onTap,
          onLongPress: spec.onLongPress,
          builder: (context, states) => AnimatedOpacity(
            duration: theme.fast,
            opacity: states.contains(WidgetState.pressed) ? 0.7 : 1,
            child: surface,
          ),
        ),
      ),
    );
  }

  @override
  Widget menu(BuildContext context, LiveMenuSpec spec) {
    final theme = LiveTheme.of(context);
    final geometry = theme.componentTheme;
    return scoped(theme, _FluentMenuAnchor(spec: spec, theme: theme, geometry: geometry));
  }

  @override
  Future<T?> dialog<T>(BuildContext context, LiveDialogSpec<T> spec) {
    final theme = LiveTheme.of(context);
    final dismissible = spec.barrierDismissible ?? spec.dismissible;
    return fluent.showDialog<T>(
      context: context,
      barrierDismissible: dismissible,
      barrierColor: theme.colors.scrim.withValues(alpha: 0.55),
      builder: (context) => scoped(
        theme,
        fluent.ContentDialog(
          title: spec.title == null ? null : Text(spec.title!, style: theme.typography.title),
          content: spec.content == null
              ? (spec.message == null
                    ? null
                    : Text(spec.message!, style: theme.typography.body.copyWith(color: theme.colors.textSecondary)))
              : DefaultTextStyle(
                  style: theme.typography.body.copyWith(color: theme.colors.textSecondary),
                  child: spec.content!,
                ),
          constraints: BoxConstraints(maxWidth: spec.maxWidth),
          actions: [
            for (final LiveDialogAction<T> action in spec.actions)
              switch (action.variant) {
                LiveButtonVariant.primary => fluent.FilledButton(
                  onPressed: action.enabled ? () => Navigator.of(context).pop(action.result) : null,
                  autofocus: action.autofocus,
                  child: Text(action.label),
                ),
                LiveButtonVariant.danger => fluent.FilledButton(
                  onPressed: action.enabled ? () => Navigator.of(context).pop(action.result) : null,
                  autofocus: action.autofocus,
                  style: const fluent.ButtonStyle(backgroundColor: fluent.WidgetStatePropertyAll(Color(0xFFC42B1C))),
                  child: Text(action.label),
                ),
                _ => fluent.Button(
                  onPressed: action.enabled ? () => Navigator.of(context).pop(action.result) : null,
                  autofocus: action.autofocus,
                  child: Text(action.label),
                ),
              },
          ],
        ),
      ),
    );
  }

  @override
  Widget progressIndicator(BuildContext context, LiveProgressIndicatorSpec spec) {
    final theme = LiveTheme.of(context);
    final size = switch (spec.size) {
      LiveControlSize.small => theme.componentTheme.loadingIndicatorSize * 0.75,
      LiveControlSize.medium => theme.componentTheme.loadingIndicatorSize,
      LiveControlSize.large => theme.componentTheme.loadingIndicatorSize * 1.5,
    };
    return scoped(
      theme,
      Semantics(
        label: spec.semanticLabel,
        child: SizedBox.square(
          dimension: size,
          child: spec.value == null
              ? fluent.ProgressRing(strokeWidth: 2.5, activeColor: theme.colors.primary)
              : fluent.ProgressBar(
                  value: spec.value!.clamp(0, 1) * 100,
                  strokeWidth: 4,
                  backgroundColor: theme.colors.surfaceVariant,
                  activeColor: theme.colors.primary,
                ),
        ),
      ),
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

  @override
  Widget errorView(BuildContext context, LiveErrorViewSpec spec) {
    final theme = LiveTheme.of(context);
    final geometry = theme.componentTheme;
    final content = Column(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(spec.icon ?? fluent.FluentIcons.error, size: geometry.iconSize * 2, color: theme.colors.error),
        SizedBox(height: geometry.sectionGap),
        Text(
          spec.message,
          textAlign: TextAlign.center,
          style: theme.typography.body.copyWith(color: theme.colors.textPrimary),
        ),
        if (spec.canRetry) ...[
          SizedBox(height: geometry.sectionGap),
          button(
            context,
            LiveButtonSpec(
              label: spec.retryLabel ?? 'Retry',
              icon: fluent.FluentIcons.refresh,
              onPressed: spec.onRetry,
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
        Icon(spec.icon ?? fluent.FluentIcons.folder, size: geometry.iconSize * 2, color: theme.colors.textDisabled),
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

  Widget _buttonContent(LiveTheme theme, LiveButtonSpec spec) {
    final geometry = theme.componentTheme;
    if (spec.loading) {
      return SizedBox.square(
        dimension: geometry.iconSize,
        child: fluent.ProgressRing(strokeWidth: 2, activeColor: theme.colors.textPrimary),
      );
    }
    final label = Text(spec.label, overflow: TextOverflow.ellipsis);
    if (spec.icon == null) {
      return Semantics(label: spec.semanticLabel, button: true, enabled: spec.isInteractive, child: label);
    }
    return Semantics(
      label: spec.semanticLabel,
      button: true,
      enabled: spec.isInteractive,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(spec.icon, size: geometry.iconSize),
          SizedBox(width: geometry.iconGap),
          Flexible(child: label),
        ],
      ),
    );
  }
}

/// The menu anchor: a Fluent flyout attached to the anchor widget and
/// opened by its controller, which is how Fluent menus are shown — there is
/// no `MenuFlyout(child:)` in the library.
class _FluentMenuAnchor extends StatefulWidget {
  const new({required this.spec, required this.theme, required this.geometry});

  final LiveMenuSpec spec;
  final LiveTheme theme;
  final LiveComponentTheme geometry;

  @override
  State<_FluentMenuAnchor> createState() => _FluentMenuAnchorState();
}

class _FluentMenuAnchorState extends State<_FluentMenuAnchor> {
  final fluent.FlyoutController _controller = fluent.FlyoutController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _show() => _controller.showFlyout<void>(
    placementMode: fluent.FlyoutPlacementMode.bottomLeft,
    builder: (context) => fluent.MenuFlyout(
      color: widget.theme.colors.surfaceElevated,
      items: [
        for (final entry in widget.spec.entries)
          fluent.MenuFlyoutItem(
            text: Text(
              entry.label,
              style: widget.theme.typography.body.copyWith(
                color: entry.danger
                    ? widget.theme.colors.error
                    : entry.enabled
                    ? widget.theme.colors.textPrimary
                    : widget.theme.colors.textDisabled,
              ),
            ),
            leading: entry.icon == null ? null : Icon(entry.icon, size: widget.geometry.iconSize),
            trailing: entry.shortcut == null ? null : Text(entry.shortcut!, style: widget.theme.typography.caption),
            onPressed: entry.enabled ? () => widget.spec.onSelected(entry.id) : null,
          ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) => LiveFocusHighlight(
    focusNode: widget.spec.focusNode,
    radius: widget.geometry.controlRadius,
    scale: 1,
    enabled: widget.spec.enabled,
    childBuilder: (context, node) => fluent.FlyoutTarget(
      controller: _controller,
      child: GestureDetector(
        onTap: widget.spec.enabled ? _show : null,
        child: Semantics(
          button: true,
          enabled: widget.spec.enabled,
          label: widget.spec.tooltip,
          child: widget.spec.child,
        ),
      ),
    ),
  );
}
