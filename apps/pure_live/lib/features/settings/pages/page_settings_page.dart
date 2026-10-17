import 'dart:async' show unawaited;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pure_live/app/preferences/app_preferences_providers.dart';
import 'package:pure_live/app/shell/shell_destinations.dart';
import 'package:pure_live/features/settings/widgets/settings_sections.dart';
import 'package:pure_live/l10n/generated/strings.g.dart';
import 'package:pure_uikit/pure_uikit.dart';

/// The page settings page (3.x `PageSettingsPage` re-scoped to what this
/// build's shell has): which shell branches the chromes render, and in what
/// order.
///
/// The visible branches are one reorderable list — drag to arrange; a
/// hidden branch keeps its follow position for when it is shown again. The
/// home branch is the floor: a shell with no destination cannot be walked,
/// so the last visible switch refuses to turn off.
final class PageSettingsPage extends ConsumerWidget {
  /// The page settings page.
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    final preferences = ref.watch(appPreferencesProvider);
    final update = ref.read(appPreferencesProvider.notifier).update;
    final visible = visibleShellBranches(preferences);
    final hidden = ShellBranch.values.where((branch) => !visible.contains(branch)).toList();

    return PureScaffold(
      appBar: PureAppBar(title: t.settings.pageSettings),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          SettingsSection(
            label: t.settings.groupVisibleBranches,
            children: [
              PureCard(
                padding: EdgeInsets.zero,
                child: ReorderableListView.builder(
                  shrinkWrap: true,
                  buildDefaultDragHandles: false,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: visible.length,
                  onReorderItem: (oldIndex, newIndex) {
                    if (oldIndex < 0 || oldIndex >= visible.length) {
                      return;
                    }
                    final reordered = [...visible]..removeAt(oldIndex);
                    reordered.insert(newIndex.clamp(0, reordered.length), visible[oldIndex]);
                    unawaited(
                      update((p) => p.copyWith(shellBranches: [for (final branch in reordered) branch.name])),
                    );
                  },
                  itemBuilder: (context, index) {
                    final branch = visible[index];
                    return PureListRow(
                      key: ValueKey(branch.name),
                      leading: Icon(branch.icon, size: 22),
                      title: branch.label(context),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          PureSwitch(
                            value: true,
                            onChanged: (value) {
                              if (value) {
                                return;
                              }
                              if (visible.length <= 1) {
                                _announceFloor(context);
                                return;
                              }
                              unawaited(_hide(context, ref, branch));
                            },
                          ),
                          ReorderableDragStartListener(
                            index: index,
                            child: const Padding(
                              padding: EdgeInsets.all(12),
                              child: Icon(Icons.drag_indicator_outlined),
                            ),
                          ),
                        ],
                      ),
                      divided: index < visible.length - 1,
                    );
                  },
                ),
              ),
            ],
          ),
          if (hidden.isNotEmpty) ...[
            const SettingsSectionGap(),
            SettingsSection.card(
              label: t.settings.groupHiddenBranches,
              tiles: [
                for (var i = 0; i < hidden.length; i++)
                  SettingsSwitchTile(
                    icon: hidden[i].icon,
                    title: hidden[i].label(context),
                    subtitle: t.settings.showBranchSubtitle,
                    value: false,
                    onChanged: (value) {
                      if (!value) {
                        return;
                      }
                      final shown = [...visible, hidden[i]];
                      unawaited(update((p) => p.copyWith(shellBranches: [for (final branch in shown) branch.name])));
                    },
                    divided: i < hidden.length - 1,
                  ),
              ],
            ),
          ],
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(
              t.settings.pageSettingsHint,
              style: PureTheme.of(context).text.caption.copyWith(color: PureTheme.of(context).colors.textSecondary),
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  static Future<void> _hide(BuildContext context, WidgetRef ref, ShellBranch branch) {
    final preferences = ref.read(appPreferencesProvider);
    final remaining = preferences.shellBranches.where((id) => id != branch.name).toList();
    return ref.read(appPreferencesProvider.notifier).update((p) => p.copyWith(shellBranches: remaining));
  }

  /// The one visible branch cannot hide: a shell with no destination cannot
  /// be walked.
  static void _announceFloor(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.t.settings.atLeastOneBranch)));
  }
}
