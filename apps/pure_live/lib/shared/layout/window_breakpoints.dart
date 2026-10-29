import 'package:desen_ui/desen_ui.dart' show DsSpace;
import 'package:responsive_breakpoints/responsive_breakpoints.dart' show TailwindBreakpoint;

/// The Tailwind breakpoint under which a shrinking window folds the
/// sidebar once, on the crossing: xl (<1280px). The toggle always gets it
/// back — the fold nudges, it does not outvote the viewer.
const TailwindBreakpoint kExpandedSidebarBreakpoint = TailwindBreakpoint.xl;

/// The Tailwind breakpoint below which a touch device takes the bottom
/// bar: under md (<768px).
const TailwindBreakpoint kBottomBarBreakpoint = TailwindBreakpoint.md;

/// The widths the app's pages switch their presentation at.
///
/// A page is laid out by its own width, never by the platform: the same
/// window may be a phone, a tablet or a desktop-sized pane once the shell
/// hands it less room. Three classes cover the pages — compact, medium and
/// expanded — and the rest are the component measures those classes are
/// built from, kept here so a page never invents its own number. The
/// rules themselves are in `docs/ui-guidelines.md`.
abstract final class LiveWindow {
  /// Below this width a page keeps one column: toolbars stack, secondary
  /// actions become icons, and a side panel is a bottom sheet.
  static const double compact = 600;

  /// At or above this width a page may hold its toolbar on one line and
  /// read as a desktop surface.
  static const double expanded = 960;

  /// A tab strip and its actions share a row only at or above this width;
  /// below it the actions stack under the tabs.
  static const double toolbar = 720;

  /// The kit's own panel breakpoint: at or above it `showDsPanel` is a side
  /// panel, below it a bottom sheet. Re-exported for pages that lay out
  /// their own overlay.
  static const double sheet = 640;

  /// The measure of a centred form card (the kit's sign-in page is 400; a
  /// pasted link or a two-field row wants a little more).
  static const double form = 480;

  /// Below this width a pair of fields stacks instead of sharing a row.
  static const double pair = 420;

  /// Below this width a table replaces its columns with stacked rows.
  static const double table = 520;

  /// The widest a settings-like column gets; a category page's list rows
  /// never run the whole window.
  static const double content = 960;

  /// The widest a full screen's body gets on a very wide window.
  static const double wideContent = 1240;

  /// Whether [width] is the compact class.
  static bool isCompact(double width) => width < compact;

  /// Whether [width] has reached the expanded class.
  static bool isExpanded(double width) => width >= expanded;

  /// Whether a toolbar stacks its actions under its tabs at [width].
  static bool stacksToolbar(double width) => width < toolbar;

  /// The horizontal inset a page keeps from the window's edge: tighter on
  /// a compact window, the feed's own measure otherwise.
  static double pageInset(double width) => isCompact(width) ? DsSpace.s16 : DsSpace.s20;
}
