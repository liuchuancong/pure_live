import 'package:desen_ui/desen_ui.dart';
import 'package:flutter/widgets.dart';

import 'package:pure_live/shared/player/on_video_colors.dart' show OnVideoColors;

/// The control bar's chrome, the one Container every surface's bottom bar
/// hangs in: the deep shade it melts out of and the inset it keeps from the
/// picture's edges. A surface hands its row — and, where the bar carries
/// one, the seek line above it — as the child and keeps its own width
/// tiers; the chrome is the app's, not the page's.
final class PlayerControlBar extends StatelessWidget {
  /// The chrome around [child].
  const PlayerControlBar({required this.child, super.key, this.padding});

  /// The bar's inset. The default is the shape a bar with a seek line
  /// wears; a bar standing alone passes its own.
  final EdgeInsetsGeometry? padding;

  /// The bar's rows.
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
    padding: padding ?? const EdgeInsetsDirectional.fromSTEB(DsSpace.s12, DsSpace.s4, DsSpace.s12, DsSpace.s12),
    decoration: BoxDecoration(
      gradient: OnVideoColors.shade(edge: VerticalDirection.down, strong: OnVideoColors.scrimDeep),
    ),
    child: child,
  );
}
