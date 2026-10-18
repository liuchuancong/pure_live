import 'dart:io' show File;

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pure_live/app/providers/app_providers.dart';
import 'package:pure_live/app/theme/appearance_preferences/appearance_preferences.dart';
import 'package:pure_live/features/settings/widgets/settings_rows.dart';
import 'package:pure_live/features/wallpaper/wallpaper_background_layer.dart';
import 'package:pure_live/features/wallpaper/wallpaper_catalog.dart';
import 'package:pure_live/features/wallpaper/wallpaper_style.dart';
import 'package:pure_live/l10n/generated/strings.g.dart';
import 'package:pure_settings_ui/pure_settings_ui.dart';
import 'package:pure_uikit/pure_uikit.dart';
import 'package:pure_uikit_background/pure_uikit_background.dart' as bg;

/// The wallpaper picker (the reference's `WallpaperPage` plus the catalogue
/// part of its `WallpaperItemsPage`): a live preview, the built-in solid
/// and gradient presets, a picture from the device, and — for a picture —
/// the display controls the reference's display group held (fill mode,
/// dim, blur).
///
/// The page keeps its own scaffold transparent while a wallpaper is set, so
/// the layer it is configuring stays visible behind the controls — changing
/// a dim or a blur takes effect where the viewer is already looking.
///
/// Degraded from the reference on purpose: its network gallery, random-image
/// APIs and video wallpapers are out of scope for this build, so the
/// sources here are the compiled-in presets and a local picture.
final class WallpaperPickerPage extends ConsumerStatefulWidget {
  /// The wallpaper picker page.
  const new({super.key});

  @override
  ConsumerState<WallpaperPickerPage> createState() => _WallpaperPickerPageState();
}

final class _WallpaperPickerPageState extends ConsumerState<WallpaperPickerPage> {
  final TextEditingController _pathController = TextEditingController();

  @override
  void dispose() {
    _pathController.dispose();
    super.dispose();
  }

  Future<void> _update(AppearancePreferences Function(AppearancePreferences) change) =>
      ref.read(appearancePreferencesProvider.notifier).update(change);

  Future<void> _pickImage() async {
    final file = await openFile(
      acceptedTypeGroups: [
        const XTypeGroup(label: 'image', extensions: ['jpg', 'jpeg', 'png', 'webp', 'gif', 'bmp']),
      ],
    );
    if (file == null || file.path.isEmpty) {
      return;
    }
    await _update((a) => a.copyWith(wallpaperKind: WallpaperKind.image, wallpaperImagePath: file.path));
  }

  Future<void> _applyTypedPath() async {
    final path = _pathController.text.trim();
    if (path.isEmpty || !File(path).existsSync()) {
      PureToast.show(context, context.t.wallpaper.imageMissing, type: PureToastType.error);
      return;
    }
    await _update((a) => a.copyWith(wallpaperKind: WallpaperKind.image, wallpaperImagePath: path));
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final appearance = ref.watch(appearancePreferencesProvider);
    final config = ref.watch(wallpaperBackgroundConfigProvider);
    final hasWallpaper = config != null;
    final update = ref.read(appearancePreferencesProvider.notifier).update;
    return PureScaffold(
      // The reference's trick: the configuring page stands on the layer it
      // configures, so the change is visible where the viewer is looking.
      background: hasWallpaper ? Colors.transparent : null,
      appBar: PureAppBar(title: t.wallpaper.title),
      body: SettingsList(
        sections: [
          // The preview is the page's own card, drawn by the same dispatcher the
          // app-wide layer uses — a section's frame would fight it.
          SettingsSection(
            tiles: [CustomSettingsTile(child: _PreviewCard(config: config))],
          ),
          SettingsSection(
            title: Text(t.wallpaper.groupPresets),
            tiles: [
              SettingsTile.navigation(
                leading: const Icon(Icons.block_outlined),
                title: Text(t.wallpaper.none),
                description: Text(t.wallpaper.noneSubtitle),
                trailing: appearance.wallpaperKind == WallpaperKind.none
                    ? Icon(Icons.check_circle, color: PureTheme.of(context).colors.primary)
                    : null,
                onPressed: (_) => update((a) => a.copyWith(wallpaperKind: WallpaperKind.none)),
              ),
            ],
          ),
          SettingsSection(
            title: Text(t.wallpaper.groupSolid),
            tiles: [
              CustomSettingsTile(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                  child: Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      for (final preset in kWallpaperSolidPresets)
                        _SolidSwatch(
                          preset: preset,
                          selected:
                              appearance.wallpaperKind == WallpaperKind.solid &&
                              appearance.wallpaperColor == preset.argb,
                          onTap: () => update(
                            (a) => a.copyWith(wallpaperKind: WallpaperKind.solid, wallpaperColor: preset.argb),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          SettingsSection(
            title: Text(t.wallpaper.groupGradient),
            tiles: [
              CustomSettingsTile(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                  child: GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: 220,
                      mainAxisSpacing: 10,
                      crossAxisSpacing: 10,
                      childAspectRatio: 1.9,
                    ),
                    itemCount: kWallpaperGradientPresets.length,
                    itemBuilder: (context, index) {
                      final preset = kWallpaperGradientPresets[index];
                      return _GradientTile(
                        preset: preset,
                        selected:
                            appearance.wallpaperKind == WallpaperKind.gradient &&
                            appearance.wallpaperGradientColors.length == preset.argbColors.length &&
                            appearance.wallpaperGradientColors.first == preset.argbColors.first,
                        onTap: () => update(
                          (a) => a.copyWith(
                            wallpaperKind: WallpaperKind.gradient,
                            wallpaperGradientColors: preset.argbColors,
                            wallpaperGradientStops: preset.positions,
                            wallpaperGradientAngle: preset.angle,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
          SettingsSection(
            title: Text(t.wallpaper.groupDevice),
            tiles: [
              SettingsTile.navigation(
                leading: const Icon(Icons.image_outlined),
                title: Text(t.wallpaper.pickImage),
                description: Text(t.wallpaper.pickImageSubtitle),
                onPressed: (_) => _pickImage(),
              ),
              SettingsRowTile(
                row: PureListRow(
                  leading: const Icon(Icons.edit_location_alt_outlined, size: 22),
                  title: t.wallpaper.imagePath,
                  subtitle: appearance.wallpaperKind == WallpaperKind.image && appearance.wallpaperImagePath.isNotEmpty
                      ? appearance.wallpaperImagePath
                      : null,
                  trailing: SizedBox(
                    width: 220,
                    child: PureTextField(
                      controller: _pathController,
                      placeholder: t.wallpaper.imagePathHint,
                      keyboardType: TextInputType.url,
                      onSubmitted: (_) => _applyTypedPath(),
                    ),
                  ),
                  onTap: _applyTypedPath,
                ),
              ),
            ],
          ),
          if (appearance.wallpaperKind == WallpaperKind.image)
            SettingsSection(
              title: Text(t.wallpaper.groupDisplay),
              tiles: [
                CustomSettingsTile(
                  child: SettingsSliderRow(
                    icon: Icons.opacity_outlined,
                    title: t.wallpaper.scrim,
                    subtitle: t.wallpaper.scrimSubtitle,
                    value: appearance.wallpaperScrim.clamp(0.0, 1.0),
                    onChanged: (value) => update((a) => a.copyWith(wallpaperScrim: value)),
                  ),
                ),
                CustomSettingsTile(
                  child: SettingsSliderRow(
                    icon: Icons.blur_on_outlined,
                    title: t.wallpaper.blur,
                    subtitle: appearance.wallpaperBlur <= 0 ? t.wallpaper.blurOff : null,
                    value: appearance.wallpaperBlur.clamp(0.0, kWallpaperMaxBlurSigma),
                    max: kWallpaperMaxBlurSigma,
                    valueLabel: appearance.wallpaperBlur.toStringAsFixed(0),
                    onChanged: (value) => update((a) => a.copyWith(wallpaperBlur: value)),
                  ),
                ),
                CustomSettingsTile(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 6, 16, 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          t.wallpaper.fit,
                          style: PureTheme.of(context).text.caption
                              .copyWith(fontWeight: FontWeight.w700, color: PureTheme.of(context).colors.primary),
                        ),
                        const SizedBox(height: 8),
                        PureSegmented(
                          labels: [t.wallpaper.fitCover, t.wallpaper.fitContain, t.wallpaper.fitFill],
                          index: switch (appearance.wallpaperFit) {
                            'contain' => 1,
                            'fill' => 2,
                            _ => 0,
                          },
                          onChanged: (index) => update(
                            (a) => a.copyWith(
                              wallpaperFit: switch (index) {
                                1 => 'contain',
                                2 => 'fill',
                                _ => 'cover',
                              },
                            ),
                          ),
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
}

/// The current choice, painted by the same dispatcher the app-wide layer
/// uses, so the preview is the truth.
final class _PreviewCard extends StatelessWidget {
  const new({required this.config});

  final bg.BackgroundConfig? config;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    return ClipRRect(
      borderRadius: BorderRadius.circular(PureRadii.lg),
      child: SizedBox(
        height: 132,
        child: bg.PureBackground(
          config: config,
          child: Stack(
            children: [
              PositionedDirectional(
                start: 16,
                end: 16,
                bottom: 12,
                child: Text(
                  switch (config) {
                    null => t.wallpaper.currentNone,
                    bg.SolidBackground() => t.wallpaper.currentSolid,
                    bg.GradientBackground() => t.wallpaper.currentGradient,
                    bg.ImageBackground() => t.wallpaper.currentImage,
                    _ => '',
                  },
                  style: PureTheme.of(context).text.caption.copyWith(
                    color: Colors.white,
                    shadows: const [Shadow(blurRadius: 6, color: Colors.black54)],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One solid preset in the palette.
final class _SolidSwatch extends StatelessWidget {
  const new({required this.preset, required this.selected, required this.onTap});

  final WallpaperSolidPreset preset;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: preset.color,
          shape: BoxShape.circle,
          border: Border.all(
            color: selected ? PureTheme.of(context).colors.primary : PureTheme.of(context).colors.border,
            width: selected ? 3 : 1,
          ),
        ),
      ),
    );
  }
}

/// One gradient preset in the gallery.
final class _GradientTile extends StatelessWidget {
  const new({required this.preset, required this.selected, required this.onTap});

  final WallpaperGradientPreset preset;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final (begin, end) = gradientAlignment(preset.angle);
    return GestureDetector(
      onTap: onTap,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(PureRadii.md),
          border: Border.all(
            color: selected ? PureTheme.of(context).colors.primary : PureTheme.of(context).colors.border,
            width: selected ? 2 : 1,
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(PureRadii.md),
          child: Stack(
            fit: StackFit.expand,
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [for (final argb in preset.argbColors) Color(argb)],
                    stops: preset.positions,
                    begin: begin,
                    end: end,
                  ),
                ),
              ),
              PositionedDirectional(
                start: 8,
                bottom: 6,
                child: Text(
                  preset.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: PureTheme.of(context).text.caption.copyWith(
                    color: Colors.white,
                    shadows: const [Shadow(blurRadius: 4, color: Colors.black45)],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
