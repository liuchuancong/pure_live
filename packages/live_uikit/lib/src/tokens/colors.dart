import 'package:flutter/widgets.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'colors.freezed.dart';

/// The semantic colour tokens.
///
/// Pages and components name roles — `surface`, `primary`, `textSecondary`,
/// `focus` — and never a shade: `Colors.blueGrey.shade800` in a page is a
/// bug that only shows on the design language nobody tested. Each language
/// resolves these roles into its own palette; the Material palette derived
/// from the user's accent is the base every language starts from.
// ignore_for_file: unnecessary_type_name_in_constructor -- Freezed
// factories cannot use the `new` shorthand.
@freezed
abstract class LiveColorTokens with _$LiveColorTokens {
  /// A palette of semantic roles.
  const factory LiveColorTokens({
    /// The page background.
    required Color surface,

    /// One step above the page: cards, raised panels.
    required Color surfaceElevated,

    /// The neighbour tone for inputs, chips and inactive rows.
    required Color surfaceVariant,

    /// A translucent sheet colour painted over content (control bars,
    /// gradient scrims).
    required Color surfaceOverlay,

    /// The accent: primary actions and selection.
    required Color primary,

    /// The colour that reads on `primary`.
    required Color onPrimary,

    /// The supporting accent (secondary actions, badges).
    required Color secondary,

    /// Borders of inputs and outlined controls.
    required Color outline,

    /// Hairlines between rows and sections.
    required Color divider,

    /// Destructive and failed states.
    required Color error,

    /// The colour that reads on `error`.
    required Color onError,

    /// Confirmations and live badges.
    required Color success,

    /// Warnings and degraded states.
    required Color warning,

    /// The focus ring — deliberately distinct from `primary` so focus stays
    /// visible on an accented button.
    required Color focus,

    /// Body text.
    required Color textPrimary,

    /// Captions, metadata, secondary labels.
    required Color textSecondary,

    /// Disabled labels and icons.
    required Color textDisabled,

    /// The base colour of shadows and elevation.
    required Color shadow,

    /// The modal barrier over blocked content.
    required Color scrim,
  }) = _LiveColorTokens;
}
