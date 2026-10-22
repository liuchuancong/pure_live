import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show TextInputFormatter;
import 'package:pure_uikit/src/styling/config/pure_design_language.dart';
import 'package:pure_uikit/src/styling/provider/pure_config_provider.dart';
import 'package:pure_uikit/src/styling/style/style.dart';

/// The kit's text field: one widget whose plate is drawn here, in every design
/// language, over Flutter's own editing engine.
///
/// Editing stays exactly where it was — a [TextField] wraps the text, the
/// controller, the focus plumbing, the keyboard hints and the selection
/// gestures, so typing, cursoring, formatters, obscuring and submission behave
/// identically to before and to the app's 44 call sites. What changes is the
/// decoration: every library chrome (Material's outlined box, Cupertino's and
/// macOS's plates, Fluent's box, shadcn's border, the glass and neumorphic
/// surfaces) is now painted by this file from the theme's own tokens, so one
/// interaction contract holds everywhere — hover lifts the border, focus draws
/// the language's ring, an error recolours it and adds a caption, a disabled
/// field greys out and answers nothing, and the plate animates between those
/// states on the token's motion. Switching `UiConfig.language` re-skins every
/// field, and none of them borrows a foreign decoration to do it.
///
/// Each language keeps its own grammar rather than a shared box: Material 3's
/// outline tightens to a two-width accent on focus, iOS answers a soft accent
/// glow over its 5-radius plate, macOS runs the 7-radius well with the
/// platform focus halo, WinUI darkens its bottom edge into the accent underline
/// while the sides stay grey, Yaru takes the distribution accent as a solid
/// outline, forui/wind ring the field with shadcn's offset focus ring, glass
/// frosts the plate through a real backdrop blur where the device affords it,
/// and neumorphic presses the extruded surface in when focused.
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
  /// language's password field does.
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
      visual: _FieldVisual.resolve(theme),
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

/// How one design language paints the plate around the text: the fill, the
/// border in each interaction state, the corner, the motion's ink and whether
/// the surface frosts what sits behind it. Every value is a function of the
/// resolved theme, so a language re-skin, a dark switch and the accent all come
/// out of the same tokens the kit's other controls read.
@immutable
final class _FieldVisual {
  const new({
    required this.radius,
    required this.plate,
    required this.contentPadding,
    required this.minHeight,
    required this.disabledAlpha,
    required this.frosted,
    this.bottomRule,
  });

  /// Material 3's outlined box: a container surface with a full hairline at
  /// rest that lifts to the text grey under the pointer and tightens to a
  /// two-width accent outline on focus.
  factory material() {
    return _FieldVisual(
      radius: (theme) => BorderRadius.circular(theme.input.borderRadius),
      contentPadding: _inset,
      minHeight: (theme) => theme.input.height,
      disabledAlpha: (theme) => theme.token.motion.opacityLoading,
      frosted: false,
      plate: (theme, {required focused, required hovered, required pressed, required disabled, required error}) {
        final line = _outline(theme, focused: focused, hovered: hovered, pressed: pressed, error: error);
        return BoxDecoration(
          color: disabled ? theme.colors.fillTertiary : theme.input.background,
          borderRadius: BorderRadius.circular(theme.input.borderRadius),
          border: Border.all(color: line, width: focused ? 2 : theme.token.motion.lineWidth),
        );
      },
    );
  }

  /// Cupertino's iOS plate: the classic 5-radius field, a hairline you barely
  /// see at rest, and on focus the accent border plus the soft glow iOS rings
  /// a focused control with.
  factory cupertino() {
    return _FieldVisual(
      radius: (theme) => BorderRadius.circular(5),
      contentPadding: (theme) => _inset(theme, vertical: theme.token.scale.sizes.sm),
      minHeight: (theme) => theme.input.height,
      disabledAlpha: (theme) => theme.token.motion.opacityLoading,
      frosted: false,
      plate: (theme, {required focused, required hovered, required pressed, required disabled, required error}) {
        final accent = theme.colors.primary;
        final line = error
            ? theme.colors.error
            : focused
            ? accent
            : hovered || pressed
            ? theme.colors.border
            : theme.colors.borderSecondary;
        return BoxDecoration(
          color: disabled ? theme.colors.fillTertiary : theme.input.background,
          borderRadius: BorderRadius.circular(5),
          border: Border.all(color: line, width: focused ? 2 : theme.token.motion.lineWidth),
          boxShadow: focused && !disabled
              ? [BoxShadow(color: accent.withValues(alpha: 0.18), blurRadius: 6)]
              : const [],
        );
      },
    );
  }

  /// macOS's well: the 7-radius elevated plate with its hairline, the accent
  /// border on focus, and the platform's own blue focus halo around it.
  factory macos() {
    return _FieldVisual(
      radius: (theme) => BorderRadius.circular(7),
      contentPadding: (theme) => _inset(theme, horizontal: theme.input.paddingInline + theme.token.scale.sizes.xxs),
      minHeight: (theme) => theme.input.height,
      disabledAlpha: (theme) => theme.token.motion.opacityLoading,
      frosted: false,
      plate: (theme, {required focused, required hovered, required pressed, required disabled, required error}) {
        final accent = theme.colors.primary;
        final line = error
            ? theme.colors.error
            : focused
            ? accent
            : hovered || pressed
            ? theme.colors.border
            : theme.colors.borderSecondary;
        return BoxDecoration(
          color: disabled ? theme.colors.fillTertiary : theme.colors.bgElevated,
          borderRadius: BorderRadius.circular(7),
          border: Border.all(color: line, width: focused ? 2 : theme.token.motion.lineWidth),
          boxShadow: focused && !disabled ? [BoxShadow(color: accent.withValues(alpha: 0.4), blurRadius: 6)] : const [],
        );
      },
    );
  }

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
      frosted: false,
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

  /// Ubuntu Yaru's field: the lightly rounded container that takes the
  /// distribution accent as a solid two-width outline on focus — the same
  /// accent-as-outline answer its checkbox gives, not Material's.
  factory yaru() {
    return _FieldVisual(
      radius: (theme) => BorderRadius.circular(theme.token.scale.radii.sm),
      contentPadding: _inset,
      minHeight: (theme) => theme.input.height,
      disabledAlpha: (theme) => theme.token.motion.opacityLoading,
      frosted: false,
      plate: (theme, {required focused, required hovered, required pressed, required disabled, required error}) {
        final line = _outline(theme, focused: focused, hovered: hovered, pressed: pressed, error: error);
        return BoxDecoration(
          color: disabled ? theme.colors.fillTertiary : theme.input.background,
          borderRadius: BorderRadius.circular(theme.token.scale.radii.sm),
          border: Border.all(
            color: error || focused ? line : theme.colors.borderSecondary,
            width: focused ? 2 : theme.token.motion.lineWidth,
          ),
        );
      },
    );
  }

  /// forui's shadcn field and the wind branch that sits in the same arm as it
  /// (and as the tab bar and checkbox put wind beside the web-descended
  /// languages): a crisp rounded border that inverts to the accent on focus and
  /// rings the field with shadcn's offset focus ring — a gap, then the accent —
  /// rather than a thick outline.
  factory crisp() {
    return _FieldVisual(
      radius: (theme) => BorderRadius.circular(theme.token.scale.radii.sm),
      contentPadding: _inset,
      minHeight: (theme) => theme.input.height,
      disabledAlpha: (theme) => theme.token.motion.opacityLoading,
      frosted: false,
      plate: (theme, {required focused, required hovered, required pressed, required disabled, required error}) {
        final accent = theme.colors.primary;
        final line = error
            ? theme.colors.error
            : focused
            ? accent
            : hovered || pressed
            ? theme.colors.textSecondary
            : theme.colors.border;
        final ring = (error ? theme.colors.error : accent).withValues(alpha: 0.5);
        return BoxDecoration(
          color: disabled ? theme.colors.fillTertiary : theme.input.background,
          borderRadius: BorderRadius.circular(theme.token.scale.radii.sm),
          border: Border.all(color: line, width: focused || error ? 2 : theme.token.motion.lineWidth),
          boxShadow: focused && !disabled
              ? [BoxShadow(color: theme.colors.bgElevated, spreadRadius: 2), BoxShadow(color: ring, spreadRadius: 4)]
              : const [],
        );
      },
    );
  }

  /// The glass language: a frosted plate (a real backdrop blur where the device
  /// can afford it, the same film the tab bar's glass track wears where it
  /// cannot) with a hairline that turns to the accent on focus.
  factory glass() {
    Color film(PureTheme theme, {required bool focused, required bool hovered, required bool pressed}) {
      final alpha = focused || pressed
          ? (theme.isDark ? 0.16 : 0.68)
          : hovered
          ? (theme.isDark ? 0.12 : 0.62)
          : (theme.isDark ? 0.08 : 0.55);
      return Colors.white.withValues(alpha: alpha);
    }

    return _FieldVisual(
      radius: (theme) => BorderRadius.circular(theme.token.scale.radii.lg),
      contentPadding: (theme) => _inset(theme, horizontal: theme.token.scale.sizes.lg),
      minHeight: (theme) => theme.input.height,
      disabledAlpha: (theme) => theme.token.motion.opacityLoading,
      frosted: true,
      plate: (theme, {required focused, required hovered, required pressed, required disabled, required error}) {
        final edge = error
            ? theme.colors.error
            : focused
            ? theme.colors.primary
            : theme.isDark
            ? Colors.white.withValues(alpha: 0.18)
            : Colors.white.withValues(alpha: 0.7);
        return BoxDecoration(
          color: film(theme, focused: focused, hovered: hovered, pressed: pressed),
          borderRadius: BorderRadius.circular(theme.token.scale.radii.lg),
          border: Border.all(color: edge, width: focused ? 2 : theme.token.motion.lineWidth),
        );
      },
    );
  }

  /// The neumorphic language: the plate raised on two soft shadows at rest, and
  /// pressed into a well with an accent hairline once focused.
  factory neumorphic() {
    List<BoxShadow> raised(PureTheme theme) => [
      BoxShadow(color: theme.colors.shadowBase, blurRadius: 6, offset: const Offset(3, 3)),
      BoxShadow(
        color: theme.colors.white.withValues(alpha: theme.isDark ? 0.04 : 0.8),
        blurRadius: 6,
        offset: const Offset(-3, -3),
      ),
    ];
    List<BoxShadow> sunk(PureTheme theme) => [
      for (final shadow in raised(theme))
        BoxShadow(color: shadow.color, blurRadius: shadow.blurRadius, offset: -shadow.offset),
    ];
    return _FieldVisual(
      radius: (theme) => BorderRadius.circular(theme.token.scale.radii.lg),
      contentPadding: (theme) => _inset(theme, horizontal: theme.token.scale.sizes.lg),
      minHeight: (theme) => theme.input.height,
      disabledAlpha: (theme) => theme.token.motion.opacityLoading,
      frosted: false,
      plate: (theme, {required focused, required hovered, required pressed, required disabled, required error}) {
        final accent = error ? theme.colors.error : theme.colors.primary;
        return BoxDecoration(
          color: disabled ? theme.colors.fillTertiary : theme.colors.bgContainer,
          borderRadius: BorderRadius.circular(theme.token.scale.radii.lg),
          border: focused
              ? Border.all(color: accent, width: 2)
              : (hovered || pressed) && !disabled
              ? Border.all(color: theme.colors.border, width: theme.token.motion.lineWidth)
              : null,
          boxShadow: focused || pressed ? sunk(theme) : raised(theme),
        );
      },
    );
  }

  /// The branch one design language paints, chosen from the resolved theme the
  /// way the tab bar and the checkbox resolve theirs.
  factory resolve(PureTheme theme) => switch (theme.config.language) {
    PureDesignLanguage.material => _FieldVisual.material(),
    PureDesignLanguage.cupertino => _FieldVisual.cupertino(),
    PureDesignLanguage.macos => _FieldVisual.macos(),
    PureDesignLanguage.fluent => _FieldVisual.fluent(),
    PureDesignLanguage.yaru => _FieldVisual.yaru(),
    // forui and wind share the crisp branch, as they share the checkbox's and
    // the tab bar's.
    PureDesignLanguage.forui || PureDesignLanguage.wind => _FieldVisual.crisp(),
    PureDesignLanguage.glass => _FieldVisual.glass(),
    PureDesignLanguage.neumorphic => _FieldVisual.neumorphic(),
  };

  /// The plate's corner.
  final BorderRadius Function(PureTheme theme) radius;

  /// The plate's whole surface for one state: fill, border (per-side in the
  /// languages whose edge differs by side), ring and shadow.
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
  /// or null for the languages whose outline is one colour all the way round.
  /// Only the fluent branch sets it, and only because Flutter refuses a
  /// two-colour border on a rounded box.
  final _BottomRule Function(
    PureTheme theme, {
    required bool focused,
    required bool hovered,
    required bool pressed,
    required bool disabled,
    required bool error,
  })?
  bottomRule;

  /// Whether the plate frosts what sits behind it — true only of the glass
  /// branch, and honoured only while [PureTheme.canBlur] agrees.
  final bool frosted;

  /// The outline colour the box-drawing languages share: the error role on an
  /// error, the accent on focus, the text grey under the pointer, the resting
  /// border otherwise.
  static Color _outline(
    PureTheme theme, {
    required bool focused,
    required bool hovered,
    required bool pressed,
    required bool error,
  }) {
    if (error) {
      return theme.colors.error;
    }
    if (focused) {
      return theme.colors.primary;
    }
    if (hovered || pressed) {
      return theme.colors.textSecondary;
    }
    return theme.colors.border;
  }

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

  /// The token inset, overridable per side for the languages whose plate wants
  /// more air than the base control padding.
  static EdgeInsets _inset(PureTheme theme, {double? horizontal, double? vertical}) => EdgeInsets.symmetric(
    horizontal: horizontal ?? theme.input.paddingInline,
    vertical: vertical ?? theme.input.paddingBlock,
  );
}

/// The accent rule a language lays along the plate's bottom edge: its ink and
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

/// The field's body: the editing engine wrapped in the language's self-painted
/// plate, under the interaction contract every language shares — hover and
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

    // A language that marks its bottom edge with a rule of its own (WinUI's
    // accent underline) lays it inside the plate's corner, so the hairline
    // stays one colour — and stays paintable — while the edge still thickens
    // into the accent on focus.
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

    // The glass branch frosts what sits behind the plate, real blur where the
    // device can afford it — the same policy the tab bar and switch read.
    final box = !visual.frosted || !theme.canBlur
        ? edged
        : ClipRRect(
            borderRadius: visual.radius(theme),
            child: BackdropFilter(filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14), child: edged),
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
        child: box,
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
