// The named `.card` factory cannot use the `new` shorthand.
// ignore_for_file: unnecessary_type_name_in_constructor

import 'package:flutter/material.dart';
import 'package:pure_uikit/pure_uikit.dart';

/// The settings pages' shared grammar, ported from the 3.x `buildGroupTitle` /
/// `buildModernCard` / `buildTile` helpers: a small primary-tinted group title
/// over a rounded card of icon + title + subtitle rows, the trailing slot
/// carrying the row's control or a chevron.
///
/// The rows are the uikit's own `PureListRow` — every design language draws
/// them its own way — so a section re-skins with the rest of the app.
final class SettingsSection extends StatelessWidget {
  /// A section with the group [label] over one entry of [children] per line.
  const new({required this.label, required this.children, super.key});

  /// A section whose [tiles] share one card, separated by the row divider
  /// every row but the last draws under itself.
  factory SettingsSection.card({required String label, required List<Widget> tiles}) => SettingsSection(
    label: label,
    children: [
      PureCard(
        padding: EdgeInsets.zero,
        child: Column(mainAxisSize: MainAxisSize.min, children: tiles),
      ),
    ],
  );

  /// The localized group label.
  final String label;

  /// The cards under the label, stacked with the section gap between them.
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = PureTheme.of(context);
    final spaced = <Widget>[
      for (var i = 0; i < children.length; i++) ...[if (i > 0) const SizedBox(height: 10), children[i]],
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 8, bottom: 8),
          child: Text(
            label,
            style: theme.text.caption.copyWith(
              fontWeight: FontWeight.w700,
              color: theme.colors.primary,
              letterSpacing: 0.5,
            ),
          ),
        ),
        ...spaced,
      ],
    );
  }
}

/// One settings entry: icon, title, optional subtitle, and a chevron (or an
/// explicit [trailing]) — the 3.x `buildTile` shape.
final class SettingsEntryTile extends StatelessWidget {
  /// An entry tile.
  const new({
    required this.icon,
    required this.title,
    this.subtitle,
    this.onTap,
    this.trailing,
    this.divided = true,
    super.key,
  });

  /// The leading icon.
  final IconData icon;

  /// The primary text.
  final String title;

  /// The secondary line.
  final String? subtitle;

  /// Opens the setting's editor; null renders the row inert.
  final VoidCallback? onTap;

  /// Overrides the chevron (a value preview, a switch…).
  final Widget? trailing;

  /// Whether a divider is drawn under the row.
  final bool divided;

  @override
  Widget build(BuildContext context) => PureListRow(
    leading: Icon(icon, size: 22),
    title: title,
    subtitle: subtitle,
    trailing: trailing ?? const Icon(Icons.chevron_right_rounded),
    onTap: onTap,
    divided: divided,
  );
}

/// A switch setting: the 3.x `buildSwitchTile` shape — icon, title, subtitle
/// and a trailing [PureSwitch]; tapping the row flips the switch.
final class SettingsSwitchTile extends StatelessWidget {
  /// A switch tile.
  const new({
    required this.icon,
    required this.title,
    required this.value,
    required this.onChanged,
    this.subtitle,
    this.divided = true,
    super.key,
  });

  /// The leading icon.
  final IconData icon;

  /// The primary text.
  final String title;

  /// The secondary line.
  final String? subtitle;

  /// Whether the switch is on.
  final bool value;

  /// Applies the flipped value.
  final ValueChanged<bool> onChanged;

  /// Whether a divider is drawn under the row.
  final bool divided;

  @override
  Widget build(BuildContext context) => PureListRow(
    leading: Icon(icon, size: 22),
    title: title,
    subtitle: subtitle,
    trailing: PureSwitch(value: value, onChanged: onChanged),
    onTap: () => onChanged(!value),
    divided: divided,
  );
}

/// A slider setting in its own padded card: the 3.x `buildSliderTile` shape —
/// a labelled block whose control sits under the title.
final class SettingsSliderCard extends StatelessWidget {
  /// A slider card.
  const new({required this.icon, required this.title, required this.child, this.subtitle, this.footer, super.key});

  /// The leading icon.
  final IconData icon;

  /// The primary text.
  final String title;

  /// The secondary line.
  final String? subtitle;

  /// The slider.
  final Widget child;

  /// A line under the slider (a preview, a unit legend).
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final theme = PureTheme.of(context);
    return PureCard(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(icon, size: 22),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(title, style: theme.text.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                    if (subtitle != null)
                      Text(
                        subtitle!,
                        style: theme.text.caption.copyWith(color: theme.colors.textSecondary),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          child,
          if (footer != null) ...[const SizedBox(height: 8), Center(child: footer)],
        ],
      ),
    );
  }
}

/// The gap between two sections.
final class SettingsSectionGap extends SizedBox {
  /// The gap.
  const new({super.key}) : super(height: 20);
}
