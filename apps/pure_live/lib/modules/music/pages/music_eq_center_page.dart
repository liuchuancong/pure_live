import 'dart:async' show StreamSubscription, unawaited;
import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:desen_ui/desen_ui.dart';
import 'package:flutter/services.dart' show LogicalKeyboardKey;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_cache/live_cache.dart' show ImageCachePolicies;
import 'package:media_core_audio/media_core_audio.dart' as audio;

import 'package:pure_live/app/background/glass/live_glass.dart' show kLiveGlassCoverFrostSigma;
import 'package:pure_live/l10n/translations.dart';
import 'package:pure_live/modules/music/controller/eq/music_eq_config.dart';
import 'package:pure_live/modules/music/controller/eq/music_eq_custom_presets.dart';
import 'package:pure_live/modules/music/controller/music_playback.dart' show MusicPlayerController, musicPlayerProvider;
import 'package:pure_live/modules/music/pages/music_eq_editor.dart';
import 'package:pure_live/modules/music/pages/music_settings_pane.dart' show MusicEqPane, MusicFxRow;
import 'package:pure_live/modules/music/widgets/music_browse_widgets.dart' show MusicBrowseHeader;
import 'package:pure_live/shared/shared.dart' show TvFocusScale, cachedImage;

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
                    DsLink(label: '${t.music.eqMorePresets} ›', onPressed: () => unawaited(_pickPreset(context))),
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

          // A/B compare: hold the button and the song plays as the source is,
          // so the chain built here can be heard against the song without
          // leaving the page for the settings.
          _Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: DsSpace.s4,
              children: [
                Text(t.music.eqCompareTitle, style: theme.typography.heading),
                _CompareButton(player: ref.read(musicPlayerProvider.notifier)),
              ],
            ),
          ),

          // The nodes the chain rides on, listed with the room left to add one
          // and the count saying how much of that room is used.
          _Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: DsSpace.s4,
              children: [
                Row(
                  children: [
                    Expanded(child: Text(t.music.eqNodesTitle, style: theme.typography.heading)),
                    Text(
                      '${eq.nodes.length} / $kMusicEqMaxNodes',
                      style: theme.typography.caption.copyWith(color: colors.textMuted),
                    ),
                  ],
                ),
                for (final node in eq.nodes) _EqNodeRow(node: node, eq: eq, controller: controller),
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: DsButton(
                    variant: DsButtonVariant.secondary,
                    size: DsSize.sm,
                    leading: const DsIcon(DsIcons.plus, size: 16),
                    onPressed: eq.nodes.length >= kMusicEqMaxNodes ? null : () => unawaited(controller.addNode()),
                    child: Text(t.music.eqNodesAdd),
                  ),
                ),
              ],
            ),
          ),

          // The loudness meter: the engine's own analysis branch, off until
          // asked for, with the caption that says what the two bars are.
          _Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: DsSpace.s4,
              children: [
                Row(
                  children: [
                    Expanded(child: Text(t.music.eqMeterTitle, style: theme.typography.heading)),
                    DsSwitch(
                      value: eq.analysis,
                      semanticLabel: t.music.eqAnalysis,
                      onChanged: (value) => unawaited(controller.setAnalysis(value: value)),
                    ),
                  ],
                ),
                _LoudnessMeter(active: eq.analysis),
                Text(t.music.eqMeterNote, style: theme.typography.caption.copyWith(color: colors.textMuted)),
              ],
            ),
          ),

          // What the switches above add up to, in the engine's own words: the
          // honesty line belongs where the chain is built.
          Text(t.music.eqChainNote, style: theme.typography.caption.copyWith(color: colors.textMuted)),
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
    final track = ref.watch(musicPlayerProvider.select((state) => state.track));
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
              child: ClipRect(
                child: ImageFiltered(
                  imageFilter: ImageFilter.blur(sigmaX: kLiveGlassCoverFrostSigma, sigmaY: kLiveGlassCoverFrostSigma),
                  child: Opacity(
                    opacity: 0.35,
                    // The backdrop is a bleed, not a card: it takes the
                    // hero's whole box, so it is the plain cover-filling
                    // image the player and the recommend hero already use —
                    // a DsImage would have to be handed a reserved box it
                    // does not own. The scale keeps the blur sampling solid
                    // to the edges instead of pulling in transparency.
                    child: Transform.scale(
                      scale: 1.5,
                      child: Image(
                        image: cachedImage(cover.toString(), policy: ImageCachePolicies.albumCover),
                        fit: BoxFit.cover,
                      ),
                    ),
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
                        style: theme.typography.caption.copyWith(color: eq.enabled ? colors.accent : colors.textMuted),
                      ),
                      Text(
                        _presetName(t, eq.presetId, custom),
                        style: theme.typography.heading,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        track == null ? t.music.eqCenterSubtitle : '${track.title} · ${track.artist}',
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
                      style: theme.typography.caption.copyWith(color: eq.enabled ? colors.accent : colors.textMuted),
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
      child: DsImage(
        image: cachedImage(cover.toString(), policy: ImageCachePolicies.albumCover),
        width: 72,
        height: 72,
        semanticLabel: title,
      ),
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
    return TvFocusScale(
      child: DsPressable(
        semanticLabel: name,
        onPressed: onTap,
        builder: (context, states, _) => Container(
          padding: const EdgeInsets.symmetric(vertical: DsSpace.s12, horizontal: DsSpace.s4),
          decoration: BoxDecoration(
            // A preset card painted nothing for the pointer or the D-pad until
            // its own states were read; the wash sits under the accent border
            // so the selected one still reads first.
            color: states.contains(WidgetState.hovered) || states.contains(WidgetState.pressed)
                ? Color.alphaBlend(colors.hover, colors.surface)
                : colors.surface,
            borderRadius: BorderRadius.circular(theme.radii.control(36)),
            border: Border.all(
              color: selected
                  ? colors.accent
                  : states.contains(WidgetState.focused)
                  ? colors.focus
                  : colors.border.withValues(alpha: 0.4),
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
                        DsButton.icon(
                          variant: DsButtonVariant.ghost,
                          size: DsSize.sm,
                          semanticLabel: t.music.eqRemovePreset,
                          onPressed: () => unawaited(custom.remove(preset.id)),
                          icon: DsIcon(DsIcons.trash2, size: 16, color: colors.textMuted),
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

/// The sound-effect centre as its own pushed screen: the mini bar opens it
/// without leaving the page the viewer was browsing, and the module's rail
/// keeps showing the same page in place.
final class MusicEffectsPage extends StatelessWidget {
  /// The pushed effect centre.
  const MusicEffectsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final colors = DsTheme.colorsOf(context);
    // Escape walks back, the way it leaves the player.
    return CallbackShortcuts(
      bindings: <SingleActivator, VoidCallback>{
        const SingleActivator(LogicalKeyboardKey.escape): () => Navigator.of(context).maybePop(),
      },
      child: Focus(
        autofocus: true,
        child: ColoredBox(
          color: colors.canvas,
          child: SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                MusicBrowseHeader(title: t.music.eqCenter),
                const Expanded(child: MusicEqCenterPage()),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The loudness meter fed by the engine's analysis branch.
///
/// Two bars — momentary (400 ms) and short-term (3 s) — scaled over the
/// meter's -60…0 LUFS window. When the probe is off, the bars rest and
/// the caption says why: this is a loudness meter, not a spectrum.
final class _LoudnessMeter extends ConsumerStatefulWidget {
  /// Creates the meter.
  const _LoudnessMeter({required this.active});

  /// Whether the probe filter is in the chain right now.
  final bool active;

  @override
  ConsumerState<_LoudnessMeter> createState() => _LoudnessMeterState();
}

final class _LoudnessMeterState extends ConsumerState<_LoudnessMeter> {
  StreamSubscription<audio.AudioLoudness>? _sub;
  audio.AudioLoudness? _levels;

  @override
  void initState() {
    super.initState();
    _listen();
  }

  @override
  void didUpdateWidget(_LoudnessMeter old) {
    super.didUpdateWidget(old);
    if (old.active != widget.active) _listen();
  }

  void _listen() {
    unawaited(_sub?.cancel());
    _sub = null;
    if (!widget.active) {
      if (mounted) setState(() => _levels = null);
      return;
    }
    _sub = ref.read(musicPlayerProvider.notifier).audioEngine.loudnessStream.listen((levels) {
      if (mounted) setState(() => _levels = levels);
    });
  }

  @override
  void dispose() {
    unawaited(_sub?.cancel());
    super.dispose();
  }

  /// -60…0 LUFS on the bar; quieter than -60 paints as empty.
  double _fraction(double lufs) => ((lufs + 60) / 60).clamp(0.0, 1.0);

  @override
  Widget build(BuildContext context) {
    final colors = DsTheme.colorsOf(context);
    final momentary = _levels == null ? 0.0 : _fraction(_levels!.momentary);
    final shortTerm = _levels == null ? 0.0 : _fraction(_levels!.shortTerm);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: DsSpace.s8,
      children: [
        _LoudnessBar(label: 'M', fraction: momentary, accent: colors.accent, track: colors.border),
        _LoudnessBar(label: 'S', fraction: shortTerm, accent: colors.accent, track: colors.border),
      ],
    );
  }
}

final class _LoudnessBar extends StatelessWidget {
  const _LoudnessBar({required this.label, required this.fraction, required this.accent, required this.track});

  final String label;
  final double fraction;
  final Color accent;
  final Color track;

  @override
  Widget build(BuildContext context) {
    final theme = DsTheme.of(context);
    return Row(
      spacing: DsSpace.s8,
      children: [
        SizedBox(
          width: 16,
          child: Text(label, style: theme.typography.caption.copyWith(color: theme.colors.textMuted)),
        ),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: SizedBox(
              height: 6,
              child: Stack(
                children: [
                  ColoredBox(color: track),
                  FractionallySizedBox(
                    widthFactor: fraction,
                    child: ColoredBox(color: accent),
                  ),
                ],
              ),
            ),
          ),
        ),
        SizedBox(
          width: 56,
          child: Text(
            '${(fraction * 60 - 60).round()} LUFS',
            style: theme.typography.caption.copyWith(color: theme.colors.textMuted),
          ),
        ),
      ],
    );
  }
}

/// One parametric node's editor: switch and delete on the header row,
/// then frequency, Q and gain sliders — log-scaled where the ear is.
final class _EqNodeRow extends ConsumerWidget {
  const _EqNodeRow({required this.node, required this.eq, required this.controller});

  final MusicEqNode node;
  final MusicEqConfig eq;
  final MusicEqController controller;

  static String _frequencyLabel(double frequency) =>
      frequency >= 1000 ? '${(frequency / 1000).toStringAsFixed(1)} kHz' : '${frequency.round()} Hz';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    final theme = DsTheme.of(context);
    final colors = DsTheme.colorsOf(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(DsSpace.s20, DsSpace.s8, DsSpace.s20, DsSpace.s12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: DsSpace.s8,
        children: [
          Row(
            spacing: DsSpace.s8,
            children: [
              DsSwitch(
                value: node.enabled,
                onChanged: (value) => unawaited(controller.updateNode(node.id, enabled: value)),
              ),
              Expanded(
                child: Text(
                  _frequencyLabel(node.frequency),
                  style: theme.typography.body.copyWith(color: node.enabled ? colors.text : colors.textMuted),
                ),
              ),
              DsButton.icon(
                variant: DsButtonVariant.ghost,
                size: DsSize.sm,
                semanticLabel: t.music.eqRemoveNode,
                onPressed: () => unawaited(controller.removeNode(node.id)),
                icon: DsIcon(DsIcons.trash2, size: 16, color: colors.textMuted),
              ),
            ],
          ),
          DsSlider(
            value: ((math.log(node.frequency / 20) / math.ln10) / 3).clamp(0.0, 1.0),
            semanticLabel: t.music.eqNodeFrequency,
            onChanged: (value) {
              final frequency = 20 * math.pow(10, value * 3).toDouble();
              unawaited(controller.updateNode(node.id, frequency: frequency));
            },
          ),
          Row(
            spacing: DsSpace.s8,
            children: [
              Expanded(
                child: DsSlider(
                  value: ((math.log(node.q / kMusicEqNodeMinQ) / math.ln10) / 2).clamp(0.0, 1.0),
                  semanticLabel: t.music.eqNodeQ,
                  onChanged: (value) {
                    final q = kMusicEqNodeMinQ * math.pow(10, value * 2).toDouble();
                    unawaited(controller.updateNode(node.id, q: q));
                  },
                ),
              ),
              SizedBox(
                width: 64,
                child: Text(
                  'Q ${node.q.toStringAsFixed(1)}',
                  textAlign: TextAlign.end,
                  style: theme.typography.caption.copyWith(color: colors.textMuted),
                ),
              ),
            ],
          ),
          Row(
            spacing: DsSpace.s8,
            children: [
              Expanded(
                child: DsSlider(
                  min: kMusicEqMinGain,
                  max: kMusicEqMaxGain,
                  value: node.gainDb,
                  semanticLabel: t.music.eqNodeGain,
                  onChanged: (value) => unawaited(controller.updateNode(node.id, gainDb: value)),
                ),
              ),
              SizedBox(
                width: 64,
                child: Text(
                  '${node.gainDb >= 0 ? '+' : ''}${node.gainDb.toStringAsFixed(1)} dB',
                  textAlign: TextAlign.end,
                  style: theme.typography.caption.copyWith(color: colors.textMuted),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// The A/B compare button: hold it and the whole chain steps aside, so the
/// ear hears the untouched mix; release restores the configuration at once.
/// The instant switch-back is the whole point — a toggle with a delay
/// cannot be compared reliably.
final class _CompareButton extends ConsumerStatefulWidget {
  /// Creates the button.
  const _CompareButton({required this.player});

  final MusicPlayerController player;

  @override
  ConsumerState<_CompareButton> createState() => _CompareButtonState();
}

final class _CompareButtonState extends ConsumerState<_CompareButton> {
  bool _held = false;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final theme = DsTheme.of(context);
    final colors = DsTheme.colorsOf(context);
    return GestureDetector(
      onTapDown: (_) {
        setState(() => _held = true);
        widget.player.setCompareBypass(bypass: true);
      },
      onTapUp: (_) {
        if (!_held) return;
        setState(() => _held = false);
        widget.player.setCompareBypass(bypass: false);
      },
      onTapCancel: () {
        if (!_held) return;
        setState(() => _held = false);
        widget.player.setCompareBypass(bypass: false);
      },
      child: Container(
        height: 44,
        decoration: BoxDecoration(
          color: _held ? colors.accent : colors.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: colors.border),
        ),
        alignment: Alignment.center,
        child: Text(
          _held ? t.music.eqCompareHeld : t.music.eqCompare,
          style: theme.typography.body.copyWith(color: _held ? colors.onAccent : colors.text),
        ),
      ),
    );
  }
}
