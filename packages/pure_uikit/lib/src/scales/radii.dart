/// The corner-radius scale.
///
/// A design language maps these to its own geometry (Material's 12 becomes
/// Fluent's 4 and Neumorphic's 20) by overriding the token set, so a page
/// that says `PureRadii.md` keeps its meaning everywhere.
abstract final class PureRadii {
  /// 4 — chips, dense badges, small controls.
  static const double xs = 4;

  /// 8 — buttons and text fields.
  static const double sm = 8;

  /// 12 — cards.
  static const double md = 12;

  /// 16 — dialogs and menus.
  static const double lg = 16;

  /// 24 — sheets and TV surfaces.
  static const double xl = 24;

  /// 999 — fully rounded ends (pills, avatars, switches).
  static const double pill = 999;

  /// The whole ladder in ascending order, for previews and diagnostics.
  static const List<double> scale = [xs, sm, md, lg, xl];
}
