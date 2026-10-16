import 'package:fluent_ui/fluent_ui.dart' as fluent;
import 'package:flutter/widgets.dart';
import 'package:live_uikit/styling.dart';

/// Builds a Fluent toast surface from a [LanguageToastSpec] (§9 Toast).
///
/// Fluent's answer to a transient status message is `InfoBar`, and it is a
/// banner rather than a pill: full width, its own severity colour and glyph, no
/// shadow. So the severity drives `InfoBar.severity` and the library draws the
/// icon — [LanguageToastSpec.icon] and [LanguageToastSpec.accent] overrides are
/// recorded as unmapped because an `InfoBar` picks both from its severity, and
/// forcing the token pill's colours onto it would give a Fluent screen a
/// non-Fluent banner.
///
/// The placement, the fade-and-slide and the dismissal timer are the core's
/// (`LiveToast`), so the message still arrives from the top of the window and
/// leaves by itself.
abstract final class FluentToastBuilder {
  /// Builds the toast surface for [spec].
  static Widget build(BuildContext context, LanguageToastSpec spec) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      child: fluent.InfoBar(title: Text(spec.message), severity: _severity(spec.type), isLong: true),
    );
  }

  static fluent.InfoBarSeverity _severity(LiveToastType type) => switch (type) {
    LiveToastType.info => fluent.InfoBarSeverity.info,
    LiveToastType.success => fluent.InfoBarSeverity.success,
    LiveToastType.warning => fluent.InfoBarSeverity.warning,
    LiveToastType.error => fluent.InfoBarSeverity.error,
  };
}
