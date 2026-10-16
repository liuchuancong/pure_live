import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:live_uikit/live_uikit.dart';

/// The token pipeline is a port, not an interpretation: a single seed is meant
/// to reproduce Ant Design v5's published derivation (§5). These assertions pin
/// the arithmetic to Ant's own documented values so a future "improvement" to
/// the maths shows up as a failure rather than as a silent re-skin.
void main() {
  const seed = SeedToken();
  final light = DesignToken.derive(seed, dark: false);
  final dark = DesignToken.derive(seed, dark: true);

  group('the seed is the only authored layer', () {
    test('the brand ramp keeps the seed at level 6 in both variants', () {
      expect(light.color.primary, seed.colorPrimary);
      expect(dark.color.primary, seed.colorPrimary, reason: 'dark re-indexes the ramp, it does not recolour it');
    });

    test('the ramp runs light-to-dark in Ant level order', () {
      final c = light.color;
      expect(c.primaryBg.computeLuminance(), greaterThan(c.primary.computeLuminance()));
      expect(c.primary.computeLuminance(), greaterThan(c.primaryActive.computeLuminance()));
      expect(c.primaryHover.computeLuminance(), greaterThan(c.primary.computeLuminance()));
      expect(c.primaryText.computeLuminance(), lessThan(c.primary.computeLuminance()));
    });

    test("the derived steps land on Ant's published primary ramp", () {
      // Ant's generate('#1677ff') levels 1 / 5 / 7. The HSV port rounds
      // differently from JavaScript, so the published value is the anchor and a
      // few levels of channel drift are the tolerance.
      expectNear(light.color.primaryBg, const Color(0xFFE6F4FF));
      expectNear(light.color.primaryHover, const Color(0xFF4096FF));
      expectNear(light.color.primaryActive, const Color(0xFF0958D9));
    });

    test('link defaults to info and follows it when info is seeded', () {
      final themed = DesignToken.derive(const SeedToken(colorInfo: Color(0xFF00FF00)), dark: false);
      expect(themed.color.link, const Color(0xFF00FF00));
      expect(
        DesignToken.derive(const SeedToken(colorLink: Color(0xFFFF00FF)), dark: false).color.link,
        const Color(0xFFFF00FF),
        reason: 'an explicit link seed wins over the info default',
      );
    });
  });

  group('the neutral ramps are alphas of the text base', () {
    test('light uses 0.88 / 0.65 / 0.45 / 0.25 over black', () {
      expect(light.color.text.a, closeTo(0.88, 0.001));
      expect(light.color.textSecondary.a, closeTo(0.65, 0.001));
      expect(light.color.textTertiary.a, closeTo(0.45, 0.001));
      expect(light.color.textQuaternary.a, closeTo(0.25, 0.001));
      expect(light.color.text.r, closeTo(0, 0.001), reason: 'the light text base is black');
    });

    test('dark flips the base to white and opens the top step to 0.85', () {
      expect(dark.color.text.a, closeTo(0.85, 0.001));
      expect(dark.color.text.r, closeTo(1, 0.001));
    });

    test('fills are heavier in dark (0.18/0.12/0.08/0.04 vs 0.15/0.06/0.04/0.02)', () {
      expect(light.color.fill.a, closeTo(0.15, 0.001));
      expect(light.color.fillSecondary.a, closeTo(0.06, 0.001));
      expect(light.color.fillTertiary.a, closeTo(0.04, 0.001));
      expect(light.color.fillQuaternary.a, closeTo(0.02, 0.001));
      expect(dark.color.fill.a, closeTo(0.18, 0.001));
      expect(dark.color.fillSecondary.a, closeTo(0.12, 0.001));
      expect(dark.color.fillTertiary.a, closeTo(0.08, 0.001));
      expect(dark.color.fillQuaternary.a, closeTo(0.04, 0.001));
    });

    test('the text base can be seeded, and every neutral step follows it', () {
      final tinted = DesignToken.derive(const SeedToken(colorTextBase: Color(0xFF102030)), dark: false);
      expect(tinted.color.text.withValues(alpha: 1), const Color(0xFF102030));
      expect(tinted.color.textSecondary.a, closeTo(0.65, 0.001));
    });

    test('the semantic aliases read the same ramp the components do', () {
      expect(light.color.textDisabled, light.color.textQuaternary);
      expect(light.color.textPlaceholder, light.color.textQuaternary);
      expect(light.color.fillContent, light.color.fillSecondary);
      expect(light.color.fillAlter, light.color.fillQuaternary);
      expect(light.color.bgContainerDisabled, light.color.fillTertiary);
      expect(light.color.bgTextHover, light.color.fillSecondary);
      expect(light.color.bgTextActive, light.color.fill);
      expect(light.color.icon, light.color.textTertiary);
      expect(light.color.onPrimary, light.color.textLightSolid);
      expect(light.color.surface, light.color.bgLayout);
      expect(light.color.scrim, light.color.mask);
      expect(light.color.divider, light.color.borderSecondary.withValues(alpha: 0.6));
    });
  });

  group("surfaces land on Ant's published neutrals", () {
    test('light: layout darkens by 4, container and elevated stay white', () {
      expectNear(light.color.bgContainer, const Color(0xFFFFFFFF));
      expectNear(light.color.bgElevated, const Color(0xFFFFFFFF));
      expectNear(light.color.bgLayout, const Color(0xFFF5F5F5));
      expectNear(light.color.border, const Color(0xFFD9D9D9));
      expectNear(light.color.borderSecondary, const Color(0xFFF0F0F0));
      expect(light.color.bgSpotlight.a, closeTo(0.85, 0.001));
    });

    test('dark: elevated lightens by 12, container by 8, layout stays base', () {
      expectNear(dark.color.bgLayout, const Color(0xFF000000));
      expectNear(dark.color.bgContainer, const Color(0xFF141414));
      expectNear(dark.color.bgElevated, const Color(0xFF1F1F1F));
      expectNear(dark.color.border, const Color(0xFF424242));
      expectNear(dark.color.borderSecondary, const Color(0xFF303030));
      expectNear(
        dark.color.bgSpotlight,
        const Color(0xFF424242),
        reason: "Ant's dark spotlight is the level-26 surface",
      );
    });

    test('pureBlack only collapses a dark variant, and only over a seeded bg', () {
      const seeded = SeedToken(colorBgBase: Color(0xFF101010));
      expect(DesignToken.derive(seeded, dark: true).color.bgLayout, const Color(0xFF101010));
      expect(
        DesignToken.derive(seeded.copyWith(pureBlack: true), dark: true).color.bgLayout,
        const Color(0xFF000000),
        reason: 'the OLED ask is a hard black layout floor',
      );
      expect(
        DesignToken.derive(const SeedToken(pureBlack: true), dark: false).color.bgContainer,
        const Color(0xFFFFFFFF),
        reason: 'pureBlack is a dark-surface rule; light is untouched',
      );
    });

    test("shadows take the variant's tint", () {
      expect(light.color.shadowBase, const Color(0xFF000000));
      expect(dark.color.shadowBase, const Color(0x33FFFFFF));
      expect(light.motion.boxShadow, hasLength(3));
      expect(light.motion.boxShadowTertiary, hasLength(3));
      expect(light.motion.boxShadow.first.color.a, closeTo(0.08, 0.001));
    });

    test('the mask is the constant scrim', () {
      expect(light.color.mask, const Color(0x73000000));
      expect(dark.color.mask, const Color(0x73000000));
    });
  });

  group('the type scale is derived, not authored', () {
    test('the seed size is level 2 of the modular scale and the steps round to even', () {
      expect(light.type.fontSize, seed.fontSize);
      expect(light.type.fontSizeSM, 12);
      expect(light.type.fontSizeLG, 16);
      expect(light.type.fontSizeXL, 20);
      expect(light.type.fontSizeSM % 2, 0);
      expect(light.type.fontSizeLG % 2, 0);
    });

    test('line heights come from (size + 8) / size', () {
      expect(light.type.lineHeight, closeTo((14 + 8) / 14, 0.0001));
      expect(light.type.lineHeightSM, closeTo((12 + 8) / 12, 0.0001));
      expect(light.type.lineHeightLG, closeTo((16 + 8) / 16, 0.0001));
    });

    test('the headings alias the same scale', () {
      expect(light.type.fontSizeHeading5, light.type.fontSizeLG);
      expect(light.type.fontSizeHeading4, light.type.fontSizeXL);
      expect(light.type.fontSizeHeading3, 24);
      expect(light.type.fontSizeHeading2, 30);
      expect(light.type.fontSizeHeading1, 38);
    });

    test('a different seed base moves the whole scale', () {
      final larger = DesignToken.derive(const SeedToken(fontSize: 16), dark: false);
      expect(larger.type.fontSize, 16);
      expect(larger.type.fontSizeSM, 14);
      expect(larger.type.fontSizeLG, 18);
    });

    test('the families are carried through untouched', () {
      final themed = DesignToken.derive(
        const SeedToken(fontFamily: 'Noto Sans SC', fontFamilyCode: 'JetBrains Mono'),
        dark: false,
      );
      expect(themed.type.fontFamily, 'Noto Sans SC');
      expect(themed.type.fontFamilyCode, 'JetBrains Mono');
    });
  });

  group('the size, radius and height scales', () {
    test('sizes step from sizeUnit and sizeStep', () {
      final s = light.scale.sizes;
      expect(s.xxl, 48);
      expect(s.xl, 32);
      expect(s.lg, 24);
      expect(s.md, 20);
      expect(s.ms, 16);
      expect(s.sm, 12);
      expect(s.xs, 8);
      expect(s.xxs, 4);
      expect(light.scale.controlPaddingHorizontal, s.md);
      expect(light.scale.controlPaddingHorizontalSM, s.sm);
    });

    test("the radius scale branches on the base, as Ant's genRadius does", () {
      final r = light.scale.radii;
      expect(r.base, 6);
      expect(r.sm, 4);
      expect(r.xs, 2);
      expect(r.lg, 8);
      expect(r.outer, 4);

      final round = DesignToken.derive(const SeedToken(borderRadius: 16), dark: false).scale.radii;
      expect(round.lg, 16, reason: 'the large radius saturates at 16');
      expect(round.sm, 8);
      expect(round.outer, 6);

      final square = DesignToken.derive(const SeedToken(borderRadius: 4), dark: false).scale.radii;
      expect(square.lg, 4);
      expect(square.xs, 1);
      expect(square.outer, 4);
    });

    test('control heights step off one seed height', () {
      expect(light.scale.controlHeight, 32);
      expect(light.scale.controlHeightLG, 40);
      expect(light.scale.controlHeightSM, 24);
      expect(light.scale.controlHeightXS, 16);
    });
  });

  group('motion, lines and stacking', () {
    test('the three durations step off motionUnit', () {
      expect(light.motion.durationFast, const Duration(milliseconds: 100));
      expect(light.motion.durationMid, const Duration(milliseconds: 200));
      expect(light.motion.durationSlow, const Duration(milliseconds: 300));
    });

    test('motion off zeroes every duration without touching the lines', () {
      final still = DesignToken.derive(const SeedToken(motion: false), dark: false);
      expect(still.motion.durationFast, Duration.zero);
      expect(still.motion.durationMid, Duration.zero);
      expect(still.motion.durationSlow, Duration.zero);
      expect(still.motion.lineWidth, 1);
    });

    test('a focus outline the user turned off reaches the token', () {
      expect(light.motion.lineWidthFocus, 3);
      expect(DesignToken.derive(const SeedToken(focusOutline: false), dark: false).motion.lineWidthFocus, 0);
    });

    test("the bold line is one step up and loading opacity is Ant's", () {
      expect(light.motion.lineWidth, seed.lineWidth);
      expect(light.motion.lineWidthBold, seed.lineWidth + 1);
      expect(light.motion.opacityLoading, 0.65);
      expect(light.motion.zIndexPopupBase, seed.zIndexPopupBase);
    });
  });

  group('the algorithms compose the way Ant threads them', () {
    test('resolving no algorithm is the default algorithm', () {
      expect(ThemeAlgorithms.resolve(seed, const []), isA<DesignToken>());
      expect(ThemeAlgorithms.resolve(seed, const []).color.bgContainer, light.color.bgContainer);
    });

    test('compact is a post pass that keeps the variant it tightens', () {
      final comfortable = ThemeAlgorithms.resolve(seed, const [ThemeAlgorithms.defaultAlgorithm]);
      final compact = ThemeAlgorithms.resolve(seed, const [
        ThemeAlgorithms.defaultAlgorithm,
        ThemeAlgorithms.compactAlgorithm,
      ]);
      expect(compact.isDark, isFalse);
      expect(compact.scale.controlHeight, comfortable.scale.controlHeight - 4);
      expect(compact.scale.sizes.md, 12, reason: 'sizeStep 4 - 2 over sizeUnit 4');
    // The same pass walks `sizeStep` down twice, which pushes Ant's `sizeStep -
    // 3` term negative: a negative gap/padding/minimum height reaches Flutter and
    // throws, so the ramp stops at zero.
    expect(compact.scale.sizes.xxs, 0, reason: 'sizeStep 2 - 3 would be -4');
    for (final size in [
      compact.scale.sizes.xxl,
      compact.scale.sizes.xl,
      compact.scale.sizes.lg,
      compact.scale.sizes.md,
      compact.scale.sizes.ms,
      compact.scale.sizes.sm,
      compact.scale.sizes.xs,
      compact.scale.sizes.xxs,
    ]) {
      expect(size, greaterThanOrEqualTo(0));
    }
      expect(compact.scale.radii.base, comfortable.scale.radii.base, reason: 'compact tightens size, not shape');
      expect(compact.color.primary, comfortable.color.primary, reason: 'compact is not a colour pass');
    });

    test('compact after dark stays dark', () {
      final compactDark = ThemeAlgorithms.resolve(seed, const [
        ThemeAlgorithms.darkAlgorithm,
        ThemeAlgorithms.compactAlgorithm,
      ]);
      expect(compactDark.isDark, isTrue);
      expect(compactDark.color.bgContainer, dark.color.bgContainer);
      expect(compactDark.scale.controlHeight, 28);
    });

    test('the seed travels with the token so an override can re-derive from it', () {
      expect(light.seed, seed);
    });
  });

  group('the config chooses the seed and the pipeline', () {
    test('every seed knob the config exposes reaches the seed', () {
      const config = UiConfig(
        accent: Color(0xFFAA0000),
        fontFamily: 'Inter',
        animations: false,
        pureBlack: true,
        focusOutline: false,
      );
      final s = config.toSeed();
      expect(s.colorPrimary, const Color(0xFFAA0000));
      expect(s.fontFamily, 'Inter');
      expect(s.motion, isFalse);
      expect(s.pureBlack, isTrue);
      expect(s.focusOutline, isFalse, reason: 'otherwise the derived focus ring ignores the user setting (§12)');
      expect(s.sizeStep, 4, reason: 'comfortable and compact change the pipeline, not the seed');
    });

    test('spacious is the one density that reseeds', () {
      const roomy = UiConfig(density: UiDensity.spacious);
      expect(roomy.toSeed().sizeStep, 5);
      expect(roomy.toSeed().controlHeight, 40);
      expect(const UiConfig(density: UiDensity.compact).toSeed().controlHeight, 32);
    });

    test('the algorithm list is brightness first, compact last', () {
      expect(const UiConfig().algorithms(dark: false), hasLength(1));
      final compactDark = const UiConfig(density: UiDensity.compact).algorithms(dark: true);
      expect(compactDark, hasLength(2));
      final token = ThemeAlgorithms.resolve(
        const UiConfig(density: UiDensity.compact, pureBlack: true).toSeed(),
        compactDark,
      );
      expect(token.isDark, isTrue);
      expect(token.scale.controlHeight, 28);
    });

    test('brightness policy resolves against the platform', () {
      expect(const UiConfig(brightness: UiBrightnessMode.light).useDark(platformDark: true), isFalse);
      expect(const UiConfig(brightness: UiBrightnessMode.dark).useDark(platformDark: false), isTrue);
      expect(const UiConfig().useDark(platformDark: true), isTrue);
      expect(const UiConfig().useDark(platformDark: false), isFalse);
    });

    test('transparency folds reduceTransparency and a zero multiplier', () {
      expect(const UiConfig().effectiveTransparency, 1);
      expect(const UiConfig().allowsTransparency, isTrue);
      expect(const UiConfig(transparency: 0.5).effectiveTransparency, 0.5);
      expect(const UiConfig(transparency: 0).allowsTransparency, isFalse);
      expect(const UiConfig(transparency: 0.5, reduceTransparency: true).effectiveTransparency, 0);
      expect(const UiConfig(transparency: 0.5, reduceTransparency: true).allowsTransparency, isFalse);
    });
  });
}

/// Asserts [actual] sits within [tolerance] 8-bit steps of Ant's published
/// [expected] per channel — the port is faithful to rounding, not byte-for-byte.
void expectNear(Color actual, Color expected, {int tolerance = 6, String? reason}) {
  for (final (double a, double b) in [(actual.r, expected.r), (actual.g, expected.g), (actual.b, expected.b)]) {
    expect(
      ((a - b) * 255).abs(),
      lessThanOrEqualTo(tolerance),
      reason: reason ?? '$actual is not within $tolerance of $expected',
    );
  }
}
