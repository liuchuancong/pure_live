import 'package:flutter/animation.dart';

/// The motion tokens: how long things take and how they get there.
///
/// Durations and curves are named by intent, not by milliseconds, so a
/// design language can retime the whole UI (Fluent is quicker, Neumorphic
/// softer) by overriding tokens instead of chasing call sites. Every
/// duration here is a *duration*; a reduced-motion environment collapses
/// them to [instant] in one place (`LiveTheme`).
abstract final class LiveMotion {
  /// 0 — no animation, for reduced-motion environments.
  static const Duration instant = Duration.zero;

  /// 100 ms — hover, press and focus-follower feedback.
  static const Duration fast = Duration(milliseconds: 100);

  /// 200 ms — the default for enters, exits and colour changes.
  static const Duration normal = Duration(milliseconds: 200);

  /// 300 ms — page transitions and larger surfaces.
  static const Duration slow = Duration(milliseconds: 300);

  /// 500 ms — hero-like moves and TV focus fly-outs.
  static const Duration slower = Duration(milliseconds: 500);

  /// The default curve for size and position changes.
  static const Curve standard = Curves.easeInOutCubic;

  /// The curve for things entering the screen.
  static const Curve decelerate = Curves.easeOutCubic;

  /// The curve for things leaving the screen.
  static const Curve accelerate = Curves.easeInCubic;

  /// A slightly springy curve for focus and selection feedback.
  static const Curve emphasized = Curves.easeOutBack;
}
