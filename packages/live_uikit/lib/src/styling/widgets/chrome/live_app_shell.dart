import 'package:flutter/material.dart';

import 'package:live_uikit/src/scales/sizing.dart';
import 'package:live_uikit/src/styling/contracts/live_ui_adapter.dart';
import 'package:live_uikit/src/styling/provider/live_config_provider.dart';
import 'package:live_uikit/src/styling/style/style.dart';
import 'package:live_uikit/src/styling/widgets/chrome/live_nav_bar.dart';
import 'package:live_uikit/src/styling/widgets/layout/live_box.dart';
import 'package:live_uikit/src/styling/widgets/layout/live_environment.dart';

/// The token-driven application shell: a navigation column when the window has
/// room for one, a strip under the content when it does not, and the page in the
/// remaining space (§ surfaces — the fallback every language gets before it owns
/// a shell of its own).
///
/// It draws neither a Material `Scaffold` nor an `AppBar`: the frame belongs to
/// the language's `scaffold` and the bar to its `appBar`, so a shell that also
/// reached for Material's frame would put every language's navigation inside a
/// Material page no matter which adapter was active.
///
/// The strip form is delegated back through the adapter's `navBar`, so a language
/// that owns a bottom bar but not a shell still draws its own bar here. A
/// destination marked disabled is refused by the shell itself rather than passed
/// on as something the library would have to invent a look for.
class TokenAppShell extends StatelessWidget {
  /// A token shell built from [spec].
  const new({required this.spec, super.key});

  /// The shell configuration.
  final LanguageShellSpec spec;

  @override
  Widget build(BuildContext context) {
    final theme = LiveTheme.of(context);
    final geometry = LiveEnvironmentScope.maybeOf(context)?.geometry;
    if (spec.placement == LiveShellPlacement.none || spec.destinations.length < 2) {
      // One destination is not a navigation choice, and a shell asked for none:
      // in both cases the frame is the page's own, and the shell stands aside.
      return spec.child;
    }

    final rail = switch (spec.placement) {
      LiveShellPlacement.rail => true,
      LiveShellPlacement.bottom || LiveShellPlacement.none => false,
      LiveShellPlacement.adaptive => (geometry?.railWidth ?? LiveSizing.railWidth) > 0,
    };

    if (rail) {
      return Row(
        children: [
          _ShellRail(
            destinations: spec.destinations,
            selectedId: spec.selectedId,
            width: geometry?.railWidth ?? LiveSizing.railWidth,
            iconSize: geometry?.iconSize ?? 18,
            onSelected: _report,
            trailing: spec.trailing,
          ),
          Expanded(child: spec.child),
        ],
      );
    }

    return Column(
      children: [
        Expanded(child: spec.child),
        theme.adapter.navBar(
          context,
          LanguageNavBarSpec(
            items: [
              for (final destination in spec.destinations)
                LiveNavBarItem(label: destination.label, icon: destination.icon),
            ],
            index: spec.destinations.indexWhere((destination) => destination.id == spec.selectedId),
            onChanged: (index) {
              final destination = spec.destinations[index];
              if (destination.enabled) {
                _report(destination.id);
              }
            },
          ),
        ),
      ],
    );
  }

  void _report(String id) {
    spec.onSelected?.call(id);
  }
}

class _ShellRail extends StatelessWidget {
  const new({
    required this.destinations,
    required this.selectedId,
    required this.width,
    required this.iconSize,
    required this.onSelected,
    this.trailing,
  });

  final List<LiveShellDestination> destinations;
  final String? selectedId;
  final double width;
  final double iconSize;
  final ValueChanged<String> onSelected;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = LiveTheme.of(context);
    return SizedBox(
      width: width,
      child: ColoredBox(
        color: theme.colors.bgElevated,
        child: Column(
          children: [
            for (final destination in destinations)
              _RailCell(
                destination: destination,
                selected: destination.id == selectedId,
                iconSize: iconSize,
                onSelected: onSelected,
              ),
            if (trailing != null) ...[const Spacer(), Align(alignment: Alignment.bottomCenter, child: trailing)],
          ],
        ),
      ),
    );
  }
}

class _RailCell extends StatelessWidget {
  const new({required this.destination, required this.selected, required this.iconSize, required this.onSelected});

  final LiveShellDestination destination;
  final bool selected;
  final double iconSize;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final theme = LiveTheme.of(context);
    final enabled = destination.enabled;
    final tint = !enabled
        ? theme.colors.textDisabled
        : selected
        ? theme.colors.primary
        : theme.colors.textSecondary;
    final gap = theme.token.scale.sizes.xxs;

    return Semantics(
      selected: selected,
      child: LiveBox(
        style: (state) => Style(
          background: enabled && (state == InteractionState.hovered || state == InteractionState.pressed)
              ? theme.colors.fillTertiary
              : null,
          foreground: tint,
          alignment: Alignment.center,
          padding: EdgeInsets.symmetric(vertical: theme.token.scale.sizes.xs),
        ),
        enabled: enabled,
        onTap: enabled ? () => onSelected(destination.id) : null,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(destination.icon, size: iconSize, color: tint),
            SizedBox(height: gap),
            Text(
              destination.label,
              style: theme.text.caption.copyWith(color: tint),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

/// The public application shell: a thin dispatcher to the active language
/// adapter, the same way the page frame and the bar are dispatched.
///
/// It sits between the host and the page — the routing layer's `ShellRoute` in an
/// app — and takes only neutral data: the destinations, the selected id, the
/// callback and the body. A language whose library ships a structural navigation
/// widget draws it; the rest get [TokenAppShell].
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
