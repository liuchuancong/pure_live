import 'package:flutter/material.dart';

import 'package:live_uikit/src/theme/live_component_theme.dart';
import 'package:live_uikit/src/tokens/colors.dart';
import 'package:live_uikit/src/tokens/typography.dart';

/// Builds the Material [ThemeData] a design language leaves underneath its
/// own components.
///
/// Every language needs one: Flutter ships Material controls (scaffolds,
/// route transitions, text selection, snack bars, scrollbars) that read
/// `Theme.of(context)` whatever the design language is, and a page that
/// mixes a Fluent button with an unstyled Material scaffold must still get
/// coherent colours. A language therefore publishes its parts here — the
/// same colours, type scale and geometry its own components use — instead
/// of leaving Flutter's defaults on screen.
abstract final class LiveThemeData {
  /// The Material theme of [colors], [typography] and [componentTheme].
  static ThemeData of({
    required LiveColorTokens colors,
    required LiveTypography typography,
    required LiveComponentTheme componentTheme,
    required Brightness brightness,
  }) {
    final scheme = _schemeOf(colors, brightness);
    final textTheme = _textThemeOf(typography, colors);
    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      textTheme: textTheme,
      scaffoldBackgroundColor: colors.surface,
      canvasColor: colors.surfaceElevated,
      dividerColor: colors.divider,
      dividerTheme: DividerThemeData(color: colors.divider, thickness: 1, space: 1),
      splashFactory: NoSplash.splashFactory,
      focusColor: colors.focus.withValues(alpha: 0.12),
      hoverColor: colors.primary.withValues(alpha: 0.06),
      highlightColor: colors.primary.withValues(alpha: 0.08),
      visualDensity: VisualDensity.standard,
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        foregroundColor: colors.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: typography.title.copyWith(color: colors.textPrimary),
      ),
      cardTheme: CardThemeData(
        color: colors.surfaceElevated,
        surfaceTintColor: Colors.transparent,
        elevation: componentTheme.cardElevation,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(componentTheme.cardRadius)),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: colors.surfaceElevated,
        surfaceTintColor: Colors.transparent,
        elevation: 8,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(componentTheme.dialogRadius)),
        titleTextStyle: typography.title.copyWith(color: colors.textPrimary),
        contentTextStyle: typography.body.copyWith(color: colors.textSecondary),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: colors.surfaceElevated,
        surfaceTintColor: Colors.transparent,
        elevation: 8,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(componentTheme.menuRadius)),
        textStyle: typography.body.copyWith(color: colors.textPrimary),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colors.surfaceVariant,
        isDense: true,
        contentPadding: EdgeInsets.symmetric(
          horizontal: componentTheme.controlPadding,
          vertical: (componentTheme.inputHeight - (typography.body.fontSize ?? 15) * 1.45) / 2,
        ),
        border: _inputBorder(colors, componentTheme, colors.divider),
        enabledBorder: _inputBorder(colors, componentTheme, colors.outline.withValues(alpha: 0.5)),
        focusedBorder: _inputBorder(colors, componentTheme, colors.primary, width: componentTheme.inputBorderWidth + 1),
        errorBorder: _inputBorder(colors, componentTheme, colors.error),
        focusedErrorBorder: _inputBorder(
          colors,
          componentTheme,
          colors.error,
          width: componentTheme.inputBorderWidth + 1,
        ),
        hintStyle: typography.body.copyWith(color: colors.textDisabled),
        labelStyle: typography.bodySmall.copyWith(color: colors.textSecondary),
        errorStyle: typography.caption.copyWith(color: colors.error),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: colors.primary,
        linearTrackColor: colors.surfaceVariant,
        circularTrackColor: Colors.transparent,
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: colors.primary,
        inactiveTrackColor: colors.surfaceVariant,
        thumbColor: colors.primary,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected) ? colors.onPrimary : colors.outline,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected) ? colors.primary : colors.surfaceVariant,
        ),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected) ? colors.primary : Colors.transparent,
        ),
        side: BorderSide(color: colors.outline),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      ),
      scrollbarTheme: ScrollbarThemeData(
        thumbColor: WidgetStatePropertyAll(colors.outline.withValues(alpha: 0.6)),
        trackColor: const WidgetStatePropertyAll(Colors.transparent),
        thickness: const WidgetStatePropertyAll(6),
        radius: const Radius.circular(3),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(color: colors.surfaceOverlay, borderRadius: BorderRadius.circular(6)),
        textStyle: typography.caption.copyWith(color: colors.textPrimary),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: colors.surfaceElevated,
        contentTextStyle: typography.body.copyWith(color: colors.textPrimary),
        actionTextColor: colors.primary,
        behavior: SnackBarBehavior.floating,
        elevation: 4,
      ),
    );
  }

  static ColorScheme _schemeOf(LiveColorTokens colors, Brightness brightness) => ColorScheme(
    brightness: brightness,
    primary: colors.primary,
    onPrimary: colors.onPrimary,
    secondary: colors.secondary,
    onSecondary: colors.onPrimary,
    error: colors.error,
    onError: colors.onError,
    surface: colors.surface,
    onSurface: colors.textPrimary,
    surfaceContainerHigh: colors.surfaceElevated,
    surfaceContainerHighest: colors.surfaceVariant,
    outline: colors.outline,
    outlineVariant: colors.divider,
    shadow: colors.shadow,
    scrim: colors.scrim,
  );

  /// Maps the neutral roles onto Material's `TextTheme` slots.
  ///
  /// One mapping among six: a language that prefers its own widget set
  /// never reads these slots, but any Material widget that lands inside it
  /// still comes out with the right sizes and colours.
  static TextTheme _textThemeOf(LiveTypography typography, LiveColorTokens colors) {
    final display = typography.display.copyWith(color: colors.textPrimary);
    final headline = typography.headline.copyWith(color: colors.textPrimary);
    final title = typography.title.copyWith(color: colors.textPrimary);
    final subtitle = typography.subtitle.copyWith(color: colors.textSecondary);
    final body = typography.body.copyWith(color: colors.textPrimary);
    final bodySmall = typography.bodySmall.copyWith(color: colors.textSecondary);
    final caption = typography.caption.copyWith(color: colors.textSecondary);
    final label = typography.label.copyWith(color: colors.textPrimary);
    return TextTheme(
      displayLarge: typography.display,
      displayMedium: typography.display,
      displaySmall: display,
      headlineLarge: typography.headline,
      headlineMedium: typography.headline,
      headlineSmall: headline,
      titleLarge: typography.title,
      titleMedium: title,
      titleSmall: subtitle,
      bodyLarge: typography.body,
      bodyMedium: body,
      bodySmall: bodySmall,
      labelLarge: label,
      labelMedium: typography.label.copyWith(color: colors.textSecondary),
      labelSmall: caption,
    );
  }

  static OutlineInputBorder _inputBorder(
    LiveColorTokens colors,
    LiveComponentTheme componentTheme,
    Color color, {
    double? width,
  }) => OutlineInputBorder(
    borderRadius: BorderRadius.circular(componentTheme.inputRadius),
    borderSide: BorderSide(color: color, width: width ?? componentTheme.inputBorderWidth),
  );
}
