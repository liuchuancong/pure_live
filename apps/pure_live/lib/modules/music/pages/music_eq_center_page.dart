import 'dart:async' show unawaited;
import 'dart:ui' show ImageFilter;

import 'package:desen_ui/desen_ui.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:pure_live/l10n/translations.dart';
import 'package:pure_live/modules/music/controller/eq/music_eq_config.dart';
import 'package:pure_live/modules/music/controller/eq/music_eq_custom_presets.dart';
import 'package:pure_live/modules/music/controller/music_playback.dart' show musicPlayerProvider;
import 'package:pure_live/modules/music/pages/music_eq_editor.dart';
import 'package:pure_live/modules/music/pages/music_settings_pane.dart' show MusicEqPane, MusicFxRow;
import 'package:pure_live/shared/shared.dart' show cachedImage;

/// The sound-effect center — the spec's own page, drawn after the streaming
/// apps' own effect rooms: the current track's cover sits blurred behind the
/// effect in force, the presets are a colourful gallery one tap away, the
/// enhancement effects are inline instead of behind a dialog, and the
/// ten-band editor keeps its card under the response curve.
final class MusicEqCenterPage extends ConsumerWidget {
  /// Creates the page.
  const MusicEqCenterPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    final colors = DsTheme.colorsOf(context);
    final theme = DsTheme.of(context);
    final eq = ref.watch(musicEqProvider);
    final controller = ref.read(musicEqProvider.notifier);
    final custom = ref.watch(musicCustomPresetsProvider);
    final applyFailed = ref.watch(musicEqApplyFailedProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(DsSpace.s20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: DsSpace.s16,
        children: [
          // The hero: the cover blurred behind the effect in force, the way
          // the streaming apps stage their own effect rooms.
          _Hero(eq: eq),

          // The honesty rule: when the engine refused the chain, the page
          // says so instead of the switches sitting on over plain sound.
          if (applyFailed)
            _Card(
              child: Row(
                children: [
                  DsIcon(DsIcons.triangleAlert, size: 18, color: colors.danger.fill),
                  const SizedBox(width: DsSpace.s8),
                  Expanded(
                    child: Text(
                      t.music.eqApplyFailed,
                      style: theme.typography.caption.copyWith(color: colors.danger.fill),
                    ),
                  ),
                ],
              ),
            ),

          // The gallery: every official preset plus the viewer's own, one
          // tap applies, the one in force carries the ring.
          _Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: DsSpace.s12,
              children: [
                Row(
                  children: [
                    Expanded(child: Text(t.music.eqCenterRecommended, style: theme.typography.heading)),
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => unawaited(_pickPreset(context)),
                      child: Text(
                        '${t.music.eqMorePresets} ›',
                        style: theme.typography.caption.copyWith(color: colors.accent),
                      ),
                    ),
                  ],
                ),
                LayoutBuilder(
                  builder: (context, constraints) {
                    // Floor-width cards: six across on a wide shell, down to
                    // two on a phone, never squashed.
                    final cards = [
                      for (final preset in kMusicEqPresets)
                        _GalleryCard(
                          name: MusicEqPane.presetLabel(t, preset),
                          tag: _GalleryCard.presetTag(t, preset.id),
                          icon: _GalleryCard.icons[preset.id] ?? DsIcons.audioLines,
                          tint: _GalleryCard.tints[preset.id] ?? _GalleryCard.tints['flat']!,
                          selected: eq.presetId == preset.id,
                          onTap: () => unawaited(controller.applyPreset(preset)),
                        ),
                      for (final mine in custom)
                        _GalleryCard(
                          name: mine.name,
                          tag: t.music.eqPresetCustom,
                          icon: DsIcons.star,
                          tint: [colors.accent, Color.lerp(colors.accent, const Color(0xFF000000), 0.3)!],
                          selected: eq.presetId == '$kMusicCustomPresetPrefix${mine.id}',
                          onTap: () => unawaited(controller.applyCustomPreset(mine)),
                        ),
                    ];
                    final columns = (constraints.maxWidth / 150).floor().clamp(2, 8);
                    final rows = (cards.length / columns).ceil();
                    return Column(
                      spacing: DsSpace.s8,
                      children: [
                        for (var row = 0; row < rows; row++)
                          Row(
                            spacing: DsSpace.s8,
                            children: [
                              for (final card in cards.skip(row * columns).take(columns)) Expanded(child: card),
                            ],
                          ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),

          // The enhancement effects, inline: every switch and strength the
          // engine can actually ride, in the same rows the settings pane uses.
          _Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: DsSpace.s4,
              children: [
                Text(t.music.eqFxSection, style: theme.typography.heading),
                for (final id in kMusicFxOrder) MusicFxRow(id: id, eq: eq, controller: controller),
                for (final id in kMusicFxSpatialOrder) MusicFxRow(id: id, eq: eq, controller: controller),
              ],
            ),
          ),

          // The bands: the response curve and the ten handles, plus the
          // preamp that rides before them.
          _Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: DsSpace.s12,
              children: [
                Row(
                  children: [
                    Expanded(child: Text(t.music.eqCenterBands, style: theme.typography.heading)),
                    Text(
                      t.music.eqCenterBandsCaption,
                      style: theme.typography.caption.copyWith(color: colors.textMuted),
                    ),
                  ],
                ),
                const MusicEqEditor(),
                Row(
                  children: [
                    Expanded(child: Text(t.music.eqPreamp)),
                    Text(
                      '${eq.preampDb >= 0 ? '+' : ''}${eq.preampDb.toStringAsFixed(1)} dB',
                      style: theme.typography.caption.copyWith(color: colors.textMuted),
                    ),
                  ],
                ),
                DsSlider(
                  value: (eq.preampDb - kMusicEqMinPreamp) / (kMusicEqMaxPreamp - kMusicEqMinPreamp),
                  semanticLabel: t.music.eqPreamp,
                  onChanged: eq.enabled
                      ? (value) => unawaited(
                          controller.setPreamp(kMusicEqMinPreamp + value * (kMusicEqMaxPreamp - kMusicEqMinPreamp)),
                        )
                      : null,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickPreset(BuildContext context) async {
    await showDsDialog<Object?>(context: context, builder: (dialogContext) => const _PresetDialog());
  }
}

/// The hero card: the current track's cover blurred behind a surface scrim,
/// the effect in force in large type, the master switch at the right.
final class _Hero extends ConsumerWidget {
  const _Hero({required this.eq});

  final MusicEqConfig eq;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    final colors = DsTheme.colorsOf(context);
    final theme = DsTheme.of(context);
    final custom = ref.watch(musicCustomPresetsProvider);
    final player = ref.watch(musicPlayerProvider);
    final track = player.track;
    final cover = track?.coverUri;

    return ClipRRect(
      borderRadius: BorderRadius.circular(theme.radii.card),
      child: Stack(
        fit: StackFit.passthrough,
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [colors.accent.withValues(alpha: 0.30), colors.surface],
                ),
              ),
            ),
          ),
          if (cover != null)
            Positioned.fill(
              child: ImageFiltered(
                imageFilter: ImageFilter.blur(sigmaX: 28, sigmaY: 28),
                child: Opacity(
                  opacity: 0.35,
                  child: DsImage(
                    image: cachedImage(cover.toString()),
                    semanticLabel: track?.title,
                  ),
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(DsSpace.s20),
            child: Row(
              children: [
                _HeroCover(cover: cover, title: track?.title),
                const SizedBox(width: DsSpace.s16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    spacing: DsSpace.s4,
                    children: [
                      Text(
                        t.music.eqCenterNow,
                        style: theme.typography.caption.copyWith(
                          color: eq.enabled ? colors.accent : colors.textMuted,
                        ),
                      ),
                      Text(
                        _presetName(t, eq.presetId, custom),
                        style: theme.typography.heading,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        track == null
                            ? t.music.eqCenterSubtitle
                            : '${track.title} · ${track.artist}',
                        style: theme.typography.caption.copyWith(color: colors.textMuted),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: DsSpace.s12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  spacing: DsSpace.s8,
                  children: [
                    Text(
                      eq.enabled ? t.music.eqCenterEnabled : t.music.eqCenterDisabled,
                      style: theme.typography.caption.copyWith(
                        color: eq.enabled ? colors.accent : colors.textMuted,
                      ),
                    ),
                    DsSwitch(
                      value: eq.enabled,
                      onChanged: (value) =>
                          unawaited(ref.read(musicEqProvider.notifier).update(eq.copyWith(enabled: value))),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// The preset in force's display name: the viewer's own preset by its
  /// name, a built-in by its label, a hand-tuned curve by 自定义.
  static String _presetName(Translations t, String? presetId, List<MusicCustomEqPreset> presets) {
    final parsed = customPresetIdOf(presetId);
    if (parsed != null) {
      for (final preset in presets) {
        if (preset.id == parsed.$2) return preset.name;
      }
    }
    if (presetId != null) {
      for (final preset in kMusicEqPresets) {
        if (preset.id == presetId) return MusicEqPane.presetLabel(t, preset);
      }
    }
    return t.music.eqPresetCustom;
  }
}

/// The hero's square: the cover when there is one, a note glyph otherwise.
final class _HeroCover extends ConsumerWidget {
  const _HeroCover({required this.cover, required this.title});

  final Uri? cover;
  final String? title;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = DsTheme.colorsOf(context);
    final theme = DsTheme.of(context);
    final radius = BorderRadius.circular(theme.radii.overlay);
    if (cover == null) {
      return Container(
        width: 72,
        height: 72,
        decoration: DsBoxDecoration(color: colors.control, borderRadius: radius),
        child: Center(child: DsIcon(DsIcons.music, size: 32, color: colors.textSubtle)),
      );
    }
    return ClipRRect(
      borderRadius: radius,
      child: DsImage(image: cachedImage(cover.toString()), width: 72, height: 72, semanticLabel: title),
    );
  }
}

/// One panel of the page: a rounded surface on the theme's card colour.
final class _Card extends ConsumerWidget {
  const _Card({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = DsTheme.colorsOf(context);
    final theme = DsTheme.of(context);
    return Container(
      padding: const EdgeInsets.all(DsSpace.s16),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(theme.radii.card),
        border: Border.all(color: colors.border.withValues(alpha: 0.4)),
      ),
      child: child,
    );
  }
}

/// One gallery card: a fixed vivid tile per preset — the streaming apps'
/// artwork treatment — its name and scene hint under it; the preset in
/// force carries the accent ring and the in-use mark.
final class _GalleryCard extends ConsumerWidget {
  const _GalleryCard({
    required this.name,
    required this.tag,
    required this.icon,
    required this.tint,
    required this.selected,
    required this.onTap,
  });

  final String name;
  final String tag;
  final DsIconData icon;
  final List<Color> tint;
  final bool selected;
  final VoidCallback onTap;

  /// One vivid pair per id, fixed like artwork rather than themed — the
  /// gallery should read the same at night as by day.
  static const Map<String, List<Color>> tints = <String, List<Color>>{
    'pop': [Color(0xFFFF7A9C), Color(0xFFE8467C)],
    'rock': [Color(0xFFFF9F57), Color(0xFFE85446)],
    'classical': [Color(0xFFF6C560), Color(0xFFD98E32)],
    'jazz': [Color(0xFFB48BE8), Color(0xFF7D4FD3)],
    'electronic': [Color(0xFF5EC9F0), Color(0xFF2D7FE0)],
    'bass': [Color(0xFF6E8DF5), Color(0xFF4054D6)],
    'vocal': [Color(0xFF5FD4B4), Color(0xFF22A98A)],
    'live': [Color(0xFFFF8B6B), Color(0xFFD9503F)],
    'flat': [Color(0xFF9AA5B5), Color(0xFF64707F)],
  };

  static const Map<String, DsIconData> icons = <String, DsIconData>{
    'pop': DsIcons.music,
    'rock': DsIcons.guitar,
    'classical': DsIcons.music2,
    'jazz': DsIcons.drum,
    'electronic': DsIcons.audioWaveform,
    'bass': DsIcons.speaker,
    'vocal': DsIcons.micVocal,
    'live': DsIcons.radio,
    'flat': DsIcons.audioLines,
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    final colors = DsTheme.colorsOf(context);
    final theme = DsTheme.of(context);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: DsSpace.s12, horizontal: DsSpace.s4),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(theme.radii.control(36)),
          border: Border.all(
            color: selected ? colors.accent : colors.border.withValues(alpha: 0.4),
            width: selected ? 2 : 1,
          ),
        ),
        child: Column(
          spacing: DsSpace.s6,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: tint),
                borderRadius: BorderRadius.circular(theme.radii.control(36)),
              ),
              child: Center(child: DsIcon(icon, size: 22, color: const Color(0xFFFFFFFF))),
            ),
            Text(name, style: theme.typography.body, overflow: TextOverflow.ellipsis),
            Text(
              selected ? t.music.eqInUse : tag,
              style: theme.typography.caption.copyWith(color: selected ? colors.accent : colors.textMuted),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  /// The card's second line — a scene hint, not a second name.
  static String presetTag(Translations t, String id) => switch (id) {
    'pop' => t.music.eqTagPop,
    'rock' => t.music.eqTagRock,
    'classical' => t.music.eqTagClassical,
    'jazz' => t.music.eqTagJazz,
    'electronic' => t.music.eqTagElectronic,
    'bass' => t.music.eqTagBass,
    'vocal' => t.music.eqTagVocal,
    'live' => t.music.eqTagLive,
    _ => t.music.eqTagFlat,
  };
}

/// The preset picker: the official list with one-tap apply, and the
/// viewer's own presets beside them.
final class _PresetDialog extends ConsumerStatefulWidget {
  const _PresetDialog();

  @override
  ConsumerState<_PresetDialog> createState() => _PresetDialogState();
}

final class _PresetDialogState extends ConsumerState<_PresetDialog> {
  var _mine = false;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final theme = DsTheme.of(context);
    final colors = DsTheme.colorsOf(context);
    final eq = ref.watch(musicEqProvider);
    final controller = ref.read(musicEqProvider.notifier);
    return DsDialog(
      title: Text(t.music.eqCenterPickTitle),
      icon: const DsIcon(DsIcons.music4),
      description: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: DsSpace.s8,
        children: [
          DsSegmentedControl<bool>(
            segments: [
              DsSegment(value: false, label: Text(t.music.eqOfficialPresets)),
              DsSegment(value: true, label: Text(t.music.eqMyPresets)),
            ],
            value: _mine,
            onChanged: (mine) => setState(() => _mine = mine),
          ),
          if (_mine)
            const _MyPresetsList()
          else
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 380),
              // Ten presets stand taller than the cap; the list scrolls
              // where it ends, as the viewer's own tab does.
              child: SingleChildScrollView(
                child: Column(
                  spacing: DsSpace.s4,
                  children: [
                    for (final preset in kMusicEqPresets)
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(MusicEqPane.presetLabel(t, preset), style: theme.typography.body),
                                Text(
                                  _GalleryCard.presetTag(t, preset.id),
                                  style: theme.typography.caption.copyWith(color: colors.textMuted),
                                ),
                              ],
                            ),
                          ),
                          if (eq.presetId == preset.id)
                            Text(t.music.eqInUse, style: theme.typography.caption.copyWith(color: colors.accent))
                          else
                            DsButton(
                              variant: DsButtonVariant.secondary,
                              size: DsSize.sm,
                              onPressed: () => unawaited(controller.applyPreset(preset)),
                              child: Text(t.music.eqUse),
                            ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
        ],
      ),
      actions: [
        DsButton(
          variant: DsButtonVariant.secondary,
          onPressed: () => Navigator.of(context).pop(),
          child: Text(t.common.close),
        ),
      ],
    );
  }
}

/// The viewer's own presets: save the curve in force under a name, apply,
/// delete — the picker's second tab, no longer an honest empty shelf.
final class _MyPresetsList extends ConsumerWidget {
  const _MyPresetsList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    final theme = DsTheme.of(context);
    final colors = DsTheme.colorsOf(context);
    final mine = ref.watch(musicCustomPresetsProvider);
    final eq = ref.watch(musicEqProvider);
    final custom = ref.read(musicCustomPresetsProvider.notifier);
    final eqController = ref.read(musicEqProvider.notifier);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: DsSpace.s4,
      children: [
        DsButton(
          variant: DsButtonVariant.secondary,
          size: DsSize.sm,
          onPressed: () => unawaited(_saveCurrent(context, ref)),
          child: Text(t.music.eqSavePreset),
        ),
        if (mine.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: DsSpace.s12),
            child: Text(t.music.eqMyPresetsEmpty, style: theme.typography.caption.copyWith(color: colors.textMuted)),
          )
        else
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 300),
            child: SingleChildScrollView(
              child: Column(
                spacing: DsSpace.s4,
                children: [
                  for (final preset in mine)
                    Row(
                      children: [
                        Expanded(
                          child: Text(preset.name, style: theme.typography.body, overflow: TextOverflow.ellipsis),
                        ),
                        if (eq.presetId == '$kMusicCustomPresetPrefix${preset.id}')
                          Text(t.music.eqInUse, style: theme.typography.caption.copyWith(color: colors.accent))
                        else
                          DsButton(
                            variant: DsButtonVariant.secondary,
                            size: DsSize.sm,
                            onPressed: () => unawaited(eqController.applyCustomPreset(preset)),
                            child: Text(t.music.eqUse),
                          ),
                        GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () => unawaited(custom.remove(preset.id)),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: DsSpace.s8, vertical: DsSpace.s4),
                            child: DsIcon(DsIcons.trash2, size: 16, color: colors.textMuted),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

/// Names the curve in force and shelves it; the saved preset takes over as
/// the preset in force, so the picker's highlight agrees with what plays.
Future<void> _saveCurrent(BuildContext context, WidgetRef ref) async {
  final t = context.t;
  final field = TextEditingController();
  final name = await showDsDialog<String>(
    context: context,
    builder: (dialogContext) => DsDialog(
      title: Text(t.music.eqSavePreset),
      icon: const DsIcon(DsIcons.star),
      description: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: DsSpace.s8,
        children: [
          Text(t.music.eqPresetNameHint, style: DsTheme.of(dialogContext).typography.caption),
          DsTextField(controller: field, autofocus: true, semanticLabel: t.music.eqPresetNameLabel),
        ],
      ),
      actions: [
        DsButton(
          variant: DsButtonVariant.secondary,
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: Text(t.common.cancel),
        ),
        DsButton(onPressed: () => Navigator.of(dialogContext).pop(field.text), child: Text(t.common.confirm)),
      ],
    ),
  );
  field.dispose();
  final trimmed = name?.trim();
  if (trimmed == null || trimmed.isEmpty) return;
  // The shelf may be gone while its dialog was up — or gone again while
  // the save writes; a dead element's ref must not be reached twice.
  if (!context.mounted) return;
  final saved = await ref.read(musicCustomPresetsProvider.notifier).save(trimmed);
  if (!context.mounted) return;
  await ref.read(musicEqProvider.notifier).applyCustomPreset(saved);
}
