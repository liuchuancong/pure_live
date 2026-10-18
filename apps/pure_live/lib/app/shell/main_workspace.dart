import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:pure_live/app/routing/routes/multiview/multiview_routes.dart';
import 'package:pure_live/app/routing/routes/search/search_routes.dart';
import 'package:pure_live/app/routing/routes/settings/settings_routes.dart';
import 'package:pure_live/app/routing/routes/toolbox/toolbox_routes.dart';
import 'package:pure_live/app/shell/main_layout.dart';
import 'package:pure_live/l10n/generated/strings.g.dart';
import 'package:pure_uikit/pure_uikit.dart';

/// The width at which the shell paints a workspace toolbar above the page.
///
/// The threshold is the shared screenutil breakpoint (`md`, 768), so it agrees
/// with [PureAdaptiveLayout]'s rail/bottom choice rather than introducing a
/// second breakpoint.
const double mainWorkspaceMinWidth = 768;

/// Tells the pages below the shell whether the shell supplies a workspace
/// toolbar. A page that has it draws its own title strip inside the content;
/// a page without it keeps a real [PureAppBar], which also carries the menu
/// affordance on a phone.
class MainWorkspaceScope extends InheritedWidget {
  /// Publishes whether the workspace toolbar is present.
  const new({required this.hasChrome, required super.child, super.key});

  /// Whether the shell is painting [MainWorkspaceBar].
  final bool hasChrome;

  /// Reads the nearest scope; false when a page is mounted outside the shell.
  static bool hasChromeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<MainWorkspaceScope>()?.hasChrome ?? false;

  @override
  bool updateShouldNotify(MainWorkspaceScope oldWidget) => oldWidget.hasChrome != hasChrome;
}

/// Wraps a shell page in the optional workspace toolbar.
///
/// The phone and TV forms keep the page's own app bar; tablet and desktop get
/// one stable search/actions strip above every branch, matching the reference's
/// top bar while leaving page-level actions on the page.
class MainWorkspaceHost extends StatelessWidget {
  /// Wraps [child].
  const new({required this.child, super.key});

  /// The routed shell content.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final hasChrome = MediaQuery.sizeOf(context).width >= mainWorkspaceMinWidth;
    if (!hasChrome) {
      return MainWorkspaceScope(hasChrome: false, child: child);
    }
    return MainWorkspaceScope(
      hasChrome: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const MainWorkspaceBar(),
          Expanded(child: child),
        ],
      ),
    );
  }
}

/// The global search / tool strip above tablet and desktop pages.
class MainWorkspaceBar extends StatelessWidget {
  /// The workspace bar.
  const new({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = PureTheme.of(context);
    final gutter = MainLayout.gutterOf(context);
    final t = context.t;

    return Container(
      height: 64,
      decoration: BoxDecoration(
        color: theme.colors.bgElevated,
        border: Border(bottom: BorderSide(color: theme.colors.border)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = math.min(constraints.maxWidth, MainLayout.maxContentWidth);
          return Align(
            alignment: Alignment.topCenter,
            child: SizedBox(
              width: width,
              height: 64,
              child: Padding(
                padding: EdgeInsetsDirectional.only(start: gutter, end: gutter - 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 460),
                          child: _WorkspaceSearch(onTap: () => unawaited(const SearchRoute().push<void>(context))),
                        ),
                      ),
                    ),
                    const SizedBox(width: PureSpacing.lg),
                    PureIconButton(
                      icon: Icons.grid_view_outlined,
                      tooltip: t.multiview.title,
                      size: ControlSize.sm,
                      onPressed: () => unawaited(const MultiviewRoute().push<void>(context)),
                    ),
                    const SizedBox(width: PureSpacing.xs),
                    PureIconButton(
                      icon: Icons.link_outlined,
                      tooltip: t.toolbox.title,
                      size: ControlSize.sm,
                      onPressed: () => unawaited(const ToolboxRoute().push<void>(context)),
                    ),
                    const SizedBox(width: PureSpacing.xs),
                    PureIconButton(
                      icon: Icons.settings_outlined,
                      tooltip: t.tabs.settings,
                      size: ControlSize.sm,
                      onPressed: () => unawaited(const SettingsRoute().push<void>(context)),
                    ),
                    const SizedBox(width: PureSpacing.sm),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// The search affordance. It is deliberately a button-shaped field: search is a
/// full page, so tapping opens that page instead of installing a second text
/// editor in the chrome.
class _WorkspaceSearch extends StatelessWidget {
  const new({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = PureTheme.of(context);
    final t = context.t;

    return SizedBox(
      height: 38,
      child: PureBox(
        style: (state) => Style(
          padding: const EdgeInsetsDirectional.symmetric(horizontal: PureSpacing.md),
          borderRadius: BorderRadius.circular(theme.input.borderRadius),
          background: state == InteractionState.hovered ? theme.colors.fillQuaternary : theme.colors.bgContainer,
          borderColor: theme.colors.border,
          borderWidth: 1,
          foreground: theme.colors.textTertiary,
          alignment: AlignmentDirectional.centerStart,
        ),
        onTap: onTap,
        child: Row(
          children: [
            const Icon(Icons.search_rounded, size: 18),
            const SizedBox(width: PureSpacing.sm),
            Expanded(
              child: Text(
                t.search.hint,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.text.bodySmall.copyWith(color: theme.colors.textTertiary),
              ),
            ),
            Icon(Icons.mic_none_rounded, size: 17, color: theme.colors.textTertiary),
          ],
        ),
      ),
    );
  }
}
