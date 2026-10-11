import 'package:flutter/widgets.dart';

/// The text roles and their styles.
///
/// Pages ask for a role — `title`, `body`, `caption` — and get a
/// [TextStyle] that already carries the design language's family, weight,
/// size and letter spacing. This set is deliberately *not* Material's
/// `TextTheme`: it is the neutral vocabulary every language maps to, so a
/// page never sees Material's `titleMedium` naming and a non-Material
/// language is not forced to imitate it. The Material theme builder copies
/// these roles into its own `TextTheme`, which is one mapping among six.
///
/// Font sizes are scaled per role rather than multiplied blindly: a TV
/// build enlarges body text more than captions, because that is what
/// becomes unreadable at three metres.
@immutable
final class LiveTypography {
  /// A typography from its eight roles.
  const new({
    required this.display,
    required this.headline,
    required this.title,
    required this.subtitle,
    required this.body,
    required this.bodySmall,
    required this.caption,
    required this.label,
    this.fontFamily,
  });

  /// The neutral default scale — sizes, weights and line heights that read
  /// well on every platform before a design language refines them.
  ///
  /// Keep this in sync with [fontFamily]: a language that ships a typeface
  /// passes it here and every role picks it up.
  // The `new(...)` shorthand does not parse in factory bodies on the
  // current SDK, so the type name stays.
  // ignore: unnecessary_type_name_in_constructor
  factory LiveTypography.standard({String? fontFamily}) => LiveTypography(
    display: TextStyle(
      fontSize: 28,
      height: 1.25,
      fontWeight: FontWeight.w600,
      fontFamily: fontFamily,
      letterSpacing: 0,
    ),
    headline: TextStyle(
      fontSize: 22,
      height: 1.3,
      fontWeight: FontWeight.w600,
      fontFamily: fontFamily,
      letterSpacing: 0,
    ),
    title: TextStyle(fontSize: 18, height: 1.35, fontWeight: FontWeight.w600, fontFamily: fontFamily, letterSpacing: 0),
    subtitle: TextStyle(
      fontSize: 15,
      height: 1.4,
      fontWeight: FontWeight.w500,
      fontFamily: fontFamily,
      letterSpacing: 0,
    ),
    body: TextStyle(fontSize: 15, height: 1.45, fontWeight: FontWeight.w400, fontFamily: fontFamily, letterSpacing: 0),
    bodySmall: TextStyle(
      fontSize: 13,
      height: 1.4,
      fontWeight: FontWeight.w400,
      fontFamily: fontFamily,
      letterSpacing: 0,
    ),
    caption: TextStyle(
      fontSize: 12,
      height: 1.35,
      fontWeight: FontWeight.w400,
      fontFamily: fontFamily,
      letterSpacing: 0.2,
    ),
    label: TextStyle(
      fontSize: 14,
      height: 1.3,
      fontWeight: FontWeight.w600,
      fontFamily: fontFamily,
      letterSpacing: 0.1,
    ),
    fontFamily: fontFamily,
  );

  /// The largest text: page headers and empty states.
  final TextStyle display;

  /// Section headers.
  final TextStyle headline;

  /// Card titles and dialog headers.
  final TextStyle title;

  /// Subtitles and emphasised metadata.
  final TextStyle subtitle;

  /// Running text.
  final TextStyle body;

  /// Dense running text (lists, tables).
  final TextStyle bodySmall;

  /// Captions, timestamps, badges.
  final TextStyle caption;

  /// Button and chip labels.
  final TextStyle label;

  /// The family every role was built with, when the language named one.
  final String? fontFamily;

  /// A copy with every size multiplied by [factor], for TV builds and the
  /// user's text-scale preference.
  LiveTypography scaled(double factor) {
    if (factor == 1) {
      return this;
    }
    TextStyle grow(TextStyle style) =>
        style.copyWith(fontSize: style.fontSize == null ? null : style.fontSize! * factor);
    return LiveTypography(
      display: grow(display),
      headline: grow(headline),
      title: grow(title),
      subtitle: grow(subtitle),
      body: grow(body),
      bodySmall: grow(bodySmall),
      caption: grow(caption),
      label: grow(label),
      fontFamily: fontFamily,
    );
  }

  /// A copy recoloured for [color], for text on a coloured surface.
  LiveTypography colored(Color color) => LiveTypography(
    display: display.copyWith(color: color),
    headline: headline.copyWith(color: color),
    title: title.copyWith(color: color),
    subtitle: subtitle.copyWith(color: color),
    body: body.copyWith(color: color),
    bodySmall: bodySmall.copyWith(color: color),
    caption: caption.copyWith(color: color),
    label: label.copyWith(color: color),
    fontFamily: fontFamily,
  );

  /// A copy with some roles replaced.
  LiveTypography copyWith({
    TextStyle? display,
    TextStyle? headline,
    TextStyle? title,
    TextStyle? subtitle,
    TextStyle? body,
    TextStyle? bodySmall,
    TextStyle? caption,
    TextStyle? label,
    String? fontFamily,
  }) => LiveTypography(
    display: display ?? this.display,
    headline: headline ?? this.headline,
    title: title ?? this.title,
    subtitle: subtitle ?? this.subtitle,
    body: body ?? this.body,
    bodySmall: bodySmall ?? this.bodySmall,
    caption: caption ?? this.caption,
    label: label ?? this.label,
    fontFamily: fontFamily ?? this.fontFamily,
  );

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    return other is LiveTypography &&
        other.display == display &&
        other.headline == headline &&
        other.title == title &&
        other.subtitle == subtitle &&
        other.body == body &&
        other.bodySmall == bodySmall &&
        other.caption == caption &&
        other.label == label &&
        other.fontFamily == fontFamily;
  }

  @override
  int get hashCode => Object.hash(display, headline, title, subtitle, body, bodySmall, caption, label, fontFamily);
}
