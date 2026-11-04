import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pure_live/shared/shared.dart' show NavigationItem;

/// Verbs a page hands to the shell's head line when its own width stacks the
/// toolbar: the refresh, the filter, the more menu — whatever the page would
/// otherwise draw in its own row.
typedef PageHeadActions = ({NavigationItem owner, List<Widget> actions});

/// The slot the current page publishes its head verbs into.
///
/// The page keeps the widgets (and with them its own state and callbacks); the
/// shell only decides where they are drawn. The owner keeps one page's verbs
/// from lingering over another page.
final class PageHeadActionsController extends Notifier<PageHeadActions?> {
  @override
  PageHeadActions? build() => null;

  /// Publishes [actions] for [owner]; the shell shows them only while that
  /// page is on screen.
  void publish(NavigationItem owner, List<Widget> actions) => state = (owner: owner, actions: actions);
}

/// The page's head verbs, as the shell shows them.
final pageHeadActionsProvider = NotifierProvider<PageHeadActionsController, PageHeadActions?>(
  PageHeadActionsController.new,
);

/// Publishes the page's narrow-mode verbs after the frame: a provider write
/// during build is rejected, and the page republishes on every rebuild, so a
/// one-frame delay is invisible.
///
/// [owner] is the page's own destination — not the shell's current selection:
/// the router keeps every branch mounted, and an off-screen page that
/// republishes its verbs must still name itself, so the shell can hide them.
void publishPageHeadActions(BuildContext context, WidgetRef ref, NavigationItem owner, List<Widget> actions) {
  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (!context.mounted) return;
    ref.read(pageHeadActionsProvider.notifier).publish(owner, actions);
  });
}
