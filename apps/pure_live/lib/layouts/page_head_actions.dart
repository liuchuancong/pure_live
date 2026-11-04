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
void publishPageHeadActions(BuildContext context, WidgetRef ref, List<Widget> actions) {
  final owner = PageOwnerScope.ownerOf(context);
  if (owner == null) return;
  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (!context.mounted) return;
    ref.read(pageHeadActionsProvider.notifier).publish(owner, actions);
  });
}

/// Names the destination the page below belongs to, so a page's published
/// verbs are only shown while that page is the one on screen.
final class PageOwnerScope extends InheritedWidget {
  /// Publishes [owner] to the page below.
  const PageOwnerScope({required this.owner, required super.child, super.key});

  /// The destination on screen.
  final NavigationItem owner;

  /// The destination [context]'s page belongs to, or null outside the shell.
  static NavigationItem? ownerOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<PageOwnerScope>()?.owner;

  @override
  bool updateShouldNotify(PageOwnerScope oldWidget) => oldWidget.owner != owner;
}
