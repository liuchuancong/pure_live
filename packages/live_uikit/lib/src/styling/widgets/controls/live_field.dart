import 'package:flutter/material.dart';
import 'package:live_uikit/src/styling/contracts/live_ui_adapter.dart';
import 'package:live_uikit/src/styling/provider/live_config_provider.dart';
import 'package:live_uikit/src/styling/style/style.dart';
import 'package:live_uikit/src/styling/tokens/component_token.dart' show InputComponentToken;

/// The token-driven text-field renderer (Material-family styling), used as the
/// base implementation for languages that do not map a field to their own
/// widget. Material's own decoration is switched off; the surface, radius and
/// the resting / hover / focused / disabled / error border come from
/// [InputComponentToken].
class TokenTextField extends StatefulWidget {
  /// A token text field built from [spec].
  const new({required this.spec, super.key});

  /// The field configuration.
  final LanguageTextFieldSpec spec;

  @override
  State<TokenTextField> createState() => _TokenTextFieldState();
}

class _TokenTextFieldState extends State<TokenTextField> {
  final FocusNode _focus = FocusNode();
  TextEditingController? _owned;
  bool _hovered = false;
  bool _focused = false;

  FocusNode get _node => widget.spec.focusNode ?? _focus;

  @override
  void initState() {
    super.initState();
    _focus.addListener(_onFocusChange);
  }

  void _onFocusChange() => setState(() => _focused = _node.hasFocus);

  @override
  void dispose() {
    _focus.removeListener(_onFocusChange);
    _focus.dispose();
    _owned?.dispose();
    super.dispose();
  }

  TextEditingController get _controller => widget.spec.controller ?? (_owned ??= TextEditingController());

  @override
  Widget build(BuildContext context) {
    final spec = widget.spec;
    final theme = LiveTheme.of(context);
    final input = theme.input;
    final enabled = spec.enabled && !spec.readOnly;

    final Color borderColor;
    if (!enabled) {
      borderColor = input.borderColor.withValues(alpha: 0.5);
    } else if (spec.errorText != null) {
      borderColor = input.errorBorderColor;
    } else if (_focused) {
      borderColor = input.focusBorderColor;
    } else if (_hovered) {
      borderColor = input.hoverBorderColor;
    } else {
      borderColor = input.borderColor;
    }
    final radius = BorderRadius.circular(input.borderRadius);

    final field = IgnorePointer(
      ignoring: !enabled,
      child: TextField(
        controller: _controller,
        focusNode: spec.focusNode,
        enabled: enabled,
        readOnly: spec.readOnly,
        obscureText: spec.obscure,
        maxLines: spec.obscure ? 1 : spec.maxLines,
        keyboardType: spec.keyboardType,
        textInputAction: spec.textInputAction,
        onChanged: spec.onChanged,
        onSubmitted: spec.onSubmitted,
        style: theme.text.body.copyWith(color: input.textColor),
        decoration: InputDecoration(
          isCollapsed: true,
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          disabledBorder: InputBorder.none,
          hintText: spec.placeholder,
          hintStyle: theme.text.body.copyWith(color: input.placeholderColor),
          contentPadding: EdgeInsets.symmetric(vertical: input.paddingBlock),
          prefixIcon: spec.prefix == null ? null : _slot(theme, spec.prefix!),
          suffixIcon: spec.suffix == null ? null : _slot(theme, spec.suffix!),
        ),
      ),
    );

    // The field's own surface, with the caller's inline style layered over it —
    // the same cascade `LiveBox` applies, so a `style:` on a field wins over the
    // component token exactly where it names something (§11). Blur is a `LiveBox`
    // effect and is not painted here; a field has no frosted state in the token
    // model.
    final surface = Style(
      padding: EdgeInsets.symmetric(horizontal: input.paddingInline),
      background: input.background,
      borderRadius: radius,
      borderColor: borderColor,
      borderWidth: theme.token.motion.lineWidth,
    ).merge(spec.style);
    final singleLineHeight = spec.maxLines == 1 && !spec.obscure ? input.height : null;

    Widget box = MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: theme.duration,
        padding: surface.padding,
        margin: surface.margin,
        alignment: surface.alignment,
        constraints: BoxConstraints(
          minWidth: surface.minWidth ?? 0,
          minHeight: surface.minHeight ?? singleLineHeight ?? 0,
          maxWidth: surface.maxWidth ?? double.infinity,
        ),
        decoration: surface.toDecoration(),
        child: Align(alignment: Alignment.centerLeft, child: field),
      ),
    );

    if (surface.opacity case final opacity? when opacity < 1) {
      box = Opacity(opacity: opacity, child: box);
    }

    final error = spec.errorText;
    if (error == null) {
      return box;
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        box,
        Padding(
          padding: EdgeInsets.only(top: theme.token.scale.sizes.xxs),
          child: Text(error, style: theme.text.caption.copyWith(color: input.errorBorderColor)),
        ),
      ],
    );
  }

  Widget _slot(LiveTheme theme, Widget child) => Padding(
    padding: EdgeInsets.symmetric(horizontal: theme.token.scale.sizes.sm),
    child: child,
  );
}

/// The public text field: a thin dispatcher to the active language adapter, so
/// switching `UiConfig.language` re-renders it with the real library's control.
class LiveTextField extends StatelessWidget {
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
    this.prefix,
    this.suffix,
    this.style,
    this.onChanged,
    this.onSubmitted,
    super.key,
  });

  /// The text controller; the field owns one when omitted.
  final TextEditingController? controller;

  /// An externally managed focus node.
  final FocusNode? focusNode;

  /// The empty-state hint.
  final String? placeholder;

  /// The validation message.
  final String? errorText;

  /// Whether the field responds to input.
  final bool enabled;

  /// Whether the field is read-only.
  final bool readOnly;

  /// Whether the field hides its content.
  final bool obscure;

  /// The line count.
  final int? maxLines;

  /// Keyboard action and type.
  final TextInputAction? textInputAction;

  /// The keyboard type.
  final TextInputType? keyboardType;

  /// A widget before the text.
  final Widget? prefix;

  /// A widget after the text.
  final Widget? suffix;

  /// An inline style override.
  final Style? style;

  /// Called when the text changes.
  final ValueChanged<String>? onChanged;

  /// Called when the field is submitted.
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) => LiveTheme.of(context).adapter.textField(
    context,
    LanguageTextFieldSpec(
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
      prefix: prefix,
      suffix: suffix,
      style: style,
      onChanged: onChanged,
      onSubmitted: onSubmitted,
    ),
  );
}
