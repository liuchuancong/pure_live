import 'package:flutter/material.dart';

import 'package:live_uikit/src/components/contracts/live_component_specs.dart';
import 'package:live_uikit/src/theme/live_theme.dart';

/// The text field every page uses.
class LiveTextField extends StatefulWidget {
  /// A text field.
  const new({
    this.controller,
    this.focusNode,
    this.label,
    this.hint,
    this.prefixIcon,
    this.suffix,
    this.obscure = false,
    this.enabled = true,
    this.autofocus = false,
    this.readOnly = false,
    this.maxLines = 1,
    this.keyboardType,
    this.textInputAction,
    this.errorText,
    this.onChanged,
    this.onSubmitted,
    super.key,
  });

  /// The text controller.
  final TextEditingController? controller;

  /// The focus node, for pages that manage focus themselves.
  final FocusNode? focusNode;

  /// The floating label.
  final String? label;

  /// The placeholder.
  final String? hint;

  /// A leading icon.
  final IconData? prefixIcon;

  /// A trailing widget.
  final Widget? suffix;

  /// Whether the text is hidden.
  final bool obscure;

  /// Whether the field accepts input.
  final bool enabled;

  /// Whether it takes focus when the view opens.
  final bool autofocus;

  /// Whether the text is selectable but not editable.
  final bool readOnly;

  /// How many lines the field grows to.
  final int maxLines;

  /// The on-screen keyboard type.
  final TextInputType? keyboardType;

  /// The keyboard's action key.
  final TextInputAction? textInputAction;

  /// A validation message shown below the field.
  final String? errorText;

  /// Called on every change.
  final ValueChanged<String>? onChanged;

  /// Called when the user submits.
  final ValueChanged<String>? onSubmitted;

  @override
  State<LiveTextField> createState() => _LiveTextFieldState();
}

class _LiveTextFieldState extends State<LiveTextField> {
  TextEditingController? _owned;

  TextEditingController get _controller => widget.controller ?? (_owned ??= TextEditingController());

  @override
  void dispose() {
    _owned?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => LiveTheme.of(context).components.textField(
    context,
    LiveTextFieldSpec(
      controller: widget.controller ?? _controller,
      focusNode: widget.focusNode,
      label: widget.label,
      hint: widget.hint,
      prefixIcon: widget.prefixIcon,
      suffix: widget.suffix,
      obscure: widget.obscure,
      enabled: widget.enabled,
      autofocus: widget.autofocus,
      readOnly: widget.readOnly,
      maxLines: widget.maxLines,
      keyboardType: widget.keyboardType,
      textInputAction: widget.textInputAction,
      errorText: widget.errorText,
      onChanged: widget.onChanged,
      onSubmitted: widget.onSubmitted,
    ),
  );
}

/// The search field every page uses.
///
/// A text field with the search chrome baked in, including the clear button
/// that appears once there is text. The widget owns the controller when the
/// page does not supply one, so `LiveSearchField(onChanged: …)` works
/// without ceremony.
class LiveSearchField extends StatefulWidget {
  /// A search field.
  const new({
    this.controller,
    this.focusNode,
    this.hint,
    this.autofocus = false,
    this.enabled = true,
    this.onChanged,
    this.onSubmitted,
    this.onClear,
    super.key,
  });

  /// The text controller.
  final TextEditingController? controller;

  /// The focus node, for pages that manage focus themselves.
  final FocusNode? focusNode;

  /// The placeholder; the caller supplies a localized string.
  final String? hint;

  /// Whether it takes focus when the view opens.
  final bool autofocus;

  /// Whether the field accepts input.
  final bool enabled;

  /// Called on every change.
  final ValueChanged<String>? onChanged;

  /// Called when the user submits the search.
  final ValueChanged<String>? onSubmitted;

  /// Called when the user clears the field.
  final VoidCallback? onClear;

  @override
  State<LiveSearchField> createState() => _LiveSearchFieldState();
}

class _LiveSearchFieldState extends State<LiveSearchField> {
  TextEditingController? _owned;

  TextEditingController get _controller => widget.controller ?? (_owned ??= TextEditingController());

  @override
  void dispose() {
    _owned?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => LiveTheme.of(context).components.searchField(
    context,
    LiveSearchFieldSpec(
      controller: widget.controller ?? _controller,
      focusNode: widget.focusNode,
      hint: widget.hint,
      autofocus: widget.autofocus,
      enabled: widget.enabled,
      onChanged: widget.onChanged,
      onSubmitted: widget.onSubmitted,
      onClear: widget.onClear,
    ),
  );
}
