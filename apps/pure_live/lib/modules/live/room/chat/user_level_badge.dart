import 'package:desen_ui/desen_ui.dart';
import 'package:flutter/widgets.dart';

/// A user-level badge built from the library's own [DsBadge]: the tier's
/// gradient is resolved to a solid fill, the tier glyph is one of [DsIcons],
/// and the number is the badge's label. No hand-drawn badge surface.
///
/// Tiers follow Huya's ladder and keep going past it:
/// - 1–9 green leaf
/// - 10–19 blue star
/// - 20–29 red moon
/// - 30–39 pink flower
/// - 40–49 purple gem
/// - 50–59 gold crown
/// - 60–79 amber crown
/// - 80–99 platinum star
/// - 100–199 diamond gem
/// - 200+ mythic sparkles
final class UserLevelBadge extends StatelessWidget {
  const UserLevelBadge({required this.level, this.height = 20, super.key});

  /// The numeric level; values at or below zero render nothing.
  final int level;

  /// The badge's height; the width follows the glyph and digits.
  final double height;

  @override
  Widget build(BuildContext context) {
    if (level <= 0) return const SizedBox.shrink();
    final style = _styleOf(level);
    final icon = height * 0.5;
    return Semantics(
      label: 'Lv.$level',
      child: DsBadge(
        dot: false,
        icon: DsIcon(_iconOf(style.tier), size: icon, color: style.ink),
        label: Text('$level'),
        style: DsBadgeStyle(
          height: height,
          padding: EdgeInsets.symmetric(horizontal: height * 0.26, vertical: (height - icon) / 2),
          background: style.background,
          foreground: style.ink,
          borderColor: const Color(0x38FFFFFF),
          borderRadius: BorderRadius.circular(height * 0.30),
          textStyle: TextStyle(fontSize: height * 0.46, fontWeight: FontWeight.w800, height: 1, letterSpacing: -0.2),
          iconSize: icon,
          gap: height * 0.14,
        ),
      ),
    );
  }
}

DsIconData _iconOf(_LevelTier tier) => switch (tier) {
  _LevelTier.leaf => DsIcons.leaf,
  _LevelTier.star || _LevelTier.platinum => DsIcons.star,
  _LevelTier.moon => DsIcons.moon,
  _LevelTier.bloom => DsIcons.flower,
  _LevelTier.gem || _LevelTier.diamond => DsIcons.gem,
  _LevelTier.crown || _LevelTier.amber => DsIcons.crown,
  _LevelTier.mythic => DsIcons.sparkles,
};

/// The badge's tier and palette.
enum _LevelTier { leaf, star, moon, bloom, gem, crown, amber, platinum, diamond, mythic }

final class _LevelTierStyle {
  const _LevelTierStyle(this.tier, this.top, this.bottom, {this.ink = const Color(0xFFFFFFFF)});

  final _LevelTier tier;
  final Color top;
  final Color bottom;

  /// The glyph and number ink; the silver tier needs a dark one.
  final Color ink;

  /// [DsBadge] takes a solid fill; the two gradient stops meet in the middle.
  Color get background => Color.lerp(top, bottom, 0.45)!;
}

_LevelTierStyle _styleOf(int level) {
  if (level >= 200) return const _LevelTierStyle(_LevelTier.mythic, Color(0xFFFF4D6D), Color(0xFF7A1230));
  if (level >= 100) return const _LevelTierStyle(_LevelTier.diamond, Color(0xFF7FF0FF), Color(0xFF1BA8D8));
  if (level >= 80) {
    return const _LevelTierStyle(_LevelTier.platinum, Color(0xFFC7D7EA), Color(0xFF6E829B), ink: Color(0xFF1F2937));
  }
  if (level >= 60) return const _LevelTierStyle(_LevelTier.amber, Color(0xFFFFC24A), Color(0xFFE07A00));
  if (level >= 50) return const _LevelTierStyle(_LevelTier.crown, Color(0xFFFFD45A), Color(0xFFF08A00));
  if (level >= 40) return const _LevelTierStyle(_LevelTier.gem, Color(0xFFB18CFF), Color(0xFF7048D8));
  if (level >= 30) return const _LevelTierStyle(_LevelTier.bloom, Color(0xFFFF8AC8), Color(0xFFD7288C));
  if (level >= 20) return const _LevelTierStyle(_LevelTier.moon, Color(0xFFFF7A7A), Color(0xFFE5354A));
  if (level >= 10) return const _LevelTierStyle(_LevelTier.star, Color(0xFF7FC4FF), Color(0xFF2F7BFF));
  return const _LevelTierStyle(_LevelTier.leaf, Color(0xFF2BD9B2), Color(0xFF12A67C));
}
