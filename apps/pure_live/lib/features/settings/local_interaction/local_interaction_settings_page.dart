import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pure_live/app/preferences/app_preferences_providers.dart';
import 'package:pure_live/features/settings/widgets/settings_chrome.dart';
import 'package:pure_live/l10n/generated/strings.g.dart';
import 'package:pure_settings_ui/pure_settings_ui.dart';
import 'package:pure_uikit/pure_uikit.dart';

/// The local interaction settings (the reference's `SettingsSection.
/// localInteraction`): who the viewer is when the app has no platform
/// login — the name and colour the local danmaku pipeline stamps on
/// messages the app itself produces.
///
/// The switch gates the whole local pipeline (see `RoomLocalMessageBus`);
/// the name and colour edits stay live — an open room picks them up on the
/// next message.
final class LocalInteractionSettingsPage extends ConsumerWidget {
  /// The local interaction settings page.
  const new({super.key});

  /// The swatch set the colour row offers — the reference's palette trimmed
  /// to readable defaults on both light and dark barrage backgrounds.
  static const List<int> _palette = [
    0xFFFFFFFF,
    0xFF19A0FF,
    0xFF2ECC71,
    0xFFFFD400,
    0xFFFF7A00,
    0xFFFF4D6D,
    0xFFB964FF,
    0xFF6EC6FF,
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    final preferences = ref.watch(appPreferencesProvider);
    final update = ref.read(appPreferencesProvider.notifier).update;
    return SettingsChrome(
      title: t.settings.localInteraction,
      body: SettingsList(
        sections: [
          SettingsSection(
            title: Text(t.settings.groupLocalInteraction),
            tiles: [
              SettingsTile.switchTile(
                leading: const Icon(Icons.auto_awesome),
                title: Text(t.settings.localInteraction),
                description: Text(t.settings.localInteractionSubtitle),
                initialValue: preferences.localInteractionEnabled,
                onToggle: (value) => unawaited(update((p) => p.copyWith(localInteractionEnabled: value))),
              ),
              SettingsTile.navigation(
                leading: const Icon(Icons.badge_outlined),
                title: Text(t.settings.localInteractionName),
                trailing: Text(
                  preferences.localInteractionUserName.trim().isEmpty
                      ? t.room.localMe
                      : preferences.localInteractionUserName,
                ),
                onPressed: (context) => unawaited(_editName(context, ref)),
              ),
              CustomSettingsTile(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: PureSpacing.lg, vertical: PureSpacing.sm),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(t.settings.localInteractionColor, style: PureTheme.of(context).text.body),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          for (final argb in _palette)
                            _Swatch(
                              argb: argb,
                              selected: preferences.localInteractionColor == argb,
                              onTap: () => unawaited(update((p) => p.copyWith(localInteractionColor: argb))),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _editName(BuildContext context, WidgetRef ref) async {
    final field = TextEditingController(text: ref.read(appPreferencesProvider).localInteractionUserName);
    final value = await showPureDialog<String>(
      context: context,
      title: context.t.settings.localInteractionName,
      child: Builder(
        builder: (fieldContext) => Focus(
          autofocus: true,
          child: PureTextField(
            controller: field,
            placeholder: context.t.room.localMe,
            onSubmitted: (submitted) => Navigator.of(fieldContext).pop(submitted),
          ),
        ),
      ),
      actions: (dialogContext) => [
        PureButton(
          label: dialogContext.t.common.cancel,
          variant: ButtonVariant.ghost,
          onPressed: () => Navigator.of(dialogContext).pop(),
        ),
        PureButton(label: dialogContext.t.common.confirm, onPressed: () => Navigator.of(dialogContext).pop(field.text)),
      ],
    );
    field.dispose();
    if (value != null) {
      await ref
          .read(appPreferencesProvider.notifier)
          .update((preferences) => preferences.copyWith(localInteractionUserName: value.trim()));
    }
  }
}

class _Swatch extends StatelessWidget {
  const new({required this.argb, required this.selected, required this.onTap});

  final int argb;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = PureTheme.of(context);
    return Semantics(
      button: true,
      selected: selected,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: Color(argb),
            shape: BoxShape.circle,
            border: Border.all(
              color: selected ? theme.colors.primary : theme.colors.border,
              width: selected ? 3 : 1,
            ),
          ),
          child: selected
              ? Icon(Icons.check_rounded, size: 16, color: Color(argb).computeLuminance() > 0.5 ? Colors.black : Colors.white)
              : null,
        ),
      ),
    );
  }
}
