import 'package:flutter/material.dart';
import 'package:pure_uikit/pure_uikit.dart';

/// The PureLive lockup at the head of the desktop / tablet navigation.
///
/// The same widget serves the 260px drawer and the 88px rail: below a narrow
/// threshold it becomes the mark alone so a narrow column never clips the
/// wordmark. The parent's width is the whole input — no route or platform
/// check is needed.
class MainSidebarBrand extends StatelessWidget {
  /// A brand lockup; [onTap] returns to the first branch.
  const new({this.onTap, super.key});

  /// The optional home action.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = PureTheme.of(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 148;
        final content = compact
            ? const Center(child: _BrandMark(size: 32))
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const _BrandMark(size: 32),
                  const SizedBox(width: PureSpacing.md),
                  Flexible(
                    child: Text(
                      'PureLive',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.text.headline.copyWith(
                        fontSize: 19,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.4,
                        color: theme.colors.text,
                      ),
                    ),
                  ),
                ],
              );

        return Semantics(
          label: 'PureLive',
          button: onTap != null,
          child: PureBox(
            style: (state) => Style(
              padding: EdgeInsets.symmetric(
                horizontal: compact ? 0 : PureSpacing.sm,
                vertical: compact ? 0 : PureSpacing.sm,
              ),
              borderRadius: BorderRadius.circular(theme.card.borderRadius),
              background: onTap != null && state == InteractionState.hovered ? theme.colors.fillQuaternary : null,
            ),
            onTap: onTap,
            child: content,
          ),
        );
      },
    );
  }
}

class _BrandMark extends StatelessWidget {
  const new({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF19A0FF), Color(0xFF0B6FDB)],
        ),
        borderRadius: BorderRadius.circular(size * 0.3),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0B6FDB).withValues(alpha: 0.24),
            blurRadius: size * 0.34,
            offset: Offset(0, size * 0.12),
          ),
        ],
      ),
      child: Center(
        child: Padding(
          padding: EdgeInsets.only(left: size * 0.06),
          child: Icon(Icons.play_arrow_rounded, size: size * 0.64, color: Colors.white),
        ),
      ),
    );
  }
}
