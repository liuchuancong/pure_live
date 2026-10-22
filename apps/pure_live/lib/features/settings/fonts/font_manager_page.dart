import 'dart:async' show unawaited;
import 'dart:io' show File;

import 'package:file_selector/file_selector.dart' show XTypeGroup, openFile;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pure_live/app/app_providers.dart';
import 'package:pure_live/features/settings/widgets/settings_rows.dart';
import 'package:pure_live/l10n/generated/strings.g.dart';
import 'package:pure_live/system/resources/font_library.dart';
import 'package:pure_live/system/theme/font_recommendations.dart';
import 'package:pure_settings_ui/pure_settings_ui.dart';
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
    final cloud = _families;
    // The skin currently rendering decides WHICH family 跟随设计语言 means,
    // and the library says whether that family's files are on disk yet.
    final language = ref.watch(uiStartupConfigProvider).language;
    final recommended = recommendedFontFor(language);
    // A skin with no owning platform promises nothing forced — the system
    // default draws. An installed one is already on the machine; a
    // downloadable pick only counts once its files are in the font tree.
    final String followSubtitle;
    if (recommended.source == RecommendedFontSource.none) {
      followSubtitle = context.t.fonts.followThemeDesc;
    } else if (recommended.source != RecommendedFontSource.downloadable || _library.isDownloaded(recommended.family)) {
      followSubtitle = context.t.fonts.followThemeCurrent(name: recommended.name);
    } else {
      followSubtitle = '${context.t.fonts.followThemeCurrent(name: recommended.name)} · '
          '${context.t.fonts.followThemeMissing}';
    }
    // The imported families are read from disk on every build: they are a
    // directory listing of the fonts tree, and the page has to show a font the
    // user imported a second ago without a reload.
    final imported = _library.installedFamilies();
    return PureScaffold(
      appBar: PureAppBar(title: context.t.settings.fonts),
      body: SettingsList(
        sections: [
          SettingsSection(
            title: Text(context.t.fonts.factoryDefault),
            tiles: [
              SettingsRowTile(
                row: _row(
                  context,
                  title: context.t.fonts.followTheme,
                  subtitle: followSubtitle,
                  selected: appearance.fontFamily == kThemeFontFamily,
                  action: appearance.fontFamily == kThemeFontFamily
                      ? null
                      : () => update((a) => a.copyWith(fontFamily: kThemeFontFamily)),
                ),
              ),
              SettingsRowTile(
                row: _row(
                  context,
                  title: context.t.fonts.system,
                  subtitle: context.t.fonts.systemDesc,
                  selected: appearance.fontFamily.isEmpty,
                  action: appearance.fontFamily.isEmpty ? null : () => update((a) => a.copyWith(fontFamily: '')),
                ),
              ),
            ],
          ),
          // The official faces shipped inside the app: always drawable,
          // nothing to fetch. A download from the cloud section (or an
          // import) simply replaces the choice — the presets stay as the
          // fallback 跟随设计语言 resolves to.
          SettingsSection(
            title: Text(context.t.fonts.presets),
            tiles: [
              for (final preset in kBundledFonts)
                SettingsRowTile(
                  row: _row(
                    context,
                    title: preset.name,
                    subtitle: context.t.fonts.presetsDesc,
                    selected: appearance.fontFamily == preset.family,
                    action: appearance.fontFamily == preset.family
                        ? null
                        : () => update((a) => a.copyWith(fontFamily: preset.family)),
                  ),
                ),
            ],
          ),
          // Everything on disk needs no network — the user's imports AND the
          // official platform faces installed outside the manifest: the
          // manifest may be unreachable, and this list still has to be
          // readable, so the section sits outside the cloud one's loading
          // and error states.
          SettingsSection(
            title: Text(context.t.fonts.onThisDevice),
            tiles: [
              SettingsRowTile(
                row: PureListRow(
                  leading: const Icon(Icons.add_circle_outline),
                  title: context.t.fonts.import,
                  subtitle: context.t.fonts.customDesc,
                  onTap: _import,
                ),
              ),
              for (var i = 0; i < imported.length; i++)
                SettingsRowTile(
                  row: _row(
                    context,
                    title: imported[i].name,
                    selected: appearance.fontFamily == imported[i].id,
                    action: () => update((a) => a.copyWith(fontFamily: imported[i].id)),
                    trailing: PureIconButton(
                      tooltip: context.t.fonts.delete,
                      icon: Icons.delete_outline,
                      onPressed: appearance.fontFamily == imported[i].id ? null : () => unawaited(_delete(imported[i])),
                    ),
                    divided: i < imported.length - 1,
                  ),
                ),
            ],
          ),
          if (cloud == null && _error != null)
            SettingsSection(
              title: Text(context.t.fonts.cloudFonts),
              tiles: [
                SettingsRowTile(
                  row: PureListRow(
                    leading: const Icon(Icons.cloud_off_outlined),
                    title: context.t.errors.network,
                    trailing: PureButton(
                      label: context.t.common.retry,
                      icon: Icons.refresh,
                      variant: ButtonVariant.secondary,
                      onPressed: _loadFamilies,
                    ),
                  ),
                ),
              ],
            )
          else if (cloud == null)
            SettingsSection(
              tiles: [
                SettingsRowTile(
                  row: const SizedBox(height: 48, child: Center(child: PureSpinner(size: 24))),
                ),
              ],
            )
          else if (cloud.isNotEmpty)
            SettingsSection(
              title: Text(context.t.fonts.cloudFonts),
              tiles: [
                // A cloud family is a radio row with an action of its own (a
                // download, a delete), which the kit's tiles do not model — the
                // rows stay the uikit's, inside the section's card.
                for (var i = 0; i < cloud.length; i++)
                  SettingsRowTile(
                    row: _row(
                      context,
                      title: cloud[i].id == recommended.family
                          ? '${cloud[i].name}（${context.t.fonts.recommended}）'
                          : cloud[i].name,
                      subtitle: cloud[i].description,
                      selected: appearance.fontFamily == cloud[i].id,
                      action: _library.isDownloaded(cloud[i].id)
                          ? () => update((a) => a.copyWith(fontFamily: cloud[i].id))
                          : null,
                      trailing: _familyAction(context, cloud[i]),
                      divided: i < cloud.length - 1,
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }

  /// Opens the platform's file picker, copies the chosen font into the library
  /// and selects it — a user who imported a font came to use it.
  Future<void> _import() async {
    const group = XTypeGroup(label: 'fonts', extensions: FontLibrary.importExtensions);
    final picked = await openFile(acceptedTypeGroups: [group]);
    if (picked?.path case final path?) {
      try {
        final id = await _library.importFile(File(path));
        if (!mounted) {
          return;
        }
        await ref.read(appearancePreferencesProvider.notifier).update((a) => a.copyWith(fontFamily: id));
        if (mounted) {
          setState(() {});
        }
      } on Object {
        if (mounted) {
          PureToast.show(context, context.t.fonts.importFailed, type: PureToastType.error);
        }
      }
    }
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
