import 'dart:async' show unawaited;

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart' show GoRouterHelper;
import 'package:live_platform/live_platform.dart' show FormFactor;

import 'package:pure_live/app/app.dart';
import 'package:pure_live/features/settings/surface/settings_sections.dart';
import 'package:pure_live/shared/shared.dart' show NavigationItem, kBottomBarBreakpoint;

/// Whether settings navigate as a stack of their own — the categories page,
/// then the category's sections, then a section — rather than swapping the
/// centre pane in place.
///
/// The shell decides, not the platform: the phone shell has no settings
/// sidebar, so a desktop window shrunk under the bottom bar takes the same
/// stack instead of a pane whose siblings it cannot reach. TV keeps the
/// desktop shell, so it keeps the pane.
bool settingsStacksRoutes(BuildContext context, {required FormFactor formFactor, required bool desktopProfile}) {
  if (formFactor == FormFactor.tv) return false;
  if (!desktopProfile) return true;
  return MediaQuery.sizeOf(context).width < kBottomBarBreakpoint.breakpoint;
}

/// Opens [section] as the surface's page. Its category comes from the
/// registry, so the sidebar, the category page and the breadcrumb agree on
/// where the page sits.
void openSettingsSection(WidgetRef ref, SettingsSection section) {
  final groups = navigationOf(ref.read(selectedModuleProvider)).settingsGroups;
  final group = settingsGroupOf(groups, section);
  if (group != null) ref.read(settingsCategoryProvider.notifier).categoryKey = group.labelKey;
  ref.read(settingsSectionProvider.notifier).section = section;
  ref.read(settingsSectionOpenProvider.notifier).open = true;
}

/// Shows [categoryKey]'s own page: its list of sections.
void openSettingsCategory(WidgetRef ref, String categoryKey) {
  ref.read(settingsCategoryProvider.notifier).categoryKey = categoryKey;
  ref.read(settingsSectionOpenProvider.notifier).open = false;
}

/// Leaves a section page for its category page.
void closeSettingsSection(WidgetRef ref) {
  ref.read(settingsSectionOpenProvider.notifier).open = false;
}

/// Opens [section] from a page inside a category: a shell without the
/// settings sidebar shows it as a pushed page, the desktop pane switches in
/// place.
void openSettingsChild(BuildContext context, WidgetRef ref, SettingsSection section) {
  openSettingsSection(ref, section);
  final runtime = ref.read(platformRuntimeProvider).environment.runtime;
  final stacked = settingsStacksRoutes(
    context,
    formFactor: runtime.formFactor,
    desktopProfile: ref.read(deviceProfileProvider).isDesktop,
  );
  if (stacked) {
    unawaited(context.push(SettingsSectionRoute(section: section.name).location));
  }
}

/// Leaves the settings surface for [item]'s own module page.
///
/// Settings owns the choices a module makes — lanes, quality, the folder — and
/// a pane that also drew the module's list gave one thing two entrances, the
/// weaker one: the page has the table, the filters and the batch verbs, and a
/// settings row cannot hold them. The summary stays here as one line that says
/// how much is queued and names the folder; the press hands the rest to the
/// module, the same way the module's own door hands settings over.
void openModuleItem(BuildContext context, WidgetRef ref, NavigationItem item) {
  ref.read(selectedNavItemProvider.notifier).selected = item;
  // Settings closes to its categories on the next visit, rather than reopening
  // on the pane that just sent the viewer away from it.
  ref.read(settingsSectionOpenProvider.notifier).open = false;
  final runtime = ref.read(platformRuntimeProvider).environment.runtime;
  final stacked = settingsStacksRoutes(
    context,
    formFactor: runtime.formFactor,
    desktopProfile: ref.read(deviceProfileProvider).isDesktop,
  );
  // A shell that navigates settings as pushed pages has the section on top of
  // the shell; the module's page is what lies under it, so stepping off the
  // section is the way out. The desktop pane needs no pop — the content area
  // follows the selection on its own.
  if (stacked && Navigator.of(context).canPop()) Navigator.of(context).maybePop();
}
