import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:pure_live/app/providers/display_refresh_rate_provider.dart';

/// Feeds pointer, scroll and lifecycle signals into the display-rate policy.
///
/// The reference keeps Android's balanced mode high only during a burst of
/// interaction and releases it after the last movement; performance holds
/// while foregrounded and releases in the background. This widget is the only
/// piece that needs a widget tree, so the policy stays in
/// [DisplayRefreshRateController] and every platform call stays in
/// live_device.
final class RefreshRateInteractionScope extends ConsumerStatefulWidget {
  /// Creates the scope around the app content.
  const RefreshRateInteractionScope({required this.child, super.key});

  /// The content whose pointer and scroll activity drives the policy.
  final Widget child;

  @override
  ConsumerState<RefreshRateInteractionScope> createState() => _RefreshRateInteractionScopeState();
}

final class _RefreshRateInteractionScopeState extends ConsumerState<RefreshRateInteractionScope>
    with WidgetsBindingObserver {
  late final DisplayRefreshRateController _controller;

  @override
  void initState() {
    super.initState();
    _controller = ref.read(displayRefreshRateProvider.notifier);
    WidgetsBinding.instance.addObserver(this);
    _controller.noteAppResumed();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Android PiP is visible while Flutter reports inactive; both still count
    // as foreground for the selected window policy.
    if (state == AppLifecycleState.resumed || state == AppLifecycleState.inactive) {
      _controller.noteAppResumed();
    } else {
      _controller.noteAppPaused();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    // The root going away releases the high-rate request; the provider also
    // cancels its settle timer when it is disposed.
    _controller.noteAppPaused();
    super.dispose();
  }

  bool _onScroll(ScrollNotification notification) {
    if (notification is ScrollStartNotification ||
        notification is ScrollUpdateNotification ||
        notification is OverscrollNotification) {
      _controller.keepInteraction();
    } else if (notification is ScrollEndNotification) {
      _controller.endInteraction();
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) => _controller.beginInteraction(),
      onPointerMove: (_) => _controller.keepInteraction(),
      onPointerUp: (_) => _controller.endInteraction(),
      onPointerCancel: (_) => _controller.endInteraction(),
      child: NotificationListener<ScrollNotification>(onNotification: _onScroll, child: widget.child),
    );
  }
}
