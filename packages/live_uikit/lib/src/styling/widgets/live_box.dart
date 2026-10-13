import 'dart:ui' show ImageFilter;

import 'package:flutter/services.dart' show KeyDownEvent, LogicalKeyboardKey;
import 'package:flutter/widgets.dart';

import 'package:live_uikit/src/styling/root/live_config_provider.dart';
import 'package:live_uikit/src/styling/style.dart';

/// The generic styled group every live_uikit component is built from — the
/// `<div class="…" style="…">` of the toolkit.
///
/// It owns the parts no component should repeat: tracking the CSS-style
/// interaction states (hover / press / focus / disabled), resolving the right
/// [Style] for the live state through a [style] builder, and painting the
/// result — background, radius, border, shadow, opacity, backdrop blur and the
/// inherited foreground (text and icons pick up [Style.foreground], exactly as
/// `color` cascades in CSS). A concrete widget only supplies its per-state
/// style and its semantic props; it never touches a design language.
class LiveBox extends StatefulWidget {
  /// A styled group whose look comes from [style] resolved for the live state.
  const new({
    required this.style,
    this.child,
    this.onTap,
    this.onLongPress,
    this.focusNode,
    this.autofocus = false,
    this.enabled = true,
    this.inlineStyle,
    super.key,
  });

  /// Resolves the box style for an interaction state; typically
  /// `UiTheme.of(context).resolveButton(variant, size, state)`.
  final Style Function(InteractionState state) style;

  /// The contents.
  final Widget? child;

  /// The tap callback; null makes the box non-interactive.
  final VoidCallback? onTap;

  /// The long-press callback.
  final VoidCallback? onLongPress;

  /// The focus node, for pages that drive focus themselves.
  final FocusNode? focusNode;

  /// Whether the box takes focus when it first appears.
  final bool autofocus;

  /// Whether the box accepts input; drives the disabled state.
  final bool enabled;

  /// A caller's inline style, merged over the resolved one (the `style=`
  /// attribute: highest precedence).
  final Style? inlineStyle;

  @override
  State<LiveBox> createState() => _LiveBoxState();
}

class _LiveBoxState extends State<LiveBox> {
  bool _hovered = false;
  bool _pressed = false;
  bool _focused = false;

  InteractionState _resolveState() {
    if (!widget.enabled) {
      return InteractionState.disabled;
    }
    if (_pressed) {
      return InteractionState.pressed;
    }
    if (_focused) {
      return InteractionState.focused;
    }
    if (_hovered) {
      return InteractionState.hovered;
    }
    return InteractionState.normal;
  }

  @override
  Widget build(BuildContext context) {
    final theme = LiveTheme.of(context);
    final state = _resolveState();
    final resolved = widget.style(state).merge(widget.inlineStyle);
    final interactive = widget.enabled && (widget.onTap != null || widget.onLongPress != null);

    var content = widget.child ?? const SizedBox.shrink();
    // The foreground cascades onto text and icons, like CSS `color`.
    if (resolved.foreground case final fg?) {
      content = DefaultTextStyle(
        style: TextStyle(color: fg),
        child: IconTheme(
          data: IconThemeData(color: fg, size: resolved.fontSize),
          child: content,
        ),
      );
    }

    final box = AnimatedContainer(
      duration: theme.config.animations ? theme.duration : Duration.zero,
      curve: Curves.easeOut,
      padding: resolved.padding,
      margin: resolved.margin,
      alignment: resolved.alignment,
      decoration: resolved.toDecoration(),
      child: content,
    );

    Widget sized = ConstrainedBox(
      constraints: BoxConstraints(
        minWidth: resolved.minWidth ?? 0,
        minHeight: resolved.minHeight ?? 0,
        maxWidth: resolved.maxWidth ?? double.infinity,
      ),
      child: box,
    );

    if (resolved.blur case final sigma? when sigma > 0 && theme.canBlur) {
      sized = ClipRRect(
        borderRadius: resolved.borderRadius ?? BorderRadius.zero,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
          child: sized,
        ),
      );
    }
    if (resolved.opacity case final opacity? when opacity < 1) {
      sized = Opacity(opacity: opacity, child: sized);
    }

    return MouseRegion(
      cursor: interactive ? SystemMouseCursors.click : MouseCursor.defer,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: Focus(
        focusNode: widget.focusNode,
        autofocus: widget.autofocus,
        canRequestFocus: interactive,
        onFocusChange: (v) => setState(() => _focused = v),
        onKeyEvent: (node, event) => _onKey(context, node, event, state),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: interactive ? widget.onTap : null,
          onLongPress: interactive ? widget.onLongPress : null,
          onTapDown: (_) => setState(() => _pressed = true),
          onTapUp: (_) => setState(() => _pressed = false),
          onTapCancel: () => setState(() => _pressed = false),
          child: sized,
        ),
      ),
    );
  }

  // Enter/Space activate a focused box, so a remote or keyboard drives every
  // interactive control, not just real buttons.
  KeyEventResult _onKey(BuildContext context, FocusNode node, KeyEvent event, InteractionState state) {
    if (!widget.enabled || widget.onTap == null) {
      return KeyEventResult.ignored;
    }
    if (event is KeyDownEvent &&
        (event.logicalKey == LogicalKeyboardKey.enter ||
            event.logicalKey == LogicalKeyboardKey.space ||
            event.logicalKey == LogicalKeyboardKey.select)) {
      widget.onTap!.call();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }
}
