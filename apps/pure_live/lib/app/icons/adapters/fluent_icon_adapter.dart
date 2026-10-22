import 'package:pure_uikit/pure_uikit.dart' show PureIconMapping;

/// The Windows Fluent skin's answers.
///
/// Checked against the package this shell's Fluent chrome is built on:
/// `fluent_2` ships no icon font, so the Fluent language draws the global
/// Material backstop until a Fluent icon font is added — this table is the
/// seam to fill then (and platform+key specials belong in
/// `app_icon_overrides.dart`, not here).
const PureIconMapping fluentIconsOverrides = PureIconMapping({});
