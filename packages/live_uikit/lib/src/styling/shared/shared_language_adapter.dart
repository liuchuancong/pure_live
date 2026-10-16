import 'package:flutter/material.dart';
import 'package:live_uikit/src/styling/contracts/live_ui_adapter.dart';
import 'package:live_uikit/src/styling/contracts/live_ui_capabilities.dart';
import 'package:live_uikit/src/styling/design_token.dart';
import 'package:live_uikit/src/styling/recipe.dart';
import 'package:live_uikit/src/styling/root/live_config_provider.dart';
import 'package:live_uikit/src/styling/style.dart';
import 'package:live_uikit/src/styling/widgets/live_app.dart';
import 'package:live_uikit/src/styling/widgets/live_app_bar.dart';
import 'package:live_uikit/src/styling/widgets/live_box.dart';
import 'package:live_uikit/src/styling/widgets/live_card.dart';
import 'package:live_uikit/src/styling/widgets/live_checkbox.dart';
import 'package:live_uikit/src/styling/widgets/live_field.dart';
import 'package:live_uikit/src/styling/widgets/live_nav_bar.dart';
import 'package:live_uikit/src/styling/widgets/live_progress.dart';
import 'package:live_uikit/src/styling/widgets/live_scaffold.dart';
import 'package:live_uikit/src/styling/widgets/live_segmented.dart';
import 'package:live_uikit/src/styling/widgets/live_select.dart';
import 'package:live_uikit/src/styling/widgets/live_slider.dart';
import 'package:live_uikit/src/styling/widgets/live_switch.dart';
import 'package:live_uikit/src/styling/widgets/live_tabs.dart';
import 'package:live_uikit/src/styling/widgets/live_toast.dart';

/// The token-driven base renderer: every control has a working default built
/// from [LiveBox] + the recipes. Library adapters extend this and override
/// only the controls (and the theme [wrap]) they map to a real widget, so an
/// unoverridden control still renders on-theme.
class SharedLanguageAdapter implements LanguageAdapter {
  /// The shared adapter.
  const new();

  /// Whether a button spec currently accepts a press (enabled, not loading,
  /// has a callback). Adapter packages reuse this from their own button builds.
  bool interactive(LanguageButtonSpec spec) => spec.enabled && !spec.loading && spec.onPressed != null;

  /// Wraps a bare control in a labelled row when the spec carries a label.
  Widget labelled(BuildContext context, String? label, Widget control) {
    if (label == null) {
      return control;
    }
    final theme = LiveTheme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        control,
        SizedBox(width: theme.token.scale.sizes.sm),
        Text(label, style: theme.text.body.copyWith(color: theme.colors.text)),
      ],
    );
  }

  /// A label (+ optional icon), or a spinner while loading, reused by adapters.
  Widget buttonLabel(LanguageButtonSpec spec, LiveTheme theme, {Color? foreground}) {
    if (spec.loading) {
      return SizedBox.square(
        dimension: theme.text.label.fontSize ?? 14,
        child: CircularProgressIndicator(strokeWidth: 2, color: foreground ?? theme.colors.onPrimary),
      );
    }
    if (spec.iconOnly) {
      // The empty `label` a textless button must still pass the contract is never
      // painted; the glyph carries the control and `tooltip` names it — including to
      // the semantics tree, which has no text left to absorb otherwise (§14).
      return Icon(
        spec.icon,
        size: theme.text.label.fontSize,
        color: foreground,
        semanticLabel: spec.tooltip ?? (spec.label.isEmpty ? null : spec.label),
      );
    }
    final text = Text(spec.label, overflow: TextOverflow.ellipsis);
    if (spec.icon == null) {
      return text;
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(spec.icon, size: theme.text.label.fontSize, color: foreground),
        SizedBox(width: theme.token.scale.sizes.xs),
        text,
      ],
    );
  }

  /// The square side an icon-only button takes at [size] — the same geometry the
  /// hand-drawn icon button used before it went through the adapter.
  double iconEdge(LiveTheme theme, ControlSize size) => switch (size) {
    ControlSize.sm => theme.button.controlHeightSM,
    ControlSize.md => theme.button.controlHeight,
    ControlSize.lg => theme.button.controlHeightLG,
  };

  @override
  LiveDesignLanguage get language => LiveDesignLanguage.material;

  @override
  String get id => language.name;

  @override
  String get displayName => language.name;

  @override
  LiveUiCapabilities get capabilities => const LiveUiCapabilities.none();

  @override
  Widget wrap(BuildContext context, DesignToken token, Widget child) => child;

  @override
  Widget button(BuildContext context, LanguageButtonSpec spec) {
    final theme = LiveTheme.of(context);
    final enabled = interactive(spec);
    Widget button = LiveBox(
      style: (state) {
        final resolved = theme.resolveButton(variant: spec.variant, size: spec.size, state: state);
        if (!spec.selected) {
          return resolved;
        }
        // A toggled-on control reads as its own primary colour, the way the
        // hand-drawn icon button did before it went through the contract.
        return resolved.copyWith(
          foreground: state == InteractionState.disabled ? theme.colors.textDisabled : theme.colors.primary,
        );
      },
      enabled: enabled,
      onTap: enabled ? spec.onPressed : null,
      focusNode: spec.focusNode,
      autofocus: spec.autofocus,
      inlineStyle: spec.style,
      child: buttonLabel(spec, theme),
    );
    if (spec.iconOnly) {
      // A textless control is sized by its own height step, not by the label it
      // does not have.
      button = SizedBox.square(
        dimension: iconEdge(theme, spec.size),
        child: Center(child: button),
      );
    }
    final sized = spec.expand ? SizedBox(width: double.infinity, child: button) : button;
    final hint = spec.tooltip;
    if (hint == null) {
      return sized;
    }
    // The caller's text verbatim (§14): every adapter wraps the same spec with
    // its own library's tooltip, so a style switch keeps the hint.
    return Tooltip(message: hint, child: sized);
  }

  @override
  Widget card(BuildContext context, LanguageCardSpec spec) => TokenCard(spec: spec);

  @override
  Widget textField(BuildContext context, LanguageTextFieldSpec spec) => TokenTextField(spec: spec);

  @override
  Widget switchWidget(BuildContext context, LanguageSwitchSpec spec) => TokenSwitch(spec: spec);

  @override
  Widget checkbox(BuildContext context, LanguageCheckboxSpec spec) => TokenCheckbox(spec: spec);

  @override
  Widget slider(BuildContext context, LanguageSliderSpec spec) => TokenSlider(spec: spec);

  @override
  Widget segmented(BuildContext context, LanguageSegmentedSpec spec) => TokenSegmented(spec: spec);

  @override
  Widget progress(BuildContext context, LanguageProgressSpec spec) => TokenProgress(spec: spec);

  @override
  Widget select<T>(BuildContext context, LanguageSelectSpec<T> spec) => TokenSelect<T>(
    items: spec.items,
    itemLabel: spec.itemLabel,
    onChanged: spec.onChanged,
    value: spec.value,
    placeholder: spec.placeholder,
    enabled: spec.enabled,
  );

  @override
  Widget tabBar(BuildContext context, LanguageTabsSpec spec) => TokenTabs(
    tabs: spec.tabs,
    index: spec.index,
    onChanged: spec.onChanged,
    spacing: spec.spacing,
    enabled: spec.enabled,
  );

  @override
  Widget scaffold(BuildContext context, LanguageScaffoldSpec spec) => TokenScaffold(spec: spec);

  @override
  Widget appBar(BuildContext context, LanguageAppBarSpec spec) => TokenAppBar(spec: spec);

  @override
  Widget listRow(BuildContext context, LanguageListRowSpec spec) => TokenListRow(spec: spec);

  @override
  Widget navBar(BuildContext context, LanguageNavBarSpec spec) => TokenNavBar(spec: spec);

  @override
  Widget toast(BuildContext context, LanguageToastSpec spec) => TokenToast(spec: spec);

  @override
  Widget host(BuildContext context, LanguageHostSpec spec) => TokenApp(spec: spec);
}
