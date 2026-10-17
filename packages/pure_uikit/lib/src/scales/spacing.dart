/// The spacing scale.
///
/// Every margin, padding and gap in the UI comes from this ladder, so
/// density changes are a token change and not a hunt through pages. The
/// values are logical pixels at the default text scale; the density
/// multipliers are applied by the component theme, not here.
abstract final class PureSpacing {
  /// 2 — hairline gaps, icon-to-label in dense chrome.
  static const double xxs = 2;

  /// 4 — tight pairs.
  static const double xs = 4;

  /// 8 — the default inner padding of small controls.
  static const double sm = 8;

  /// 12 — the default gap between related controls.
  static const double md = 12;

  /// 16 — the default page padding on mobile.
  static const double lg = 16;

  /// 24 — the default page padding on desktop, and section gaps.
  static const double xl = 24;

  /// 32 — gaps between page sections on wide layouts.
  static const double xxl = 32;

  /// 48 — the vertical rhythm of TV layouts and empty states.
  static const double huge = 48;

  /// The whole ladder in ascending order, for previews and diagnostics.
  static const List<double> scale = [xxs, xs, sm, md, lg, xl, xxl, huge];
}
