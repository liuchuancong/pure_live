import 'package:desen_ui/desen_ui.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:pure_live/app/providers/window_providers.dart' show desktopWindowHostProvider, maximizedProvider;
import 'package:pure_live/l10n/translations.dart';
import 'package:pure_live/shared/enums/navigation_item.dart' show NavigationItem;

/// The height of the title bar: the drag band and the caption row.
const double kTitleBarHeight = 44;

/// The desktop layout, following the v4 navigation design: the self-drawn
/// title bar above; a grouped sidebar below it — the brand on top, three
/// labelled sections of destinations, the user entry last — expanded with
/// labels at wide widths and folded to an icon rail with tooltips below
/// the breakpoint; a search field opening the search destination above the
/// content.
///
/// The caption and the drag band go to the window host — the layout is the
/// app's, the window behaviour is `live_shell_desktop`'s. Which widths get
/// which sidebar is the caller's breakpoints, not this widget's.
final class DesktopLayout extends ConsumerWidget {
  /// A desktop layout over [content].
  const DesktopLayout({
    required this.content,
    required this.groups,
    required this.selected,
    required this.onSelected,
    required this.expanded,
    super.key,
  });

  /// The current screen.
  final Widget content;

  /// The sidebar groups: (slang key of the section label, destinations).
  final List<(String, List<NavigationItem>)> groups;

  /// The selected destination.
  final NavigationItem selected;

  /// Fired when the viewer picks a destination.
  final ValueChanged<NavigationItem> onSelected;

  /// Whether the sidebar shows its labels (the expanded rail) or folds to
  /// icons with tooltips.
  final bool expanded;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = DsTheme.colorsOf(context);
    final t = context.t;
    return ColoredBox(
      color: colors.surface,
      child: Column(
        children: [
          const _WindowTitleBar(),
          Expanded(
            child: Row(
              children: [
                DsSidebar(
                  collapsed: !expanded,
                  header: _Brand(collapsed: !expanded),
                  value: selected,
                  onChanged: onSelected,
                  children: [
                    for (final (groupKey, groupItems) in groups) ...[
                      DsSidebarSection(label: Text(_groupLabel(t, groupKey))),
                      for (final item in groupItems)
                        DsSidebarItem(
                          label: Text(item.label(t)),
                          value: item,
                          leading: DsIcon(item.icon),
                          selected: item == selected,
                          onPressed: () => onSelected(item),
                        ),
                    ],
                  ],
                ),
                ColoredBox(color: colors.border, child: const SizedBox(width: 1)),
                Expanded(
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                        child: GestureDetector(
                          onTap: () => onSelected(NavigationItem.search),
                          child: AbsorbPointer(child: DsSearchField(placeholder: t.common.searchHint)),
                        ),
                      ),
                      Expanded(child: content),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _groupLabel(Translations t, String key) => switch (key) {
    'groupPrimary' => t.navigation.groupPrimary,
    'groupContent' => t.navigation.groupContent,
    'groupPersonal' => t.navigation.groupPersonal,
    _ => key,
  };
}

/// The brand at the sidebar's top: icon plus the app name when expanded,
/// the icon alone when folded.
final class _Brand extends StatelessWidget {
  const _Brand({required this.collapsed});

  final bool collapsed;

  @override
  Widget build(BuildContext context) {
    final colors = DsTheme.colorsOf(context);
    if (collapsed) {
      return Center(child: DsIcon(DsIcons.tv, size: 18, color: colors.text));
    }
    return Row(
      children: [
        const SizedBox(width: 12),
        DsIcon(DsIcons.tv, size: 18, color: colors.text),
        const SizedBox(width: 8),
        Text(context.t.common.appTitle, style: DsTheme.of(context).typography.title.copyWith(color: colors.text)),
      ],
    );
  }
}

/// The strip above every route: drag band, brand, caption controls.
final class _WindowTitleBar extends ConsumerWidget {
  const _WindowTitleBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = DsTheme.colorsOf(context);
    final host = ref.watch(desktopWindowHostProvider);
    return ColoredBox(
      color: colors.surface,
      child: SizedBox(
        height: kTitleBarHeight,
        child: Row(
          children: [
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onPanStart: (_) => host.startDragging(),
                onDoubleTap: host.toggleMaximize,
                child: Row(
                  children: [
                    const SizedBox(width: 12),
                    DsIcon(DsIcons.tv, size: 16, color: colors.textMuted),
                    const SizedBox(width: 8),
                    Text(
                      context.t.common.appTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: DsTheme.of(context).typography.caption.copyWith(color: colors.textMuted),
                    ),
                  ],
                ),
              ),
            ),
            const _CaptionControls(),
          ],
        ),
      ),
    );
  }
}

final class _CaptionControls extends ConsumerWidget {
  const _CaptionControls();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    final host = ref.watch(desktopWindowHostProvider);
    final maximized = ref.watch(maximizedProvider);
    return Row(
      children: [
        _CaptionButton(semanticLabel: t.common.minimize, icon: DsIcons.minus, onPressed: host.minimize),
        _CaptionButton(
          semanticLabel: maximized ? t.common.restore : t.common.maximize,
          icon: maximized ? DsIcons.copy : DsIcons.square,
          onPressed: host.toggleMaximize,
        ),
        _CaptionButton(semanticLabel: t.common.close, icon: DsIcons.x, danger: true, onPressed: host.close),
      ],
    );
  }
}

final class _CaptionButton extends ConsumerWidget {
  const _CaptionButton({required this.semanticLabel, required this.icon, required this.onPressed, this.danger = false});

  final String semanticLabel;
  final DsIconData icon;
  final Future<void> Function() onPressed;
  final bool danger;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = DsTheme.colorsOf(context);
    return SizedBox(
      width: kTitleBarHeight,
      height: kTitleBarHeight,
      child: DsPressable(
        semanticLabel: semanticLabel,
        onPressed: onPressed,
        builder: (context, states, _) {
          final hovered = states.contains(WidgetState.hovered);
          final pressed = states.contains(WidgetState.pressed);
          Color? background;
          if (danger && hovered) {
            background = colors.danger.fill;
          } else if (hovered || pressed) {
            background = pressed ? colors.press : colors.hover;
          }
          return ColoredBox(
            color: background ?? const Color(0x00000000),
            child: Center(child: DsIcon(icon, size: 14, color: colors.text)),
          );
        },
      ),
    );
  }
}
