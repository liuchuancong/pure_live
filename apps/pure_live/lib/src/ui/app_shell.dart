import 'package:flutter/material.dart';
import 'package:live_uikit/live_uikit.dart';

import 'package:pure_live/src/services.dart';

/// One entry of the shell's navigation.
class AppDestination {
  /// A destination.
  const new({required this.id, required this.label, required this.icon, required this.pageBuilder, this.selectedIcon});

  /// The stable id, used as the route name and the focus-memory key.
  final String id;

  /// The label under the icon.
  final String label;

  /// The icon in its resting state.
  final IconData icon;

  /// The icon in its selected state.
  final IconData? selectedIcon;

  /// Builds the page.
  final WidgetBuilder pageBuilder;
}

/// The application shell: navigation on the outside, one page at a time on the
/// inside, and the focus plumbing a remote control needs.
///
/// The shape follows the layout mode rather than the platform: a bottom bar
/// with one page (mobile), a rail beside the content (desktop), and a
/// focus-driven top bar over a single full-bleed page (TV). The pages
/// themselves are identical in all three — only the chrome moves — which is
/// what keeps a feature from existing in two versions.
///
/// It also owns the two pieces of TV plumbing that must wrap *every* page:
/// the focus restorer (so stepping back into a page lands on the item the user
/// left) and the remote input scope (so the actions a page declares reach it
/// from the shell's level too).
class AppShell extends StatefulWidget {
  /// A shell over [destinations].
  const new({required this.services, required this.theme, required this.destinations, super.key});

  /// The service graph, handed to the pages that need it.
  final PureLiveServices services;

  /// The resolved theme, used for the shell's own chrome.
  final LiveTheme theme;

  /// The destinations, in display order.
  final List<AppDestination> destinations;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  final List<FocusNode> _destinationFocus = [];
  int _selected = 0;

  @override
  void initState() {
    super.initState();
    for (final _ in widget.destinations) {
      _destinationFocus.add(FocusNode(debugLabel: 'shell destination'));
    }
  }

  @override
  void dispose() {
    for (final node in _destinationFocus) {
      node.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final environment = LiveEnvironmentScope.of(context);
    final navigation = environment.layoutMode == LiveLayoutMode.tv
        ? _TvNavigation(
            destinations: widget.destinations,
            selected: _selected,
            focusNodes: _destinationFocus,
            onSelected: _select,
          )
        : null;
    final content = KeyedSubtree(
      key: ValueKey(widget.destinations[_selected].id),
      child: Builder(builder: widget.destinations[_selected].pageBuilder),
    );
    return LiveRemoteInput(
      // The menu key opens the settings destination, wherever the user is:
      // on a remote there is no pointer to find the gear icon with.
      onMenu: (_) {
        _select(widget.destinations.indexWhere((d) => d.id == 'settings'));
        return true;
      },
      child: LiveFocusRestorer(
        child: switch (environment.layoutMode) {
          LiveLayoutMode.mobile => _MobileFrame(
            destinations: widget.destinations,
            selected: _selected,
            focusNodes: _destinationFocus,
            onSelected: _select,
            child: content,
          ),
          LiveLayoutMode.desktop => _DesktopFrame(
            destinations: widget.destinations,
            selected: _selected,
            focusNodes: _destinationFocus,
            onSelected: _select,
            child: content,
          ),
          LiveLayoutMode.tv => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ?navigation,
              Expanded(child: content),
            ],
          ),
        },
      ),
    );
  }

  void _select(int index) {
    if (index < 0 || index >= widget.destinations.length || index == _selected) {
      return;
    }
    setState(() => _selected = index);
  }
}

/// The mobile frame: content above a bottom bar.
class _MobileFrame extends StatelessWidget {
  const new({
    required this.destinations,
    required this.selected,
    required this.focusNodes,
    required this.onSelected,
    required this.child,
  });

  final List<AppDestination> destinations;
  final int selected;
  final List<FocusNode> focusNodes;
  final ValueChanged<int> onSelected;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = LiveTheme.of(context);
    return Column(
      children: [
        Expanded(child: child),
        Material(
          color: theme.colors.surfaceElevated,
          child: SafeArea(
            top: false,
            child: SizedBox(
              height: LiveSizing.navBarHeight,
              child: Row(
                children: [
                  for (var index = 0; index < destinations.length; index++)
                    Expanded(
                      child: _DestinationTab(
                        destination: destinations[index],
                        selected: index == selected,
                        focusNode: focusNodes[index],
                        onTap: () => onSelected(index),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// The desktop frame: content beside a rail.
class _DesktopFrame extends StatelessWidget {
  const new({
    required this.destinations,
    required this.selected,
    required this.focusNodes,
    required this.onSelected,
    required this.child,
  });

  final List<AppDestination> destinations;
  final int selected;
  final List<FocusNode> focusNodes;
  final ValueChanged<int> onSelected;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = LiveTheme.of(context);
    return Row(
      children: [
        Material(
          color: theme.colors.surfaceElevated,
          child: SizedBox(
            width: LiveSizing.railWidth,
            child: Column(
              children: [
                const SizedBox(height: LiveSpacing.sm),
                for (var index = 0; index < destinations.length; index++)
                  _DestinationTab(
                    destination: destinations[index],
                    selected: index == selected,
                    focusNode: focusNodes[index],
                    onTap: () => onSelected(index),
                    vertical: true,
                  ),
              ],
            ),
          ),
        ),
        Expanded(child: child),
      ],
    );
  }
}

/// One navigation entry, in either frame.
class _DestinationTab extends StatelessWidget {
  const new({
    required this.destination,
    required this.selected,
    required this.focusNode,
    required this.onTap,
    this.vertical = false,
  });

  final AppDestination destination;
  final bool selected;
  final FocusNode focusNode;
  final VoidCallback onTap;
  final bool vertical;

  @override
  Widget build(BuildContext context) {
    final theme = LiveTheme.of(context);
    final color = selected ? theme.colors.primary : theme.colors.textSecondary;
    final icon = Icon(
      selected ? (destination.selectedIcon ?? destination.icon) : destination.icon,
      size: theme.componentTheme.iconSize,
      color: color,
    );
    final label = Text(
      destination.label,
      style: theme.typography.caption.copyWith(color: color),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
    return LiveFocusHighlight(
      focusNode: focusNode,
      radius: theme.componentTheme.controlRadius,
      scale: 1,
      childBuilder: (context, node) => Semantics(
        button: true,
        selected: selected,
        label: destination.label,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: Focus(
            focusNode: node,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: LiveSpacing.sm, horizontal: LiveSpacing.xs),
              child: vertical
                  ? Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        icon,
                        const SizedBox(height: LiveSpacing.xxs),
                        label,
                      ],
                    )
                  : Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        icon,
                        const SizedBox(height: LiveSpacing.xxs),
                        label,
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The TV's top navigation: a focusable row of destinations.
class _TvNavigation extends StatelessWidget {
  const new({required this.destinations, required this.selected, required this.focusNodes, required this.onSelected});

  final List<AppDestination> destinations;
  final int selected;
  final List<FocusNode> focusNodes;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final theme = LiveTheme.of(context);
    final geometry = theme.componentTheme;
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: geometry.pagePaddingWide.horizontal / 2, vertical: geometry.iconGap),
      child: Row(
        children: [
          for (var index = 0; index < destinations.length; index++)
            Padding(
              padding: EdgeInsets.only(right: geometry.iconGap),
              child: LiveButton(
                label: destinations[index].label,
                icon: index == selected
                    ? (destinations[index].selectedIcon ?? destinations[index].icon)
                    : destinations[index].icon,
                variant: index == selected ? LiveButtonVariant.primary : LiveButtonVariant.text,
                size: LiveControlSize.large,
                focusNode: focusNodes[index],
                onPressed: () => onSelected(index),
              ),
            ),
        ],
      ),
    );
  }
}
