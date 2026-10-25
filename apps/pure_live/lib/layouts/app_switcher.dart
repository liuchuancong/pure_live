import 'package:desen_ui/desen_ui.dart';
import 'package:flutter/widgets.dart';

import 'package:pure_live/l10n/translations.dart';
import 'package:pure_live/shared/enums/app_module.dart';

/// The sidebar's head: the app mark and "Pure Live" beside a dropdown
/// chevron — the app switcher. Pressing it opens a popover under the name
/// with one entry per content type; the chosen entry keeps its tinted icon
/// tile, a subtle highlight, and a check on the end side.
///
/// Choosing a content type swaps the business menu and the content area in
/// place; no new window opens. Collapsed (the icon rail), the switcher is
/// the current type's tile alone.
final class AppSwitcher extends StatelessWidget {
  /// A switcher over [module].
  const AppSwitcher({required this.module, required this.onModule, this.collapsed = false, super.key});

  /// The content type the shell shows now.
  final AppModule module;

  /// Fired when the viewer chooses a content type.
  final ValueChanged<AppModule> onModule;

  /// Whether the sidebar is folded to its icon rail.
  final bool collapsed;

  @override
  Widget build(BuildContext context) {
    final colors = DsTheme.colorsOf(context);
    final theme = DsTheme.of(context);
    final t = context.t;

    return DsMenuAnchor(
      semanticLabel: t.common.switchModule,
      items: [
        for (final candidate in AppModule.values)
          DsMenuItem(
            label: Text(candidate.label(t)),
            leading: ModuleTile(module: candidate, size: 22),
            trailing: candidate == module ? const DsIcon(DsIcons.check, size: 16) : null,
            onPressed: () => onModule(candidate),
          ),
      ],
      builder: (context, controller, _) => DsPressable(
        semanticLabel: t.common.switchModule,
        onPressed: controller.toggle,
        builder: (context, states, _) {
          final hovered = states.contains(WidgetState.hovered);
          return Container(
            height: 40,
            padding: collapsed ? null : const EdgeInsetsDirectional.symmetric(horizontal: DsSpace.s8),
            decoration: DsBoxDecoration(
              color: controller.isOpen || hovered ? colors.hover : null,
              borderRadius: BorderRadius.circular(theme.radii.control(40)),
            ),
            child: collapsed
                ? Center(child: ModuleTile(module: module, size: 24))
                : Row(
                    children: [
                      const AppMark(size: 24),
                      const SizedBox(width: DsSpace.s8),
                      Expanded(
                        child: Text(
                          t.common.appTitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.typography.title.copyWith(color: colors.text),
                        ),
                      ),
                      _SwitcherChevron(controller: controller),
                    ],
                  ),
          );
        },
      ),
    );
  }
}

/// The chevron beside the app name; it flips while the popover is open.
final class _SwitcherChevron extends StatelessWidget {
  const _SwitcherChevron({required this.controller});

  final DsOverlayController controller;

  @override
  Widget build(BuildContext context) {
    final colors = DsTheme.colorsOf(context);
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) => TweenAnimationBuilder<double>(
        tween: Tween(end: controller.isOpen ? 1.0 : 0.0),
        duration: DsTheme.of(context).motion.moveDuration,
        curve: Curves.easeOutCubic,
        builder: (context, turn, child) => Transform.rotate(angle: turn * 3.14159265358979, child: child),
        child: DsIcon(DsIcons.chevronDown, size: 16, color: colors.textMuted),
      ),
    );
  }
}

/// The product mark: the blue rounded tile with the play glyph, as in the
/// v4 wordmark.
final class AppMark extends StatelessWidget {
  /// A mark at [size].
  const AppMark({required this.size, super.key});

  /// The tile's edge.
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: AlignmentDirectional.topStart,
          end: AlignmentDirectional.bottomEnd,
          colors: [Color(0xFF19A0FF), Color(0xFF0B84F3)],
        ),
        borderRadius: BorderRadius.circular(size * 0.3),
        boxShadow: [
          BoxShadow(
            color: const Color(0x370B84F3).withValues(alpha: 0.4),
            blurRadius: size * 0.4,
            offset: Offset(0, size * 0.12),
          ),
        ],
      ),
      child: Center(
        child: Padding(
          padding: EdgeInsetsDirectional.only(start: size * 0.04),
          child: DsIcon(DsIcons.play, size: size * 0.62, color: const Color(0xFFFFFFFF)),
        ),
      ),
    );
  }
}

/// A content type's tinted icon tile, as the popover and the collapsed
/// rail show it.
final class ModuleTile extends StatelessWidget {
  /// [module]'s tile at [size].
  const ModuleTile({required this.module, required this.size, super.key});

  /// The content type to picture.
  final AppModule module;

  /// The tile's edge.
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: module.tile,
        borderRadius: BorderRadius.circular(size * 0.3),
        boxShadow: [
          BoxShadow(
            color: module.tile.withValues(alpha: 0.30),
            blurRadius: size * 0.35,
            offset: Offset(0, size * 0.12),
          ),
        ],
      ),
      child: Center(
        child: DsIcon(module.icon, size: size * 0.6, color: const Color(0xFFFFFFFF)),
      ),
    );
  }
}

/// The quiet line that sets the business menu apart from the shared tools
/// (and the tools from the pinned settings entry) inside a sidebar.
final class SidebarDivider extends StatelessWidget {
  /// The divider, inset like a sidebar section's.
  const SidebarDivider({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.symmetric(horizontal: DsSpace.s8, vertical: DsSpace.s8),
      child: DsLine(color: DsTheme.colorsOf(context).border),
    );
  }
}
