import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:pure_settings_ui/src/vendor/split/fluent_controls.dart';
import 'package:pure_settings_ui/src/vendor/split/settings_page_header.dart';
import 'package:pure_settings_ui/src/vendor/split/settings_page_trail.dart';
import 'package:pure_settings_ui/src/vendor/split/sidebar_button.dart';
import 'package:pure_settings_ui/src/vendor/utils/fluent_tokens.dart';
import 'package:pure_settings_ui/src/vendor/utils/settings_theme.dart';

// The page header of the Windows style (Windows 11 Settings): the page
// title, with a breadcrumb for nested pages. All sizes are effective pixels.

/// Page titles: Title, 28/36 semibold.
const TextStyle kFluentTitleStyle = TextStyle(
  fontSize: 28,
  height: 36 / 28,
  fontWeight: FontWeight.w600,
  letterSpacing: 0,
  leadingDistribution: TextLeadingDistribution.even,
);

/// The side margins of a Windows page's content in a page [width] wide:
/// the Fluent `SettingsList` column (at most 1000, 24 margins, 16 below
/// 641).
double fluentPageSideMargin(double width) =>
    math.max(width < 641 ? 16.0 : 24.0, (width - 1000) / 2);

/// The title of a Windows Settings page: Title (28/36 semibold) over the
/// content column, 24 from the top. A page opened from another page shows
/// a breadcrumb ("System › Display") whose parent crumbs are in the
/// secondary color and go back to their page when clicked. A first page
/// with somewhere to go back to gets a back button before its title.
/// Internal.
class FluentPageHeader extends StatelessWidget {
  const FluentPageHeader({
    super.key,
    required this.title,
    this.parents = const <SettingsPageTrailEntry>[],
    this.onBack,
    this.actions,
  });

  final Widget? title;
  final List<SettingsPageTrailEntry> parents;
  final VoidCallback? onBack;
  final List<Widget>? actions;

  @override
  Widget build(BuildContext context) {
    final theme = SettingsTheme.of(context).themeData;
    final tokens = fluentTokensOf(context);
    final primary = theme.settingsTileTextColor ?? tokens.textPrimary;
    final secondary = theme.tileDescriptionTextColor ?? tokens.textSecondary;
    final onBack = parents.isEmpty ? this.onBack : null;
    final actions = this.actions;
    final title = this.title;

    return SafeArea(
      bottom: false,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final side = fluentPageSideMargin(constraints.maxWidth);
          return Padding(
            padding: EdgeInsetsDirectional.only(
              start: onBack == null ? side : math.max(0, side - 8),
              end: side,
              top: 24,
            ),
            child: Row(
              children: [
                if (onBack != null)
                  Padding(
                    padding: const EdgeInsetsDirectional.only(end: 8),
                    child: FluentSubtleButton(
                      semanticLabel: settingsBackLabel(context),
                      onPressed: onBack,
                      glyph: FluentGlyph.back,
                    ),
                  ),
                Expanded(
                  child: Semantics(
                    header: true,
                    child: _FluentBreadcrumb(
                      parents: parents,
                      title: title,
                      primary: primary,
                      secondary: secondary,
                    ),
                  ),
                ),
                if (actions != null && actions.isNotEmpty)
                  Row(mainAxisSize: MainAxisSize.min, children: actions),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// The page's title or a crumb, on one line in [color].
Widget _titleLine(Widget child, Color color) => DefaultTextStyle(
  style: kFluentTitleStyle.copyWith(color: color),
  maxLines: 1,
  softWrap: false,
  overflow: TextOverflow.ellipsis,
  child: child,
);

/// The page title of a Windows page on one line: the crumbs of the pages
/// above it, then its title, like WinUI's `BreadcrumbBar` in Windows
/// Settings. When they don't fit, the crumbs nearest the start collapse
/// into a "…" crumb (which goes back to the last collapsed page), and a
/// title too long for the line ends in an ellipsis.
class _FluentBreadcrumb extends StatefulWidget {
  const _FluentBreadcrumb({
    required this.parents,
    required this.title,
    required this.primary,
    required this.secondary,
  });

  final List<SettingsPageTrailEntry> parents;
  final Widget? title;
  final Color primary;
  final Color secondary;

  @override
  State<_FluentBreadcrumb> createState() => _FluentBreadcrumbState();
}

class _FluentBreadcrumbState extends State<_FluentBreadcrumb> {
  /// How many crumbs (from the first) the last layout collapsed. Only for
  /// the keyboard focus and the "…" crumb's target: the layout decides.
  int _collapsed = 0;

  void _handleCollapsed(int count) {
    if (count == _collapsed) return;
    // Called during layout.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && count != _collapsed) setState(() => _collapsed = count);
    });
  }

  @override
  Widget build(BuildContext context) {
    final parents = widget.parents;
    final title = widget.title;
    final collapsed = math.min(_collapsed, parents.length);
    final titleWidget = title == null
        ? const SizedBox.shrink()
        : _titleLine(title, widget.primary);
    if (parents.isEmpty) return titleWidget;

    // A crumb goes back to its page. [label] replaces the page's title.
    Widget crumb(SettingsPageTrailEntry entry, {Widget? label}) => _Crumb(
      onPressed: () => popToSettingsPage(context, entry),
      label: label ?? entry.title,
      color: widget.secondary,
      hoverColor: widget.primary,
    );

    final last = parents[math.max(0, collapsed - 1)];
    final lastTitle = last.title;
    return _BreadcrumbLayout(
      crumbCount: parents.length,
      textDirection: Directionality.of(context),
      onCollapsed: _handleCollapsed,
      children: [
        ExcludeFocus(
          excluding: collapsed == 0,
          child: crumb(
            last,
            label: Text(
              '…',
              semanticsLabel: lastTitle is Text ? lastTitle.data : null,
            ),
          ),
        ),
        _BreadcrumbChevron(color: widget.secondary),
        for (final (index, parent) in parents.indexed) ...[
          ExcludeFocus(excluding: index < collapsed, child: crumb(parent)),
          _BreadcrumbChevron(color: widget.secondary),
        ],
        titleWidget,
      ],
    );
  }
}

/// Lays out the "…" crumb and its chevron, [crumbCount] crumbs with their
/// chevrons, and the title (in that order) on one line; see
/// [_FluentBreadcrumb].
class _BreadcrumbLayout extends MultiChildRenderObjectWidget {
  const _BreadcrumbLayout({
    required this.crumbCount,
    required this.textDirection,
    required this.onCollapsed,
    required super.children,
  });

  final int crumbCount;
  final TextDirection textDirection;
  final ValueChanged<int> onCollapsed;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderBreadcrumb(crumbCount, textDirection, onCollapsed);

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderBreadcrumb renderObject,
  ) {
    renderObject
      ..crumbCount = crumbCount
      ..textDirection = textDirection
      ..onCollapsed = onCollapsed;
  }
}

class _BreadcrumbParentData extends ContainerBoxParentData<RenderBox> {
  bool shown = true;
}

class _RenderBreadcrumb extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, _BreadcrumbParentData>,
        RenderBoxContainerDefaultsMixin<RenderBox, _BreadcrumbParentData> {
  _RenderBreadcrumb(this._crumbCount, this._textDirection, this.onCollapsed);

  int get crumbCount => _crumbCount;
  int _crumbCount;
  set crumbCount(int value) {
    if (value == _crumbCount) return;
    _crumbCount = value;
    markNeedsLayout();
  }

  TextDirection get textDirection => _textDirection;
  TextDirection _textDirection;
  set textDirection(TextDirection value) {
    if (value == _textDirection) return;
    _textDirection = value;
    markNeedsLayout();
  }

  ValueChanged<int> onCollapsed;

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! _BreadcrumbParentData) {
      child.parentData = _BreadcrumbParentData();
    }
  }

  /// How many crumbs collapse into the "…" crumb, from the natural widths
  /// of the children, when the line is [maxWidth] wide; and the width the
  /// title gets.
  (int, double) _fit(List<double> widths, double maxWidth) {
    final count = crumbCount;
    final title = widths.last;
    double pair(int index) => widths[2 + 2 * index] + widths[3 + 2 * index];
    var crumbs = 0.0;
    for (var i = 0; i < count; i++) {
      crumbs += pair(i);
    }
    if (!maxWidth.isFinite || crumbs + title <= maxWidth) return (0, title);
    // The title stays whole when it leaves room for the "…" crumb; the
    // crumbs nearest it show while they fit.
    final ellipsis = widths[0] + widths[1];
    final titleWidth = math.min(title, math.max(0.0, maxWidth - ellipsis));
    var room = maxWidth - ellipsis - titleWidth;
    var collapsed = count;
    for (var i = count - 1; i >= 0 && pair(i) <= room; i--) {
      room -= pair(i);
      collapsed = i;
    }
    // Everything that fits (a collapse of 0 would have fit whole).
    return (math.max(1, collapsed), titleWidth);
  }

  bool get _valid => childCount == 2 * crumbCount + 3;

  @override
  void performLayout() {
    final children = getChildrenAsList();
    final loose = BoxConstraints(maxHeight: constraints.maxHeight);
    for (final child in children) {
      child.layout(loose, parentUsesSize: true);
    }
    if (!_valid) {
      size = constraints.constrain(Size.zero);
      return;
    }
    final maxWidth = constraints.maxWidth;
    final (collapsed, titleWidth) = _fit([
      for (final child in children) child.size.width,
    ], maxWidth);
    onCollapsed(collapsed);
    final title = children.last;
    if (title.size.width > titleWidth) {
      title.layout(loose.copyWith(maxWidth: titleWidth), parentUsesSize: true);
    }

    bool isShown(int index) {
      if (index == children.length - 1) return true;
      if (index < 2) return collapsed > 0;
      return (index - 2) ~/ 2 >= collapsed;
    }

    var height = 0.0;
    var width = 0.0;
    for (final (index, child) in children.indexed) {
      final shown = isShown(index);
      (child.parentData! as _BreadcrumbParentData).shown = shown;
      if (!shown) continue;
      height = math.max(height, child.size.height);
      width += child.size.width;
    }
    size = constraints.constrain(Size(width, height));
    var x = 0.0;
    for (final child in children) {
      final data = child.parentData! as _BreadcrumbParentData;
      if (!data.shown) {
        data.offset = Offset.zero;
        continue;
      }
      final dx = textDirection == TextDirection.rtl
          ? size.width - x - child.size.width
          : x;
      data.offset = Offset(dx, (size.height - child.size.height) / 2);
      x += child.size.width;
    }
  }

  // No intrinsic sizes or dry layout: the header's LayoutBuilder is above
  // the breadcrumb, and it answers those itself.

  @override
  void paint(PaintingContext context, Offset offset) {
    for (var child = firstChild; child != null; child = childAfter(child)) {
      final data = child.parentData! as _BreadcrumbParentData;
      if (data.shown) context.paintChild(child, offset + data.offset);
    }
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    for (var child = lastChild; child != null; child = childBefore(child)) {
      final data = child.parentData! as _BreadcrumbParentData;
      if (!data.shown) continue;
      final target = child;
      final hit = result.addWithPaintOffset(
        offset: data.offset,
        position: position,
        hitTest: (result, transformed) =>
            target.hitTest(result, position: transformed),
      );
      if (hit) return true;
    }
    return false;
  }

  @override
  void visitChildrenForSemantics(RenderObjectVisitor visitor) {
    for (var child = firstChild; child != null; child = childAfter(child)) {
      if ((child.parentData! as _BreadcrumbParentData).shown) visitor(child);
    }
  }
}

/// A parent page in the breadcrumb: secondary text that turns primary on
/// hover and goes back to its page when clicked.
class _Crumb extends SidebarButton {
  const _Crumb({
    required VoidCallback super.onPressed,
    required this.label,
    required this.color,
    required this.hoverColor,
  }) : super(tracksPressed: false, mouseCursor: SystemMouseCursors.click);

  /// The page's title, or "…" for the collapsed crumbs.
  final Widget label;
  final Color color;
  final Color hoverColor;

  @override
  Widget buildButton(BuildContext context, SidebarButtonStates states) {
    final crumb = _titleLine(
      label,
      states.hovered || states.focused ? hoverColor : color,
    );
    return states.focused
        ? fluentFocusRing(fluentTokensOf(context), crumb)
        : crumb;
  }
}

/// The breadcrumb separator: a thin chevron, 7 wide and 12 tall, mirrored
/// in right-to-left layouts, with the spacing Windows Settings leaves
/// around it.
class _BreadcrumbChevron extends StatelessWidget {
  const _BreadcrumbChevron({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.only(start: 19, end: 17),
      child: CustomPaint(
        size: const Size(7, 36),
        painter: _BreadcrumbChevronPainter(
          color: color,
          textDirection: Directionality.of(context),
        ),
      ),
    );
  }
}

class _BreadcrumbChevronPainter extends CustomPainter {
  const _BreadcrumbChevronPainter({
    required this.color,
    required this.textDirection,
  });

  final Color color;
  final TextDirection textDirection;

  @override
  void paint(Canvas canvas, Size size) {
    // Centered on the capitals, which sit a little above the line's middle.
    final top = (size.height - 12) / 2 + 1;
    if (textDirection == TextDirection.rtl) {
      canvas.translate(size.width, 0);
      canvas.scale(-1, 1);
    }
    canvas.drawPath(
      Path()
        ..moveTo(0.75, top + 0.75)
        ..lineTo(6.25, top + 6)
        ..lineTo(0.75, top + 11.25),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = color,
    );
  }

  @override
  bool shouldRepaint(_BreadcrumbChevronPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.textDirection != textDirection;
}
