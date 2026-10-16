import 'package:flutter/widgets.dart';
import 'package:glass_morphism_plus/glass_morphism_plus.dart' as glass;
import 'package:live_uikit/live_uikit.dart';

/// Builds a frosted list row from a [LanguageListRowSpec] (§9 List row).
///
/// Mapped: `glass_morphism_plus` does ship a row — [glass.GlassListTile], a
/// [glass.GlassContainer] sheet with the leading, title, subtitle and trailing
/// slots the spec carries — so the control is the library's own and the surface,
/// radius, blur and stroke are its inherited values (§8). Two things the library
/// hardcodes are given back to the theme rather than left alone: it styles the
/// title and subtitle white whatever the brightness, so each is wrapped in the
/// token's text role, and its own margin is kept, since a floating frosted row is
/// what the surface is for.
///
/// [LanguageListRowSpec.selected] raises the sheet's opacity and takes the token's
/// selected tint as its colour, which is how this adapter marks a choice
/// everywhere; [LanguageListRowSpec.divided] appends the library's own
/// [glass.GlassDivider]. [LanguageListRowSpec.focusNode] and
/// [LanguageListRowSpec.autofocus] have no slot: `GlassListTile` builds its
/// Material row inside the sheet and forwards no focus parameter, so a glass row
/// is reached by the traversal around it, not handed a node (§15).
abstract final class GlassListRowBuilder {
  /// Builds the row for [spec].
  static Widget build(BuildContext context, LanguageListRowSpec spec) {
    final theme = LiveTheme.of(context);
    final glassTheme = glass.GlassTheme.of(context);
    final lt = theme.listTile;

    final row = glass.GlassListTile(
      leading: spec.leading,
      title: Text(
        spec.title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: theme.text.body.copyWith(color: theme.colors.text),
      ),
      subtitle: spec.subtitle == null
          ? null
          : Text(
              spec.subtitle!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.text.bodySmall.copyWith(color: theme.colors.textSecondary),
            ),
      trailing: spec.trailing,
      // A row with no callback is inert rather than greyed: `GlassListTile` folds
      // `enabled` into its Material row, which dims the labels the contract wants
      // kept readable, so the spec's nullability drives the callbacks instead.
      onTap: spec.onTap,
      onLongPress: spec.onLongPress,
      color: spec.selected ? theme.colors.primaryBg : glassTheme.color,
      opacity: spec.selected ? (glassTheme.opacity * 2.6).clamp(0.0, 1.0) : glassTheme.opacity,
      borderColor: spec.selected ? theme.colors.primary : glassTheme.borderColor,
    );

    if (!spec.divided) {
      return row;
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        row,
        glass.GlassDivider(thickness: theme.token.motion.lineWidth, color: lt.dividerColor),
      ],
    );
  }
}
