import 'package:flutter/material.dart';

import 'package:live_uikit/src/styling/contracts/live_ui_adapter.dart';
import 'package:live_uikit/src/styling/provider/live_config_provider.dart';

/// The public application shell: a thin dispatcher to the active language
/// adapter, the same way the page frame and the bar are dispatched.
///
/// It sits between the host and the page — the routing layer's `ShellRoute` in an
/// app — and takes only neutral data: the destinations, the selected id, the
/// callback and the body. A language whose library ships a structural navigation
/// widget draws it; a language whose library ships none composes one out of its
/// own surfaces.
class LiveAppShell extends StatelessWidget {
  /// A shell around [child].
  const new({
    required this.child,
    this.destinations = const <LiveShellDestination>[],
    this.selectedId,
    this.onSelected,
    this.trailing,
    this.placement = LiveShellPlacement.adaptive,
    super.key,
  });

  /// The page content.
  final Widget child;

  /// The destinations, in order.
  final List<LiveShellDestination> destinations;

  /// The selected destination's id.
  final String? selectedId;

  /// Called with a destination's id.
  final ValueChanged<String>? onSelected;

  /// Content pinned at the end of a navigation column; see [LanguageShellSpec.trailing].
  final Widget? trailing;

  /// Where the caller wants the navigation.
  final LiveShellPlacement placement;

  @override
  Widget build(BuildContext context) => LiveTheme.of(context).adapter.shell(
    context,
    LanguageShellSpec(
      child: child,
      destinations: destinations,
      selectedId: selectedId,
      onSelected: onSelected,
      trailing: trailing,
      placement: placement,
    ),
  );
}
