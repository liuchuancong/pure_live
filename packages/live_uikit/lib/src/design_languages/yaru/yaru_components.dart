// Yaru is a Material theme with its own widgets on top, so Material's
// popup items and icons are part of this language rather than a fallback.
import 'package:flutter/material.dart' show Icon, Icons, InkWell, Material, MaterialType, PopupMenuItem;
import 'package:flutter/widgets.dart';
import 'package:live_uikit/src/components/contracts/live_component_specs.dart';
import 'package:live_uikit/src/components/contracts/live_design_language_components.dart';
import 'package:live_uikit/src/design_languages/material/material_components.dart';
import 'package:live_uikit/src/focus/live_focus_highlight.dart';
import 'package:live_uikit/src/theme/live_theme.dart';
import 'package:yaru/yaru.dart';

/// The Yaru implementation of the component contract.
///
/// Ubuntu's Yaru is a Material theme plus a handful of its own widgets, and
/// this implementation follows that split honestly instead of pretending
/// otherwise: the components Yaru ships ([YaruSearchField], [YaruIconButton],
/// [YaruPopupMenuButton], [YaruBorderContainer], the Yaru progress
/// indicators) are used natively, and the ones it does *not* ship — a text
/// button, a text field, an alert dialog — are the Material ones rendered
/// through the Yaru-tinted theme, which is exactly what Yaru applications
/// themselves do. Every delegated method says so in its own documentation,
/// so the fallback list is auditable component by component.
class YaruComponents implements LiveDesignLanguageComponents {
  /// The Yaru component set.
  const new();

  /// The implementation of the components Yaru has no widget for.
  static const MaterialComponents _material = MaterialComponents();

  /// Delegates to Material: Yaru ships no text button, and its applications
  /// use Material's, styled through the Yaru theme's radii, heights and
  /// palette.
  @override
  Widget button(BuildContext context, LiveButtonSpec spec) => _material.button(context, spec);

  @override
  Widget iconButton(BuildContext context, LiveIconButtonSpec spec) {
    final theme = LiveTheme.of(context);
    final geometry = theme.componentTheme;
    final interactive = spec.isInteractive;
    final selected = spec.selected;
    return LiveFocusHighlight(
      focusNode: spec.focusNode,
      radius: geometry.controlRadius,
      enabled: interactive,
      scale: 1,
      childBuilder: (context, node) => YaruIconButton(
        icon: Icon(
          spec.icon,
          size: geometry.iconSize,
          color: interactive
              ? (selected ? theme.colors.primary : theme.colors.textSecondary)
              : theme.colors.textDisabled,
        ),
        tooltip: spec.tooltip,
        isSelected: selected,
        focusNode: node,
        autofocus: spec.autofocus,
        onPressed: interactive ? spec.onPressed : null,
      ),
    );
  }

  /// Delegates to Material: Yaru has no text field of its own, and its
  /// applications use Material's `TextField` with the Yaru theme.
  @override
  Widget textField(BuildContext context, LiveTextFieldSpec spec) => _material.textField(context, spec);

  @override
  Widget searchField(BuildContext context, LiveSearchFieldSpec spec) {
    final theme = LiveTheme.of(context);
    final geometry = theme.componentTheme;
    return YaruSearchField(
      controller: spec.controller,
      focusNode: spec.focusNode,
      hintText: spec.hint,
      autofocus: spec.autofocus,
      onChanged: spec.onChanged,
      onSubmitted: spec.onSubmitted == null ? null : (value) => spec.onSubmitted?.call(value ?? ''),
      onClear: spec.onClear,
      fillColor: theme.colors.surfaceVariant,
      borderColor: theme.colors.outline,
      radius: Radius.circular(geometry.inputRadius),
    );
  }

  /// The card is a [YaruBorderContainer]: Ubuntu separates surfaces with a
  /// border rather than a shadow.
  @override
  Widget card(BuildContext context, LiveCardSpec spec) {
    final theme = LiveTheme.of(context);
    final geometry = theme.componentTheme;
    final padding = spec.padding ?? (spec.dense ? geometry.cardPaddingDense : geometry.cardPadding);
    final surface = YaruBorderContainer(
      color: theme.colors.surfaceElevated,
      borderRadius: BorderRadius.circular(geometry.cardRadius),
      child: Padding(padding: padding, child: spec.child),
    );
    if (spec.onTap == null && spec.onLongPress == null) {
      return surface;
    }
    return LiveFocusHighlight(
      focusNode: spec.focusNode,
      radius: geometry.cardRadius,
      scale: 1,
      childBuilder: (context, node) => Material(
        type: MaterialType.transparency,
        child: InkWell(
          focusNode: node,
          autofocus: spec.autofocus,
          onTap: spec.onTap,
          onLongPress: spec.onLongPress,
          borderRadius: BorderRadius.circular(geometry.cardRadius),
          child: surface,
        ),
      ),
    );
  }

  @override
  Widget menu(BuildContext context, LiveMenuSpec spec) {
    final theme = LiveTheme.of(context);
    final geometry = theme.componentTheme;
    return YaruPopupMenuButton<String>(
      enabled: spec.enabled,
      tooltip: spec.tooltip,
      onSelected: spec.onSelected,
      showArrow: false,
      itemBuilder: (context) => [
        for (final entry in spec.entries)
          PopupMenuItem<String>(
            value: entry.id,
            enabled: entry.enabled,
            height: geometry.menuItemHeight,
            child: DefaultTextStyle(
              style: theme.typography.body.copyWith(
                color: entry.danger
                    ? theme.colors.error
                    : entry.enabled
                    ? theme.colors.textPrimary
                    : theme.colors.textDisabled,
              ),
              child: Row(
                children: [
                  if (entry.icon case final icon?) ...[
                    Icon(icon, size: geometry.iconSize),
                    SizedBox(width: geometry.iconGap),
                  ],
                  Expanded(child: Text(entry.label, overflow: TextOverflow.ellipsis)),
                  if (entry.selected) ...[
                    SizedBox(width: geometry.iconGap),
                    Icon(Icons.check, size: geometry.iconSize, color: theme.colors.primary),
                  ],
                ],
              ),
            ),
          ),
      ],
      child: spec.child,
    );
  }

  /// Delegates to Material: Ubuntu shows Material dialogs with the Yaru
  /// theme, and Yaru ships no dialog of its own.
  @override
  Future<T?> dialog<T>(BuildContext context, LiveDialogSpec<T> spec) => _material.dialog<T>(context, spec);

  @override
  Widget progressIndicator(BuildContext context, LiveProgressIndicatorSpec spec) {
    final theme = LiveTheme.of(context);
    final value = spec.value;
    final strokeWidth = switch (spec.size) {
      LiveControlSize.small => 2.0,
      LiveControlSize.medium => 3.0,
      LiveControlSize.large => 4.0,
    };
    if (value == null) {
      return SizedBox.square(
        dimension: theme.componentTheme.loadingIndicatorSize,
        child: YaruCircularProgressIndicator(
          strokeWidth: strokeWidth,
          color: theme.colors.primary,
          semanticsLabel: spec.semanticLabel,
        ),
      );
    }
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: theme.componentTheme.dialogMaxWidth * 0.5),
      child: YaruLinearProgressIndicator(
        value: value.clamp(0, 1),
        strokeWidth: strokeWidth,
        color: theme.colors.primary,
        trackColor: theme.colors.surfaceVariant,
        semanticsLabel: spec.semanticLabel,
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
        Icon(spec.icon ?? YaruIcons.error, size: geometry.iconSize * 2, color: theme.colors.error),
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
            LiveButtonSpec(label: spec.retryLabel ?? 'Retry', icon: YaruIcons.refresh, onPressed: spec.onRetry),
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
        Icon(spec.icon ?? YaruIcons.folder, size: geometry.iconSize * 2, color: theme.colors.textDisabled),
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
}
