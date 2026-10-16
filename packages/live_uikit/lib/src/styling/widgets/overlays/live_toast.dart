import 'dart:async';

import 'package:flutter/material.dart';

import 'package:live_uikit/src/styling/contracts/live_ui_adapter.dart';
import 'package:live_uikit/src/styling/provider/live_config_provider.dart';

/// The semantic kinds of a toast, mapped to the theme's status colours.
enum LiveToastType {
  /// Informational.
  info,

  /// Successful.
  success,

  /// Warning.
  warning,

  /// Error.
  error,
}

/// The token-driven toast surface: a pill on the elevated background, the
/// status colour on its glyph, the message in the body role.
///
/// It is the message's own body, not its placement — the overlay, the fade and
/// the timer stay in [LiveToast] because every language wants the same thing
/// there, and a library that wants a different one overrides this method whole.
class TokenToast extends StatelessWidget {
  /// A token pill built from [spec].
  const new({required this.spec, super.key});

  /// The toast configuration.
  final LanguageToastSpec spec;

  @override
  Widget build(BuildContext context) {
    final theme = LiveTheme.of(context);
    final accent = spec.accent ?? _accent(theme, spec.type);
    final icon = spec.icon ?? _icon(spec.type);

    return Container(
      padding: EdgeInsets.symmetric(horizontal: theme.token.scale.sizes.md, vertical: theme.token.scale.sizes.sm),
      decoration: BoxDecoration(
        color: theme.colors.bgElevated,
        borderRadius: BorderRadius.circular(theme.card.borderRadius),
        boxShadow: theme.token.motion.boxShadow,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: theme.text.body.fontSize, color: accent),
          SizedBox(width: theme.token.scale.sizes.sm),
          Flexible(
            child: Text(spec.message, style: theme.text.body.copyWith(color: theme.colors.text)),
          ),
        ],
      ),
    );
  }

  static Color _accent(LiveTheme theme, LiveToastType type) => switch (type) {
    LiveToastType.info => theme.colors.info,
    LiveToastType.success => theme.colors.success,
    LiveToastType.warning => theme.colors.warning,
    LiveToastType.error => theme.colors.error,
  };

  static IconData _icon(LiveToastType type) => switch (type) {
    LiveToastType.info => Icons.info_outline,
    LiveToastType.success => Icons.check_circle_outline,
    LiveToastType.warning => Icons.warning_amber_rounded,
    LiveToastType.error => Icons.error_outline,
  };
}

/// A brief, self-dismissing status message — Ant's `message`.
///
/// The placement, the fade-and-slide and the removal timer are the core's job;
/// what the active design language decides is the pill itself, through
/// [LanguageAdapter.toast]. Nothing here needs a `Scaffold`: the message goes to
/// the root [Overlay], so a toast fired from a route, a dialog or a second
/// desktop window still finds its way to the top of the screen.
abstract final class LiveToast {
  /// Shows [message] for [duration], then removes it.
  ///
  /// A context with no [Overlay] above it (a bare test harness, a window still
  /// building) is not an error worth crashing over: the call is dropped, since
  /// the message had nowhere to be drawn anyway.
  static void show(
    BuildContext context,
    String message, {
    LiveToastType type = LiveToastType.info,
    IconData? icon,
    Color? accent,
    Duration duration = const Duration(milliseconds: 2200),
  }) {
    final theme = LiveTheme.of(context);
    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) {
      return;
    }
    final spec = LanguageToastSpec(message: message, type: type, icon: icon, accent: accent, duration: duration);

    late final OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => _ToastOverlay(
        theme: theme,
        lifetime: duration,
        onFinished: () => entry.remove(),
        // Resolved inside the overlay's own context, so an inherited theme
        // change during the message's life does not leave it on the old skin.
        child: Builder(builder: (inner) => theme.adapter.toast(inner, spec)),
      ),
    );
    overlay.insert(entry);
  }
}

class _ToastOverlay extends StatefulWidget {
  const new({required this.theme, required this.lifetime, required this.onFinished, required this.child});

  final LiveTheme theme;
  final Duration lifetime;
  final VoidCallback onFinished;
  final Widget child;

  @override
  State<_ToastOverlay> createState() => _ToastOverlayState();
}

class _ToastOverlayState extends State<_ToastOverlay> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(vsync: this, duration: widget.theme.duration);
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _controller.forward();
    _timer = Timer(widget.lifetime, _dismiss);
  }

  Future<void> _dismiss() async {
    await _controller.reverse();
    widget.onFinished();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = widget.theme;
    return IgnorePointer(
      child: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: Padding(
            padding: EdgeInsets.only(top: theme.token.scale.sizes.lg),
            child: FadeTransition(
              opacity: _controller,
              child: SlideTransition(
                position: Tween<Offset>(begin: const Offset(0, -0.3), end: Offset.zero).animate(_controller),
                child: widget.child,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
