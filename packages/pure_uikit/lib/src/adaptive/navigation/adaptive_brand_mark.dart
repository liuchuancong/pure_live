import 'package:flutter/material.dart';
import 'package:pure_uikit/src/adaptive/adaptive_surface_tokens.dart';


/// The plain accent mark shown when a navigation surface needs a brand and
/// the app handed none in. Apps normally pass their own lockup via the
/// `brand` slot; this keeps the surfaces presentable without one.
class AdaptiveBrandMark extends StatelessWidget {
  /// A mark [size] logical pixels square.
  const new({this.onTap, this.size = 30, super.key});

  /// The mark's tap handler (usually "go home").
  final VoidCallback? onTap;

  /// The mark's edge length.
  final double size;

  @override
  Widget build(BuildContext context) {
    final colors = AdaptiveSurfaceColors.of(context);
    final Widget mark = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: colors.brand,
        borderRadius: BorderRadius.circular(size * 0.28),
      ),
      child: Center(
        child: Padding(
          padding: EdgeInsets.only(left: size * 0.06),
          child: Icon(Icons.play_arrow_rounded, color: colors.onBrand, size: size * 0.62),
        ),
      ),
    );
    if (onTap == null) {
      return mark;
    }
    return IconButton(tooltip: 'PureLive', onPressed: onTap, icon: mark);
  }
}
