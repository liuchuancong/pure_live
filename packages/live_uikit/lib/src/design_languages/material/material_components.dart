import 'package:flutter/material.dart';

import 'package:live_uikit/src/components/contracts/live_component_specs.dart';
import 'package:live_uikit/src/components/contracts/live_design_language_components.dart';
import 'package:live_uikit/src/focus/live_focus_highlight.dart';
import 'package:live_uikit/src/theme/live_component_theme.dart';
import 'package:live_uikit/src/theme/live_theme.dart';
import 'package:live_uikit/src/tokens/radii.dart';
import 'package:live_uikit/src/tokens/sizing.dart';
import 'package:live_uikit/src/tokens/spacing.dart';

/// The Material implementation of the component contract.
///
/// Every method here is the same *semantic* component the contract
/// describes, rendered with Material widgets and the tokens from the
/// active [LiveTheme] — so a Material button on a Neumorphic build is never
/// a possibility, because this class is only reached when Material is the
/// active language.
class MaterialComponents implements LiveDesignLanguageComponents {
  /// The Material component set.
  const new();

  @override
  Widget button(BuildContext context, LiveButtonSpec spec) {
    final theme = LiveTheme.of(context);
    final geometry = theme.componentTheme;
    final colors = theme.colors;
    final interactive = spec.isInteractive;
    final (background, foreground, border) = switch (spec.variant) {
      LiveButtonVariant.primary => (colors.primary, colors.onPrimary, null),
      LiveButtonVariant.secondary => (colors.surfaceVariant, colors.textPrimary, null),
      LiveButtonVariant.outline => (null, colors.textPrimary, colors.outline),
      LiveButtonVariant.text => (null, colors.primary, null),
      LiveButtonVariant.danger => (colors.error, colors.onError, null),
    };
    return LiveFocusHighlight(
      focusNode: spec.focusNode,
      radius: LiveRadii.sm,
      enabled: interactive,
      autofocus: spec.autofocus,
      childBuilder: (context, node) {
        final content = _buttonContent(context, spec, foreground, geometry.iconSize, geometry.iconGap);
        final style = ButtonStyle(
          backgroundColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.disabled) ? background?.withValues(alpha: 0.4) : background,
          ),
          foregroundColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.disabled) ? colors.textDisabled : foreground,
          ),
          overlayColor: WidgetStatePropertyAll(colors.focus.withValues(alpha: 0.12)),
          elevation: const WidgetStatePropertyAll(0),
          padding: WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: geometry.controlPadding)),
          minimumSize: WidgetStatePropertyAll(Size(0, geometry.heightFor(spec.size))),
          maximumSize: const WidgetStatePropertyAll(Size.infinite),
          shape: const WidgetStatePropertyAll(
            RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(LiveRadii.sm))),
          ),
          textStyle: WidgetStatePropertyAll(theme.typography.label.copyWith(color: foreground)),
          side: border == null ? null : WidgetStatePropertyAll(BorderSide(color: border)),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        );
        final onPressed = interactive ? spec.onPressed : null;
        final button = switch (spec.variant) {
          LiveButtonVariant.primary ||
          LiveButtonVariant.secondary ||
          LiveButtonVariant.danger => FilledButton(style: style, onPressed: onPressed, focusNode: node, child: content),
          LiveButtonVariant.outline => OutlinedButton(
            style: style,
            onPressed: onPressed,
            focusNode: node,
            child: content,
          ),
          LiveButtonVariant.text => TextButton(style: style, onPressed: onPressed, focusNode: node, child: content),
        };
        return _tappable(spec, button);
      },
    );
  }

  @override
  Widget iconButton(BuildContext context, LiveIconButtonSpec spec) {
    final theme = LiveTheme.of(context);
    final geometry = theme.componentTheme;
    final colors = theme.colors;
    final interactive = spec.isInteractive;
    final (background, foreground) = switch (spec.variant) {
      LiveButtonVariant.primary => (colors.primary, colors.onPrimary),
      LiveButtonVariant.secondary => (colors.surfaceVariant, colors.textPrimary),
      LiveButtonVariant.outline => (null, colors.textPrimary),
      LiveButtonVariant.text => (null, colors.textSecondary),
      LiveButtonVariant.danger => (colors.error, colors.onError),
    };
    final selectedForeground = spec.selected ? colors.primary : foreground;
    return LiveFocusHighlight(
      focusNode: spec.focusNode,
      radius: LiveRadii.pill,
      enabled: interactive,
      autofocus: spec.autofocus,
      childBuilder: (context, node) => Tooltip(
        message: spec.tooltip,
        child: IconButton(
          onPressed: interactive ? spec.onPressed : null,
          focusNode: node,
          style: ButtonStyle(
            backgroundColor: WidgetStateProperty.resolveWith(
              (states) => states.contains(WidgetState.disabled) ? background?.withValues(alpha: 0.4) : background,
            ),
            foregroundColor: WidgetStateProperty.resolveWith(
              (states) => states.contains(WidgetState.disabled) ? colors.textDisabled : selectedForeground,
            ),
            overlayColor: WidgetStatePropertyAll(colors.focus.withValues(alpha: 0.12)),
            minimumSize: WidgetStatePropertyAll(Size.square(geometry.heightFor(spec.size))),
            shape: const WidgetStatePropertyAll(CircleBorder()),
          ),
          icon: Icon(spec.icon, size: geometry.iconSize, semanticLabel: spec.tooltip),
        ),
      ),
    );
  }

  @override
  Widget textField(BuildContext context, LiveTextFieldSpec spec) {
    final theme = LiveTheme.of(context);
    final geometry = theme.componentTheme;
    return TextField(
      controller: spec.controller,
      focusNode: spec.focusNode,
      enabled: spec.enabled,
      autofocus: spec.autofocus,
      readOnly: spec.readOnly,
      obscureText: spec.obscure,
      maxLines: spec.obscure ? 1 : spec.maxLines,
      keyboardType: spec.keyboardType,
      textInputAction: spec.textInputAction,
      onChanged: spec.onChanged,
      onSubmitted: spec.onSubmitted,
      style: theme.typography.body.copyWith(color: theme.colors.textPrimary),
      decoration: InputDecoration(
        labelText: spec.label,
        hintText: spec.hint,
        errorText: spec.errorText,
        prefixIcon: spec.prefixIcon == null ? null : Icon(spec.prefixIcon, size: geometry.iconSize),
        suffixIcon: spec.suffix,
      ),
    );
  }

  @override
  Widget searchField(BuildContext context, LiveSearchFieldSpec spec) => _MaterialSearchField(spec: spec);

  @override
  Widget card(BuildContext context, LiveCardSpec spec) {
    final theme = LiveTheme.of(context);
    final geometry = theme.componentTheme;
    final padding = spec.padding ?? (spec.dense ? geometry.cardPaddingDense : geometry.cardPadding);
    final body = Padding(padding: padding, child: spec.child);
    if (spec.onTap == null && spec.onLongPress == null) {
      return Material(
        color: theme.colors.surfaceElevated,
        borderRadius: BorderRadius.circular(geometry.cardRadius),
        elevation: geometry.cardElevation,
        child: body,
      );
    }
    return LiveFocusHighlight(
      focusNode: spec.focusNode,
      radius: geometry.cardRadius,
      autofocus: spec.autofocus,
      childBuilder: (context, node) => Material(
        color: theme.colors.surfaceElevated,
        borderRadius: BorderRadius.circular(geometry.cardRadius),
        elevation: spec.selected ? geometry.cardElevation + 2 : geometry.cardElevation,
        child: InkWell(
          onTap: spec.onTap,
          onLongPress: spec.onLongPress,
          focusNode: node,
          borderRadius: BorderRadius.circular(geometry.cardRadius),
          overlayColor: WidgetStatePropertyAll(theme.colors.focus.withValues(alpha: 0.1)),
          child: body,
        ),
      ),
    );
  }

  @override
  Widget menu(BuildContext context, LiveMenuSpec spec) {
    final theme = LiveTheme.of(context);
    final geometry = theme.componentTheme;
    return PopupMenuButton<String>(
      enabled: spec.enabled,
      tooltip: spec.tooltip,
      onSelected: spec.onSelected,
      position: PopupMenuPosition.under,
      color: theme.colors.surfaceElevated,
      elevation: 8,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(geometry.menuRadius)),
      constraints: BoxConstraints(minWidth: 180, maxWidth: geometry.dialogMaxWidth),
      itemBuilder: (context) => [
        for (final entry in spec.entries)
          PopupMenuItem<String>(
            value: entry.id,
            enabled: entry.enabled,
            height: geometry.menuItemHeight,
            padding: geometry.menuItemPadding,
            child: _menuRow(context, entry),
          ),
      ],
      child: spec.child,
    );
  }

  @override
  Future<T?> dialog<T>(BuildContext context, LiveDialogSpec<T> spec) {
    final theme = LiveTheme.of(context);
    final geometry = theme.componentTheme;
    final dismissible = spec.barrierDismissible ?? spec.dismissible;
    return showDialog<T>(
      context: context,
      barrierDismissible: dismissible,
      barrierColor: theme.colors.scrim.withValues(alpha: 0.55),
      builder: (context) => _MaterialDialog<T>(spec: spec, geometry: geometry, theme: theme),
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
    return SizedBox.square(
      dimension: size,
      child: CircularProgressIndicator(
        value: spec.value,
        strokeWidth: 2.5,
        color: theme.colors.primary,
        semanticsLabel: spec.semanticLabel,
      ),
    );
  }

  @override
  Widget loadingView(BuildContext context, LiveLoadingViewSpec spec) {
    final theme = LiveTheme.of(context);
    final indicator = progressIndicator(context, LiveProgressIndicatorSpec(value: spec.value));
    final content = Column(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        indicator,
        if (spec.message case final message?) ...[
          SizedBox(height: theme.componentTheme.sectionGap),
          Text(message, style: theme.typography.bodySmall.copyWith(color: theme.colors.textSecondary)),
        ],
      ],
    );
    return spec.compact ? Padding(padding: theme.componentTheme.cardPadding, child: content) : Center(child: content);
  }

  @override
  Widget errorView(BuildContext context, LiveErrorViewSpec spec) {
    final theme = LiveTheme.of(context);
    final geometry = theme.componentTheme;
    final content = Column(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(spec.icon ?? Icons.error_outline, size: geometry.iconSize * 2, color: theme.colors.error),
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
              variant: LiveButtonVariant.outline,
              icon: Icons.refresh,
              onPressed: spec.onRetry,
            ),
          ),
        ],
        if (spec.details case final details?) ...[
          SizedBox(height: geometry.sectionGap),
          _DetailsExpander(details: details),
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
        Icon(spec.icon ?? Icons.inbox_outlined, size: geometry.iconSize * 2, color: theme.colors.textDisabled),
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

  Widget _menuRow(BuildContext context, LiveMenuEntry entry) {
    final theme = LiveTheme.of(context);
    final color = entry.danger
        ? theme.colors.error
        : entry.enabled
        ? theme.colors.textPrimary
        : theme.colors.textDisabled;
    return Row(
      children: [
        if (entry.icon case final icon?) ...[
          Icon(icon, size: theme.componentTheme.iconSize, color: color),
          SizedBox(width: theme.componentTheme.iconGap),
        ],
        Expanded(
          child: Text(
            entry.label,
            style: theme.typography.body.copyWith(color: color),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (entry.selected) ...[
          SizedBox(width: theme.componentTheme.iconGap),
          Icon(Icons.check, size: theme.componentTheme.iconSize, color: theme.colors.primary),
        ],
        if (entry.shortcut case final shortcut?) ...[
          SizedBox(width: theme.componentTheme.iconGap),
          Text(shortcut, style: theme.typography.caption.copyWith(color: theme.colors.textSecondary)),
        ],
      ],
    );
  }

  Widget _buttonContent(BuildContext context, LiveButtonSpec spec, Color? foreground, double iconSize, double gap) {
    final theme = LiveTheme.of(context);
    if (spec.loading) {
      return SizedBox.square(
        dimension: iconSize,
        child: CircularProgressIndicator(strokeWidth: 2, color: foreground ?? theme.colors.textPrimary),
      );
    }
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
        Icon(spec.icon, size: iconSize, color: foreground),
        SizedBox(width: gap),
        Flexible(child: label),
      ],
    );
  }

  Widget _tappable(LiveButtonSpec spec, Widget child) => Semantics(
    label: spec.semanticLabel,
    button: true,
    enabled: spec.isInteractive,
    child: spec.expand ? SizedBox(width: double.infinity, child: child) : child,
  );
}

/// The search field's Material implementation: a text field with the
/// search chrome and a clear button that appears once there is text.
class _MaterialSearchField extends StatefulWidget {
  const new({required this.spec});

  final LiveSearchFieldSpec spec;

  @override
  State<_MaterialSearchField> createState() => _MaterialSearchFieldState();
}

class _MaterialSearchFieldState extends State<_MaterialSearchField> {
  TextEditingController? _owned;
  bool _filled = false;

  TextEditingController get _controller => widget.spec.controller ?? (_owned ??= TextEditingController());

  @override
  void initState() {
    super.initState();
    _filled = _controller.text.isNotEmpty;
    _controller.addListener(_onText);
  }

  void _onText() {
    final filled = _controller.text.isNotEmpty;
    if (filled != _filled) {
      setState(() => _filled = filled);
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_onText);
    _owned?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final spec = widget.spec;
    return const MaterialComponents().textField(
      context,
      LiveTextFieldSpec(
        controller: _controller,
        focusNode: spec.focusNode,
        hint: spec.hint,
        prefixIcon: Icons.search,
        enabled: spec.enabled,
        autofocus: spec.autofocus,
        textInputAction: TextInputAction.search,
        suffix: _filled
            ? IconButton(
                icon: const Icon(Icons.close),
                tooltip: 'Clear',
                onPressed: () {
                  _controller.clear();
                  spec.onChanged?.call('');
                  spec.onClear?.call();
                },
              )
            : null,
        onChanged: spec.onChanged,
        onSubmitted: spec.onSubmitted,
      ),
    );
  }
}

/// The dialog's Material implementation.
class _MaterialDialog<T> extends StatelessWidget {
  const new({required this.spec, required this.geometry, required this.theme});

  final LiveDialogSpec<T> spec;
  final LiveComponentTheme geometry;
  final LiveTheme theme;

  @override
  Widget build(BuildContext context) {
    final content = spec.content;
    return Dialog(
      backgroundColor: theme.colors.surfaceElevated,
      surfaceTintColor: Colors.transparent,
      elevation: 8,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(geometry.dialogRadius)),
      insetPadding: const EdgeInsets.all(LiveSpacing.lg),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: spec.maxWidth),
        child: Padding(
          padding: geometry.dialogPadding,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (spec.title case final title?) ...[
                Text(title, style: theme.typography.title.copyWith(color: theme.colors.textPrimary)),
                SizedBox(height: geometry.sectionGap),
              ],
              if (content != null)
                Flexible(child: content)
              else if (spec.message case final message?)
                Text(message, style: theme.typography.body.copyWith(color: theme.colors.textSecondary)),
              if (spec.actions.isNotEmpty) ...[
                SizedBox(height: geometry.sectionGap),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    for (final action in spec.actions)
                      Padding(
                        padding: EdgeInsets.only(left: geometry.iconGap),
                        child: const MaterialComponents().button(
                          context,
                          LiveButtonSpec(
                            label: action.label,
                            variant: action.variant,
                            enabled: action.enabled,
                            autofocus: action.autofocus,
                            onPressed: action.enabled ? () => Navigator.of(context).pop(action.result) : null,
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// A collapsed technical detail under an error message.
class _DetailsExpander extends StatefulWidget {
  const new({required this.details});

  final String details;

  @override
  State<_DetailsExpander> createState() => _DetailsExpanderState();
}

class _DetailsExpanderState extends State<_DetailsExpander> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final theme = LiveTheme.of(context);
    if (!_open) {
      return TextButton(
        onPressed: () => setState(() => _open = true),
        style: ButtonStyle(foregroundColor: WidgetStatePropertyAll(theme.colors.textSecondary)),
        child: Text('Details', style: theme.typography.caption),
      );
    }
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: LiveSizing.contentMaxWidth),
      child: SelectableText(
        widget.details,
        style: theme.typography.caption.copyWith(color: theme.colors.textSecondary),
      ),
    );
  }
}
