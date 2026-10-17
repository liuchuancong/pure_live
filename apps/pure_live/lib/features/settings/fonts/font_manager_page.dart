import 'dart:async' show unawaited;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pure_live/app/fonts/font_library.dart';
import 'package:pure_live/app/providers/app_providers.dart';
import 'package:pure_live/features/settings/widgets/settings_sections.dart';
import 'package:pure_live/l10n/generated/strings.g.dart';
import 'package:pure_uikit/pure_uikit.dart';

/// The font manager (3.x `FontFamilyManagerPage`, app-font slice): the
/// reference's two groups — the factory default and the cloud manifest —
/// with download, apply and delete on each cloud family.
///
/// Applying writes the family id into the persisted appearance
/// (`fontFamily`), which the mapper carries into the uikit's `UiConfig`;
/// the engine learns the family's glyphs live through `FontLoader`, so no
/// restart is needed. Danmaku fonts join with the danmaku wave.
final class FontManagerPage extends ConsumerStatefulWidget {
  /// The font manager.
  const new({super.key});

  @override
  ConsumerState<FontManagerPage> createState() => _FontManagerPageState();
}

final class _FontManagerPageState extends ConsumerState<FontManagerPage> {
  List<FontFamily>? _families;
  Object? _error;
  final Set<String> _downloading = {};

  FontLibrary get _library => ref.read(fontLibraryProvider);

  @override
  void initState() {
    super.initState();
    unawaited(_loadFamilies());
  }

  Future<void> _loadFamilies() async {
    try {
      final families = await _library.fetchManifest();
      if (!mounted) {
        return;
      }
      setState(() => _families = families);
    } on Object {
      if (!mounted) {
        return;
      }
      setState(() => _error = StateError('manifest'));
    }
  }

  @override
  Widget build(BuildContext context) {
    final appearance = ref.watch(appearancePreferencesProvider);
    final update = ref.read(appearancePreferencesProvider.notifier).update;
    final families = _families;
    return PureScaffold(
      appBar: PureAppBar(title: context.t.settings.fonts),
      body: families == null
          ? Center(
              child: _error != null
                  ? Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(context.t.errors.network, textAlign: TextAlign.center),
                        const SizedBox(height: 12),
                        PureButton(label: context.t.common.retry, icon: Icons.refresh, onPressed: _loadFamilies),
                      ],
                    )
                  : const Center(child: PureSpinner(size: 40)),
            )
          : ListView(
              padding: const EdgeInsets.all(12),
              children: [
                SettingsSection.card(
                  label: context.t.fonts.factoryDefault,
                  tiles: [
                    _row(
                      context,
                      title: context.t.fonts.system,
                      selected: appearance.fontFamily?.isEmpty ?? true,
                      action: (appearance.fontFamily?.isEmpty ?? true)
                          ? null
                          : () => update((a) => a.copyWith(fontFamily: '')),
                    ),
                  ],
                ),
                if (families.isNotEmpty) ...[
                  const SettingsSectionGap(),
                  SettingsSection.card(
                    label: context.t.fonts.cloudFonts,
                    tiles: [
                      for (var i = 0; i < families.length; i++)
                        _row(
                          context,
                          title: families[i].name,
                          selected: appearance.fontFamily == families[i].id,
                          action: _library.isDownloaded(families[i].id)
                              ? () => update((a) => a.copyWith(fontFamily: families[i].id))
                              : null,
                          trailing: _familyAction(context, families[i]),
                          divided: i < families.length - 1,
                        ),
                    ],
                  ),
                ],
                const SizedBox(height: 32),
              ],
            ),
    );
  }

  PureListRow _row(
    BuildContext context, {
    required String title,
    required bool selected,
    required VoidCallback? action,
    String? subtitle,
    Widget? trailing,
    bool divided = false,
  }) => PureListRow(
    leading: selected
        ? Icon(Icons.check_circle, color: PureTheme.of(context).colors.primary)
        : const Icon(Icons.radio_button_unchecked),
    title: title,
    subtitle: (subtitle == null || subtitle.isEmpty) ? null : subtitle,
    trailing: trailing,
    onTap: action,
    divided: divided,
  );

  Widget? _familyAction(BuildContext context, FontFamily family) {
    if (_downloading.contains(family.id)) {
      return const PureSpinner(size: 20);
    }
    if (_library.isDownloaded(family.id)) {
      return PureIconButton(
        tooltip: context.t.fonts.delete,
        icon: Icons.delete_outline,
        onPressed: ref.read(appearancePreferencesProvider).fontFamily == family.id
            ? null
            : () => unawaited(_delete(family)),
      );
    }
    return PureIconButton(
      tooltip: context.t.fonts.download,
      icon: Icons.download_outlined,
      onPressed: () => unawaited(_download(family)),
    );
  }

  Future<void> _download(FontFamily family) async {
    setState(() => _downloading.add(family.id));
    try {
      await _library.download(family);
    } on Object {
      if (mounted) {
        PureToast.show(context, context.t.errors.network, type: PureToastType.error);
      }
    } finally {
      if (mounted) {
        setState(() => _downloading.remove(family.id));
      }
    }
  }

  Future<void> _delete(FontFamily family) async {
    final active = ref.read(appearancePreferencesProvider).fontFamily == family.id;
    if (active) {
      return;
    }
    await _library.delete(family.id);
    if (mounted) {
      setState(() {});
    }
  }
}
