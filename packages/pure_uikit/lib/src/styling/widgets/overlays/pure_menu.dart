import 'dart:async' show Completer, unawaited;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show KeyDownEvent, KeyEvent, KeyRepeatEvent, LogicalKeyboardKey;
import 'package:pure_uikit/src/styling/provider/pure_config_provider.dart';

/// One line of a [PureMenu]: an action, a checked choice, or a hairline that
/// separates two groups. The id, label, icon, [danger], [enabled] and [onTap]
/// are the fields the app pages already build menus from; [checked], [shortcut]
/// and [isSeparator] are how a menu says "this one is on", "and here is the key
/// that does it" and "the items below begin a new group" — the three things a
/// real menu states beyond a plain list, and the ones every language below draws
/// in its own idiom.
@immutable
final class PureMenuItem {
  /// A menu item; give [onTap] to make it actionable.
  const new({
    required this.id,
    required this.label,
    this.icon,
    this.danger = false,
    this.enabled = true,
    this.checked = false,
    this.shortcut,
    this.semanticLabel,
    this.onTap,
    this.isSeparator = false,
  });

  /// A hairline that separates the items around it. It carries no action, so
  /// navigation and hover skip it in every design language.
  factory separator({String? id}) => PureMenuItem(id: id ?? 'separator', label: '', isSeparator: true, enabled: false);

  /// The stable id.
  final String id;

  /// The visible label.
  final String label;

  /// An optional leading icon; replaced by the tick when [checked] is set.
  final IconData? icon;

  /// Whether to draw the label in the error colour (a destructive action).
  final bool danger;

  /// Whether the item responds to input; a disabled item greys out and is
  /// skipped by pointer, keyboard and screen-reader alike.
  final bool enabled;

  /// Whether the choice this item stands for is on; drawn as the language's own
  /// tick (a Material or macOS check, an iOS checkmark, a Fluent glyph).
  final bool checked;

  /// The keyboard accelerator shown in the trailing column — the shortcut a
  /// desktop menu prints beside the label.
  final String? shortcut;

  /// The name read aloud; a labelled item reads [label] and ignores this.
  final String? semanticLabel;

  /// Called when the item is chosen, after the menu has closed. An item with no
  /// callback is shown but inert.
  final VoidCallback? onTap;

  /// Whether this line is a hairline separator rather than an item.
  final bool isSeparator;

  /// Whether the row answers to input at all: switched off, given no callback,
  /// or a separator — all three are inert, all three are skipped by traversal.
  bool get actionable => enabled && !isSeparator && onTap != null;

  /// The name used for semantics.
  String get semanticsText => label.isNotEmpty ? label : (semanticLabel ?? '');

  @override
  bool operator ==(Object other) =>
      other is PureMenuItem &&
      other.id == id &&
      other.label == label &&
      other.icon == icon &&
      other.danger == danger &&
      other.enabled == enabled &&
      other.checked == checked &&
      other.shortcut == shortcut &&
      other.semanticLabel == semanticLabel &&
      other.onTap == onTap &&
      other.isSeparator == isSeparator;

  @override
  int get hashCode =>
      Object.hash(id, label, icon, danger, enabled, checked, shortcut, semanticLabel, onTap, isSeparator);
}

/// A menu — a list of commands dropped over the trigger that opened it.
///
/// Where the earlier kit handed the popup to each library's own menu widget,
/// this is the menu drawn here, the WinUI flyout shape from the tokens — the
/// bordered card with its accelerator column. The colours, radii, motion and
/// text all come from the tokens, so a re-skin and a dark switch still come
/// out right — a menu is exactly the surface no anchor library drops into
/// a `PureConfigProvider` that sits above the [Navigator], which is why it is
/// painted here rather than borrowed.
///
/// Every shape answers to the same interaction contract: the surface opens
/// anchored to the trigger (or to the tap point handed to [showPureMenu]), the
/// items walk with the arrow keys and Home/End, Enter and Space choose and Escape
/// closes, hover highlights the row under the pointer, a disabled row greys out
/// and is stepped over, and a tap anywhere off the card dismisses it. The list
/// carries menu semantics and each row reads as a menu item that knows whether
/// it is chosen and whether it is live.
///
/// Wrap the widget around the trigger the menu belongs to, or call
/// [showPureMenu] to drop one at an explicit position.
class PureMenu extends StatelessWidget {
  /// A menu over [items], anchored to [child].
  const new({required this.items, required this.child, this.enabled = true, this.width, super.key});

  /// The actions.
  final List<PureMenuItem> items;

  /// The trigger widget; tapping it drops the menu from the point pressed.
  final Widget child;

  /// Whether the trigger responds.
  final bool enabled;

  /// A fixed card width; null lets the card size to its content between the
  /// design language's own bounds.
  final double? width;

  @override
  Widget build(BuildContext context) {
    final live = enabled && items.isNotEmpty;
    // The menu is dropped at the point the user pressed, so it hangs from under
    // the finger — the same anchor a right-click or long-press hands to
    // [showPureMenu]. The trigger's own box would need a render lookup that
    // resolves to an ancestor of this widget, so the tap point is the honest
    // anchor here.
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapUp: live
          ? (details) => unawaited(showPureMenu(context, items: items, position: details.globalPosition, width: width))
          : null,
      child: child,
    );
  }
}

/// Drops a [PureMenu] over the trigger's [anchor], or at a global tap [position]
/// when there is no trigger box — a right-click menu, a keyboard-invoked one, a
/// long-press on a canvas.
///
/// The scrim, the fade-and-scale, the dismissal and the walk of the items are
/// the core's and stay the same in every language; the surface inside them is
/// the active design language's own menu, drawn from the tokens. The future
/// completes with the chosen item once the card is gone, and the item's
/// [PureMenuItem.onTap] runs at that moment — after the menu has closed, exactly
/// as the anchor libraries' menus behave. Nothing here needs a [Scaffold]: the
/// card goes to the root [Overlay], so a menu fired from a route, a dialog or a
/// second desktop window still finds its way to the top of the screen.
Future<PureMenuItem?> showPureMenu(
  BuildContext context, {
  required List<PureMenuItem> items,
  Rect? anchor,
  Offset? position,
  double? width,
}) async {
  if (items.isEmpty) {
    return null;
  }
  // The theme and the visual are resolved on the caller's side of the route,
  // because the provider sits above the Navigator and is out of reach once the
  // card is on the overlay — the same reason the toast captures its theme.
  final theme = PureTheme.of(context);
  final overlay = Overlay.maybeOf(context, rootOverlay: true);
  if (overlay == null) {
    return null;
  }
  final visual = _MenuVisual.fluent();
  final done = Completer<PureMenuItem?>();
  late final OverlayEntry entry;
  entry = OverlayEntry(
    builder: (_) => _MenuOverlay(
      items: items,
      theme: theme,
      visual: visual,
      anchor: anchor,
      position: position ?? Offset.zero,
      width: width,
      onDone: (chosen) {
        entry.remove();
        if (!done.isCompleted) {
          done.complete(chosen);
        }
      },
    ),
  );
  overlay.insert(entry);
  final chosen = await done.future;
  // Chosen after the card has animated away, so a destructive item can pop the
  // page underneath without its route racing the menu's own dismissal.
  chosen?.onTap?.call();
  return chosen;
}

/// The geometry and colours one design language gives the menu card: the
/// surface it is painted on, the row it lays each item in, the highlight under
/// the active row, the text and tick colours of each state, the hairline that
/// divides groups, and the entrance the card scales and fades in through.
@immutable
final class _MenuVisual {
  const new({
    required this.card,
    required this.rowHeight,
    required this.iconSize,
    required this.rowPadding,
    required this.rowRadius,
    required this.leadingGap,
    required this.minWidth,
    required this.maxWidth,
    required this.beginScale,
    required this.beginAlignment,
    required this.curve,
    required this.highlight,
    required this.content,
    required this.checkColor,
    required this.separatorColor,
    required this.showSeparators,
  });

  /// Windows's flyout: a bordered card at Fluent's control radius, a row tall
  /// enough for its reveal fill, and the accelerator the item carries printed in
  /// the trailing column the way WinUI's menu items do.
  factory fluent() => _MenuVisual(
    card: (theme, body) => DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colors.surfaceElevated,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: theme.colors.borderSecondary),
        boxShadow: _elevation(theme, 8),
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: theme.token.scale.sizes.xs),
        child: body,
      ),
    ),
    rowHeight: 36,
    iconSize: 16,
    rowPadding: const EdgeInsets.symmetric(horizontal: 10),
    rowRadius: BorderRadius.circular(4),
    leadingGap: 10,
    minWidth: 200,
    maxWidth: 400,
    beginScale: 0.88,
    beginAlignment: Alignment.topLeft,
    curve: Curves.easeOutBack,
    highlight: (theme) => theme.colors.fill,
    content: _standardContent,
    checkColor: (theme, {required active}) => theme.colors.primary,
    separatorColor: (theme) => theme.colors.split,
    showSeparators: false,
  );

  /// Wraps the row list in whatever the language puts around it: the fill, the
  /// blur, the border, the shadow, the card's own inset.
  final Widget Function(PureTheme theme, Widget body) card;

  /// The height of one row.
  final double rowHeight;

  /// The size of a leading glyph or tick.
  final double iconSize;

  /// The padding inside a row, around its highlight.
  final EdgeInsets rowPadding;

  /// The corner radius of a row's highlight.
  final BorderRadius rowRadius;

  /// The gap between a row's leading glyph and its label.
  final double leadingGap;

  /// The card's narrowest and widest it may be when it sizes to its content.
  final double minWidth;
  final double maxWidth;

  /// The scale the card grows from, the corner it grows from, and the curve of
  /// the entrance — a WinUI flyout pops, an M3 menu eases, iOS barely moves.
  final double beginScale;
  final Alignment beginAlignment;
  final Curve curve;

  /// The wash behind the active row.
  final Color Function(PureTheme theme) highlight;

  /// The label colour in each state.
  final Color Function(PureTheme theme, {required bool active, required bool danger, required bool enabled}) content;

  /// The tick colour for a chosen item; `active` says the row is already washed.
  final Color Function(PureTheme theme, {required bool active}) checkColor;

  /// The hairline that divides two groups.
  final Color Function(PureTheme theme) separatorColor;

  /// Whether group breaks draw a rule between rows without an explicit
  /// separator; the flyout draws only the separators the caller placed.
  final bool showSeparators;

  /// The text colour: greyed when off, the error colour for a destructive
  /// action, the plain text role otherwise.
  static Color _standardContent(PureTheme theme, {required bool active, required bool danger, required bool enabled}) {
    if (!enabled) {
      return theme.colors.textQuaternary;
    }
    return danger ? theme.colors.error : theme.colors.text;
  }

  /// The elevation shadow the flyout card floats the menu on.
  static List<BoxShadow> _elevation(PureTheme theme, double blur) => [
    BoxShadow(
      color: theme.colors.shadowBase.withValues(alpha: theme.isDark ? 0.4 : 0.16),
      blurRadius: blur,
      offset: Offset(0, blur / 4),
    ),
  ];
}

/// The card on the overlay: the scrim that dismisses it, the anchored placement
/// that flips and clamps it into the viewport, the fade-and-scale entrance, the
/// keyboard walk through the items, and the semantics that name the list.
class _MenuOverlay extends StatefulWidget {
  const new({
    required this.items,
    required this.theme,
    required this.visual,
    required this.anchor,
    required this.position,
    required this.width,
    required this.onDone,
  });

  final List<PureMenuItem> items;
  final PureTheme theme;
  final _MenuVisual visual;
  final Rect? anchor;
  final Offset position;
  final double? width;
  final void Function(PureMenuItem? chosen) onDone;

  @override
  State<_MenuOverlay> createState() => _MenuOverlayState();
}

class _MenuOverlayState extends State<_MenuOverlay> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(vsync: this, duration: widget.theme.duration);
  late final Animation<double> _scale = Tween<double>(
    begin: widget.visual.beginScale,
    end: 1,
  ).animate(CurvedAnimation(parent: _controller, curve: widget.visual.curve));
  late final Animation<double> _fade = CurvedAnimation(parent: _controller, curve: widget.visual.curve);

  /// The node the keyboard walk is bound to; taken on the first frame after the
  /// card is on the overlay, so the arrow keys reach it however the trigger had
  /// left focus.
  final FocusNode _focusNode = FocusNode(debugLabel: 'PureMenu');

  /// The row the keyboard or the pointer is on; `-1` when no row is actionable.
  int _active = -1;
  bool _closing = false;

  @override
  void initState() {
    super.initState();
    _active = _walk(from: -1, direction: 1) ?? _walk(from: widget.items.length, direction: -1) ?? -1;
    _controller.forward();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _focusNode.requestFocus();
      }
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    _controller.dispose();
    super.dispose();
  }

  bool _actionable(int index) => index >= 0 && index < widget.items.length && widget.items[index].actionable;

  /// The nearest actionable row from [from] in [direction], or null at the end.
  int? _walk({required int from, required int direction}) {
    var next = from + direction;
    while (next >= 0 && next < widget.items.length) {
      if (_actionable(next)) {
        return next;
      }
      next += direction;
    }
    return null;
  }

  void _move(int direction) {
    final next = _walk(from: _active, direction: direction);
    if (next != null) {
      setState(() => _active = next);
    }
  }

  void _jump({required bool end}) {
    final target = end ? _walk(from: widget.items.length, direction: -1) : _walk(from: -1, direction: 1);
    if (target != null) {
      setState(() => _active = target);
    }
  }

  void _select(int index) {
    if (!_actionable(index)) {
      return;
    }
    unawaited(_close(widget.items[index]));
  }

  Future<void> _close([PureMenuItem? chosen]) async {
    if (_closing) {
      return;
    }
    setState(() => _closing = true);
    await _controller.reverse();
    widget.onDone(chosen);
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
      _move(1);
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
      _move(-1);
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.home) {
      _jump(end: false);
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.end) {
      _jump(end: true);
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.escape) {
      unawaited(_close());
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.enter ||
        event.logicalKey == LogicalKeyboardKey.numpadEnter ||
        event.logicalKey == LogicalKeyboardKey.space) {
      _select(_active);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final theme = widget.theme;
    final visual = widget.visual;
    final margin = theme.token.scale.sizes.sm;
    final gap = theme.token.scale.sizes.xxs;
    final viewport = MediaQuery.sizeOf(context);

    final list = Column(
      key: const Key('PureMenu.list'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: _rows(theme, visual),
    );
    final sized = widget.width != null
        ? SizedBox(width: widget.width, child: list)
        : ConstrainedBox(
            constraints: BoxConstraints(minWidth: visual.minWidth, maxWidth: visual.maxWidth),
            child: list,
          );
    final scrollable = ConstrainedBox(
      constraints: BoxConstraints(maxHeight: viewport.height * 0.8),
      child: SingleChildScrollView(child: sized),
    );

    return Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(behavior: HitTestBehavior.opaque, onTap: () => unawaited(_close())),
        ),
        Positioned.fill(
          child: CustomSingleChildLayout(
            delegate: _MenuPositionDelegate(anchor: widget.anchor, position: widget.position, margin: margin, gap: gap),
            child: FadeTransition(
              opacity: _fade,
              child: ScaleTransition(
                scale: _scale,
                alignment: visual.beginAlignment,
                child: Focus(
                  focusNode: _focusNode,
                  autofocus: true,
                  canRequestFocus: true,
                  onKeyEvent: _onKey,
                  child: Semantics(container: true, child: visual.card(theme, scrollable)),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// The rows with the separators the caller placed woven in.
  List<Widget> _rows(PureTheme theme, _MenuVisual visual) {
    final children = <Widget>[];
    var drewRow = false;
    for (var index = 0; index < widget.items.length; index++) {
      final item = widget.items[index];
      if (item.isSeparator) {
        children.add(_divider(theme, visual));
        drewRow = false;
        continue;
      }
      if (drewRow && visual.showSeparators) {
        children.add(_divider(theme, visual));
      }
      children.add(_row(theme, visual, index, item));
      drewRow = true;
    }
    return children;
  }

  Widget _divider(PureTheme theme, _MenuVisual visual) => Padding(
    // The hairline sits in the row gutter rather than running edge to edge, the
    // way desktop menus inset their separators.
    padding: EdgeInsets.symmetric(horizontal: theme.token.scale.sizes.sm, vertical: theme.token.scale.sizes.xxs / 2),
    child: ExcludeSemantics(child: Container(height: 1, color: visual.separatorColor(theme))),
  );

  Widget _row(PureTheme theme, _MenuVisual visual, int index, PureMenuItem item) {
    final active = index == _active;
    final actionable = item.actionable;
    final color = visual.content(theme, active: active, danger: item.danger, enabled: actionable);
    final labelStyle = theme.text.body.copyWith(color: color);
    final wash = active && actionable ? visual.highlight(theme) : null;

    final Widget glyph;
    if (item.checked) {
      glyph = Icon(
        Icons.check,
        size: visual.iconSize,
        color: visual.checkColor(theme, active: active),
      );
    } else if (item.icon case final IconData icon) {
      glyph = Icon(icon, size: visual.iconSize, color: color);
    } else {
      // The gutter is kept even with no glyph, so labels line up across a menu
      // that carries icons only on some rows.
      glyph = SizedBox(width: visual.iconSize);
    }

    return MouseRegion(
      cursor: actionable ? SystemMouseCursors.click : MouseCursor.defer,
      onEnter: (_) {
        if (actionable && !active) {
          setState(() => _active = index);
        }
      },
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: actionable ? () => _select(index) : null,
        child: Semantics(
          button: true,
          selected: item.checked,
          enabled: actionable,
          label: item.semanticsText.isEmpty ? null : item.semanticsText,
          child: Container(
            constraints: BoxConstraints(minHeight: visual.rowHeight),
            margin: EdgeInsets.symmetric(horizontal: theme.token.scale.sizes.xxs),
            padding: visual.rowPadding,
            decoration: BoxDecoration(color: wash, borderRadius: visual.rowRadius),
            alignment: Alignment.centerLeft,
            child: Row(
              children: [
                glyph,
                SizedBox(width: visual.leadingGap),
                Expanded(
                  child: Text(item.label, maxLines: 1, overflow: TextOverflow.ellipsis, style: labelStyle),
                ),
                if (item.shortcut case final String accelerator) ...[
                  SizedBox(width: visual.leadingGap),
                  Text(accelerator, style: theme.text.bodySmall.copyWith(color: theme.colors.textTertiary)),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Places the card against its [anchor] (or at the tap [position]), opening
/// downward as it does on every platform, flipping up when the bottom is short,
/// and clamping the whole card inside the viewport.
class _MenuPositionDelegate extends SingleChildLayoutDelegate {
  new({required this.anchor, required this.position, required this.margin, required this.gap});

  final Rect? anchor;
  final Offset position;
  final double margin;
  final double gap;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) => constraints.loosen();

  @override
  Offset getPositionForChild(Size size, Size childSize) {
    var left = position.dx;
    var top = position.dy;
    if (anchor case final trigger?) {
      left = trigger.left;
      top = trigger.bottom + gap;
      if (top + childSize.height > size.height - margin) {
        final above = trigger.top - gap - childSize.height;
        top = above >= margin ? above : size.height - margin - childSize.height;
      }
    } else if (top + childSize.height > size.height - margin) {
      top = position.dy - childSize.height;
    }
    return Offset(
      left.clamp(margin, doubleMax(margin, size.width - margin - childSize.width)),
      top.clamp(margin, doubleMax(margin, size.height - margin - childSize.height)),
    );
  }

  static double doubleMax(double a, double b) => a > b ? a : b;

  @override
  bool shouldRelayout(_MenuPositionDelegate oldDelegate) =>
      oldDelegate.anchor != anchor ||
      oldDelegate.position != position ||
      oldDelegate.margin != margin ||
      oldDelegate.gap != gap;
}
