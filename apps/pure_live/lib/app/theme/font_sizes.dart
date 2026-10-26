import 'package:desen_ui/desen_ui.dart';
import 'package:flutter/foundation.dart' show immutable;
import 'package:flutter/painting.dart' show TextStyle;

/// The reference's typography tokens, in logical pixels, and the bounds its
/// sliders allow.
const double kDefaultFontSizeBodySmall = 12;
const double kMinFontSizeBodySmall = 9;
const double kMaxFontSizeBodySmall = 15;

const double kDefaultFontSizeBodyMedium = 13;
const double kMinFontSizeBodyMedium = 11;
const double kMaxFontSizeBodyMedium = 17;

const double kDefaultFontSizeBodyLarge = 14;
const double kMinFontSizeBodyLarge = 12;
const double kMaxFontSizeBodyLarge = 18;

const double kDefaultFontSizeTitleMedium = 15;
const double kMinFontSizeTitleMedium = 13;
const double kMaxFontSizeTitleMedium = 20;

const double kDefaultFontSizeTitleLarge = 20;
const double kMinFontSizeTitleLarge = 16;
const double kMaxFontSizeTitleLarge = 26;

/// Persisted keys, one per reference token.
const String kFontSizeBodySmallPrefsKey = 'theme.fontSizeBodySmall';
const String kFontSizeBodyMediumPrefsKey = 'theme.fontSizeBodyMedium';
const String kFontSizeBodyLargePrefsKey = 'theme.fontSizeBodyLarge';
const String kFontSizeTitleMediumPrefsKey = 'theme.fontSizeTitleMedium';
const String kFontSizeTitleLargePrefsKey = 'theme.fontSizeTitleLarge';

/// The viewer's five typography sizes, named after the reference's
/// `fontSizeBody*` and `fontSizeTitle*` settings.
@immutable
final class AppFontSizes {
  const AppFontSizes({
    this.bodySmall = kDefaultFontSizeBodySmall,
    this.bodyMedium = kDefaultFontSizeBodyMedium,
    this.bodyLarge = kDefaultFontSizeBodyLarge,
    this.titleMedium = kDefaultFontSizeTitleMedium,
    this.titleLarge = kDefaultFontSizeTitleLarge,
  });

  /// The viewer's micro-metadata size.
  final double bodySmall;

  /// The viewer's standard body size.
  final double bodyMedium;

  /// The viewer's prominent body size.
  final double bodyLarge;

  /// The viewer's card and section header size.
  final double titleMedium;

  /// The viewer's page, dialog and app bar title size.
  final double titleLarge;

  AppFontSizes copyWith({
    double? bodySmall,
    double? bodyMedium,
    double? bodyLarge,
    double? titleMedium,
    double? titleLarge,
  }) => AppFontSizes(
    bodySmall: bodySmall ?? this.bodySmall,
    bodyMedium: bodyMedium ?? this.bodyMedium,
    bodyLarge: bodyLarge ?? this.bodyLarge,
    titleMedium: titleMedium ?? this.titleMedium,
    titleLarge: titleLarge ?? this.titleLarge,
  );

  @override
  bool operator ==(Object other) =>
      other is AppFontSizes &&
      other.bodySmall == bodySmall &&
      other.bodyMedium == bodyMedium &&
      other.bodyLarge == bodyLarge &&
      other.titleMedium == titleMedium &&
      other.titleLarge == titleLarge;

  @override
  int get hashCode => Object.hash(bodySmall, bodyMedium, bodyLarge, titleMedium, titleLarge);
}

/// Clamps a stored or chosen size; a missing or unreadable value keeps
/// [fallback].
double normalizeFontSize(double? value, {required double fallback, required double min, required double max}) {
  if (value == null || !value.isFinite) return fallback;
  return value.clamp(min, max);
}

/// The reference's size mapping for a text theme: title roles take Title
/// Large and Title Medium, body roles take Body Large, list and description
/// roles Body Medium, and metadata roles Body Small. Weights, families and
/// line-height multipliers stay as the design system set them; tracking
/// stays in em when the size changes.
DsTypography applyAppFontSizes(DsTypography base, AppFontSizes sizes) {
  TextStyle at(TextStyle style, double size) {
    final from = style.fontSize;
    if (from == null || from == 0 || from == size) return style;
    final tracking = (style.letterSpacing ?? 0) / from;
    return style.copyWith(fontSize: size, letterSpacing: tracking * size);
  }

  return base.copyWith(
    title: at(base.title, sizes.titleLarge),
    heading: at(base.heading, sizes.titleMedium),
    body: at(base.body, sizes.bodyLarge),
    bodyStrong: at(base.bodyStrong, sizes.bodyLarge),
    small: at(base.small, sizes.bodyMedium),
    label: at(base.label, sizes.bodyMedium),
    labelStrong: at(base.labelStrong, sizes.bodyMedium),
    caption: at(base.caption, sizes.bodySmall),
    fieldLabel: at(base.fieldLabel, sizes.bodySmall),
  );
}
