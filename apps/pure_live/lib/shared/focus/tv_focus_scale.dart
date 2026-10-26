import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_platform/live_platform.dart' show FormFactor;
import 'package:pure_live/app/app.dart';
import 'package:pure_live/features/settings/settings.dart';

/// How much a focused card or menu row grows on TV (the reference's
/// `tvFocusZoom`, U.15a c2).
const double kTvFocusZoom = 1.05;

/// How long the growth takes; losing focus snaps so a held arrow never
/// leaves a trail of half-grown items.
const Duration kTvFocusZoomDuration = Duration(milliseconds: 120);

/// Grows [child] by [kTvFocusZoom] while it or a control inside it holds
/// focus, on a TV build with the focus-zoom setting on.
///
/// The wrapper is not a focus stop: the control inside keeps the focus and
/// the ring, and this only watches whether the focus is somewhere below.
final class TvFocusScale extends ConsumerStatefulWidget {
  /// Grows the focused [child].
  const TvFocusScale({required this.child, super.key});

  /// The focus target and its content.
  final Widget child;

  @override
  ConsumerState<TvFocusScale> createState() => _TvFocusScaleState();
}

final class _TvFocusScaleState extends ConsumerState<TvFocusScale> {
  late final FocusNode _node = FocusNode(
    debugLabel: 'tv focus zoom',
    canRequestFocus: false,
    skipTraversal: true,
  );
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    _node.addListener(_onFocus);
  }

  @override
  void dispose() {
    _node
      ..removeListener(_onFocus)
      ..dispose();
    super.dispose();
  }

  void _onFocus() {
    if (!mounted || _focused == _node.hasFocus) return;
    setState(() => _focused = _node.hasFocus);
  }

  @override
  Widget build(BuildContext context) {
    final tv = ref.watch(platformRuntimeProvider).environment.runtime.formFactor == FormFactor.tv;
    final grow = tv && ref.watch(tvFocusZoomProvider) && _focused;
    return Focus(
      focusNode: _node,
      canRequestFocus: false,
      skipTraversal: true,
      includeSemantics: false,
      child: AnimatedScale(
        scale: grow ? kTvFocusZoom : 1,
        duration: grow ? kTvFocusZoomDuration : Duration.zero,
        curve: Curves.easeOutCubic,
        child: widget.child,
      ),
    );
  }
}
