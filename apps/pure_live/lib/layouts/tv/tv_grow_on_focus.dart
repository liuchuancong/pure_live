import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_platform/live_platform.dart' show FormFactor;

import 'package:pure_live/app/app.dart';
import 'package:pure_live/shared/focus/tv_focus_style.dart';

/// Grows [child] by [kTvFocusScale] while a control inside it holds focus,
/// on a TV build.
///
/// The wrapper is not a focus stop: the pressable inside keeps the focus,
/// the ring and the activation (every DsPressable answers the select key),
/// and this only watches whether the focus is somewhere below. It exists
/// because the app's cards and rows are DsPressable-based content that
/// cannot carry [TvFocusable]'s own-focus effects — a stop would steal the
/// focus from the pressable and double-fire every tap.
///
/// Arriving animates over [kTvFocusIn]; losing focus snaps, so a held arrow
/// never leaves a trail of half-grown items.
final class TvGrowOnFocus extends ConsumerStatefulWidget {
  /// Grows the focused [child].
  const TvGrowOnFocus({required this.child, this.scale = kTvFocusScale, super.key});

  /// The focus target and its content.
  final Widget child;

  /// How far focus grows; 1.0 for content that fills its row.
  final double scale;

  @override
  ConsumerState<TvGrowOnFocus> createState() => _TvGrowOnFocusState();
}

final class _TvGrowOnFocusState extends ConsumerState<TvGrowOnFocus> {
  late final FocusNode _node = FocusNode(canRequestFocus: false, skipTraversal: true);
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
    if (!tv) return widget.child;
    return Focus(
      focusNode: _node,
      canRequestFocus: false,
      skipTraversal: true,
      child: AnimatedScale(
        scale: _focused ? widget.scale : 1.0,
        duration: tvFocusDuration(entered: _focused),
        curve: kTvFocusCurve,
        child: widget.child,
      ),
    );
  }
}
