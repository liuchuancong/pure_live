import 'package:flutter/material.dart';
import 'package:pure_live/app/shell/shell_actions.dart';
import 'package:pure_live/app/shell/shell_destinations.dart';
import 'package:pure_live/l10n/generated/strings.g.dart';
import 'package:pure_uikit/pure_uikit.dart';

/// The width from which the shell draws the side rail instead of the bottom
/// bar — the reference's `homeTabletBreakpoint` (600; the old build switched
/// above 680).
///
/// The decision is width-only, exactly as the reference: a landscape phone
/// crosses onto the rail, a narrow desktop window drops to the bottom bar.
const double homeRailBreakpoint = 600;

/// Whether a home of [width] uses the side rail.
bool isHomeRailWidth(double width) => width >= homeRailBreakpoint;

/// Tells the home tabs which layout the shell chose (the reference's
/// `HomeLayoutScope`): a page shows its own menu/search buttons only in the
/// phone layout, because the rail already carries them.
class HomeLayoutScope extends InheritedWidget {
  /// Marks [child] as laid out with the bottom bar ([phone]) or the rail.
  const new({required this.phone, required super.child, super.key});

  /// Whether the bottom bar layout is used.
  final bool phone;

  /// The scope above [context], or null outside the home shell.
  static HomeLayoutScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<HomeLayoutScope>();

  @override
  bool updateShouldNotify(HomeLayoutScope oldWidget) => oldWidget.phone != phone;
}

/// Sizes of the side rail (the reference's `HomeRailMetrics`, Material 3's
/// rail: docs/A-界面设计/A06-首页和全局/A06.2-宽屏首页).
abstract final class HomeRailMetrics {
  /// The rail's width.
  static const double width = 80;

  /// The menu button's row: the 48 button with 12 above and 8 below.
  static const double menuHeight = 68;

  /// A tool button's row: the 48 button, its name and 6 below.
  static const double toolHeight = 66;

  /// The line between the tools and the destinations.
  static const double separatorHeight = 21;

  /// A destination: the 56 × 32 indicator, its name, 4 above and 12 below.
  static const double destinationHeight = 68;
}

/// The rail column (the reference's `HomeTabletView` inner rail): the menu
/// button, the tool buttons with their names (search, watch history, link
/// parser, multi-view), a short line, then the destinations.
///
/// When the window is too short for everything, the destinations stay in
/// view and the menu and tools above them scroll; even shorter, all of it
/// scrolls (the reference's fix for 3.x pushing destinations off screen).
class HomeRail extends StatelessWidget {
  /// Builds the rail over [branches].
  const new({required this.branches, required this.selected, required this.onSelected, super.key});

  /// The destinations, in their display order.
  final List<ShellBranch> branches;

  /// The destination shown.
  final ShellBranch? selected;

  /// A destination was tapped.
  final ValueChanged<ShellBranch> onSelected;

  @override
  Widget build(BuildContext context) {
    final theme = PureTheme.of(context);
    final t = context.t;
    final top = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Padding(padding: EdgeInsets.fromLTRB(12, 12, 12, 8), child: HomeMenuButton()),
        for (final action in homeActions())
          _RailTool(
            key: ValueKey('home-rail-${action.name}'),
            icon: action.icon,
            label: action.label(t),
            onTap: () => action.run(context),
          ),
      ],
    );
    final destinations = [
      for (final branch in branches)
        _RailDestination(
          key: ValueKey('home-nav-${branch.name}'),
          branch: branch,
          selected: branch == selected,
          onTap: () => onSelected(branch),
        ),
    ];
    final separator = Container(
      key: const ValueKey('home-rail-separator'),
      width: 40,
      height: 1,
      margin: const EdgeInsets.only(top: 6, bottom: 14),
      color: theme.colors.border,
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        final content = Column(mainAxisSize: MainAxisSize.min, children: [top, separator, ...destinations]);
        // The row heights are the reference's Material metrics; the other
        // design languages draw taller buttons and labels, so the fixed
        // arithmetic that decides "top scrolls, destinations stay" cannot
        // trust them. The rail simply scrolls as a whole when its content
        // does not fit — the destinations are reachable from the first
        // frame either way, and a window that fits them never scrolls.
        return SingleChildScrollView(
          primary: false,
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: content,
          ),
        );
      },
    );
  }
}

/// The state a rail item draws: the hover or press layer and the keyboard
/// focus (the reference's `_RailState`).
typedef _RailState = ({Color? layer, bool focused});

/// Hover, focus (keyboard only) and press of a rail item, drawn on the
/// indicator rather than over the whole cell (Material 3's rail).
class _RailItem extends StatefulWidget {
  const new({required this.label, required this.onTap, required this.builder, this.selected});

  final String label;
  final VoidCallback onTap;
  final bool? selected;

  /// Builds the item from its state: the layer to put on the indicator and
  /// whether the keyboard focus is here.
  final Widget Function(BuildContext context, _RailState state) builder;

  @override
  State<_RailItem> createState() => _RailItemState();
}

class _RailItemState extends State<_RailItem> {
  bool _hovered = false;
  bool _pressed = false;
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final theme = PureTheme.of(context);
    final keyboard = _focused && FocusManager.instance.highlightMode == FocusHighlightMode.traditional;
    final layer = _pressed || keyboard
        ? theme.colors.text.withValues(alpha: 0.1)
        : (_hovered ? theme.colors.text.withValues(alpha: 0.08) : null);
    return Semantics(
      button: true,
      selected: widget.selected,
      label: widget.label,
      excludeSemantics: true,
      child: InkWell(
        onTap: widget.onTap,
        onHover: (value) => setState(() => _hovered = value),
        onHighlightChanged: (value) => setState(() => _pressed = value),
        onFocusChange: (value) => setState(() => _focused = value),
        overlayColor: WidgetStatePropertyAll(theme.colors.text.withValues(alpha: 0)),
        splashFactory: NoSplash.splashFactory,
        child: widget.builder(context, (layer: layer, focused: keyboard)),
      ),
    );
  }
}

/// The text of a rail item: 12 points, one line, 16 high.
Widget _railLabel(BuildContext context, String label, {required Color color, FontWeight? weight}) => Text(
  label,
  maxLines: 1,
  overflow: TextOverflow.ellipsis,
  style: PureTheme.of(context).text.bodySmall.copyWith(color: color, fontWeight: weight, height: 16 / 12),
);

/// A tool button of the rail: a round 48 button with its name under it (the
/// reference's `_RailTool`).
class _RailTool extends StatelessWidget {
  const new({required this.icon, required this.label, required this.onTap, super.key});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = PureTheme.of(context);
    final fluent = theme.config.language == PureDesignLanguage.fluent;
    return _RailItem(
      label: label,
      onTap: onTap,
      builder: (context, state) => ConstrainedBox(
        constraints: const BoxConstraints.tightFor(width: HomeRailMetrics.width),
        child: Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 120),
                curve: Curves.easeOut,
                width: kMinInteractiveDimension,
                height: kMinInteractiveDimension,
                decoration: BoxDecoration(
                  color: state.layer,
                  // Fluent's toolbar buttons are a 4-point square plate; the
                  // circle is Material's touch target.
                  shape: fluent ? BoxShape.rectangle : BoxShape.circle,
                  borderRadius: fluent ? BorderRadius.circular(4) : null,
                  border: state.focused ? Border.all(color: theme.colors.primary, width: 2) : null,
                ),
                child: Icon(icon, color: theme.colors.textSecondary),
              ),
              Transform.translate(
                offset: const Offset(0, -4),
                child: _railLabel(context, label, color: theme.colors.textSecondary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A destination of the rail. Material 3 draws it as an icon inside a 56 × 32
/// indicator with the name under it; Fluent owns the whole cell instead — a
/// 4-point row that fills on hover and selection, marked by a short accent pill
/// on its left edge (WinUI's NavigationViewItem).
class _RailDestination extends StatelessWidget {
  const new({required this.branch, required this.selected, required this.onTap, super.key});

  final ShellBranch branch;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = PureTheme.of(context);
    final label = branch.label(context);
    final fluent = theme.config.language == PureDesignLanguage.fluent;
    return _RailItem(
      label: label,
      selected: selected,
      onTap: onTap,
      builder: (context, state) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOut,
          width: HomeRailMetrics.width - 12,
          decoration: BoxDecoration(
            color: fluent ? (state.layer ?? (selected ? theme.colors.fillQuaternary : null)) : null,
            borderRadius: BorderRadius.circular(4),
            border: state.focused ? Border.all(color: theme.colors.primary, width: 2) : null,
          ),
          child: Stack(
            alignment: AlignmentDirectional.center,
            children: [
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: EdgeInsets.fromLTRB(0, fluent ? 8 : 4, 0, fluent ? 4 : 0),
                    child: fluent
                        ? Icon(branch.icon, color: selected ? theme.colors.text : theme.colors.textSecondary)
                        : AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            curve: Curves.easeOut,
                            width: 56,
                            height: 32,
                            decoration: BoxDecoration(
                              color: selected ? theme.colors.fillSecondary : null,
                              borderRadius: BorderRadius.circular(16),
                              border: state.focused ? Border.all(color: theme.colors.primary, width: 2) : null,
                            ),
                            // The Material layer sits on the indicator, which is
                            // the cell the language highlights.
                            foregroundDecoration: state.layer == null
                                ? null
                                : BoxDecoration(color: state.layer, borderRadius: BorderRadius.circular(16)),
                            child: Icon(branch.icon, color: selected ? theme.colors.text : theme.colors.textSecondary),
                          ),
                  ),
                  _railLabel(
                    context,
                    label,
                    color: theme.colors.text,
                    weight: selected ? FontWeight.w600 : FontWeight.w400,
                  ),
                  SizedBox(height: fluent ? 7 : 12),
                ],
              ),
              if (fluent && selected)
                const PositionedDirectional(top: 0, bottom: 0, start: 2, child: Center(child: _RailAccent())),
            ],
          ),
        ),
      ),
    );
  }
}

/// The 3 × 16 accent pill Fluent puts on the leading edge of the selected
/// navigation item.
class _RailAccent extends StatelessWidget {
  const new();

  @override
  Widget build(BuildContext context) => Container(
    width: 3,
    height: 16,
    decoration: BoxDecoration(color: PureTheme.of(context).colors.primary, borderRadius: BorderRadius.circular(1.5)),
  );
}
