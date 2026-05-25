import 'package:flutter/material.dart';
import 'package:pure_live/common/style/app_text_styles.dart';

enum AppStatusType { loading, empty, error }

class AppStatusView extends StatefulWidget {
  final AppStatusType type;
  final String title;
  final String subtitle;
  final IconData? icon;
  final String? buttonText;
  final VoidCallback? onButtonPressed;
  final bool isMini;
  final Color? iconColor;
  final Color? titleColor;
  final Color? subtitleColor;

  const AppStatusView({
    super.key,
    required this.type,
    required this.title,
    required this.subtitle,
    this.icon,
    this.buttonText,
    this.onButtonPressed,
    this.isMini = false,
    this.iconColor,
    this.titleColor,
    this.subtitleColor,
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
    final effectiveIconColor = widget.iconColor ?? theme.colorScheme.primary;

    if (widget.type == AppStatusType.loading) {
      return Center(
        child: RotationTransition(
          turns: _rotateController,
          child: ShaderMask(
            shaderCallback: (rect) {
              return SweepGradient(
                startAngle: 0.0,
                endAngle: 3.14 * 2,
                colors: [effectiveIconColor, effectiveIconColor.withValues(alpha: 0.1)],
                stops: const [0.0, 0.85],
              ).createShader(rect);
            },
            child: Container(
              width: widget.isMini ? 20 : 44,
              height: widget.isMini ? 20 : 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(width: widget.isMini ? 2.0 : 3.5, color: Colors.white),
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
              padding: EdgeInsets.all(widget.isMini ? 8 : 22),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.15),
                shape: BoxShape.circle,
                border: Border.all(color: effectiveIconColor.withValues(alpha: 0.05), width: 1),
              ),
              child: Icon(
                widget.icon ?? (widget.type == AppStatusType.error ? Icons.wifi_off_rounded : Icons.live_tv_rounded),
                size: widget.isMini ? 16 : 42,
                color: widget.iconColor ?? theme.colorScheme.primary.withValues(alpha: 0.6),
              ),
            ),
          ),
          if (!widget.isMini || widget.title.isNotEmpty) ...[
            const SizedBox(height: 20),
            Text(
              widget.title,
              style: AppTextStyles.t15.copyWith(
                fontWeight: FontWeight.w600,
                color: widget.titleColor ?? theme.textTheme.titleMedium?.color,
              ),
            ),
          ],
          if (!widget.isMini || widget.subtitle.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(widget.subtitle, style: AppTextStyles.t13.copyWith(color: widget.subtitleColor ?? theme.hintColor)),
          ],
          if (!widget.isMini && widget.buttonText != null && widget.onButtonPressed != null) ...[
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
