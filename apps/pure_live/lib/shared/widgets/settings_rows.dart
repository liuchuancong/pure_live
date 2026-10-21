import 'package:flutter/material.dart';
import 'package:pure_settings_ui/pure_settings_ui.dart';
import 'package:pure_uikit/pure_uikit.dart';

/// A labelled slider written in the settings kit's tile metrics: the title, its
/// value as an accent badge and the track under it.
///
/// `pure_settings_ui` models a switch, a destination and a custom tile — a slider
/// is none of those — so this is the one composition the settings cluster shares,
/// placed inside the section the active language already frames. The badge is the
/// reference's `buildSliderTile` reading: the number the track is set to, without
/// a tooltip to chase while dragging.
final class SettingsSliderRow extends StatelessWidget {
  /// A slider row.
  const new({
    required this.icon,
    required this.title,
    required this.value,
    required this.onChanged,
    this.subtitle,
    this.min = 0,
    this.max = 1,
    this.valueLabel,
    super.key,
  });

  /// The leading glyph.
  final IconData icon;

  /// The setting's name.
  final String title;

  /// The secondary line, or the value's legend when there is no description.
  final String? subtitle;

  /// The current value.
  final double value;

  /// The track's floor.
  final double min;

  /// The track's ceiling.
  final double max;

  /// Applies the dragged value.
  final ValueChanged<double> onChanged;

  /// The badge text; two decimals unless the setting spells it differently.
  final String? valueLabel;

  @override
  Widget build(BuildContext context) {
    final theme = PureTheme.of(context);
    // The row is placed inside a section card the language draws, and a language
    // whose card is not a Material (Cupertino's list section, Fluent's pane)
    // gives the Material slider no sheet to print on. The transparent Material
    // here is that sheet — it paints nothing and only satisfies the slider.
    return Material(
      type: MaterialType.transparency,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 22, color: theme.colors.primary),
                const SizedBox(width: 12),
                Expanded(child: Text(title, style: theme.text.title)),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: theme.colors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    valueLabel ?? value.toStringAsFixed(2),
                    style: theme.text.bodySmall.copyWith(color: theme.colors.primary, fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
            if (subtitle != null && subtitle!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 2, bottom: 2),
                child: Text(subtitle!, style: theme.text.caption.copyWith(color: theme.colors.textSecondary)),
              ),
            PureSlider(value: value.clamp(min, max), min: min, max: max, onChanged: onChanged),
          ],
        ),
      ),
    );
  }
}

/// A row of the uikit's own list rows, placed as a settings tile.
///
/// Two things a section's card owes a row and does not give it by itself. The
/// first is a sheet of its own: a `ListTile` prints its background and ink on the
/// nearest `Material`, and without this transparent one that is the card's own
/// coloured box, which Flutter reports as hiding the splash. The second is a
/// width — the kit measures a tile as a row, so the card's inset is already
/// applied and the row keeps its own leading/trailing metrics.
final class SettingsRowTile extends CustomSettingsTile {
  /// A tile over [row], the row wrapped in its own transparent sheet.
  new({required Widget row, super.key})
    : super(
        child: Material(type: MaterialType.transparency, child: row),
      );
}
