import 'package:flutter/material.dart';
import 'package:forui/forui.dart' as forui;
import 'package:glass_morphism_plus/glass_morphism_plus.dart' as glass;
import 'package:pure_uikit/src/styling/config/pure_design_language.dart';
import 'package:pure_uikit/src/styling/provider/pure_config_provider.dart';

/// A separator between content: one widget, every design language.
///
/// [build] switches on `UiConfig.language` and constructs the library's own
/// divider — Material's `Divider`, forui's `FDivider`, glass's `GlassDivider`,
/// the iOS hairline — so the rule matches the surfaces it separates rather than
/// staying a Material line under eight other skins. Where the library ships no
/// divider at all (neumorphic, wind, and the token surfaces) the hairline is
/// drawn from the same two tokens the libraries' own dividers resolve:
/// `motion.lineWidth` and the list's separator colour.
///
/// [extent] is the band the line sits in, not the line's thickness. Material
/// names that pair `height` and `thickness`; the other languages draw the line
/// alone, so a band is made by centring it in padding. Left null each language
/// keeps its own default — Material's gap, forui's, and a bare hairline
/// elsewhere — which is what a plain `const PureDivider()` asks for.
class PureDivider extends StatelessWidget {
  /// A hairline, optionally indented at either end, optionally set in an
  /// [extent]-tall band, and optionally drawn in [color] instead of the list's
  /// own separator.
  const new({this.indent, this.endIndent, this.extent, this.color, super.key});

  /// The gap left before the line begins.
  final double? indent;

  /// The gap left after the line ends.
  final double? endIndent;

  /// The band the line is centred in, or null for the language's own.
  final double? extent;

  /// A rule colour of its own, for a divider that separates a different kind of
  /// block than the list rows the token's separator serves.
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final theme = PureTheme.of(context);
    final line = theme.token.motion.lineWidth;
    final rule = color ?? theme.listTile.dividerColor;

    return switch (theme.config.language) {
      // Material owns both numbers: the band is `height`, the stroke inside it
      // is `thickness`, and the insets are its own.
      PureDesignLanguage.material || PureDesignLanguage.yaru => Divider(
        height: extent ?? line * 2,
        thickness: line,
        indent: indent,
        endIndent: endIndent,
        color: rule,
      ),
      // forui's divider is its own widget with the library's stroke and colour;
      // the insets are the only part this contract adds on top of it. It has no
      // colour slot, so a rule named here falls back to the token hairline.
      PureDesignLanguage.forui => color != null
        ? _hairline(line, rule)
        : _band(
            Padding(
              padding: EdgeInsetsDirectional.only(start: indent ?? 0, end: endIndent ?? 0),
              child: const forui.FDivider(),
            ),
            line,
          ),
      // The fork's divider takes a thickness and a colour, which is the same
      // pair Material names.
      PureDesignLanguage.glass => _band(
        Padding(
          padding: EdgeInsetsDirectional.only(start: indent ?? 0, end: endIndent ?? 0),
          child: glass.GlassDivider(thickness: line, color: rule),
        ),
        line,
      ),
      // The remaining libraries ship no divider widget — iOS included, whose
      // separators are drawn by the list section rather than by a widget — so
      // the hairline is drawn from the tokens those libraries' own rows
      // separate with.
      PureDesignLanguage.cupertino ||
      PureDesignLanguage.macos ||
      PureDesignLanguage.fluent ||
      PureDesignLanguage.neumorphic ||
      PureDesignLanguage.wind => _hairline(line, rule),
    };
  }

  /// The token hairline: the stroke every language's own divider resolves to,
  /// drawn where the library ships none (or none with the slot asked for).
  Widget _hairline(double thickness, Color rule) => _band(
    Padding(
      padding: EdgeInsetsDirectional.only(start: indent ?? 0, end: endIndent ?? 0),
      child: Container(height: thickness, color: rule),
    ),
    thickness,
  );

  /// The line centred in [PureDivider.extent], when the caller asked for a band
  /// wider than the stroke.
  Widget _band(Widget line, double thickness) {
    final band = extent;
    if (band == null || band <= thickness) {
      return line;
    }
    final gap = (band - thickness) / 2;
    return Padding(padding: EdgeInsets.symmetric(vertical: gap), child: line);
  }
}
