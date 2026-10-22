import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show TextInputFormatter;
import 'package:pure_uikit/src/styling/provider/pure_config_provider.dart';
import 'package:pure_uikit/src/styling/style/style.dart';

/// The kit's text field: one widget whose plate is drawn here, over Flutter's
/// own editing engine.
///
/// Editing stays exactly where it was — a [TextField] wraps the text, the
/// controller, the focus plumbing, the keyboard hints and the selection
/// gestures, so typing, cursoring, formatters, obscuring and submission behave
/// identically to before and to the app's 44 call sites. What changes is the
/// decoration: the plate is painted by this file from the theme's own tokens in
/// the WinUI grammar — the grey hairline box whose bottom edge darkens into the
/// accent underline — so one interaction contract holds everywhere: hover lifts
/// the border, focus draws the ring, an error recolours it and adds a caption,
/// a disabled field greys out and answers nothing, and the plate animates
/// between those states on the token's motion.
class PureTextField extends StatelessWidget {
  /// A text field.
  const new({
    this.controller,
    this.focusNode,
    this.placeholder,
    this.errorText,
    this.enabled = true,
    this.readOnly = false,
    this.obscure = false,
    this.maxLines = 1,
    this.textInputAction,
    this.keyboardType,
    this.inputFormatters,
    this.autocorrect = true,
    this.enableSuggestions = true,
    this.autofocus = false,
    this.prefix,
    this.suffix,
    this.style,
    this.onTap,
    this.onChanged,
    this.onSubmitted,
    super.key,
  });

  /// The text controller; the field owns one when omitted, exactly as the
  /// editing engine does.
  final TextEditingController? controller;

  /// An externally managed focus node; the plate's focus ring reads it, and
  /// one is owned here when the caller brings none.
  final FocusNode? focusNode;

  /// The empty-state hint.
  final String? placeholder;

  /// The validation message; non-null recolours the plate in the error role and
  /// draws this as its own caption line under the field.
  final String? errorText;

  /// Whether the field responds to input; false greys the plate and text out
  /// and stops the engine from taking focus or keystrokes.
  final bool enabled;

  /// Whether the field is read-only. A read-only field stays live-looking (not
  /// dimmed, focusable, selectable) but does not edit; only [enabled] drives
  /// the disabled render.
  final bool readOnly;

  /// Whether the field hides its content. Forces [maxLines] to one, as every
  /// password field does.
  final bool obscure;

  /// The line count; a value above one grows the plate with its content.
  final int? maxLines;

  /// Keyboard action and type.
  final TextInputAction? textInputAction;

  /// The keyboard type.
  final TextInputType? keyboardType;

  /// The edits the text can take (a digits-only port field is one), handed
  /// straight to the engine.
  final List<TextInputFormatter>? inputFormatters;

  /// Whether the platform may autocorrect what is typed. Off for a host, a path
  /// or a room id, where "capitalising" the value is a corruption.
  final bool autocorrect;

  /// Whether the platform may offer suggestions while typing.
  final bool enableSuggestions;

  /// Whether the field takes focus on first appearance.
  final bool autofocus;

  /// A widget before the text, laid out in the plate's leading slot.
  final Widget? prefix;

  /// A widget after the text, laid out in the plate's trailing slot.
  final Widget? suffix;

  /// An inline style override, layered over the token body text; a null
  /// property keeps the token value.
  final Style? style;

  /// Called when the field is tapped; the tap still places the caret and takes
  /// focus — this only reports it, so a caller can react without disturbing
  /// editing.
  final VoidCallback? onTap;

  /// Called when the text changes.
  final ValueChanged<String>? onChanged;

  /// Called when the field is submitted.
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) {
    final theme = PureTheme.of(context);
    final language = theme.config.language;
    return _FieldShell(
      // The branch a field draws is its identity in tests and diagnostics.
      key: ValueKey('PureTextField.${language.name}'),
      visual: _FieldVisual.fluent(),
      controller: controller,
      focusNode: focusNode,
      placeholder: placeholder,
      errorText: errorText,
      enabled: enabled,
      readOnly: readOnly,
      obscure: obscure,
      maxLines: maxLines,
      textInputAction: textInputAction,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      autocorrect: autocorrect,
      enableSuggestions: enableSuggestions,
      autofocus: autofocus,
      prefix: prefix,
      suffix: suffix,
      style: style,
      onTap: onTap,
      onChanged: onChanged,
      onSubmitted: onSubmitted,
    );
  }
}

/// How the plate around the text is painted: the fill, the border in each
/// interaction state, the corner, the motion's ink. Every value is a function
/// of the resolved theme, so a dark switch and the accent all come out of the
/// same tokens the kit's other controls read.
@immutable
final class _FieldVisual {
  const new({
    required this.radius,
    required this.plate,
    required this.contentPadding,
    required this.minHeight,
    required this.disabledAlpha,
    this.bottomRule,
  });

  /// Windows Fluent's WinUI box: the sides keep their grey hairline while the
  /// bottom edge is the accent line the control is known for — it darkens under
  /// the pointer and thickens to two pixels in the accent when focused.
  ///
  /// The rule is a layer of its own ([bottomRule]) rather than the box's bottom
  /// side: Flutter paints a rounded box only with a single-colour border ("a
  /// borderRadius can only be given on borders with uniform colors"), so a
  /// grey-sided, accent-bottomed [Border] would throw in `Border.paint` and the
  /// plate would never reach the screen. The tab bar's underline indicator
  /// takes the same shape for the same reason.
  factory fluent() {
    return _FieldVisual(
      radius: (theme) => BorderRadius.circular(4),
      contentPadding: _inset,
      minHeight: (theme) => theme.input.height,
      disabledAlpha: (theme) => theme.token.motion.opacityLoading,
      plate: (theme, {required focused, required hovered, required pressed, required disabled, required error}) {
        return BoxDecoration(
          color: disabled
              ? theme.colors.fillTertiary
              : focused
              ? theme.colors.bgElevated
              : theme.input.background,
          borderRadius: BorderRadius.circular(4),
          // One colour all the way round, so the 4-corner box stays paintable;
          // the bottom edge's own ink comes from the rule layered over it.
          border: Border.all(
            color: _winuiSide(theme, focused: focused, hovered: hovered, pressed: pressed, error: error),
            width: theme.token.motion.lineWidth,
          ),
        );
      },
      bottomRule: (theme, {required focused, required hovered, required pressed, required disabled, required error}) {
        final lw = theme.token.motion.lineWidth;
        final side = _winuiSide(theme, focused: focused, hovered: hovered, pressed: pressed, error: error);
        return _BottomRule(
          color: error
              ? theme.colors.error
              : focused
              ? theme.colors.primary
              : hovered || pressed
              ? theme.colors.textSecondary
              : side,
          width: focused || error ? 2.0 : lw,
        );
      },
    );
  }

  /// The plate's corner.
  final BorderRadius Function(PureTheme theme) radius;

  /// The plate's whole surface for one state: fill and border.
  final BoxDecoration Function(
    PureTheme theme, {
    required bool focused,
    required bool hovered,
    required bool pressed,
    required bool disabled,
    required bool error,
  })
  plate;

  /// The text and leading/trailing slot inset inside the plate.
  final EdgeInsets Function(PureTheme theme) contentPadding;

  /// The single-line plate's minimum height; a taller field grows past it.
  final double Function(PureTheme theme) minHeight;

  /// The opacity a disabled (not merely read-only) field falls to.
  final double Function(PureTheme theme) disabledAlpha;

  /// The accent rule laid over the plate's bottom edge in the resolved state,
  /// or null for an outline that is one colour all the way round.
  final _BottomRule Function(
    PureTheme theme, {
    required bool focused,
    required bool hovered,
    required bool pressed,
    required bool disabled,
    required bool error,
  })?
  bottomRule;

  /// The grey hairline WinUI keeps on its three non-accent sides: the error
  /// role on an error, the stronger grey once the field is engaged, the resting
  /// border otherwise. The bottom edge reads the same value at rest and takes
  /// its own ink from the rule on top of it.
  static Color _winuiSide(
    PureTheme theme, {
    required bool focused,
    required bool hovered,
    required bool pressed,
    required bool error,
  }) {
    if (error) {
      return theme.colors.error;
    }
    if (focused || hovered || pressed) {
      return theme.colors.border;
    }
    return theme.colors.borderSecondary;
  }

  /// The token inset, overridable per side.
  static EdgeInsets _inset(PureTheme theme, {double? horizontal, double? vertical}) => EdgeInsets.symmetric(
    horizontal: horizontal ?? theme.input.paddingInline,
    vertical: vertical ?? theme.input.paddingBlock,
  );
}

/// The accent rule laid along the plate's bottom edge: its ink and
/// its thickness in one resolved state. It rides over the plate as its own
/// animated layer, clipped to the plate's corner, because a rounded
/// [BoxDecoration] may not carry two border colours.
@immutable
final class _BottomRule {
  const new({required this.color, required this.width});

  /// The rule's ink.
  final Color color;

  /// The rule's thickness.
  final double width;
}

/// The field's body: the editing engine wrapped in the self-painted
/// plate, under the interaction contract — hover and
/// focus tints, the disabled render, the error recolour and caption, the focus
/// ring, `textField` semantics and the plate's state animation.
class _FieldShell extends StatefulWidget {
  const new({
    required this.visual,
    required this.controller,
    required this.focusNode,
    required this.placeholder,
    required this.errorText,
    required this.enabled,
    required this.readOnly,
    required this.obscure,
    required this.maxLines,
    required this.textInputAction,
    required this.keyboardType,
    required this.inputFormatters,
    required this.autocorrect,
    required this.enableSuggestions,
    required this.autofocus,
    required this.prefix,
    required this.suffix,
    required this.style,
    required this.onTap,
    required this.onChanged,
    required this.onSubmitted,
    super.key,
  });

  final _FieldVisual visual;

  final TextEditingController? controller;

  /// The caller's node; one is owned and disposed here when it is null.
  final FocusNode? focusNode;

  final String? placeholder;

  final String? errorText;

  final bool enabled;

  final bool readOnly;

  final bool obscure;

  final int? maxLines;

  final TextInputAction? textInputAction;

  final TextInputType? keyboardType;

  final List<TextInputFormatter>? inputFormatters;

  final bool autocorrect;

  final bool enableSuggestions;

  final bool autofocus;

  final Widget? prefix;

  final Widget? suffix;

  final Style? style;

  final VoidCallback? onTap;

  final ValueChanged<String>? onChanged;

  final ValueChanged<String>? onSubmitted;

  @override
  State<_FieldShell> createState() => _FieldShellState();
}

class _FieldShellState extends State<_FieldShell> {
  FocusNode? _ownedNode;

  /// The node the focus listener is currently attached to; tracked so a swapped
  /// in node detaches the old listener instead of leaking it.
  FocusNode? _attached;
  bool _focused = false;
  bool _hovered = false;
  bool _pressed = false;

  /// The node the edit sits on: the caller's when they brought one, an owned
  /// one otherwise. The plate's ring follows this node, so it must always exist.
  FocusNode get _node => widget.focusNode ?? (_ownedNode ??= FocusNode(debugLabel: 'PureTextField'));

  @override
  void initState() {
    super.initState();
    _attachFocus();
  }

  @override
  void didUpdateWidget(covariant _FieldShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_node != _attached) {
      // Only release a node we made; the caller keeps theirs.
      _ownedNode?.dispose();
      _ownedNode = null;
      _attachFocus();
    }
  }

  @override
  void dispose() {
    _attached?.removeListener(_onFocusChanged);
    _attached = null;
    // Externally managed nodes are left for their owner; only the one made here
    // is released.
    _ownedNode?.dispose();
    super.dispose();
  }

  /// Moves the focus listener onto the live node and seeds the ring's state.
  void _attachFocus() {
    _attached?.removeListener(_onFocusChanged);
    _attached = _node;
    _attached!.addListener(_onFocusChanged);
    _focused = _node.hasFocus;
  }

  void _onFocusChanged() {
    if (mounted) {
      setState(() => _focused = _node.hasFocus);
    }
  }

  bool get _live => widget.enabled;

  @override
  Widget build(BuildContext context) {
    final theme = PureTheme.of(context);
    final visual = widget.visual;
    final live = _live;
    final error = widget.errorText;
    final focused = _focused && live;
    final hovered = _hovered && live;
    final pressed = _pressed && live;

    final field = TextField(
      controller: widget.controller,
      focusNode: _node,
      enabled: live,
      readOnly: widget.readOnly,
      obscureText: widget.obscure,
      maxLines: widget.obscure ? 1 : (widget.maxLines ?? 1),
      keyboardType: widget.keyboardType,
      textInputAction: widget.textInputAction,
      inputFormatters: widget.inputFormatters,
      autocorrect: widget.autocorrect,
      enableSuggestions: widget.enableSuggestions,
      autofocus: widget.autofocus,
      onTap: widget.onTap,
      onChanged: widget.onChanged,
      onSubmitted: widget.onSubmitted,
      style: _textStyle(theme, visual),
      cursorColor: theme.colors.text,
      // The engine's own Material decoration is fully neutralised — no borders,
      // no fill, no hover/focus ink — so the plate below is the only chrome.
      decoration: InputDecoration(
        isDense: true,
        filled: false,
        fillColor: Colors.transparent,
        hoverColor: Colors.transparent,
        focusColor: Colors.transparent,
        hintText: widget.placeholder,
        hintStyle: theme.text.body.copyWith(color: theme.input.placeholderColor),
        contentPadding: visual.contentPadding(theme),
        border: InputBorder.none,
        enabledBorder: InputBorder.none,
        focusedBorder: InputBorder.none,
        errorBorder: InputBorder.none,
        focusedErrorBorder: InputBorder.none,
        disabledBorder: InputBorder.none,
        prefixIcon: widget.prefix == null
            ? null
            : IconTheme.merge(
                data: IconThemeData(color: theme.colors.icon),
                child: widget.prefix!,
              ),
        suffixIcon: widget.suffix == null
            ? null
            : IconTheme.merge(
                data: IconThemeData(color: theme.colors.icon),
                child: widget.suffix!,
              ),
      ),
    );

    final plate = AnimatedContainer(
      key: const ValueKey('PureTextField.plate'),
      duration: theme.duration,
      curve: Curves.easeOut,
      constraints: BoxConstraints(minHeight: visual.minHeight(theme)),
      decoration: visual.plate(
        theme,
        focused: focused,
        hovered: hovered,
        pressed: pressed,
        disabled: !live,
        error: error != null,
      ),
      child: field,
    );

    // The WinUI accent underline lays inside the plate's corner, so the
    // hairline stays one colour — and stays paintable — while the edge still
    // thickens into the accent on focus.
    final rule = visual.bottomRule?.call(
      theme,
      focused: focused,
      hovered: hovered,
      pressed: pressed,
      disabled: !live,
      error: error != null,
    );
    final edged = rule == null
        ? plate
        : ClipRRect(
            key: const ValueKey('PureTextField.edgeClip'),
            borderRadius: visual.radius(theme),
            child: Stack(
              children: [
                plate,
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: AnimatedContainer(
                    key: const ValueKey('PureTextField.edge'),
                    duration: theme.duration,
                    curve: Curves.easeOut,
                    height: rule.width,
                    decoration: BoxDecoration(color: rule.color),
                  ),
                ),
              ],
            ),
          );

    final observed = MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      // Pointer observers report the press for the tint without competing for
      // the gesture, so the caret placement and selection stay the engine's.
      child: Listener(
        onPointerDown: (_) => setState(() => _pressed = true),
        onPointerUp: (_) => setState(() => _pressed = false),
        onPointerCancel: (_) => setState(() => _pressed = false),
        child: edged,
      ),
    );

    final faded = AnimatedOpacity(
      key: const ValueKey('PureTextField.dim'),
      duration: theme.duration,
      curve: Curves.easeOut,
      opacity: live ? 1 : visual.disabledAlpha(theme),
      child: observed,
    );

    final errorCaption = error;
    final result = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        faded,
        if (errorCaption != null)
          Padding(
            padding: EdgeInsets.only(top: theme.token.scale.sizes.xxs),
            child: Text(errorCaption, style: theme.text.caption.copyWith(color: theme.colors.error)),
          ),
      ],
    );

    return Semantics(
      key: const ValueKey('PureTextField.semantics'),
      textField: true,
      enabled: live,
      label: widget.placeholder,
      child: result,
    );
  }

  /// The token body text in the state's colour, with the inline style override
  /// layered on top; a null property keeps the token value.
  TextStyle _textStyle(PureTheme theme, _FieldVisual visual) {
    final color = _live ? theme.colors.text : theme.colors.textQuaternary;
    final base = theme.text.body.copyWith(color: color);
    return widget.style?.applyText(base) ?? base;
  }
}
