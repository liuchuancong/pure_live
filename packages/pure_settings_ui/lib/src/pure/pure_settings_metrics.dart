/// The page geometry of the [DevicePlatform.pure] style.
///
/// Every other style's numbers are measurements of a real settings app — iPad
/// Settings, Windows 11 Settings, GNOME Settings. This style has no such
/// reference, so it takes pure_uikit's own host-facing scale instead, which is
/// what the app's pages already lay themselves out on:
/// [PureSizing.contentMaxWidth] for the reading column and the [PureSpacing]
/// steps for the gutters.
///
/// They live here rather than in the vendored switch that reads them, so the
/// vendor tree stays a thin diff against upstream.
library;

import 'package:pure_settings_ui/src/vendor/utils/platform_utils.dart' show DevicePlatform;
import 'package:pure_uikit/pure_uikit.dart' show PureSizing, PureSpacing;

/// The widest the list's content column grows on a wide screen.
const double pureSettingsContentWidth = PureSizing.contentMaxWidth;

/// The gutter kept at the sides when the window is narrower than the column.
const double pureSettingsSidePadding = PureSpacing.md;

/// The space above the first section.
const double pureSettingsTopPadding = PureSpacing.md;

/// The space below the last section.
const double pureSettingsBottomPadding = PureSpacing.xxl;

/// The gap between two sections.
const double pureSettingsSectionGap = PureSpacing.lg;

/// The gap between a section's title and its card.
const double pureSettingsTitleGap = PureSpacing.sm;

/// The width of a split view's list pane.
///
/// Narrower than iPad's 320pt sidebar and wider than macOS's 232pt: a
/// pure_uikit row carries a leading icon, a title and a trailing control, and
/// 280 keeps a sentence-case title on one line at the token's body size.
const double pureSettingsListPaneWidth = 280;

/// The width at which a split view shows two panes.
const double pureSettingsSplitBreakpoint = 720;

/// The widest a row's `value` grows before it ellipsises.
///
/// The vendor's `tileValue` needs a bound, because a row's trailing slot is
/// laid out at its natural width and an unbounded value would push the title
/// out of the row. Half the row is the rule the other styles use; this one
/// states a number instead, since the row belongs to a library whose metrics
/// this package does not know.
const double pureSettingsValueMaxWidth = 160;

/// The height of the pure style's page bar.
///
/// Between Chrome's 56px and GNOME's 46px, and the height pure_uikit's own app
/// bars settle on for a secondary page.
const double pureSettingsBarHeight = 52;
