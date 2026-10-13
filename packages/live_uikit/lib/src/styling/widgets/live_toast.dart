import 'dart:async';

import 'package:flutter/material.dart';

import 'package:live_uikit/src/styling/root/live_config_provider.dart';

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

/// Shows a brief, self-dismissing message at the top of the screen — Ant's
/// `message`. The pill surface, the status colour and the text all come from the
/// active theme, so toasts match the rest of the UI. Fire-and-forget; a timer
/// removes the overlay entry after [duration].
void styledToast(
  BuildContext context,
  String message, {
  LiveToastType type = LiveToastType.info,
  Duration duration = const Duration(milliseconds: 2200),
}) {
  final theme = LiveTheme.of(context);
  final overlay = Overlay.maybeOf(context, rootOverlay: true);
  if (overlay == null) {
    return;
  }
  final color = switch (type) {
    LiveToastType.info => theme.colors.info,
    LiveToastType.success => theme.colors.success,
    LiveToastType.warning => theme.colors.warning,
    LiveToastType.error => theme.colors.error,
  };
  final icon = switch (type) {
    LiveToastType.info => Icons.info_outline,
    LiveToastType.success => Icons.check_circle_outline,
    LiveToastType.warning => Icons.warning_amber_rounded,
    LiveToastType.error => Icons.error_outline,
  };

  late final OverlayEntry entry;
  entry = OverlayEntry(
    builder: (_) => _Toast(
      icon: icon,
      accent: color,
      message: message,
      theme: theme,
      lifetime: duration,
      onFinished: () => entry.remove(),
    ),
  );
  overlay.insert(entry);
}

class _Toast extends StatefulWidget {
  const new({
    required this.icon,
    required this.accent,
    required this.message,
    required this.theme,
    required this.lifetime,
    required this.onFinished,
  });

  final IconData icon;
  final Color accent;
  final String message;
  final LiveTheme theme;
  final Duration lifetime;
  final VoidCallback onFinished;

  @override
  State<_Toast> createState() => _ToastState();
}

class _ToastState extends State<_Toast> with SingleTickerProviderStateMixin {
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
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: theme.token.scale.sizes.md,
                    vertical: theme.token.scale.sizes.sm,
                  ),
                  decoration: BoxDecoration(
                    color: theme.colors.bgElevated,
                    borderRadius: BorderRadius.circular(theme.card.borderRadius),
                    boxShadow: theme.token.motion.boxShadow,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(widget.icon, size: theme.text.body.fontSize, color: widget.accent),
                      SizedBox(width: theme.token.scale.sizes.sm),
                      Text(widget.message, style: theme.text.body.copyWith(color: theme.colors.text)),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
