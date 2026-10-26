import 'dart:async' show unawaited;

import 'package:desen_ui/desen_ui.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pure_live/app/app.dart';
import 'package:pure_live/features/settings/dialogs/theme_color_dialog.dart' show kThemeColorPresets;
import 'package:pure_live/l10n/translations.dart';
import 'package:pure_live/shared/shared.dart';

/// The current language's name for a loading style.
String loadingStyleLabel(Translations t, String key) => switch (key) {
  'rotatingPlain' => t.settings.loadingStyleRotatingPlain,
  'doubleBounce' => t.settings.loadingStyleDoubleBounce,
  'wave' => t.settings.loadingStyleWave,
  'wanderingCubes' => t.settings.loadingStyleWanderingCubes,
  'fadingFour' => t.settings.loadingStyleFadingFour,
  'fadingCube' => t.settings.loadingStyleFadingCube,
  'pulse' => t.settings.loadingStylePulse,
  'chasingDots' => t.settings.loadingStyleChasingDots,
  'threeBounce' => t.settings.loadingStyleThreeBounce,
  'circle' => t.settings.loadingStyleCircle,
  'cubeGrid' => t.settings.loadingStyleCubeGrid,
  'fadingCircle' => t.settings.loadingStyleFadingCircle,
  'rotatingCircle' => t.settings.loadingStyleRotatingCircle,
  'foldingCube' => t.settings.loadingStyleFoldingCube,
  'pumpingHeart' => t.settings.loadingStylePumpingHeart,
  'hourGlass' => t.settings.loadingStyleHourGlass,
  'pouringHourGlass' => t.settings.loadingStylePouringHourGlass,
  'pouringHourGlassRefined' => t.settings.loadingStylePouringHourGlassRefined,
  'fadingGrid' => t.settings.loadingStyleFadingGrid,
  'ring' => t.settings.loadingStyleRing,
  'ripple' => t.settings.loadingStyleRipple,
  'spinningCircle' => t.settings.loadingStyleSpinningCircle,
  'spinningLines' => t.settings.loadingStyleSpinningLines,
  'squareCircle' => t.settings.loadingStyleSquareCircle,
  'dualRing' => t.settings.loadingStyleDualRing,
  'pianoWave' => t.settings.loadingStylePianoWave,
  'dancingSquare' => t.settings.loadingStyleDancingSquare,
  'threeInOut' => t.settings.loadingStyleThreeInOut,
  'waveSpinner' => t.settings.loadingStyleWaveSpinner,
  'pulsingGrid' => t.settings.loadingStylePulsingGrid,
  'waveDots' => t.settings.loadingStyleWaveDots,
  'inkDrop' => t.settings.loadingStyleInkDrop,
  'twistingDots' => t.settings.loadingStyleTwistingDots,
  'threeRotatingDots' => t.settings.loadingStyleThreeRotatingDots,
  'staggeredDotsWave' => t.settings.loadingStyleStaggeredDotsWave,
  'fourRotatingDots' => t.settings.loadingStyleFourRotatingDots,
  'fallingDot' => t.settings.loadingStyleFallingDot,
  'progressiveDots' => t.settings.loadingStyleProgressiveDots,
  'discreteCircular' => t.settings.loadingStyleDiscreteCircular,
  'threeArchedCircle' => t.settings.loadingStyleThreeArchedCircle,
  'bouncingBall' => t.settings.loadingStyleBouncingBall,
  'flickr' => t.settings.loadingStyleFlickr,
  'hexagonDots' => t.settings.loadingStyleHexagonDots,
  'beat' => t.settings.loadingStyleBeat,
  'twoRotatingArc' => t.settings.loadingStyleTwoRotatingArc,
  'horizontalRotatingDots' => t.settings.loadingStyleHorizontalRotatingDots,
  'newtonCradle' => t.settings.loadingStyleNewtonCradle,
  'stretchedDots' => t.settings.loadingStyleStretchedDots,
  'halfTriangleDot' => t.settings.loadingStyleHalfTriangleDot,
  'dotsTriangle' => t.settings.loadingStyleDotsTriangle,
  'ballPulse' => t.settings.loadingStyleBallPulse,
  'ballGridPulse' => t.settings.loadingStyleBallGridPulse,
  'ballClipRotate' => t.settings.loadingStyleBallClipRotate,
  'ballClipRotatePulse' => t.settings.loadingStyleBallClipRotatePulse,
  'squareSpin' => t.settings.loadingStyleSquareSpin,
  'ballClipRotateMultiple' => t.settings.loadingStyleBallClipRotateMultiple,
  'ballPulseRise' => t.settings.loadingStyleBallPulseRise,
  'ballRotate' => t.settings.loadingStyleBallRotate,
  'cubeTransition' => t.settings.loadingStyleCubeTransition,
  'ballZigZag' => t.settings.loadingStyleBallZigZag,
  'ballZigZagDeflect' => t.settings.loadingStyleBallZigZagDeflect,
  'ballTrianglePath' => t.settings.loadingStyleBallTrianglePath,
  'ballTrianglePathColored' => t.settings.loadingStyleBallTrianglePathColored,
  'ballTrianglePathColoredFilled' => t.settings.loadingStyleBallTrianglePathColoredFilled,
  'ballScale' => t.settings.loadingStyleBallScale,
  'lineScale' => t.settings.loadingStyleLineScale,
  'lineScaleParty' => t.settings.loadingStyleLineScaleParty,
  'ballScaleMultiple' => t.settings.loadingStyleBallScaleMultiple,
  'ballPulseSync' => t.settings.loadingStyleBallPulseSync,
  'ballBeat' => t.settings.loadingStyleBallBeat,
  'lineScalePulseOut' => t.settings.loadingStyleLineScalePulseOut,
  'lineScalePulseOutRapid' => t.settings.loadingStyleLineScalePulseOutRapid,
  'ballScaleRipple' => t.settings.loadingStyleBallScaleRipple,
  'ballScaleRippleMultiple' => t.settings.loadingStyleBallScaleRippleMultiple,
  'ballSpinFadeLoader' => t.settings.loadingStyleBallSpinFadeLoader,
  'lineSpinFadeLoader' => t.settings.loadingStyleLineSpinFadeLoader,
  'triangleSkewSpin' => t.settings.loadingStyleTriangleSkewSpin,
  'pacman' => t.settings.loadingStylePacman,
  'ballGridBeat' => t.settings.loadingStyleBallGridBeat,
  'semiCircleSpin' => t.settings.loadingStyleSemiCircleSpin,
  'ballRotateChase' => t.settings.loadingStyleBallRotateChase,
  'orbit' => t.settings.loadingStyleOrbit,
  'audioEqualizer' => t.settings.loadingStyleAudioEqualizer,
  'circleStrokeSpin' => t.settings.loadingStyleCircleStrokeSpin,
  _ => t.settings.loadingStyleDefault,
};

/// Opens the loading-style gallery: every style this build draws, playing,
/// with the current one marked. A choice writes at once, so the settings row
/// and every page behind the dialog follow it.
Future<void> showLoadingStyleDialog(BuildContext context) =>
    showDsDialog<void>(context: context, builder: (context) => const _LoadingStyleDialog());

final class _LoadingStyleDialog extends ConsumerWidget {
  const _LoadingStyleDialog();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    final selected = ref.watch(loadingStyleProvider);
    final loadingColor = ref.watch(loadingColorProvider);
    return DsDialog(
      title: Text(t.settings.loadingStyleChoose),
      description: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.65),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: DsSpace.s16,
            children: [
              DsListSection(
                children: [
                  DsListRow(
                    leading: _LoadingColorDot(color: loadingColor ?? DsTheme.colorsOf(context).accent),
                    title: Text(t.settings.loadingColor),
                    description: Text(t.settings.loadingColorDescription),
                    detail: Text(
                      loadingColor == null
                          ? t.settings.loadingColorFollowTheme
                          : ThemePersistence.encodeArgbColor(loadingColor),
                    ),
                    showChevron: true,
                    onPressed: () => unawaited(showLoadingColorDialog(context)),
                  ),
                ],
              ),
              Text(t.settings.loadingStyleChooseHint),
              Wrap(
                spacing: DsSpace.s8,
                runSpacing: DsSpace.s8,
                children: [
                  for (final key in kLoadingStyleKeys)
                    _LoadingStyleCell(
                      styleKey: key,
                      label: loadingStyleLabel(t, key),
                      selected: key == selected,
                      onPressed: () => ref.read(loadingStyleProvider.notifier).style = key,
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
      style: const DsDialogStyle(width: 560),
      actions: [
        // The reference's restore action clears both the animation and its
        // ink, so the default ring goes back to the theme's accent.
        DsButton(
          variant: DsButtonVariant.ghost,
          onPressed: selected == 'default' && loadingColor == null
              ? null
              : () {
                  ref.read(loadingStyleProvider.notifier).style = 'default';
                  ref.read(loadingColorProvider.notifier).color = null;
                },
          child: Text(t.settings.styleReset),
        ),
        DsButton(
          variant: DsButtonVariant.secondary,
          onPressed: () => Navigator.of(context).pop(),
          child: Text(t.common.close),
        ),
      ],
    );
  }
}

/// Opens the loading-colour picker: follow the accent, one of the reference's
/// preset tones, or any colour as a hex value. A choice writes on Confirm, so
/// closing the dialog leaves the loaders as they were.
Future<void> showLoadingColorDialog(BuildContext context) =>
    showDsDialog<void>(context: context, builder: (context) => const _LoadingColorDialog());

final class _LoadingColorDialog extends ConsumerStatefulWidget {
  const _LoadingColorDialog();

  @override
  ConsumerState<_LoadingColorDialog> createState() => _LoadingColorDialogState();
}

final class _LoadingColorDialogState extends ConsumerState<_LoadingColorDialog> {
  late final TextEditingController _hex;
  Color? _color;
  bool _invalid = false;

  @override
  void initState() {
    super.initState();
    _color = ref.read(loadingColorProvider);
    _hex = TextEditingController(text: _color == null ? '' : ThemePersistence.encodeArgbColor(_color!));
  }

  @override
  void dispose() {
    _hex.dispose();
    super.dispose();
  }

  void _select(Color? color) {
    setState(() {
      _color = color;
      _invalid = false;
      _hex.text = color == null ? '' : ThemePersistence.encodeArgbColor(color);
    });
  }

  void _onHexChanged(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) {
      setState(() {
        _color = null;
        _invalid = false;
      });
      return;
    }
    final parsed = ThemePersistence.parseSeedColor(trimmed);
    setState(() {
      _color = parsed;
      _invalid = parsed == null;
    });
  }

  void _apply() {
    ref.read(loadingColorProvider.notifier).color = _color;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final theme = DsTheme.of(context);
    final colors = DsTheme.colorsOf(context);
    final preview = _color ?? colors.accent;
    final sectionStyle = theme.typography.small.copyWith(color: colors.textMuted, fontWeight: FontWeight.w600);
    return DsDialog(
      title: Text(t.settings.loadingColor),
      description: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: DsSpace.s16,
        children: [
          DsListSection(
            children: [
              DsListRow(
                leading: const DsIcon(DsIcons.monitor),
                title: Text(t.settings.loadingColorFollowTheme),
                selected: _color == null,
                trailing: _color == null ? const DsIcon(DsIcons.check) : null,
                onPressed: () => _select(null),
              ),
            ],
          ),
          Text(t.settings.loadingColorPresets, style: sectionStyle),
          Wrap(
            spacing: DsSpace.s8,
            runSpacing: DsSpace.s8,
            children: [
              for (final color in kThemeColorPresets)
                _LoadingColorSwatch(color: color, selected: _color == color, onPressed: () => _select(color)),
            ],
          ),
          Text(t.settings.loadingColorHex, style: sectionStyle),
          Row(
            spacing: DsSpace.s12,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: preview,
                  borderRadius: BorderRadius.circular(theme.radii.card / 2),
                  border: Border.all(color: colors.borderField),
                ),
              ),
              Expanded(
                child: DsTextField(
                  controller: _hex,
                  placeholder: '#RRGGBB',
                  clearable: true,
                  semanticLabel: t.settings.loadingColorHex,
                  error: _invalid,
                  onChanged: _onHexChanged,
                ),
              ),
            ],
          ),
          if (_invalid)
            Text(t.settings.loadingColorHexInvalid, style: theme.typography.small.copyWith(color: colors.danger.text)),
        ],
      ),
      style: const DsDialogStyle(width: 520),
      actions: [
        DsButton(
          variant: DsButtonVariant.secondary,
          onPressed: () => Navigator.of(context).pop(),
          child: Text(t.common.cancel),
        ),
        DsButton(onPressed: _invalid ? null : _apply, child: Text(t.common.confirm)),
      ],
    );
  }
}

/// One preset colour, marked when it is the draft.
final class _LoadingColorSwatch extends StatelessWidget {
  const _LoadingColorSwatch({required this.color, required this.selected, required this.onPressed});

  final Color color;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = DsTheme.of(context);
    final colors = DsTheme.colorsOf(context);
    final hex = ThemePersistence.encodeArgbColor(color);
    return DsTooltip(
      message: hex,
      child: DsPressable(
        onPressed: onPressed,
        semanticLabel: hex,
        selected: selected,
        builder: (context, states, _) {
          final focused = states.contains(WidgetState.focused);
          return Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(theme.radii.card / 2),
              border: Border.all(
                color: selected ? colors.accent : (focused ? colors.focus : colors.borderField),
                width: selected || focused ? 2 : 1,
              ),
            ),
            child: selected
                ? Center(
                    child: DsIcon(
                      DsIcons.check,
                      size: 16,
                      color: color.computeLuminance() > 0.5 ? const Color(0xFF101418) : const Color(0xFFFFFFFF),
                    ),
                  )
                : null,
          );
        },
      ),
    );
  }
}

/// The current loading colour as a dot in the dialog's row.
final class _LoadingColorDot extends StatelessWidget {
  const _LoadingColorDot({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 16,
      height: 16,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
        border: Border.all(color: DsTheme.colorsOf(context).borderField),
      ),
    );
  }
}

/// One style as a live preview and its name, with the selected ring and mark.
final class _LoadingStyleCell extends StatelessWidget {
  const _LoadingStyleCell({
    required this.styleKey,
    required this.label,
    required this.selected,
    required this.onPressed,
  });

  final String styleKey;
  final String label;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = DsTheme.of(context);
    final colors = DsTheme.colorsOf(context);
    return SizedBox(
      width: 112,
      height: 100,
      child: DsPressable(
        onPressed: onPressed,
        selected: selected,
        semanticLabel: label,
        builder: (context, states, _) {
          final focused = states.contains(WidgetState.focused);
          return Stack(
            children: [
              AnimatedContainer(
                duration: theme.motion.toneDuration,
                curve: theme.motion.toneCurve,
                padding: const EdgeInsets.all(DsSpace.s8),
                decoration: BoxDecoration(
                  color: selected ? colors.accentTint : colors.field,
                  borderRadius: BorderRadius.circular(theme.radii.card),
                  border: Border.all(
                    color: selected
                        ? colors.accent
                        : focused
                        ? colors.focus
                        : colors.border,
                    width: selected ? 2 : 1,
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  spacing: DsSpace.s8,
                  children: [
                    // Each animation repaints inside its own layer; the
                    // dialog is the one place every style plays at once.
                    AppLoadingIndicator(size: 30, color: colors.accent),
                    Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.typography.caption.copyWith(
                        color: selected ? colors.accent : colors.text,
                        fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
              if (selected)
                PositionedDirectional(top: 6, end: 6, child: DsIcon(DsIcons.check, size: 14, color: colors.accent)),
            ],
          );
        },
      ),
    );
  }
}
