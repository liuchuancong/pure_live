import 'dart:async' show unawaited;

import 'package:desen_ui/desen_ui.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:pure_live/l10n/translations.dart';
import 'package:pure_live/modules/music/controller/eq/music_eq_config.dart';
import 'package:pure_live/modules/music/pages/music_eq_editor.dart';
import 'package:pure_live/modules/music/pages/music_settings_pane.dart' show MusicEqPane;

/// The sound-effect center — the spec's own page, not a settings subpage:
/// the master switch up top, the preset in force, the recommended presets,
/// and the ten-band editor under the response curve, with the preset picker
/// and the enhancement effects one tap away in their dialogs.
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

    return SingleChildScrollView(
      padding: const EdgeInsets.all(DsSpace.s20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: DsSpace.s16,
        children: [
        // The header card: what this page is, and whether any of it runs.
        _Card(
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: colors.accent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(theme.radii.control(36)),
                ),
                child: const Center(child: DsIcon(DsIcons.audioLines)),
              ),
              const SizedBox(width: DsSpace.s12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(t.music.eqCenter, style: theme.typography.heading),
                    Text(
                      t.music.eqCenterSubtitle,
                      style: theme.typography.caption.copyWith(color: colors.textMuted),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: DsSpace.s12),
              Text(
                eq.enabled ? t.music.eqCenterEnabled : t.music.eqCenterDisabled,
                style: theme.typography.caption.copyWith(color: eq.enabled ? colors.accent : colors.textMuted),
              ),
              DsSwitch(
                value: eq.enabled,
                onChanged: (value) => unawaited(controller.update(eq.copyWith(enabled: value))),
              ),
            ],
          ),
        ),

        // The preset in force: its name opens the picker, the three quick
        // buttons jump at the bands and the enhancement effects.
        _Card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: DsSpace.s8,
            children: [
              Text(t.music.eqCurrent, style: theme.typography.caption.copyWith(color: colors.textMuted)),
              Row(
                children: [
                  Flexible(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => unawaited(_pickPreset(context, ref)),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Flexible(
                            child: Text(
                              eq.presetId != null
                                  ? MusicEqPane.presetLabel(t, _presetOf(eq.presetId!))
                                  : t.music.eqPresetCustom,
                              style: theme.typography.title,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: DsSpace.s4),
                          const DsIcon(DsIcons.chevronDown, size: 18),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: DsSpace.s8),
                  if (eq.presetId == null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: DsSpace.s8, vertical: 2),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: colors.accent),
                      ),
                      child: Text(
                        t.music.eqPresetCustom,
                        style: theme.typography.caption.copyWith(color: colors.accent),
                      ),
                    ),
                ],
              ),
              Row(
                spacing: DsSpace.s8,
                children: [
                  _QuickButton(
                    icon: DsIcons.slidersVertical,
                    label: t.music.eqCenterEqualizer,
                    onTap: () => unawaited(_scrollToBands(context)),
                  ),
                  _QuickButton(
                    icon: DsIcons.micVocal,
                    label: t.music.eqFxVocal,
                    onTap: () => unawaited(_showEffects(context)),
                  ),
                  _QuickButton(
                    icon: DsIcons.waves,
                    label: t.music.eqFxSurround,
                    onTap: () => unawaited(_showEffects(context)),
                  ),
                ],
              ),
              Text(
                _presetNote(t, eq.presetId),
                style: theme.typography.caption.copyWith(color: colors.textMuted),
              ),
            ],
          ),
        ),

        // The recommended six: one tap applies the preset.
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: DsSpace.s8,
          children: [
            Row(
              children: [
                Expanded(child: Text(t.music.eqCenterRecommended, style: theme.typography.heading)),
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => unawaited(_pickPreset(context, ref)),
                  child: Text(
                    '${t.music.eqMorePresets} ›',
                    style: theme.typography.caption.copyWith(color: colors.accent),
                  ),
                ),
              ],
            ),
            LayoutBuilder(
              builder: (context, constraints) {
                // Six across on a wide shell, two on a phone — the cards
                // keep a floor width instead of squashing.
                final columns = (constraints.maxWidth / 180).floor().clamp(2, 6);
                final rows = (kRecommendedPresetIds.length / columns).ceil();
                return Column(
                  spacing: DsSpace.s8,
                  children: [
                    for (var row = 0; row < rows; row++)
                      Row(
                        spacing: DsSpace.s8,
                        children: [
                          for (final id in kRecommendedPresetIds.skip(row * columns).take(columns))
                            Expanded(
                              child: _PresetCard(
                                preset: _presetOf(id),
                                selected: eq.presetId == id,
                                onTap: () => unawaited(controller.applyPreset(_presetOf(id))),
                              ),
                            ),
                        ],
                      ),
                  ],
                );
              },
            ),
          ],
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
                        controller.setPreamp(
                          kMusicEqMinPreamp + value * (kMusicEqMaxPreamp - kMusicEqMinPreamp),
                        ),
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

  static const List<String> kRecommendedPresetIds = <String>[
    'pop',
    'rock',
    'classical',
    'jazz',
    'electronic',
    'bass',
  ];

  static MusicEqPreset _presetOf(String id) =>
      kMusicEqPresets.firstWhere((preset) => preset.id == id, orElse: () => kMusicEqPresets.first);

  static String _presetNote(Translations t, String? presetId) => switch (presetId) {
    'vocal' => t.music.eqNoteVocal,
    'bass' => t.music.eqNoteBass,
    'classical' => t.music.eqNoteClassical,
    _ => t.music.eqPresetDesc,
  };

  Future<void> _scrollToBands(BuildContext context) async {
    await Scrollable.ensureVisible(
      context,
      duration: const Duration(milliseconds: 300),
      alignment: 0.8,
    );
  }

  Future<void> _showEffects(BuildContext context) async {
    await showDsDialog<Object?>(
      context: context,
      builder: (dialogContext) => const _EffectsDialog(),
    );
  }

  Future<void> _pickPreset(BuildContext context, WidgetRef ref) async {
    await showDsDialog<Object?>(
      context: context,
      builder: (dialogContext) => const _PresetDialog(),
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

/// A small labelled square button — the current-effect card's quick jumps.
final class _QuickButton extends ConsumerWidget {
  const _QuickButton({required this.icon, required this.label, required this.onTap});

  final DsIconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = DsTheme.colorsOf(context);
    final theme = DsTheme.of(context);
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: DsSpace.s8),
          decoration: BoxDecoration(
            color: colors.control,
            borderRadius: BorderRadius.circular(theme.radii.control(36)),
          ),
          child: Column(
            spacing: DsSpace.s4,
            children: [
              DsIcon(icon, size: 18, color: colors.accent),
              Text(label, style: theme.typography.caption, overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
      ),
    );
  }
}

/// One recommended preset: a tinted glyph, its name and its tag line; the
/// preset in force carries the ring.
final class _PresetCard extends ConsumerWidget {
  const _PresetCard({required this.preset, required this.selected, required this.onTap});

  final MusicEqPreset preset;
  final bool selected;
  final VoidCallback onTap;

  static const Map<String, DsIconData> _icons = <String, DsIconData>{
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
          spacing: DsSpace.s4,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: colors.accent.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(theme.radii.control(36)),
              ),
              child: Center(child: DsIcon(_icons[preset.id] ?? DsIcons.audioLines, size: 18)),
            ),
            Text(MusicEqPane.presetLabel(t, preset), style: theme.typography.body, overflow: TextOverflow.ellipsis),
            Text(
              presetTag(t, preset.id),
              style: theme.typography.caption.copyWith(color: colors.textMuted),
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

/// The preset picker: the official list with one-tap apply, and the viewer's
/// own presets — honestly empty until the spec's custom presets exist.
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
            Padding(
              padding: const EdgeInsets.symmetric(vertical: DsSpace.s12),
              child: Text(
                t.music.eqMyPresetsEmpty,
                style: theme.typography.caption.copyWith(color: colors.textMuted),
              ),
            )
          else
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 380),
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
                                _PresetCard.presetTag(t, preset.id),
                                style: theme.typography.caption.copyWith(color: colors.textMuted),
                              ),
                            ],
                          ),
                        ),
                        if (eq.presetId == preset.id)
                          Text(
                            t.music.eqInUse,
                            style: theme.typography.caption.copyWith(color: colors.accent),
                          )
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

/// The enhancement effects: every switch and strength the DSP chain really
/// carries — no row for an effect the chain cannot apply.
final class _EffectsDialog extends ConsumerWidget {
  const _EffectsDialog();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    final theme = DsTheme.of(context);
    final colors = DsTheme.colorsOf(context);
    final eq = ref.watch(musicEqProvider);
    final controller = ref.read(musicEqProvider.notifier);
    return DsDialog(
      title: Text(t.music.eqFxSection),
      icon: const DsIcon(DsIcons.slidersHorizontal),
      description: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: DsSpace.s12,
        children: [
          for (final id in kMusicFxOrder)
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: DsSpace.s4,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(_fxLabel(t, id), style: theme.typography.body),
                          Text(
                            _fxDescription(t, id),
                            style: theme.typography.caption.copyWith(color: colors.textMuted),
                          ),
                        ],
                      ),
                    ),
                    DsSwitch(
                      value: eq.effectOf(id).enabled,
                      onChanged: (value) => unawaited(controller.setEffect(id, enabled: value)),
                    ),
                  ],
                ),
                Row(
                  children: [
                    Text(
                      '${t.music.eqCenterStrength} ${(eq.effectOf(id).amount * 100).round()}%',
                      style: theme.typography.caption.copyWith(color: colors.textMuted),
                    ),
                    const SizedBox(width: DsSpace.s8),
                    Expanded(
                      child: DsSlider(
                        value: eq.effectOf(id).amount,
                        semanticLabel: t.music.eqCenterStrength,
                        onChanged: eq.effectOf(id).enabled
                            ? (value) => unawaited(controller.setEffect(id, amount: value))
                            : null,
                      ),
                    ),
                  ],
                ),
              ],
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

/// The effect's display name — the ids the DSP chain knows, the words the
/// listener does.
String _fxLabel(Translations t, String id) => switch (id) {
  'loudness' => t.music.eqFxLoudness,
  'bass' => t.music.eqFxBass,
  'vocal' => t.music.eqFxVocal,
  'width' => t.music.eqFxWidth,
  'surround' => t.music.eqFxSurround,
  _ => t.music.eqFxDynamics,
};

/// The effect's one-line description, the filter it really rides.
String _fxDescription(Translations t, String id) => switch (id) {
  'loudness' => t.music.eqFxLoudnessDesc,
  'bass' => t.music.eqFxBassDesc,
  'vocal' => t.music.eqFxVocalDesc,
  'width' => t.music.eqFxWidthDesc,
  'surround' => t.music.eqFxSurroundDesc,
  _ => t.music.eqFxDynamicsDesc,
};
