import 'dart:async' show unawaited;

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart' show GoRouterHelper;

import 'package:pure_live/app/app.dart';
import 'package:pure_live/features/settings/surface/settings_sections.dart';

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

/// Opens [section] from a page inside a category: desktop shows it in the
/// centre pane, a touch shell pushes the page as its own route.
void openSettingsChild(BuildContext context, WidgetRef ref, SettingsSection section) {
  openSettingsSection(ref, section);
  if (!ref.read(deviceProfileProvider).isDesktop) {
    unawaited(context.push(SettingsSectionRoute(section: section.name).location));
  }
}
