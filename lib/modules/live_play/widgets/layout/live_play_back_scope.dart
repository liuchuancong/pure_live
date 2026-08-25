import 'dart:async';

import 'package:flutter/widgets.dart';

/// Route-local system-back handling for a live room.
///
/// Normal rooms remain immediately poppable. Fullscreen and widescreen
/// presentations block exactly one route pop and restore the normal room
/// instead. Dialogs and bottom sheets stay above this scope, so Navigator
/// closes them before this callback is considered.
class LivePlayBackScope extends StatelessWidget {
  const LivePlayBackScope({
    super.key,
    required this.presentationActive,
    required this.onExitPresentation,
    required this.child,
  });

  final bool presentationActive;
  final FutureOr<void> Function() onExitPresentation;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return PopScope<Object?>(
      canPop: !presentationActive,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && presentationActive) {
          unawaited(Future<void>.sync(onExitPresentation));
        }
      },
      child: child,
    );
  }
}
