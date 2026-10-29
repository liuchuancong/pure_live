import 'package:desen_ui/desen_ui.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pure_live/features/settings/settings.dart';
import 'package:pure_live/l10n/translations.dart';
import 'package:pure_live/shared/shared.dart';

/// The where-am-I path at a shell's head: the module, then the page — or,
/// on the settings surface, the settings root, its category and the sections
/// under the one on screen.
///
/// The crumbs say where the viewer stands (the current page is the last
/// crumb, not pressed); deeper context — an area inside the areas page, the
/// query inside the search page — is that page's own breadcrumb, one level
/// below this one. The desktop content head and the phone's top bar share
/// this one path, so the two shells never disagree about the location.
final class LocationBreadcrumb extends ConsumerWidget {
  /// The breadcrumb of [module]'s [selected] page, or of a settings surface
  /// at [settings] under [categoryKey].
  const LocationBreadcrumb({
    required this.module,
    required this.selected,
    this.settings,
    this.categoryKey,
    this.sectionOpen = false,
    super.key,
  });

  /// The module whose page is on screen.
  final AppModule module;

  /// The selected destination, outside settings.
  final Object? selected;

  /// The settings section on screen; null outside the settings surface.
  final SettingsSection? settings;

  /// The settings category the surface is on.
  final String? categoryKey;

  /// Whether a section page is open below [categoryKey].
  final bool sectionOpen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    // A small screen's bar keeps one line: the middle levels collapse into
    // the kit's "…" menu instead of wrapping under the title.
    final overflow = LiveWindow.isCompact(MediaQuery.sizeOf(context).width) ? DsBreadcrumbOverflow.collapse : null;
    final section = settings;
    if (section != null) {
      // Walk the whole tree: Settings › Personalization › Background ›
      // Online images. The category steps back to its page of sections.
      final category = categoryKey;
      final ancestors = <SettingsSection>[];
      if (sectionOpen) {
        for (var parent = section.parentSection; parent != null; parent = parent.parentSection) {
          ancestors.add(parent);
        }
      }
      return DsBreadcrumb(
        overflow: overflow,
        items: [
          DsBreadcrumbItem(label: t.navigation.settings, icon: const DsIcon(DsIcons.settings)),
          if (category != null)
            DsBreadcrumbItem(
              label: settingsGroupLabel(t, category),
              icon: DsIcon(settingsGroupIcon(category)),
              onPressed: sectionOpen ? () => closeSettingsSection(ref) : null,
            ),
          if (sectionOpen) ...[
            for (final ancestor in ancestors.reversed)
              DsBreadcrumbItem(
                label: ancestor.label(t),
                icon: DsIcon(ancestor.icon),
                onPressed: () => openSettingsSection(ref, ancestor),
              ),
            DsBreadcrumbItem(label: section.label(t), icon: DsIcon(section.icon)),
          ],
        ],
      );
    }
    return DsBreadcrumb(
      overflow: overflow,
      items: [
        DsBreadcrumbItem(label: module.label(t), icon: DsIcon(module.icon)),
        if (selected case final NavigationItem item) DsBreadcrumbItem(label: item.label(t), icon: DsIcon(item.icon)),
      ],
    );
  }
}
