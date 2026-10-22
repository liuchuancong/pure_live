import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show KeyDownEvent, KeyEvent, KeyRepeatEvent, LogicalKeyboardKey;
import 'package:pure_uikit/src/styling/provider/pure_config_provider.dart';

/// The kit's select / combobox: choose one value from a list.
///
/// Where the tab bar and the segmented control name a choice you already made
/// in the page, this is the form control that makes the choice: a closed field
/// carrying the current value (or the placeholder while nothing is chosen) and
/// a menu of the options that opens under it. The grammar is WinUI's
/// `ComboBox`: a bordered box on the subtle fill, a chevron that flips when the
/// popup opens, and a popup whose items reveal on hover. All of it is painted
/// here; the colours, radii, motion and text come from the tokens, so a dark
/// switch still comes out right.
///
/// Every visual answers to the same interaction contract: hover, pressed and
/// focus tints on the closed field; Enter, Space and ArrowDown open (ArrowUp
/// opens at the last option) and, while the menu is open, ArrowUp and
/// ArrowDown move the highlighted option, Enter and Space choose it, Escape
/// closes without choosing, and focus never leaves the field; the closed-to-open
/// and open-to-closed transitions animate over the theme's motion duration;
/// the field reads as a button that reports whether its menu is expanded, and
/// the chosen option reads as selected; a disabled (or inert) field greys out,
/// refuses taps and refuses keys.
///
/// A [value] the list does not carry is dropped to nothing-chosen — the field
/// shows its placeholder instead of pretending the value is selected — and the
/// menu keeps only choosable options (nulls and duplicates removed), the same
/// contract the library-backed control kept.
class PureSelect<T> extends StatelessWidget {
  /// A select over [items] with [value] chosen.
  const new({
    required this.items,
    required this.itemLabel,
    required this.onChanged,
    this.value,
    this.placeholder,
    this.enabled = true,
    super.key,
  });

  /// The selectable values, in order.
  final List<T> items;

  /// Maps a value to its display label.
  final String Function(T item) itemLabel;

  /// Called with the chosen value; null renders the select inert.
  final ValueChanged<T>? onChanged;

  /// The currently selected value, if any.
  final T? value;

  /// Text shown when nothing is selected.
  final String? placeholder;

  /// Whether the select responds to input; false greys the field out and
  /// refuses every interaction.
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    // A null callback is the inert state, so folding `enabled` into it once
    // gives the field a single verdict.
    final select = enabled ? onChanged : null;
    final carried = <T>[];
    for (final item in items) {
      if (item != null && !carried.contains(item)) {
        carried.add(item);
      }
    }
    return _SelectField<T>(
      items: carried,
      labelOf: itemLabel,
      value: value != null && carried.contains(value) ? value : null,
      placeholder: placeholder,
      select: select,
      visual: _SelectVisual.winuiComboBox(),
    );
  }
}

/// The closed field, the opening menu and the whole interaction contract:
/// only the [_SelectVisual] it paints with changes.
class _SelectField<T> extends StatefulWidget {
  const new({
    required this.items,
    required this.labelOf,
    required this.value,
    required this.placeholder,
    required this.select,
    required this.visual,
    super.key,
  });

  final List<T> items;

  final String Function(T item) labelOf;

  final T? value;

  final String? placeholder;

  final ValueChanged<T>? select;

  final _SelectVisual visual;

  @override
  State<_SelectField<T>> createState() => _SelectFieldState<T>();
}

class _SelectFieldState<T> extends State<_SelectField<T>> with SingleTickerProviderStateMixin {
  final FocusNode _focusNode = FocusNode(debugLabel: 'PureSelect.field');
  final GlobalKey _fieldKey = GlobalKey(debugLabel: 'PureSelect.field.box');
  List<GlobalKey> _optionKeys = const [];
  AnimationController? _menu;
  OverlayEntry? _entry;
  PureTheme? _lastTheme;
  bool _open = false;
  bool _hovered = false;
  bool _pressed = false;
  bool _focused = false;
  int _highlight = 0;

  @override
  void initState() {
    super.initState();
    _syncKeys();
  }

  @override
  void didUpdateWidget(covariant _SelectField<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.items.length != widget.items.length) {
      _syncKeys();
    }
    if (oldWidget.value != widget.value && !_open) {
      _highlight = _valueIndex;
    }
    // A select that goes inert while its menu is open closes it: nothing may
    // be chosen from a menu no one may choose from.
    if (_open && oldWidget.select != null && widget.select == null) {
      _close();
    }
  }

  @override
  void dispose() {
    _entry?.remove();
    _entry = null;
    _menu?.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  /// Whether the select answers to anything: an inert contract or an empty
  /// option list both refuse every interaction.
  bool get _live => widget.select != null && widget.items.isNotEmpty;

  int get _valueIndex {
    final value = widget.value;
    return value == null ? -1 : widget.items.indexOf(value);
  }

  void _syncKeys() {
    _optionKeys = [for (var i = 0; i < widget.items.length; i++) GlobalKey(debugLabel: 'PureSelect.option.$i')];
    _highlight = _valueIndex;
  }

  void _toggle() {
    if (!_live) {
      return;
    }
    if (_open) {
      _close();
      return;
    }
    final chosen = _valueIndex;
    _openMenu(chosen < 0 ? 0 : chosen);
  }

  void _openAt(int index) {
    if (!_live) {
      return;
    }
    _openMenu(index);
  }

  /// Mounts the menu into the nearest overlay — a real combobox floats its
  /// popup above the page, and a popup that left the field's box would be
  /// hit-tested no more — and drives the closed-to-open animation.
  void _openMenu(int index) {
    final theme = _lastTheme;
    if (theme == null) {
      return;
    }
    setState(() {
      _highlight = index.clamp(0, widget.items.length - 1);
      _open = true;
    });
    final controller = _menu;
    if (controller == null) {
      _menu = AnimationController(vsync: this, duration: theme.duration, reverseDuration: theme.duration)
        ..addStatusListener(_onMenuStatus);
    }
    _menu!
      ..duration = theme.duration
      ..reverseDuration = theme.duration
      ..forward();
    final entry = _entry;
    if (entry == null) {
      final fresh = OverlayEntry(builder: _menuLayer);
      _entry = fresh;
      Overlay.of(context).insert(fresh);
    } else {
      entry.markNeedsBuild();
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _reveal(_highlight));
  }

  void _close() {
    if (!_open) {
      return;
    }
    setState(() => _open = false);
    _syncMenu();
    _menu?.reverse();
  }

  /// Rebuilds the overlay menu one frame late: a close requested from
  /// `didUpdateWidget` (a select that goes inert while the menu is open) runs
  /// inside the field's own build, and the entry lives in the overlay —
  /// outside that widget — so an immediate `markNeedsBuild` would be illegal.
  void _syncMenu() {
    final entry = _entry;
    if (entry == null) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _entry == entry) {
        entry.markNeedsBuild();
      }
    });
  }

  /// The menu unmounts only once its fade-out has finished, so the
  /// open-to-close transition has something to animate. The removal waits for
  /// the frame's end — the status lands during the animation tick, and an
  /// overlay entry deactivated mid-frame trips the build scopes.
  void _onMenuStatus(AnimationStatus status) {
    if (status == AnimationStatus.dismissed && !_open && _entry != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !_open && _entry != null) {
          _entry!.remove();
          _entry = null;
        }
      });
    }
  }

  void _choose(int index) {
    if (!_open || !_live || index < 0 || index >= widget.items.length) {
      return;
    }
    widget.select!(widget.items[index]);
    _close();
  }

  void _moveHighlight(int direction) {
    if (!_live || !_open) {
      return;
    }
    final target = (_highlight + direction).clamp(0, widget.items.length - 1);
    if (target != _highlight) {
      setState(() => _highlight = target);
      _entry?.markNeedsBuild();
      _reveal(target);
    }
  }

  void _setHighlight(int index) {
    if (_open && _live && index != _highlight) {
      setState(() => _highlight = index);
      _entry?.markNeedsBuild();
    }
  }

  /// Scrolls the menu so option [index] is in view; a no-op while the menu is
  /// closed or the option list fits.
  void _reveal(int index) {
    if (index < 0 || index >= _optionKeys.length || !_open) {
      return;
    }
    final optionContext = _optionKeys[index].currentContext;
    if (optionContext != null) {
      Scrollable.ensureVisible(optionContext, duration: context.themeFor.duration, alignment: 0.5);
    }
  }

  KeyEventResult _handleKey(KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    if (!_live) {
      return KeyEventResult.ignored;
    }
    final key = event.logicalKey;
    if (_open) {
      if (key == LogicalKeyboardKey.escape) {
        _close();
        return KeyEventResult.handled;
      }
      if (key == LogicalKeyboardKey.arrowDown) {
        _moveHighlight(1);
        return KeyEventResult.handled;
      }
      if (key == LogicalKeyboardKey.arrowUp) {
        _moveHighlight(-1);
        return KeyEventResult.handled;
      }
      if (_activating.contains(key)) {
        _choose(_highlight);
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    }
    if (key == LogicalKeyboardKey.arrowDown || _activating.contains(key)) {
      // Enter, Space and the remote's A button open the menu on the chosen
      // option (or the first); ArrowDown rides the same gesture.
      _openAt(_valueIndex >= 0 ? _valueIndex : 0);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowUp) {
      _openAt(widget.items.length - 1);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  static final Set<LogicalKeyboardKey> _activating = {
    LogicalKeyboardKey.enter,
    LogicalKeyboardKey.numpadEnter,
    LogicalKeyboardKey.space,
    LogicalKeyboardKey.select,
    LogicalKeyboardKey.gameButtonA,
  };

  @override
  Widget build(BuildContext context) {
    final theme = context.themeFor;
    // The overlay menu paints with the theme of the last field build; the
    // entry re-reads this on every parent rebuild.
    _lastTheme = theme;
    final visual = widget.visual;
    final select = theme.select;
    final states = _FieldStates(open: _open, hovered: _hovered, pressed: _pressed, focused: _focused, enabled: _live);
    final valueIndex = _valueIndex;
    final label = valueIndex < 0 ? (widget.placeholder ?? '') : widget.labelOf(widget.items[valueIndex]);
    final labelStyle = theme.text.bodySmall.copyWith(color: visual.labelColor(theme, states, empty: valueIndex < 0));

    final box = visual.field(theme, states);
    // The focus ring is a foreground border that is always there and only
    // changes colour: an AnimatedContainer tweening a decoration that appears
    // and disappears trips the decoration lerp, so the ring fades in from
    // transparent instead of switching on.
    final ring = Border.fromBorderSide(
      BorderSide(color: _focused ? theme.colors.primary : Colors.transparent, width: _SelectMetrics.focusWidth),
    );
    final field = AnimatedContainer(
      key: _fieldKey,
      duration: theme.duration,
      curve: Curves.easeOut,
      height: select.height,
      padding: EdgeInsets.symmetric(horizontal: select.paddingInline),
      decoration: box,
      foregroundDecoration: BoxDecoration(borderRadius: box.borderRadius, border: ring),
      child: LayoutBuilder(
        builder: (context, constraints) {
          // A field with a width to fill spreads its label and pins the
          // arrow to the trailing edge; a field asked to hug its content
          // keeps both tight.
          final fills = constraints.hasBoundedWidth;
          final labelText = Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: labelStyle);
          return Row(
            mainAxisSize: fills ? MainAxisSize.max : MainAxisSize.min,
            children: [
              if (fills) Expanded(child: labelText) else Flexible(child: labelText),
              ExcludeSemantics(child: visual.arrow(theme, states)),
            ],
          );
        },
      ),
    );

    return Semantics(
      button: true,
      expanded: _open,
      enabled: _live,
      label: label.isEmpty ? null : label,
      child: Focus(
        focusNode: _focusNode,
        canRequestFocus: _live,
        onFocusChange: (focused) => setState(() => _focused = focused),
        onKeyEvent: (node, event) => _handleKey(event),
        child: MouseRegion(
          cursor: _live ? SystemMouseCursors.click : MouseCursor.defer,
          onEnter: (_) => setState(() => _hovered = true),
          onExit: (_) => setState(() => _hovered = false),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: _live
                ? (_) {
                    _focusNode.requestFocus();
                    setState(() => _pressed = true);
                  }
                : null,
            onTapUp: _live ? (_) => setState(() => _pressed = false) : null,
            onTapCancel: _live ? () => setState(() => _pressed = false) : null,
            onTap: _live ? _toggle : null,
            child: ExcludeSemantics(child: field),
          ),
        ),
      ),
    );
  }

  /// The overlay's single layer: a full-screen transparent stack that pins the
  /// menu to the field's bottom-left corner. The entry mounts when the menu
  /// opens and unmounts when the close animation lands, so the fade has
  /// something to animate out and a closed select keeps no popup weight.
  Widget _menuLayer(BuildContext overlayContext) {
    final theme = _lastTheme ?? PureTheme.of(overlayContext);
    final fieldBox = _fieldKey.currentContext?.findRenderObject();
    final anchor = fieldBox is RenderBox && fieldBox.hasSize
        ? fieldBox.localToGlobal(Offset.zero) & fieldBox.size
        : Rect.zero;
    return Stack(
      children: [
        const SizedBox.expand(),
        Positioned(
          left: anchor.left,
          top: anchor.bottom + _SelectMetrics.menuGap,
          width: anchor.width,
          child: IgnorePointer(
            ignoring: !_open,
            child: ExcludeSemantics(
              excluding: !_open,
              child: FadeTransition(
                key: _SelectMetrics.menuKey,
                opacity: CurvedAnimation(parent: _menu!, curve: Curves.easeOut),
                child: ScaleTransition(
                  scale: Tween<double>(
                    begin: _SelectMetrics.closedScale,
                    end: 1,
                  ).animate(CurvedAnimation(parent: _menu!, curve: Curves.easeOutCubic)),
                  alignment: Alignment.topCenter,
                  child: _menuPanel(theme, widget.visual),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// The popup panel: the menu decoration over the scrolling
  /// option list, sized to the field and capped at the menu ceiling.
  Widget _menuPanel(PureTheme theme, _SelectVisual visual) {
    return DecoratedBox(
      decoration: visual.menu(theme),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: _SelectMetrics.menuMaxHeight),
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(vertical: _SelectMetrics.menuPadding),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < widget.items.length; i++)
                _OptionRow(
                  key: _optionKeys[i],
                  label: widget.labelOf(widget.items[i]),
                  selected: i == _valueIndex,
                  highlighted: _open && i == _highlight,
                  live: _live,
                  visual: visual,
                  onHighlight: () => _setHighlight(i),
                  onPick: () => _choose(i),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One row of the menu: the hover that moves the highlight, the tap that
/// chooses, and the reading of a highlighted, chosen row.
class _OptionRow extends StatelessWidget {
  const new({
    required this.label,
    required this.selected,
    required this.highlighted,
    required this.live,
    required this.visual,
    required this.onHighlight,
    required this.onPick,
    super.key,
  });

  final String label;

  final bool selected;

  final bool highlighted;

  /// Whether the row may answer to input at all; an inert select's rows grey
  /// out and refuse.
  final bool live;

  final _SelectVisual visual;

  final VoidCallback onHighlight;

  final VoidCallback onPick;

  @override
  Widget build(BuildContext context) {
    final theme = context.themeFor;
    final states = _OptionStates(highlighted: highlighted, selected: selected, enabled: live);
    final foreground = visual.optionForeground(theme, states);
    final row = AnimatedContainer(
      duration: theme.duration,
      curve: Curves.easeOut,
      height: theme.select.itemHeight,
      padding: EdgeInsets.symmetric(horizontal: theme.select.paddingInline),
      alignment: AlignmentDirectional.centerStart,
      decoration: BoxDecoration(
        color: visual.optionBackground(theme, states),
        borderRadius: visual.optionRadius(theme),
      ),
      child: Row(
        children: [
          // The chosen row leads with the WinUI accent bar.
          if (selected) ...[
            Container(width: _SelectMetrics.barWidth, height: _SelectMetrics.barHeight, color: theme.colors.primary),
            const SizedBox(width: _SelectMetrics.barGap),
          ],
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.text.bodySmall.copyWith(color: foreground),
            ),
          ),
        ],
      ),
    );
    return Semantics(
      button: true,
      selected: selected,
      enabled: live,
      label: label.isEmpty ? null : label,
      child: ExcludeSemantics(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: live ? onPick : null,
          child: MouseRegion(
            cursor: live ? SystemMouseCursors.click : MouseCursor.defer,
            onEnter: (_) => onHighlight(),
            child: row,
          ),
        ),
      ),
    );
  }
}

extension on BuildContext {
  /// The resolved theme, read the way every component here does.
  PureTheme get themeFor => PureTheme.of(this);
}

/// The fixed geometry a select lays out: absolute pixels, so the menu keeps
/// its shape. Heights, paddings and item rows still come from the select's
/// component tokens.
abstract final class _SelectMetrics {
  /// The key the popup menu answers to — the fade that carries
  /// the open/close animation inside the overlay.
  static const Key menuKey = ValueKey<String>('PureSelect.menu');

  /// 4 — the gap between the field's bottom edge and the menu's top.
  static const double menuGap = 4;

  /// 300 — the menu's ceiling; a longer option list scrolls under it.
  static const double menuMaxHeight = 300;

  /// 4 — the menu's vertical padding inside its panel.
  static const double menuPadding = 4;

  /// 0.96 — the scale a closing menu shrinks to while it fades out.
  static const double closedScale = 0.96;

  /// 2 — the focus ring's width.
  static const double focusWidth = 2;

  /// 2 — the width of the accent bar a chosen option leads with.
  static const double barWidth = 2;

  /// 14 — that bar's height.
  static const double barHeight = 14;

  /// 6 — the gap between that bar and the label.
  static const double barGap = 6;

  /// 18 — the trailing arrow's glyph size.
  static const double arrowSize = 18;
}

/// The interaction states the closed field answers in.
@immutable
final class _FieldStates {
  const new({
    required this.open,
    required this.hovered,
    required this.pressed,
    required this.focused,
    required this.enabled,
  });

  final bool open;

  final bool hovered;

  final bool pressed;

  final bool focused;

  final bool enabled;
}

/// The states one menu row answers in.
@immutable
final class _OptionStates {
  const new({required this.highlighted, required this.selected, required this.enabled});

  final bool highlighted;

  final bool selected;

  final bool enabled;
}

/// How the select is painted: the closed field, its trailing
/// arrow, the menu panel, and the colours of a highlighted or chosen option.
@immutable
final class _SelectVisual {
  const new({
    required this.field,
    required this.labelColor,
    required this.arrow,
    required this.menu,
    required this.optionBackground,
    required this.optionForeground,
    required this.optionRadius,
  });

  /// WinUI's `ComboBox`: a bordered box on the subtle fill, the chevron that
  /// flips when the popup opens, and a popup whose rows reveal a soft fill on
  /// hover while the chosen one leads with the accent bar.
  factory winuiComboBox() {
    return _SelectVisual(
      field: (theme, states) => BoxDecoration(
        color: states.enabled
            ? (states.open
                  ? theme.colors.fillSecondary
                  : states.pressed || states.hovered
                  ? theme.colors.fillTertiary
                  : theme.colors.bgContainer)
            : theme.colors.bgContainerDisabled,
        borderRadius: BorderRadius.circular(theme.token.scale.radii.base),
        border: Border.all(
          color: states.open
              ? theme.colors.primary
              : states.hovered && states.enabled
              ? theme.colors.textTertiary
              : theme.colors.border,
          width: states.open ? theme.token.motion.lineWidthBold : theme.token.motion.lineWidth,
        ),
      ),
      labelColor: _defaultLabel,
      arrow: (theme, states) => _flip(
        theme,
        states,
        Icon(Icons.keyboard_arrow_down, size: _SelectMetrics.arrowSize, color: _arrowInk(theme, states)),
      ),
      menu: (theme) => BoxDecoration(
        color: theme.colors.bgElevated,
        borderRadius: BorderRadius.circular(theme.token.scale.radii.base),
        border: Border.all(color: theme.colors.borderSecondary, width: theme.token.motion.lineWidth),
        boxShadow: theme.token.motion.boxShadow,
      ),
      optionBackground: (theme, states) => states.highlighted ? theme.colors.fillSecondary : null,
      optionForeground: _defaultOption,
      optionRadius: (theme) => BorderRadius.circular(theme.token.scale.radii.sm),
    );
  }

  /// The closed field's decoration in each state.
  final BoxDecoration Function(PureTheme theme, _FieldStates states) field;

  /// The field's label colour; `empty` is true while the placeholder shows.
  final Color Function(PureTheme theme, _FieldStates states, {required bool empty}) labelColor;

  /// The trailing indicator — the flipping chevron.
  final Widget Function(PureTheme theme, _FieldStates states) arrow;

  /// The menu panel's decoration.
  final BoxDecoration Function(PureTheme theme) menu;

  /// The background of a highlighted or chosen option row.
  final Color? Function(PureTheme theme, _OptionStates states) optionBackground;

  /// The label colour of an option row.
  final Color Function(PureTheme theme, _OptionStates states) optionForeground;

  /// The corner radius of an option row's highlight.
  final BorderRadius Function(PureTheme theme) optionRadius;

  /// The field's label colour: the disabled grey, the
  /// placeholder's tertiary, and the text role everywhere else.
  static Color _defaultLabel(PureTheme theme, _FieldStates states, {required bool empty}) {
    if (!states.enabled) {
      return theme.colors.textQuaternary;
    }
    return empty ? theme.colors.textPlaceholder : theme.colors.text;
  }

  /// The option label colour: the disabled grey, and the text role everywhere
  /// else — the highlight is the paint.
  static Color _defaultOption(PureTheme theme, _OptionStates states) =>
      states.enabled ? theme.colors.text : theme.colors.textQuaternary;

  /// The arrow ink: the icon role, brightened on hover, greyed when inert.
  static Color _arrowInk(PureTheme theme, _FieldStates states) {
    if (!states.enabled) {
      return theme.colors.textQuaternary;
    }
    return states.hovered ? theme.colors.iconHover : theme.colors.icon;
  }

  /// The open-close flip: the chevron turns half a
  /// turn while the menu is open.
  static Widget _flip(PureTheme theme, _FieldStates states, Widget icon) =>
      AnimatedRotation(turns: states.open ? 0.5 : 0, duration: theme.duration, curve: Curves.easeOut, child: icon);
}
