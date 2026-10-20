import 'package:fluent_2/fluent_2.dart' as f2;
import 'package:flutter/cupertino.dart' as cupertino;
import 'package:flutter/material.dart';
import 'package:flutter_neumorphic_ui_kit/flutter_neumorphic_ui_kit.dart' as neu;
import 'package:fluttersdk_wind/fluttersdk_wind.dart' as wind;
import 'package:forui/forui.dart' as forui;
import 'package:glass_morphism_plus/glass_morphism_plus.dart' as glass;
import 'package:macos_ui/macos_ui.dart' as macos;
import 'package:pure_uikit/src/styling/config/pure_design_language.dart';
import 'package:pure_uikit/src/styling/provider/pure_config_provider.dart';
import 'package:pure_uikit/src/styling/style/style.dart';

/// The public text field: one widget, every theme and density. [build] switches
/// on `UiConfig.language` and constructs the library's real component directly
/// — Material's `TextField`, iOS's `CupertinoTextField`, macOS's
/// `MacosTextField`, fluent_2's `FluentInput` — so what the user sees is
/// exactly what that library's own documentation shows. Switching
/// `UiConfig.language` re-skins every field.
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
  Widget build(BuildContext context) {
    final theme = PureTheme.of(context);

    return switch (theme.config.language) {
      // An error carries two signals here — it redraws the border and adds a
      // caption line beneath the field — so the field means the same thing on
      // either signal and keeps that meaning across a style switch.
      PureDesignLanguage.cupertino => _withError(
        theme,
        cupertino.CupertinoTextField(
          controller: controller,
          focusNode: focusNode,
          placeholder: placeholder,
          enabled: enabled,
          readOnly: readOnly,
          obscureText: obscure,
          maxLines: obscure ? 1 : (maxLines ?? 1),
          keyboardType: keyboardType,
          textInputAction: textInputAction,
          prefix: prefix,
          suffix: suffix,
          onSubmitted: onSubmitted,
          onChanged: onChanged,
          style: _textStyle(theme),
          decoration: BoxDecoration(
            color: theme.colors.bgContainer,
            borderRadius: BorderRadius.circular(theme.input.borderRadius),
            border: Border.all(color: errorText != null ? theme.colors.error : theme.colors.border),
          ),
        ),
      ),
      PureDesignLanguage.macos => _withError(
        theme,
        macos.MacosTextField(
          controller: controller,
          focusNode: focusNode,
          placeholder: placeholder,
          enabled: enabled,
          readOnly: readOnly,
          obscureText: obscure,
          keyboardType: keyboardType,
          textInputAction: textInputAction,
          maxLines: obscure ? 1 : (maxLines ?? 1),
          prefix: prefix,
          suffix: suffix,
          onSubmitted: onSubmitted,
          onChanged: onChanged,
          // The library has no error slot: an error redraws the border in the
          // token error colour and the message rides underneath it as its own
          // caption line.
          decoration: BoxDecoration(
            border: Border.all(color: errorText == null ? theme.colors.border : theme.colors.error),
            borderRadius: BorderRadius.circular(theme.input.borderRadius),
          ),
          style: _textStyle(theme),
        ),
      ),
      // fluent_2's own field wrapper carries the validation message under the
      // box, and its input paints the error border.
      PureDesignLanguage.fluent => _fluentField(theme),
      // The library's own field: it owns a controller when the caller brings
      // none, and reports through the same control object — so a caller-owned
      // controller is never replaced and a null `onChanged` stays null instead
      // of becoming a swallowing closure. Its label fork carries an error
      // slot, so `errorText` reaches it instead of being drawn as an invented
      // caption.
      PureDesignLanguage.forui => forui.FTextField(
        control: forui.FTextFieldControl.managed(
          controller: controller,
          onChange: onChanged == null ? null : (value) => onChanged!(value.text),
        ),
        hint: placeholder,
        error: errorText == null ? null : Text(errorText!),
        enabled: enabled,
        readOnly: readOnly,
        obscureText: obscure,
        maxLines: obscure ? 1 : (maxLines ?? 1),
        keyboardType: keyboardType,
        textInputAction: textInputAction,
        focusNode: focusNode,
        prefixBuilder: prefix == null ? null : (context, style, variants) => prefix!,
        suffixBuilder: suffix == null ? null : (context, style, variants) => suffix!,
        onSubmit: onSubmitted,
      ),
      // The library's own field, carrying hint, obscuring, keyboard hints,
      // line count, enable and read-only state and the leading/trailing slots.
      // It has no error slot, so the message is drawn as the caption this
      // contract composes elsewhere, and the field keeps the library's own
      // focus treatment rather than an approximation of a Material error
      // border.
      // The library's own frosted plate (`GlassContainer`) with Flutter's
      // official field on it. `GlassTextField` hard-codes white text, hint
      // and cursor — right on a photo backdrop, invisible on the app's own
      // light surface — so the surface stays the library's while the ink
      // follows the tokens, as every other language's field does.
      PureDesignLanguage.glass => _withError(
        theme,
        glass.GlassContainer(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          opacity: 0.12,
          borderRadius: 16,
          child: TextField(
            controller: controller,
            focusNode: focusNode,
            enabled: enabled,
            readOnly: readOnly,
            obscureText: obscure,
            maxLines: obscure ? 1 : (maxLines ?? 1),
            keyboardType: keyboardType,
            textInputAction: textInputAction,
            onChanged: onChanged,
            onSubmitted: onSubmitted,
            style: _textStyle(theme),
            cursorColor: theme.colors.text,
            decoration: InputDecoration(
              isDense: true,
              hintText: placeholder,
              hintStyle: theme.text.body.copyWith(color: theme.colors.textTertiary),
              prefixIcon: prefix,
              suffixIcon: suffix,
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              errorBorder: InputBorder.none,
              focusedErrorBorder: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ),
      ),
      // The library's own field, carrying hint, error, prefix/suffix icons,
      // obscuring, keyboard type and action, line count and enable state.
      // `readOnly` has no parameter on `NeuTextField` and is unmappable rather
      // than emulated by dropping the callback, which would change what the
      // field means.
      PureDesignLanguage.neumorphic => neu.NeuTextField(
        controller: controller,
        focusNode: focusNode,
        hintText: placeholder,
        errorText: errorText,
        prefixIcon: prefix,
        suffixIcon: suffix,
        obscureText: obscure,
        maxLines: obscure ? 1 : (maxLines ?? 1),
        keyboardType: keyboardType,
        textInputAction: textInputAction,
        enabled: enabled,
        onChanged: onChanged,
        onSubmitted: onSubmitted,
        style: _textStyle(theme),
      ),
      // The fork's own input: it takes the caller's controller and focus node
      // untouched, owns one only when the caller supplies neither, and carries
      // placeholder, enabled, read-only, line count, keyboard action, prefix
      // and suffix natively. It has no `keyboardType`/`obscureText` pair of
      // its own — both derive from one [wind.InputType], so the two fields
      // collapse into the closest single intent (`obscure` wins, then an
      // email/number keyboard, then the line count). The error message has no
      // slot in the fork either, so it is drawn the same caption under the
      // same error border state.
      PureDesignLanguage.wind => _windField(theme),
      // Yaru ships no text field of its own — the library's parts are buttons,
      // tiles, chips and bars — so the official Material field is the fallback.
      PureDesignLanguage.material || PureDesignLanguage.yaru => TextField(
        controller: controller,
        focusNode: focusNode,
        enabled: enabled,
        readOnly: readOnly,
        obscureText: obscure,
        maxLines: obscure ? 1 : maxLines,
        keyboardType: keyboardType,
        textInputAction: textInputAction,
        onChanged: onChanged,
        onSubmitted: onSubmitted,
        style: _textStyle(theme),
        decoration: InputDecoration(
          hintText: placeholder,
          errorText: errorText,
          // The outlined box rather than the bare `InputDecoration` default,
          // which is the underline variant: this family's field then carries
          // the token's input corner and error colour like every other
          // language's, instead of a rule with no shape to it.
          border: _outline(theme, theme.colors.border),
          enabledBorder: _outline(theme, theme.colors.border),
          focusedBorder: _outline(theme, theme.colors.primary),
          errorBorder: _outline(theme, theme.colors.error),
          focusedErrorBorder: _outline(theme, theme.colors.error),
          prefixIcon: prefix == null
              ? null
              : IconTheme.merge(data: IconThemeData(color: theme.colors.icon), child: prefix!),
          suffixIcon: suffix,
        ),
      ),
    };
  }

  /// The Material family's field border: the token's input corner, in [color].
  OutlineInputBorder _outline(PureTheme theme, Color color) => OutlineInputBorder(
    borderRadius: BorderRadius.circular(theme.input.borderRadius),
    borderSide: BorderSide(color: color),
  );

  /// The fluent branch: the library's input, wrapped in its validation field
  /// when there is an error to report.
  Widget _fluentField(PureTheme theme) {
    final error = errorText;
    final input = f2.FluentInput(
      controller: controller,
      focusNode: focusNode,
      placeholder: placeholder == null ? null : Text(placeholder!),
      enabled: enabled,
      readOnly: readOnly,
      error: error != null,
      obscureText: obscure,
      maxLines: obscure ? 1 : (maxLines ?? 1),
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      contentBefore: prefix,
      contentAfter: suffix,
      onChanged: onChanged,
      onSubmitted: onSubmitted,
      // The input styles its text from its own theme; the spec's inline style
      // rides in through the style override, its documented last word.
      style: f2.FluentInputStyle(textStyle: WidgetStatePropertyAll<TextStyle?>(_textStyle(theme))),
    );
    if (error == null) {
      return input;
    }
    return f2.FluentField(
      validationMessage: Text(error),
      validationState: f2.FluentFieldValidationState.error,
      child: input,
    );
  }

  /// The wind branch: the fork's input with the closest single
  /// [wind.InputType], and the validation message as its own caption line in
  /// the token's error border colour.
  Widget _windField(PureTheme theme) {
    final field = wind.WInput(
      controller: controller,
      focusNode: focusNode,
      placeholder: placeholder,
      enabled: enabled,
      readOnly: readOnly,
      maxLines: maxLines,
      textInputAction: textInputAction,
      onChanged: onChanged,
      onSubmitted: onSubmitted,
      prefix: prefix,
      suffix: suffix,
      type: _windInputType(),
      states: errorText == null ? null : const {'error'},
    );
    final error = errorText;
    if (error == null) {
      return field;
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        field,
        Padding(
          padding: EdgeInsets.only(top: theme.token.scale.sizes.xxs),
          child: Text(error, style: theme.text.caption.copyWith(color: theme.input.errorBorderColor)),
        ),
      ],
    );
  }

  /// The one [wind.InputType] the fork derives both the keyboard and the
  /// obscuring from: `obscure` wins, then an email/number keyboard, then the
  /// line count.
  wind.InputType _windInputType() {
    if (obscure) {
      return wind.InputType.password;
    }
    return switch (keyboardType) {
      TextInputType.emailAddress => wind.InputType.email,
      TextInputType.number || TextInputType.phone || TextInputType.url => wind.InputType.number,
      _ => (maxLines ?? 1) > 1 ? wind.InputType.multiline : wind.InputType.text,
    };
  }

  /// The field, plus the validation message as its own caption line in the
  /// error colour — the shape Cupertino, macOS and glass use, whose fields
  /// have no error slot of their own.
  Widget _withError(PureTheme theme, Widget field) {
    final error = errorText;
    if (error == null) {
      return field;
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        field,
        Padding(
          padding: EdgeInsets.only(top: theme.token.scale.sizes.xxs),
          child: Text(error, style: theme.text.caption.copyWith(color: theme.colors.error)),
        ),
      ],
    );
  }

  /// The token body text with the inline [style] layered on top; a null
  /// property keeps the token value (`TextStyle.copyWith` keeps the base for a
  /// null argument, so only the named properties move).
  TextStyle _textStyle(PureTheme theme) {
    final base = theme.text.body.copyWith(color: theme.colors.text);
    final override = style;
    if (override == null) {
      return base;
    }
    return base.copyWith(
      color: override.foreground,
      fontFamily: override.fontFamily,
      fontSize: override.fontSize,
      fontWeight: override.fontWeight,
      letterSpacing: override.letterSpacing,
      height: override.lineHeight,
    );
  }
}
