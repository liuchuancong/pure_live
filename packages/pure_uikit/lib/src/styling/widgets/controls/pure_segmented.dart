import 'package:fluent_2/fluent_2.dart' as f2;
import 'package:flutter/cupertino.dart' as cupertino;
import 'package:flutter/material.dart';
import 'package:flutter_neumorphic_ui_kit/flutter_neumorphic_ui_kit.dart' as neu;
import 'package:fluttersdk_wind/fluttersdk_wind.dart' as wind;
import 'package:forui/forui.dart' as forui;
import 'package:glass_morphism_plus/glass_morphism_plus.dart' as glass;
import 'package:macos_ui/macos_ui.dart' as macos;
import 'package:pure_uikit/src/styling/config/pure_design_language.dart';
import 'package:pure_uikit/src/styling/provider/pure_config_provider.dart';
import 'package:pure_uikit/src/styling/style/style.dart' show InteractionState, Style;
import 'package:pure_uikit/src/styling/widgets/layout/pure_box.dart';

/// The public segmented control: one widget, every theme and density. [build]
/// switches on `UiConfig.language` and constructs the language's own answer to
/// "one choice out of a row" directly — Material's `SegmentedButton`, iOS's
/// `CupertinoSegmentedControl`, macOS's `MacosSegmentedControl`, and under
/// fluent a row of the library's real buttons with the accent fill on the
/// checked one. Switching `UiConfig.language` re-skins every track.
class PureSegmented extends StatelessWidget {
  /// A segmented control over [labels].
  const new({
    required this.labels,
    required this.index,
    required this.onChanged,
    this.expand = false,
    this.enabled = true,
    super.key,
  });

  /// The segment labels, in order.
  final List<String> labels;

  /// The selected index.
  final int index;

  /// Called with a segment's index when chosen.
  final ValueChanged<int>? onChanged;

  /// Whether the segments share the full width.
  final bool expand;

  /// Whether the control responds to input.
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final theme = PureTheme.of(context);
    // A null callback is every library's inert state, so folding `enabled`
    // into it once serves all the branches below.
    final select = enabled ? onChanged : null;

    return switch (theme.config.language) {
      PureDesignLanguage.material => SegmentedButton<int>(
        showSelectedIcon: false,
        expandedInsets: expand ? EdgeInsets.zero : null,
        segments: [for (var i = 0; i < labels.length; i++) ButtonSegment(value: i, label: Text(labels[i]))],
        selected: {index},
        onSelectionChanged: select == null ? null : (selection) => select(selection.first),
      ),
      // The Cupertino track divides the width it is handed between its
      // segments, so `expand` is how iOS draws one anyway.
      PureDesignLanguage.cupertino => _cupertino(theme, select),
      PureDesignLanguage.macos => labels.isEmpty ? const SizedBox.shrink() : _MacosSegmentedControl(this),
      // fluent_2 has no segmented widget yet: the language's own reading of a
      // segmented pick is a group of buttons whose checked one carries the
      // accent fill, composed here from the library's real button.
      PureDesignLanguage.fluent => Row(
        mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
        children: [
          for (var i = 0; i < labels.length; i++)
            if (expand)
              Expanded(child: _fluentSegment(i, select))
            else
              _fluentSegment(i, select),
        ],
      ),
      // Hand-rolled forui-style composition: forui has no segmented-track
      // widget — its only single choice out of a row is `FTabs`, and that is a
      // tab view every entry of which carries a content panel this contract
      // already spends on the tab strip. A segment is a value, not a view, so
      // the track is assembled out of the library's own `FButton`s in the
      // ghost variant, where the chosen one takes `FButton.selected` — the
      // library's real toggled affordance, drawn by its style table rather
      // than painted over it.
      PureDesignLanguage.forui => Row(
        mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
        children: [
          for (var i = 0; i < labels.length; i++)
            if (expand) Expanded(child: _foruiSegment(i, select)) else _foruiSegment(i, select),
        ],
      ),
      // Hand-rolled glass-style composition: glass_morphism_plus ships no
      // choice track, so the groove is a frosted [glass.GlassContainer] sheet
      // and the chosen segment a second, brighter one sitting in it — a lit
      // surface, not a filled shape, which is how glassmorphism marks a
      // selection. Taps and interaction tints ride on the core's [PureBox],
      // for the reason every composed glass control gives.
      PureDesignLanguage.glass => _glass(context, theme, select),
      // Hand-rolled neumorphic-style composition: the library ships no
      // segmented track, and the style answers "one choice out of a row" with
      // depth rather than with colour fill — a recessed dish
      // (`NeuContainer` in [neu.NeuShape.pressed]) holding one cell per
      // segment, the chosen cell pushed back out as a dome
      // ([neu.NeuShape.convex]) at the theme's depth with the accent on its
      // label, the library's own idle/pressed pair read as a selection.
      PureDesignLanguage.neumorphic => _neumorphic(context, select),
      // Hand-rolled wind-style composition: the fork has no segmented track,
      // so it is a row of `WButton`s where the chosen one carries the
      // library's own `selected:` state prefix — the very mechanism `WTabs`
      // uses to mark its active tab — through the fork's state pipeline. The
      // accent carries the choice and the neutral greys the hover, because
      // Wind's `primary` scale reaches this subtree as one flat accent.
      PureDesignLanguage.wind => _wind(select),
      // Yaru IS Material theming — its character comes from the host theme, not
      // from a different track.
      PureDesignLanguage.material || PureDesignLanguage.yaru => SegmentedButton<int>(
        showSelectedIcon: false,
        expandedInsets: expand ? EdgeInsets.zero : null,
        segments: [for (var i = 0; i < labels.length; i++) ButtonSegment(value: i, label: Text(labels[i]))],
        selected: {index},
        onSelectionChanged: select == null ? null : (selection) => select(selection.first),
      ),
    };
  }

  /// The Cupertino track, or its inert forms: `CupertinoSegmentedControl`
  /// asserts at least two segments, so one label is drawn as the library's own
  /// dead press cell and none at all as an empty box.
  Widget _cupertino(PureTheme theme, ValueChanged<int>? select) {
    if (labels.isEmpty) {
      return const SizedBox.shrink();
    }
    if (labels.length == 1) {
      return cupertino.CupertinoButton(
        minimumSize: Size.zero,
        padding: EdgeInsets.symmetric(horizontal: theme.token.scale.sizes.sm, vertical: theme.token.scale.sizes.xxs),
        foregroundColor: theme.tabs.itemColor,
        onPressed: null,
        child: Text(labels.first, maxLines: 1, overflow: TextOverflow.ellipsis),
      );
    }
    final children = {for (var i = 0; i < labels.length; i++) i: Text(labels[i], maxLines: 1, overflow: TextOverflow.ellipsis)};
    return cupertino.CupertinoSegmentedControl<int>(
      children: children,
      groupValue: children.containsKey(index) ? index : null,
      onValueChanged: (i) => select?.call(i),
      disabledChildren: enabled ? const <int>{} : children.keys.toSet(),
    );
  }

  /// One Fluent segment: the library's button, accent-filled when it is the
  /// checked one.
  Widget _fluentSegment(int i, ValueChanged<int>? select) {
    return f2.FluentButton(
      onPressed: select == null ? null : () => select(i),
      appearance: i == index ? f2.FluentButtonAppearance.primary : f2.FluentButtonAppearance.secondary,
      child: Text(labels[i], maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center),
    );
  }

  /// One forui segment: the library's ghost `FButton`, whose `selected` state
  /// — forui's own toggled affordance — marks the chosen one.
  Widget _foruiSegment(int i, ValueChanged<int>? select) {
    return forui.FButton(
      variant: forui.FButtonVariant.ghost,
      selected: i == index,
      onPress: select == null ? null : () => select(i),
      mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
      child: Text(labels[i], maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center),
    );
  }

  /// The glass track: the frosted groove and its lit chosen segment, taps on
  /// the core's [PureBox].
  Widget _glass(BuildContext context, PureTheme theme, ValueChanged<int>? select) {
    final glassTheme = glass.GlassTheme.of(context);
    final radius = BorderRadius.circular(glassTheme.borderRadius - theme.token.motion.lineWidth);

    Widget segment(int i) {
      final selected = i == index;
      final text = Text(
        labels[i],
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.center,
        style: theme.text.label.copyWith(color: selected ? theme.colors.text : theme.colors.textSecondary),
      );
      return PureBox(
        style: (state) => Style(
          borderRadius: radius,
          background: switch (state) {
            InteractionState.hovered ||
            InteractionState.pressed ||
            InteractionState.focused => glassTheme.color.withValues(alpha: (glassTheme.opacity * 1.8).clamp(0.0, 1.0)),
            InteractionState.disabled => null,
            InteractionState.normal => null,
          },
          opacity: state == InteractionState.disabled ? theme.token.motion.opacityLoading : null,
        ),
        onTap: select == null ? null : () => select(i),
        enabled: enabled,
        child: selected
            ? glass.GlassContainer(
                padding: EdgeInsets.symmetric(horizontal: theme.tabs.horizontalPadding, vertical: theme.token.scale.sizes.xs),
                customBorderRadius: radius,
                color: theme.colors.primary,
                opacity: (glassTheme.opacity * 2.6).clamp(0.0, 1.0),
                child: text,
              )
            : Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: theme.tabs.horizontalPadding,
                  vertical: theme.token.scale.sizes.xs,
                ),
                child: text,
              ),
      );
    }

    final track = glass.GlassContainer(
      padding: EdgeInsets.all(theme.token.motion.lineWidth),
      child: Row(
        mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
        children: [
          for (var i = 0; i < labels.length; i++)
            if (expand) Expanded(child: segment(i)) else segment(i),
        ],
      ),
    );
    return expand ? SizedBox(width: double.infinity, child: track) : track;
  }

  /// The neumorphic track: a recessed dish of cells, the chosen one domed back
  /// out with the accent on its label.
  Widget _neumorphic(BuildContext context, ValueChanged<int>? select) {
    final theme = PureTheme.of(context);
    final surface = neu.NeuTheme.of(context);
    final inset = theme.token.scale.sizes.xs;
    final trackRadius = surface.borderRadius.resolve(Directionality.of(context));
    final cellRadius = BorderRadius.circular(trackRadius.topLeft.x <= inset ? 0.0 : trackRadius.topLeft.x - inset);

    Widget cell(int i) => _NeumorphicSegmentCell(
      label: labels[i],
      selected: i == index,
      enabled: enabled,
      onTap: select == null ? null : () => select(i),
      radius: cellRadius,
      surface: surface,
      theme: theme,
    );

    return neu.NeuContainer(
      shape: neu.NeuShape.pressed,
      borderRadius: trackRadius,
      baseColor: surface.baseColor,
      depth: 2.5,
      padding: EdgeInsets.all(inset),
      child: Row(
        mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
        children: [
          for (var i = 0; i < labels.length; i++)
            if (expand) Expanded(child: cell(i)) else cell(i),
        ],
      ),
    );
  }

  /// The wind track: one `WButton` per segment, the chosen one carrying the
  /// library's own `selected:` tokens. `flex-1` is a `WDiv`/`WText` feature
  /// and `WButton` reads only its own width classes, so `expand` wraps each
  /// button in an `Expanded` with `w-full` on it.
  Widget _wind(ValueChanged<int>? select) {
    const selectedStates = <String>{'selected'};
    const segmentClasses =
        'px-4 py-2 rounded-lg text-sm text-gray-600 dark:text-gray-300 transition-colors'
        ' hover:bg-gray-100 dark:hover:bg-gray-800'
        ' selected:bg-primary-500 selected:text-white'
        ' disabled:opacity-50';

    Widget segment(int i) {
      final inert = select == null;
      final button = wind.WButton(
        onTap: inert ? null : () => select(i),
        disabled: inert,
        states: i == index ? selectedStates : null,
        semanticLabel: labels[i],
        className: expand ? '$segmentClasses w-full' : segmentClasses,
        child: wind.WText(labels[i], className: 'text-center truncate'),
      );
      return expand ? Expanded(child: button) : button;
    }

    return wind.WDiv(
      className: expand ? 'flex flex-row items-center gap-1 w-full' : 'flex flex-row items-center gap-1',
      children: [for (var i = 0; i < labels.length; i++) segment(i)],
    );
  }
}

/// One cell of the neumorphic track: the same plane the dish is made of, domed
/// out ([neu.NeuShape.convex]) when it is the chosen one — the library's own
/// idle/pressed pair read as a selection instead of as a touch.
class _NeumorphicSegmentCell extends StatelessWidget {
  const new({
    required this.label,
    required this.selected,
    required this.enabled,
    required this.onTap,
    required this.radius,
    required this.surface,
    required this.theme,
  });

  final String label;
  final bool selected;
  final bool enabled;
  final VoidCallback? onTap;
  final BorderRadius radius;
  final neu.NeuThemeData surface;
  final PureTheme theme;

  @override
  Widget build(BuildContext context) {
    final Color tint;
    if (!enabled) {
      tint = theme.colors.textDisabled;
    } else if (selected) {
      tint = surface.accentColor;
    } else {
      tint = theme.colors.text;
    }
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: neu.NeuContainer(
        shape: selected ? neu.NeuShape.convex : neu.NeuShape.flat,
        borderRadius: radius,
        baseColor: surface.baseColor,
        depth: selected ? surface.depth : 0.0,
        distance: selected ? surface.distance : 0.0,
        alignment: Alignment.center,
        padding: EdgeInsets.symmetric(horizontal: theme.token.scale.sizes.md, vertical: theme.token.scale.sizes.sm),
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: selected
              ? theme.text.body.copyWith(color: tint, fontWeight: FontWeight.w600)
              : theme.text.body.copyWith(color: tint),
        ),
      ),
    );
  }
}

/// The macOS track: `MacosSegmentedControl` is driven by a `MacosTabController`
/// and offers no index callback, so the controller belongs here and is wired
/// both ways — its change is reported through the spec's `onChanged`, and the
/// spec's [PureSegmented.index] is asserted back onto it on every rebuild. That keeps
/// the track controlled: a caller that refuses a tap gets the chip moved back
/// on its next frame. The control has no disabled state at all — it sets the
/// controller index on tap whatever the caller asked — so an inert spec is
/// wrapped in an [IgnorePointer], which keeps the segments where the spec puts
/// them instead of drawing a selection the caller never agreed to. The control
/// sizes to its labels, so `expand` has no counterpart in this language.
class _MacosSegmentedControl extends StatefulWidget {
  const new(this.spec);

  final PureSegmented spec;

  @override
  State<_MacosSegmentedControl> createState() => _MacosSegmentedControlState();
}

class _MacosSegmentedControlState extends State<_MacosSegmentedControl> {
  late macos.MacosTabController _controller = _createController();

  /// True while the index change came from this widget rather than from a tap,
  /// so the listener does not report the caller's own value back to it.
  bool _asserting = false;

  macos.MacosTabController _createController() {
    final spec = widget.spec;
    return macos.MacosTabController(
      length: spec.labels.length,
      initialIndex: spec.index.clamp(0, spec.labels.length - 1),
    )..addListener(_handleControllerChanged);
  }

  void _handleControllerChanged() {
    if (_asserting) {
      return;
    }
    (widget.spec.enabled ? widget.spec.onChanged : null)?.call(_controller.index);
  }

  @override
  void didUpdateWidget(covariant _MacosSegmentedControl oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.spec.labels.length != widget.spec.labels.length) {
      // The controller's length is final, so a track that gained or lost a
      // segment gets a fresh one, seeded at the spec's index.
      _releaseController();
      _controller = _createController();
      return;
    }
    _assertIndex();
  }

  void _assertIndex() {
    final index = widget.spec.index;
    if (index < 0 || index >= widget.spec.labels.length || _controller.index == index) {
      return;
    }
    _asserting = true;
    _controller.index = index;
    _asserting = false;
  }

  void _releaseController() {
    _controller
      ..removeListener(_handleControllerChanged)
      ..dispose();
  }

  @override
  void dispose() {
    _releaseController();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final spec = widget.spec;
    final inert = !spec.enabled || spec.onChanged == null;
    return IgnorePointer(
      ignoring: inert,
      child: macos.MacosSegmentedControl(
        controller: _controller,
        tabs: [for (final label in spec.labels) macos.MacosTab(label: label)],
      ),
    );
  }
}
