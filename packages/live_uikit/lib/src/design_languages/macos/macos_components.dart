import 'package:flutter/cupertino.dart' hide OverlayVisibilityMode;
import 'package:flutter/services.dart' show LogicalKeyboardKey, TextInputAction;
import 'package:live_uikit/src/components/contracts/live_component_specs.dart';
import 'package:live_uikit/src/components/contracts/live_design_language_components.dart';
import 'package:live_uikit/src/focus/live_focus_highlight.dart';
import 'package:live_uikit/src/theme/live_component_theme.dart';
import 'package:live_uikit/src/theme/live_theme.dart';
import 'package:live_uikit/src/tokens/radii.dart';
import 'package:macos_ui/macos_ui.dart';

/// The macOS implementation of the component contract.
///
/// macOS is the flattest of the six languages: no elevation anywhere, 6px
/// corners, hairline borders instead of shadows, and the accent only on the
/// default button. The library's controls cover the button, field and
/// indicator cases ([PushButton], [MacosIconButton], [MacosTextField],
/// [ProgressCircle]); the card, dialog and menu are drawn here with the
/// theme's tokens, because macos_ui's own dialog is a fixed two-button
/// alert and its menus are buttons rather than popups anchored at an
/// arbitrary widget — neither can express the contract without dropping the
/// disabled and destructive semantics.
class MacosComponents implements LiveDesignLanguageComponents {
  /// The macOS component set.
  const new();

  /// The macOS theme built from [theme]'s tokens, for the shell widgets of
  /// the application (sidebar, tab view, toolbar) that read it from the
  /// tree.
  static MacosThemeData themeDataOf(LiveTheme theme) => MacosThemeData(
    brightness: theme.brightness,
    primaryColor: theme.colors.primary,
    canvasColor: theme.colors.surface,
    dividerColor: theme.colors.divider,
    typography: MacosTypography(
      color: theme.colors.textPrimary,
      largeTitle: theme.typography.display,
      title1: theme.typography.headline,
      title2: theme.typography.title,
      title3: theme.typography.subtitle,
      headline: theme.typography.subtitle,
      body: theme.typography.body,
      callout: theme.typography.bodySmall,
      footnote: theme.typography.bodySmall,
      caption1: theme.typography.caption,
      caption2: theme.typography.caption,
    ),
  );

  /// Wraps [child] in the macOS theme the library widgets read.
  static Widget scoped(LiveTheme theme, Widget child) => MacosTheme(data: themeDataOf(theme), child: child);

  @override
  Widget button(BuildContext context, LiveButtonSpec spec) {
    final theme = LiveTheme.of(context);
    final geometry = theme.componentTheme;
    final interactive = spec.isInteractive;
    final (color, secondary) = switch (spec.variant) {
      LiveButtonVariant.primary => (theme.colors.primary, false),
      LiveButtonVariant.danger => (theme.colors.error, false),
      LiveButtonVariant.secondary => (theme.colors.surfaceVariant, false),
      LiveButtonVariant.outline || LiveButtonVariant.text => (null, true),
    };
    final content = spec.loading
        ? SizedBox.square(
            dimension: geometry.iconSize,
            child: ProgressCircle(radius: geometry.iconSize / 2.6),
          )
        : _content(theme, spec, spec.variant == LiveButtonVariant.primary || spec.variant == LiveButtonVariant.danger);
    return scoped(
      theme,
      LiveFocusHighlight(
        focusNode: spec.focusNode,
        radius: geometry.controlRadius,
        enabled: interactive,
        scale: 1,
        childBuilder: (context, node) => Focus(
          focusNode: node,
          child: Semantics(
            label: spec.semanticLabel,
            button: true,
            enabled: interactive,
            child: PushButton(
              controlSize: _controlSize(spec.size),
              color: color,
              secondary: secondary,
              semanticLabel: spec.semanticLabel,
              borderRadius: BorderRadius.circular(geometry.controlRadius),
              onPressed: interactive ? spec.onPressed : null,
              child: SizedBox(
                width: spec.expand ? double.infinity : null,
                child: Center(child: content),
              ),
            ),
          ),
        ),
      ),
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
    return scoped(
      theme,
      LiveFocusHighlight(
        focusNode: spec.focusNode,
        radius: geometry.controlRadius,
        enabled: interactive,
        scale: 1,
        childBuilder: (context, node) => MacosIconButton(
          icon: MacosIcon(spec.icon, color: interactive ? color : theme.colors.textDisabled, size: geometry.iconSize),
          boxConstraints: BoxConstraints.tightFor(
            width: geometry.heightFor(spec.size),
            height: geometry.heightFor(spec.size),
          ),
          borderRadius: BorderRadius.circular(geometry.controlRadius),
          backgroundColor: theme.colors.surfaceVariant,
          disabledColor: theme.colors.surfaceVariant,
          semanticLabel: spec.tooltip,
          onPressed: interactive ? spec.onPressed : null,
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
      MacosTextField(
        controller: spec.controller,
        focusNode: spec.focusNode,
        enabled: spec.enabled,
        readOnly: spec.readOnly,
        autofocus: spec.autofocus,
        obscureText: spec.obscure,
        maxLines: spec.obscure ? 1 : spec.maxLines,
        textInputAction: spec.textInputAction,
        onChanged: spec.onChanged,
        onSubmitted: spec.onSubmitted,
        style: theme.typography.body.copyWith(color: theme.colors.textPrimary),
        placeholder: spec.hint,
        placeholderStyle: theme.typography.body.copyWith(color: theme.colors.textDisabled),
        cursorColor: theme.colors.primary,
        padding: EdgeInsets.symmetric(horizontal: geometry.iconGap, vertical: geometry.iconGap),
        decoration: _fieldDecoration(theme, geometry, focused: false),
        focusedDecoration: _fieldDecoration(theme, geometry, focused: true),
        prefix: spec.prefixIcon == null
            ? null
            : MacosIcon(spec.prefixIcon, color: theme.colors.textSecondary, size: geometry.iconSize),
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
      MacosTextField(
        controller: spec.controller,
        focusNode: spec.focusNode,
        enabled: spec.enabled,
        autofocus: spec.autofocus,
        textInputAction: TextInputAction.search,
        onChanged: spec.onChanged,
        onSubmitted: spec.onSubmitted,
        style: theme.typography.body.copyWith(color: theme.colors.textPrimary),
        placeholder: spec.hint,
        placeholderStyle: theme.typography.body.copyWith(color: theme.colors.textDisabled),
        cursorColor: theme.colors.primary,
        padding: EdgeInsets.symmetric(horizontal: geometry.iconGap, vertical: geometry.iconGap),
        decoration: _fieldDecoration(theme, geometry, focused: false, radius: LiveRadii.pill),
        focusedDecoration: _fieldDecoration(theme, geometry, focused: true, radius: LiveRadii.pill),
        // macOS search fields carry their own clear button.
        clearButtonMode: OverlayVisibilityMode.editing,
        prefix: MacosIcon(CupertinoIcons.search, color: theme.colors.textSecondary, size: geometry.iconSize),
      ),
    );
  }

  @override
  Widget card(BuildContext context, LiveCardSpec spec) {
    final theme = LiveTheme.of(context);
    final geometry = theme.componentTheme;
    final padding = spec.padding ?? (spec.dense ? geometry.cardPaddingDense : geometry.cardPadding);
    final surface = DecoratedBox(
      decoration: BoxDecoration(
        color: spec.selected
            ? Color.alphaBlend(theme.colors.primary.withValues(alpha: 0.18), theme.colors.surfaceElevated)
            : theme.colors.surfaceElevated,
        borderRadius: BorderRadius.circular(geometry.cardRadius),
        border: Border.all(color: theme.colors.divider),
      ),
      child: Padding(padding: padding, child: spec.child),
    );
    if (spec.onTap == null && spec.onLongPress == null) {
      return surface;
    }
    return scoped(
      theme,
      LiveFocusHighlight(
        focusNode: spec.focusNode,
        radius: geometry.cardRadius,
        scale: 1,
        childBuilder: (context, node) => _HoverSurface(
          focusNode: node,
          autofocus: spec.autofocus,
          onTap: spec.onTap,
          onLongPress: spec.onLongPress,
          theme: theme,
          radius: geometry.cardRadius,
          child: surface,
        ),
      ),
    );
  }

  /// A macOS context-menu style popup anchored at the widget.
  @override
  Widget menu(BuildContext context, LiveMenuSpec spec) => _MacosMenuAnchor(spec: spec);

  /// A macOS panel dialog.
  ///
  /// macos_ui's `MacosAlertDialog` takes exactly two buttons and an app
  /// icon, which cannot carry a variable action list, disabled actions or a
  /// destructive variant — so the panel is drawn here in the same visual
  /// language (hairline border, canvas fill, no elevation, the default
  /// action accented) and shown with a route that returns the chosen
  /// result.
  @override
  Future<T?> dialog<T>(BuildContext context, LiveDialogSpec<T> spec) {
    final theme = LiveTheme.of(context);
    final dismissible = spec.barrierDismissible ?? spec.dismissible;
    return showGeneralDialog<T>(
      context: context,
      barrierDismissible: dismissible,
      barrierLabel: spec.title,
      barrierColor: theme.colors.scrim.withValues(alpha: 0.4),
      transitionDuration: theme.normal,
      pageBuilder: (context, _, _) => scoped(theme, _MacosDialogPanel<T>(spec: spec)),
      transitionBuilder: (context, animation, _, child) => FadeTransition(
        opacity: CurvedAnimation(parent: animation, curve: theme.animationsEnabled ? Curves.easeOut : Curves.linear),
        child: child,
      ),
    );
  }

  @override
  Widget progressIndicator(BuildContext context, LiveProgressIndicatorSpec spec) {
    final theme = LiveTheme.of(context);
    final value = spec.value;
    final radius = switch (spec.size) {
      LiveControlSize.small => 8.0,
      LiveControlSize.medium => 11.0,
      LiveControlSize.large => 16.0,
    };
    return scoped(
      theme,
      Semantics(
        label: spec.semanticLabel,
        child: value == null
            ? ProgressCircle(radius: radius, borderColor: theme.colors.primary)
            : ProgressCircle(
                value: value.clamp(0, 1) * 100,
                radius: radius,
                innerColor: theme.colors.primary,
                borderColor: theme.colors.surfaceVariant,
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
        MacosIcon(
          spec.icon ?? CupertinoIcons.exclamationmark_triangle,
          color: theme.colors.error,
          size: geometry.iconSize * 2,
        ),
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
            LiveButtonSpec(label: spec.retryLabel ?? 'Retry', icon: CupertinoIcons.refresh, onPressed: spec.onRetry),
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
        MacosIcon(CupertinoIcons.tray, color: theme.colors.textDisabled, size: geometry.iconSize * 2),
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

  static ControlSize _controlSize(LiveControlSize size) => switch (size) {
    LiveControlSize.small => ControlSize.small,
    LiveControlSize.medium => ControlSize.regular,
    LiveControlSize.large => ControlSize.large,
  };

  static BoxDecoration _fieldDecoration(
    LiveTheme theme,
    LiveComponentTheme geometry, {
    required bool focused,
    double? radius,
  }) => BoxDecoration(
    color: theme.colors.surfaceVariant,
    borderRadius: BorderRadius.circular(radius ?? geometry.controlRadius),
    border: Border.all(
      color: focused ? theme.colors.primary : theme.colors.divider,
      width: focused ? geometry.inputBorderWidth + 1 : geometry.inputBorderWidth,
    ),
  );

  static Widget _content(LiveTheme theme, LiveButtonSpec spec, bool onFill) {
    final geometry = theme.componentTheme;
    final color = onFill ? theme.colors.onPrimary : theme.colors.textPrimary;
    final label = Text(
      spec.label,
      style: theme.typography.label.copyWith(color: color),
      overflow: TextOverflow.ellipsis,
    );
    if (spec.icon == null) {
      return label;
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        MacosIcon(spec.icon, color: color, size: geometry.iconSize),
        SizedBox(width: geometry.iconGap),
        Flexible(child: label),
      ],
    );
  }
}

/// A hover- and focus-aware surface, macOS's flat interaction feedback.
class _HoverSurface extends StatefulWidget {
  const new({
    required this.child,
    required this.theme,
    required this.radius,
    required this.focusNode,
    this.onTap,
    this.onLongPress,
    this.autofocus = false,
  });

  final Widget child;
  final LiveTheme theme;
  final double radius;
  final FocusNode focusNode;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final bool autofocus;

  @override
  State<_HoverSurface> createState() => _HoverSurfaceState();
}

class _HoverSurfaceState extends State<_HoverSurface> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: widget.onTap == null ? MouseCursor.defer : SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        onLongPress: widget.onLongPress,
        child: Focus(
          focusNode: widget.focusNode,
          child: AnimatedContainer(
            duration: widget.theme.fast,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(widget.radius),
              color: _hovered ? widget.theme.colors.surfaceOverlay.withValues(alpha: 0.25) : null,
            ),
            child: widget.child,
          ),
        ),
      ),
    );
  }
}

/// The macOS menu: a panel anchored under the widget, dismissed by tapping
/// outside or pressing Escape.
class _MacosMenuAnchor extends StatefulWidget {
  const new({required this.spec});

  final LiveMenuSpec spec;

  @override
  State<_MacosMenuAnchor> createState() => _MacosMenuAnchorState();
}

class _MacosMenuAnchorState extends State<_MacosMenuAnchor> {
  final LayerLink _link = LayerLink();
  OverlayEntry? _entry;

  @override
  void dispose() {
    _entry?.remove();
    _entry = null;
    super.dispose();
  }

  void _toggle() {
    if (_entry != null) {
      _close();
    } else {
      _open();
    }
  }

  void _close() {
    _entry?.remove();
    _entry = null;
  }

  void _open() {
    final theme = LiveTheme.of(context);
    final geometry = theme.componentTheme;
    _entry = OverlayEntry(
      builder: (context) => Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(behavior: HitTestBehavior.opaque, onTap: _close),
          ),
          CompositedTransformFollower(
            link: _link,
            showWhenUnlinked: false,
            targetAnchor: Alignment.bottomLeft,
            child: Focus(
              autofocus: true,
              onKeyEvent: (node, event) {
                if (event.logicalKey == LogicalKeyboardKey.escape) {
                  _close();
                  return KeyEventResult.handled;
                }
                return KeyEventResult.ignored;
              },
              child: Align(
                alignment: Alignment.topLeft,
                child: Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: MacosComponents.scoped(
                    theme,
                    DecoratedBox(
                      decoration: BoxDecoration(
                        color: theme.colors.surfaceElevated,
                        borderRadius: BorderRadius.circular(geometry.menuRadius),
                        border: Border.all(color: theme.colors.divider),
                        boxShadow: [
                          BoxShadow(
                            color: theme.colors.shadow.withValues(alpha: 0.2),
                            blurRadius: 16,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(minWidth: 180, maxWidth: geometry.dialogMaxWidth),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            for (final entry in widget.spec.entries)
                              _MacosMenuEntry(
                                entry: entry,
                                theme: theme,
                                onChosen: () {
                                  _close();
                                  widget.spec.onSelected(entry.id);
                                },
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
    Overlay.of(context).insert(_entry!);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) => CompositedTransformTarget(
    link: _link,
    child: LiveFocusHighlight(
      focusNode: widget.spec.focusNode,
      radius: LiveTheme.of(context).componentTheme.controlRadius,
      scale: 1,
      enabled: widget.spec.enabled,
      childBuilder: (context, node) => GestureDetector(
        onTap: widget.spec.enabled ? _toggle : null,
        child: Focus(
          focusNode: node,
          child: Semantics(button: true, enabled: widget.spec.enabled, child: widget.spec.child),
        ),
      ),
    ),
  );
}

/// One row of the macOS menu panel.
class _MacosMenuEntry extends StatefulWidget {
  const new({required this.entry, required this.theme, required this.onChosen});

  final LiveMenuEntry entry;
  final LiveTheme theme;
  final VoidCallback onChosen;

  @override
  State<_MacosMenuEntry> createState() => _MacosMenuEntryState();
}

class _MacosMenuEntryState extends State<_MacosMenuEntry> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final entry = widget.entry;
    final theme = widget.theme;
    final geometry = theme.componentTheme;
    final color = entry.danger
        ? theme.colors.error
        : entry.enabled
        ? theme.colors.textPrimary
        : theme.colors.textDisabled;
    return MouseRegion(
      cursor: entry.enabled ? SystemMouseCursors.click : MouseCursor.defer,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: entry.enabled ? widget.onChosen : null,
        child: ColoredBox(
          color: _hovered && entry.enabled ? theme.colors.primary : const Color(0x00000000),
          child: SizedBox(
            height: geometry.menuItemHeight,
            child: Padding(
              padding: geometry.menuItemPadding,
              child: Row(
                children: [
                  SizedBox(
                    width: geometry.iconSize,
                    child: entry.selected
                        ? MacosIcon(
                            CupertinoIcons.checkmark,
                            color: _hovered ? theme.colors.onPrimary : color,
                            size: geometry.iconSize * 0.7,
                          )
                        : null,
                  ),
                  if (entry.icon case final icon?) ...[
                    MacosIcon(
                      icon,
                      color: _hovered && entry.enabled ? theme.colors.onPrimary : color,
                      size: geometry.iconSize,
                    ),
                    SizedBox(width: geometry.iconGap),
                  ],
                  Expanded(
                    child: Text(
                      entry.label,
                      style: theme.typography.body.copyWith(
                        color: _hovered && entry.enabled ? theme.colors.onPrimary : color,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (entry.shortcut case final shortcut?) ...[
                    SizedBox(width: geometry.sectionGap),
                    Text(
                      shortcut,
                      style: theme.typography.caption.copyWith(
                        color: _hovered && entry.enabled ? theme.colors.onPrimary : theme.colors.textSecondary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The macOS dialog panel.
class _MacosDialogPanel<T> extends StatelessWidget {
  const new({required this.spec});

  final LiveDialogSpec<T> spec;

  @override
  Widget build(BuildContext context) {
    final theme = LiveTheme.of(context);
    final geometry = theme.componentTheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: DefaultTextStyle(
          style: theme.typography.body,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: spec.maxWidth),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: theme.colors.surfaceElevated,
                borderRadius: BorderRadius.circular(geometry.dialogRadius),
                border: Border.all(color: theme.colors.divider),
                boxShadow: [
                  BoxShadow(
                    color: theme.colors.shadow.withValues(alpha: 0.25),
                    blurRadius: 24,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Padding(
                padding: geometry.dialogPadding,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (spec.title case final title?) ...[
                      Text(
                        title,
                        textAlign: TextAlign.center,
                        style: theme.typography.title.copyWith(color: theme.colors.textPrimary),
                      ),
                      SizedBox(height: geometry.iconGap),
                    ],
                    if (spec.content case final content?)
                      Flexible(child: content)
                    else if (spec.message case final message?)
                      Text(
                        message,
                        textAlign: TextAlign.center,
                        style: theme.typography.body.copyWith(color: theme.colors.textSecondary),
                      ),
                    if (spec.actions.isNotEmpty) ...[
                      SizedBox(height: geometry.sectionGap),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          for (final action in spec.actions)
                            Padding(
                              padding: EdgeInsets.only(left: geometry.iconGap),
                              child: const MacosComponents().button(
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
          ),
        ),
      ),
    );
  }
}
