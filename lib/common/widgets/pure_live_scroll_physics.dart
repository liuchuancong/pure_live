import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// Uses the native touch model instead of forcing the iOS spring model on
/// Android and desktop lists.
class PureLiveScrollPhysics extends ScrollPhysics {
  const PureLiveScrollPhysics({super.parent});

  @override
  ScrollPhysics applyTo(ScrollPhysics? ancestor) {
    final resolvedParent = buildParent(ancestor);
    return switch (defaultTargetPlatform) {
      TargetPlatform.iOS || TargetPlatform.macOS => BouncingScrollPhysics(parent: resolvedParent),
      _ => ClampingScrollPhysics(parent: resolvedParent),
    };
  }
}
