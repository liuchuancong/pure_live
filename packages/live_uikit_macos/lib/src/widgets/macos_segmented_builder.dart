import 'package:flutter/widgets.dart';
import 'package:live_uikit/live_uikit.dart';
import 'package:macos_ui/macos_ui.dart' as macos;

/// Builds a macOS segmented track from a [LanguageSegmentedSpec] (§9 Segmented).
///
/// Mapped: `MacosSegmentedControl` is the library's own answer to one choice out
/// of a row — the tinted track, the white rounded chip on the checked segment and
/// the hairline between neighbours. Its documentation calls itself the analogue of
/// Material's `TabBar`, which is why the tab strip of this adapter composes its
/// cells out of the same segment cell.
///
/// Two differences from the neutral spec are handled here rather than ignored:
///
///  * the control is driven by a `MacosTabController` and offers no index
///    callback, so the controller belongs to this widget and is wired both ways —
///    its change is reported through [LanguageSegmentedSpec.onChanged], and the
///    spec's [LanguageSegmentedSpec.index] is asserted back onto it on every
///    rebuild. That keeps the track controlled: a caller that refuses a tap gets
///    the chip moved back on its next frame.
///  * the control has no disabled state at all — it sets the controller index on
///    tap whatever the caller asked — so an inert spec is wrapped in
///    [IgnorePointer], which keeps the segments where the spec puts them instead
///    of drawing a selection the caller never agreed to.
///
/// [LanguageSegmentedSpec.expand] has no counterpart: the control lays its
/// segments out through `IntrinsicWidth`/`IntrinsicHeight` and sizes to their
/// labels, so it cannot be stretched to fill. An empty track has nothing to draw
/// and returns an empty box, because the control asserts at least one segment.
abstract final class MacosSegmentedBuilder {
  /// Builds the segmented track for [spec].
  static Widget build(BuildContext context, LanguageSegmentedSpec spec) {
    if (spec.labels.isEmpty) {
      return const SizedBox.shrink();
    }
    return _ControlledSegmentedControl(spec: spec);
  }
}

class _ControlledSegmentedControl extends StatefulWidget {
  const new({required this.spec});

  final LanguageSegmentedSpec spec;

  @override
  State<_ControlledSegmentedControl> createState() => _ControlledSegmentedControlState();
}

class _ControlledSegmentedControlState extends State<_ControlledSegmentedControl> {
  late macos.MacosTabController _controller = _createController();

  /// True while the index change came from this widget rather than from a tap, so
  /// the listener does not report the caller's own value back to it.
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
  void didUpdateWidget(covariant _ControlledSegmentedControl oldWidget) {
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
