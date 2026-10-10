// Module: lib/src/control_metrics.dart
// Purpose: How big a thing you can aim at has to be, per input mode and density.
// Author: liuchuancong
// Created: 2026-10-10
//
// Spec: section 5.4's "高度与尺寸" and "密度:TV/遥控器、桌面鼠标、移动触摸分别定义交互尺寸".
//
// The number that matters most is the minimum hit target, and it is not the same for every input: a finger
// needs about 48 logical px, a pointer is usable at 32, and a d-pad row needs to be tall enough to read from
// three metres as well as to be seen as focused. Taking one of those three numbers for all of them is how a
// settings list becomes unusable on exactly one platform while looking fine in the review on another.

import 'scale_tokens.dart';
import 'semantic_roles.dart';

/// A class of control whose size is defined once here rather than per widget.
enum ControlKind {
  /// A full-width or labelled button.
  button,

  /// A text input.
  input,

  /// An icon-only control: close, back, play/pause.
  iconButton,

  /// A selectable row in a list.
  listItem,

  /// A bar pinned to an edge: app bar, toolbar, player controls.
  toolbar,

  /// A chip or tag inside a scrolling row.
  chip,

  /// A poster tile in a grid, sized by width.
  posterTile;

  /// The height every instance of this control gets at [density] for [mode].
  ///
  /// Text scale is not folded in here: a control's height must grow with the text inside it, and the
  /// surface that knows the scale does that multiplication - this number is the design's minimum, not a
  /// layout's final word.
  double heightFor({required InputMode mode, Density density = Density.standard}) => baseHeight(mode) * density.scale;

  /// The base height before density.
  double baseHeight(InputMode mode) => switch ((this, mode)) {
    (ControlKind.button, InputMode.remote) => 56,
    (ControlKind.button, InputMode.touch) => 48,
    (ControlKind.button, InputMode.pointer) => 36,
    (ControlKind.input, InputMode.remote) => 56,
    (ControlKind.input, InputMode.touch) => 48,
    (ControlKind.input, InputMode.pointer) => 34,
    (ControlKind.iconButton, InputMode.remote) => 48,
    (ControlKind.iconButton, InputMode.touch) => 44,
    (ControlKind.iconButton, InputMode.pointer) => 32,
    (ControlKind.listItem, InputMode.remote) => 72,
    (ControlKind.listItem, InputMode.touch) => 56,
    (ControlKind.listItem, InputMode.pointer) => 40,
    (ControlKind.toolbar, InputMode.remote) => 72,
    (ControlKind.toolbar, InputMode.touch) || (ControlKind.toolbar, InputMode.pointer) => 56,
    (ControlKind.chip, InputMode.remote) => 44,
    (ControlKind.chip, InputMode.touch) => 36,
    (ControlKind.chip, InputMode.pointer) => 28,
    (ControlKind.posterTile, InputMode.remote) => 156,
    (ControlKind.posterTile, InputMode.touch) => 132,
    (ControlKind.posterTile, InputMode.pointer) => 120,
  };

  /// True when this control sits inside a padded row whose own hit area extends it, so its bare height is
  /// allowed to be smaller than a standalone target's.
  bool get isInline => this == ControlKind.chip;

  /// The smallest hit area this kind may ever be drawn at, for accessibility checks.
  ///
  /// Two numbers per mode, not one: a filter chip is legitimately shorter than a button because the row
  /// around it is tappable too, and pretending otherwise would force a floor this design does not want.
  double minTarget(InputMode mode) => switch ((isInline, mode)) {
    (true, InputMode.pointer) => 20,
    (true, InputMode.touch || InputMode.remote) => 32,
    (false, InputMode.remote) => 48,
    (false, InputMode.touch) => 44,
    (false, InputMode.pointer) => 24,
  };

  /// True when [height] would be too small to aim at. A surface that fails this is a bug report waiting:
  /// the check exists so it is caught in a test rather than on a remote.
  bool isAimable({required double height, required InputMode mode, Density density = Density.standard}) =>
      heightFor(mode: mode, density: density) >= minTarget(mode) && height >= minTarget(mode);
}

/// The visual ring a focused control gets.
final class FocusVisual {
  const FocusVisual({
    required this.shape,
    required this.width,
    required this.offset,
    required this.color,
    required this.contrastRatio,
  });

  /// How the focus shows itself.
  final FocusShape shape;

  /// Ring or outline thickness in logical pixels. Two is the least that survives a scaled-down window; a TV
  /// needs three to read at a distance.
  final double width;

  /// How far outside the control's bounds the ring sits. Negative means inside.
  final double offset;

  /// The role the style resolves the colour from; never a concrete colour.
  final ColorRole color;

  /// The minimum contrast against the surface behind it, as a ratio (1.0 = no difference).
  ///
  /// WCAG's non-text minimum is 3:1, and the reference app's TV build had focus rings a hairline thick on a
  /// mid-grey surface - technically visible, practically invisible. So the floor is enforced per mode.
  final double contrastRatio;

  /// The focus visual for [mode].
  factory FocusVisual.forMode(InputMode mode) => switch (mode) {
    InputMode.remote => const FocusVisual(
      shape: FocusShape.ring,
      width: 3,
      offset: 2,
      color: ColorRole.focus,
      contrastRatio: 3.5,
    ),
    InputMode.touch => const FocusVisual(
      shape: FocusShape.ring,
      width: 2,
      offset: 1,
      color: ColorRole.focus,
      contrastRatio: 3,
    ),
    InputMode.pointer => const FocusVisual(
      shape: FocusShape.outline,
      width: 2,
      offset: 0,
      color: ColorRole.focus,
      contrastRatio: 3,
    ),
  };

  /// True when a style's chosen ring would be too thin or too low-contrast to find.
  bool get isFindable => width >= 2 && contrastRatio >= 3;
}
