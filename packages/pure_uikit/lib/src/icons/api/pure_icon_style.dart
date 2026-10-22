/// How an icon participates in the theme's palette.
enum PureIconColorRole {
  /// The theme's primary foreground — the resting colour of most glyphs.
  foreground,

  /// The theme's accent (primary) colour — selected destinations, calls to action.
  accent,

  /// The theme's tertiary colour — quiet affordances like chevrons and carets.
  tertiary,

  /// Keep the resource's own colours: multi-colour brand marks and product
  /// logos are never tinted (the theme defers to the artwork).
  preserve,
}

/// The visual spec one icon draw should follow.
///
/// Every field is optional: null means "ask the theme (and its design
/// language tokens) for the default". A widget can pass a style override
/// without knowing which library the glyph ultimately comes from.
class PureIconStyle {
  /// Builds a style; unset fields inherit.
  const new({this.size, this.role, this.opacity});

  /// The draw size in logical pixels; null takes the language's default.
  final double? size;

  /// The palette role; null takes the theme's default (foreground).
  final PureIconColorRole? role;

  /// An extra opacity multiplier (selection fades, pressed dimming); null
  /// takes the state rule.
  final double? opacity;
}

/// The interaction state an icon is drawn in. The component owns this —
/// never the icon library — so selection, hover and focus behave the same
/// whatever glyph answers.
enum PureIconState {
  /// At rest.
  normal,

  /// The owner is the current selection.
  selected,

  /// A pointer is over the owner.
  hovered,

  /// The owner is being pressed.
  pressed,

  /// The owner does not accept input.
  disabled,

  /// The owner holds keyboard or remote-control focus (desktop and TV).
  focused,
}
