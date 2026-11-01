/// Immutable description of a page background.
///
/// `BackgroundConfig` is a sealed union; every legal variant lives in this
/// library (this file plus the `part` files under `background_config/` and
/// `background_layer/`), so callers can never construct an "image with no
/// source" or a "video with no media". Use pattern matching (`switch` on
/// the sealed type) in the rendering layer to make the compiler enforce
/// exhaustiveness.
///
/// An [BackgroundOverlay] value object hangs off every variant so a scrim
/// is a first-class part of the description rather than an afterthought
/// painted by each page.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart' show AlignmentGeometry, ImageProvider;
import 'package:flutter/widgets.dart' show Alignment, BlendMode, BoxFit, Color;
import 'package:live_uikit_background/src/contracts/background_video_source.dart';

part 'background_overlay.dart';
part 'image_source.dart';
part 'solid_background.dart';
part 'gradient_background.dart';
part 'image_background.dart';
part 'video_background.dart';
part '../background_layer/background_layer.dart';
part '../background_layer/background_layer_stack.dart';

/// A stable, immutable description of what to paint behind a subtree.
@immutable
sealed class BackgroundConfig {
  /// Creates a background configuration.
  const new({this.overlay});

  /// Optional scrim painted over the base fill to protect foreground
  /// contrast. When `null`, no scrim is applied.
  final BackgroundOverlay? overlay;
}
