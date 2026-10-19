import 'dart:async' show unawaited;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_platform/live_platform.dart' show FormFactor;
import 'package:pure_live/app/preferences/app_preferences.dart';
import 'package:pure_live/app/preferences/app_preferences_providers.dart';
import 'package:pure_live/app/providers/app_providers.dart';
import 'package:pure_live/app/shell/shell_destinations.dart';
import 'package:pure_live/features/settings/widgets/settings_chooser.dart';
import 'package:pure_live/features/settings/widgets/settings_rows.dart';
import 'package:pure_live/features/settings/widgets/settings_surface.dart';
import 'package:pure_live/l10n/generated/strings.g.dart';
import 'package:pure_live/shared/rooms/paging.dart';
import 'package:pure_settings_ui/pure_settings_ui.dart';
import 'package:pure_uikit/pure_uikit.dart';

/// The page settings page (3.x `PageSettingsPage`): which shell branches
/// the chromes render and in what order — the favorites branch is the floor
/// — and, on computers, the pager that owns the browsing lists: default
/// rooms per page, the choice list, the jump buttons, the size selector and
/// the go-to field (the reference's "分页条（电脑）" group).
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
      body: SettingsList(
        sections: [
          SettingsSection(
            title: Text(t.settings.groupVisibleBranches),
            tiles: [
              // A reorderable list is not a tile the kit models — the drag
              // handle and the per-row switch are the app's own rows, inside the
              // section the language already draws a card around.
              SettingsRowTile(
                row: ReorderableListView.builder(
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
                    unawaited(update((p) => p.copyWith(shellBranches: [for (final branch in reordered) branch.name])));
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
                              unawaited(_hide(ref, branch));
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
          if (hidden.isNotEmpty)
            SettingsSection(
              title: Text(t.settings.groupHiddenBranches),
              tiles: [
                for (final branch in hidden)
                  SettingsTile.switchTile(
                    leading: Icon(branch.icon),
                    title: Text(branch.label(context)),
                    description: Text(t.settings.showBranchSubtitle),
                    initialValue: false,
                    onToggle: (value) {
                      if (!value) {
                        return;
                      }
                      final shown = [...visible, branch];
                      unawaited(update((p) => p.copyWith(shellBranches: [for (final item in shown) item.name])));
                    },
                  ),
              ],
            ),
          // The pager of computers (the reference shows these only off
          // phones and tablets, where lists page instead of growing).
          if (ref.watch(environmentProvider).runtime.formFactor case FormFactor.desktop || FormFactor.tv)
            SettingsSection(
              title: Text(t.settings.pagerGroup),
              tiles: [
                SettingsTile.navigation(
                  leading: const Icon(Icons.view_array_outlined),
                  key: const ValueKey('settings-page-default-size'),
                  title: Text(t.settings.pageDefaultSize),
                  description: Text(t.settings.pageDefaultSizeHint),
                  value: Text(
                    preferences.pageDefaultSize == 0
                        ? t.settings.pageSizeAuto
                        : '${preferences.pageDefaultSize} ${t.settings.itemsPerPage}',
                  ),
                  onPressed: (_) => unawaited(
                    _choose<int>(
                      context,
                      ref,
                      title: t.settings.pageDefaultSize,
                      hint: t.settings.pageDefaultSizeHint,
                      current: preferences.pageDefaultSize,
                      options: [
                        for (final size in const [0, 12, 20, 30, 40, 60])
                          (size, size == 0 ? t.settings.pageSizeAuto : '$size ${t.settings.itemsPerPage}'),
                      ],
                      apply: (value) => update((p) => p.copyWith(pageDefaultSize: value)),
                    ),
                  ),
                ),
                SettingsTile.navigation(
                  leading: const Icon(Icons.format_list_numbered_outlined),
                  key: const ValueKey('settings-page-size-options'),
                  title: Text(t.settings.pageSizeOptionsTitle),
                  value: Text(pageSizesOf(preferences, MediaQuery.sizeOf(context).width).options.join(', ')),
                  onPressed: (_) => unawaited(_editPageSizeOptions(context, ref, preferences, update)),
                ),
                SettingsTile.switchTile(
                  leading: const Icon(Icons.vertical_align_top),
                  key: const ValueKey('settings-page-show-scroll-top'),
                  title: Text(t.settings.pageShowScrollTop),
                  description: Text(t.settings.pageShowScrollTopSubtitle),
                  initialValue: preferences.pageShowScrollTop,
                  onToggle: (value) => unawaited(update((p) => p.copyWith(pageShowScrollTop: value))),
                ),
                SettingsTile.switchTile(
                  leading: const Icon(Icons.straighten_outlined),
                  key: const ValueKey('settings-page-show-size-selector'),
                  title: Text(t.settings.pageShowSizeSelector),
                  description: Text(t.settings.pageShowSizeSelectorSubtitle),
                  initialValue: preferences.pageShowSizeSelector,
                  onToggle: (value) => unawaited(update((p) => p.copyWith(pageShowSizeSelector: value))),
                ),
                SettingsTile.switchTile(
                  leading: const Icon(Icons.skip_next_outlined),
                  key: const ValueKey('settings-page-show-goto'),
                  title: Text(t.settings.pageShowGoto),
                  description: Text(t.settings.pageShowGotoSubtitle),
                  initialValue: preferences.pageShowGoto,
                  onToggle: (value) => unawaited(update((p) => p.copyWith(pageShowGoto: value))),
                ),
              ],
            ),
          SettingsSection(
            tiles: [
              CustomSettingsTile(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Text(
                    t.settings.pageSettingsHint,
                    style: PureTheme.of(context).text.caption
                        .copyWith(color: PureTheme.of(context).colors.textSecondary),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static Future<void> _hide(WidgetRef ref, ShellBranch branch) {
    final preferences = ref.read(appPreferencesProvider);
    final remaining = preferences.shellBranches.where((id) => id != branch.name).toList();
    return ref.read(appPreferencesProvider.notifier).update((p) => p.copyWith(shellBranches: remaining));
  }

  /// The one visible branch cannot hide: a shell with no destination cannot be
  /// walked.
  static void _announceFloor(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.t.settings.atLeastOneBranch)));
  }

  /// A choice row — the same chooser the refresh page drives.
  static Future<void> _choose<T>(
    BuildContext context,
    WidgetRef ref, {
    required String title,
    required String? hint,
    required T current,
    required List<(T, String)> options,
    required Future<void> Function(T) apply,
  }) async {
    final picked = await showSettingsChooser<T>(
      context,
      ref,
      title: title,
      hint: hint,
      current: current,
      options: options,
    );
    if (picked != null) {
      await apply(picked);
    }
  }

  /// The page-size choices dialog (the reference's `PageSizeOptionsTile`):
  /// chips to remove, a field to add, "恢复推荐" back to the width rule; at
  /// least one choice stays.
  static Future<void> _editPageSizeOptions(
    BuildContext context,
    WidgetRef ref,
    AppPreferences preferences,
    Future<void> Function(AppPreferences Function(AppPreferences)) update,
  ) async {
    final t = context.t;
    final key = GlobalKey<_PageSizeDialogState>(debugLabel: 'page-size-options');
    final result = await showSettingsSurface<List<int>>(
      context,
      ref,
      title: t.settings.pageSizeOptionsTitle,
      body: (surfaceContext) => _PageSizeDialog(
        key: key,
        initial: parsePageSizeOptions(preferences.pageSizeOptions),
        recommended: MediaQuery.sizeOf(context).width > 960 ? const [20, 40, 60, 80] : const [12, 24, 36, 48],
      ),
      actions: (dialogContext) => [
        PureButton(
          label: dialogContext.t.common.cancel,
          variant: ButtonVariant.ghost,
          onPressed: () => Navigator.of(dialogContext).pop(),
        ),
        PureButton(
          key: const ValueKey('settings-page-sizes-save'),
          label: dialogContext.t.common.save,
          onPressed: () => Navigator.of(dialogContext).pop(key.currentState?.options ?? const <int>[]),
        ),
      ],
    );
    if (result != null) {
      await update((p) => p.copyWith(pageSizeOptions: result.join(',')));
    }
  }
}

/// The choices editor inside the page-size options dialog; the current
/// list is read back through the key when the dialog's save fires.
final class _PageSizeDialog extends StatefulWidget {
  const new({required this.initial, required this.recommended, super.key});

  final List<int> initial;
  final List<int> recommended;

  @override
  State<_PageSizeDialog> createState() => _PageSizeDialogState();
}

final class _PageSizeDialogState extends State<_PageSizeDialog> {
  /// Empty means "recommended" (stored as an empty list).
  late List<int> _options = List.of(widget.initial);
  final TextEditingController _input = TextEditingController();
  String? _error;

  /// The choices the dialog will hand back; the recommended set while none
  /// were picked by hand.
  List<int> get options => _options;
  List<int> get _shown => _options.isEmpty ? widget.recommended : _options;

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  void _add() {
    final value = int.tryParse(_input.text.trim());
    if (value == null || value < 1 || value > 100) {
      setState(() => _error = context.t.settings.pageSizeRangeError);
      return;
    }
    if (_shown.contains(value)) {
      setState(() => _error = context.t.settings.pageSizeDuplicateError);
      return;
    }
    setState(() {
      _options = [..._shown, value]..sort();
      _input.clear();
      _error = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final theme = PureTheme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Text(t.settings.pageSizeCurrent, style: theme.text.bodySmall)),
            PureButton(
              key: const ValueKey('settings-page-sizes-recommended'),
              label: t.settings.pageSizeRestore,
              icon: Icons.auto_fix_high_outlined,
              size: ControlSize.sm,
              variant: ButtonVariant.ghost,
              onPressed: () => setState(() => _options = []),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final value in _shown)
              Container(
                key: ValueKey('settings-page-size-$value'),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: theme.colors.fillSecondary, borderRadius: BorderRadius.circular(14)),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('$value', style: theme.text.bodySmall),
                    // At least one stays (3.x).
                    if (_shown.length > 1)
                      PureIconButton(
                        icon: Icons.close_rounded,
                        tooltip: t.common.clear,
                        size: ControlSize.sm,
                        onPressed: () => setState(() => _options = [..._shown]..remove(value)),
                      ),
                  ],
                ),
              ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  PureTextField(
                    key: const ValueKey('settings-page-size-input'),
                    controller: _input,
                    placeholder: '${t.settings.pageSizeInputHint} ${t.settings.itemsPerPage}',
                    keyboardType: TextInputType.number,
                    errorText: _error,
                    onChanged: (text) {
                      final digits = text.replaceAll(RegExp(r'\D'), '');
                      if (digits != text) {
                        _input.text = digits;
                        _input.selection = TextSelection.collapsed(offset: digits.length);
                      }
                      if (_error != null) {
                        setState(() => _error = null);
                      }
                    },
                    onSubmitted: (_) => _add(),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            PureButton(
              key: const ValueKey('settings-page-size-add'),
              label: t.common.addOne,
              icon: Icons.add,
              onPressed: _add,
            ),
          ],
        ),
      ],
    );
  }
}
