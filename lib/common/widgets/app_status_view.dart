import 'package:flutter/material.dart';

enum AppStatusType { loading, empty, error }

class AppStatusView extends StatefulWidget {
  final AppStatusType type;
  final String title;
  final String subtitle;
  final IconData? icon;
  final String? buttonText;
  final VoidCallback? onButtonPressed;

  const AppStatusView({
    super.key,
    required this.type,
    required this.title,
    required this.subtitle,
    this.icon,
    this.buttonText,
    this.onButtonPressed,
  });

  @override
  State<AppStatusView> createState() => _AppStatusViewState();
}

class _AppStatusViewState extends State<AppStatusView> with SingleTickerProviderStateMixin {
  late AnimationController _rotateController;

  @override
  void initState() {
    super.initState();
    _rotateController = AnimationController(duration: const Duration(milliseconds: 1000), vsync: this);
    if (widget.type == AppStatusType.loading) {
      _rotateController.repeat();
    }
  }

  @override
  void didUpdateWidget(AppStatusView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.type == AppStatusType.loading && !_rotateController.isAnimating) {
      _rotateController.repeat();
    } else if (widget.type != AppStatusType.loading && _rotateController.isAnimating) {
      _rotateController.stop();
    }
  }

  @override
  void dispose() {
    _rotateController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (widget.type == AppStatusType.loading) {
      return Center(
        child: RotationTransition(
          turns: _rotateController,
          child: ShaderMask(
            shaderCallback: (rect) {
              return SweepGradient(
                startAngle: 0.0,
                endAngle: 3.14 * 2,
                colors: [theme.colorScheme.primary, theme.colorScheme.primary.withValues(alpha: 0.1)],
                stops: const [0.0, 0.85],
              ).createShader(rect);
            },
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(width: 3.5, color: Colors.white),
              ),
            ),
          ),
        ),
      );
    }

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.0, end: 1.0),
            duration: const Duration(milliseconds: 1000),
            curve: Curves.elasticOut,
            builder: (context, value, child) {
              return Transform.scale(scale: value, child: child);
            },
            child: Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.15),
                shape: BoxShape.circle,
                border: Border.all(color: theme.colorScheme.primary.withValues(alpha: 0.05), width: 1),
              ),
              child: Icon(
                widget.icon ?? (widget.type == AppStatusType.error ? Icons.wifi_off_rounded : Icons.live_tv_rounded),
                size: 42,
                color: theme.colorScheme.primary.withValues(alpha: 0.6),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            widget.title,
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: theme.textTheme.titleMedium?.color),
          ),
          const SizedBox(height: 6),
          Text(widget.subtitle, style: TextStyle(fontSize: 13, color: theme.hintColor)),
          if (widget.buttonText != null && widget.onButtonPressed != null) ...[
            const SizedBox(height: 16),
            TextButton.icon(
              onPressed: widget.onButtonPressed,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: Text(widget.buttonText!),
            ),
          ],
        ],
      ),
    );
  }
}
