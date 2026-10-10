// Module: lib/src/semantic_roles.dart
// Purpose: The names a style resolves, never the values - so a style swap changes one file.
// Author: liuchuancong
// Created: 2026-10-10
//
// Spec: docs/architecture/pure_live_v2_flutter_technology_stack.md section 5.4 asks every style adapter to
// map the same semantic colour set, focus states and density, so a feature never writes one set of Material
// constants and another set of Fluent ones. Roles are the contract; the concrete Color values live in the
// style that builds a scheme.
//
// Two decisions worth stating: a role is named for what it means, not for the Material 3 slot it currently
// maps to (the six styles do not share Material's naming), and the focus states are an exhaustive enum
// because a surface that forgets `disabled` renders the same as `resting` and a d-pad user cannot tell.

/// A colour role a style must answer for.
enum ColorRole {
  /// The main canvas behind content.
  surface,

  /// A secondary canvas: cards, wells, inset panels.
  surfaceVariant,

  /// The most prominent interactive colour.
  primary,

  /// Text or icon drawn on [primary].
  onPrimary,

  /// The least prominent text that still has to be readable.
  onSurfaceVariant,

  /// Body and heading text on [surface].
  onSurface,

  /// A destructive action or an unrecoverable state.
  error,

  /// Hairlines and outlines that separate without competing with content.
  outline,

  /// A quieter outline than [outline], for dividers and disabled borders.
  outlineVariant,

  /// A fill behind a selected row or chip.
  selection,

  /// A fill behind a focused control - drawn as a ring, not a fill, when [FocusShape] says ring.
  focus,

  /// A scrim behind a modal.
  scrim,

  /// A colour meant to be read against a dark backdrop regardless of brightness (a subtitle over video).
  overlayText,
}

/// The interactive states a control can be drawn in.
enum ControlState { resting, hovered, focused, selected, pressed, disabled }

/// How a focused control announces itself.
enum FocusShape {
  /// A ring outside the control's bounds. The default, and the only shape that survives every style: an
  /// inside glow disappears on a filled control, and a scale change is refused on TV (see MotionProfile).
  ring,

  /// A thicker outline replacing the resting one, for styles without room outside the bounds.
  outline,

  /// A tonal fill behind the control, for high-contrast styles where a ring vanishes.
  glow,
}

/// The reason a background is being drawn, so the resolver can pick its own rules.
enum InputMode {
  /// A finger: touch targets are the constraint.
  touch,

  /// A pointer: hit areas can be smaller and hover exists.
  pointer,

  /// A d-pad: focus is the only cursor, so every state a pointer sees by hover has to be visible by focus,
  /// and text has to survive a ten-foot viewing distance.
  remote,
}

/// The device family a layout is being sized for.
enum PlatformProfile {
  androidPhone(InputMode.touch),
  androidTv(InputMode.remote),
  ios(InputMode.touch),
  windows(InputMode.pointer),
  macos(InputMode.pointer),
  linux(InputMode.pointer);

  const PlatformProfile(this.preferredInput);

  /// What this platform is normally operated with. A user can override it - a Windows box driven by a remote
  /// is a real configuration - so this is a default, never a derivation.
  final InputMode preferredInput;
}
