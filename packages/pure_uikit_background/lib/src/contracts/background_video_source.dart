/// Contract the video rendering layer drives to obtain a background view.
///
/// The app implements this over media_core (or any other player kernel);
/// `pure_uikit_background` never sees the concrete controller. The widget
/// returned from [BackgroundVideoSource.buildView] owns its own decoder
/// lifecycle: it must release resources when the widget is disposed and
/// must pause without tearing the decoder down when `paused` flips to
/// `true`.
///
/// The returned widget is placed inside a tight parent box; it decides
/// how to honour the [BackgroundVideoSource.buildView] `fit` and
/// `alignment` hints given that it knows the decoded frame's intrinsic
/// size while this package does not.
library;

import 'package:flutter/painting.dart' show AlignmentGeometry;
import 'package:flutter/widgets.dart' show Alignment, BoxFit, Widget;

/// The seam between background rendering and a player kernel.
abstract interface class BackgroundVideoSource {
  /// Builds the video view.
  ///
  /// [paused] reflects app visibility; [looping] and [muted] come from
  /// the enclosing `VideoBackground` configuration. [fit] and
  /// [alignment] are hints taken from the same configuration so a real
  /// decoder can honour BoxFit/anchor with knowledge of the frame size.
  Widget buildView({
    required bool paused,
    required bool looping,
    required bool muted,
    BoxFit fit = BoxFit.cover,
    AlignmentGeometry alignment = Alignment.center,
  });
}
