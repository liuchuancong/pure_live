// Module: lib/src/scale_tokens.dart
// Purpose: The measurable half of the vocabulary: spacing, corners, density, motion and type sizes.
// Author: liuchuancong
// Created: 2026-10-10
//
// Spec: section 5.4 of docs/architecture/pure_live_v2_flutter_technology_stack.md. Everything here is a
// number, so a style adapter can map it without inventing its own scale and a test can assert the scale
// instead of eyeballing a screenshot.
//
// Two rules are baked in because they were gotchas in the reference app this project grew out of:
//
// - Type sizes are *base* sizes. A surface multiplies them by the platform's text scale; nothing here
//   clamps that factor back toward 1, because a control that ignores text scaling is unreadable for the
//   people who set it. The only floor is [TypeRole.minReadableLogicalPx], which says how small a role may
//   get on a ten-foot screen even when the user has not turned anything up.
// - Motion has a reduced profile that zeroes durations rather than shortening them, and a remote input mode
//   never animates a control's size: a focused button that grows moves the rows below it, which on a d-pad
//   reads as the interface flinching.

import 'semantic_roles.dart';

/// A step in the spacing scale.
enum SpaceToken {
  /// 2 logical px: hairline gaps inside a dense row.
  space2(2),

  /// 4: icon to label.
  space4(4),

  /// 8: between controls in a group.
  space8(8),

  /// 12: card padding on compact density.
  space12(12),

  /// 16: the default gap and card padding.
  space16(16),

  /// 24: between sections.
  space24(24),

  /// 32: page gutters on a phone.
  space32(32),

  /// 48: page gutters on a TV.
  space48(48);

  const SpaceToken(this.px);

  /// Logical pixels, before any density or text scale is applied.
  final double px;
}

/// A corner radius step.
///
/// The numbers are what the shipped surfaces already draw, so adopting the enum is not a silent restyle:
/// changing a value here is a design decision on its own, made against a screenshot rather than a refactor.
enum RadiusToken {
  /// 6: the least rounding that still reads as intentional.
  small(6),

  /// 12: the default control corner.
  medium(12),

  /// 20: cards and sheets.
  large(20),

  /// 28: the soft style's generous corners.
  extraLarge(28);

  const RadiusToken(this.px);

  final double px;
}

/// How much room a layout leaves between and around controls.
enum Density {
  /// Mouse and keyboard: smaller targets, tighter rows.
  compact(0.85),

  /// The default.
  standard(1),

  /// Touch and TV: everything you can aim at gets bigger.
  comfortable(1.25);

  const Density(this.scale);

  /// Multiplier applied to a control's base size. Text does not use it - the platform's text scale owns
  /// that axis, and folding the two together makes a setting nobody can reason about.
  final double scale;

  /// The density a platform profile starts from. A user's choice overrides it; this is only the default so
  /// a TV does not open in a phone's density.
  static Density forPlatform(PlatformProfile profile) => switch (profile) {
    PlatformProfile.androidTv => Density.comfortable,
    PlatformProfile.windows || PlatformProfile.macos || PlatformProfile.linux => Density.compact,
    PlatformProfile.androidPhone || PlatformProfile.ios => Density.standard,
  };
}

/// A kind of text in the layout.
enum TypeRole {
  /// Page title.
  titleLarge(22, 28),

  /// Section heading.
  titleMedium(18, 24),

  /// List row primary text.
  bodyLarge(16, 24),

  /// Default body text.
  bodyMedium(14, 20),

  /// Secondary text: timestamps, subtitles.
  bodySmall(12, 16),

  /// The smallest label that may still be used, e.g. a chip.
  labelSmall(11, 14),

  /// Fixed-width text: a log line, a technical id.
  monospace(13, 20);

  const TypeRole(this.basePx, this.lineHeightPx);

  /// The designed size in logical pixels, before the platform's text scale.
  final double basePx;

  /// The baseline height that goes with it.
  final double lineHeightPx;

  /// The smallest this role may be rendered on a ten-foot screen.
  ///
  /// Only meaningful for remote input: a phone user who has not enlarged anything can legitimately read 11,
  /// while the same size on a TV at three metres is a wall of grey. A surface takes the maximum of its
  /// scaled size and this floor - never the minimum of the two, which would be clamping the user's setting.
  double minReadableLogicalPx(InputMode mode) => switch (mode) {
    InputMode.remote => basePx < 16 ? 16 : basePx,
    InputMode.touch || InputMode.pointer => basePx < 11 ? 11 : basePx,
  };

  /// The size for [textScale], with the [mode] floor applied.
  double sizeFor({required double textScale, InputMode mode = InputMode.touch}) {
    final scaled = basePx * textScale;
    final floor = minReadableLogicalPx(mode);
    return scaled < floor ? floor : scaled;
  }
}

/// How long things take to move, and whether they move at all.
final class MotionProfile {
  const MotionProfile({
    required this.instant,
    required this.quick,
    required this.standard,
    required this.slow,
    required this.scaleOnFocusAllowed,
    required this.curveName,
  });

  /// Under 100ms: a press feedback, a chip toggle.
  final Duration instant;

  /// A control's own state change.
  final Duration quick;

  /// A sheet, a page transition within a view.
  final Duration standard;

  /// Anything that reveals a lot of content at once.
  final Duration slow;

  /// Whether a focused control may change size. False for remote input: growth shifts the rows underneath
  /// the focus, which on a d-pad looks like the interface flinching.
  final bool scaleOnFocusAllowed;

  /// The easing named by role, so a style can map it to its own curve without a feature choosing one.
  final String curveName;

  /// The normal profile for [mode].
  factory MotionProfile.forMode(InputMode mode) => MotionProfile.normal(mode);

  MotionProfile.normal(InputMode mode)
    : instant = const Duration(milliseconds: 80),
      quick = const Duration(milliseconds: 140),
      standard = const Duration(milliseconds: 220),
      slow = const Duration(milliseconds: 360),
      // A TV is driven by focus and has no hover to soften, so the size change is the one thing that must
      // not move other rows. Touch keeps it: a pressed button under a finger is expected to grow.
      scaleOnFocusAllowed = mode != InputMode.remote,
      curveName = 'standard';

  /// Everything a "reduce motion" request turns into: durations are zero, not shortened.
  ///
  /// Shortening still moves content, which is what the setting is asking for an escape from.
  static const MotionProfile reduced = MotionProfile(
    instant: Duration.zero,
    quick: Duration.zero,
    standard: Duration.zero,
    slow: Duration.zero,
    scaleOnFocusAllowed: false,
    curveName: 'linear',
  );

  /// The profile for a reduce-motion preference; [reduced] wins over a mode that would otherwise animate.
  factory MotionProfile.resolve({required InputMode mode, required bool reduceMotion}) =>
      reduceMotion ? MotionProfile.reduced : MotionProfile.forMode(mode);
}
