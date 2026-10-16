import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:live_uikit/src/styling/provider/live_config_provider.dart';
import 'package:live_uikit/src/styling/tokens/design_token.dart' show ColorTokens;

/// A hover/focus tooltip — Ant's `Tooltip`. On pointer enter or keyboard focus
/// it shows a spotlight bubble above the [child] after a short delay; the
/// bubble's surface and text use [ColorTokens.bgSpotlight] and
/// [ColorTokens.textLightSolid], so it matches the active theme.
class LiveTooltip extends StatefulWidget {
  /// A tooltip around [child].
  const new({
    required this.message,
    required this.child,
    this.waitDuration = const Duration(milliseconds: 400),
    super.key,
  });

  /// The text to reveal.
  final String message;

  /// The hovered widget.
  final Widget child;

  /// How long the pointer must rest before the bubble appears.
  final Duration waitDuration;

  @override
  State<LiveTooltip> createState() => _LiveTooltipState();
}

class _LiveTooltipState extends State<LiveTooltip> {
  final LayerLink _link = LayerLink();
  OverlayEntry? _entry;
  Timer? _timer;

  void _show() {
    if (_entry != null) {
      return;
    }
    final theme = LiveTheme.of(context);
    _entry = OverlayEntry(
      builder: (_) => _Bubble(link: _link, theme: theme, message: widget.message),
    );
    Overlay.of(context).insert(_entry!);
  }

  void _hide() {
    _timer?.cancel();
    _timer = null;
    _entry?.remove();
    _entry = null;
  }

  void _scheduleShow() {
    _timer?.cancel();
    _timer = Timer(widget.waitDuration, _show);
  }

  @override
  void dispose() {
    _hide();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => _scheduleShow(),
      onExit: (_) => _hide(),
      child: Focus(
        onFocusChange: (focused) => focused ? _show() : _hide(),
        child: CompositedTransformTarget(link: _link, child: widget.child),
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const new({required this.link, required this.theme, required this.message});

  final LayerLink link;
  final LiveTheme theme;
  final String message;

  @override
  Widget build(BuildContext context) {
    return CompositedTransformFollower(
      link: link,
      showWhenUnlinked: false,
      targetAnchor: Alignment.topCenter,
      followerAnchor: Alignment.bottomCenter,
      offset: Offset(0, -theme.token.scale.sizes.sm),
      child: IgnorePointer(
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: theme.token.scale.sizes.sm, vertical: theme.token.scale.sizes.xs),
          decoration: BoxDecoration(
            color: theme.colors.bgSpotlight,
            borderRadius: BorderRadius.circular(theme.token.scale.radii.sm),
            boxShadow: theme.token.motion.boxShadowTertiary,
          ),
          child: Text(message, style: theme.text.bodySmall.copyWith(color: theme.colors.textLightSolid)),
        ),
      ),
    );
  }
}
