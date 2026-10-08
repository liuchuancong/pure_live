import 'package:flutter/widgets.dart';
import 'package:pure_live/core/widgets/pure_live_scroll_physics.dart';

/// A modal sheet body that keeps its content's height, and starts scrolling
/// only when the sheet cannot fit all of it.
///
/// `showModalBottomSheet` hands its builder loose constraints capped at 90% of
/// the viewport, and a scroll view sizes itself to the child under those
/// constraints - so this stays as short as the cards it holds, yet scrolls
/// instead of overflowing once they need more than the sheet can give. The
/// recorder's ⋮ sheet on a short phone window ran 44 pixels past the bottom and
/// painted the last row into the striped overflow gutter.
class FittingSheetBody extends StatelessWidget {
  const FittingSheetBody({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const PureLiveScrollPhysics(),
      child: Column(mainAxisSize: MainAxisSize.min, children: children),
    );
  }
}
