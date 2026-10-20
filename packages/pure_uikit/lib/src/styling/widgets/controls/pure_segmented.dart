import 'package:fluent_2/fluent_2.dart' as f2;
import 'package:flutter/cupertino.dart' as cupertino;
import 'package:flutter/material.dart';
import 'package:forui/forui.dart' as forui;
import 'package:macos_ui/macos_ui.dart' as macos;
import 'package:pure_uikit/src/styling/config/pure_design_language.dart';
import 'package:pure_uikit/src/styling/provider/pure_config_provider.dart';

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
            if (expand) Expanded(child: _fluentSegment(i, select)) else _fluentSegment(i, select),
        ],
      ),
      // forui has no segmented-track widget — its only single choice out of a
      // row is `FTabs`, and that is a tab view every entry of which carries a
      // content panel this contract already spends on the tab strip. A segment
      // is a value, not a view, so the track is assembled out of the library's
      // own `FButton`s in the ghost variant, where the chosen one takes
      // `FButton.selected` — the library's real toggled affordance, drawn by
      // its style table rather than painted over it.
      PureDesignLanguage.forui => Row(
        mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
        children: [
          for (var i = 0; i < labels.length; i++)
            if (expand) Expanded(child: _foruiSegment(i, select)) else _foruiSegment(i, select),
        ],
      ),
      // glass_morphism_plus ships no segmented control. Use Flutter's official
      // Material segmented button rather than a hand-painted glass track.
      PureDesignLanguage.glass => _materialSegmented(select),
      // The neumorphic library ships no segmented track; the official Material
      // segmented button is the fallback control.
      PureDesignLanguage.neumorphic => _materialSegmented(select),
      // fluttersdk_wind ships no segmented track; the official Material
      // segmented button is the fallback control.
      PureDesignLanguage.wind => _materialSegmented(select),
      // Yaru's nearest thing is `YaruChoiceChipBar` — chips, which select,
      // deselect and wrap, rather than one track with one thumb. Flutter's
      // official segmented button is the control this contract describes.
      PureDesignLanguage.material || PureDesignLanguage.yaru => _materialSegmented(select),
    };
  }

  /// The official Material segmented button, shared by the languages whose
  /// libraries do not ship a segmented track.
  Widget _materialSegmented(ValueChanged<int>? select) {
    return SegmentedButton<int>(
      showSelectedIcon: false,
      expandedInsets: expand ? EdgeInsets.zero : null,
      segments: [for (var i = 0; i < labels.length; i++) ButtonSegment(value: i, label: Text(labels[i]))],
      selected: {index},
      onSelectionChanged: select == null ? null : (selection) => select(selection.first),
    );
  }

  /// The Cupertino track, or its inert forms: the sliding control asserts at
  /// least two segments, so one label is drawn as the library's own dead press
  /// cell and none at all as an empty box.
  ///
  /// This is the same control the tab strip dispatches to — iOS's segmented
  /// track with the sliding thumb. The legacy `CupertinoSegmentedControl` is a
  /// different object in the same library, and having one of each meant the same
  /// idea arrived at two heights (28 and 32) depending on which control the
  /// caller reached for.
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
    final children = {
      for (var i = 0; i < labels.length; i++) i: Text(labels[i], maxLines: 1, overflow: TextOverflow.ellipsis),
    };
    return cupertino.CupertinoSlidingSegmentedControl<int>(
      children: children,
      groupValue: children.containsKey(index) ? index : null,
      // The sliding control reports a null value when the thumb is released off
      // any cell; the legacy one never did.
      onValueChanged: (i) {
        if (i != null) {
          select?.call(i);
        }
      },
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
