import 'package:flutter/services.dart' show LogicalKeyboardKey;
// The library re-exports Material's widgets, so the text field and icons come
// from this single import; only the progress widgets are taken as a prefix to
// keep them apart from the plain ones.
import 'package:flutter_neumorphic_plus/flutter_neumorphic.dart'
    hide NeumorphicProgress, NeumorphicProgressIndeterminate;
import 'package:flutter_neumorphic_plus/flutter_neumorphic.dart'
    as neu
    show NeumorphicProgress, NeumorphicProgressIndeterminate, ProgressStyle;
import 'package:live_uikit/src/components/contracts/live_component_specs.dart';
import 'package:live_uikit/src/components/contracts/live_design_language_components.dart';
import 'package:live_uikit/src/core/ui_environment.dart';
import 'package:live_uikit/src/focus/live_focus_highlight.dart';
import 'package:live_uikit/src/theme/live_component_theme.dart';
import 'package:live_uikit/src/theme/live_theme.dart';
import 'package:live_uikit/src/tokens/radii.dart';

/// The Neumorphic implementation of the component contract.
///
/// Neumorphism has one hard rule: a control is the *same colour* as what it
/// sits on, and only its shadows say whether it is raised or pressed in.
/// That is why this language overrides the palette — [baseColorOf] flattens
/// the surface tones to one soft base — and why the depth values here come
/// from the tokens rather than from the widget library's defaults: a
/// neumorphic screen that mixes two base colours stops reading as
/// neumorphic at all.
///
/// The library ships buttons, text, switches, sliders, checkboxes, radios
/// and progress; for the rest (text fields, cards, menus, dialogs) this
/// language composes its own surfaces out of `Neumorphic` at the documented
/// per-component level. The text field keeps Flutter's own `TextField` for
/// editing — selection, IME and accessibility are not worth reimplementing
/// — with the Material chrome switched off and the neumorphic surface drawn
/// around it.
class NeumorphicComponents implements LiveDesignLanguageComponents {
  /// The Neumorphic component set.
  const new();

  /// The single base colour of a neumorphic screen: the surface tinted
  /// towards the accent by a few percent, which is what gives the shadows
  /// something to fall on.
  static Color baseColorOf(LiveTheme theme) => theme.colors.surface;

  /// The theme data the library's widgets read.
  static NeumorphicThemeData themeDataOf(LiveTheme theme) => NeumorphicThemeData(
    baseColor: baseColorOf(theme),
    accentColor: theme.colors.primary,
    variantColor: theme.colors.secondary,
    disabledColor: theme.colors.textDisabled,
    defaultTextColor: theme.colors.textPrimary,
    depth: _depthOf(theme),
    intensity: theme.brightness == Brightness.dark ? 0.5 : 0.65,
  );

  /// Wraps [child] in the theme the library's widgets read.
  static Widget scoped(LiveTheme theme, Widget child) {
    final data = themeDataOf(theme);
    return NeumorphicTheme(theme: data, darkTheme: data, themeMode: ThemeMode.light, child: child);
  }

  static double _depthOf(LiveTheme theme) => theme.environment.layoutMode == LiveLayoutMode.tv ? 8 : 5;

  static NeumorphicBoxShape _shape(double radius) => NeumorphicBoxShape.roundRect(BorderRadius.circular(radius));

  /// The raised surface a card or dialog sits on.
  static Widget raised(LiveTheme theme, {required double radius, required Widget child}) => Neumorphic(
    style: NeumorphicStyle(
      boxShape: _shape(radius),
      color: baseColorOf(theme),
      depth: _depthOf(theme),
      intensity: theme.brightness == Brightness.dark ? 0.5 : 0.7,
    ),
    child: child,
  );

  @override
  Widget button(BuildContext context, LiveButtonSpec spec) {
    final theme = LiveTheme.of(context);
    final geometry = theme.componentTheme;
    final interactive = spec.isInteractive;
    final (color, foreground) = switch (spec.variant) {
      LiveButtonVariant.primary => (theme.colors.primary, theme.colors.onPrimary),
      LiveButtonVariant.danger => (theme.colors.error, theme.colors.onError),
      LiveButtonVariant.secondary => (baseColorOf(theme), theme.colors.textPrimary),
      LiveButtonVariant.outline || LiveButtonVariant.text => (baseColorOf(theme), theme.colors.textSecondary),
    };
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
            child: NeumorphicButton(
              // The primary and danger variants are filled, so they read as
              // raised; the rest stay flat against the surface.
              style: NeumorphicStyle(
                shape: spec.variant == LiveButtonVariant.text ? NeumorphicShape.flat : NeumorphicShape.convex,
                boxShape: _shape(geometry.controlRadius),
                color: color,
                depth: spec.variant == LiveButtonVariant.text ? 0 : _depthOf(theme) * 0.6,
                intensity: 0.6,
              ),
              padding: EdgeInsets.symmetric(
                horizontal: geometry.controlPadding,
                vertical: (geometry.heightFor(spec.size) - geometry.iconSize) / 2,
              ),
              onPressed: interactive ? spec.onPressed : null,
              child: SizedBox(
                height: geometry.iconSize,
                child: Center(
                  child: spec.loading
                      ? SizedBox.square(
                          dimension: geometry.iconSize,
                          child: const neu.NeumorphicProgressIndeterminate(height: 3),
                        )
                      : _label(theme, spec, foreground),
                ),
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
        radius: LiveRadii.pill,
        enabled: interactive,
        scale: 1,
        childBuilder: (context, node) => Focus(
          focusNode: node,
          child: Tooltip(
            message: spec.tooltip,
            child: NeumorphicButton(
              style: NeumorphicStyle(
                shape: spec.selected ? NeumorphicShape.concave : NeumorphicShape.flat,
                boxShape: const NeumorphicBoxShape.circle(),
                color: baseColorOf(theme),
                depth: _depthOf(theme) * 0.5,
                intensity: 0.6,
              ),
              padding: EdgeInsets.all(geometry.iconGap),
              onPressed: interactive ? spec.onPressed : null,
              child: Icon(spec.icon, size: geometry.iconSize, color: interactive ? color : theme.colors.textDisabled),
            ),
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
      Neumorphic(
        style: NeumorphicStyle(
          // An inset field: light comes from the top-left, so the shadow
          // inside the top edge says "you can type here".
          shape: NeumorphicShape.concave,
          boxShape: _shape(geometry.inputRadius),
          color: baseColorOf(theme),
          depth: -_depthOf(theme),
          intensity: 0.5,
        ),
        padding: EdgeInsets.symmetric(horizontal: geometry.controlPadding, vertical: geometry.iconGap),
        child: Row(
          children: [
            if (spec.prefixIcon case final icon?) ...[
              Icon(icon, size: geometry.iconSize, color: theme.colors.textSecondary),
              SizedBox(width: geometry.iconGap),
            ],
            Expanded(
              child: TextField(
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
                cursorColor: theme.colors.primary,
                decoration: InputDecoration.collapsed(
                  hintText: spec.hint,
                  hintStyle: theme.typography.body.copyWith(color: theme.colors.textDisabled),
                ),
              ),
            ),
            if (spec.errorText != null) ...[
              SizedBox(width: geometry.iconGap),
              Icon(Icons.error_outline, size: geometry.iconSize, color: theme.colors.error),
            ],
            ?spec.suffix,
          ],
        ),
      ),
    );
  }

  @override
  Widget searchField(BuildContext context, LiveSearchFieldSpec spec) {
    final theme = LiveTheme.of(context);
    final geometry = theme.componentTheme;
    return scoped(
      theme,
      Neumorphic(
        style: NeumorphicStyle(
          shape: NeumorphicShape.concave,
          boxShape: _shape(LiveRadii.pill),
          color: baseColorOf(theme),
          depth: -_depthOf(theme),
          intensity: 0.5,
        ),
        padding: EdgeInsets.symmetric(horizontal: geometry.controlPadding, vertical: geometry.iconGap),
        child: Row(
          children: [
            Icon(Icons.search, size: geometry.iconSize, color: theme.colors.textSecondary),
            SizedBox(width: geometry.iconGap),
            Expanded(
              child: TextField(
                controller: spec.controller,
                focusNode: spec.focusNode,
                enabled: spec.enabled,
                autofocus: spec.autofocus,
                textInputAction: TextInputAction.search,
                onChanged: spec.onChanged,
                onSubmitted: spec.onSubmitted,
                style: theme.typography.body.copyWith(color: theme.colors.textPrimary),
                cursorColor: theme.colors.primary,
                decoration: InputDecoration.collapsed(
                  hintText: spec.hint,
                  hintStyle: theme.typography.body.copyWith(color: theme.colors.textDisabled),
                ),
              ),
            ),
            if (spec.onClear case final onClear?)
              NeumorphicButton(
                style: NeumorphicStyle(
                  boxShape: const NeumorphicBoxShape.circle(),
                  color: baseColorOf(theme),
                  depth: 0,
                ),
                padding: const EdgeInsets.all(4),
                onPressed: onClear,
                child: Icon(Icons.close, size: geometry.iconSize * 0.7, color: theme.colors.textSecondary),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget card(BuildContext context, LiveCardSpec spec) {
    final theme = LiveTheme.of(context);
    final geometry = theme.componentTheme;
    final padding = spec.padding ?? (spec.dense ? geometry.cardPaddingDense : geometry.cardPadding);
    // A selected card is pressed in, everything else is raised.
    final surface = Neumorphic(
      style: NeumorphicStyle(
        shape: spec.selected ? NeumorphicShape.concave : NeumorphicShape.flat,
        boxShape: _shape(geometry.cardRadius),
        color: baseColorOf(theme),
        depth: spec.selected ? -_depthOf(theme) : _depthOf(theme),
        intensity: 0.6,
      ),
      child: Padding(padding: padding, child: spec.child),
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
        childBuilder: (context, node) => Focus(
          focusNode: node,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: spec.onTap,
            onLongPress: spec.onLongPress,
            child: surface,
          ),
        ),
      ),
    );
  }

  @override
  Widget menu(BuildContext context, LiveMenuSpec spec) =>
      scoped(LiveTheme.of(context), _NeumorphicMenuAnchor(spec: spec));

  @override
  Future<T?> dialog<T>(BuildContext context, LiveDialogSpec<T> spec) {
    final theme = LiveTheme.of(context);
    final dismissible = spec.barrierDismissible ?? spec.dismissible;
    return showGeneralDialog<T>(
      context: context,
      barrierDismissible: dismissible,
      barrierLabel: spec.title,
      barrierColor: theme.colors.scrim.withValues(alpha: 0.35),
      transitionDuration: theme.normal,
      pageBuilder: (context, _, _) => scoped(theme, _NeumorphicDialogPanel<T>(spec: spec)),
      transitionBuilder: (context, animation, _, child) => FadeTransition(
        opacity: CurvedAnimation(parent: animation, curve: theme.animationsEnabled ? Curves.easeOut : Curves.linear),
        child: child,
      ),
    );
  }

  @override
  Widget progressIndicator(BuildContext context, LiveProgressIndicatorSpec spec) {
    final theme = LiveTheme.of(context);
    final geometry = theme.componentTheme;
    final value = spec.value;
    return scoped(
      theme,
      Semantics(
        label: spec.semanticLabel,
        child: SizedBox(
          width: value == null ? geometry.loadingIndicatorSize : geometry.dialogMaxWidth * 0.5,
          child: value == null
              ? const neu.NeumorphicProgressIndeterminate(height: 4)
              : neu.NeumorphicProgress(percent: value.clamp(0, 1), height: 6, style: const neu.ProgressStyle(depth: 1)),
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
            LiveButtonSpec(label: spec.retryLabel ?? 'Retry', icon: Icons.refresh, onPressed: spec.onRetry),
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

  static Widget _label(LiveTheme theme, LiveButtonSpec spec, Color foreground) {
    final geometry = theme.componentTheme;
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

/// The Neumorphic menu: a raised panel anchored under the widget.
class _NeumorphicMenuAnchor extends StatefulWidget {
  const new({required this.spec});

  final LiveMenuSpec spec;

  @override
  State<_NeumorphicMenuAnchor> createState() => _NeumorphicMenuAnchorState();
}

class _NeumorphicMenuAnchorState extends State<_NeumorphicMenuAnchor> {
  final LayerLink _link = LayerLink();
  OverlayEntry? _entry;

  @override
  void dispose() {
    _entry?.remove();
    _entry = null;
    super.dispose();
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
                  padding: const EdgeInsets.only(top: 6),
                  child: NeumorphicComponents.raised(
                    theme,
                    radius: geometry.menuRadius,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(minWidth: 180, maxWidth: geometry.dialogMaxWidth),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          for (final entry in widget.spec.entries)
                            _NeumorphicMenuEntry(
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
      childBuilder: (context, node) => Focus(
        focusNode: node,
        child: GestureDetector(
          onTap: widget.spec.enabled ? _open : null,
          child: Semantics(
            button: true,
            enabled: widget.spec.enabled,
            label: widget.spec.tooltip,
            child: widget.spec.child,
          ),
        ),
      ),
    ),
  );
}

/// One row of the Neumorphic menu panel.
class _NeumorphicMenuEntry extends StatefulWidget {
  const new({required this.entry, required this.theme, required this.onChosen});

  final LiveMenuEntry entry;
  final LiveTheme theme;
  final VoidCallback onChosen;

  @override
  State<_NeumorphicMenuEntry> createState() => _NeumorphicMenuEntryState();
}

class _NeumorphicMenuEntryState extends State<_NeumorphicMenuEntry> {
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
        child: Neumorphic(
          // The hovered row presses into the panel, the neumorphic way of
          // showing what is under the pointer.
          style: NeumorphicStyle(
            shape: NeumorphicShape.concave,
            boxShape: NeumorphicComponents._shape(geometry.menuRadius),
            color: NeumorphicComponents.baseColorOf(theme),
            depth: _hovered && entry.enabled ? -2 : 0,
            intensity: 0.5,
          ),
          child: SizedBox(
            height: geometry.menuItemHeight,
            child: Padding(
              padding: geometry.menuItemPadding,
              child: Row(
                children: [
                  if (entry.icon case final icon?) ...[
                    Icon(icon, size: geometry.iconSize, color: color),
                    SizedBox(width: geometry.iconGap),
                  ],
                  Expanded(
                    child: Text(
                      entry.label,
                      style: theme.typography.body.copyWith(color: color),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (entry.selected) ...[
                    SizedBox(width: geometry.iconGap),
                    Icon(Icons.check, size: geometry.iconSize, color: theme.colors.primary),
                  ],
                  if (entry.shortcut case final shortcut?) ...[
                    SizedBox(width: geometry.iconGap),
                    Text(shortcut, style: theme.typography.caption.copyWith(color: theme.colors.textSecondary)),
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

/// The Neumorphic dialog panel.
class _NeumorphicDialogPanel<T> extends StatelessWidget {
  const new({required this.spec});

  final LiveDialogSpec<T> spec;

  @override
  Widget build(BuildContext context) {
    final theme = LiveTheme.of(context);
    final geometry = theme.componentTheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: spec.maxWidth),
          child: NeumorphicComponents.raised(
            theme,
            radius: geometry.dialogRadius,
            child: Padding(
              padding: geometry.dialogPadding,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (spec.title case final title?) ...[
                    Text(title, style: theme.typography.title.copyWith(color: theme.colors.textPrimary)),
                    SizedBox(height: geometry.iconGap),
                  ],
                  if (spec.content case final content?)
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
                            child: const NeumorphicComponents().button(
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
    );
  }
}
