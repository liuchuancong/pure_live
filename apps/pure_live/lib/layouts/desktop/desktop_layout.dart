import 'package:desen_ui/desen_ui.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:pure_live/app/providers/window_providers.dart' show desktopWindowHostProvider, maximizedProvider;
import 'package:pure_live/l10n/translations.dart';
import 'package:pure_live/shared/enums/navigation_item.dart' show NavigationItem;

/// The height of the title bar: the drag band and the caption row.
const double kTitleBarHeight = 44;

/// The desktop layout: the self-drawn title bar above, the sidebar on the
/// left, the content to the right.
///
/// The caption is drawn here and every window verb goes to the window
/// host — the layout is the app's, the window behaviour is
/// `live_shell_desktop`'s.
final class DesktopLayout extends ConsumerWidget {
  /// A desktop layout over [content].
  const DesktopLayout({
    required this.content,
    required this.items,
    required this.selectedIndex,
    required this.onSelected,
    super.key,
  });

  /// The current screen.
  final Widget content;

  /// The navigation destinations, in order.
  final List<NavigationItem> items;

  /// The selected destination's index.
  final int selectedIndex;

  /// Fired when the viewer picks a destination.
  final ValueChanged<int> onSelected;

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
                  value: selectedIndex,
                  onChanged: onSelected,
                  children: [
                    for (final (index, item) in items.indexed)
                      DsSidebarItem(
                        label: Text(item.label(t)),
                        value: index,
                        leading: DsIcon(item.icon),
                        selected: index == selectedIndex,
                        onPressed: () => onSelected(index),
                      ),
                  ],
                ),
                ColoredBox(color: colors.border, child: const SizedBox(width: 1)),
                Expanded(child: content),
              ],
            ),
          ),
        ],
      ),
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
