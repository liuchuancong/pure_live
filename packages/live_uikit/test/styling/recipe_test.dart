import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:live_uikit/styling.dart';

/// The button recipe is `base ⊕ variant ⊕ size ⊕ state` (§4). Its contract is
/// that each layer overrides only what it names, that it reads nothing but the
/// tokens, and that a component-token override repaints it — the look has to
/// stay data, or the adapters' reason for existing disappears.
void main() {
  const seed = SeedToken();
  final token = DesignToken.derive(seed, dark: false);
  final button = ButtonComponentToken.of(token);
  const recipe = ButtonRecipe();

  Style resolve({
    ButtonVariant variant = ButtonVariant.secondary,
    ControlSize size = ControlSize.md,
    InteractionState state = InteractionState.normal,
    ButtonComponentToken? from,
  }) => recipe.resolve(token, from ?? button, variant: variant, size: size, state: state);

  group('the base layer', () {
    test('every control starts from the component token, not a literal', () {
      final style = resolve();
      expect(style.borderRadius, BorderRadius.circular(button.borderRadius));
      expect(style.borderRadius, BorderRadius.circular(token.scale.radii.base));
      expect(style.minHeight, button.controlHeight);
      expect(style.padding, EdgeInsets.symmetric(horizontal: button.paddingInline));
      expect(style.alignment, Alignment.center);
      expect(style.fontWeight, FontWeight.w600);
      expect(style.fontFamily, token.type.fontFamily);
    });
  });

  group('the variant layer', () {
    test('primary is a solid brand fill with the light-solid label', () {
      final style = resolve(variant: ButtonVariant.primary);
      expect(style.background, token.color.primary);
      expect(style.foreground, token.color.textLightSolid);
      expect(style.borderColor, isNull, reason: 'a filled button has no border to speak of');
    });

    test('secondary is the bordered surface', () {
      final style = resolve();
      expect(style.background, token.color.bgContainer);
      expect(style.foreground, token.color.text);
      expect(style.borderColor, token.color.border);
      expect(style.borderWidth, 1);
    });

    test('ghost names only its label', () {
      final style = resolve(variant: ButtonVariant.ghost);
      expect(style.foreground, token.color.primary);
      expect(style.background, isNull);
      expect(style.borderColor, isNull);
    });

    test('danger fills with the error ramp and keeps the light-solid label', () {
      final style = resolve(variant: ButtonVariant.danger);
      expect(style.background, token.color.error);
      expect(style.foreground, token.color.textLightSolid);
    });
  });

  group('the size layer', () {
    test('sm takes the small height, small text and tighter padding', () {
      final style = resolve(size: ControlSize.sm);
      expect(style.minHeight, token.scale.controlHeightSM);
      expect(style.fontSize, token.type.fontSizeSM);
      expect(style.padding, EdgeInsets.symmetric(horizontal: button.paddingInline * 0.66));
    });

    test('md only restates the height and the base text', () {
      final style = resolve();
      expect(style.minHeight, token.scale.controlHeight);
      expect(style.fontSize, token.type.fontSize);
      expect(
        style.padding,
        EdgeInsets.symmetric(horizontal: button.paddingInline),
        reason: 'md does not touch padding',
      );
    });

    test('lg grows the height, text and padding', () {
      final style = resolve(size: ControlSize.lg);
      expect(style.minHeight, token.scale.controlHeightLG);
      expect(style.fontSize, token.type.fontSizeLG);
      expect(style.padding, EdgeInsets.symmetric(horizontal: button.paddingInline * 1.33));
    });
  });

  group('the state layer', () {
    test('disabled dims every variant and changes no colour', () {
      for (final variant in ButtonVariant.values) {
        final style = resolve(variant: variant, state: InteractionState.disabled);
        expect(style.opacity, button.opacityLoading, reason: '$variant disabled');
        expect(style.minHeight, button.controlHeight);
      }
      expect(
        resolve(variant: ButtonVariant.primary, state: InteractionState.disabled).background,
        token.color.primary,
        reason: 'the dimming is opacity, not a greying of the fill',
      );
    });

    test('pressed moves the filled variants and leaves the quiet ones alone', () {
      expect(
        resolve(variant: ButtonVariant.primary, state: InteractionState.pressed).background,
        token.color.primaryActive,
      );
      expect(
        resolve(variant: ButtonVariant.danger, state: InteractionState.pressed).background,
        token.color.error,
        reason: 'Ant gives danger no separate active step; the fill stays put',
      );
      expect(
        resolve(state: InteractionState.pressed).background,
        token.color.bgContainer,
        reason: 'a null delta cannot clear the variant fill',
      );
      expect(resolve(variant: ButtonVariant.ghost, state: InteractionState.pressed).background, isNull);
    });

    test('hovered lifts each variant by its own rule', () {
      expect(
        resolve(state: InteractionState.hovered, variant: ButtonVariant.primary).background,
        token.color.primaryHover,
      );
      expect(
        resolve(state: InteractionState.hovered, variant: ButtonVariant.danger).background,
        token.color.errorHover,
      );
      final secondary = resolve(state: InteractionState.hovered);
      expect(secondary.background, token.color.fillQuaternary);
      expect(secondary.borderColor, token.color.primary, reason: 'the outlined button answers hover with its border');
      expect(
        resolve(variant: ButtonVariant.ghost, state: InteractionState.hovered).background,
        token.color.bgTextHover,
      );
    });

    test('focused is a border, never a fill', () {
      final style = resolve(variant: ButtonVariant.primary, state: InteractionState.focused);
      expect(style.borderColor, token.color.primary);
      expect(style.borderWidth, token.motion.lineWidth);
      expect(style.background, token.color.primary, reason: 'focus must not repaint a filled button');
    });

    test('normal adds nothing', () {
      expect(resolve().opacity, isNull, reason: 'normal is the resting state');
      expect(resolve().borderWidth, 1, reason: 'that is the variant speaking');
    });
  });

  group('precedence is the merge order', () {
    test('size beats variant beats base, and state sits on top', () {
      final style = resolve(variant: ButtonVariant.primary, size: ControlSize.lg, state: InteractionState.disabled);
      expect(style.minHeight, token.scale.controlHeightLG);
      expect(style.fontSize, token.type.fontSizeLG);
      expect(style.padding, EdgeInsets.symmetric(horizontal: button.paddingInline * 1.33));
      expect(style.background, token.color.primary);
      expect(style.opacity, button.opacityLoading);
    });

    test('an inline style still outranks the whole recipe', () {
      final style = resolve(variant: ButtonVariant.primary).merge(const Style(background: Color(0xFF123456)));
      expect(style.background, const Color(0xFF123456));
      expect(style.foreground, token.color.textLightSolid);
    });
  });

  group('the look is data', () {
    test('a component-token override repaints without touching the design tokens', () {
      const purple = Color(0xFF800080);
      final overridden = button.copyWith(primaryBg: purple, defaultBorder: purple);
      expect(resolve(variant: ButtonVariant.primary, from: overridden).background, purple);
      expect(resolve(from: overridden).borderColor, purple);
      expect(
        resolve(variant: ButtonVariant.ghost, from: overridden).foreground,
        token.color.primary,
        reason: 'an override scoped to the button cannot move the global primary',
      );
      expect(token.color.primary, seed.colorPrimary);
    });

    testWidgets('a provider-level override reaches LiveTheme.resolveButton', (tester) async {
      const purple = Color(0xFF800080);
      late LiveTheme captured;
      await tester.pumpWidget(
        LiveConfigProvider(
          config: const UiConfig(),
          buttonToken: (t) => ButtonComponentToken.of(t).copyWith(primaryBg: purple),
          child: Builder(
            builder: (context) {
              captured = LiveTheme.of(context);
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      expect(
        captured
            .resolveButton(variant: ButtonVariant.primary, size: ControlSize.md, state: InteractionState.normal)
            .background,
        purple,
      );
      expect(captured.button.paddingInline, token.scale.controlPaddingHorizontal);
    });
  });
}
